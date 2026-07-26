import 'package:flutter/material.dart';

/// Blind Tiger Club District brand palette.
abstract final class AppColors {
  // Primary brand
  static const tigerRed = Color(0xFFD4252B);
  static const bloodRed = Color(0xFF800000);
  static const matteBlack = Color(0xFF0E0E0E);
  static const charcoal = Color(0xFF1A1A1A);
  static const darkSteel = Color(0xFF2B2B2B);
  static const antiqueGold = Color(0xFF8B6C32);
  static const offWhite = Color(0xFFF5F5F5);

  // Legacy aliases → brand (keep call sites compiling during migration)
  static const crimsonDeep = Color(0xFF1A0000);
  static const crimsonRich = bloodRed;
  static const crimson = tigerRed;
  static const crimsonBright = tigerRed;
  static const goldBrushed = antiqueGold;
  static const goldBright = Color(0xFFB8924A);
  static const goldDark = Color(0xFF6B5226);
  static const tigerOrange = tigerRed;
  static const darkBackground = matteBlack;
  static const cardSurface = charcoal;
  static const cardBorder = Color(0x33D4252B);

  // VIP / rooms — steel + red, not purple
  static const microclubPurple = tigerRed;
  static const microclubBg = Color(0xFF140808);
  static const vvipAmethyst = goldBright;
  static const vvipDeep = Color(0xFF1C1010);

  static const successGreen = Color(0xFF2ECC71);
  static const dangerRed = Color(0xFFE74C3C);
  static const warningYellow = Color(0xFFF1C40F);
  static const textLight = offWhite;
  static const textMuted = Color(0xFFA3A3A3);
  static const neutral400 = Color(0xFFA3A3A3);
  static const neutral500 = Color(0xFF737373);
  static const neutral900 = darkSteel;
  static const neutral950 = matteBlack;

  /// Battery-style time bands (psychology board).
  static const timerHealthy = Color(0xFF2ECC71); // 180–121 min
  static const timerCaution = Color(0xFFF1C40F); // 120–31 min
  static const timerLow = tigerRed; // ≤30 min

  // Legacy timer names → battery bands
  static const timerNeon = timerHealthy;
  static const timerNeonCore = Color(0xFF58D68D);
  static const timerNeonGlow = Color(0xFF27AE60);
  static const timerNeonDeep = Color(0xFF1E8449);
  static const timerWarning = timerCaution;
  static const timerCritical = timerLow;

  /// Battery psychology: green 180–121, yellow 120–31, red ≤30.
  static Color timerColor(Duration remaining, {bool isCheckedIn = true}) {
    if (!isCheckedIn) return timerHealthy;
    return timerBandColor(remaining.inMinutes);
  }

  static Color timerBandColor(int minutesRemaining) {
    if (minutesRemaining <= 30) return timerLow;
    if (minutesRemaining <= 120) return timerCaution;
    return timerHealthy;
  }

  static TimerBand timerBand(int minutesRemaining) {
    if (minutesRemaining <= 30) return TimerBand.low;
    if (minutesRemaining <= 120) return TimerBand.caution;
    return TimerBand.healthy;
  }

  static List<Shadow> timerGlow(Color color, {double intensity = 1}) {
    final i = intensity.clamp(0.4, 1.6);
    return [
      Shadow(color: color.withValues(alpha: 0.85 * i), blurRadius: 2 * i),
      Shadow(color: color.withValues(alpha: 0.55 * i), blurRadius: 10 * i),
      Shadow(color: color.withValues(alpha: 0.28 * i), blurRadius: 22 * i),
    ];
  }

  static String timerLabel(Duration remaining, {bool isCheckedIn = true}) {
    if (!isCheckedIn) return 'READY';
    return timerBand(remaining.inMinutes).label;
  }

  static String tierFromSeconds(int seconds) {
    if (seconds >= 100 * 3600) return 'VVIP';
    if (seconds >= 10800) return 'Platinum';
    if (seconds >= 5400) return 'Gold';
    if (seconds >= 2700) return 'Silver';
    return 'Bronze';
  }
}

enum TimerBand {
  healthy,
  caution,
  low;

  String get label => switch (this) {
        TimerBand.healthy => 'PLENTY',
        TimerBand.caution => 'STEADY',
        TimerBand.low => 'EXTEND',
      };

  String get guestHint => switch (this) {
        TimerBand.healthy => 'Your night is open.',
        TimerBand.caution => 'Time is getting shorter — extend when you\'re ready.',
        TimerBand.low => 'Extend your time.',
      };
}
