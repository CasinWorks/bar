import 'package:flutter/material.dart';

/// Three types of time in the Blind Tiger economy.
enum TimeCurrencyType { liquid, banked, reserved, vipRoom }

extension TimeCurrencyTypeMeta on TimeCurrencyType {
  String get label => switch (this) {
    TimeCurrencyType.liquid => 'Liquid Time',
    TimeCurrencyType.banked => 'Banked Time',
    TimeCurrencyType.reserved => 'Reserved Time',
    TimeCurrencyType.vipRoom => 'VIP Room Tab',
  };

  String get subtitle => switch (this) {
    TimeCurrencyType.liquid => 'LIVE · Current visit',
    TimeCurrencyType.banked => 'SAVED · Loyalty currency',
    TimeCurrencyType.reserved => 'CLUB · Venue reserve',
    TimeCurrencyType.vipRoom => 'ROOM · Liquor tab only',
  };

  String get description => switch (this) {
    TimeCurrencyType.liquid =>
      'Counts down in real-time. Spend inside the club. Cannot be banked.',
    TimeCurrencyType.banked =>
      'Earned from missions & achievements. Never decays. Gift or extend next visit.',
    TimeCurrencyType.reserved =>
      'Controlled by the venue. Special events & rewards. Prevents inflation.',
    TimeCurrencyType.vipRoom =>
      'Loaded when you book a VIP room or couch. Every liquor order charges this tab — not your personal time.',
  };

  IconData get icon => switch (this) {
    TimeCurrencyType.liquid => Icons.water_drop,
    TimeCurrencyType.banked => Icons.account_balance_wallet,
    TimeCurrencyType.reserved => Icons.lock_clock,
    TimeCurrencyType.vipRoom => Icons.meeting_room,
  };

  Color get accentColor => switch (this) {
    TimeCurrencyType.liquid => const Color(0xFF2ECC71),
    TimeCurrencyType.banked => const Color(0xFFB8924A),
    TimeCurrencyType.reserved => const Color(0xFFD4252B),
    TimeCurrencyType.vipRoom => const Color(0xFF9B59B6),
  };
}

class TimeWalletSnapshot {
  const TimeWalletSnapshot({
    required this.liquidSeconds,
    required this.bankedSeconds,
    required this.reservedSeconds,
    required this.isInsideClub,
    this.vipRoomSeconds = 0,
    this.activeVipRoomName,
  });

  final int liquidSeconds;
  final int bankedSeconds;
  final int reservedSeconds;
  final bool isInsideClub;
  final int vipRoomSeconds;
  final String? activeVipRoomName;

  int get liquidMinutes => liquidSeconds ~/ 60;
  int get bankedMinutes => bankedSeconds ~/ 60;
  int get reservedMinutes => reservedSeconds ~/ 60;
  int get vipRoomMinutes => vipRoomSeconds ~/ 60;

  bool get hasActiveVipRoom =>
      activeVipRoomName != null && activeVipRoomName!.isNotEmpty;
}

/// Reputation ranks — unlock experiences money cannot buy.
enum ReputationLevel { cub, hunter, alpha, whiteTiger, blindTigerLegend }

extension ReputationLevelMeta on ReputationLevel {
  String get label => switch (this) {
    ReputationLevel.cub => 'Cub',
    ReputationLevel.hunter => 'Hunter',
    ReputationLevel.alpha => 'Alpha',
    ReputationLevel.whiteTiger => 'White Tiger',
    ReputationLevel.blindTigerLegend => 'Blind Tiger Legend',
  };

  int get xpRequired => switch (this) {
    ReputationLevel.cub => 0,
    ReputationLevel.hunter => 100,
    ReputationLevel.alpha => 300,
    ReputationLevel.whiteTiger => 750,
    ReputationLevel.blindTigerLegend => 2000,
  };

  List<String> get unlocks => switch (this) {
    ReputationLevel.cub => ['Base lounge access'],
    ReputationLevel.hunter => ['Secret menu preview'],
    ReputationLevel.alpha => ['Hidden rooms', 'Priority seating'],
    ReputationLevel.whiteTiger => [
      'Invitation-only nights',
      'Early event access',
    ],
    ReputationLevel.blindTigerLegend => [
      'Exclusive badges',
      'Director\'s table',
      'Venue reserve time',
    ],
  };

  static ReputationLevel forXp(int xp) {
    if (xp >= 2000) return ReputationLevel.blindTigerLegend;
    if (xp >= 750) return ReputationLevel.whiteTiger;
    if (xp >= 300) return ReputationLevel.alpha;
    if (xp >= 100) return ReputationLevel.hunter;
    return ReputationLevel.cub;
  }

  ReputationLevel? get next {
    const order = ReputationLevel.values;
    final i = order.indexOf(this);
    if (i >= order.length - 1) return null;
    return order[i + 1];
  }
}

enum QuestCategory {
  icebreaker,
  social,
  team,
  weeklyMovie,
  mystery,
  competitive,
  reputation,
  timeQuest,
}

extension QuestCategoryMeta on QuestCategory {
  String get label => switch (this) {
    QuestCategory.icebreaker => 'Icebreaker',
    QuestCategory.social => 'Social',
    QuestCategory.team => 'Team',
    QuestCategory.weeklyMovie => 'Weekly Movie',
    QuestCategory.mystery => 'Mystery',
    QuestCategory.competitive => 'Competitive',
    QuestCategory.reputation => 'Reputation',
    QuestCategory.timeQuest => 'Time Quest',
  };

  String get difficulty => switch (this) {
    QuestCategory.icebreaker => 'Easy · First-time guests',
    QuestCategory.social => 'Medium · Genuine interaction',
    QuestCategory.team => 'Team · Work together',
    QuestCategory.weeklyMovie => 'Weekly · Movie-inspired',
    QuestCategory.mystery => 'Secret · Only you know',
    QuestCategory.competitive => 'Competitive · Leaderboard',
    QuestCategory.reputation => 'Multi-visit · Build status',
    QuestCategory.timeQuest => 'Time Economy · Unique',
  };

  IconData get icon => switch (this) {
    QuestCategory.icebreaker => Icons.waving_hand,
    QuestCategory.social => Icons.people,
    QuestCategory.team => Icons.groups,
    QuestCategory.weeklyMovie => Icons.movie,
    QuestCategory.mystery => Icons.visibility_off,
    QuestCategory.competitive => Icons.emoji_events,
    QuestCategory.reputation => Icons.military_tech,
    QuestCategory.timeQuest => Icons.schedule,
  };
}

enum QuestRewardType { liquidMinutes, bankedMinutes, xp, badge, rareBadge }

class QuestReward {
  const QuestReward({
    required this.type,
    this.amount = 0,
    this.badgeId,
    this.label,
  });

  final QuestRewardType type;
  final int amount;
  final String? badgeId;
  final String? label;

  String get displayLabel =>
      label ??
      switch (type) {
        QuestRewardType.liquidMinutes => '+$amount min liquid',
        QuestRewardType.bankedMinutes => '+$amount min banked',
        QuestRewardType.xp => '+$amount XP',
        QuestRewardType.badge => badgeId ?? 'Badge',
        QuestRewardType.rareBadge => 'Rare: ${badgeId ?? 'Badge'}',
      };
}

class ClubQuest {
  ClubQuest({
    required this.id,
    required this.title,
    required this.objective,
    required this.category,
    required this.targetCount,
    this.currentCount = 0,
    this.rewards = const [],
    this.claimed = false,
    this.hidden = false,
    this.movieTheme,
    this.isWeekly = false,
  });

  final String id;
  final String title;
  final String objective;
  final QuestCategory category;
  final int targetCount;
  int currentCount;
  final List<QuestReward> rewards;
  bool claimed;
  final bool hidden;
  final String? movieTheme;
  final bool isWeekly;

  bool get isComplete => currentCount >= targetCount;
  double get progress => (currentCount / targetCount).clamp(0.0, 1.0);

  ClubQuest copyWith({int? currentCount, bool? claimed}) => ClubQuest(
    id: id,
    title: title,
    objective: objective,
    category: category,
    targetCount: targetCount,
    currentCount: currentCount ?? this.currentCount,
    rewards: rewards,
    claimed: claimed ?? this.claimed,
    hidden: hidden,
    movieTheme: movieTheme,
    isWeekly: isWeekly,
  );
}

/// Competitive leaderboard categories.
enum LeaderboardCategory {
  mostSocial,
  bestDancer,
  mostQuestsCompleted,
  mostIntroductions,
  longestConsecutiveVisit,
  fastestQuestFinisher,
}

extension LeaderboardCategoryMeta on LeaderboardCategory {
  String get label => switch (this) {
    LeaderboardCategory.mostSocial => 'Most Social Guest',
    LeaderboardCategory.bestDancer => 'Best Dancer',
    LeaderboardCategory.mostQuestsCompleted => 'Most Quests Completed',
    LeaderboardCategory.mostIntroductions => 'Most People Introduced',
    LeaderboardCategory.longestConsecutiveVisit => 'Longest Consecutive Visit',
    LeaderboardCategory.fastestQuestFinisher => 'Fastest Quest Finisher',
  };

  IconData get icon => switch (this) {
    LeaderboardCategory.mostSocial => Icons.people_alt,
    LeaderboardCategory.bestDancer => Icons.music_note,
    LeaderboardCategory.mostQuestsCompleted => Icons.task_alt,
    LeaderboardCategory.mostIntroductions => Icons.handshake,
    LeaderboardCategory.longestConsecutiveVisit => Icons.calendar_month,
    LeaderboardCategory.fastestQuestFinisher => Icons.speed,
  };
}

class CompetitiveRanking {
  const CompetitiveRanking({
    required this.rank,
    required this.name,
    required this.score,
    required this.category,
    this.isCurrentUser = false,
    this.avatarGlyph = '?',
  });

  final int rank;
  final String name;
  final int score;
  final LeaderboardCategory category;
  final bool isCurrentUser;
  final String avatarGlyph;
}
