import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../utils/time_animation.dart';
import 'animated_time_display.dart';
import '../../models/drink_delivery_alert.dart';
import '../../models/drink_order.dart';

/// Guest-facing drink order animations.
abstract final class DrinkOrderOverlay {
  /// Shown immediately after the guest sends an order to the bar.
  static Future<void> showOrderPlaced(
    BuildContext context, {
    required String drinkName,
    required DrinkChargeSource chargeSource,
    required int costSeconds,
  }) async {
    await showGeneralDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.88),
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (_, _, _) => _OrderPlacedDialog(
        drinkName: drinkName,
        chargeSource: chargeSource,
        costSeconds: costSeconds,
      ),
      transitionBuilder: (_, anim, _, child) {
        return FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: Tween(
              begin: 0.9,
              end: 1.0,
            ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutBack)),
            child: child,
          ),
        );
      },
    );
  }

  /// Full celebration when the bartender marks the drink delivered.
  static Future<void> showDelivered(
    BuildContext context, {
    required DrinkDeliveryAlert alert,
  }) async {
    HapticFeedback.heavyImpact();
    await showGeneralDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      barrierLabel: 'Delivered',
      barrierColor: Colors.black.withValues(alpha: 0.92),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (_, _, _) => _DeliveredDialog(alert: alert),
      transitionBuilder: (_, anim, _, child) {
        return FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position:
                Tween<Offset>(
                  begin: const Offset(0, 0.08),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
                ),
            child: child,
          ),
        );
      },
    );

    if (!context.mounted) return;

    await _showSettlement(context, alert: alert);
  }

  static Future<void> _showSettlement(
    BuildContext context, {
    required DrinkDeliveryAlert alert,
  }) async {
    await showGeneralDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      barrierLabel: 'Drink charge settled',
      barrierColor: Colors.black.withValues(alpha: 0.94),
      transitionDuration: const Duration(milliseconds: 360),
      pageBuilder: (_, _, _) => _SettlementDialog(alert: alert),
      transitionBuilder: (_, anim, _, child) {
        final curved = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween(begin: 0.94, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
  }
}

class _OrderPlacedDialog extends StatefulWidget {
  const _OrderPlacedDialog({
    required this.drinkName,
    required this.chargeSource,
    required this.costSeconds,
  });

  final String drinkName;
  final DrinkChargeSource chargeSource;
  final int costSeconds;

  @override
  State<_OrderPlacedDialog> createState() => _OrderPlacedDialogState();
}

class _OrderPlacedDialogState extends State<_OrderPlacedDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sway;
  Timer? _autoClose;

  @override
  void initState() {
    super.initState();
    HapticFeedback.mediumImpact();
    _sway = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _autoClose = Timer(const Duration(milliseconds: 2800), _close);
  }

  @override
  void dispose() {
    _autoClose?.cancel();
    _sway.dispose();
    super.dispose();
  }

  void _close() {
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  String get _chargeHint {
    if (widget.chargeSource == DrinkChargeSource.cashAtBar) {
      return 'Settle at the bar when it arrives';
    }
    if (widget.chargeSource == DrinkChargeSource.packageAllowance) {
      return 'Package drink · charged when served';
    }
    if (widget.costSeconds <= 0) return 'Charged when bartender serves';
    return '−${widget.costSeconds ~/ 60} min · charged when served';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: _close,
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _sway,
                  builder: (context, child) {
                    final t = _sway.value;
                    return Transform.rotate(
                      angle: (t - 0.5) * 0.12,
                      child: Transform.translate(
                        offset: Offset(0, math.sin(t * math.pi * 2) * 4),
                        child: child,
                      ),
                    );
                  },
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.goldBright.withValues(alpha: 0.12),
                      border: Border.all(
                        color: AppColors.goldBright.withValues(alpha: 0.5),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.goldBright.withValues(alpha: 0.2),
                          blurRadius: 24,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.local_bar,
                      color: AppColors.goldBright,
                      size: 44,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'SENT TO BAR',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.goldBright,
                    letterSpacing: 2,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.drinkName,
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.headlineMedium?.copyWith(fontSize: 22),
                ),
                const SizedBox(height: 10),
                Text(
                  'Waiting for your bartender to pour & serve…',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.darkSteel,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.neutral500),
                  ),
                  child: Text(
                    _chargeHint,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.offWhite,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const _PulseDots(),
                const SizedBox(height: 16),
                Text(
                  'TAP TO CONTINUE',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontSize: 9,
                    letterSpacing: 2,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DeliveredDialog extends StatefulWidget {
  const _DeliveredDialog({required this.alert});

  final DrinkDeliveryAlert alert;

  @override
  State<_DeliveredDialog> createState() => _DeliveredDialogState();
}

class _DeliveredDialogState extends State<_DeliveredDialog>
    with TickerProviderStateMixin {
  late final AnimationController _enter;
  late final AnimationController _sparkle;
  late final Animation<double> _glassScale;
  late final Animation<double> _fade;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _sparkle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _glassScale = CurvedAnimation(parent: _enter, curve: Curves.elasticOut);
    _fade = CurvedAnimation(
      parent: _enter,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
    );
    _enter.forward();
    Timer(const Duration(milliseconds: 2600), _close);
  }

  @override
  void dispose() {
    _enter.dispose();
    _sparkle.dispose();
    super.dispose();
  }

  void _close() {
    if (_done || !mounted) return;
    _done = true;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final alert = widget.alert;
    final bartender = alert.bartenderName ?? 'Your bartender';

    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: _close,
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScaleTransition(
                  scale: Tween<double>(
                    begin: 0.2,
                    end: 1.0,
                  ).animate(_glassScale),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: _sparkle,
                        builder: (context, _) {
                          return CustomPaint(
                            size: const Size(120, 120),
                            painter: _SparklePainter(_sparkle.value),
                          );
                        },
                      ),
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              AppColors.timerNeon.withValues(alpha: 0.35),
                              AppColors.tigerRed.withValues(alpha: 0.15),
                            ],
                          ),
                          border: Border.all(color: AppColors.timerNeon),
                        ),
                        child: const Icon(
                          Icons.check_circle,
                          color: AppColors.timerNeon,
                          size: 48,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                FadeTransition(
                  opacity: _fade,
                  child: Column(
                    children: [
                      Text(
                        'DELIVERED!',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppColors.timerNeon,
                          letterSpacing: 2.5,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        alert.drinkName,
                        textAlign: TextAlign.center,
                        style: Theme.of(
                          context,
                        ).textTheme.headlineMedium?.copyWith(fontSize: 24),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$bartender just served your round.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 12,
                          color: AppColors.goldBright,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'TAP TO CONTINUE',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontSize: 9,
                          letterSpacing: 2,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettlementDialog extends StatefulWidget {
  const _SettlementDialog({required this.alert});

  final DrinkDeliveryAlert alert;

  @override
  State<_SettlementDialog> createState() => _SettlementDialogState();
}

class _SettlementDialogState extends State<_SettlementDialog>
    with TickerProviderStateMixin {
  late final AnimationController _enter;
  late final AnimationController _glow;
  Timer? _autoClose;
  bool _done = false;

  DrinkDeliveryAlert get alert => widget.alert;

  Color get _accent => switch (alert.chargeSource) {
    DrinkChargeSource.packageAllowance => AppColors.timerHealthy,
    DrinkChargeSource.cashAtBar => AppColors.goldBright,
    _ => AppColors.timerCritical,
  };

  IconData get _icon => switch (alert.chargeSource) {
    DrinkChargeSource.personalTime => Icons.hourglass_bottom_rounded,
    DrinkChargeSource.eventWallet => Icons.celebration_rounded,
    DrinkChargeSource.vipRoomTab => Icons.diamond_rounded,
    DrinkChargeSource.packageAllowance => Icons.redeem_rounded,
    DrinkChargeSource.cashAtBar => Icons.payments_rounded,
  };

  @override
  void initState() {
    super.initState();
    HapticFeedback.mediumImpact();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    )..forward();
    _glow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    final from = alert.deductionFromSeconds;
    final to = alert.deductionToSeconds;
    final animationDuration = from != null && to != null
        ? TimeAnimation.durationForDelta(to - from)
        : const Duration(milliseconds: 1600);
    _autoClose = Timer(
      animationDuration + const Duration(milliseconds: 1900),
      _close,
    );
  }

  @override
  void dispose() {
    _autoClose?.cancel();
    _enter.dispose();
    _glow.dispose();
    super.dispose();
  }

  void _close() {
    if (_done || !mounted) return;
    _done = true;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final from = alert.deductionFromSeconds;
    final to = alert.deductionToSeconds;

    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: _close,
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: FadeTransition(
              opacity: CurvedAnimation(parent: _enter, curve: Curves.easeOut),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: _glow,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: 0.96 + (_glow.value * 0.07),
                        child: Container(
                          width: 82,
                          height: 82,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _accent.withValues(alpha: 0.12),
                            border: Border.all(
                              color: _accent.withValues(
                                alpha: 0.55 + (_glow.value * 0.35),
                              ),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _accent.withValues(
                                  alpha: 0.2 + (_glow.value * 0.18),
                                ),
                                blurRadius: 26 + (_glow.value * 14),
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: child,
                        ),
                      );
                    },
                    child: Icon(_icon, color: _accent, size: 40),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    alert.settlementTitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: _accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    alert.drinkName,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppColors.offWhite,
                      fontSize: 23,
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (alert.showsTimeDeduction) ...[
                    Text(
                      alert.settlementAmountLabel,
                      style: TextStyle(
                        color: _accent,
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        shadows: AppColors.timerGlow(_accent),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (from != null && to != null)
                      AnimatedTimeDisplay(
                        initialSeconds: from,
                        seconds: to,
                        color: _accent,
                        fontSize: 48,
                        animateDecreases: true,
                      )
                    else
                      Text(
                        'SETTLED',
                        style: TextStyle(
                          color: _accent,
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3,
                        ),
                      ),
                  ] else if (alert.chargeSource ==
                      DrinkChargeSource.packageAllowance) ...[
                    TweenAnimationBuilder<double>(
                      tween: Tween(
                        begin:
                            (alert.packageDrinksRemaining ?? 0).toDouble() + 1,
                        end: (alert.packageDrinksRemaining ?? 0).toDouble(),
                      ),
                      duration: const Duration(milliseconds: 1300),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) => Text(
                        value.round().toString(),
                        style: TextStyle(
                          color: _accent,
                          fontSize: 58,
                          fontWeight: FontWeight.w900,
                          shadows: AppColors.timerGlow(_accent),
                        ),
                      ),
                    ),
                    Text(
                      'INCLUDED DRINKS REMAINING',
                      style: TextStyle(
                        color: _accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.6,
                      ),
                    ),
                  ] else ...[
                    Text(
                      'NO TIME DEDUCTED',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _accent,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        shadows: AppColors.timerGlow(_accent),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: _accent.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _accent.withValues(alpha: 0.38),
                      ),
                    ),
                    child: Text(
                      alert.walletSourceLabel,
                      style: TextStyle(
                        color: _accent,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    alert.settlementDetail,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'TAP TO CONTINUE',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontSize: 9,
                      letterSpacing: 2,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PulseDots extends StatefulWidget {
  const _PulseDots();

  @override
  State<_PulseDots> createState() => _PulseDotsState();
}

class _PulseDotsState extends State<_PulseDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = (_ctrl.value + i * 0.2) % 1.0;
            final opacity = 0.35 + (math.sin(phase * math.pi) * 0.65);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Opacity(
                opacity: opacity.clamp(0.0, 1.0),
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppColors.goldBright,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _SparklePainter extends CustomPainter {
  _SparklePainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..color = AppColors.timerNeon.withValues(alpha: 0.7);
    for (var i = 0; i < 8; i++) {
      final angle = (i / 8) * math.pi * 2 + progress * math.pi * 2;
      final radius = 34 + math.sin(progress * math.pi * 2 + i) * 6;
      final alpha = 0.25 + math.sin(progress * math.pi * 2 + i * 0.7) * 0.35;
      paint.color = AppColors.timerNeon.withValues(
        alpha: alpha.clamp(0.0, 1.0),
      );
      final pos =
          center + Offset(math.cos(angle) * radius, math.sin(angle) * radius);
      canvas.drawCircle(pos, 3, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SparklePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
