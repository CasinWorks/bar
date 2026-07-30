import 'package:flutter/material.dart';

import '../models/member_user.dart';
import '../models/time_economy.dart';

/// Which wallet pool loses seconds on a decay tick.
enum TimeDecaySource { personal, vipRoom, eventWallet, none }

/// Club-night clock, decay math, timeline schedule, and badge catalog.
abstract final class TimeEconomyService {
  static const clubOpenHour = 20;
  static const clubCloseHour = 2;

  /// VIP room time decays alone while occupied; otherwise a live event wallet
  /// pauses personal; personal resumes only when neither pool is active.
  static TimeDecaySource decaySource({
    required bool isInVipRoom,
    required int vipRoomSeconds,
    required bool eventWalletActive,
    required int eventWalletSeconds,
    required int personalSeconds,
  }) {
    if (isInVipRoom && vipRoomSeconds > 0) {
      return TimeDecaySource.vipRoom;
    }
    if (eventWalletActive && eventWalletSeconds > 0) {
      return TimeDecaySource.eventWallet;
    }
    if (personalSeconds > 0) return TimeDecaySource.personal;
    return TimeDecaySource.none;
  }

  static ClubTimeWindow windowFor(DateTime now) {
    final h = now.hour;
    // 1:00–2:00 AM — maximum acceleration
    if (h == 1) return ClubTimeWindow.lastCall;
    // 11:00 PM – 12:59 AM
    if (h >= 23 || h == 0) return ClubTimeWindow.frenzy;
    // 9:00–11:00 PM
    if (h >= 21 && h <= 22) return ClubTimeWindow.peak;
    // 8:00–9:00 PM (and demo default outside hours)
    return ClubTimeWindow.opening;
  }

  static ClubStateSnapshot clubStateAt(DateTime now) =>
      ClubStateSnapshot(window: windowFor(now), at: now);

  /// Wallet seconds lost per real second after buffs.
  static double decayPerRealSecond({
    required ClubTimeWindow window,
    required List<ActiveTimeBuff> buffs,
  }) {
    if (buffs.any((b) => b.hasFrozenTime)) return 0;

    final base = 1.0 / window.realSecondsPerWalletSecond;

    var rate = base;
    if (buffs.any((b) => b.type == TimeBuffType.timeShield && !b.isExpired)) {
      rate *= 0.75;
    }
    return rate;
  }

  static String effectiveDecayLabel({
    required ClubTimeWindow window,
    required List<ActiveTimeBuff> buffs,
    required double rate,
  }) {
    if (buffs.any((b) => b.hasFrozenTime)) {
      final frozen = buffs.firstWhere((b) => b.hasFrozenTime);
      final mins = (frozen.frozenSecondsRemaining / 60).ceil();
      return 'DECAY FROZEN · ${mins}m shield';
    }
    if (rate <= 0) return 'NO DECAY';
    if (buffs.any((b) => b.type == TimeBuffType.timeShield && !b.isExpired)) {
      return '${window.decayRateLabel} · VIP −25%';
    }
    return window.decayRateLabel;
  }

  static List<NightTimelineEvent> buildNightTimeline() => [
    for (final type in NightEventType.values)
      NightTimelineEvent(id: 'night-${type.name}', type: type),
  ];

  static void refreshTimelineStates(
    List<NightTimelineEvent> events,
    DateTime now,
  ) {
    for (final event in events) {
      final trigger = _triggerDateTime(event.triggerTime, now);
      final end = trigger.add(_eventDuration(event.type));
      final wasActive = event.isActive;

      if (now.isBefore(trigger)) {
        event.isActive = false;
      } else if (now.isBefore(end)) {
        event.isActive = true;
      } else {
        event.isActive = false;
        if (wasActive && !event.isCompleted) {
          // Window passed — mark missed unless joined.
        }
      }
    }
  }

  static NightTimelineEvent? nextUpcoming(
    List<NightTimelineEvent> events,
    DateTime now,
  ) {
    NightTimelineEvent? best;
    Duration? bestDelta;
    for (final event in events) {
      if (event.isCompleted) continue;
      final trigger = _triggerDateTime(event.triggerTime, now);
      final delta = trigger.difference(now);
      if (delta.isNegative) continue;
      if (bestDelta == null || delta < bestDelta) {
        bestDelta = delta;
        best = event;
      }
    }
    return best;
  }

  static NightTimelineEvent? activeEvent(
    List<NightTimelineEvent> events,
    DateTime now,
  ) {
    for (final event in events) {
      if (event.isActive && !event.isCompleted) return event;
    }
    return null;
  }

  static DateTime _triggerDateTime(TimeOfDay time, DateTime reference) {
    var dt = DateTime(
      reference.year,
      reference.month,
      reference.day,
      time.hour,
      time.minute,
    );
    // Events before club open belong to tonight's schedule (same calendar day).
    if (time.hour < clubOpenHour && reference.hour >= clubOpenHour) {
      // already correct
    } else if (dt.isBefore(reference) && time.hour >= clubOpenHour) {
      // same day trigger already passed
    }
    if (dt.isBefore(reference.subtract(const Duration(hours: 6)))) {
      dt = dt.add(const Duration(days: 1));
    }
    return dt;
  }

  static Duration _eventDuration(NightEventType type) => switch (type) {
    NightEventType.theVault => const Duration(seconds: 60),
    NightEventType.timeMarket => const Duration(minutes: 15),
    NightEventType.timeDrop => const Duration(minutes: 10),
    NightEventType.mysteryPatron => const Duration(minutes: 20),
    NightEventType.secretMissions => const Duration(hours: 1),
    NightEventType.hiddenRoom => const Duration(hours: 2),
  };

  static List<AchievementBadge> allBadges({Set<AchievementBadgeId>? unlocked}) {
    final set = unlocked ?? {};
    return AchievementBadgeId.values
        .map((id) => AchievementBadge(id: id, unlocked: set.contains(id)))
        .toList();
  }

  static List<ActiveTimeBuff> defaultBuffsFor(MemberUser? user) {
    final buffs = <ActiveTimeBuff>[];
    if (user == null) return buffs;

    if (user.isWhitelisted) {
      buffs.add(
        ActiveTimeBuff(
          type: TimeBuffType.timeShield,
          expiresAt: DateTime.now().add(const Duration(hours: 6)),
        ),
      );
    }

    if (_isBirthday(user.birthdate)) {
      buffs.add(
        const ActiveTimeBuff(
          type: TimeBuffType.birthdayBlessing,
          frozenSecondsRemaining: 30 * 60,
        ),
      );
    }

    return buffs;
  }

  static bool _isBirthday(DateTime? birthdate) {
    if (birthdate == null) return false;
    final now = DateTime.now();
    return birthdate.month == now.month && birthdate.day == now.day;
  }

  static TimeEconomySnapshot snapshot({
    required DateTime now,
    required int walletSeconds,
    required List<ActiveTimeBuff> buffs,
    required List<NightTimelineEvent> timeline,
  }) {
    final club = clubStateAt(now);
    final rate = decayPerRealSecond(window: club.window, buffs: buffs);
    return TimeEconomySnapshot(
      clubState: club,
      effectiveDecayPerSecond: rate,
      decayRateLabel: effectiveDecayLabel(
        window: club.window,
        buffs: buffs,
        rate: rate,
      ),
      activeBuffs: buffs,
      minutesRemaining: walletSeconds ~/ 60,
      flowMultiplier: club.flowMultiplier,
      nextEvent: nextUpcoming(timeline, now) ?? activeEvent(timeline, now),
    );
  }
}
