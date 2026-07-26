import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/lattice_background.dart';
import '../../providers/app_state.dart';

class RideAssistSheet extends StatefulWidget {
  const RideAssistSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const RideAssistSheet(),
    );
  }

  @override
  State<RideAssistSheet> createState() => _RideAssistSheetState();
}

class _RideAssistSheetState extends State<RideAssistSheet> {
  final _destination = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _destination.dispose();
    super.dispose();
  }

  Future<void> _request() async {
    if (_destination.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a destination or landmark.')),
      );
      return;
    }
    setState(() => _busy = true);
    final (ride, error) = await context.read<AppState>().requestRideAssist(
      destination: _destination.text.trim(),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    final suffix = ride?.externalUrl == null
        ? ''
        : ' Partner link prepared for confirmation.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? 'Ride assistance requested.$suffix')),
    );
    if (error == null) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
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
                  const Expanded(
                    child: Text(
                      'Get A Ride',
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
                'Staff can help you prepare a ride. External partners stay behind adapters until credentials are ready.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _destination,
                decoration: const InputDecoration(
                  labelText: 'Destination or safe landmark',
                  prefixIcon: Icon(Icons.place),
                ),
              ),
              const SizedBox(height: 12),
              TigerButton(
                label: _busy ? 'REQUESTING...' : 'REQUEST RIDE HELP',
                icon: Icons.local_taxi,
                onPressed: _busy ? null : _request,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
