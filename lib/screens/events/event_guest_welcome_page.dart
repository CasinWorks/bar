import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/lattice_background.dart';
import '../../models/event_guest_welcome_alert.dart';

/// Full-screen welcome the guest sees the moment the door scans them into an
/// event. Opaque and CTA-dismissed only — this is the payoff of the invite and
/// must not fade away before the guest looks at their phone.
Future<void> showEventGuestWelcomePage(
  BuildContext context, {
  required EventGuestWelcomeAlert alert,
}) async {
  HapticFeedback.heavyImpact();
  unawaited(HapticFeedback.vibrate());
  await Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: true,
      fullscreenDialog: true,
      transitionDuration: const Duration(milliseconds: 420),
      pageBuilder: (_, _, _) => EventGuestWelcomePage(alert: alert),
      transitionsBuilder: (_, anim, _, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: Tween(begin: 0.82, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    ),
  );
}

class EventGuestWelcomePage extends StatefulWidget {
  const EventGuestWelcomePage({super.key, required this.alert});

  final EventGuestWelcomeAlert alert;

  @override
  State<EventGuestWelcomePage> createState() => _EventGuestWelcomePageState();
}

class _EventGuestWelcomePageState extends State<EventGuestWelcomePage>
    with TickerProviderStateMixin {
  late final AnimationController _pulse;
  late final AnimationController _burst;
  Timer? _secondHaptic;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _burst = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _secondHaptic = Timer(const Duration(milliseconds: 280), () {
      HapticFeedback.mediumImpact();
    });
  }

  @override
  void dispose() {
    _secondHaptic?.cancel();
    _pulse.dispose();
    _burst.dispose();
    super.dispose();
  }

  void _close() {
    if (!mounted) return;
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final alert = widget.alert;
    final theme = Theme.of(context);
    final greeting = alert.greetingName;

    return Scaffold(
      backgroundColor: AppColors.matteBlack,
      body: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _burst,
            builder: (context, _) {
              return CustomPaint(
                size: MediaQuery.sizeOf(context),
                painter: _BurstPainter(
                  progress: Curves.easeOut.transform(_burst.value),
                ),
              );
            },
          ),
          SafeArea(
            // Centred when it fits, scrollable when a long title or a large
            // font scale needs more room than the phone has.
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 24,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: math.max(0, constraints.maxHeight - 48),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _pulsingSeal(),
                      const SizedBox(height: 28),
                      Text(
                        greeting == null
                            ? "YOU'RE IN"
                            : "YOU'RE IN, ${greeting.toUpperCase()}",
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontSize: 11,
                          letterSpacing: 3,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        alert.shout,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineLarge?.copyWith(
                          color: AppColors.goldBright,
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        alert.eventTitle,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontSize: 24,
                          height: 1.2,
                          color: AppColors.offWhite,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _detailCard(theme, alert),
                      const SizedBox(height: 18),
                      Text(
                        alert.body,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 14,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 36),
                      TigerButton(
                        label: alert.ctaLabel,
                        icon: Icons.celebration,
                        onPressed: _close,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pulsingSeal() {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final t = _pulse.value;
        return Transform.scale(
          scale: 1.0 + t * 0.06,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.goldBright.withValues(
                    alpha: 0.28 + t * 0.35,
                  ),
                  blurRadius: 36 + t * 28,
                  spreadRadius: 4 + t * 8,
                ),
                BoxShadow(
                  color: AppColors.tigerRed.withValues(alpha: 0.18 + t * 0.12),
                  blurRadius: 48 + t * 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: Container(
        width: 112,
        height: 112,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.goldBright.withValues(alpha: 0.35),
              AppColors.tigerRed.withValues(alpha: 0.22),
            ],
          ),
          border: Border.all(
            color: AppColors.goldBright.withValues(alpha: 0.75),
            width: 2,
          ),
        ),
        child: const Icon(
          Icons.celebration,
          color: AppColors.goldBright,
          size: 52,
        ),
      ),
    );
  }

  Widget _detailCard(ThemeData theme, EventGuestWelcomeAlert alert) {
    final branch = alert.branch?.trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.goldBright.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.goldBright.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          _detailRow(theme, 'HOSTED BY', alert.hostName),
          if (branch != null && branch.isNotEmpty) ...[
            const SizedBox(height: 10),
            _detailRow(theme, 'VENUE', branch),
          ],
        ],
      ),
    );
  }

  Widget _detailRow(ThemeData theme, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            fontSize: 10,
            letterSpacing: 1.6,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: theme.textTheme.titleSmall?.copyWith(
              color: AppColors.offWhite,
            ),
          ),
        ),
      ],
    );
  }
}

class _BurstPainter extends CustomPainter {
  _BurstPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final center = Offset(size.width / 2, size.height / 2 - 40);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = AppColors.goldBright.withValues(alpha: (1 - progress) * 0.55);

    final radius = 40 + progress * 160;
    canvas.drawCircle(center, radius, paint);
    canvas.drawCircle(
      center,
      radius * 0.62,
      paint
        ..color = AppColors.tigerRed.withValues(alpha: (1 - progress) * 0.35),
    );

    final spark = Paint()
      ..style = PaintingStyle.fill
      ..color = AppColors.goldBright.withValues(alpha: (1 - progress) * 0.7);
    for (var i = 0; i < 10; i++) {
      final angle = (i / 10) * math.pi * 2;
      final dist = 70 + progress * 130;
      final p = Offset(
        center.dx + math.cos(angle) * dist,
        center.dy + math.sin(angle) * dist,
      );
      canvas.drawCircle(p, 3.2 * (1 - progress * 0.4), spark);
    }
  }

  @override
  bool shouldRepaint(covariant _BurstPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
