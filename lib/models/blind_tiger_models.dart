import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

class AvatarConfig {
  const AvatarConfig({
    this.hair = 'TF',
    this.eyes = 'SV',
    this.accessory = 'GP',
    this.color = 0xFFD97706,
    this.name = 'TigerGuest_07',
  });

  final String hair;
  final String eyes;
  final String accessory;
  final int color;
  final String name;

  AvatarConfig copyWith({
    String? hair,
    String? eyes,
    String? accessory,
    int? color,
    String? name,
  }) {
    return AvatarConfig(
      hair: hair ?? this.hair,
      eyes: eyes ?? this.eyes,
      accessory: accessory ?? this.accessory,
      color: color ?? this.color,
      name: name ?? this.name,
    );
  }
}

class AvatarOption {
  const AvatarOption({
    required this.id,
    required this.name,
    required this.path,
  });
  final String id;
  final String name;
  final String path;
}

class PresetColor {
  const PresetColor({required this.code, required this.name});
  final int code;
  final String name;
}

class PriceTier {
  const PriceTier({
    required this.id,
    required this.duration,
    required this.price,
    required this.tagline,
    required this.valueProp,
    this.popular = false,
  });

  final String id;
  final int duration;
  final int price;
  final String tagline;
  final String valueProp;
  final bool popular;

  int get discountedPrice => (price * 0.85).floor();
}

class TimePackage {
  const TimePackage({
    required this.id,
    required this.minutes,
    required this.label,
    required this.tagline,
    this.popular = false,
    this.pricePeso,
    this.includedDrinks,
  });

  final String id;
  final int minutes;
  final String label;
  final String tagline;
  final bool popular;
  final int? pricePeso;
  final int? includedDrinks;

  int get price => pricePeso ?? minutes * AppTimePricing.pesoPerMinute;
  int get discountedPrice => (price * 0.85).floor();
}

/// Club time is sold per minute with a GCash referral discount on checkout.
abstract final class AppTimePricing {
  static const pesoPerMinute = 17;

  static int priceForMinutes(int minutes) => minutes * pesoPerMinute;
  static int discountedPriceForMinutes(int minutes) =>
      (priceForMinutes(minutes) * 0.85).floor();
}

enum ChallengeCategory { drink, social, game }

class Challenge {
  Challenge({
    required this.id,
    required this.title,
    required this.icon,
    required this.targetCount,
    this.currentCount = 0,
    required this.points,
    this.bonusMinutes = 0,
    this.claimed = false,
    required this.category,
  });

  final String id;
  final String title;
  final String icon;
  final int targetCount;
  int currentCount;
  final int points;

  /// Minutes credited to wallet on claim (Club District earn model).
  final int bonusMinutes;
  bool claimed;
  final ChallengeCategory category;

  bool get isComplete => currentCount >= targetCount;

  Challenge copyWith({int? currentCount, bool? claimed}) {
    return Challenge(
      id: id,
      title: title,
      icon: icon,
      targetCount: targetCount,
      currentCount: currentCount ?? this.currentCount,
      points: points,
      bonusMinutes: bonusMinutes,
      claimed: claimed ?? this.claimed,
      category: category,
    );
  }
}

class FeedEvent {
  FeedEvent({
    required this.id,
    required this.avatarSeed,
    required this.userName,
    required this.userRank,
    required this.isFriend,
    required this.timeAgo,
    required this.eventText,
    Map<String, int>? likes,
    this.userReacted,
  }) : likes = likes ?? {'luxe': 0, 'salute': 0, 'gold': 0};

  final String id;
  final AvatarSeed avatarSeed;
  final String userName;
  final String userRank;
  final bool isFriend;
  final String timeAgo;
  final String eventText;
  final Map<String, int> likes;
  String? userReacted;
}

class AvatarSeed {
  const AvatarSeed({
    required this.hair,
    required this.eyes,
    required this.accessory,
    required this.color,
  });

  final String hair;
  final String eyes;
  final String accessory;
  final int color;
}

enum MemberTier { vvip, platinum, gold, silver, bronze }

/// Time thresholds for member tiers and private room access.
abstract final class MemberTierThresholds {
  static const silverSeconds = 45 * 60;
  static const goldSeconds = 90 * 60;
  static const platinumSeconds = 3 * 3600;
  static const vipRoomSeconds = platinumSeconds;
  static const vvipSeconds = 100 * 3600;
  static const vvipRoomSeconds = vvipSeconds;

  static MemberTier tierForSeconds(int seconds) {
    if (seconds >= vvipSeconds) return MemberTier.vvip;
    if (seconds >= platinumSeconds) return MemberTier.platinum;
    if (seconds >= goldSeconds) return MemberTier.gold;
    if (seconds >= silverSeconds) return MemberTier.silver;
    return MemberTier.bronze;
  }
}

extension MemberTierLabel on MemberTier {
  String get label => switch (this) {
    MemberTier.vvip => 'VVIP',
    MemberTier.platinum => 'Platinum',
    MemberTier.gold => 'Gold',
    MemberTier.silver => 'Silver',
    MemberTier.bronze => 'Bronze',
  };

  Color get accentColor => switch (this) {
    MemberTier.vvip => AppColors.vvipAmethyst,
    MemberTier.platinum => AppColors.goldBright,
    MemberTier.gold => AppColors.tigerOrange,
    MemberTier.silver => AppColors.neutral400,
    MemberTier.bronze => AppColors.goldDark,
  };
}

class LeaderboardUser {
  LeaderboardUser({
    required this.rank,
    required this.name,
    required this.points,
    required this.tier,
    this.isCurrentUser = false,
    required this.avatarColor,
    required this.avatarGlyph,
    this.timeBalance,
  });

  final int rank;
  final String name;
  int points;
  MemberTier tier;
  final bool isCurrentUser;
  final int avatarColor;
  final String avatarGlyph;
  int? timeBalance;
}

enum DrinkCategory { spirits, wine, beer, nonAlc }

extension DrinkCategoryLabel on DrinkCategory {
  String get label => switch (this) {
    DrinkCategory.spirits => 'Spirits',
    DrinkCategory.wine => 'Wine',
    DrinkCategory.beer => 'Beer',
    DrinkCategory.nonAlc => 'Non-Alc',
  };
}

enum DrinkKind { standard, premium }

class Drink {
  const Drink({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.price,
    required this.flavor,
    required this.abv,
    this.badge,
    required this.ingredients,
    required this.bartenderQuote,
    required this.imageColorStart,
    required this.imageColorEnd,
    required this.timeCostSeconds,
    this.kind = DrinkKind.premium,
  });

  final String id;
  final String name;
  final DrinkCategory category;
  final String description;
  final String price;
  final String flavor;
  final String abv;
  final String? badge;
  final List<String> ingredients;
  final String bartenderQuote;
  final int imageColorStart;
  final int imageColorEnd;

  /// Premium path: burn minutes. Standard path: uses package allowance.
  final int timeCostSeconds;
  final DrinkKind kind;

  bool get isStandard => kind == DrinkKind.standard;
  bool get isPremium => kind == DrinkKind.premium;

  /// Stable catalog key used by POS tickets / drink_orders.drink_id.
  String get slug => id;

  static DrinkCategory categoryFromString(String? raw) {
    final value = (raw ?? '').trim().toLowerCase();
    return switch (value) {
      'beer' => DrinkCategory.beer,
      'wine' => DrinkCategory.wine,
      'nonalcoholic' || 'non-alc' || 'na' || 'mocktail' => DrinkCategory.nonAlc,
      _ => DrinkCategory.spirits,
    };
  }

  factory Drink.fromCatalogRow(Map<String, dynamic> row) {
    final slug = (row['slug'] as String? ?? '').trim();
    final name = (row['name'] as String? ?? '').trim();
    final kindRaw = (row['kind'] as String? ?? 'premium').toLowerCase();
    final kind = kindRaw == 'standard' ? DrinkKind.standard : DrinkKind.premium;
    final timeCost = (row['time_cost_seconds'] as num?)?.toInt() ?? 0;
    final pricePeso = (row['price_peso'] as num?)?.toInt();
    final ingredientsRaw = row['ingredients'];
    final ingredients = ingredientsRaw is List
        ? ingredientsRaw.map((e) => e.toString()).where((s) => s.isNotEmpty).toList()
        : <String>[];

    String priceLabel;
    if (kind == DrinkKind.standard && (pricePeso == null || pricePeso <= 0)) {
      priceLabel = timeCost > 0 ? 'Package / ${timeCost ~/ 60}m' : 'Included';
    } else if (pricePeso != null) {
      priceLabel = '₱$pricePeso';
    } else if (timeCost > 0) {
      priceLabel = '${timeCost ~/ 60} min';
    } else {
      priceLabel = '—';
    }

    return Drink(
      id: slug.isNotEmpty ? slug : (row['id']?.toString() ?? name),
      name: name.isNotEmpty ? name : 'Drink',
      category: categoryFromString(row['category'] as String?),
      description: row['description'] as String? ?? '',
      price: priceLabel,
      flavor: row['flavor'] as String? ?? '',
      abv: row['abv'] as String? ?? '',
      badge: row['badge'] as String?,
      ingredients: ingredients,
      bartenderQuote: row['bartender_quote'] as String? ?? '',
      imageColorStart: (row['image_color_start'] as num?)?.toInt() ?? 0xFFD97706,
      imageColorEnd: (row['image_color_end'] as num?)?.toInt() ?? 0xFF78350F,
      timeCostSeconds: timeCost,
      kind: kind,
    );
  }
}

class MiniGame {
  const MiniGame({
    required this.id,
    required this.title,
    required this.description,
    required this.points,
    required this.icon,
    this.locked = false,
    this.lockRequirement,
  });

  final String id;
  final String title;
  final String description;
  final int points;
  final String icon;
  final bool locked;
  final String? lockRequirement;
}

class ClubBranch {
  const ClubBranch({
    required this.id,
    required this.name,
    required this.city,
    this.icon = '',
    this.ambience = '',
  });

  final String id;
  final String name;
  final String city;
  final String icon;
  final String ambience;

  factory ClubBranch.fromSupabaseRow(Map<String, dynamic> json) {
    final slug = (json['slug'] as String?)?.trim();
    final rawId = json['id'];
    return ClubBranch(
      id: slug?.isNotEmpty == true
          ? slug!
          : (rawId is String && rawId.trim().isNotEmpty
                ? rawId.trim()
                : (json['name'] as String? ?? '').trim()),
      name: (json['name'] as String? ?? '').trim(),
      city: (json['city'] as String? ?? '').trim(),
      icon: (json['icon'] as String? ?? '').trim(),
      ambience: (json['ambience'] as String? ?? '').trim(),
    );
  }
}

enum PaymentMethod { gcash, visa, paymaya }

extension PaymentMethodLabel on PaymentMethod {
  String get label => switch (this) {
    PaymentMethod.gcash => 'GCASH',
    PaymentMethod.visa => 'VISA',
    PaymentMethod.paymaya => 'MAYA',
  };
}

enum LoungeTab { timeEconomy, games, social, chats, menu, leaderboard }

enum DoorStatus { locked, unlocked, wrong }
