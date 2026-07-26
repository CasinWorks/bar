import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/lattice_background.dart';
import '../../providers/app_state.dart';
import '../../router/member_routes.dart';

/// First-run tutorial after a member creates or signs into an account.
class MemberTutorialScreen extends StatefulWidget {
  const MemberTutorialScreen({super.key});

  @override
  State<MemberTutorialScreen> createState() => _MemberTutorialScreenState();
}

class _MemberTutorialScreenState extends State<MemberTutorialScreen>
    with TickerProviderStateMixin {
  static const _pages = [
    (
      'WELCOME',
      'You’re in.\nThe night starts here.',
      'This is your member pass. Time loads at the cash desk — the app is your wallet, QR, and lounge.',
      Icons.auto_awesome_rounded,
    ),
    (
      'LOAD',
      'Cash at the desk.\nBalance on your phone.',
      'During the pilot, buy time with cash at the house. Open the app after — your wallet updates live.',
      Icons.account_balance_wallet_outlined,
    ),
    (
      'ENTER',
      'Show the door\nyour QR.',
      'When you have time, open Entry and let staff scan. The lounge timer starts when you’re inside.',
      Icons.qr_code_2_rounded,
    ),
    (
      'PLAY',
      'Meet, tip,\nstay safe.',
      'Open to Meet, friends, rides, and private reports live in the lounge. Staff see reports — never the person you report.',
      Icons.groups_2_outlined,
    ),
    (
      'EXIT',
      'Leave clean.\nKeep the receipt.',
      'Request exit, show the exit QR, and you’re done. Sessions left open auto-close after 48 hours.',
      Icons.logout_rounded,
    ),
  ];

  final _controller = PageController();
  late final AnimationController _pulse;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    HapticFeedback.mediumImpact();
  }

  @override
  void dispose() {
    _controller.dispose();
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (_index < _pages.length - 1) {
      HapticFeedback.selectionClick();
      await _controller.nextPage(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    await _finish();
  }

  Future<void> _finish() async {
    final app = context.read<AppState>();
    await app.completeMemberTutorial();
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    context.go(routeForMemberState(app));
  }

  @override
  Widget build(BuildContext context) {
    final name = context.watch<AppState>().user?.name ?? 'Member';
    final bottom = MediaQuery.paddingOf(context).bottom;
    final onLast = _index == _pages.length - 1;

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: LatticeBackground(
        animate: true,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Row(
                  children: [
                    Text(
                      'MEMBER BRIEFING',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.4,
                        color: AppColors.goldBrushed,
                      ),
                    ),
                    const Spacer(),
                    if (!onLast)
                      GestureDetector(
                        onTap: _finish,
                        child: Text(
                          'SKIP',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.6,
                            color: AppColors.textMuted,
                          ),
                        ),
                      )
                    else
                      Text(
                        'FOR $name'.toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: AppColors.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _pages.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (context, i) {
                    final page = _pages[i];
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(28, 28, 28, 12),
                      child: Column(
                        children: [
                          const Spacer(),
                          AnimatedBuilder(
                            animation: _pulse,
                            builder: (_, child) {
                              return Container(
                                width: 96,
                                height: 96,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.goldBright.withValues(
                                      alpha: 0.5 + _pulse.value * 0.4,
                                    ),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.crimson.withValues(
                                        alpha: 0.2 + _pulse.value * 0.15,
                                      ),
                                      blurRadius: 24,
                                    ),
                                  ],
                                  color: const Color(0xEE120A00),
                                ),
                                alignment: Alignment.center,
                                child: child,
                              );
                            },
                            child: Icon(
                              page.$4,
                              size: 40,
                              color: AppColors.goldBright,
                            ),
                          ),
                          const SizedBox(height: 28),
                          Text(
                            page.$1,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2.6,
                              color: AppColors.goldBrushed,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            page.$2,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.cinzel(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              height: 1.15,
                              color: AppColors.textLight,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            page.$3,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              height: 1.55,
                              color: const Color(0xFFC4B8A8),
                            ),
                          ),
                          const Spacer(flex: 2),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(24, 0, 24, bottom + 12),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_pages.length, (i) {
                        final on = i == _index;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: on ? 18 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(99),
                            color: on
                                ? AppColors.goldBright
                                : AppColors.goldBrushed.withValues(alpha: 0.28),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 16),
                    TigerButton(
                      label: onLast ? 'ENTER THE CLUB' : 'NEXT',
                      icon: onLast ? Icons.door_front_door_rounded : Icons.arrow_forward_rounded,
                      onPressed: _next,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
