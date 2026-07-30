import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_logo.dart';
import '../../core/widgets/lattice_background.dart';
import '../../providers/app_state.dart';
import '../../services/tiger_sound_service.dart';

const _kWelcomeSeenKey = 'welcome_intro_seen_v2';

/// One full-screen scene per idea — with theater beats that stay calm.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  static const _pageCount = 5;

  PageController? _pageController;
  late final AnimationController _pulse;
  late final AnimationController _orb;
  late final List<AnimationController> _entrances;

  int _page = 0;
  bool _ready = false;
  bool _seenBefore = false;
  bool _soundEnabled = true;
  final _sounds = TigerSoundService.instance;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _orb = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();

    _entrances = List.generate(
      _pageCount,
      (i) => AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 780 + i * 50),
      ),
    );

    _boot();
  }

  Future<void> _boot() async {
    final prefs = await SharedPreferences.getInstance();
    await _sounds.ensureLoaded();
    final seen = prefs.getBool(_kWelcomeSeenKey) ?? false;
    final sound = _sounds.enabled;
    final start = seen ? _pageCount - 1 : 0;
    _pageController = PageController(initialPage: start);
    if (!mounted) return;
    setState(() {
      _seenBefore = seen;
      _soundEnabled = sound;
      _page = start;
      _ready = true;
    });
    _entrances[start].forward();
    if (start == 0) {
      HapticFeedback.mediumImpact();
      _playKnock();
    }
  }

  Future<void> _markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kWelcomeSeenKey, true);
    if (mounted) setState(() => _seenBefore = true);
  }

  Future<void> _setSoundEnabled(bool on) async {
    await _sounds.setEnabled(on);
    if (!mounted) return;
    setState(() => _soundEnabled = on);
  }

  Future<void> _playKnock() async {
    await _sounds.playKnock();
  }

  @override
  void dispose() {
    _pageController?.dispose();
    _pulse.dispose();
    _orb.dispose();
    for (final c in _entrances) {
      c.dispose();
    }
    super.dispose();
  }

  void _onPageChanged(int i) {
    HapticFeedback.selectionClick();
    setState(() => _page = i);
    _entrances[i]
      ..reset()
      ..forward();
    if (i == 0) HapticFeedback.mediumImpact();
    _playKnock();
    if (i == _pageCount - 1) _markSeen();
  }

  Future<void> _next() async {
    if (_page < _pageCount - 1) {
      await _pageController?.nextPage(
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _skipToAccess() async {
    await _markSeen();
    await _pageController?.animateToPage(
      _pageCount - 1,
      duration: const Duration(milliseconds: 480),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _replay() async {
    await _pageController?.animateToPage(
      0,
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bootstrapping = context.watch<AppState>().isLoading;
    if (bootstrapping) {
      return const Scaffold(
        backgroundColor: AppColors.darkBackground,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.goldBrushed),
        ),
      );
    }

    final h = MediaQuery.sizeOf(context).height;
    final topPad = MediaQuery.paddingOf(context).top;
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final onFinale = _page == _pageCount - 1;

    if (!_ready || _pageController == null) {
      return const Scaffold(
        backgroundColor: AppColors.darkBackground,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.goldBrushed),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: LatticeBackground(
        animate: true,
        child: Stack(
          children: [
            AnimatedBuilder(
              animation: _orb,
              builder: (_, _) {
                final t = _orb.value * math.pi * 2;
                return Stack(
                  children: [
                    Positioned(
                      top: h * 0.05 + math.sin(t) * 12,
                      right: -50,
                      child: _GlowOrb(
                        size: h * 0.42,
                        color: AppColors.crimson.withValues(alpha: 0.28),
                      ),
                    ),
                    Positioned(
                      bottom: h * 0.15 + math.cos(t) * 10,
                      left: -60,
                      child: _GlowOrb(
                        size: h * 0.32,
                        color: AppColors.goldBrushed.withValues(alpha: 0.16),
                      ),
                    ),
                  ],
                );
              },
            ),

            PageView(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              onPageChanged: _onPageChanged,
              children: [
                _SceneShell(
                  topPad: topPad,
                  bottomPad: bottomPad,
                  child: _HeroScene(entrance: _entrances[0], pulse: _pulse),
                ),
                _SceneShell(
                  topPad: topPad,
                  bottomPad: bottomPad,
                  child: _StoryScene(entrance: _entrances[1]),
                ),
                _SceneShell(
                  topPad: topPad,
                  bottomPad: bottomPad,
                  child: _HowScene(entrance: _entrances[2]),
                ),
                _SceneShell(
                  topPad: topPad,
                  bottomPad: bottomPad,
                  child: _LoopScene(entrance: _entrances[3]),
                ),
                _SceneShell(
                  topPad: topPad,
                  bottomPad: bottomPad,
                  child: _AccessScene(
                    entrance: _entrances[4],
                    soundEnabled: _soundEnabled,
                    onToggleSound: _setSoundEnabled,
                    onSignIn: () => context.push('/login'),
                    onSignUp: () => context.push('/signup'),
                  ),
                ),
              ],
            ),

            Positioned(
              top: topPad + 10,
              left: 20,
              right: 20,
              child: Row(
                children: [
                  const AppLogo(size: 30),
                  const SizedBox(width: 10),
                  Text(
                    'BLIND TIGER',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 3.2,
                      color: AppColors.goldBright,
                    ),
                  ),
                  const Spacer(),
                  if (!onFinale)
                    GestureDetector(
                      onTap: _skipToAccess,
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        child: Text(
                          'SKIP',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.8,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    )
                  else if (_seenBefore)
                    GestureDetector(
                      onTap: _replay,
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        child: Text(
                          'REPLAY',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.8,
                            color: AppColors.goldBrushed,
                          ),
                        ),
                      ),
                    )
                  else
                    Text(
                      '${(_page + 1).toString().padLeft(2, '0')} / 0$_pageCount',
                      style: GoogleFonts.shareTechMono(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                ],
              ),
            ),

            Positioned(
              left: 20,
              right: 20,
              bottom: bottomPad + 14,
              child: Column(
                children: [
                  _PageDots(count: _pageCount, index: _page),
                  const SizedBox(height: 12),
                  if (!onFinale)
                    GestureDetector(
                      onTap: _next,
                      behavior: HitTestBehavior.opaque,
                      child: AnimatedBuilder(
                        animation: _pulse,
                        builder: (_, child) {
                          return Opacity(
                            opacity: 0.55 + _pulse.value * 0.4,
                            child: Transform.translate(
                              offset: Offset(0, _pulse.value * 5),
                              child: child,
                            ),
                          );
                        },
                        child: Column(
                          children: [
                            Text(
                              'SWIPE UP',
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 2.6,
                                color: AppColors.goldBrushed,
                              ),
                            ),
                            Icon(
                              Icons.keyboard_arrow_up_rounded,
                              color: AppColors.goldBrushed.withValues(
                                alpha: 0.85,
                              ),
                              size: 22,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: _PillButton(
                            label: 'SIGN IN',
                            filled: true,
                            onTap: () => context.push('/login'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _PillButton(
                            label: 'JOIN',
                            filled: false,
                            onTap: () => context.push('/signup'),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SceneShell extends StatelessWidget {
  const _SceneShell({
    required this.topPad,
    required this.bottomPad,
    required this.child,
  });

  final double topPad;
  final double bottomPad;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(22, topPad + 56, 22, bottomPad + 88),
      child: child,
    );
  }
}

double _stagger(double t, double start, double span) {
  return Curves.easeOutCubic.transform(((t - start) / span).clamp(0.0, 1.0));
}

Widget _in({
  required double t,
  required Widget child,
  double dy = 28,
  double dx = 0,
  double scaleFrom = 0.94,
}) {
  final v = t.clamp(0.0, 1.0);
  return Opacity(
    opacity: v,
    child: Transform.translate(
      offset: Offset(dx * (1 - v), dy * (1 - v)),
      child: Transform.scale(
        scale: scaleFrom + (1 - scaleFrom) * v,
        child: child,
      ),
    ),
  );
}

// ─── SCENE 1: HERO + claw wipe ──────────────────────────────────────

class _HeroScene extends StatelessWidget {
  const _HeroScene({required this.entrance, required this.pulse});

  final Animation<double> entrance;
  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([entrance, pulse]),
      builder: (_, _) {
        final t = entrance.value;
        final emblem = _stagger(t, 0.05, 0.45);
        final claw = _stagger(t, 0.35, 0.45);
        final scale = 0.86 + emblem * 0.14;
        final glow = 0.35 + pulse.value * 0.3;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _in(
              t: _stagger(t, 0.0, 0.4),
              child: Text(
                '私 人 会 所  ·  MEMBER PASS',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.4,
                  color: AppColors.goldBrushed,
                ),
              ),
            ),
            const SizedBox(height: 10),
            _in(
              t: _stagger(t, 0.08, 0.4),
              dy: 22,
              child: Text(
                'Your time starts now.',
                style: GoogleFonts.cinzel(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  height: 1.12,
                  color: AppColors.textLight,
                ),
              ),
            ),
            const SizedBox(height: 10),
            _in(
              t: _stagger(t, 0.18, 0.4),
              child: Text(
                'TIME IS YOUR CURRENCY.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  height: 1.45,
                  color: AppColors.textMuted,
                ),
              ),
            ),
            const Spacer(),
            Center(
              child: Opacity(
                opacity: emblem,
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.0014)
                    ..rotateY(-0.28 + emblem * 0.36)
                    ..rotateX(0.1 - emblem * 0.06)
                    ..scaleByDouble(scale, scale, scale, 1),
                  child: SizedBox(
                    width: 188,
                    height: 188,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 188,
                          height: 188,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const RadialGradient(
                              colors: [
                                Color(0xFF6B4518),
                                Color(0xFF1A0C00),
                                Color(0xFF050200),
                              ],
                            ),
                            border: Border.all(
                              color: AppColors.goldBright.withValues(
                                alpha: 0.65,
                              ),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.goldBrushed.withValues(
                                  alpha: glow * 0.6,
                                ),
                                blurRadius: 48,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: const AppLogo(size: 148),
                        ),
                        // Claw stroke wipe over the emblem
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _ClawWipePainter(progress: claw),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const Spacer(),
            _in(t: _stagger(t, 0.55, 0.4), dy: 20, child: const _WalletStrip()),
          ],
        );
      },
    );
  }
}

class _ClawWipePainter extends CustomPainter {
  _ClawWipePainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final paint = Paint()
      ..color = AppColors.darkBackground
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.085
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.6);

    final cx = size.width / 2;
    final top = size.height * 0.22;
    final bottom = size.height * 0.82;

    for (var i = 0; i < 3; i++) {
      final x = size.width * (0.34 + i * 0.16);
      final path = Path()
        ..moveTo(x + (i - 1) * 4, top)
        ..quadraticBezierTo(
          x + (cx - x) * 0.15,
          size.height * 0.5,
          x - (i - 1) * 6,
          bottom,
        );

      for (final metric in path.computeMetrics()) {
        final extract = metric.extractPath(0, metric.length * progress);
        canvas.drawPath(extract, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ClawWipePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _WalletStrip extends StatelessWidget {
  const _WalletStrip();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xF50A0500),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.goldBrushed.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: AppColors.timerNeon,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.timerNeon.withValues(alpha: 0.7),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'LIVE · 2h 00m',
            style: GoogleFonts.shareTechMono(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.timerNeon,
              shadows: AppColors.timerGlow(
                AppColors.timerNeon,
                intensity: 0.85,
              ),
            ),
          ),
          const Spacer(),
          Text(
            'WALLET READY',
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── SCENE 2: STORY type-on ─────────────────────────────────────────

class _StoryScene extends StatelessWidget {
  const _StoryScene({required this.entrance});

  final Animation<double> entrance;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: entrance,
      builder: (_, _) {
        final t = entrance.value;
        final line1 = _typeOn("It's the night,", _stagger(t, 0.0, 0.42));
        final line2 = _typeOn(
          'remastered for\nyour pocket.',
          _stagger(t, 0.28, 0.45),
        );
        final bodyT = _stagger(t, 0.62, 0.35);

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              line1,
              textAlign: TextAlign.center,
              style: GoogleFonts.cinzel(
                fontSize: 32,
                fontWeight: FontWeight.w600,
                color: AppColors.textLight,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              line2,
              textAlign: TextAlign.center,
              style: GoogleFonts.cinzel(
                fontSize: 30,
                fontWeight: FontWeight.w600,
                height: 1.15,
                color: AppColors.goldBright,
              ),
            ),
            const SizedBox(height: 22),
            Opacity(
              opacity: bodyT,
              child: Transform.translate(
                offset: Offset(0, 16 * (1 - bodyT)),
                child: Text(
                  'Buy club hours. Walk in with a pass.\n'
                  'Spend time like currency — drinks, tips,\n'
                  'and status that climbs with every minute.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    height: 1.6,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

String _typeOn(String full, double t) {
  if (t <= 0) return '';
  if (t >= 1) return full;
  final runes = full.runes.toList();
  final count = (runes.length * t).ceil().clamp(0, runes.length);
  return String.fromCharCodes(runes.take(count));
}

// ─── SCENE 3: HOW + tap expand ──────────────────────────────────────

class _HowScene extends StatefulWidget {
  const _HowScene({required this.entrance});

  final Animation<double> entrance;

  @override
  State<_HowScene> createState() => _HowSceneState();
}

class _HowSceneState extends State<_HowScene> {
  int? _open;

  static const _cards = [
    (
      '01',
      'Load time',
      'Cash at the desk → wallet updates live.',
      '₱2,000 → ~2 hours on your phone.',
      false,
    ),
    (
      '02',
      'Enter with QR',
      'Door scan unlocks the lounge timer.',
      'Show pass → curtain lifts → you’re in.',
      true,
    ),
    (
      '03',
      'Spend minutes',
      'Drinks, tips, status — time is money.',
      'Order a pour → minutes leave the wallet.',
      false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.entrance,
      builder: (_, _) {
        final t = widget.entrance.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _in(
              t: _stagger(t, 0.0, 0.35),
              child: Text(
                'HOW IT WORKS',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.4,
                  color: AppColors.goldBrushed,
                ),
              ),
            ),
            const SizedBox(height: 8),
            _in(
              t: _stagger(t, 0.05, 0.35),
              dy: 18,
              child: Text(
                'Three moves.\nOne velvet door.',
                style: GoogleFonts.cinzel(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                  color: AppColors.textLight,
                ),
              ),
            ),
            const SizedBox(height: 6),
            _in(
              t: _stagger(t, 0.12, 0.3),
              child: Text(
                'Tap a card for a demo moment.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: Column(
                children: List.generate(_cards.length, (i) {
                  final c = _cards[i];
                  return Expanded(
                    flex: _open == i ? 3 : 2,
                    child: Padding(
                      padding: EdgeInsets.only(bottom: i == 2 ? 0 : 10),
                      child: _in(
                        t: _stagger(t, 0.18 + i * 0.14, 0.4),
                        dy: 28,
                        child: _HowCard(
                          index: c.$1,
                          title: c.$2,
                          body: c.$3,
                          demo: c.$4,
                          hot: c.$5,
                          expanded: _open == i,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _open = _open == i ? null : i);
                          },
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HowCard extends StatelessWidget {
  const _HowCard({
    required this.index,
    required this.title,
    required this.body,
    required this.demo,
    required this.hot,
    required this.expanded,
    required this.onTap,
  });

  final String index;
  final String title;
  final String body;
  final String demo;
  final bool hot;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: hot
                ? const LinearGradient(
                    colors: [Color(0xFF5C1010), Color(0xFF1C0800)],
                  )
                : null,
            color: hot ? null : const Color(0xEE120A00),
            border: Border.all(
              color: AppColors.goldBrushed.withValues(
                alpha: expanded ? 0.55 : (hot ? 0.4 : 0.22),
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Text(
                    index,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.8,
                      color: AppColors.goldBrushed,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: AppColors.goldBrushed.withValues(alpha: 0.7),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: GoogleFonts.cinzel(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textLight,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                body,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  height: 1.35,
                  color: const Color(0xFFC4B8A8),
                ),
              ),
              AnimatedCrossFade(
                firstChild: const SizedBox(width: double.infinity, height: 0),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: AppColors.goldBrushed.withValues(alpha: 0.1),
                      border: Border.all(
                        color: AppColors.goldBrushed.withValues(alpha: 0.28),
                      ),
                    ),
                    child: Text(
                      demo,
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.goldBright,
                      ),
                    ),
                  ),
                ),
                crossFadeState: expanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 280),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── SCENE 4: LOOP + gold connector ─────────────────────────────────

class _LoopScene extends StatelessWidget {
  const _LoopScene({required this.entrance});

  final Animation<double> entrance;

  @override
  Widget build(BuildContext context) {
    const steps = [
      ('DESK', 'Cash loads time'),
      ('DOOR', 'QR unlocks entry'),
      ('LOUNGE', 'Timer runs live'),
      ('SPEND', 'Minutes buy moments'),
    ];

    return AnimatedBuilder(
      animation: entrance,
      builder: (_, _) {
        final t = entrance.value;
        final lineT = _stagger(t, 0.2, 0.7);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _in(
              t: _stagger(t, 0.0, 0.35),
              child: Text(
                'THE LOOP',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.4,
                  color: AppColors.goldBrushed,
                ),
              ),
            ),
            const SizedBox(height: 8),
            _in(
              t: _stagger(t, 0.05, 0.35),
              dy: 16,
              child: Text(
                'One night.\nFour beats.',
                style: GoogleFonts.cinzel(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                  color: AppColors.textLight,
                ),
              ),
            ),
            const SizedBox(height: 22),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    children: [
                      // Gold connector behind the numbered nodes
                      Positioned(
                        left: 21,
                        top: 22,
                        bottom: 22,
                        width: 2,
                        child: CustomPaint(
                          painter: _GoldLinePainter(progress: lineT),
                          size: Size(2, constraints.maxHeight),
                        ),
                      ),
                      Column(
                        children: List.generate(steps.length, (i) {
                          final (label, sub) = steps[i];
                          final stepReveal = _stagger(t, 0.15 + i * 0.14, 0.4);
                          return Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(bottom: i == 3 ? 0 : 8),
                              child: _in(
                                t: stepReveal,
                                dx: 36,
                                dy: 12,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: AppColors.goldBrushed
                                              .withValues(alpha: 0.55),
                                        ),
                                        color: AppColors.cardSurface,
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.goldBrushed
                                                .withValues(
                                                  alpha: 0.2 * stepReveal,
                                                ),
                                            blurRadius: 12,
                                          ),
                                        ],
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        '${i + 1}'.padLeft(2, '0'),
                                        style: GoogleFonts.shareTechMono(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.goldBright,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Container(
                                        height: double.infinity,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                        ),
                                        alignment: Alignment.centerLeft,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: AppColors.cardBorder,
                                          ),
                                          color: const Color(0xEE120A00),
                                        ),
                                        child: Row(
                                          children: [
                                            Text(
                                              label,
                                              style: GoogleFonts.inter(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: 1.5,
                                                color: AppColors.goldBright,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                sub,
                                                style: GoogleFonts.inter(
                                                  fontSize: 13,
                                                  color: const Color(
                                                    0xFFC4B8A8,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _GoldLinePainter extends CustomPainter {
  _GoldLinePainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final track = Paint()
      ..color = AppColors.goldBrushed.withValues(alpha: 0.15)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final glow = Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(0, size.height * progress),
        [
          AppColors.goldBright.withValues(alpha: 0.15),
          AppColors.goldBright,
          AppColors.goldBrushed,
        ],
        const [0.0, 0.7, 1.0],
      )
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2);

    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      track,
    );
    if (progress > 0) {
      canvas.drawLine(
        Offset(size.width / 2, 0),
        Offset(size.width / 2, size.height * progress),
        glow,
      );
      canvas.drawLine(
        Offset(size.width / 2, 0),
        Offset(size.width / 2, size.height * progress),
        Paint()
          ..color = AppColors.goldBright
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GoldLinePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// ─── SCENE 5: ACCESS ────────────────────────────────────────────────

class _AccessScene extends StatelessWidget {
  const _AccessScene({
    required this.entrance,
    required this.soundEnabled,
    required this.onToggleSound,
    required this.onSignIn,
    required this.onSignUp,
  });

  final Animation<double> entrance;
  final bool soundEnabled;
  final ValueChanged<bool> onToggleSound;
  final VoidCallback onSignIn;
  final VoidCallback onSignUp;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: entrance,
      builder: (_, _) {
        final t = entrance.value;
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _in(
              t: _stagger(t, 0.0, 0.4),
              dy: 24,
              scaleFrom: 0.9,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(18, 26, 18, 22),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppColors.goldBrushed.withValues(alpha: 0.4),
                  ),
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.85),
                    radius: 1.1,
                    colors: [
                      AppColors.goldBrushed.withValues(alpha: 0.14),
                      const Color(0xF50C0600),
                    ],
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      'PRIVATE ACCESS',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.6,
                        color: AppColors.goldBrushed,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Step through\nthe velvet door.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cinzel(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                        color: AppColors.textLight,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Members and door staff use the same sign-in.\nAge 21+ · member pass required.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        height: 1.5,
                        color: const Color(0xFFC4B8A8),
                      ),
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () => onToggleSound(!soundEnabled),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(
                            color: AppColors.goldBrushed.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              soundEnabled
                                  ? Icons.volume_up_rounded
                                  : Icons.volume_off_rounded,
                              size: 16,
                              color: AppColors.goldBrushed,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              soundEnabled ? 'SOUND ON' : 'SOUND OFF',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.6,
                                color: AppColors.goldBrushed,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    TigerButton(
                      label: 'SIGN IN',
                      icon: Icons.login,
                      onPressed: onSignIn,
                    ),
                    const SizedBox(height: 10),
                    TigerButton(
                      label: 'CREATE MEMBER ACCOUNT',
                      icon: Icons.person_add,
                      secondary: true,
                      onPressed: onSignUp,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─── CHROME ─────────────────────────────────────────────────────────

class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final on = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
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
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.filled,
    required this.onTap,
  });

  final String label;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          height: 46,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: filled
                ? const LinearGradient(
                    colors: [
                      Color(0xFFE5C180),
                      Color(0xFFC5A059),
                      Color(0xFF8E6E35),
                    ],
                  )
                : null,
            color: filled ? null : const Color(0xE6080400),
            border: filled
                ? null
                : Border.all(
                    color: AppColors.goldBrushed.withValues(alpha: 0.45),
                  ),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
                color: filled ? const Color(0xFF120A00) : AppColors.goldBright,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      ),
    );
  }
}
