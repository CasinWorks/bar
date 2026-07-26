import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/lattice_background.dart';
import '../../models/club_packages.dart';
import '../../providers/app_state.dart';

/// Spend time on venue experiences — time is the currency.
class VipRoomsSheet extends StatefulWidget {
  const VipRoomsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.charcoal,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const VipRoomsSheet(),
    );
  }

  @override
  State<VipRoomsSheet> createState() => _VipRoomsSheetState();
}

class _VipRoomsSheetState extends State<VipRoomsSheet> {
  String? _spendingSlug;
  String? _error;

  Future<void> _spend(VenueActivity activity) async {
    if (_spendingSlug != null) return;
    final state = context.read<AppState>();
    if (state.isWalletBusy) {
      setState(() => _error = 'Hang on — another spend is still processing.');
      return;
    }

    setState(() {
      _spendingSlug = activity.slug;
      _error = null;
    });

    final ok = await state.redeemVenueActivity(activity);
    if (!mounted) return;

    setState(() => _spendingSlug = null);

    if (!ok) {
      setState(() {
        _error = 'Could not unlock ${activity.name}. Check your time balance.';
      });
      return;
    }

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${activity.name} unlocked (−${activity.timeCostMinutes} min). Invest your time wisely.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final height = MediaQuery.sizeOf(context).height * 0.88;
    final busy = _spendingSlug != null || state.isWalletBusy;

    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.darkSteel,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'SPEND TIME',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 18),
            ),
            Text(
              'Premium experiences use minutes — ${state.formatDuration(state.timeBalance)} remaining.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 11),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(color: AppColors.tigerOrange, fontSize: 12),
              ),
            ],
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: [
                  LuxuryCard(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        const Icon(Icons.nightlife, color: AppColors.tigerRed),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'DANCE FLOOR',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                'Included with your package · no extra charge',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                        Text(
                          'OPEN',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                color: AppColors.timerHealthy,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...VenueActivities.all.map((activity) {
                    final costSec = activity.timeCostMinutes * 60;
                    final canAfford = state.timeBalance >= costSec;
                    final thisBusy = _spendingSlug == activity.slug;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: LuxuryCard(
                        highlighted: canAfford && !busy,
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Text(activity.icon, style: const TextStyle(fontSize: 22)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    activity.name.toUpperCase(),
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                  Text(
                                    activity.description,
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              children: [
                                Text(
                                  '−${activity.timeCostMinutes}m',
                                  style: TextStyle(
                                    color: canAfford
                                        ? AppColors.tigerRed
                                        : AppColors.textMuted,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                SizedBox(
                                  height: 32,
                                  child: ElevatedButton(
                                    onPressed: canAfford && !busy
                                        ? () => _spend(activity)
                                        : null,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.tigerRed,
                                      foregroundColor: AppColors.offWhite,
                                      disabledBackgroundColor: AppColors.darkSteel,
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                    ),
                                    child: thisBusy
                                        ? const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: AppColors.offWhite,
                                            ),
                                          )
                                        : const Text('SPEND', style: TextStyle(fontSize: 11)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
            TigerButton(
              label: 'CLOSE',
              secondary: true,
              onPressed: busy ? null : () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}
