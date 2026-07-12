import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/lattice_background.dart';
import '../../providers/app_state.dart';

class VipRoomsSheet extends StatelessWidget {
  const VipRoomsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.neutral950,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const VipRoomsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final height = MediaQuery.sizeOf(context).height * 0.88;

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
                  color: AppColors.neutral500,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'PRIVATE ROOMS',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 18),
            ),
            Text(
              'Your load unlocks hidden floors — ${state.formatDuration(state.spendableTimeSeconds)} on account.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 11),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: [
                  _RoomCard(
                    title: 'Main Lounge',
                    subtitle: 'Open floor · beats, bar, and the full crowd.',
                    icon: Icons.local_bar,
                    accent: AppColors.goldBrushed,
                    unlocked: true,
                    badge: 'OPEN',
                    onEnter: () => _showEntered(context, 'Main Lounge'),
                  ),
                  _RoomCard(
                    title: 'VIP Room',
                    subtitle: 'Platinum tier · leather booths, bottle service, quieter pours.',
                    icon: Icons.diamond,
                    accent: AppColors.goldBright,
                    unlocked: state.hasVipRoomAccess,
                    requiredLabel: '3h+ club time (Platinum)',
                    badge: 'VIP',
                    onEnter: state.hasVipRoomAccess
                        ? () => _showEntered(context, 'VIP Room')
                        : null,
                  ),
                  _RoomCard(
                    title: 'VVIP Room',
                    subtitle: '100h+ legends · private cellar, concierge, zero queue.',
                    icon: Icons.auto_awesome,
                    accent: AppColors.vvipAmethyst,
                    unlocked: state.hasVvipRoomAccess,
                    requiredLabel: '100h+ club time (VVIP)',
                    badge: 'VVIP',
                    gradient: const [AppColors.vvipDeep, Color(0xFF120820)],
                    onEnter: state.hasVvipRoomAccess
                        ? () => _showEntered(context, 'VVIP Room')
                        : null,
                  ),
                ],
              ),
            ),
            TigerButton(
              label: 'CLOSE',
              secondary: true,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  static void _showEntered(BuildContext context, String room) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardSurface,
        title: Text('Welcome to $room'),
        content: Text(
          room == 'VVIP Room'
              ? 'Concierge notified. Your table is ready in the cellar — time is currency here.'
              : room == 'VIP Room'
                  ? 'VIP host will meet you at the velvet rope. Enjoy the elevated pour.'
                  : 'You\'re on the main floor. The night is yours.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ENTER')),
        ],
      ),
    );
  }
}

class _RoomCard extends StatelessWidget {
  const _RoomCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.unlocked,
    required this.badge,
    this.requiredLabel,
    this.gradient,
    this.onEnter,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final bool unlocked;
  final String badge;
  final String? requiredLabel;
  final List<Color>? gradient;
  final VoidCallback? onEnter;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: LuxuryCard(
        highlighted: unlocked,
        padding: EdgeInsets.zero,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: gradient != null
                ? LinearGradient(colors: gradient!)
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(icon, color: unlocked ? accent : AppColors.neutral500, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                title,
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                  color: unlocked ? AppColors.textLight : AppColors.textMuted,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: unlocked ? 0.25 : 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: accent.withValues(alpha: 0.5)),
                                ),
                                child: Text(
                                  badge,
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w900,
                                    color: unlocked ? accent : AppColors.neutral500,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      unlocked ? Icons.lock_open : Icons.lock,
                      color: unlocked ? AppColors.successGreen : AppColors.neutral500,
                      size: 20,
                    ),
                  ],
                ),
                if (!unlocked && requiredLabel != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Requires $requiredLabel',
                    style: const TextStyle(
                      color: AppColors.tigerOrange,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
                if (unlocked) ...[
                  const SizedBox(height: 12),
                  TigerButton(
                    label: 'ENTER $badge',
                    icon: Icons.door_front_door,
                    onPressed: onEnter,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
