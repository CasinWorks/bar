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
  void didUpdateWidget(_GradientLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.animate && _controller.isAnimating) {
      _controller.stop();
    }
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
            colors: [AppColors.microclubBg, AppColors.matteBlack],
          ),
        ),
      );
    }

    if (!widget.animate) {
      return const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1A0808),
              AppColors.matteBlack,
              Color(0xFF0A0505),
            ],
            stops: [0.0, 0.55, 1.0],
          ),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final top = Color.lerp(
          const Color(0xFF1A0808),
          const Color(0xFF2A0C0C),
          t,
        )!;
        final mid = Color.lerp(
          AppColors.matteBlack,
          const Color(0xFF120808),
          t,
        )!;
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-0.2 + t * 0.4, -1),
              end: Alignment(0.2 - t * 0.4, 1),
              colors: [top, mid, const Color(0xFF0A0505)],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}

class _LatticePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.tigerRed.withValues(alpha: 0.05)
      ..strokeWidth = 0.7
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
        colors: [AppColors.tigerRed, Color(0xFFE85A5F), AppColors.bloodRed],
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
          colors: [AppColors.charcoal, Color(0xFF120808)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: highlighted
              ? AppColors.tigerRed
              : AppColors.darkSteel,
          width: highlighted ? 1.5 : 1,
        ),
        boxShadow: highlighted
            ? [
                BoxShadow(
                  color: AppColors.tigerRed.withValues(alpha: 0.35),
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
      height: 48,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: secondary
              ? null
              : const LinearGradient(
                  colors: [AppColors.tigerRed, AppColors.bloodRed],
                ),
          color: secondary ? AppColors.darkSteel : null,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: secondary
                ? AppColors.darkSteel
                : AppColors.tigerRed.withValues(alpha: 0.6),
          ),
          boxShadow: secondary
              ? null
              : [
                  BoxShadow(
                    color: AppColors.tigerRed.withValues(alpha: 0.4),
                    blurRadius: 14,
                  ),
                ],
        ),
        child: ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: AppColors.offWhite,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.offWhite,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 6)],
                    Text(
                      label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
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
