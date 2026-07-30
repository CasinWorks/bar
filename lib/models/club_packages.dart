import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

/// Canonical entry packages — seeded in `time_packages`; Dart defaults are fallback.
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
    this.sortOrder = 0,
    this.active = true,
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
  final int sortOrder;
  final bool active;

  bool get isUnlimited => durationMinutes == null;

  String get durationLabel {
    if (durationMinutes == null) return 'Until closing';
    return '$durationMinutes min';
  }

  String get drinksLabel {
    if (includedDrinks == null) return 'Unlimited*';
    return '$includedDrinks drinks';
  }

  factory ClubPackage.fromSupabaseRow(Map<String, dynamic> row) {
    int? asNullableInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      return int.tryParse(value.toString());
    }

    return ClubPackage(
      slug: row['slug'] as String? ?? '',
      name: row['name'] as String? ?? '',
      pricePeso: asNullableInt(row['price_peso']) ?? 0,
      durationMinutes: asNullableInt(row['duration_minutes']),
      includedDrinks: asNullableInt(row['included_drinks']),
      targetGuest: row['target_guest'] as String? ?? '',
      tagline: row['tagline'] as String? ?? '',
      popular: row['popular'] as bool? ?? false,
      sortOrder: asNullableInt(row['sort_order']) ?? 0,
      active: row['active'] as bool? ?? true,
    );
  }
}

abstract final class ClubPackages {
  static const defaults = [
    ClubPackage(
      slug: 'quick-escape',
      name: 'Quick Escape',
      pricePeso: 699,
      durationMinutes: 90,
      includedDrinks: 2,
      targetGuest: 'After-work crowd',
      tagline: 'Your time starts now.',
      sortOrder: 1,
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
      sortOrder: 2,
    ),
    ClubPackage(
      slug: 'after-hours',
      name: 'After Hours',
      pricePeso: 1299,
      durationMinutes: 240,
      includedDrinks: 5,
      targetGuest: 'Late-night / weekend',
      tagline: 'Extend your time.',
      sortOrder: 3,
    ),
    ClubPackage(
      slug: 'unlimited',
      name: 'Unlimited',
      pricePeso: 1799,
      durationMinutes: null,
      includedDrinks: null,
      targetGuest: 'VIP / Members',
      tagline: 'Invest your time wisely.',
      sortOrder: 4,
    ),
  ];

  /// Live catalog (defaults until a successful cloud fetch).
  static List<ClubPackage> _catalog = List<ClubPackage>.from(defaults);

  /// Active packages shown in Pricing / lookups. Falls back to [defaults].
  static List<ClubPackage> get all => List.unmodifiable(_catalog);

  static void replaceCatalog(List<ClubPackage> packages) {
    _catalog = packages.isEmpty
        ? List<ClubPackage>.from(defaults)
        : List<ClubPackage>.from(packages);
  }

  static void resetCatalog() {
    _catalog = List<ClubPackage>.from(defaults);
  }

  static ClubPackage? bySlug(String? slug) {
    if (slug == null || slug.isEmpty) return null;
    for (final p in _catalog) {
      if (p.slug == slug) return p;
    }
    for (final p in defaults) {
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
    this.usesVipRoomTab = false,
  });

  final String slug;
  final String name;

  /// Minutes of room occupancy/liquor pool loaded when booked.
  final int timeCostMinutes;
  final String description;
  final String icon;

  /// VIP rooms/couches use a separate pool that decays while occupied.
  final bool usesVipRoomTab;

  static const vipRoomSlugs = {'vip-lounge', 'vvip-room', 'private-booth'};

  bool get isVipRoomExperience => usesVipRoomTab || vipRoomSlugs.contains(slug);
}

abstract final class VenueActivities {
  static const all = [
    VenueActivity(
      slug: 'vip-lounge',
      name: 'VIP Lounge',
      timeCostMinutes: 30,
      description: 'Room time decays while occupied · liquor billed to room',
      icon: '🛋️',
      usesVipRoomTab: true,
    ),
    VenueActivity(
      slug: 'vvip-room',
      name: 'VVIP Room',
      timeCostMinutes: 60,
      description: 'Premium room time · decays instead of personal',
      icon: '👑',
      usesVipRoomTab: true,
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
      description: 'VIP couch time · drinks charge the booth',
      icon: '🪑',
      usesVipRoomTab: true,
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
    BonusTimeRule(
      slug: 'social-media',
      name: 'Social Media Promotion',
      minutes: 10,
    ),
    BonusTimeRule(
      slug: 'loyalty-daily',
      name: 'Loyalty Membership',
      minutes: 10,
    ),
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
