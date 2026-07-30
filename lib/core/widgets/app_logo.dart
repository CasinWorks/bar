import 'package:flutter/material.dart';

/// Blind Tiger brand mark from [assetPath].
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 40, this.fit = BoxFit.contain});

  static const assetPath = 'assets/images/logo.png';

  final double size;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        assetPath,
        fit: fit,
        filterQuality: FilterQuality.high,
        semanticLabel: 'Blind Tiger logo',
      ),
    );
  }
}
