import 'package:flutter/material.dart';

import 'main.dart' show supabase, kZetraGreen, buildErrorBanner, showZetraToast;
import 'security_features.dart' show DeviceIdentityService;

// =====================================================================
// REPORTING — lets a user flag a scam/spam/abusive message or account.
// Reports are write-only from the client (see reports_migration.sql):
// once submitted, nobody — not even the reporter — can read them back
// through the app. That's deliberate: it protects reporters and keeps
// this a one-way channel into your review process, not a public log.
//
// Getting these into coderinnovator@gmail.com requires one dashboard
// step outside the app — see reports_notifications.md — the same
// Database Webhook pattern already used for security alerts.
// =====================================================================

class _ReportReason {
  final String code;
  final String label;
  const _ReportReason(this.code, this.label);
}

const List<_ReportReason> _kReportReasons = [
  _ReportReason('SCAM_PHISHING', 'Scam or phishing'),
  _ReportReason('HARASSMENT', 'Harassment or abuse'),
  _ReportReason('SPAM', 'Spam'),
  _ReportReason('OTHER', 'Something else'),
];

class ReportScreen extends StatefulWidget {
  /// 'message' or 'user'.
  final String reportType;
  final String? targetMessageId;
  final String? targetUsername;
  final String? targetZetramail;

  const ReportScreen({
    super.key,
    required this.reportType,
    this.targetMessageId,
    this.targetUsername,
    this.targetZetramail,
  });

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  String? _reason;
  final _detailsController = TextEditingController();
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_reason == null) {
      setState(() => _error = 'Choose a reason for this report.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        setState(() => _error = 'Your session has expired. Please log in again.');
        return;
      }

      final deviceId = await DeviceIdentityService.instance.getOrCreateInstallationId();

      await supabase.from('reports').insert({
        'reporter_id': userId,
        'report_type': widget.reportType,
        'target_message_id': widget.targetMessageId,
        'target_username': widget.targetUsername,
        'target_zetramail': widget.targetZetramail,
        'reason': _reason,
        'details': _detailsController.text.trim().isEmpty ? null : _detailsController.text.trim(),
        'device_id': deviceId,
      }).timeout(const Duration(seconds: 20));

      if (mounted) {
        showZetraToast(context, 'Report submitted — thank you');
        Navigator.of(context).pop(true);
      }
    } catch (_) {
      setState(() => _error = 'Could not submit your report. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final targetLabel = widget.reportType == 'message'
        ? 'this message'
        : (widget.targetUsername ?? 'this account');

    return Scaffold(
      appBar: AppBar(title: const Text('Report')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Report $targetLabel',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'This is reviewed by our team — it\'s not visible to the account you\'re reporting.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              const SizedBox(height: 20),
              ..._kReportReasons.map(
                (r) => RadioListTile<String>(
                  value: r.code,
                  groupValue: _reason,
                  onChanged: (v) => setState(() => _reason = v),
                  title: Text(r.label),
                  activeColor: kZetraGreen,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _detailsController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Additional details (optional)',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 20),
              if (_error != null) ...[
                buildErrorBanner(_error!),
                const SizedBox(height: 16),
              ],
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                      )
                    : const Text('Submit Report'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
