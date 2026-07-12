import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class LatticeBackground extends StatelessWidget {
  const LatticeBackground({
    super.key,
    required this.child,
    this.animate = false,
    this.isMidnight = false,
  });

  final Widget child;
  final bool animate;
  final bool isMidnight;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _GradientLayer(animate: animate, isMidnight: isMidnight),
        CustomPaint(painter: _LatticePainter(), child: const SizedBox.expand()),
        child,
      ],
    );
  }
}

class _GradientLayer extends StatefulWidget {
  const _GradientLayer({required this.animate, required this.isMidnight});

  final bool animate;
  final bool isMidnight;

  @override
  State<_GradientLayer> createState() => _GradientLayerState();
}

class _GradientLayerState extends State<_GradientLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );
    if (widget.animate) _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isMidnight) {
      return const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.microclubBg, AppColors.darkBackground],
          ),
        ),
      );
    }

    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1C0500), AppColors.darkBackground, Color(0xFF0A0000)],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
    );
  }
}

class _LatticePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.goldBrushed.withValues(alpha: 0.06)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    const spacing = 40.0;
    for (var x = 0.0; x < size.width + spacing; x += spacing) {
      for (var y = 0.0; y < size.height + spacing; y += spacing) {
        final cx = x;
        final cy = y;
        final path = Path()
          ..moveTo(cx, cy + spacing / 2)
          ..lineTo(cx + spacing / 2, cy)
          ..lineTo(cx + spacing, cy + spacing / 2)
          ..lineTo(cx + spacing / 2, cy + spacing)
          ..close()
          ..moveTo(cx + spacing / 2, cy + spacing / 4)
          ..lineTo(cx + spacing * 0.75, cy + spacing / 2)
          ..lineTo(cx + spacing / 2, cy + spacing * 0.75)
          ..lineTo(cx + spacing / 4, cy + spacing / 2)
          ..close();
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class GoldGradientText extends StatelessWidget {
  const GoldGradientText(this.text, {super.key, this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        colors: [AppColors.goldBright, AppColors.goldBrushed, AppColors.goldDark],
      ).createShader(bounds),
      child: Text(
        text,
        style: (style ?? Theme.of(context).textTheme.headlineLarge)?.copyWith(
              color: Colors.white,
            ),
      ),
    );
  }
}

class LuxuryCard extends StatelessWidget {
  const LuxuryCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.highlighted = false,
  });

  final Widget child;
  final EdgeInsets padding;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1C0A00), Color(0xFF050000)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: highlighted
              ? AppColors.goldBrushed
              : AppColors.goldBrushed.withValues(alpha: 0.2),
          width: highlighted ? 1.5 : 1,
        ),
        boxShadow: highlighted
            ? [
                BoxShadow(
                  color: AppColors.crimson.withValues(alpha: 0.35),
                  blurRadius: 20,
                ),
              ]
            : null,
      ),
      child: child,
    );
  }
}

class TigerButton extends StatelessWidget {
  const TigerButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.secondary = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool secondary;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: secondary
              ? null
              : const LinearGradient(
                  colors: [Color(0xFFB45309), AppColors.crimson],
                ),
          color: secondary ? AppColors.neutral900 : null,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.goldBrushed.withValues(alpha: 0.4),
          ),
          boxShadow: secondary
              ? null
              : [
                  BoxShadow(
                    color: AppColors.crimson.withValues(alpha: 0.35),
                    blurRadius: 12,
                  ),
                ],
        ),
        child: ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: secondary ? AppColors.textLight : AppColors.goldBright,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 6)],
                    Text(
                      label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
