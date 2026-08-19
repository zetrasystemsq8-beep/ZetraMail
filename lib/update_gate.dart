// update_gate.dart
// Checks Supabase zetraid_config table on launch. Blocks the whole app
// with a full-screen "Update Required" page if this build is below the
// minimum supported version. Fails open — any network/Supabase error
// just lets the app continue normally.
//
// USAGE IN main.dart:
//   1. import 'update_gate.dart';
//   2. Wrap your root widget:
//        runApp(const UpdateGate(child: ZetraIdApp()));
//   3. Add these two dependencies to pubspec.yaml if not already present:
//        package_info_plus: ^8.0.0
//        url_launcher: ^6.3.1   (already present in Zetra ID)

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateGate extends StatefulWidget {
  final Widget child;
  const UpdateGate({Key? key, required this.child}) : super(key: key);

  @override
  State<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends State<UpdateGate> {
  bool _loading = true;
  bool _blocked = false;
  String _message = '';
  String _apkUrl = '';

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final row = await Supabase.instance.client
          .from('zetraid_config')
          .select()
          .eq('id', 1)
          .maybeSingle()
          .timeout(const Duration(seconds: 8));

      if (row == null) {
        setState(() => _loading = false);
        return;
      }

      final minVersion = row['min_supported_version'] as String? ?? '0.0.0';
      final apkUrl = row['apk_url'] as String? ?? '';
      final message = row['update_message'] as String? ??
          'A new version of Zetra ID is required to continue.';

      final isBehind = _isOlder(currentVersion, minVersion);

      setState(() {
        _loading = false;
        _blocked = isBehind;
        _message = message;
        _apkUrl = apkUrl;
      });
    } catch (e) {
      // Never block the app if the check itself fails (offline, etc).
      setState(() => _loading = false);
    }
  }

  bool _isOlder(String current, String minimum) {
    final c = current.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final m = minimum.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final len = c.length > m.length ? c.length : m.length;
    for (var i = 0; i < len; i++) {
      final cv = i < c.length ? c[i] : 0;
      final mv = i < m.length ? m[i] : 0;
      if (cv != mv) return cv < mv;
    }
    return false;
  }

  Future<void> _openDownload() async {
    if (_apkUrl.isEmpty) return;
    final uri = Uri.tryParse(_apkUrl);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_blocked) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: WillPopScope(
          onWillPop: () async => false,
          child: Scaffold(
            backgroundColor: const Color(0xFF008751),
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.system_update, color: Colors.white, size: 72),
                    const SizedBox(height: 24),
                    const Text(
                      'Update Required',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _message,
                      style: const TextStyle(color: Colors.white70, fontSize: 15),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF008751),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: _openDownload,
                        child: const Text('Update Zetra ID'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return widget.child;
  }
}
