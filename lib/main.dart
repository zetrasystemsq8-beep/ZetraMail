import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

const String kApiBase = 'https://zetra-backend.onrender.com/api';

void main() {
  runApp(const ZetraIdApp());
}

class ZetraIdApp extends StatelessWidget {
  const ZetraIdApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zetra ID',
      theme: ThemeData(
        primarySwatch: Colors.green,
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

/// Decides whether to show the login/register screen or the home
/// screen, based on whether a token is already stored.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _checking = true;
  String? _token;

  @override
  void initState() {
    super.initState();
    _loadToken();
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _token = prefs.getString('access_token');
      _checking = false;
    });
  }

  void _onAuthenticated(String token) {
    setState(() => _token = token);
  }

  void _onLoggedOut() {
    setState(() => _token = null);
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_token == null) {
      return AuthScreen(onAuthenticated: _onAuthenticated);
    }
    return HomeScreen(token: _token!, onLoggedOut: _onLoggedOut);
  }
}

/// Combined Register / Login screen.
class AuthScreen extends StatefulWidget {
  final void Function(String token) onAuthenticated;
  const AuthScreen({super.key, required this.onAuthenticated});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isRegisterMode = true;
  bool _isLoading = false;
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

  Future<void> _submit() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final uri = Uri.parse(
        _isRegisterMode ? '$kApiBase/auth/register' : '$kApiBase/auth/login',
      );

      final Map<String, dynamic> body = _isRegisterMode
          ? {
              'username': _usernameController.text.trim(),
              'email': _emailController.text.trim(),
              'password': _passwordController.text,
              if (_phoneController.text.trim().isNotEmpty)
                'phone': _phoneController.text.trim(),
            }
          : {
              'identifier': _identifierController.text.trim(),
              'password': _passwordController.text,
            };

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final accessToken = data['access_token'] as String?;
        final refreshToken = data['refresh_token'] as String?;

        if (accessToken == null) {
          setState(() {
            _errorMessage = 'No access token in response.';
          });
          return;
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', accessToken);
        if (refreshToken != null) {
          await prefs.setString('refresh_token', refreshToken);
        }

        widget.onAuthenticated(accessToken);
      } else {
        String message = 'Error: ${response.statusCode}';
        try {
          final data = jsonDecode(response.body);
          if (data['error'] != null) message = data['error'].toString();
        } catch (_) {}
        setState(() => _errorMessage = message);
      }
    } catch (e) {
      setState(() => _errorMessage = 'Failed to connect to the backend: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Zetra ID')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            Text(
              _isRegisterMode ? 'Create your Zetra ID' : 'Log in to Zetra',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (_isRegisterMode) ...[
              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ] else ...[
              TextField(
                controller: _identifierController,
                decoration: const InputDecoration(
                  labelText: 'Zetra ID, username, ZetraMail, phone, or email',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(_isRegisterMode ? 'Register' : 'Log In'),
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
                    ? 'Already have an account? Log in'
                    : "Don't have an account? Register",
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shows the logged-in user's Zetra ID and related identifiers.
class HomeScreen extends StatefulWidget {
  final String token;
  final VoidCallback onLoggedOut;
  const HomeScreen({super.key, required this.token, required this.onLoggedOut});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _user;

  @override
  void initState() {
    super.initState();
    _fetchZetraId();
  }

  Future<void> _fetchZetraId() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http.get(
        Uri.parse('$kApiBase/users/me/zetra-id'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );

      if (response.statusCode == 200) {
        setState(() => _user = jsonDecode(response.body));
      } else if (response.statusCode == 401) {
        await _logout();
      } else {
        setState(() => _errorMessage = 'Error: ${response.statusCode}\n${response.body}');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Failed to connect to the backend: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    widget.onLoggedOut();
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: SelectableText(value, style: const TextStyle(fontFamily: 'monospace')),
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
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Log out',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchZetraId,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            const SizedBox(height: 12),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_errorMessage != null)
              Column(
                children: [
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(onPressed: _fetchZetraId, child: const Text('Retry')),
                ],
              )
            else if (_user != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _infoRow('Zetra ID', _user!['zetra_id'] ?? '-'),
                    _infoRow('Username', _user!['username'] ?? '-'),
                    _infoRow('ZetraMail', _user!['zetramail'] ?? '-'),
                    _infoRow('Email', _user!['email'] ?? '-'),
                    if (_user!['phone'] != null) _infoRow('Phone', _user!['phone']),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
