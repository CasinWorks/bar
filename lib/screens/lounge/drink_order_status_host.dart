import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../models/drink_order.dart';
import '../../providers/app_state.dart';

/// Persistent top pill while guest drink orders are pending or being poured.
/// Visible across the lounge even when the timer header is collapsed.
class DrinkOrderStatusHost extends StatelessWidget {
  const DrinkOrderStatusHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, app, _) {
        final orders = app.activeDrinkOrders;
        final visible = app.isInsideClub && !app.isStaff && orders.isNotEmpty;

        return Stack(
          children: [
            child,
            if (visible)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: _DrinkStatusPill(
                        key: ValueKey(
                          orders
                              .map((o) => '${o.id}:${o.status.name}')
                              .join(','),
                        ),
                        orders: orders,
                      ),
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

class _DrinkStatusPill extends StatefulWidget {
  const _DrinkStatusPill({super.key, required this.orders});

  final List<DrinkOrder> orders;

  @override
  State<_DrinkStatusPill> createState() => _DrinkStatusPillState();
}

class _DrinkStatusPillState extends State<_DrinkStatusPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  DrinkOrder get _primary {
    final preparing = widget.orders
        .where((o) => o.status == DrinkOrderStatus.preparing)
        .toList();
    if (preparing.isNotEmpty) return preparing.first;
    return widget.orders.first;
  }

  @override
  Widget build(BuildContext context) {
    final primary = _primary;
    final preparing = primary.status == DrinkOrderStatus.preparing;
    final accent = preparing ? AppColors.tigerOrange : AppColors.goldBright;
    final extra = widget.orders.length - 1;

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        return Container(
          constraints: const BoxConstraints(maxWidth: 360),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: accent.withValues(alpha: 0.4 + _pulse.value * 0.2),
              width: 1.15,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(
                  AppColors.charcoal,
                  accent,
                  0.1 + _pulse.value * 0.04,
                )!,
                AppColors.matteBlack,
                const Color(0xFF0A0404),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.18 + _pulse.value * 0.1),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: child,
        );
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            preparing ? Icons.water_drop_rounded : Icons.local_bar_rounded,
            size: 18,
            color: accent,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'DRINK ON THE WAY',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6,
                    color: AppColors.goldBrushed,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  extra > 0
                      ? '${primary.drinkName} · ${primary.status.label} (+$extra)'
                      : '${primary.drinkName} · ${primary.status.label}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textLight,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          _PulseDots(color: accent),
        ],
      ),
    );
  }
}

class _PulseDots extends StatelessWidget {
  const _PulseDots({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return _PulseDotsAnimated(color: color);
  }
}

class _PulseDotsAnimated extends StatefulWidget {
  const _PulseDotsAnimated({required this.color});

  final Color color;

  @override
  State<_PulseDotsAnimated> createState() => _PulseDotsAnimatedState();
}

class _PulseDotsAnimatedState extends State<_PulseDotsAnimated>
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
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: Opacity(
                opacity: opacity.clamp(0.0, 1.0),
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: widget.color,
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
