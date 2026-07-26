import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/lattice_background.dart';
import '../../providers/app_state.dart';
import 'insurance_incident_sheet.dart';

class SafetyReportSheet extends StatefulWidget {
  const SafetyReportSheet({
    super.key,
    this.reportedMemberId,
    this.reportedMemberName,
  });

  final String? reportedMemberId;
  final String? reportedMemberName;

  static Future<void> show(
    BuildContext context, {
    String? reportedMemberId,
    String? reportedMemberName,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SafetyReportSheet(
        reportedMemberId: reportedMemberId,
        reportedMemberName: reportedMemberName,
      ),
    );
  }

  @override
  State<SafetyReportSheet> createState() => _SafetyReportSheetState();
}

class _SafetyReportSheetState extends State<SafetyReportSheet> {
  final _details = TextEditingController();
  String _category = 'harassment';
  bool _busy = false;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    final error = await context.read<AppState>().submitSafetyReport(
      category: _category,
      description: _details.text,
      reportedMemberId: widget.reportedMemberId,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? 'Report submitted to staff.')),
    );
    if (error == null) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final title = widget.reportedMemberName == null
        ? 'Safety Report'
        : 'Report ${widget.reportedMemberName}';

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
        child: LuxuryCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Text(
                'Reports are private and do not alert the other member.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: const [
                  DropdownMenuItem(
                    value: 'harassment',
                    child: Text('Harassment'),
                  ),
                  DropdownMenuItem(
                    value: 'suspicious',
                    child: Text('Suspicious behavior'),
                  ),
                  DropdownMenuItem(
                    value: 'unsafe_ride',
                    child: Text('Unsafe ride'),
                  ),
                  DropdownMenuItem(
                    value: 'medical',
                    child: Text('Medical incident'),
                  ),
                  DropdownMenuItem(
                    value: 'other',
                    child: Text('Other concern'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _category = value);
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _details,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Details for staff',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              TigerButton(
                label: _busy ? 'SENDING...' : 'SUBMIT REPORT',
                icon: Icons.report,
                onPressed: _busy ? null : _submit,
              ),
              const SizedBox(height: 8),
              TigerButton(
                label: 'START INSURANCE PACKAGE',
                icon: Icons.health_and_safety,
                secondary: true,
                onPressed: () => InsuranceIncidentSheet.show(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
