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

  static Color timerColor(Duration remaining, {bool isCheckedIn = true}) {
    if (!isCheckedIn) return goldBright;
    final minutes = remaining.inMinutes;
    if (minutes < 5) return dangerRed;
    if (minutes < 15) return warningYellow;
    return successGreen;
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
