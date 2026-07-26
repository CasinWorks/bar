import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/animated_time_display.dart';
import '../../core/widgets/lattice_background.dart';
import '../../core/widgets/tiger_motion.dart';
import '../../models/blind_tiger_models.dart';
import '../../providers/app_state.dart';
import 'lounge_tabs.dart';
import 'night_hub_sheet.dart';
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
        animate: true,
        child: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 40),
                    child: _Header(state: state),
                  ),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 120),
                    child: NeonPulse(
                      color: timerColor,
                      enabled: !state.isTimeDepleted,
                      child: _TimerCard(
                        timeRemaining: state.timeRemaining,
                        timerColor: timerColor,
                        points: state.points,
                        tier: state.memberTier,
                        isDepleted: state.isTimeDepleted,
                        onPassGlass: () => PassTheGlassSheet.show(context),
                      ),
                    ),
                  ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 280),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      child: KeyedSubtree(
                        key: ValueKey(state.activeTab),
                        child: _TabBody(tab: state.activeTab),
                      ),
                    ),
                  ),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 200),
                    child: _TabBar(
                      active: state.activeTab,
                      onChanged: state.setActiveTab,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: FadeSlideIn(
                      delay: const Duration(milliseconds: 260),
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
          IconButton(
            tooltip: 'Your night',
            onPressed: () => NightHubSheet.show(context),
            icon: const Icon(Icons.grid_view_rounded, color: AppColors.goldBright),
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

class _TimerCard extends StatefulWidget {
  const _TimerCard({
    required this.timeRemaining,
    required this.timerColor,
    required this.points,
    required this.tier,
    required this.isDepleted,
    required this.onPassGlass,
  });

  final int timeRemaining;
  final Color timerColor;
  final int points;
  final MemberTier tier;
  final bool isDepleted;
  final VoidCallback onPassGlass;

  /// Short phones default collapsed so challenges/content keep room.
  static const double shortScreenHeight = 720;

  static const String _prefKey = 'lounge_timer_card_expanded';

  @override
  State<_TimerCard> createState() => _TimerCardState();
}

class _TimerCardState extends State<_TimerCard> {
  /// Null until prefs resolve; UI falls back to screen-height default.
  bool? _expandedPref;

  @override
  void initState() {
    super.initState();
    _loadExpandedPref();
  }

  Future<void> _loadExpandedPref() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      final saved = prefs.getBool(_TimerCard._prefKey);
      if (saved == null) return;
      setState(() => _expandedPref = saved);
    } catch (_) {}
  }

  bool _isExpanded(BuildContext context) {
    if (_expandedPref != null) return _expandedPref!;
    return MediaQuery.sizeOf(context).height >= _TimerCard.shortScreenHeight;
  }

  Future<void> _setExpanded(bool value) async {
    setState(() => _expandedPref = value);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_TimerCard._prefKey, value);
    } catch (_) {}
  }

  void _toggle(BuildContext context) => _setExpanded(!_isExpanded(context));

  @override
  Widget build(BuildContext context) {
    final roomState = context.watch<AppState>();
    final expanded = _isExpanded(context);
    final timerLabel = widget.isDepleted
        ? 'TIME DEPLETED'
        : AppColors.timerLabel(Duration(seconds: widget.timeRemaining));
    final labelColor =
        widget.isDepleted ? AppColors.tigerOrange : widget.timerColor;
    final expandedFontSize = widget.timeRemaining >= 3600 ? 40.0 : 48.0;
    final collapsedFontSize = widget.timeRemaining >= 3600 ? 26.0 : 30.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: EdgeInsets.fromLTRB(16, expanded ? 16 : 12, 16, expanded ? 16 : 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF1C0F00), Color(0xFF050000)]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: widget.timerColor.withValues(alpha: 0.5)),
        boxShadow: [BoxShadow(color: widget.timerColor.withValues(alpha: 0.2), blurRadius: 20)],
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOutCubic,
        alignment: Alignment.topCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _toggle(context),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            '${widget.points} PTS',
                            style: const TextStyle(
                              color: AppColors.goldBright,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            widget.tier.label.toUpperCase(),
                            style: TextStyle(
                              color: widget.tier.accentColor,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            expanded ? Icons.expand_less : Icons.expand_more,
                            size: 22,
                            color: AppColors.goldBright.withValues(alpha: 0.85),
                          ),
                        ],
                      ),
                      AnimatedTimeDisplay(
                        seconds: widget.timeRemaining,
                        color: widget.timerColor,
                        fontSize: expanded ? expandedFontSize : collapsedFontSize,
                      ),
                      if (expanded)
                        Text(
                          timerLabel,
                          style: TextStyle(
                            color: labelColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      else
                        Text(
                          '$timerLabel · ${roomState.drinksAllowanceRemaining} drinks · ${widget.points} PTS',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: labelColor.withValues(alpha: 0.9),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (expanded) ...[
              const SizedBox(height: 10),
              Text(
                '${roomState.drinksAllowanceRemaining} drinks left · package wallet',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 11),
              ),
              const SizedBox(height: 10),
              TigerButton(
                label: 'YOUR NIGHT',
                icon: Icons.grid_view_rounded,
                onPressed: () => NightHubSheet.show(context),
              ),
              const SizedBox(height: 8),
              TigerButton(
                label: 'TIP BAR',
                icon: Icons.nfc,
                secondary: true,
                onPressed: () => TipBartenderSheet.show(context),
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
                onPressed: widget.onPassGlass,
              ),
            ],
          ],
        ),
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
    (LoungeTab.challenges, Icons.emoji_events, 'EARN'),
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
