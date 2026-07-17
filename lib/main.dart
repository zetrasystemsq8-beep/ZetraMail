import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// =====================================================================
// Supabase project configuration.
// Replace with your project's values from Project Settings -> API.
// The anon key is safe to ship in a client app — it has no privileges
// beyond what RLS policies grant it.
// =====================================================================
const String kSupabaseUrl = 'https://ssmwuihkafrulmvtiuam.supabase.co';
const String kSupabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNzbXd1aWhrYWZydWxtdnRpdWFtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA4Mjk2NjAsImV4cCI6MjA5NjQwNTY2MH0.e1PxmDW77ZhbonS-Z96SWA_sPyVGedzpZNZbJQz7pQo';

const Color kZetraGreen = Color(0xFF008751);
const Color kZetraGreenDark = Color(0xFF00623B);

SupabaseClient get supabase => Supabase.instance.client;

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

// =====================================================================
// AuthGate
//
// On cold start, trusts Supabase's own persisted session (it restores
// this itself before Supabase.initialize() returns) to decide whether
// to show AuthScreen or RootScreen — no WelcomeScreen on a returning
// user, same as the original SharedPreferences-token check.
//
// After a fresh sign-up/sign-in, the session becomes non-null
// immediately, but _authenticated is intentionally NOT flipped by the
// auth-state stream at that moment — AuthScreen pushes WelcomeScreen
// first, and only calls onAuthenticated() when the user taps
// "Continue", exactly matching the original UX. The stream is used
// only to catch involuntary sign-outs (expired/revoked session),
// which immediately bounce the user back to AuthScreen.
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
      return AuthScreen(onAuthenticated: _onAuthenticated);
    }
    return RootScreen(onLoggedOut: _onLoggedOut);
  }
}

class AuthScreen extends StatefulWidget {
  final VoidCallback onAuthenticated;
  const AuthScreen({super.key, required this.onAuthenticated});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isRegisterMode = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _identifierController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _identifierController.dispose();
    super.dispose();
  }

  String? _validate() {
    if (_isRegisterMode) {
      if (_usernameController.text.trim().length < 3) {
        return 'Username must be at least 3 characters.';
      }
      if (!_emailController.text.contains('@')) {
        return 'Enter a valid email address.';
      }
    } else {
      if (_identifierController.text.trim().isEmpty) {
        return 'Enter your Zetra ID, username, ZetraMail, phone, or email.';
      }
    }
    if (_passwordController.text.length < 8) {
      return 'Password must be at least 8 characters.';
    }
    return null;
  }

  Future<void> _submit() async {
    final validationError = _validate();
    if (validationError != null) {
      setState(() => _errorMessage = validationError);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_isRegisterMode) {
        await _submitRegister();
      } else {
        await _submitLogin();
      }
    } on AuthException catch (e) {
      setState(() {
        _errorMessage = _isRegisterMode
            ? (e.message.isNotEmpty ? e.message : 'Something went wrong. Please try again.')
            : 'Incorrect login credentials. Please check and try again.';
      });
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

  Future<void> _submitRegister() async {
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;

    final availabilityRaw = await supabase
        .rpc('check_registration_availability', params: {
          'p_username': username,
          'p_email': email,
          'p_phone': phone.isEmpty ? null : phone,
        })
        .timeout(const Duration(seconds: 20));

    final availability = Map<String, dynamic>.from(availabilityRaw as Map);

    if (availability['username_taken'] == true) {
      setState(() => _errorMessage = 'That username is already taken.');
      return;
    }
    if (availability['email_taken'] == true) {
      setState(() => _errorMessage = 'That email is already registered.');
      return;
    }
    if (availability['phone_taken'] == true) {
      setState(() => _errorMessage = 'That phone number is already registered.');
      return;
    }

    final response = await supabase.auth
        .signUp(
          email: email,
          password: password,
          data: {
            'username': username,
            if (phone.isNotEmpty) 'phone': phone,
          },
        )
        .timeout(const Duration(seconds: 20));

    if (response.session == null) {
      setState(() => _errorMessage = 'Check your email to confirm your account, then log in.');
      return;
    }

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WelcomeScreen(
          username: username,
          onContinue: widget.onAuthenticated,
        ),
      ),
    );
  }

  Future<void> _submitLogin() async {
    final identifier = _identifierController.text.trim();
    final password = _passwordController.text;

    final resolvedEmail = await supabase
        .rpc('resolve_login_email', params: {'p_identifier': identifier})
        .timeout(const Duration(seconds: 20)) as String?;

    if (resolvedEmail == null) {
      setState(() => _errorMessage = 'Incorrect login credentials. Please check and try again.');
      return;
    }

    final response = await supabase.auth
        .signInWithPassword(email: resolvedEmail, password: password)
        .timeout(const Duration(seconds: 20));

    if (response.session == null) {
      setState(() => _errorMessage = 'Incorrect login credentials. Please check and try again.');
      return;
    }

    final username = (response.user?.userMetadata?['username'] as String?) ?? '';

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WelcomeScreen(
          username: username,
          onContinue: widget.onAuthenticated,
        ),
      ),
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
              const SizedBox(height: 32),
              Center(
                child: Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: kZetraGreen,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.badge_outlined, color: Colors.white, size: 44),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _isRegisterMode ? 'Create your Zetra ID' : 'Welcome back',
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                _isRegisterMode
                    ? 'One identity for every Zetra app'
                    : 'Log in with your Zetra ID, username, ZetraMail, phone, or email',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              if (_isRegisterMode) ...[
                TextField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.mail_outline),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone (optional)',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
              ] else ...[
                TextField(
                  controller: _identifierController,
                  decoration: const InputDecoration(
                    labelText: 'Zetra ID / username / ZetraMail / phone / email',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
              ],
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
                Container(
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
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                child: _isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                      )
                    : Text(_isRegisterMode ? 'Create Zetra ID' : 'Log In'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _isLoading
                    ? null
                    : () => setState(() {
                          _isRegisterMode = !_isRegisterMode;
                          _errorMessage = null;
                        }),
                child: Text(
                  _isRegisterMode
                      ? 'Already have a Zetra ID? Log in'
                      : "Don't have a Zetra ID? Create one",
                  style: const TextStyle(color: kZetraGreenDark, fontWeight: FontWeight.w600),
                ),
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
          .select('zetra_id, username, zetramail, email, phone')
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

  Widget _identityCard(String label, String value, IconData icon) {
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
              _identityCard('Email', _user!['email'] ?? '-', Icons.alternate_email),
              if (_user!['phone'] != null)
                _identityCard('Phone', _user!['phone'], Icons.phone_outlined),
            ],
          ],
        ),
      ),
    );
  }
}

/// ZetraMail inbox: verification codes and messages sent from
/// other Zetra apps and from Zetra itself.
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ZetraMail')),
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
                            'Verification codes from other Zetra apps will appear here.',
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
