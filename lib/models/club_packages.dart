import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

/// Canonical entry packages — must match admin ENTRY_PACKAGES + migration seed.
class ClubPackage {
  const ClubPackage({
    required this.slug,
    required this.name,
    required this.pricePeso,
    required this.durationMinutes,
    required this.includedDrinks,
    required this.targetGuest,
    required this.tagline,
    this.popular = false,
  });

  final String slug;
  final String name;
  final int pricePeso;
  /// Null = until closing (soft-loaded as 480 min).
  final int? durationMinutes;
  /// Null = unlimited (responsible soft cap).
  final int? includedDrinks;
  final String targetGuest;
  final String tagline;
  final bool popular;

  bool get isUnlimited => durationMinutes == null;

  String get durationLabel {
    if (durationMinutes == null) return 'Until closing';
    return '$durationMinutes min';
  }

  String get drinksLabel {
    if (includedDrinks == null) return 'Unlimited*';
    return '$includedDrinks drinks';
  }
}

abstract final class ClubPackages {
  static const all = [
    ClubPackage(
      slug: 'quick-escape',
      name: 'Quick Escape',
      pricePeso: 699,
      durationMinutes: 90,
      includedDrinks: 2,
      targetGuest: 'After-work crowd',
      tagline: 'Your time starts now.',
    ),
    ClubPackage(
      slug: 'standard-night',
      name: 'Standard Night',
      pricePeso: 999,
      durationMinutes: 180,
      includedDrinks: 4,
      targetGuest: 'Most guests',
      tagline: 'Every second counts.',
      popular: true,
    ),
    ClubPackage(
      slug: 'after-hours',
      name: 'After Hours',
      pricePeso: 1299,
      durationMinutes: 240,
      includedDrinks: 5,
      targetGuest: 'Late-night / weekend',
      tagline: 'Extend your time.',
    ),
    ClubPackage(
      slug: 'unlimited',
      name: 'Unlimited',
      pricePeso: 1799,
      durationMinutes: null,
      includedDrinks: null,
      targetGuest: 'VIP / Members',
      tagline: 'Invest your time wisely.',
    ),
  ];

  static ClubPackage? bySlug(String? slug) {
    if (slug == null || slug.isEmpty) return null;
    for (final p in all) {
      if (p.slug == slug) return p;
    }
    return null;
  }
}

class VenueActivity {
  const VenueActivity({
    required this.slug,
    required this.name,
    required this.timeCostMinutes,
    required this.description,
    required this.icon,
  });

  final String slug;
  final String name;
  final int timeCostMinutes;
  final String description;
  final String icon;
}

abstract final class VenueActivities {
  static const all = [
    VenueActivity(
      slug: 'vip-lounge',
      name: 'VIP Lounge',
      timeCostMinutes: 30,
      description: 'Private lounge access',
      icon: '🛋️',
    ),
    VenueActivity(
      slug: 'vvip-room',
      name: 'VVIP Room',
      timeCostMinutes: 60,
      description: 'Top-tier private room',
      icon: '👑',
    ),
    VenueActivity(
      slug: 'secret-room',
      name: 'Secret Room',
      timeCostMinutes: 45,
      description: 'Members-only room',
      icon: '🔐',
    ),
    VenueActivity(
      slug: 'photo-booth',
      name: 'Photo Booth',
      timeCostMinutes: 5,
      description: 'Capture the night',
      icon: '📸',
    ),
    VenueActivity(
      slug: 'dj-meet',
      name: 'DJ Meet & Greet',
      timeCostMinutes: 15,
      description: 'Meet the booth',
      icon: '🎧',
    ),
    VenueActivity(
      slug: 'private-booth',
      name: 'Private Booth',
      timeCostMinutes: 30,
      description: 'Reserved booth time',
      icon: '🪑',
    ),
  ];
}

class BonusTimeRule {
  const BonusTimeRule({
    required this.slug,
    required this.name,
    required this.minutes,
    this.variable = false,
  });

  final String slug;
  final String name;
  final int minutes;
  final bool variable;
}

abstract final class BonusTimeRules {
  static const all = [
    BonusTimeRule(slug: 'birthday', name: 'Birthday Celebration', minutes: 15),
    BonusTimeRule(slug: 'bring-a-friend', name: 'Bring a Friend', minutes: 20),
    BonusTimeRule(slug: 'club-games', name: 'Win Club Games', minutes: 30),
    BonusTimeRule(
      slug: 'dance-competition',
      name: 'Dance Competition Winner',
      minutes: 60,
    ),
    BonusTimeRule(slug: 'social-media', name: 'Social Media Promotion', minutes: 10),
    BonusTimeRule(slug: 'loyalty-daily', name: 'Loyalty Membership', minutes: 10),
    BonusTimeRule(
      slug: 'special-events',
      name: 'Special Events',
      minutes: 0,
      variable: true,
    ),
  ];
}

/// Soft brand accents for package cards.
Color packageAccent(ClubPackage pkg) {
  if (pkg.popular) return AppColors.tigerRed;
  if (pkg.isUnlimited) return AppColors.antiqueGold;
  return AppColors.darkSteel;
}
