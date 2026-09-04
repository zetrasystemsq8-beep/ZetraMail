import 'dart:async';
import 'dart:io';
import 'update_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:passkeys/authenticator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'app_features.dart';
import 'security_features.dart' show handlePostAuthSecurityCheck, SecurityScreen, SecurityEventService;
import 'reports_feature.dart' show ReportScreen;

// =====================================================================
// Supabase project configuration.
// Replace with your project's values from Project Settings -> API.
// =====================================================================
const String kSupabaseUrl = 'https://ssmwuihkafrulmvtiuam.supabase.co';
const String kSupabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNzbXd1aWhrYWZydWxtdnRpdWFtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA4Mjk2NjAsImV4cCI6MjA5NjQwNTY2MH0.e1PxmDW77ZhbonS-Z96SWA_sPyVGedzpZNZbJQz7pQo';

const Color kZetraGreen = Color(0xFF008751);
const Color kZetraGreenDark = Color(0xFF00623B);

const String kTermsAndPrivacyUrl = 'https://trusty-id-hub.lovable.app/';

SupabaseClient get supabase => Supabase.instance.client;

const List<String> kCountries = [
  'Nigeria',
  'Afghanistan', 'Albania', 'Algeria', 'Andorra', 'Angola', 'Antigua and Barbuda',
  'Argentina', 'Armenia', 'Australia', 'Austria', 'Azerbaijan', 'Bahamas', 'Bahrain',
  'Bangladesh', 'Barbados', 'Belarus', 'Belgium', 'Belize', 'Benin', 'Bhutan', 'Bolivia',
  'Bosnia and Herzegovina', 'Botswana', 'Brazil', 'Brunei', 'Bulgaria', 'Burkina Faso',
  'Burundi', 'Cabo Verde', 'Cambodia', 'Cameroon', 'Canada', 'Central African Republic',
  'Chad', 'Chile', 'China', 'Colombia', 'Comoros', 'Congo (Brazzaville)', 'Congo (Kinshasa)',
  'Costa Rica', 'Croatia', 'Cuba', 'Cyprus', 'Czechia', 'Denmark', 'Djibouti', 'Dominica',
  'Dominican Republic', 'Ecuador', 'Egypt', 'El Salvador', 'Equatorial Guinea', 'Eritrea',
  'Estonia', 'Eswatini', 'Ethiopia', 'Fiji', 'Finland', 'France', 'Gabon', 'Gambia',
  'Georgia', 'Germany', 'Ghana', 'Greece', 'Grenada', 'Guatemala', 'Guinea', 'Guinea-Bissau',
  'Guyana', 'Haiti', 'Honduras', 'Hungary', 'Iceland', 'India', 'Indonesia', 'Iran', 'Iraq',
  'Ireland', 'Israel', 'Italy', 'Ivory Coast', 'Jamaica', 'Japan', 'Jordan', 'Kazakhstan',
  'Kenya', 'Kiribati', 'Kosovo', 'Kuwait', 'Kyrgyzstan', 'Laos', 'Latvia', 'Lebanon',
  'Lesotho', 'Liberia', 'Libya', 'Liechtenstein', 'Lithuania', 'Luxembourg', 'Madagascar',
  'Malawi', 'Malaysia', 'Maldives', 'Mali', 'Malta', 'Marshall Islands', 'Mauritania',
  'Mauritius', 'Mexico', 'Micronesia', 'Moldova', 'Monaco', 'Mongolia', 'Montenegro',
  'Morocco', 'Mozambique', 'Myanmar', 'Namibia', 'Nauru', 'Nepal', 'Netherlands',
  'New Zealand', 'Nicaragua', 'Niger', 'North Korea', 'North Macedonia', 'Norway', 'Oman',
  'Pakistan', 'Palau', 'Palestine', 'Panama', 'Papua New Guinea', 'Paraguay', 'Peru',
  'Philippines', 'Poland', 'Portugal', 'Qatar', 'Romania', 'Russia', 'Rwanda',
  'Saint Kitts and Nevis', 'Saint Lucia', 'Saint Vincent and the Grenadines', 'Samoa',
  'San Marino', 'Sao Tome and Principe', 'Saudi Arabia', 'Senegal', 'Serbia', 'Seychelles',
  'Sierra Leone', 'Singapore', 'Slovakia', 'Slovenia', 'Solomon Islands', 'Somalia',
  'South Africa', 'South Korea', 'South Sudan', 'Spain', 'Sri Lanka', 'Sudan', 'Suriname',
  'Sweden', 'Switzerland', 'Syria', 'Taiwan', 'Tajikistan', 'Tanzania', 'Thailand',
  'Timor-Leste', 'Togo', 'Tonga', 'Trinidad and Tobago', 'Tunisia', 'Turkey',
  'Turkmenistan', 'Tuvalu', 'Uganda', 'Ukraine', 'United Arab Emirates', 'United Kingdom',
  'United States', 'Uruguay', 'Uzbekistan', 'Vanuatu', 'Vatican City', 'Venezuela',
  'Vietnam', 'Yemen', 'Zambia', 'Zimbabwe',
];

/// All 36 Nigerian states plus the Federal Capital Territory (Abuja),
/// shown as a second dropdown when the selected country is Nigeria —
/// this app's primary market.
const List<String> kNigerianStates = [
  'Abia', 'Adamawa', 'Akwa Ibom', 'Anambra', 'Bauchi', 'Bayelsa', 'Benue',
  'Borno', 'Cross River', 'Delta', 'Ebonyi', 'Edo', 'Ekiti', 'Enugu',
  'Federal Capital Territory (Abuja)', 'Gombe', 'Imo', 'Jigawa', 'Kaduna',
  'Kano', 'Katsina', 'Kebbi', 'Kogi', 'Kwara', 'Lagos', 'Nasarawa', 'Niger',
  'Ogun', 'Ondo', 'Osun', 'Oyo', 'Plateau', 'Rivers', 'Sokoto', 'Taraba',
  'Yobe', 'Zamfara',
];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: kSupabaseUrl,
    anonKey: kSupabaseAnonKey,
  );
  await NotificationService.instance.init();
  runApp(const UpdateGate(child: ZetraIdApp()));
}

class ZetraIdApp extends StatelessWidget {
  const ZetraIdApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'Zetra ID',
          debugShowCheckedModeBanner: false,
          theme: kLightTheme,
          darkTheme: kDarkTheme,
          themeMode: mode,
          home: const AppLockGate(child: AuthGate()),
        );
      },
    );
  }
}

class ApiFailure {
  final String message;
  final bool isNetworkError;
  ApiFailure(this.message, {this.isNetworkError = false});
}

Widget buildErrorBanner(String message) {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.red.shade50,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.red.shade200),
    ),
    child: Row(
      children: [
        Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(message, style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
        ),
      ],
    ),
  );
}

Widget buildStepIndicator(int currentStep) {
  Widget dot(bool active) => Container(
        width: active ? 28 : 8,
        height: 8,
        decoration: BoxDecoration(
          color: active ? kZetraGreen : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(4),
        ),
      );
  return Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      dot(currentStep == 1),
      const SizedBox(width: 6),
      dot(currentStep == 2),
    ],
  );
}

String formatDisplayDate(String isoDate) {
  final parts = isoDate.split('-');
  if (parts.length != 3) return isoDate;
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final year = parts[0];
  final month = int.tryParse(parts[1]) ?? 1;
  final day = int.tryParse(parts[2]) ?? 1;
  return '$day ${months[month - 1]} $year';
}

// =====================================================================
// OTP helpers — detect verification codes inside message bodies and
// render them as tappable, copyable chips.
// =====================================================================
final RegExp _otpPattern = RegExp(r'\b\d{4,8}\b');

List<String> extractOtpCodes(String text) {
  return _otpPattern.allMatches(text).map((m) => m.group(0)!).toSet().toList();
}

Widget buildOtpChip(BuildContext context, String code) {
  return ActionChip(
    avatar: const Icon(Icons.key_outlined, size: 16, color: kZetraGreenDark),
    label: Text(
      code,
      style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, letterSpacing: 1),
    ),
    backgroundColor: kZetraGreen.withOpacity(0.08),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: BorderSide(color: kZetraGreen.withOpacity(0.2)),
    ),
    onPressed: () {
      Clipboard.setData(ClipboardData(text: code));
      HapticFeedback.lightImpact();
      showZetraToast(context, 'Code $code copied', icon: Icons.check_circle_outline);
    },
  );
}

// =====================================================================
// HOOKY UI HELPERS
//
// Small, reusable pieces used to make the product feel alive: colored
// initials avatars, a consistent "toast" for copy/success actions, a
// message-type badge, and profile-completeness math for the Zetra
// Score gauge on the Home screen.
// =====================================================================

/// A deterministic, pleasant gradient chosen from a name/label so the
/// same person always gets the same avatar color across the app.
List<Color> avatarGradientFor(String seed) {
  const gradients = <List<Color>>[
    [Color(0xFF00B87A), Color(0xFF008751)],
    [Color(0xFF00A8A8), Color(0xFF006B6B)],
    [Color(0xFF4C6EF5), Color(0xFF3B5BDB)],
    [Color(0xFFF59F00), Color(0xFFE67700)],
    [Color(0xFFE64980), Color(0xFFC2255C)],
    [Color(0xFF7048E8), Color(0xFF5F3DC4)],
    [Color(0xFF12B886), Color(0xFF0CA678)],
  ];
  if (seed.isEmpty) return gradients.first;
  final sum = seed.codeUnits.fold<int>(0, (a, b) => a + b);
  return gradients[sum % gradients.length];
}

/// Circular initials avatar used across Zetra ID, the inbox, search
/// results, and the compose screen — gives every identity a face even
/// without real profile photos.
Widget buildAvatar(String label, {double size = 44, IconData? fallbackIcon}) {
  final trimmed = label.trim();
  final initial = trimmed.isNotEmpty ? trimmed[0].toUpperCase() : '?';
  final colors = avatarGradientFor(trimmed);
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
      boxShadow: [
        BoxShadow(color: colors[1].withOpacity(0.35), blurRadius: 8, offset: const Offset(0, 3)),
      ],
    ),
    alignment: Alignment.center,
    child: fallbackIcon != null && trimmed.isEmpty
        ? Icon(fallbackIcon, color: Colors.white, size: size * 0.5)
        : Text(
            initial,
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: size * 0.42),
          ),
  );
}

/// Consistent floating confirmation toast (copy actions, sends, etc.)
/// instead of relying on plain SnackBars everywhere.
void showZetraToast(BuildContext context, String message, {IconData icon = Icons.check_circle_outline}) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
      backgroundColor: kZetraGreenDark,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 2),
    ),
  );
}

/// Small "Seen"/"Delivered" indicator for the Sent tab — reuses the
/// existing `read_at` column (set when the recipient opens the
/// message) so no backend change is required for this hook.
Widget buildSeenIndicator(Map<String, dynamic> message) {
  final seen = message['read_at'] != null;
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        seen ? Icons.done_all : Icons.done,
        size: 15,
        color: seen ? kZetraGreen : Colors.grey.shade500,
      ),
      const SizedBox(width: 4),
      Text(
        seen ? 'Seen' : 'Delivered',
        style: TextStyle(
          fontSize: 12,
          fontWeight: seen ? FontWeight.w600 : FontWeight.normal,
          color: seen ? kZetraGreen : Colors.grey.shade500,
        ),
      ),
    ],
  );
}

/// Profile-completeness ratio (0.0–1.0) that powers the "Zetra Score"
/// gauge on the Home screen — a lightweight, non-punitive nudge to
/// finish setting up the profile.
double profileCompleteness(Map<String, dynamic> user) {
  const optionalFields = ['full_name', 'date_of_birth', 'gender', 'country'];
  int filled = 1; // username / zetra_id are always present
  for (final f in optionalFields) {
    final v = user[f];
    if (v != null && v.toString().trim().isNotEmpty) filled++;
  }
  return filled / (optionalFields.length + 1);
}

String timeOfDayGreeting() {
  final hour = DateTime.now().hour;
  if (hour < 5) return 'Still up';
  if (hour < 12) return 'Good morning';
  if (hour < 17) return 'Good afternoon';
  if (hour < 21) return 'Good evening';
  return 'Good night';
}

// =====================================================================
// AuthGate
// =====================================================================
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _authenticated = false;
  late final StreamSubscription<AuthState> _authSubscription;

  @override
  void initState() {
    super.initState();
    _authenticated = supabase.auth.currentSession != null;
    if (_authenticated) {
      NotificationService.instance.startListening();
    }
    _authSubscription = supabase.auth.onAuthStateChange.listen((data) {
      if (!mounted) return;
      if (data.event == AuthChangeEvent.signedOut) {
        setState(() => _authenticated = false);
        NotificationService.instance.stopListening();
      }
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  void _onAuthenticated() {
    setState(() => _authenticated = true);
    NotificationService.instance.startListening();
  }

  void _onLoggedOut() {
    setState(() => _authenticated = false);
    NotificationService.instance.stopListening();
  }

  @override
  Widget build(BuildContext context) {
    if (!_authenticated) {
      return AuthEntryScreen(onAuthenticated: _onAuthenticated);
    }
    return OnboardingGate(child: RootScreen(onLoggedOut: _onLoggedOut));
  }
}

// =====================================================================
// AuthEntryScreen
// =====================================================================
class AuthEntryScreen extends StatefulWidget {
  final VoidCallback onAuthenticated;
  const AuthEntryScreen({super.key, required this.onAuthenticated});

  @override
  State<AuthEntryScreen> createState() => _AuthEntryScreenState();
}

class _AuthEntryScreenState extends State<AuthEntryScreen> {
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_identifierController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Enter your username or Zetra ID.');
      return;
    }
    if (_passwordController.text.length < 8) {
      setState(() => _errorMessage = 'Password must be at least 8 characters.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final identifier = _identifierController.text.trim();
      final resolvedEmail = await supabase
          .rpc('resolve_login_email', params: {'p_identifier': identifier})
          .timeout(const Duration(seconds: 20)) as String?;

      if (resolvedEmail == null) {
        unawaited(SecurityEventService.instance.logLoginAttempt(identifier, false));
        setState(() => _errorMessage = 'Incorrect login credentials. Please check and try again.');
        return;
      }

      final response = await supabase.auth
          .signInWithPassword(email: resolvedEmail, password: _passwordController.text)
          .timeout(const Duration(seconds: 20));

      if (response.session == null) {
        unawaited(SecurityEventService.instance.logLoginAttempt(identifier, false));
        setState(() => _errorMessage = 'Incorrect login credentials. Please check and try again.');
        return;
      }

      final username = (response.user?.userMetadata?['username'] as String?) ?? '';

      // Fire-and-forget: records this device/login and alerts the user
      // if it's a new device on an account with prior trusted devices.
      // Never awaited into the critical path — a security-signal hiccup
      // must never block a legitimate login.
      unawaited(SecurityEventService.instance.logLoginAttempt(identifier, true));
      unawaited(handlePostAuthSecurityCheck());

      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => WelcomeScreen(username: username, onContinue: widget.onAuthenticated),
        ),
      );
    } on AuthException catch (_) {
      unawaited(SecurityEventService.instance.logLoginAttempt(_identifierController.text.trim(), false));
      setState(() => _errorMessage = 'Incorrect login credentials. Please check and try again.');
    } on PostgrestException catch (_) {
      setState(() => _errorMessage = 'Something went wrong. Please try again.');
    } on SocketException {
      setState(() => _errorMessage = 'No internet connection. Check your network and try again.');
    } on TimeoutException {
      setState(() => _errorMessage = 'Could not reach the server. Please try again.');
    } catch (e) {
      setState(() => _errorMessage = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _goToRegister() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => RegisterScreenOne(onAuthenticated: widget.onAuthenticated)),
    );
  }

  /// Signs in using a passkey already registered for this account (see
  /// SecurityScreen's "Fingerprint sign-in" section, where one gets
  /// created). This is the real, cross-app version — the credential is
  /// recognized by Supabase directly, not just this one app's local
  /// lock screen.
  Future<void> _signInWithPasskey() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authenticator = PasskeyAuthenticator();
      final response = await supabase.auth.signInWithPasskey(authenticator);

      if (response.session == null) {
        setState(() => _errorMessage = 'Could not sign in with fingerprint. Please try again or use your password.');
        return;
      }

      final username = (response.user?.userMetadata?['username'] as String?) ?? '';
      unawaited(SecurityEventService.instance.logLoginAttempt(username.isNotEmpty ? username : 'passkey', true));
      unawaited(handlePostAuthSecurityCheck());

      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => WelcomeScreen(username: username, onContinue: widget.onAuthenticated),
        ),
      );
    } catch (_) {
      setState(() => _errorMessage = 'No fingerprint sign-in set up on this device yet, or it was cancelled.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 48),
              Center(
                child: Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(color: kZetraGreen, borderRadius: BorderRadius.circular(20)),
                  child: const Icon(Icons.badge_outlined, color: Colors.white, size: 44),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Welcome back',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'Log in with your username or Zetra ID',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _identifierController,
                decoration: const InputDecoration(
                  labelText: 'Username or Zetra ID',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (_errorMessage != null) ...[
                buildErrorBanner(_errorMessage!),
                const SizedBox(height: 16),
              ],
              ElevatedButton(
                onPressed: _isLoading ? null : _login,
                child: _isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                      )
                    : const Text('Log In'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _isLoading ? null : _signInWithPasskey,
                icon: const Icon(Icons.fingerprint, color: kZetraGreenDark),
                label: const Text(
                  'Sign in with fingerprint',
                  style: TextStyle(color: kZetraGreenDark, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: kZetraGreen),
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _isLoading ? null : _goToRegister,
                child: const Text(
                  "Don't have a Zetra ID? Create one",
                  style: TextStyle(color: kZetraGreenDark, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// RegisterScreenOne
// =====================================================================
class RegisterScreenOne extends StatefulWidget {
  final VoidCallback onAuthenticated;
  const RegisterScreenOne({super.key, required this.onAuthenticated});

  @override
  State<RegisterScreenOne> createState() => _RegisterScreenOneState();
}

class _RegisterScreenOneState extends State<RegisterScreenOne> {
  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _errorMessage;

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validate() {
    if (_fullNameController.text.trim().isEmpty) {
      return 'Enter your full name.';
    }
    if (_usernameController.text.trim().length < 3) {
      return 'Username must be at least 3 characters.';
    }
    if (_passwordController.text.length < 8) {
      return 'Password must be at least 8 characters.';
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      return 'Passwords do not match.';
    }
    return null;
  }

  void _continue() {
    final error = _validate();
    if (error != null) {
      setState(() => _errorMessage = error);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RegisterScreenTwo(
          fullName: _fullNameController.text.trim(),
          username: _usernameController.text.trim(),
          password: _passwordController.text,
          onAuthenticated: widget.onAuthenticated,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create your Zetra ID')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              buildStepIndicator(1),
              const SizedBox(height: 24),
              const Text('Tell us about you', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text('Step 1 of 2', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
              const SizedBox(height: 28),
              TextField(
                controller: _fullNameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirm,
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (_errorMessage != null) ...[
                buildErrorBanner(_errorMessage!),
                const SizedBox(height: 16),
              ],
              ElevatedButton(onPressed: _continue, child: const Text('Continue')),
            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// RegisterScreenTwo
// =====================================================================
class RegisterScreenTwo extends StatefulWidget {
  final String fullName;
  final String username;
  final String password;
  final VoidCallback onAuthenticated;
  const RegisterScreenTwo({
    super.key,
    required this.fullName,
    required this.username,
    required this.password,
    required this.onAuthenticated,
  });

  @override
  State<RegisterScreenTwo> createState() => _RegisterScreenTwoState();
}

class _RegisterScreenTwoState extends State<RegisterScreenTwo> {
  DateTime? _dateOfBirth;
  String? _gender;
  String? _country = 'Nigeria'; // Zetra's primary market — sensible default, still changeable.
  String? _state;
  bool _isLoading = false;
  String? _errorMessage;

  static const List<String> _genderOptions = ['Male', 'Female', 'Prefer not to say'];

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final initial = _dateOfBirth ?? DateTime(now.year - 18, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 100),
      lastDate: DateTime(now.year - 13, now.month, now.day),
      helpText: 'Select date of birth',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(primary: kZetraGreen),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _dateOfBirth = picked);
  }

  String _formatPickedDate(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  Future<void> _createAccount() async {
    if (_dateOfBirth == null) {
      setState(() => _errorMessage = 'Please select your date of birth.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final internalEmail = await supabase
          .rpc('internal_auth_email', params: {'p_username': widget.username})
          .timeout(const Duration(seconds: 15)) as String;

      final availabilityRaw = await supabase
          .rpc('check_registration_availability', params: {
            'p_username': widget.username,
            'p_email': internalEmail,
            'p_phone': null,
          })
          .timeout(const Duration(seconds: 20));
      final availability = Map<String, dynamic>.from(availabilityRaw as Map);

      if (availability['username_taken'] == true) {
        setState(() => _errorMessage = 'That username is already taken.');
        return;
      }

      final dob =
          '${_dateOfBirth!.year.toString().padLeft(4, '0')}-${_dateOfBirth!.month.toString().padLeft(2, '0')}-${_dateOfBirth!.day.toString().padLeft(2, '0')}';

      final response = await supabase.auth
          .signUp(
            email: internalEmail,
            password: widget.password,
            data: {
              'username': widget.username,
              'full_name': widget.fullName,
              'date_of_birth': dob,
              if (_gender != null) 'gender': _gender,
              if (_country != null) 'country': _country,
              if (_state != null) 'state': _state,
            },
          )
          .timeout(const Duration(seconds: 20));

      if (response.session == null) {
        setState(() => _errorMessage = 'Something went wrong creating your account. Please try again.');
        return;
      }

      unawaited(handlePostAuthSecurityCheck());

      if (!mounted) return;
      await Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => WelcomeScreen(username: widget.username, onContinue: widget.onAuthenticated),
        ),
        (route) => route.isFirst,
      );
    } on AuthException catch (e) {
      setState(() => _errorMessage = e.message.isNotEmpty ? e.message : 'Something went wrong. Please try again.');
    } on PostgrestException catch (_) {
      setState(() => _errorMessage = 'Something went wrong. Please try again.');
    } on SocketException {
      setState(() => _errorMessage = 'No internet connection. Check your network and try again.');
    } on TimeoutException {
      setState(() => _errorMessage = 'Could not reach the server. Please try again.');
    } catch (e) {
      setState(() => _errorMessage = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create your Zetra ID')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              buildStepIndicator(2),
              const SizedBox(height: 24),
              const Text('A few more details', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text('Step 2 of 2', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
              const SizedBox(height: 28),
              InkWell(
                onTap: _pickDateOfBirth,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date of Birth',
                    prefixIcon: Icon(Icons.cake_outlined),
                  ),
                  child: Text(
                    _dateOfBirth == null ? 'Select date' : _formatPickedDate(_dateOfBirth!),
                    style: TextStyle(
                      color: _dateOfBirth == null ? Colors.grey.shade600 : Colors.black87,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _gender,
                decoration: const InputDecoration(
                  labelText: 'Gender (optional)',
                  prefixIcon: Icon(Icons.people_outline),
                ),
                items: _genderOptions.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                onChanged: (v) => setState(() => _gender = v),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _country,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Country (optional)',
                  prefixIcon: Icon(Icons.public_outlined),
                ),
                items: kCountries.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setState(() {
                  _country = v;
                  if (v != 'Nigeria') _state = null; // clear an out-of-scope state selection
                }),
              ),
              if (_country == 'Nigeria') ...[
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: _state,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'State (optional)',
                    prefixIcon: Icon(Icons.map_outlined),
                  ),
                  items: kNigerianStates.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (v) => setState(() => _state = v),
                ),
              ],
              const SizedBox(height: 20),
              if (_errorMessage != null) ...[
                buildErrorBanner(_errorMessage!),
                const SizedBox(height: 16),
              ],
              ElevatedButton(
                onPressed: _isLoading ? null : _createAccount,
                child: _isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                      )
                    : const Text('Create Zetra ID'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// ONBOARDING — a one-time, dismissible feature tour shown the first
// time someone reaches the main app. Purely local (OnboardingService),
// never blocks login, and never re-appears once seen.
// =====================================================================
class OnboardingGate extends StatefulWidget {
  final Widget child;
  const OnboardingGate({super.key, required this.child});

  @override
  State<OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends State<OnboardingGate> {
  bool? _showOnboarding; // null = still checking, don't block first paint

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final seen = await OnboardingService.instance.hasSeenOnboarding();
    if (mounted) setState(() => _showOnboarding = !seen);
  }

  Future<void> _finish() async {
    await OnboardingService.instance.markSeen();
    if (mounted) setState(() => _showOnboarding = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_showOnboarding == true) {
      return OnboardingScreen(onDone: _finish);
    }
    return widget.child;
  }
}

class _OnboardingPageData {
  final IconData icon;
  final String title;
  final String subtitle;
  const _OnboardingPageData({required this.icon, required this.title, required this.subtitle});
}

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onDone;
  const OnboardingScreen({super.key, required this.onDone});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _pages = [
    _OnboardingPageData(
      icon: Icons.badge_outlined,
      title: 'One identity, everywhere',
      subtitle: 'Your Zetra ID works across every Zetra app — NAI, Nigergram, ZTC, and more.',
    ),
    _OnboardingPageData(
      icon: Icons.mail_outline,
      title: 'All your codes in one place',
      subtitle: 'ZetraMail collects verification codes and messages so you never dig through spam.',
    ),
    _OnboardingPageData(
      icon: Icons.reply,
      title: 'Reply, don\u2019t just receive',
      subtitle: 'Message other Zetra ID holders directly and reply right from your inbox.',
    ),
    _OnboardingPageData(
      icon: Icons.local_fire_department,
      title: 'Build your streak',
      subtitle: 'Open Zetra daily to grow your streak and complete your Zetra Score.',
    ),
    _OnboardingPageData(
      icon: Icons.qr_code,
      title: 'Share with a scan',
      subtitle: 'Show your QR code so anyone can add you on Zetra in seconds.',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_page == _pages.length - 1) {
      widget.onDone();
      return;
    }
    _controller.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kZetraGreen,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: TextButton(
                  onPressed: widget.onDone,
                  child: const Text('Skip', style: TextStyle(color: Colors.white70)),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) {
                  final p = _pages[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.14),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(p.icon, color: Colors.white, size: 46),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          p.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          p.subtitle,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.4),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pages.length, (i) {
                final active = i == _page;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active ? Colors.white : Colors.white.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: kZetraGreen),
                  onPressed: _next,
                  child: Text(_page == _pages.length - 1 ? 'Get Started' : 'Next'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// SHARE ZETRA ID — QR code so another person can scan and add you.
// Requires the `qr_flutter` package (see pubspec note).
// =====================================================================
class ShareZetraIdScreen extends StatelessWidget {
  final String zetraId;
  final String username;
  final String zetramail;
  const ShareZetraIdScreen({
    super.key,
    required this.zetraId,
    required this.username,
    required this.zetramail,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Share Zetra ID')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                buildAvatar(username, size: 64),
                const SizedBox(height: 16),
                Text(username, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(zetramail, style: TextStyle(color: Colors.grey.shade600)),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 18, offset: const Offset(0, 6)),
                    ],
                  ),
                  child: QrImageView(
                    data: 'zetraid:$zetraId',
                    version: QrVersions.auto,
                    size: 220,
                    foregroundColor: kZetraGreenDark,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Scan to add me on Zetra',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: zetraId));
                    HapticFeedback.lightImpact();
                    showZetraToast(context, 'Zetra ID copied');
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: kZetraGreen),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.copy_outlined, color: kZetraGreenDark, size: 18),
                  label: Text(zetraId, style: const TextStyle(color: kZetraGreenDark, fontFamily: 'monospace')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class WelcomeScreen extends StatelessWidget {
  final String username;
  final VoidCallback onContinue;
  const WelcomeScreen({super.key, required this.username, required this.onContinue});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kZetraGreen,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 88),
              const SizedBox(height: 24),
              Text(
                username.isNotEmpty ? 'Welcome, $username!' : 'Welcome to Zetra!',
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                'Your Zetra ID is ready. It works across every Zetra app — NAI, Nigergram, ZTC, and more.',
                style: TextStyle(fontSize: 15, color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: kZetraGreen,
                  ),
                  onPressed: () async {
                    final shouldOffer = await AppLockService.instance.shouldOfferBiometricPrompt();
                    if (shouldOffer && context.mounted) {
                      await _offerBiometricSignIn(context);
                    }
                    if (context.mounted) {
                      Navigator.of(context).pop();
                      onContinue();
                    }
                  },
                  child: const Text('Continue'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown once, right after a successful login or registration, on any
/// device with usable biometric hardware. Turning it on reuses the
/// exact same AppLockService/LockScreen already in the app — a PIN is
/// still set as the fallback (matching how Face ID/Touch ID always
/// keep a passcode fallback on iOS and Android), but day-to-day, the
/// first thing the user sees on opening Zetra is their fingerprint or
/// face, not a password field.
Future<void> _offerBiometricSignIn(BuildContext context) async {
  final enable = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Sign in faster next time?'),
      content: const Text(
        'Use your fingerprint or face to unlock Zetra instead of typing your password every time you open the app.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Not now')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Enable')),
      ],
    ),
  );

  await AppLockService.instance.markBiometricPromptShown();

  if (enable != true || !context.mounted) return;

  final pin = await Navigator.of(context).push<String>(
    MaterialPageRoute(builder: (_) => const SetPinScreen()),
  );
  if (pin != null && pin.length >= 4) {
    await AppLockService.instance.setPin(pin);
    await AppLockService.instance.setLockEnabled(true);
  }
}

/// Hosts the bottom navigation: Zetra ID tab and ZetraMail tab.
class RootScreen extends StatefulWidget {
  final VoidCallback onLoggedOut;
  const RootScreen({super.key, required this.onLoggedOut});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  int _tabIndex = 0;
  int _unreadCount = 0;

  void _updateUnreadCount(int count) {
    if (mounted) setState(() => _unreadCount = count);
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(onLoggedOut: widget.onLoggedOut),
      MessagesScreen(onUnreadCountChanged: _updateUnreadCount),
    ];

    return Scaffold(
      body: IndexedStack(index: _tabIndex, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        destinations: [
          const NavigationDestination(icon: Icon(Icons.badge_outlined), label: 'Zetra ID'),
          NavigationDestination(
            icon: Badge(
              label: Text('$_unreadCount'),
              isLabelVisible: _unreadCount > 0,
              child: const Icon(Icons.mail_outline),
            ),
            label: 'ZetraMail',
          ),
        ],
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final VoidCallback onLoggedOut;
  const HomeScreen({super.key, required this.onLoggedOut});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;
  ApiFailure? _failure;
  Map<String, dynamic>? _user;
  int _streak = 0;

  @override
  void initState() {
    super.initState();
    _fetchZetraId();
    _loadStreak();
  }

  Future<void> _loadStreak() async {
    final streak = await StreakService.instance.registerOpenAndGetStreak();
    if (mounted) setState(() => _streak = streak);
  }

  Future<void> _fetchZetraId() async {
    setState(() {
      _isLoading = true;
      _failure = null;
    });

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        await _logout();
        return;
      }

      final data = await supabase
          .from('profiles')
          .select('zetra_id, username, zetramail, full_name, date_of_birth, gender, country, state')
          .eq('id', userId)
          .single()
          .timeout(const Duration(seconds: 20));

      setState(() => _user = Map<String, dynamic>.from(data));
    } on PostgrestException catch (e) {
      final isAuthError = e.code == 'PGRST301' || e.message.toLowerCase().contains('jwt');
      if (isAuthError) {
        await _logout();
        return;
      }
      setState(() => _failure = ApiFailure('Could not load your Zetra ID (${e.code ?? 'error'}).'));
    } on SocketException {
      setState(() => _failure = ApiFailure('No internet connection.', isNetworkError: true));
    } on TimeoutException {
      setState(() => _failure = ApiFailure('The request timed out. Please try again.', isNetworkError: true));
    } catch (e) {
      setState(() => _failure = ApiFailure('Something went wrong. Please try again.'));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    await supabase.auth.signOut();
    widget.onLoggedOut();
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will need to log in again to see your Zetra ID.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _logout();
            },
            child: const Text('Log out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _openTermsAndPrivacy() async {
    final uri = Uri.parse(kTermsAndPrivacyUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Terms & Privacy Policy.')),
      );
    }
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  void _copyToClipboard(String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    HapticFeedback.lightImpact();
    showZetraToast(context, '$label copied');
  }

  Widget _profileHeaderCard() {
    if (_user == null) return const SizedBox.shrink();
    final displayName = (_user!['full_name'] as String?)?.trim().isNotEmpty == true
        ? _user!['full_name'] as String
        : (_user!['username'] as String? ?? 'Zetra User');
    final username = _user!['username'] as String? ?? '';
    final score = profileCompleteness(_user!);
    final scorePercent = (score * 100).round();

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [kZetraGreen, kZetraGreenDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: kZetraGreen.withOpacity(0.3), blurRadius: 14, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              buildAvatar(displayName, size: 52),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${timeOfDayGreeting()}${username.isNotEmpty ? ', $username' : ''} 👋',
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      displayName,
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              if (_streak > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Text('🔥', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 4),
                      Text(
                        '$_streak',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Text(
                'Zetra Score',
                style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Text(
                '$scorePercent%',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: score),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 8,
                backgroundColor: Colors.white.withOpacity(0.2),
                valueColor: const AlwaysStoppedAnimation(Colors.white),
              ),
            ),
          ),
          if (score < 1.0) ...[
            const SizedBox(height: 8),
            Text(
              'Complete your profile to unlock the full Zetra experience.',
              style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _identityCard(String label, String value, IconData icon, {bool copyable = true}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: kZetraGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: kZetraGreen, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
          if (copyable)
            IconButton(
              icon: const Icon(Icons.copy_outlined, size: 20, color: kZetraGreenDark),
              onPressed: () => _copyToClipboard(label, value),
              tooltip: 'Copy $label',
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Zetra ID'),
        actions: [
          if (_user != null)
            IconButton(
              icon: const Icon(Icons.qr_code_outlined),
              tooltip: 'Share Zetra ID',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ShareZetraIdScreen(
                    zetraId: _user!['zetra_id'] as String? ?? '',
                    username: _user!['username'] as String? ?? '',
                    zetramail: _user!['zetramail'] as String? ?? '',
                  ),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: _openSettings,
          ),
          IconButton(
            icon: const Icon(Icons.description_outlined),
            tooltip: 'Terms & Privacy Policy',
            onPressed: _openTermsAndPrivacy,
          ),
          IconButton(icon: const Icon(Icons.logout), onPressed: _confirmLogout, tooltip: 'Log out'),
        ],
      ),
      body: RefreshIndicator(
        color: kZetraGreen,
        onRefresh: _fetchZetraId,
        child: ListView(
          padding: const EdgeInsets.all(20.0),
          children: [
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 60),
                child: Center(child: CircularProgressIndicator(color: kZetraGreen)),
              )
            else if (_failure != null)
              Padding(
                padding: const EdgeInsets.only(top: 60),
                child: Column(
                  children: [
                    Icon(
                      _failure!.isNetworkError ? Icons.wifi_off : Icons.error_outline,
                      size: 48,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 12),
                    Text(_failure!.message, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700)),
                    const SizedBox(height: 16),
                    ElevatedButton(onPressed: _fetchZetraId, child: const Text('Retry')),
                  ],
                ),
              )
            else if (_user != null) ...[
              _profileHeaderCard(),
              _identityCard('Zetra ID', _user!['zetra_id'] ?? '-', Icons.badge_outlined),
              _identityCard('Username', _user!['username'] ?? '-', Icons.person_outline),
              _identityCard('ZetraMail', _user!['zetramail'] ?? '-', Icons.mail_outline),
              _identityCard('Full Name', _user!['full_name'] ?? '-', Icons.badge, copyable: false),
              if (_user!['date_of_birth'] != null)
                _identityCard(
                  'Date of Birth',
                  formatDisplayDate(_user!['date_of_birth'] as String),
                  Icons.cake_outlined,
                  copyable: false,
                ),
              if (_user!['gender'] != null)
                _identityCard('Gender', _user!['gender'], Icons.people_outline, copyable: false),
              if (_user!['country'] != null)
                _identityCard('Country', _user!['country'], Icons.public_outlined, copyable: false),
              if (_user!['state'] != null)
                _identityCard('State', _user!['state'], Icons.map_outlined, copyable: false),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: _openTermsAndPrivacy,
                  child: Text(
                    'Terms & Privacy Policy',
                    style: TextStyle(color: Colors.grey.shade600, decoration: TextDecoration.underline),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// ZetraMail: Inbox, Archived, and Sent — with archiving, deletion
/// (with undo), OTP detection, read tracking, and replies.
class MessagesScreen extends StatefulWidget {
  final void Function(int unreadCount) onUnreadCountChanged;
  const MessagesScreen({super.key, required this.onUnreadCountChanged});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  bool _isLoading = true;
  ApiFailure? _failure;
  List<Map<String, dynamic>> _inbox = [];
  List<Map<String, dynamic>> _archived = [];
  List<Map<String, dynamic>> _sent = [];
  int _tab = 0; // 0 = Inbox, 1 = Archived, 2 = Sent
  String? _appFilter;

  Map<String, dynamic>? _pendingDeleteItem;
  int? _pendingDeleteIndex;
  String _pendingDeleteFrom = 'inbox'; // 'inbox' | 'archived' | 'sent'
  Timer? _pendingDeleteTimer;

  @override
  void initState() {
    super.initState();
    _fetchMessages();
  }

  @override
  void dispose() {
    _pendingDeleteTimer?.cancel();
    _finalizePendingDelete();
    super.dispose();
  }

  Future<void> _fetchMessages() async {
    setState(() {
      _isLoading = true;
      _failure = null;
    });

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        setState(() => _failure = ApiFailure('Your session has expired. Please log in again.'));
        return;
      }

      final inboxData = await supabase
          .from('messages')
          .select('id, from_app, subject, body, code, read_at, created_at, archived_at, sender_zetramail')
          .eq('user_id', userId)
          .filter('deleted_at', 'is', null)
          .filter('archived_at', 'is', null)
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 20));

      final archivedData = await supabase
          .from('messages')
          .select('id, from_app, subject, body, code, read_at, created_at, archived_at, sender_zetramail')
          .eq('user_id', userId)
          .filter('deleted_at', 'is', null)
          .not('archived_at', 'is', null)
          .order('archived_at', ascending: false)
          .timeout(const Duration(seconds: 20));

      final sentData = await supabase
          .from('messages')
          .select('id, from_app, subject, body, code, read_at, created_at, archived_at, sender_zetramail, user_id')
          .eq('sender_id', userId)
          .filter('deleted_at', 'is', null)
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 20));

      final inbox = List<Map<String, dynamic>>.from(inboxData as List);
      final archived = List<Map<String, dynamic>>.from(archivedData as List);
      final sent = List<Map<String, dynamic>>.from(sentData as List);

      // The Sent tab should show who each message was sent *to*, not the
      // sender's own from_app label. This goes through a security-definer
      // RPC rather than reading `profiles` directly — a direct read
      // silently returns nothing for anyone else's row under typical RLS,
      // which is exactly what caused this to only ever work in self-tests.
      final messageIds = sent.map((m) => m['id'] as String).toList();
      if (messageIds.isNotEmpty) {
        try {
          final recipientData = await supabase
              .rpc('get_recipient_usernames', params: {'p_message_ids': messageIds})
              .timeout(const Duration(seconds: 15));
          final recipientMap = <String, Map<String, dynamic>>{
            for (final r in List<Map<String, dynamic>>.from(recipientData as List)) r['message_id'] as String: r,
          };
          for (final m in sent) {
            final r = recipientMap[m['id'] as String];
            m['recipient_username'] = r?['recipient_username'];
            m['recipient_zetramail'] = r?['recipient_zetramail'];
          }
        } catch (_) {
          // Best effort — Sent tab falls back to the from_app label if
          // recipient lookup fails for any reason.
        }

      }

      setState(() {
        _inbox = inbox;
        _archived = archived;
        _sent = sent;
      });

      final unread = inbox.where((m) => m['read_at'] == null).length;
      widget.onUnreadCountChanged(unread);
    } on PostgrestException catch (e) {
      setState(() => _failure = ApiFailure('Could not load ZetraMail (${e.code ?? 'error'}).'));
    } on SocketException {
      setState(() => _failure = ApiFailure('No internet connection.', isNetworkError: true));
    } on TimeoutException {
      setState(() => _failure = ApiFailure('The request timed out. Please try again.', isNetworkError: true));
    } catch (e) {
      setState(() => _failure = ApiFailure('Something went wrong. Please try again.'));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markRead(String id) async {
    try {
      final result = await supabase
          .rpc('mark_message_read', params: {'message_id': id})
          .timeout(const Duration(seconds: 15));

      if (result != null) {
        final updated = Map<String, dynamic>.from(result as Map);
        setState(() {
          final index = _inbox.indexWhere((m) => m['id'] == id);
          if (index != -1) _inbox[index] = updated;
        });
        final unread = _inbox.where((m) => m['read_at'] == null).length;
        widget.onUnreadCountChanged(unread);
      }
    } catch (_) {
      // Silent — marking read is a background nicety.
    }
  }

  Future<void> _markAllRead() async {
    final hasUnread = _inbox.any((m) => m['read_at'] == null);
    if (!hasUnread) return;

    final nowIso = DateTime.now().toUtc().toIso8601String();
    setState(() {
      for (final m in _inbox) {
        if (m['read_at'] == null) m['read_at'] = nowIso;
      }
    });
    widget.onUnreadCountChanged(0);

    try {
      await supabase.rpc('mark_all_messages_read').timeout(const Duration(seconds: 15));
    } catch (_) {
      // Best effort — a manual refresh will resync if this failed.
    }
  }

  void _archiveMessage(Map<String, dynamic> m) {
    setState(() {
      _inbox.remove(m);
      m['archived_at'] = DateTime.now().toUtc().toIso8601String();
      _archived.insert(0, m);
      final unread = _inbox.where((x) => x['read_at'] == null).length;
      widget.onUnreadCountChanged(unread);
    });

    showZetraToast(context, 'Message archived', icon: Icons.archive_outlined);

    _persistArchive(m['id'] as String);
  }

  Future<void> _persistArchive(String id) async {
    try {
      await supabase.rpc('archive_message', params: {'message_id': id}).timeout(const Duration(seconds: 15));
    } catch (_) {
      // Best effort — a manual refresh will resync if this failed.
    }
  }

  void _unarchiveMessage(Map<String, dynamic> m) {
    setState(() {
      _archived.remove(m);
      m['archived_at'] = null;
      _inbox.insert(0, m);
      final unread = _inbox.where((x) => x['read_at'] == null).length;
      widget.onUnreadCountChanged(unread);
    });

    showZetraToast(context, 'Moved back to inbox', icon: Icons.unarchive_outlined);

    _persistUnarchive(m['id'] as String);
  }

  Future<void> _persistUnarchive(String id) async {
    try {
      await supabase.rpc('unarchive_message', params: {'message_id': id}).timeout(const Duration(seconds: 15));
    } catch (_) {
      // Best effort — a manual refresh will resync if this failed.
    }
  }

  void _deleteMessage(Map<String, dynamic> m, {required String from}) {
    final list = from == 'archived' ? _archived : (from == 'sent' ? _sent : _inbox);
    final index = list.indexOf(m);
    if (index == -1) return;

    _pendingDeleteTimer?.cancel();
    _finalizePendingDelete();

    setState(() {
      list.removeAt(index);
      if (from == 'inbox') {
        final unread = _inbox.where((x) => x['read_at'] == null).length;
        widget.onUnreadCountChanged(unread);
      }
    });

    _pendingDeleteItem = m;
    _pendingDeleteIndex = index;
    _pendingDeleteFrom = from;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Message deleted'),
        backgroundColor: Colors.grey.shade900,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'UNDO',
          textColor: Colors.greenAccent,
          onPressed: _undoDelete,
        ),
      ),
    );

    _pendingDeleteTimer = Timer(const Duration(seconds: 4), _finalizePendingDelete);
  }

  void _undoDelete() {
    if (_pendingDeleteItem == null) return;
    _pendingDeleteTimer?.cancel();
    final item = _pendingDeleteItem!;
    final from = _pendingDeleteFrom;
    final index = _pendingDeleteIndex ?? 0;
    _pendingDeleteItem = null;

    final list = from == 'archived' ? _archived : (from == 'sent' ? _sent : _inbox);
    setState(() {
      list.insert(index.clamp(0, list.length), item);
      if (from == 'inbox') {
        final unread = _inbox.where((x) => x['read_at'] == null).length;
        widget.onUnreadCountChanged(unread);
      }
    });
  }

  Future<void> _finalizePendingDelete() async {
    final item = _pendingDeleteItem;
    if (item == null) return;
    _pendingDeleteItem = null;
    _pendingDeleteTimer?.cancel();
    try {
      await supabase
          .rpc('delete_message', params: {'message_id': item['id']})
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      // If this fails, the message reappears on next refresh since it
      // was never actually removed server-side — acceptable fallback.
    }
  }

  String _timeAgo(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final diff = DateTime.now().toUtc().difference(dt.toUtc());
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  void _openSearch() async {
    final sent = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const SearchZetraMailScreen()),
    );
    if (sent == true) {
      _fetchMessages();
    }
  }

  void _openDetail(Map<String, dynamic> m, {required String from}) async {
    if (from == 'inbox' && m['read_at'] == null) {
      _markRead(m['id'] as String);
    }
    final action = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => MessageDetailScreen(message: m, from: from),
      ),
    );
    if (action == 'delete') {
      _deleteMessage(m, from: from);
    } else if (action == 'archive') {
      _archiveMessage(m);
    } else if (action == 'unarchive') {
      _unarchiveMessage(m);
    } else if (action == 'reply') {
      _openReply(m);
    }
  }

  /// Reply from an inbox message. Gated on `sender_zetramail` being
  /// present (see MessageDetailScreen.canReplyTo) rather than parsing
  /// `from_app` text — that parsing was the actual bug behind "can't
  /// reply to messages from a friend."
  void _openReply(Map<String, dynamic> m) {
    if (!MessageDetailScreen.canReplyTo(m)) {
      showZetraToast(context, "This message can't be replied to.", icon: Icons.info_outline);
      return;
    }
    final zetramail = m['sender_zetramail'] as String;
    final username = MessageDetailScreen.senderDisplayName(m);

    final rawSubject = (m['subject'] as String? ?? '').trim();
    final subject = rawSubject.toLowerCase().startsWith('re:') ? rawSubject : 'Re: $rawSubject';

    Navigator.of(context)
        .push<bool>(
          MaterialPageRoute(
            builder: (_) => ComposeMailScreen(
              recipientZetraMail: zetramail,
              recipientUsername: username,
              initialSubject: subject,
            ),
          ),
        )
        .then((sent) {
      if (sent == true) _fetchMessages();
    });
  }

  List<String> get _availableApps {
    final apps = _inbox.map((m) => (m['from_app'] as String? ?? 'zetra')).toSet().toList();
    apps.sort();
    return apps;
  }

  List<Map<String, dynamic>> get _filteredInbox {
    if (_appFilter == null) return _inbox;
    return _inbox.where((m) => (m['from_app'] as String? ?? 'zetra') == _appFilter).toList();
  }

  Widget _filterChips() {
    final apps = _availableApps;
    if (apps.length < 2) return const SizedBox.shrink();
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: const Text('All'),
              selected: _appFilter == null,
              onSelected: (_) => setState(() => _appFilter = null),
              selectedColor: kZetraGreen.withOpacity(0.15),
            ),
          ),
          for (final app in apps)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(app.toUpperCase()),
                selected: _appFilter == app,
                onSelected: (_) => setState(() => _appFilter = app),
                selectedColor: kZetraGreen.withOpacity(0.15),
              ),
            ),
        ],
      ),
    );
  }

  Widget _messageList(List<Map<String, dynamic>> messages, {required String from}) {
    final isInbox = from == 'inbox';
    final isArchived = from == 'archived';
    final isSent = from == 'sent';

    if (messages.isEmpty) {
      final icon = isSent
          ? Icons.outbox_outlined
          : (isArchived ? Icons.archive_outlined : Icons.mail_outline);
      final title = isSent ? 'No sent mail yet' : (isArchived ? 'No archived mail' : 'No mail yet');
      final subtitle = isSent
          ? 'Messages you send will appear here.'
          : (isArchived
              ? 'Swipe right on a message in your inbox to archive it.'
              : 'Tap the search icon to find someone and send a message. Swipe left to delete, right to archive.');

      return ListView(
        children: [
          const SizedBox(height: 100),
          Icon(icon, size: 56, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600, fontSize: 15)),
          const SizedBox(height: 4),
          Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final m = messages[index];
        final isUnread = isInbox && m['read_at'] == null;
        final body = m['body'] as String? ?? '';
        final explicitCode = m['code'] as String?;
        final codes = {
          if (explicitCode != null) explicitCode,
          ...extractOtpCodes(body),
        }.toList();
        final isVerification = codes.isNotEmpty;
        final senderLabel = (m['from_app'] as String? ?? 'zetra');
        final recipientUsername = m['recipient_username'] as String?;
        // Sent tab shows who the message went *to*; every other tab
        // shows who it came from.
        final displayLabel = isSent && recipientUsername != null
            ? 'To: $recipientUsername'
            : senderLabel.toUpperCase();
        final avatarSeed = isSent && recipientUsername != null
            ? recipientUsername
            : (senderLabel.contains(':') ? senderLabel.split(':').last : senderLabel);

        final card = Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(14),
            border: isUnread ? Border.all(color: kZetraGreen.withOpacity(0.4)) : null,
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _openDetail(m, from: from),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    buildAvatar(avatarSeed, size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (isUnread)
                                Container(
                                  width: 8,
                                  height: 8,
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: const BoxDecoration(color: kZetraGreen, shape: BoxShape.circle),
                                ),
                              Expanded(
                                child: Text(
                                  displayLabel,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: kZetraGreenDark,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              if (isVerification)
                                Container(
                                  margin: const EdgeInsets.only(right: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'CODE',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange.shade800,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              Text(
                                _timeAgo(m['created_at'] as String? ?? ''),
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            m['subject'] as String? ?? '',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            body,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                          ),
                          if (isSent) ...[
                            const SizedBox(height: 8),
                            buildSeenIndicator(m),
                          ],
                          if (codes.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: codes.map((c) => buildOtpChip(context, c)).toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        if (isSent) {
          // Sent mail: swipe left to delete only.
          return Dismissible(
            key: ValueKey(m['id']),
            direction: DismissDirection.endToStart,
            background: _swipeBackground(alignRight: true, icon: Icons.delete_outline, color: Colors.red.shade400),
            onDismissed: (_) => _deleteMessage(m, from: from),
            child: card,
          );
        }

        if (isArchived) {
          // Archived: swipe right to unarchive, swipe left to delete forever.
          return Dismissible(
            key: ValueKey(m['id']),
            direction: DismissDirection.horizontal,
            background: _swipeBackground(alignRight: false, icon: Icons.unarchive_outlined, color: kZetraGreen),
            secondaryBackground: _swipeBackground(alignRight: true, icon: Icons.delete_outline, color: Colors.red.shade400),
            onDismissed: (direction) {
              if (direction == DismissDirection.startToEnd) {
                _unarchiveMessage(m);
              } else {
                _deleteMessage(m, from: from);
              }
            },
            child: card,
          );
        }

        // Inbox: swipe right to archive, swipe left to delete.
        return Dismissible(
          key: ValueKey(m['id']),
          direction: DismissDirection.horizontal,
          background: _swipeBackground(alignRight: false, icon: Icons.archive_outlined, color: kZetraGreen),
          secondaryBackground: _swipeBackground(alignRight: true, icon: Icons.delete_outline, color: Colors.red.shade400),
          onDismissed: (direction) {
            if (direction == DismissDirection.startToEnd) {
              _archiveMessage(m);
            } else {
              _deleteMessage(m, from: from);
            }
          },
          child: card,
        );
      },
    );
  }

  Widget _swipeBackground({required bool alignRight, required IconData icon, required Color color}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)),
      alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Icon(icon, color: Colors.white),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _inbox.where((m) => m['read_at'] == null).length;
    final currentFrom = _tab == 0 ? 'inbox' : (_tab == 1 ? 'archived' : 'sent');
    return Scaffold(
      appBar: AppBar(
        title: const Text('ZetraMail'),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(_tab == 0 && _availableApps.length > 1 ? 96 : 48),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ToggleButtons(
                  isSelected: [_tab == 0, _tab == 1, _tab == 2],
                  onPressed: (i) => setState(() => _tab = i),
                  borderRadius: BorderRadius.circular(10),
                  selectedColor: Colors.white,
                  fillColor: Colors.white24,
                  color: Colors.white70,
                  constraints: BoxConstraints(
                    minWidth: (MediaQuery.of(context).size.width - 32) / 3 - 4,
                    minHeight: 36,
                  ),
                  children: const [Text('Inbox'), Text('Archived'), Text('Sent')],
                ),
              ),
              if (_tab == 0) _filterChips(),
              if (_tab == 0) const SizedBox(height: 8),
            ],
          ),
        ),
        actions: [
          if (_tab == 0 && unreadCount > 0)
            IconButton(
              icon: const Icon(Icons.done_all),
              tooltip: 'Mark all as read',
              onPressed: _markAllRead,
            ),
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Find a ZetraMail account',
            onPressed: _openSearch,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: kZetraGreen,
        onPressed: _openSearch,
        tooltip: 'New message',
        child: const Icon(Icons.edit_outlined, color: Colors.white),
      ),
      body: RefreshIndicator(
        color: kZetraGreen,
        onRefresh: _fetchMessages,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: kZetraGreen))
            : _failure != null
                ? ListView(
                    children: [
                      const SizedBox(height: 80),
                      Icon(
                        _failure!.isNetworkError ? Icons.wifi_off : Icons.error_outline,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 12),
                      Text(_failure!.message, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700)),
                      const SizedBox(height: 16),
                      Center(child: ElevatedButton(onPressed: _fetchMessages, child: const Text('Retry'))),
                    ],
                  )
                : (_tab == 0
                    ? _messageList(_filteredInbox, from: 'inbox')
                    : _tab == 1
                        ? _messageList(_archived, from: 'archived')
                        : _messageList(_sent, from: currentFrom)),
      ),
    );
  }
}

/// Full-page message view. Pops with 'delete', 'archive', 'unarchive',
/// or 'reply' depending on which action the user takes.
class MessageDetailScreen extends StatelessWidget {
  final Map<String, dynamic> message;
  final String from; // 'inbox' | 'archived' | 'sent'
  const MessageDetailScreen({super.key, required this.message, required this.from});

  /// Whether this message can be replied to. Deliberately does NOT parse
  /// `from_app` text — that field's exact format for genuine peer-to-peer
  /// messages turned out not to match what was assumed here, which is
  /// why reply silently failed for real messages from other people while
  /// appearing to work in self-testing. `sender_zetramail` is the actual
  /// data used to send the reply, so its presence is the correct signal:
  /// if we have a real return address, replying is meaningful; system/app
  /// senders (OTP codes etc.) never populate this field, so they're
  /// correctly excluded without needing to know their exact naming.
  static bool canReplyTo(Map<String, dynamic> message) {
    final zetramail = message['sender_zetramail'] as String?;
    return zetramail != null && zetramail.trim().isNotEmpty;
  }

  /// Best-effort display name for the sender, used only for the reply
  /// screen's header — derived from their ZetraMail address rather than
  /// the unreliable from_app text.
  static String senderDisplayName(Map<String, dynamic> message) {
    final zetramail = message['sender_zetramail'] as String?;
    if (zetramail != null && zetramail.contains('@')) {
      return zetramail.split('@').first;
    }
    final fromApp = (message['from_app'] as String?) ?? '';
    return fromApp.contains(':') ? fromApp.split(':').last : fromApp;
  }

  String _formatFullDate(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final local = dt.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final period = local.hour < 12 ? 'AM' : 'PM';
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.day} ${months[local.month - 1]} ${local.year} · $hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final body = message['body'] as String? ?? '';
    final explicitCode = message['code'] as String?;
    final codes = {
      if (explicitCode != null) explicitCode,
      ...extractOtpCodes(body),
    }.toList();

    final isInbox = from == 'inbox';
    final isArchived = from == 'archived';
    final isSent = from == 'sent';
    final senderLabel = (message['from_app'] as String? ?? 'zetra');
    final recipientUsername = message['recipient_username'] as String?;
    final displayLabel = isSent && recipientUsername != null
        ? 'To: $recipientUsername'
        : senderLabel.toUpperCase();
    final avatarSeed = isSent && recipientUsername != null
        ? recipientUsername
        : (senderLabel.contains(':') ? senderLabel.split(':').last : senderLabel);
    final canReply = isInbox && canReplyTo(message);

    return Scaffold(
      appBar: AppBar(
        title: Text(displayLabel),
        actions: [
          if (canReply)
            IconButton(
              icon: const Icon(Icons.reply),
              tooltip: 'Reply',
              onPressed: () => Navigator.of(context).pop('reply'),
            ),
          if (isInbox)
            IconButton(
              icon: const Icon(Icons.archive_outlined),
              tooltip: 'Archive',
              onPressed: () => Navigator.of(context).pop('archive'),
            ),
          if (isArchived)
            IconButton(
              icon: const Icon(Icons.unarchive_outlined),
              tooltip: 'Move to inbox',
              onPressed: () => Navigator.of(context).pop('unarchive'),
            ),
          if (!isSent)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete',
              onPressed: () => Navigator.of(context).pop('delete'),
            ),
          if (!isSent)
            IconButton(
              icon: const Icon(Icons.flag_outlined),
              tooltip: 'Report',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ReportScreen(
                    reportType: 'message',
                    targetMessageId: message['id'] as String?,
                    targetUsername: avatarSeed,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildAvatar(avatarSeed, size: 46),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          message['subject'] as String? ?? '',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _formatFullDate(message['created_at'] as String? ?? ''),
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                        ),
                        if (isSent) ...[
                          const SizedBox(height: 6),
                          buildSeenIndicator(message),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (codes.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: kZetraGreen.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: kZetraGreen.withOpacity(0.15)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        codes.length > 1 ? 'Verification codes' : 'Verification code',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: codes.map((c) => buildOtpChip(context, c)).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
              Text(
                body,
                style: const TextStyle(fontSize: 15, height: 1.6),
              ),
              const SizedBox(height: 24),
              if (canReply)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pop('reply'),
                    icon: const Icon(Icons.reply, color: kZetraGreenDark),
                    label: const Text('Reply', style: TextStyle(color: kZetraGreenDark, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: kZetraGreen),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Search other Zetra ID holders by username or ZetraMail address,
/// then tap a result to compose a message to them.
class SearchZetraMailScreen extends StatefulWidget {
  const SearchZetraMailScreen({super.key});

  @override
  State<SearchZetraMailScreen> createState() => _SearchZetraMailScreenState();
}

class _SearchZetraMailScreenState extends State<SearchZetraMailScreen> {
  final _queryController = TextEditingController();
  bool _isLoading = false;
  ApiFailure? _failure;
  List<Map<String, dynamic>> _results = [];
  Timer? _debounce;

  @override
  void dispose() {
    _queryController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(value));
  }

  Future<void> _search(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) {
      setState(() {
        _results = [];
        _failure = null;
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _failure = null;
    });

    try {
      final data = await supabase
          .rpc('search_zetramail', params: {'p_query': trimmed})
          .timeout(const Duration(seconds: 15));
      setState(() => _results = List<Map<String, dynamic>>.from(data as List));
    } on PostgrestException catch (_) {
      setState(() => _failure = ApiFailure('Something went wrong. Please try again.'));
    } on SocketException {
      setState(() => _failure = ApiFailure('No internet connection.', isNetworkError: true));
    } on TimeoutException {
      setState(() => _failure = ApiFailure('The request timed out. Please try again.', isNetworkError: true));
    } catch (e) {
      setState(() => _failure = ApiFailure('Something went wrong. Please try again.'));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openCompose(Map<String, dynamic> account) async {
    final sent = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ComposeMailScreen(
          recipientZetraMail: account['zetramail'] as String,
          recipientUsername: account['username'] as String,
        ),
      ),
    );
    if (sent == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Find a ZetraMail account')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _queryController,
              autofocus: true,
              onChanged: _onQueryChanged,
              decoration: const InputDecoration(
                labelText: 'Search by username or ZetraMail',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: kZetraGreen))
                  : _failure != null
                      ? Center(
                          child: Text(
                            _failure!.message,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                        )
                      : _results.isEmpty
                          ? Center(
                              child: Text(
                                _queryController.text.trim().length < 2
                                    ? 'Type at least 2 characters to search.'
                                    : 'No matching ZetraMail account found.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            )
                          : ListView.separated(
                              itemCount: _results.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final r = _results[index];
                                final displayName = (r['full_name'] as String?) ?? (r['username'] as String? ?? '');

                                return Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).cardColor,
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [
                                      BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
                                    ],
                                  ),
                                  child: ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: buildAvatar(displayName, size: 44),
                                    title: Text(displayName),
                                    subtitle: Text(r['zetramail'] as String? ?? ''),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.flag_outlined, size: 20, color: Colors.grey),
                                          tooltip: 'Report',
                                          onPressed: () => Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) => ReportScreen(
                                                reportType: 'user',
                                                targetUsername: r['username'] as String?,
                                                targetZetramail: r['zetramail'] as String?,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const Icon(Icons.chevron_right, color: kZetraGreenDark),
                                      ],
                                    ),
                                    onTap: () => _openCompose(r),
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compose and send a ZetraMail message to another Zetra ID holder.
/// `initialSubject` is used to pre-fill "Re: ..." when opened via the
/// Reply action on a message detail screen.
class ComposeMailScreen extends StatefulWidget {
  final String recipientZetraMail;
  final String recipientUsername;
  final String? initialSubject;
  const ComposeMailScreen({
    super.key,
    required this.recipientZetraMail,
    required this.recipientUsername,
    this.initialSubject,
  });

  @override
  State<ComposeMailScreen> createState() => _ComposeMailScreenState();
}

class _ComposeMailScreenState extends State<ComposeMailScreen> {
  final _subjectController = TextEditingController();
  final _bodyController = TextEditingController();
  bool _isSending = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.initialSubject != null && widget.initialSubject!.trim().isNotEmpty) {
      _subjectController.text = widget.initialSubject!;
    }
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final subject = _subjectController.text.trim();
    final body = _bodyController.text.trim();

    if (subject.isEmpty) {
      setState(() => _errorMessage = 'Enter a subject.');
      return;
    }
    if (body.isEmpty) {
      setState(() => _errorMessage = 'Enter a message.');
      return;
    }

    setState(() {
      _isSending = true;
      _errorMessage = null;
    });

    try {
      await supabase.rpc('send_zetramail', params: {
        'p_recipient_zetramail': widget.recipientZetraMail,
        'p_subject': subject,
        'p_body': body,
      }).timeout(const Duration(seconds: 20));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sent to ${widget.recipientUsername}'),
          backgroundColor: kZetraGreenDark,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop(true);
    } on PostgrestException catch (e) {
      setState(() => _errorMessage = e.message.isNotEmpty ? e.message : 'Could not send this message. Please try again.');
    } on SocketException {
      setState(() => _errorMessage = 'No internet connection. Check your network and try again.');
    } on TimeoutException {
      setState(() => _errorMessage = 'Could not reach the server. Please try again.');
    } catch (e) {
      setState(() => _errorMessage = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isReply = widget.initialSubject != null && widget.initialSubject!.trim().isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: Text(isReply ? 'Reply' : 'New Message')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: kZetraGreen.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    buildAvatar(widget.recipientUsername, size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.recipientUsername, style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text(widget.recipientZetraMail, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _subjectController,
                decoration: const InputDecoration(labelText: 'Subject', prefixIcon: Icon(Icons.subject)),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _bodyController,
                maxLines: 6,
                autofocus: isReply,
                decoration: const InputDecoration(
                  labelText: 'Message',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.message_outlined),
                ),
              ),
              const SizedBox(height: 20),
              if (_errorMessage != null) ...[
                buildErrorBanner(_errorMessage!),
                const SizedBox(height: 16),
              ],
              ElevatedButton(
                onPressed: _isSending ? null : _send,
                child: _isSending
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                      )
                    : Text(isReply ? 'Send Reply' : 'Send'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
