import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// =====================================================================
// Supabase project configuration.
// Replace with your project's values from Project Settings -> API.
// =====================================================================
const String kSupabaseUrl = 'https://ssmwuihkafrulmvtiuam.supabase.co';
const String kSupabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNzbXd1aWhrYWZydWxtdnRpdWFtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA4Mjk2NjAsImV4cCI6MjA5NjQwNTY2MH0.e1PxmDW77ZhbonS-Z96SWA_sPyVGedzpZNZbJQz7pQo';

const Color kZetraGreen = Color(0xFF008751);
const Color kZetraGreenDark = Color(0xFF00623B);

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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: kSupabaseUrl,
    anonKey: kSupabaseAnonKey,
  );
  runApp(const ZetraIdApp());
}

class ZetraIdApp extends StatelessWidget {
  const ZetraIdApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zetra ID',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: kZetraGreen,
          primary: kZetraGreen,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF6FBF8),
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
      ),
      home: const AuthGate(),
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
// AuthGate
//
// On cold start, trusts Supabase's own persisted session to decide
// whether to show AuthEntryScreen or RootScreen. After a fresh
// sign-up/sign-in, _authenticated is intentionally NOT flipped by the
// auth-state stream immediately — WelcomeScreen is shown first, and
// only calling onAuthenticated() (via its "Continue" button) switches
// to RootScreen. The stream is used only to catch involuntary
// sign-outs (expired/revoked session), which bounce the user back to
// AuthEntryScreen.
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
    _authSubscription = supabase.auth.onAuthStateChange.listen((data) {
      if (!mounted) return;
      if (data.event == AuthChangeEvent.signedOut) {
        setState(() => _authenticated = false);
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
  }

  void _onLoggedOut() {
    setState(() => _authenticated = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_authenticated) {
      return AuthEntryScreen(onAuthenticated: _onAuthenticated);
    }
    return RootScreen(onLoggedOut: _onLoggedOut);
  }
}

// =====================================================================
// AuthEntryScreen — login with username or Zetra ID, or go to signup.
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
        setState(() => _errorMessage = 'Incorrect login credentials. Please check and try again.');
        return;
      }

      final response = await supabase.auth
          .signInWithPassword(email: resolvedEmail, password: _passwordController.text)
          .timeout(const Duration(seconds: 20));

      if (response.session == null) {
        setState(() => _errorMessage = 'Incorrect login credentials. Please check and try again.');
        return;
      }

      final username = (response.user?.userMetadata?['username'] as String?) ?? '';

      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => WelcomeScreen(username: username, onContinue: widget.onAuthenticated),
        ),
      );
    } on AuthException catch (_) {
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
// RegisterScreenOne — full name, username, password, confirm password.
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
// RegisterScreenTwo — date of birth, gender, country, then creation.
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
  String? _country;
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
            },
          )
          .timeout(const Duration(seconds: 20));

      if (response.session == null) {
        setState(() => _errorMessage = 'Something went wrong creating your account. Please try again.');
        return;
      }

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
                onChanged: (v) => setState(() => _country = v),
              ),
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
                  onPressed: () {
                    Navigator.of(context).pop();
                    onContinue();
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

  @override
  void initState() {
    super.initState();
    _fetchZetraId();
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
          .select('zetra_id, username, zetramail, full_name, date_of_birth, gender, country')
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

  void _copyToClipboard(String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied'),
        backgroundColor: kZetraGreenDark,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _identityCard(String label, String value, IconData icon, {bool copyable = true}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
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
            ],
          ],
        ),
      ),
    );
  }
}

/// ZetraMail inbox: verification codes and messages sent from
/// other Zetra apps, from Zetra itself, and from other users.
class MessagesScreen extends StatefulWidget {
  final void Function(int unreadCount) onUnreadCountChanged;
  const MessagesScreen({super.key, required this.onUnreadCountChanged});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  bool _isLoading = true;
  ApiFailure? _failure;
  List<Map<String, dynamic>> _messages = [];

  @override
  void initState() {
    super.initState();
    _fetchMessages();
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

      final data = await supabase
          .from('messages')
          .select('id, from_app, subject, body, code, read_at, created_at')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 20));

      final messages = List<Map<String, dynamic>>.from(data as List);
      setState(() => _messages = messages);
      final unread = messages.where((m) => m['read_at'] == null).length;
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

  Future<void> _markRead(String id, int index) async {
    try {
      final result = await supabase
          .rpc('mark_message_read', params: {'message_id': id})
          .timeout(const Duration(seconds: 15));

      if (result != null) {
        setState(() => _messages[index] = Map<String, dynamic>.from(result as Map));
        final unread = _messages.where((m) => m['read_at'] == null).length;
        widget.onUnreadCountChanged(unread);
      }
    } catch (_) {
      // Silent — marking read is a background nicety, not worth
      // interrupting the user with an error for.
    }
  }

  void _copyCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Code copied'),
        backgroundColor: kZetraGreenDark,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ZetraMail'),
        actions: [
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
                : _messages.isEmpty
                    ? ListView(
                        children: [
                          const SizedBox(height: 100),
                          Icon(Icons.mail_outline, size: 56, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            'No mail yet',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tap the search icon to find someone and send a message.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final m = _messages[index];
                          final isUnread = m['read_at'] == null;
                          final code = m['code'] as String?;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: isUnread ? Border.all(color: kZetraGreen.withOpacity(0.4)) : null,
                              boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
                              ],
                            ),
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
                                        (m['from_app'] as String? ?? 'zetra').toUpperCase(),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: kZetraGreenDark,
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
                                  m['body'] as String? ?? '',
                                  style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                                ),
                                if (code != null) ...[
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: kZetraGreen.withOpacity(0.08),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          code,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'monospace',
                                            letterSpacing: 2,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(Icons.copy_outlined, size: 20, color: kZetraGreenDark),
                                        onPressed: () => _copyCode(code),
                                        tooltip: 'Copy code',
                                      ),
                                    ],
                                  ),
                                ],
                                if (isUnread) ...[
                                  const SizedBox(height: 8),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: () => _markRead(m['id'] as String, index),
                                      child: const Text('Mark as read'),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
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
                                final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

                                return Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [
                                      BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
                                    ],
                                  ),
                                  child: ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: CircleAvatar(
                                      backgroundColor: kZetraGreen.withOpacity(0.1),
                                      child: Text(
                                        initial,
                                        style: const TextStyle(color: kZetraGreenDark, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    title: Text(displayName),
                                    subtitle: Text(r['zetramail'] as String? ?? ''),
                                    trailing: const Icon(Icons.chevron_right, color: kZetraGreenDark),
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
class ComposeMailScreen extends StatefulWidget {
  final String recipientZetraMail;
  final String recipientUsername;
  const ComposeMailScreen({
    super.key,
    required this.recipientZetraMail,
    required this.recipientUsername,
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
    return Scaffold(
      appBar: AppBar(title: const Text('New Message')),
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
                    const Icon(Icons.person, color: kZetraGreenDark),
                    const SizedBox(width: 10),
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
                    : const Text('Send'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
