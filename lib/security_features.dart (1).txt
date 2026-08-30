import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_features.dart' show NotificationService;
import 'main.dart' show supabase, kZetraGreen, kZetraGreenDark, buildErrorBanner, showZetraToast;

// =====================================================================
// ZETRA ACCOUNT SECURITY — PHASE 1
//
// This file implements the parts of an account-security system that
// are genuinely achievable from a mobile client talking to Supabase,
// with no paid third-party services:
//
//   - A privacy-preserving installation ID (random, local, no IMEI/
//     hardware serial — resets on reinstall by design)
//   - OS name/version signals (via dart:io Platform — no extra package)
//   - A manually-maintained app version constant (kAppVersion below)
//   - Device trust tracking (new vs. known device) via a `device_trust`
//     table + a security-definer RPC (see security_migration.sql)
//   - A `security_events` audit log the user can review
//   - New-device local notifications
//   - Native two-factor authentication (TOTP) using Supabase's built-in
//     `auth.mfa` API — no extra package, no extra table
//
// What this file deliberately does NOT implement, and why:
//
//   - IP reputation / VPN / Tor / ASN detection — the client's own IP
//     can't be trusted to self-report; this needs a server-side Edge
//     Function reading the real request IP plus a paid intelligence
//     API (e.g. IPQualityScore, MaxMind minFraud, ipinfo.io). See the
//     roadmap notes shipped alongside this file.
//   - Impossible-travel detection — depends on the IP geolocation above.
//   - Root/jailbreak detection — needs a platform-specific plugin
//     (e.g. flutter_jailbreak_detection) that isn't in your project
//     yet; noted as an easy Phase 1.5 add-on once you confirm you want
//     the extra dependency.
//   - Bulk-behavior / bot-timing / automation detection, account
//     linkage across payment instruments, and an automated trust-score
//     engine — these need a real signal pipeline and tuning against
//     your actual traffic; shipping a fake scoring formula today would
//     give false confidence, so this is left to the roadmap.
//   - Remote sign-out of other devices — Supabase's admin session
//     revocation API requires the service_role key, which must never
//     ship inside a mobile app; this needs a small Edge Function you
//     control. Sketch included in the roadmap notes.
// =====================================================================

/// Bump this manually whenever you release a new build. There's no
/// extra package required for this — just keep it in sync with your
/// pubspec.yaml `version:` field.
const String kAppVersion = '1.0.0';

class DeviceIdentityService {
  DeviceIdentityService._();
  static final DeviceIdentityService instance = DeviceIdentityService._();

  final _storage = const FlutterSecureStorage();
  static const _kDeviceIdKey = 'zetra_device_id';

  /// A random, local-only identifier — not derived from any hardware
  /// serial, IMEI, or advertising ID. It changes if the app is
  /// reinstalled or the user clears app data, which is intentional:
  /// it identifies "this app installation," not "this physical device"
  /// in a way that could be used to fingerprint someone across apps.
  Future<String> getOrCreateInstallationId() async {
    final existing = await _storage.read(key: _kDeviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;

    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    final id = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

    await _storage.write(key: _kDeviceIdKey, value: id);
    return id;
  }

  String get osName {
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isLinux) return 'Linux';
    return 'Unknown';
  }

  String get osVersion {
    try {
      return Platform.operatingSystemVersion;
    } catch (_) {
      return 'unknown';
    }
  }
}

/// Talks to the two security-definer RPCs created by
/// security_migration.sql. Every call is best-effort: a failure here
/// should never block login or app usage — security signal collection
/// degrading gracefully is safer than an outage turning into a lockout.
class SecurityEventService {
  SecurityEventService._();
  static final SecurityEventService instance = SecurityEventService._();

  /// Call this once, right after a successful login or signup.
  /// Returns null on any failure (network, RPC missing, etc.) instead
  /// of throwing, so callers can simply ignore a null result.
  Future<Map<String, dynamic>?> registerDeviceLogin() async {
    try {
      final deviceId = await DeviceIdentityService.instance.getOrCreateInstallationId();
      final result = await supabase.rpc('register_device_login', params: {
        'p_device_id': deviceId,
        'p_os': DeviceIdentityService.instance.osName,
        'p_os_version': DeviceIdentityService.instance.osVersion,
        'p_app_version': kAppVersion,
      }).timeout(const Duration(seconds: 15));
      if (result == null) return null;
      return Map<String, dynamic>.from(result as Map);
    } catch (_) {
      return null;
    }
  }

  /// Call this for any other event worth recording — e.g. after
  /// enabling/disabling MFA. `eventType` should be one of the
  /// SCREAMING_SNAKE_CASE event names from the roadmap doc, so your
  /// event log stays consistent and queryable.
  Future<void> logEvent(String eventType, {Map<String, dynamic>? metadata}) async {
    try {
      await supabase.rpc('log_security_event', params: {
        'p_event_type': eventType,
        'p_metadata': metadata,
      }).timeout(const Duration(seconds: 15));
    } catch (_) {
      // Best effort — never block the user action that triggered this.
    }
  }

  Future<List<Map<String, dynamic>>> fetchRecentEvents({int limit = 50}) async {
    final data = await supabase
        .from('security_events')
        .select('id, event_type, device_id, metadata, created_at')
        .order('created_at', ascending: false)
        .limit(limit)
        .timeout(const Duration(seconds: 20));
    return List<Map<String, dynamic>>.from(data as List);
  }

  Future<List<Map<String, dynamic>>> fetchTrustedDevices() async {
    final data = await supabase
        .from('device_trust')
        .select('id, device_id, os, os_version, app_version, first_seen, last_seen')
        .order('last_seen', ascending: false)
        .timeout(const Duration(seconds: 20));
    return List<Map<String, dynamic>>.from(data as List);
  }

  Future<void> removeTrustedDevice(String rowId) async {
    await supabase.from('device_trust').delete().eq('id', rowId).timeout(const Duration(seconds: 15));
  }
}

/// Call this once, right after a successful login or signup (see the
/// wiring in main.dart's login/signup flows). It silently records the
/// login and, if this is a new device on an account that already has
/// at least one other trusted device, shows a local "new device"
/// notification so the user notices unexpected access.
Future<void> handlePostAuthSecurityCheck() async {
  final result = await SecurityEventService.instance.registerDeviceLogin();
  if (result == null) return;
  final isNew = result['is_new_device'] == true;
  final deviceCount = (result['device_count'] as num?)?.toInt() ?? 1;
  if (isNew && deviceCount > 1) {
    await NotificationService.instance.showNewDeviceAlert();
  }
}

// =====================================================================
// RE-AUTHENTICATION — a small password prompt used before any
// sensitive action (changing the password, turning off 2FA). Verifies
// identity by re-running sign-in with the current session's email;
// Supabase's client SDK has no separate "just check this password"
// call, so re-signing-in is the standard way to confirm it.
// =====================================================================
Future<bool> promptReauthentication(BuildContext context, {required String reason}) async {
  final controller = TextEditingController();
  bool obscure = true;
  String? error;
  bool isChecking = false;

  final verified = await showDialog<bool>(
    context: context,
    barrierDismissible: !isChecking,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setDialogState) {
          Future<void> verify() async {
            final password = controller.text;
            if (password.isEmpty) {
              setDialogState(() => error = 'Enter your password.');
              return;
            }
            final email = supabase.auth.currentUser?.email;
            if (email == null) {
              setDialogState(() => error = 'Your session has expired. Please log in again.');
              return;
            }
            setDialogState(() {
              isChecking = true;
              error = null;
            });
            try {
              await supabase.auth
                  .signInWithPassword(email: email, password: password)
                  .timeout(const Duration(seconds: 20));
              if (ctx.mounted) Navigator.of(ctx).pop(true);
            } on AuthException catch (_) {
              setDialogState(() {
                error = 'Incorrect password.';
                isChecking = false;
              });
            } catch (_) {
              setDialogState(() {
                error = 'Something went wrong. Please try again.';
                isChecking = false;
              });
            }
          }

          return AlertDialog(
            title: const Text('Confirm it\'s you'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(reason, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  obscureText: obscure,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Current password',
                    suffixIcon: IconButton(
                      icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setDialogState(() => obscure = !obscure),
                    ),
                  ),
                  onSubmitted: (_) => verify(),
                ),
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Text(error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: isChecking ? null : () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: isChecking ? null : verify,
                child: isChecking
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Confirm'),
              ),
            ],
          );
        },
      );
    },
  );

  controller.dispose();
  return verified ?? false;
}

// =====================================================================
// SECURITY SCREEN — the user-facing hub: 2FA, password, trusted
// devices, and recent activity.
// =====================================================================
class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  bool _loadingMfa = true;
  bool _mfaEnabled = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMfaStatus();
  }

  Future<void> _loadMfaStatus() async {
    setState(() {
      _loadingMfa = true;
      _error = null;
    });
    try {
      final factors = await supabase.auth.mfa.listFactors();
      final verified = factors.totp.where((f) => f.status == FactorStatus.verified).toList();
      if (mounted) setState(() => _mfaEnabled = verified.isNotEmpty);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not check two-factor status.');
    } finally {
      if (mounted) setState(() => _loadingMfa = false);
    }
  }

  Future<void> _startEnrollMfa() async {
    final enrolled = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const MfaEnrollScreen()),
    );
    if (enrolled == true) {
      await SecurityEventService.instance.logEvent('MFA_ENABLED');
      _loadMfaStatus();
    }
  }

  Future<void> _disableMfa() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Turn off two-factor authentication?'),
        content: const Text('Your account will be protected by your password alone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Turn off', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    if (!mounted) return;
    final reauthed = await promptReauthentication(
      context,
      reason: 'Turning off two-factor authentication weakens your account\'s protection.',
    );
    if (!reauthed) return;

    try {
      final factors = await supabase.auth.mfa.listFactors();
      for (final f in factors.totp) {
        await supabase.auth.mfa.unenroll(UnenrollParams(factorId: f.id));
      }
      await SecurityEventService.instance.logEvent('MFA_DISABLED');
      if (mounted) showZetraToast(context, 'Two-factor authentication turned off');
      _loadMfaStatus();
    } catch (_) {
      if (mounted) showZetraToast(context, 'Could not turn off two-factor authentication.', icon: Icons.error_outline);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Security')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionCard(
            icon: Icons.verified_user_outlined,
            title: 'Two-factor authentication',
            subtitle: _loadingMfa
                ? 'Checking status…'
                : (_mfaEnabled
                    ? 'Enabled — your account requires a code at sign-in.'
                    : 'Add a second layer of protection using an authenticator app.'),
            trailing: _loadingMfa
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4))
                : Switch(
                    value: _mfaEnabled,
                    activeColor: kZetraGreen,
                    onChanged: (v) => v ? _startEnrollMfa() : _disableMfa(),
                  ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            buildErrorBanner(_error!),
          ],
          const SizedBox(height: 12),
          _navCard(
            icon: Icons.password_outlined,
            title: 'Change password',
            subtitle: 'Update your password. We\'ll confirm it\'s you first.',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _navCard(
            icon: Icons.devices_outlined,
            title: 'Trusted devices',
            subtitle: 'See every device that has signed in to your account.',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const TrustedDevicesScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _navCard(
            icon: Icons.history,
            title: 'Recent activity',
            subtitle: 'A log of logins and security-relevant changes.',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SecurityActivityScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: kZetraGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: kZetraGreen),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    );
  }

  Widget _navCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: kZetraGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: kZetraGreen),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// CHANGE PASSWORD — requires re-authentication first (see
// promptReauthentication above), then updates via Supabase Auth and
// logs a PASSWORD_CHANGED security event.
// =====================================================================
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String? _validate() {
    if (_currentController.text.isEmpty) return 'Enter your current password.';
    if (_newController.text.length < 8) return 'New password must be at least 8 characters.';
    if (_newController.text != _confirmController.text) return 'New passwords do not match.';
    if (_newController.text == _currentController.text) return 'New password must be different from your current one.';
    return null;
  }

  Future<void> _submit() async {
    final validationError = _validate();
    if (validationError != null) {
      setState(() => _error = validationError);
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final email = supabase.auth.currentUser?.email;
      if (email == null) {
        setState(() => _error = 'Your session has expired. Please log in again.');
        return;
      }

      // Re-verify the current password before changing anything —
      // this also refreshes the session, which Supabase requires for
      // a sensitive update like this to succeed reliably.
      await supabase.auth
          .signInWithPassword(email: email, password: _currentController.text)
          .timeout(const Duration(seconds: 20));

      await supabase.auth
          .updateUser(UserAttributes(password: _newController.text))
          .timeout(const Duration(seconds: 20));

      await SecurityEventService.instance.logEvent('PASSWORD_CHANGED');

      if (mounted) {
        showZetraToast(context, 'Password updated');
        Navigator.of(context).pop();
      }
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('invalid') || msg.contains('credentials')) {
        setState(() => _error = 'Your current password is incorrect.');
      } else {
        setState(() => _error = e.message.isNotEmpty ? e.message : 'Something went wrong. Please try again.');
      }
    } catch (_) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Change password')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _currentController,
                obscureText: _obscureCurrent,
                decoration: InputDecoration(
                  labelText: 'Current password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureCurrent ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _newController,
                obscureText: _obscureNew,
                decoration: InputDecoration(
                  labelText: 'New password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureNew ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscureNew = !_obscureNew),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _confirmController,
                obscureText: _obscureConfirm,
                decoration: InputDecoration(
                  labelText: 'Confirm new password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (_error != null) ...[
                buildErrorBanner(_error!),
                const SizedBox(height: 16),
              ],
              ElevatedButton(
                onPressed: _isSaving ? null : _submit,
                child: _isSaving
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                      )
                    : const Text('Update Password'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// MFA ENROLLMENT — TOTP (Google Authenticator / Authy style) using
// Supabase's built-in auth.mfa API. No new package, no new table.
// =====================================================================
class MfaEnrollScreen extends StatefulWidget {
  const MfaEnrollScreen({super.key});

  @override
  State<MfaEnrollScreen> createState() => _MfaEnrollScreenState();
}

class _MfaEnrollScreenState extends State<MfaEnrollScreen> {
  bool _isEnrolling = true;
  bool _isVerifying = false;
  String? _error;
  String? _factorId;
  String? _secret;
  String? _qrSvg;
  final _codeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _enroll();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _enroll() async {
    setState(() {
      _isEnrolling = true;
      _error = null;
    });
    try {
      final response = await supabase.auth.mfa.enroll(
        factorType: FactorType.totp,
        issuer: 'Zetra ID',
      );
      setState(() {
        _factorId = response.id;
        _secret = response.totp.secret;
        _qrSvg = response.totp.qrCode;
      });
    } catch (e) {
      setState(() => _error = 'Could not start two-factor setup. Please try again.');
    } finally {
      if (mounted) setState(() => _isEnrolling = false);
    }
  }

  Future<void> _verify() async {
    final code = _codeController.text.trim();
    if (code.length < 6 || _factorId == null) {
      setState(() => _error = 'Enter the 6-digit code from your authenticator app.');
      return;
    }
    setState(() {
      _isVerifying = true;
      _error = null;
    });
    try {
      final challenge = await supabase.auth.mfa.challenge(factorId: _factorId!);
      await supabase.auth.mfa.verify(factorId: _factorId!, challengeId: challenge.id, code: code);
      if (mounted) {
        showZetraToast(context, 'Two-factor authentication enabled');
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() => _error = 'That code didn\'t work. Check your authenticator app and try again.');
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Set up two-factor authentication')),
      body: SafeArea(
        child: _isEnrolling
            ? const Center(child: CircularProgressIndicator(color: kZetraGreen))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      '1. Scan this in your authenticator app',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Google Authenticator, Authy, or any TOTP app works.',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    if (_qrSvg != null)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12)],
                        ),
                        child: SizedBox(
                          height: 200,
                          child: Center(
                            child: Text(
                              // The SVG string from Supabase can be rendered with
                              // flutter_svg if you add that package; showing the
                              // manual-entry secret below always works with zero
                              // extra dependencies, so it's the primary path here.
                              'QR rendering needs flutter_svg (optional).\nUse the code below instead — it works the same.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    const Text(
                      '2. Or enter this code manually',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: kZetraGreen.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: kZetraGreen.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _secret ?? '',
                              style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, letterSpacing: 1),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy_outlined, color: kZetraGreenDark),
                            onPressed: _secret == null
                                ? null
                                : () {
                                    Clipboard.setData(ClipboardData(text: _secret!));
                                    showZetraToast(context, 'Secret copied');
                                  },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      '3. Enter the 6-digit code it shows',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _codeController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 22, letterSpacing: 6),
                      decoration: const InputDecoration(counterText: '', hintText: '000000'),
                    ),
                    const SizedBox(height: 12),
                    if (_error != null) ...[
                      buildErrorBanner(_error!),
                      const SizedBox(height: 16),
                    ],
                    ElevatedButton(
                      onPressed: _isVerifying ? null : _verify,
                      child: _isVerifying
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                            )
                          : const Text('Verify & Enable'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

// =====================================================================
// TRUSTED DEVICES
// =====================================================================
class TrustedDevicesScreen extends StatefulWidget {
  const TrustedDevicesScreen({super.key});

  @override
  State<TrustedDevicesScreen> createState() => _TrustedDevicesScreenState();
}

class _TrustedDevicesScreenState extends State<TrustedDevicesScreen> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _devices = [];
  String? _currentDeviceId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      _currentDeviceId = await DeviceIdentityService.instance.getOrCreateInstallationId();
      final devices = await SecurityEventService.instance.fetchTrustedDevices();
      setState(() => _devices = devices);
    } catch (_) {
      setState(() => _error = 'Could not load your devices. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _remove(Map<String, dynamic> device) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove this device?'),
        content: const Text(
          'This clears it from your trusted list. It does not sign that device out — '
          'if you\'re worried someone else has access, change your password too.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await SecurityEventService.instance.removeTrustedDevice(device['id'] as String);
      setState(() => _devices.remove(device));
      if (mounted) showZetraToast(context, 'Device removed');
    } catch (_) {
      if (mounted) showZetraToast(context, 'Could not remove that device.', icon: Icons.error_outline);
    }
  }

  String _timeAgo(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final diff = DateTime.now().toUtc().difference(dt.toUtc());
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trusted devices')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kZetraGreen))
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: buildErrorBanner(_error!)))
              : RefreshIndicator(
                  color: kZetraGreen,
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _devices.length,
                    itemBuilder: (context, index) {
                      final d = _devices[index];
                      final isCurrent = d['device_id'] == _currentDeviceId;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(14),
                          border: isCurrent ? Border.all(color: kZetraGreen.withOpacity(0.4)) : null,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              (d['os'] as String? ?? '').toLowerCase() == 'ios' ? Icons.phone_iphone : Icons.smartphone,
                              color: kZetraGreenDark,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        '${d['os'] ?? 'Unknown'} · ${d['os_version'] ?? ''}',
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                      ),
                                      if (isCurrent) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: kZetraGreen.withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            'THIS DEVICE',
                                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: kZetraGreenDark),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Last active ${_timeAgo(d['last_seen'] as String?)} · App v${d['app_version'] ?? '?'}',
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ),
                            if (!isCurrent)
                              IconButton(
                                icon: const Icon(Icons.close, size: 20, color: Colors.red),
                                tooltip: 'Remove',
                                onPressed: () => _remove(d),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

// =====================================================================
// RECENT SECURITY ACTIVITY
// =====================================================================
class SecurityActivityScreen extends StatefulWidget {
  const SecurityActivityScreen({super.key});

  @override
  State<SecurityActivityScreen> createState() => _SecurityActivityScreenState();
}

class _SecurityActivityScreenState extends State<SecurityActivityScreen> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _events = [];

  static const Map<String, String> _labels = {
    'LOGIN': 'Signed in',
    'NEW_DEVICE_LOGIN': 'New device signed in',
    'MFA_ENABLED': 'Two-factor authentication turned on',
    'MFA_DISABLED': 'Two-factor authentication turned off',
    'PASSWORD_CHANGED': 'Password changed',
  };

  static const Map<String, IconData> _icons = {
    'LOGIN': Icons.login,
    'NEW_DEVICE_LOGIN': Icons.smartphone,
    'MFA_ENABLED': Icons.verified_user_outlined,
    'MFA_DISABLED': Icons.gpp_maybe_outlined,
    'PASSWORD_CHANGED': Icons.password_outlined,
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final events = await SecurityEventService.instance.fetchRecentEvents();
      setState(() => _events = events);
    } catch (_) {
      setState(() => _error = 'Could not load recent activity.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final period = dt.hour < 12 ? 'AM' : 'PM';
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} · $hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recent activity')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kZetraGreen))
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: buildErrorBanner(_error!)))
              : _events.isEmpty
                  ? Center(
                      child: Text('No activity recorded yet.', style: TextStyle(color: Colors.grey.shade600)),
                    )
                  : RefreshIndicator(
                      color: kZetraGreen,
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _events.length,
                        itemBuilder: (context, index) {
                          final e = _events[index];
                          final type = e['event_type'] as String? ?? '';
                          final label = _labels[type] ?? type;
                          final icon = _icons[type] ?? Icons.info_outline;
                          final metadata = e['metadata'];
                          String? detail;
                          if (metadata is Map && metadata['os'] != null) {
                            detail = '${metadata['os']} ${metadata['os_version'] ?? ''}'.trim();
                          }
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(icon, color: kZetraGreenDark, size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                      if (detail != null) ...[
                                        const SizedBox(height: 2),
                                        Text(detail, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                      ],
                                    ],
                                  ),
                                ),
                                Text(
                                  _formatDate(e['created_at'] as String?),
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
