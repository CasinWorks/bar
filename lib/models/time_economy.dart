import 'package:flutter/material.dart';

/// Club night phases — drives passive decay and flow multipliers.
enum ClubTimeWindow { opening, peak, frenzy, lastCall }

extension ClubTimeWindowLabel on ClubTimeWindow {
  String get label => switch (this) {
    ClubTimeWindow.opening => 'Opening',
    ClubTimeWindow.peak => 'Peak',
    ClubTimeWindow.frenzy => 'Frenzy',
    ClubTimeWindow.lastCall => 'Last Call',
  };

  String get clubState => switch (this) {
    ClubTimeWindow.opening => 'Stable (20% Occupancy)',
    ClubTimeWindow.peak => 'Active (50% Occupancy)',
    ClubTimeWindow.frenzy => 'Frenzy (80% Occupancy)',
    ClubTimeWindow.lastCall => 'Final Hour',
  };

  double get flowMultiplier => switch (this) {
    ClubTimeWindow.opening => 1.0,
    ClubTimeWindow.peak => 1.5,
    ClubTimeWindow.frenzy => 2.0,
    ClubTimeWindow.lastCall => 3.0,
  };

  int get occupancyPercent => switch (this) {
    ClubTimeWindow.opening => 20,
    ClubTimeWindow.peak => 50,
    ClubTimeWindow.frenzy => 80,
    ClubTimeWindow.lastCall => 95,
  };

  /// Real seconds of wall clock per 1 second of wallet time lost.
  int get realSecondsPerWalletSecond => switch (this) {
    ClubTimeWindow.opening => 5,
    ClubTimeWindow.peak => 3,
    ClubTimeWindow.frenzy => 2,
    ClubTimeWindow.lastCall => 1,
  };

  String get decayRateLabel => switch (this) {
    ClubTimeWindow.opening => '−1 min / 5 real min',
    ClubTimeWindow.peak => '−1 min / 3 real min',
    ClubTimeWindow.frenzy => '−1 min / 2 real min',
    ClubTimeWindow.lastCall => '−1 min / 1 real min',
  };
}

/// Protections that modify passive decay.
enum TimeBuffType { timeShield, birthdayBlessing, timeStasis }

extension TimeBuffTypeLabel on TimeBuffType {
  String get label => switch (this) {
    TimeBuffType.timeShield => 'Time Shield',
    TimeBuffType.birthdayBlessing => 'Birthday Blessing',
    TimeBuffType.timeStasis => 'Time Stasis',
  };

  String get description => switch (this) {
    TimeBuffType.timeShield => 'VIP · 25% slower decay',
    TimeBuffType.birthdayBlessing => '30 minutes frozen decay',
    TimeBuffType.timeStasis => '15 minutes zero decay',
  };
}

class ActiveTimeBuff {
  const ActiveTimeBuff({
    required this.type,
    this.expiresAt,
    this.frozenSecondsRemaining = 0,
  });

  final TimeBuffType type;
  final DateTime? expiresAt;
  final int frozenSecondsRemaining;

  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);

  bool get hasFrozenTime => frozenSecondsRemaining > 0;

  ActiveTimeBuff copyWith({DateTime? expiresAt, int? frozenSecondsRemaining}) =>
      ActiveTimeBuff(
        type: type,
        expiresAt: expiresAt ?? this.expiresAt,
        frozenSecondsRemaining:
            frozenSecondsRemaining ?? this.frozenSecondsRemaining,
      );
}

class ClubStateSnapshot {
  const ClubStateSnapshot({required this.window, required this.at});

  final ClubTimeWindow window;
  final DateTime at;

  double get flowMultiplier => window.flowMultiplier;
  int get occupancyPercent => window.occupancyPercent;
  String get label => window.label;
  String get clubState => window.clubState;
  String get decayRateLabel => window.decayRateLabel;
}

/// Scheduled live events on the night timeline.
enum NightEventType {
  timeDrop,
  mysteryPatron,
  theVault,
  timeMarket,
  secretMissions,
  hiddenRoom,
}

extension NightEventTypeMeta on NightEventType {
  String get title => switch (this) {
    NightEventType.timeDrop => 'Time Drop',
    NightEventType.mysteryPatron => 'Mystery Patron',
    NightEventType.theVault => 'The Vault',
    NightEventType.timeMarket => 'Time Market',
    NightEventType.secretMissions => 'Secret Missions',
    NightEventType.hiddenRoom => 'The Hidden Room',
  };

  String get description => switch (this) {
    NightEventType.timeDrop =>
      'First 20 guests at the DJ area get +15 minutes.',
    NightEventType.mysteryPatron =>
      'Anonymous time transfer — someone may gift you minutes.',
    NightEventType.theVault =>
      '60-second venue-wide vote for tonight\'s perks.',
    NightEventType.timeMarket =>
      'Real-time auction — bid minutes for exclusive perks.',
    NightEventType.secretMissions =>
      'Proximity alerts when someone drops below 5 minutes.',
    NightEventType.hiddenRoom => 'Requires >90 minutes balance for entry.',
  };

  IconData get icon => switch (this) {
    NightEventType.timeDrop => Icons.cloud_download,
    NightEventType.mysteryPatron => Icons.card_giftcard,
    NightEventType.theVault => Icons.how_to_vote,
    NightEventType.timeMarket => Icons.gavel,
    NightEventType.secretMissions => Icons.radar,
    NightEventType.hiddenRoom => Icons.door_sliding,
  };

  TimeOfDay get triggerTime => switch (this) {
    NightEventType.timeDrop => const TimeOfDay(hour: 20, minute: 15),
    NightEventType.mysteryPatron => const TimeOfDay(hour: 20, minute: 30),
    NightEventType.theVault => const TimeOfDay(hour: 21, minute: 0),
    NightEventType.timeMarket => const TimeOfDay(hour: 21, minute: 30),
    NightEventType.secretMissions => const TimeOfDay(hour: 22, minute: 0),
    NightEventType.hiddenRoom => const TimeOfDay(hour: 23, minute: 0),
  };
}

class NightTimelineEvent {
  NightTimelineEvent({
    required this.id,
    required this.type,
    this.isActive = false,
    this.isCompleted = false,
    this.isJoined = false,
    this.rewardMinutes = 0,
    this.participantCount = 0,
  });

  final String id;
  final NightEventType type;
  bool isActive;
  bool isCompleted;
  bool isJoined;
  int rewardMinutes;
  int participantCount;

  String get title => type.title;
  String get description => type.description;
  IconData get icon => type.icon;
  TimeOfDay get triggerTime => type.triggerTime;

  String get triggerLabel {
    final h = triggerTime.hourOfPeriod == 0 ? 12 : triggerTime.hourOfPeriod;
    final m = triggerTime.minute.toString().padLeft(2, '0');
    final ampm = triggerTime.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $ampm';
  }

  NightTimelineEvent copyWith({
    bool? isActive,
    bool? isCompleted,
    bool? isJoined,
    int? rewardMinutes,
    int? participantCount,
  }) => NightTimelineEvent(
    id: id,
    type: type,
    isActive: isActive ?? this.isActive,
    isCompleted: isCompleted ?? this.isCompleted,
    isJoined: isJoined ?? this.isJoined,
    rewardMinutes: rewardMinutes ?? this.rewardMinutes,
    participantCount: participantCount ?? this.participantCount,
  );
}

/// Visit-based player tiers.
enum PlayerVisitTier { firstTimer, regular, insider, vipTiger, legend }

extension PlayerVisitTierMeta on PlayerVisitTier {
  String get label => switch (this) {
    PlayerVisitTier.firstTimer => 'First Timer',
    PlayerVisitTier.regular => 'Regular',
    PlayerVisitTier.insider => 'Insider',
    PlayerVisitTier.vipTiger => 'VIP Tiger',
    PlayerVisitTier.legend => 'Legend',
  };

  int get visitsRequired => switch (this) {
    PlayerVisitTier.firstTimer => 0,
    PlayerVisitTier.regular => 5,
    PlayerVisitTier.insider => 10,
    PlayerVisitTier.vipTiger => 25,
    PlayerVisitTier.legend => 100,
  };

  static PlayerVisitTier forVisits(int visits) {
    if (visits >= 100) return PlayerVisitTier.legend;
    if (visits >= 25) return PlayerVisitTier.vipTiger;
    if (visits >= 10) return PlayerVisitTier.insider;
    if (visits >= 5) return PlayerVisitTier.regular;
    return PlayerVisitTier.firstTimer;
  }
}

enum AchievementBadgeId {
  timeSaver,
  bigSpender,
  timeInvestor,
  timeDonor,
  timeMillionaire,
  lastSecond,
  wingman,
  socialButterfly,
  conversationStarter,
  lifeOfTheParty,
  matchmaker,
}

extension AchievementBadgeMeta on AchievementBadgeId {
  String get label => switch (this) {
    AchievementBadgeId.timeSaver => 'Time Saver',
    AchievementBadgeId.bigSpender => 'Big Spender',
    AchievementBadgeId.timeInvestor => 'Time Investor',
    AchievementBadgeId.timeDonor => 'Time Donor',
    AchievementBadgeId.timeMillionaire => 'Time Millionaire',
    AchievementBadgeId.lastSecond => 'Last Second',
    AchievementBadgeId.wingman => 'Wingman',
    AchievementBadgeId.socialButterfly => 'Social Butterfly',
    AchievementBadgeId.conversationStarter => 'Conversation Starter',
    AchievementBadgeId.lifeOfTheParty => 'Life of the Party',
    AchievementBadgeId.matchmaker => 'Matchmaker',
  };

  String get description => switch (this) {
    AchievementBadgeId.timeSaver => 'Ended the night with 60+ minutes left.',
    AchievementBadgeId.bigSpender => 'Spent 300+ minutes in a single night.',
    AchievementBadgeId.timeInvestor =>
      'Purchased time mid-visit to extend your night.',
    AchievementBadgeId.timeDonor => 'Gifted 30+ minutes to others.',
    AchievementBadgeId.timeMillionaire => '1,000 lifetime minutes banked.',
    AchievementBadgeId.lastSecond => 'Exited with under 2 minutes left.',
    AchievementBadgeId.wingman => 'Helped a friend below 5 minutes.',
    AchievementBadgeId.socialButterfly => 'Met 5+ people tonight.',
    AchievementBadgeId.conversationStarter => 'Completed 3 icebreaker meets.',
    AchievementBadgeId.lifeOfTheParty => 'Won a venue vote or auction perk.',
    AchievementBadgeId.matchmaker => 'Connected two guests via Toast to Meet.',
  };

  IconData get icon => switch (this) {
    AchievementBadgeId.timeSaver => Icons.savings,
    AchievementBadgeId.bigSpender => Icons.diamond,
    AchievementBadgeId.timeInvestor => Icons.trending_up,
    AchievementBadgeId.timeDonor => Icons.volunteer_activism,
    AchievementBadgeId.timeMillionaire => Icons.stars,
    AchievementBadgeId.lastSecond => Icons.timer_off,
    AchievementBadgeId.wingman => Icons.handshake,
    AchievementBadgeId.socialButterfly => Icons.flutter_dash,
    AchievementBadgeId.conversationStarter => Icons.chat_bubble,
    AchievementBadgeId.lifeOfTheParty => Icons.celebration,
    AchievementBadgeId.matchmaker => Icons.favorite,
  };

  bool get isSocial => switch (this) {
    AchievementBadgeId.wingman ||
    AchievementBadgeId.socialButterfly ||
    AchievementBadgeId.conversationStarter ||
    AchievementBadgeId.lifeOfTheParty ||
    AchievementBadgeId.matchmaker => true,
    _ => false,
  };
}

class AchievementBadge {
  const AchievementBadge({
    required this.id,
    this.unlocked = false,
    this.unlockedAt,
  });

  final AchievementBadgeId id;
  final bool unlocked;
  final DateTime? unlockedAt;

  String get label => id.label;
  String get description => id.description;
  IconData get icon => id.icon;

  AchievementBadge copyWith({bool? unlocked, DateTime? unlockedAt}) =>
      AchievementBadge(
        id: id,
        unlocked: unlocked ?? this.unlocked,
        unlockedAt: unlockedAt ?? this.unlockedAt,
      );
}

/// Tracks stats for the current visit — surfaced on exit recap.
class VisitRecap {
  VisitRecap({
    this.peopleMet = 0,
    this.xpGained = 0,
    this.timeGiftedMinutes = 0,
    this.timeReceivedMinutes = 0,
    this.minutesSpentTonight = 0,
    this.minutesDecayedTonight = 0,
    this.eventsJoined = 0,
    this.questsCompleted = 0,
    List<AchievementBadgeId>? achievementsUnlocked,
    List<String>? peopleMetNames,
  }) : achievementsUnlocked = achievementsUnlocked ?? [],
       peopleMetNames = peopleMetNames ?? [];

  int peopleMet;
  int xpGained;
  int timeGiftedMinutes;
  int timeReceivedMinutes;
  int minutesSpentTonight;
  int minutesDecayedTonight;
  int eventsJoined;
  int questsCompleted;
  final List<AchievementBadgeId> achievementsUnlocked;
  final List<String> peopleMetNames;

  Map<String, dynamic> toJson() => {
    'peopleMet': peopleMet,
    'xpGained': xpGained,
    'timeGiftedMinutes': timeGiftedMinutes,
    'timeReceivedMinutes': timeReceivedMinutes,
    'minutesSpentTonight': minutesSpentTonight,
    'minutesDecayedTonight': minutesDecayedTonight,
    'eventsJoined': eventsJoined,
    'questsCompleted': questsCompleted,
    'achievementsUnlocked': achievementsUnlocked.map((a) => a.name).toList(),
    'peopleMetNames': peopleMetNames,
  };

  factory VisitRecap.fromJson(Map<String, dynamic> json) => VisitRecap(
    peopleMet: json['peopleMet'] as int? ?? 0,
    xpGained: json['xpGained'] as int? ?? 0,
    timeGiftedMinutes: json['timeGiftedMinutes'] as int? ?? 0,
    timeReceivedMinutes: json['timeReceivedMinutes'] as int? ?? 0,
    minutesSpentTonight: json['minutesSpentTonight'] as int? ?? 0,
    minutesDecayedTonight: json['minutesDecayedTonight'] as int? ?? 0,
    eventsJoined: json['eventsJoined'] as int? ?? 0,
    questsCompleted: json['questsCompleted'] as int? ?? 0,
    achievementsUnlocked:
        (json['achievementsUnlocked'] as List<dynamic>?)
            ?.map((e) => AchievementBadgeId.values.byName(e as String))
            .toList() ??
        [],
    peopleMetNames:
        (json['peopleMetNames'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList() ??
        [],
  );
}

/// Real-time transparency payload for the lounge HUD.
class TimeEconomySnapshot {
  const TimeEconomySnapshot({
    required this.clubState,
    required this.effectiveDecayPerSecond,
    required this.decayRateLabel,
    required this.activeBuffs,
    required this.minutesRemaining,
    required this.flowMultiplier,
    required this.nextEvent,
  });

  final ClubStateSnapshot clubState;
  final double effectiveDecayPerSecond;
  final String decayRateLabel;
  final List<ActiveTimeBuff> activeBuffs;
  final int minutesRemaining;
  final double flowMultiplier;
  final NightTimelineEvent? nextEvent;

  bool get hasDecayProtection => activeBuffs.any(
    (b) => b.hasFrozenTime || b.type == TimeBuffType.timeShield,
  );
}
