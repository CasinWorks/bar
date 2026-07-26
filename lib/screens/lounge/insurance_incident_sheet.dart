import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/lattice_background.dart';
import '../../providers/app_state.dart';

class InsuranceIncidentSheet extends StatefulWidget {
  const InsuranceIncidentSheet({super.key, this.reportId});

  final String? reportId;

  static Future<void> show(BuildContext context, {String? reportId}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => InsuranceIncidentSheet(reportId: reportId),
    );
  }

  @override
  State<InsuranceIncidentSheet> createState() => _InsuranceIncidentSheetState();
}

class _InsuranceIncidentSheetState extends State<InsuranceIncidentSheet> {
  String _incidentType = 'general';
  bool _consentToShare = false;
  bool _busy = false;

  Future<void> _create() async {
    setState(() => _busy = true);
    final (incident, error) = await context
        .read<AppState>()
        .createInsuranceIncident(
          incidentType: _incidentType,
          consentToShare: _consentToShare,
          reportId: widget.reportId,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    final reference = incident?.partnerReference == null
        ? ''
        : ' Reference: ${incident!.partnerReference}.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? 'Incident package saved.$reference')),
    );
    if (error == null) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LuxuryCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Insurance Incident',
                      style: TextStyle(
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
                'Consent is required before any partner-ready incident package can be shared externally.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _incidentType,
                decoration: const InputDecoration(labelText: 'Incident type'),
                items: const [
                  DropdownMenuItem(
                    value: 'general',
                    child: Text('General incident'),
                  ),
                  DropdownMenuItem(value: 'medical', child: Text('Medical')),
                  DropdownMenuItem(value: 'ride', child: Text('Ride-related')),
                  DropdownMenuItem(
                    value: 'property',
                    child: Text('Property loss'),
                  ),
                  DropdownMenuItem(value: 'injury', child: Text('Injury')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _incidentType = value);
                },
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                value: _consentToShare,
                onChanged: (value) {
                  setState(() => _consentToShare = value ?? false);
                },
                contentPadding: EdgeInsets.zero,
                activeColor: AppColors.goldBrushed,
                title: const Text(
                  'I consent to prepare this package for an insurance partner.',
                  style: TextStyle(fontSize: 12),
                ),
                subtitle: const Text(
                  'Without consent, the incident stays as a local/staff draft.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 10),
                ),
              ),
              const SizedBox(height: 8),
              TigerButton(
                label: _busy ? 'SAVING...' : 'SAVE INCIDENT PACKAGE',
                icon: Icons.health_and_safety,
                onPressed: _busy ? null : _create,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
