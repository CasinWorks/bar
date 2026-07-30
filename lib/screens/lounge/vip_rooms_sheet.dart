import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/lattice_background.dart';
import '../../models/club_packages.dart';
import '../../models/vip_hosted_event_conflict.dart';
import '../../providers/app_state.dart';

/// Book VIP rooms/couches (room tab) or spend personal time on other experiences.
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
    if (activity.isVipRoomExperience && state.blocksVipRoomDueToHostedEvent) {
      setState(() => _error = VipHostedEventConflict.bookingBlockedMessage);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(VipHostedEventConflict.bookingBlockedMessage),
        ),
      );
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
        _error = activity.isVipRoomExperience
            ? (state.blocksVipRoomDueToHostedEvent
                  ? VipHostedEventConflict.bookingBlockedMessage
                  : 'Could not book ${activity.name}. Try again.')
            : 'Could not unlock ${activity.name}. Check your personal time.';
      });
      if (activity.isVipRoomExperience && state.blocksVipRoomDueToHostedEvent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(VipHostedEventConflict.bookingBlockedMessage),
          ),
        );
      }
      return;
    }

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          activity.isVipRoomExperience
              ? '${activity.name} booked · ${activity.timeCostMinutes} min room time (personal timer paused while room is active).'
              : '${activity.name} unlocked (−${activity.timeCostMinutes} min personal time).',
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
              state.isInVipRoom ? 'VIP ROOM ACTIVE' : 'SPEND TIME',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontSize: 18),
            ),
            if (state.isInVipRoom) ...[
              Text(
                '${state.activeVipRoomName} · ${state.formatDuration(state.vipRoomTimeSeconds)} room time · decays instead of personal · liquor also charges this pool.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontSize: 11),
              ),
              const SizedBox(height: 8),
              Text(
                'Personal time: ${state.formatDuration(state.timeBalance)} (paused while room time remains)',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 10,
                  color: AppColors.timerHealthy,
                ),
              ),
              const SizedBox(height: 8),
              TigerButton(
                label: 'LEAVE VIP ROOM',
                secondary: true,
                onPressed: busy
                    ? null
                    : () async {
                        await state.leaveVipRoom();
                        if (context.mounted) Navigator.pop(context);
                      },
              ),
              const SizedBox(height: 12),
            ] else ...[
              Text(
                'Personal time: ${state.formatDuration(state.timeBalance)} · VIP room time decays while you occupy the room.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontSize: 11),
              ),
            ],
            if (state.blocksVipRoomDueToHostedEvent) ...[
              const SizedBox(height: 8),
              Text(
                VipHostedEventConflict.bookingBlockedMessage,
                style: const TextStyle(
                  color: AppColors.tigerOrange,
                  fontSize: 12,
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(
                  color: AppColors.tigerOrange,
                  fontSize: 12,
                ),
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
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(color: AppColors.timerHealthy),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...VenueActivities.all.map((activity) {
                    final isVip = activity.isVipRoomExperience;
                    final costSec = activity.timeCostMinutes * 60;
                    final hostBlocksVip =
                        isVip && state.blocksVipRoomDueToHostedEvent;
                    final canAfford = isVip
                        ? !state.isInVipRoom && !hostBlocksVip
                        : state.timeBalance >= costSec;
                    final thisBusy = _spendingSlug == activity.slug;
                    final isActiveRoom =
                        state.isInVipRoom &&
                        state.session?.activeVipRoomSlug == activity.slug;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: LuxuryCard(
                        highlighted: (canAfford || isActiveRoom) && !busy,
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Text(
                              activity.icon,
                              style: const TextStyle(fontSize: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    activity.name.toUpperCase(),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  Text(
                                    activity.description,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                  if (isVip) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Room time decays while occupied; liquor orders also charge this pool — personal timer pauses.',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            fontSize: 9,
                                            color: const Color(0xFF9B59B6),
                                          ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Column(
                              children: [
                                Text(
                                  isVip
                                      ? '+${activity.timeCostMinutes}m tab'
                                      : '−${activity.timeCostMinutes}m',
                                  style: TextStyle(
                                    color: isVip
                                        ? const Color(0xFF9B59B6)
                                        : (canAfford
                                              ? AppColors.tigerRed
                                              : AppColors.textMuted),
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                SizedBox(
                                  height: 32,
                                  child: ElevatedButton(
                                    onPressed: isActiveRoom
                                        ? null
                                        : (canAfford && !busy
                                              ? () => _spend(activity)
                                              : null),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isVip
                                          ? const Color(0xFF9B59B6)
                                          : AppColors.tigerRed,
                                      foregroundColor: AppColors.offWhite,
                                      disabledBackgroundColor:
                                          AppColors.darkSteel,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
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
                                        : Text(
                                            isActiveRoom
                                                ? 'ACTIVE'
                                                : (isVip ? 'BOOK' : 'SPEND'),
                                            style: const TextStyle(
                                              fontSize: 11,
                                            ),
                                          ),
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
