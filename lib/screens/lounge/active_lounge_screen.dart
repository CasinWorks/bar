import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/animated_time_display.dart';
import '../../core/widgets/lattice_background.dart';
import '../../models/blind_tiger_models.dart';
import '../../providers/app_state.dart';
import 'lounge_tabs.dart';
import 'pass_the_glass_sheet.dart';
import 'tip_bartender_sheet.dart';
import 'time_depleted_overlay.dart';
import 'vip_rooms_sheet.dart';

class ActiveLoungeScreen extends StatelessWidget {
  const ActiveLoungeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final remaining = state.remaining;
    final timerColor = AppColors.timerColor(remaining, isCheckedIn: true);

    return Scaffold(
      body: LatticeBackground(
        child: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  _Header(state: state),
                  _TimerCard(
                    timeRemaining: state.timeRemaining,
                    timerColor: timerColor,
                    points: state.points,
                    tier: state.memberTier,
                    isDepleted: state.isTimeDepleted,
                    onBuyTime: () => context.push('/buy-time'),
                    onPassGlass: () => PassTheGlassSheet.show(context),
                  ),
                  Expanded(child: _TabBody(tab: state.activeTab)),
                  _TabBar(
                    active: state.activeTab,
                    onChanged: state.setActiveTab,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: TigerButton(
                      label: 'REQUEST EXIT — SHOW QR AT DOOR',
                      icon: Icons.logout,
                      secondary: true,
                      onPressed: () async {
                        await state.requestExit();
                        if (context.mounted) context.go('/exit');
                      },
                    ),
                  ),
                ],
              ),
            ),
            if (state.isTimeDepleted) const TimeDepletedOverlay(),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Color(state.avatar.color),
            child: Text(
              state.avatar.name.substring(0, 1).toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(state.user?.name ?? 'Member', style: Theme.of(context).textTheme.titleMedium),
                Text(
                  '${state.session?.branch ?? ''} • #${state.currentRank} ${state.memberTier.label}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 10),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.successGreen.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.successGreen),
            ),
            child: const Text(
              'INSIDE CLUB',
              style: TextStyle(color: AppColors.successGreen, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimerCard extends StatelessWidget {
  const _TimerCard({
    required this.timeRemaining,
    required this.timerColor,
    required this.points,
    required this.tier,
    required this.isDepleted,
    required this.onBuyTime,
    required this.onPassGlass,
  });

  final int timeRemaining;
  final Color timerColor;
  final int points;
  final MemberTier tier;
  final bool isDepleted;
  final VoidCallback onBuyTime;
  final VoidCallback onPassGlass;

  @override
  Widget build(BuildContext context) {
    final roomState = context.watch<AppState>();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF1C0F00), Color(0xFF050000)]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: timerColor.withValues(alpha: 0.5)),
        boxShadow: [BoxShadow(color: timerColor.withValues(alpha: 0.2), blurRadius: 20)],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$points PTS', style: const TextStyle(color: AppColors.goldBright, fontWeight: FontWeight.bold, fontSize: 11)),
              Text(tier.label.toUpperCase(), style: TextStyle(color: tier.accentColor, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
            ],
          ),
          AnimatedTimeDisplay(
            seconds: timeRemaining,
            color: timerColor,
            fontSize: timeRemaining >= 3600 ? 40 : 48,
          ),
          Text(
            isDepleted ? 'TIME DEPLETED' : AppColors.timerLabel(Duration(seconds: timeRemaining)),
            style: TextStyle(color: isDepleted ? AppColors.tigerOrange : timerColor, fontSize: 10, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TigerButton(label: 'BUY TIME', icon: Icons.bolt, onPressed: onBuyTime),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TigerButton(
                  label: 'TIP BAR',
                  icon: Icons.nfc,
                  secondary: true,
                  onPressed: () => TipBartenderSheet.show(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TigerButton(
            label: roomState.hasVvipRoomAccess
                ? 'VVIP ROOM'
                : roomState.hasVipRoomAccess
                    ? 'VIP ROOM'
                    : 'PRIVATE ROOMS',
            icon: roomState.hasVvipRoomAccess
                ? Icons.auto_awesome
                : roomState.hasVipRoomAccess
                    ? Icons.diamond
                    : Icons.meeting_room,
            secondary: true,
            onPressed: () => VipRoomsSheet.show(context),
          ),
          const SizedBox(height: 8),
          TigerButton(
            label: 'PASS THE GLASS',
            icon: Icons.local_bar,
            secondary: true,
            onPressed: onPassGlass,
          ),
        ],
      ),
    );
  }
}

class _TabBody extends StatelessWidget {
  const _TabBody({required this.tab});
  final LoungeTab tab;

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: tab.index,
      children: const [
        ChallengesTab(),
        GamesTab(),
        SocialTab(),
        MenuTab(),
        LeaderboardTab(),
      ],
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({required this.active, required this.onChanged});

  final LoungeTab active;
  final ValueChanged<LoungeTab> onChanged;

  static const _items = [
    (LoungeTab.challenges, Icons.emoji_events, 'CHALLENGE'),
    (LoungeTab.games, Icons.grid_view, 'PLAY'),
    (LoungeTab.social, Icons.people, 'FEED'),
    (LoungeTab.menu, Icons.auto_awesome, 'MENU'),
    (LoungeTab.leaderboard, Icons.leaderboard, 'RANK'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.goldBrushed.withValues(alpha: 0.2))),
      ),
      child: Row(
        children: _items.map((item) {
          final isActive = active == item.$1;
          return Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onChanged(item.$1),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(item.$2, size: 18, color: isActive ? AppColors.goldBright : AppColors.neutral500),
                      const SizedBox(height: 4),
                      Text(
                        item.$3,
                        style: TextStyle(
                          fontSize: 7,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                          color: isActive ? AppColors.goldBright : AppColors.neutral500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
