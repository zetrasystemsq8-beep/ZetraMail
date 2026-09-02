import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:local_auth/local_auth.dart';

import 'main.dart' show supabase, kZetraGreen, kZetraGreenDark, buildErrorBanner;
import 'security_features.dart' show SecurityScreen;

// =====================================================================
// DARK MODE
// =====================================================================
final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier(ThemeMode.light);

final ThemeData kLightTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  colorScheme: ColorScheme.fromSeed(
    seedColor: kZetraGreen,
    primary: kZetraGreen,
    brightness: Brightness.light,
  ),
  scaffoldBackgroundColor: const Color(0xFFF6FBF8),
  cardColor: Colors.white,
  appBarTheme: const AppBarTheme(
    backgroundColor: kZetraGreen,
    foregroundColor: Colors.white,
    elevation: 0,
    centerTitle: true,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: kZetraGreen,
      foregroundColor: Colors.white,
      minimumSize: const Size.fromHeight(50),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: kZetraGreen, width: 2),
    ),
  ),
);

final ThemeData kDarkTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  colorScheme: ColorScheme.fromSeed(
    seedColor: kZetraGreen,
    primary: kZetraGreen,
    brightness: Brightness.dark,
  ),
  scaffoldBackgroundColor: const Color(0xFF0F1512),
  cardColor: const Color(0xFF1A211D),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF0F1512),
    foregroundColor: Colors.white,
    elevation: 0,
    centerTitle: true,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: kZetraGreen,
      foregroundColor: Colors.white,
      minimumSize: const Size.fromHeight(50),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xFF1A211D),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.grey.shade800),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.grey.shade800),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: kZetraGreen, width: 2),
    ),
  ),
);

// =====================================================================
// NOTIFICATIONS
//
// Shows a local notification the moment a new ZetraMail row is
// inserted for the current user, via a live Supabase Realtime stream.
// This fires while the app is open or backgrounded (process alive).
// It does NOT fire if the app has been fully killed by the OS — that
// requires Firebase Cloud Messaging plus a Supabase database webhook
// calling an Edge Function, which needs Firebase console setup
// (google-services.json / APNs keys) outside of this Dart code.
// =====================================================================
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  StreamSubscription<List<Map<String, dynamic>>>? _sub;
  final Set<String> _seenIds = {};
  bool _isFirstEmit = true;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);
    await _plugin.initialize(initSettings);

    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.requestNotificationsPermission();
  }

  void startListening() {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    _sub?.cancel();
    _seenIds.clear();
    _isFirstEmit = true;

    _sub = supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .listen(_onInboxChanged);
  }

  void stopListening() {
    _sub?.cancel();
    _sub = null;
    _seenIds.clear();
    _isFirstEmit = true;
  }

  void _onInboxChanged(List<Map<String, dynamic>> rows) {
    if (_isFirstEmit) {
      _isFirstEmit = false;
      _seenIds.addAll(rows.map((r) => r['id'] as String));
      return;
    }
    for (final row in rows) {
      final id = row['id'] as String;
      if (_seenIds.contains(id)) continue;
      _seenIds.add(id);
      _notify(row);
    }
  }

  Future<void> _notify(Map<String, dynamic> message) async {
    final fromApp = (message['from_app'] as String? ?? 'Zetra').toUpperCase();
    final subject = message['subject'] as String? ?? 'New message';
    final code = message['code'] as String?;
    final body = code != null ? 'Verification code: $code' : (message['body'] as String? ?? '');

    const androidDetails = AndroidNotificationDetails(
      'zetramail_channel',
      'ZetraMail',
      channelDescription: 'New ZetraMail messages and verification codes',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _plugin.show(
      message['id'].hashCode,
      '$fromApp · $subject',
      body,
      details,
    );
  }

  /// Shown when a new device signs in to an account that already has
  /// at least one other trusted device — a plain, informational alert,
  /// not an account lock. See security_features.dart for the caller.
  Future<void> showNewDeviceAlert() async {
    const androidDetails = AndroidNotificationDetails(
      'zetra_security_channel',
      'Zetra Security',
      channelDescription: 'Security alerts such as new-device sign-ins',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _plugin.show(
      'new_device_alert'.hashCode,
      'New device signed in',
      'If this wasn\'t you, review your devices and change your password.',
      details,
    );
  }
}

// =====================================================================
// APP LOCK — biometrics with PIN fallback
// =====================================================================
class AppLockService {
  AppLockService._();
  static final AppLockService instance = AppLockService._();

  final _storage = const FlutterSecureStorage();
  static const _kPinKey = 'zetra_lock_pin';
  static const _kLockEnabledKey = 'zetra_lock_enabled';
  static const _kBiometricPromptShownKey = 'zetra_biometric_prompt_shown';

  Future<bool> isLockEnabled() async {
    final v = await _storage.read(key: _kLockEnabledKey);
    return v == 'true';
  }

  Future<void> setLockEnabled(bool enabled) async {
    await _storage.write(key: _kLockEnabledKey, value: enabled.toString());
    if (!enabled) {
      await _storage.delete(key: _kPinKey);
    }
  }

  Future<void> setPin(String pin) async {
    await _storage.write(key: _kPinKey, value: pin);
  }

  Future<bool> verifyPin(String pin) async {
    final saved = await _storage.read(key: _kPinKey);
    return saved != null && saved == pin;
  }

  Future<bool> tryBiometricUnlock() async {
    final auth = LocalAuthentication();
    try {
      final supported = await auth.isDeviceSupported();
      final canCheck = await auth.canCheckBiometrics;
      if (!supported && !canCheck) return false;
      return await auth.authenticate(
        localizedReason: 'Unlock Zetra ID',
        options: const AuthenticationOptions(biometricOnly: false, stickyAuth: true),
      );
    } catch (_) {
      return false;
    }
  }

  /// Whether this device has usable biometric/passcode hardware at
  /// all — used to decide whether it's even worth offering the
  /// "sign in faster" prompt.
  Future<bool> isBiometricAvailable() async {
    final auth = LocalAuthentication();
    try {
      final supported = await auth.isDeviceSupported();
      final canCheck = await auth.canCheckBiometrics;
      return supported || canCheck;
    } catch (_) {
      return false;
    }
  }

  /// True exactly once per install: the device supports biometrics,
  /// the user hasn't already turned on App Lock, and they haven't
  /// been asked before. Keeps the prompt from ever being naggy.
  Future<bool> shouldOfferBiometricPrompt() async {
    final alreadyEnabled = await isLockEnabled();
    if (alreadyEnabled) return false;
    final alreadyShown = await _storage.read(key: _kBiometricPromptShownKey);
    if (alreadyShown == 'true') return false;
    return isBiometricAvailable();
  }

  Future<void> markBiometricPromptShown() async {
    await _storage.write(key: _kBiometricPromptShownKey, value: 'true');
  }
}

/// Wraps the whole app. Shows LockScreen on cold start (if lock is
/// enabled) and again whenever the app returns from the background.
class AppLockGate extends StatefulWidget {
  final Widget child;
  const AppLockGate({super.key, required this.child});

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  bool _locked = false;
  bool _checkedInitialState = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkInitialLock();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _checkInitialLock() async {
    final enabled = await AppLockService.instance.isLockEnabled();
    if (mounted) {
      setState(() {
        _locked = enabled;
        _checkedInitialState = true;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      final enabled = await AppLockService.instance.isLockEnabled();
      if (enabled && mounted) setState(() => _locked = true);
    }
  }

  void _unlock() => setState(() => _locked = false);

  @override
  Widget build(BuildContext context) {
    if (!_checkedInitialState) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: kZetraGreen)));
    }
    if (_locked) {
      return LockScreen(onUnlocked: _unlock);
    }
    return widget.child;
  }
}

class LockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;
  const LockScreen({super.key, required this.onUnlocked});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _pinController = TextEditingController();
  String? _error;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _attemptBiometric());
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _attemptBiometric() async {
    setState(() => _checking = true);
    final ok = await AppLockService.instance.tryBiometricUnlock();
    if (mounted) setState(() => _checking = false);
    if (ok) widget.onUnlocked();
  }

  Future<void> _submitPin() async {
    final pin = _pinController.text.trim();
    if (pin.length < 4) {
      setState(() => _error = 'Enter your PIN.');
      return;
    }
    final ok = await AppLockService.instance.verifyPin(pin);
    if (ok) {
      widget.onUnlocked();
    } else {
      setState(() {
        _error = 'Incorrect PIN.';
        _pinController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kZetraGreen,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, color: Colors.white, size: 72),
              const SizedBox(height: 20),
              const Text(
                'Zetra ID Locked',
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 30),
              TextField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, letterSpacing: 8),
                decoration: InputDecoration(
                  counterText: '',
                  filled: true,
                  fillColor: Colors.white,
                  hintText: 'Enter PIN',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onSubmitted: (_) => _submitPin(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: Colors.white)),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: kZetraGreen),
                  onPressed: _submitPin,
                  child: const Text('Unlock'),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _checking ? null : _attemptBiometric,
                child: Text(
                  _checking ? 'Checking...' : 'Use biometrics instead',
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SetPinScreen extends StatefulWidget {
  const SetPinScreen({super.key});

  @override
  State<SetPinScreen> createState() => _SetPinScreenState();
}

class _SetPinScreenState extends State<SetPinScreen> {
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _save() {
    final pin = _pinController.text.trim();
    final confirm = _confirmController.text.trim();
    if (pin.length < 4) {
      setState(() => _error = 'PIN must be at least 4 digits.');
      return;
    }
    if (pin != confirm) {
      setState(() => _error = 'PINs do not match.');
      return;
    }
    Navigator.of(context).pop(pin);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Set a PIN')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Choose a PIN', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text("You'll use this if biometrics fail.", style: TextStyle(color: Colors.grey.shade600)),
              const SizedBox(height: 24),
              TextField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                decoration: const InputDecoration(labelText: 'New PIN', counterText: ''),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _confirmController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                decoration: const InputDecoration(labelText: 'Confirm PIN', counterText: ''),
              ),
              const SizedBox(height: 20),
              if (_error != null) ...[
                buildErrorBanner(_error!),
                const SizedBox(height: 16),
              ],
              ElevatedButton(onPressed: _save, child: const Text('Save PIN')),
            ],
          ),
        ),
      ),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _lockEnabled = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await AppLockService.instance.isLockEnabled();
    if (mounted) {
      setState(() {
        _lockEnabled = enabled;
        _loading = false;
      });
    }
  }

  Future<void> _toggleLock(bool value) async {
    if (value) {
      final pin = await Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (_) => const SetPinScreen()),
      );
      if (pin == null || pin.length < 4) return;
      await AppLockService.instance.setPin(pin);
      await AppLockService.instance.setLockEnabled(true);
    } else {
      await AppLockService.instance.setLockEnabled(false);
    }
    if (mounted) setState(() => _lockEnabled = value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kZetraGreen))
          : ValueListenableBuilder<ThemeMode>(
              valueListenable: themeModeNotifier,
              builder: (context, mode, _) {
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          SwitchListTile(
                            title: const Text('Dark mode'),
                            subtitle: const Text('Switch between light and dark appearance'),
                            secondary: const Icon(Icons.dark_mode_outlined, color: kZetraGreenDark),
                            value: mode == ThemeMode.dark,
                            onChanged: (v) {
                              themeModeNotifier.value = v ? ThemeMode.dark : ThemeMode.light;
                            },
                            activeColor: kZetraGreen,
                          ),
                          const Divider(height: 1),
                          SwitchListTile(
                            title: const Text('App lock'),
                            subtitle: const Text('Require biometrics or a PIN to open the app'),
                            secondary: const Icon(Icons.lock_outline, color: kZetraGreenDark),
                            value: _lockEnabled,
                            onChanged: _toggleLock,
                            activeColor: kZetraGreen,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.security_outlined, color: kZetraGreenDark),
                        title: const Text('Security'),
                        subtitle: const Text('Two-factor authentication, devices, and activity'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const SecurityScreen()),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

// =====================================================================
// STREAK SERVICE — daily open streak, stored locally.
//
// Purely a client-side engagement nudge (like a "day count" badge):
// it counts consecutive calendar days the app has been opened. It is
// never punitive or blocking — it just powers the flame badge on the
// Home screen. No account/server state depends on it.
// =====================================================================
class StreakService {
  StreakService._();
  static final StreakService instance = StreakService._();

  final _storage = const FlutterSecureStorage();
  static const _kStreakCountKey = 'zetra_streak_count';
  static const _kStreakLastDateKey = 'zetra_streak_last_date';

  String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Call once per app session (e.g. when the Home screen loads).
  /// Returns the current streak count including today.
  Future<int> registerOpenAndGetStreak() async {
    final now = DateTime.now();
    final todayKey = _dateKey(now);

    final lastDateStr = await _storage.read(key: _kStreakLastDateKey);
    final countStr = await _storage.read(key: _kStreakCountKey);
    int count = int.tryParse(countStr ?? '') ?? 0;

    if (lastDateStr == todayKey) {
      // Already registered today.
      return count == 0 ? 1 : count;
    }

    if (lastDateStr != null) {
      final lastDate = DateTime.tryParse(lastDateStr);
      if (lastDate != null) {
        final diff = DateTime(now.year, now.month, now.day)
            .difference(DateTime(lastDate.year, lastDate.month, lastDate.day))
            .inDays;
        if (diff == 1) {
          count += 1; // consecutive day
        } else if (diff > 1 || diff < 0) {
          count = 1; // streak broken (or clock rolled back) — restart
        } else {
          count = count == 0 ? 1 : count;
        }
      } else {
        count = 1;
      }
    } else {
      count = 1; // first ever open
    }

    await _storage.write(key: _kStreakLastDateKey, value: todayKey);
    await _storage.write(key: _kStreakCountKey, value: count.toString());
    return count;
  }
}

// =====================================================================
// ONBOARDING SERVICE — tracks whether the first-run feature tour has
// been shown, so it only appears once per install.
// =====================================================================
class OnboardingService {
  OnboardingService._();
  static final OnboardingService instance = OnboardingService._();

  final _storage = const FlutterSecureStorage();
  static const _kSeenKey = 'zetra_onboarding_seen_v1';

  Future<bool> hasSeenOnboarding() async {
    final v = await _storage.read(key: _kSeenKey);
    return v == 'true';
  }

  Future<void> markSeen() async {
    await _storage.write(key: _kSeenKey, value: 'true');
  }
}
