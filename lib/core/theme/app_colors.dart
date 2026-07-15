import 'package:flutter/material.dart';

abstract final class AppColors {
  // Blind Tiger palette
  static const crimsonDeep = Color(0xFF2A0000);
  static const crimsonRich = Color(0xFF4D0000);
  static const crimson = Color(0xFF8B0000);
  static const crimsonBright = Color(0xFFB22222);
  static const goldBrushed = Color(0xFFC5A059);
  static const goldBright = Color(0xFFE5C180);
  static const goldDark = Color(0xFF8E6E35);
  static const tigerOrange = Color(0xFFD97706);
  static const darkBackground = Color(0xFF050200);
  static const cardSurface = Color(0xFF1C0F00);
  static const cardBorder = Color(0x33C5A059);
  static const microclubPurple = Color(0xFF7C3AED);
  static const microclubBg = Color(0xFF180330);
  static const vvipAmethyst = Color(0xFFB794F6);
  static const vvipDeep = Color(0xFF2D1B4E);
  static const successGreen = Color(0xFF2ECC71);
  static const dangerRed = Color(0xFFFF6B6B);
  static const warningYellow = Color(0xFFF39C12);
  static const textLight = Color(0xFFF5F5F5);
  static const textMuted = Color(0xFFA3A3A3);
  static const neutral400 = Color(0xFFA3A3A3);
  static const neutral500 = Color(0xFF737373);
  static const neutral900 = Color(0xFF171717);
  static const neutral950 = Color(0xFF0A0A0A);

  /// In Time — neon green clock (not yellow/chartreuse).
  static const timerNeon = Color(0xFF39FF14);
  static const timerNeonCore = Color(0xFF7CFF66);
  static const timerNeonGlow = Color(0xFF00E676);
  static const timerNeonDeep = Color(0xFF00C853);
  static const timerWarning = Color(0xFFFFE566);
  static const timerCritical = Color(0xFFFF3B3B);

  static Color timerColor(Duration remaining, {bool isCheckedIn = true}) {
    if (!isCheckedIn) return timerNeon;
    final minutes = remaining.inMinutes;
    if (minutes < 5) return timerCritical;
    if (minutes < 15) return timerWarning;
    return timerNeon;
  }

  /// Soft outer glow for digital timer digits (In Time look).
  static List<Shadow> timerGlow(Color color, {double intensity = 1}) {
    final i = intensity.clamp(0.4, 1.6);
    return [
      Shadow(color: color.withValues(alpha: 0.95 * i), blurRadius: 2 * i),
      Shadow(color: color.withValues(alpha: 0.75 * i), blurRadius: 8 * i),
      Shadow(color: color.withValues(alpha: 0.45 * i), blurRadius: 18 * i),
      Shadow(color: color.withValues(alpha: 0.22 * i), blurRadius: 32 * i),
    ];
  }

  static String timerLabel(Duration remaining, {bool isCheckedIn = true}) {
    if (!isCheckedIn) return 'FROZEN';
    final minutes = remaining.inMinutes;
    if (minutes < 5) return 'CRITICAL';
    if (minutes < 15) return 'WARNING';
    return 'HEALTHY';
  }

  static String tierFromSeconds(int seconds) {
    if (seconds >= 100 * 3600) return 'VVIP';
    if (seconds >= 10800) return 'Platinum';
    if (seconds >= 5400) return 'Gold';
    if (seconds >= 2700) return 'Silver';
    return 'Bronze';
  }
}
