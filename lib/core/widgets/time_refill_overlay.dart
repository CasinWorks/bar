import 'dart:async';

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../utils/time_animation.dart';
import 'animated_time_display.dart';

/// Full-screen time refill / spend animation after buy, tip, or order.
class TimeRefillOverlay {
  static Future<void> show(
    BuildContext context, {
    required int fromSeconds,
    required int toSeconds,
    String? title,
    String? subtitle,
  }) async {
    final delta = toSeconds - fromSeconds;
    if (delta == 0) return;

    await showGeneralDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.88),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (ctx, _, _) => _TimeRefillDialog(
        fromSeconds: fromSeconds,
        toSeconds: toSeconds,
        title: title,
        subtitle: subtitle,
      ),
      transitionBuilder: (ctx, anim, _, child) {
        return FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: Tween(
              begin: 0.92,
              end: 1.0,
            ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutBack)),
            child: child,
          ),
        );
      },
    );
  }
}

class _TimeRefillDialog extends StatefulWidget {
  const _TimeRefillDialog({
    required this.fromSeconds,
    required this.toSeconds,
    this.title,
    this.subtitle,
  });

  final int fromSeconds;
  final int toSeconds;
  final String? title;
  final String? subtitle;

  @override
  State<_TimeRefillDialog> createState() => _TimeRefillDialogState();
}

class _TimeRefillDialogState extends State<_TimeRefillDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _pulseScale;
  bool _done = false;
  Timer? _safetyTimer;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseScale = Tween(
      begin: 0.97,
      end: 1.05,
    ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));

    final expected = TimeAnimation.durationForDelta(
      widget.toSeconds - widget.fromSeconds,
    );
    // Never leave the pour stuck — dismiss even if the tween fails to complete.
    _safetyTimer = Timer(
      expected + const Duration(milliseconds: 1600),
      _onComplete,
    );
  }

  @override
  void dispose() {
    _safetyTimer?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  void _onComplete() {
    if (_done) return;
    _done = true;
    _safetyTimer?.cancel();
    Future<void>.delayed(const Duration(milliseconds: 420), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final delta = widget.toSeconds - widget.fromSeconds;
    final increasing = delta > 0;
    final accent = increasing ? AppColors.timerNeon : AppColors.timerCritical;
    final label = increasing ? 'TIME LOADED' : 'TIME SPENT';

    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _onComplete,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScaleTransition(
                  scale: _pulseScale,
                  child: Icon(
                    increasing ? Icons.bolt : Icons.local_bar,
                    color: accent,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.title ?? label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: accent,
                    letterSpacing: 2,
                    fontSize: 12,
                  ),
                ),
                if (widget.subtitle != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    widget.subtitle!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 12,
                      color: AppColors.goldBright.withValues(alpha: 0.85),
                      letterSpacing: 0.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: accent.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    TimeAnimation.formatDelta(delta),
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                AnimatedTimeDisplay(
                  initialSeconds: widget.fromSeconds,
                  seconds: widget.toSeconds,
                  color: accent,
                  fontSize: 52,
                  animateDecreases: true,
                  onAnimationComplete: _onComplete,
                ),
                const SizedBox(height: 8),
                Text(
                  increasing ? 'Balance increasing…' : 'Balance decreasing…',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 10,
                    color: AppColors.textMuted,
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
        ),
      ),
    );
  }
}
