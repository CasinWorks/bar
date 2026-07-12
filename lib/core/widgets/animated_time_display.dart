import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../utils/time_animation.dart';

/// Counts up or down between two time values; speed depends on the delta.
class AnimatedTimeDisplay extends StatefulWidget {
  const AnimatedTimeDisplay({
    super.key,
    required this.seconds,
    this.initialSeconds,
    this.color,
    this.fontSize = 48,
    this.fontWeight = FontWeight.w900,
    this.letterSpacing = 2,
    this.onAnimationComplete,
  });

  final int seconds;
  final int? initialSeconds;
  final Color? color;
  final double fontSize;
  final FontWeight fontWeight;
  final double letterSpacing;
  final VoidCallback? onAnimationComplete;

  @override
  State<AnimatedTimeDisplay> createState() => _AnimatedTimeDisplayState();
}

class _AnimatedTimeDisplayState extends State<AnimatedTimeDisplay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _tween;
  late int _from;
  late int _to;

  @override
  void initState() {
    super.initState();
    final start = widget.initialSeconds ?? widget.seconds;
    _from = start;
    _to = widget.seconds;
    _controller = AnimationController(vsync: this, duration: Duration.zero);
    _tween = AlwaysStoppedAnimation(start.toDouble());
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onAnimationComplete?.call();
      }
    });

    if (widget.initialSeconds != null && widget.initialSeconds != widget.seconds) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _animateTo(widget.seconds);
      });
    }
  }

  @override
  void didUpdateWidget(AnimatedTimeDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seconds != widget.seconds) {
      _animateTo(widget.seconds);
    }
  }

  void _animateTo(int target) {
    _from = _tween.value.round();
    _to = target;
    final delta = _to - _from;
    if (delta == 0) return;

    // Per-second lounge countdown — update instantly.
    if (delta <= 0 || delta.abs() < 5) {
      _tween = AlwaysStoppedAnimation(_to.toDouble());
      _controller.stop();
      setState(() {});
      return;
    }

    // Only animate time being added — decreases snap to avoid false spend loops.
    if (delta < 0) {
      _tween = AlwaysStoppedAnimation(_to.toDouble());
      _controller.stop();
      setState(() {});
      return;
    }

    _controller.duration = TimeAnimation.durationForDelta(delta);
    _tween = Tween<double>(begin: _from.toDouble(), end: _to.toDouble()).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? AppColors.successGreen;

    return AnimatedBuilder(
      animation: _tween,
      builder: (context, _) {
        final current = _tween.value.round();
        final display = TimeAnimation.formatClock(current);
        final fs = current >= 3600 ? widget.fontSize * 0.85 : widget.fontSize;

        return Text(
          display,
          style: GoogleFonts.shareTechMono(
            fontSize: fs,
            fontWeight: widget.fontWeight,
            color: color,
            letterSpacing: widget.letterSpacing,
          ),
        );
      },
    );
  }
}
