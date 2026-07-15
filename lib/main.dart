import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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
        primarySwatch: Colors.blue,
      ),
      home: const ZetraIdScreen(),
    );
  }
}

class ZetraIdScreen extends StatefulWidget {
  const ZetraIdScreen({super.key});

  @override
  State<ZetraIdScreen> createState() => _ZetraIdScreenState();
}

class _ZetraIdScreenState extends State<ZetraIdScreen> {
  String _zetraId = '';
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _generateZetraId() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _zetraId = '';
    });

    try {
      final response = await http.post(
        Uri.parse('https://zetra-backend.onrender.com/api/identity/create'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': 'user'}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        setState(() {
          _zetraId = data['zetra_id'] ?? 'No ID found in response';
        });
      } else {
        setState(() {
          _errorMessage = 'Error: ${response.statusCode}\n${response.body}';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to connect to the backend: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Zetra ID'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Zetra ID',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _generateZetraId,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Generate Zetra ID'),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                _zetraId.isNotEmpty ? _zetraId : 'No ID generated yet',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontFamily: 'monospace'),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 20),
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
