import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/lattice_background.dart';
import '../../models/blind_tiger_models.dart';
import '../../models/club_packages.dart';
import '../../providers/app_state.dart';
import 'pass_the_glass_sheet.dart';
import 'vip_rooms_sheet.dart';

/// Guest-facing hub for Time Currency modules + revenue actions.
class NightHubSheet extends StatelessWidget {
  const NightHubSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.charcoal,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const NightHubSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final drinks = state.drinksAllowanceRemaining;
    final pkg = ClubPackages.bySlug(
      state.session?.packageSlug ?? state.user?.activePackageSlug,
    );
    final height = MediaQuery.sizeOf(context).height * 0.9;

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
              'YOUR NIGHT',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 18),
            ),
            Text(
              pkg != null
                  ? '${pkg.name} · ${state.formatDuration(state.timeBalance)} · $drinks drinks left'
                  : '${state.formatDuration(state.timeBalance)} · $drinks drinks left',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: [
                  Text('REVENUE & ACCESS', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  _HubTile(
                    title: 'Time packages / extend',
                    subtitle: 'Buy more minutes at the desk — wallet updates live',
                    icon: Icons.schedule,
                    onTap: () {
                      Navigator.pop(context);
                      context.go('/pricing');
                    },
                  ),
                  _HubTile(
                    title: 'Premium cocktails',
                    subtitle: 'Spend minutes or pay at the bar',
                    icon: Icons.local_bar,
                    onTap: () {
                      Navigator.pop(context);
                      state.setActiveTab(LoungeTab.menu);
                    },
                  ),
                  _HubTile(
                    title: 'VIP & hidden experiences',
                    subtitle: 'Spend time on lounge, secret room, booth…',
                    icon: Icons.auto_awesome,
                    onTap: () {
                      Navigator.pop(context);
                      VipRoomsSheet.show(context);
                    },
                  ),
                  _HubTile(
                    title: 'Events',
                    subtitle: 'Themed nights — ask the house what’s on',
                    icon: Icons.event,
                    onTap: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Ask the house about tonight’s events.'),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Text('SOFTWARE MODULES', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  _HubTile(
                    title: 'QR entry / exit',
                    subtitle: 'Digital pass at the door',
                    icon: Icons.qr_code_2,
                    onTap: () {
                      Navigator.pop(context);
                      context.go('/exit');
                    },
                  ),
                  _HubTile(
                    title: 'Drink tracking',
                    subtitle: drinks > 0
                        ? '$drinks package drinks remaining'
                        : 'Allowance empty — premium path available',
                    icon: Icons.sports_bar,
                    onTap: () {
                      Navigator.pop(context);
                      state.setActiveTab(LoungeTab.menu);
                    },
                  ),
                  _HubTile(
                    title: 'Time transfer',
                    subtitle: 'Pass the Glass — guest to guest',
                    icon: Icons.volunteer_activism,
                    onTap: () {
                      Navigator.pop(context);
                      PassTheGlassSheet.show(context);
                    },
                  ),
                  _HubTile(
                    title: 'Loyalty / earn time',
                    subtitle: 'Challenges award bonus minutes',
                    icon: Icons.emoji_events,
                    onTap: () {
                      Navigator.pop(context);
                      state.setActiveTab(LoungeTab.challenges);
                    },
                  ),
                  _HubTile(
                    title: 'Membership',
                    subtitle: 'Ask the desk about recurring packages',
                    icon: Icons.card_membership,
                    onTap: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Membership is desk-managed — ask the house.',
                          ),
                        ),
                      );
                    },
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
}

class _HubTile extends StatelessWidget {
  const _HubTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: LuxuryCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(icon, color: AppColors.tigerRed),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: Theme.of(context).textTheme.titleMedium),
                      Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
