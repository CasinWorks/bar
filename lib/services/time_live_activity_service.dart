import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:live_activities/live_activities.dart';

/// Dynamic Island / Lock Screen / Apple Watch Live Activity for time-as-currency.
///
/// Apple Watch shows the same Live Activity automatically when the iPhone
/// activity is running (watchOS 10.1+ / 11 preferred). No separate Watch app.
class TimeLiveActivityService {
  TimeLiveActivityService();

  static const appGroupId = 'group.com.intime.inTimeBartender';
  static const _activityId = 'blind-tiger-time';

  /// Native countdown is clearest under ~36h; above that we show the wallet label
  /// (e.g. "423h 12m") so Island/Watch never silently clamp to ~7 days.
  static const liveCountdownMaxSeconds = 36 * 3600;

  final LiveActivities _plugin = LiveActivities();
  bool _ready = false;
  Future<void>? _inflight;

  Future<void> init() async {
    if (kIsWeb || !Platform.isIOS) return;
    try {
      await _plugin.init(appGroupId: appGroupId, urlScheme: 'blindtiger');
      // Kill orphans from prior launches so the lock screen never stacks twins.
      await _plugin.endAllActivities();
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  Map<String, dynamic> _payload({
    required String memberName,
    required String branch,
    required String status,
    required int remainingSeconds,
  }) {
    final now = DateTime.now();
    final seconds = remainingSeconds < 0 ? 0 : remainingSeconds;
    final useLiveCountdown = seconds > 0 && seconds <= liveCountdownMaxSeconds;
    final end = now.add(Duration(seconds: seconds == 0 ? 1 : seconds));
    return {
      'memberName': memberName,
      'branch': branch,
      'status': status,
      'timerStartMs': now.millisecondsSinceEpoch,
      'timerEndMs': end.millisecondsSinceEpoch,
      'remainingSeconds': seconds,
      'useLiveCountdown': useLiveCountdown,
      'urgent': seconds > 0 && seconds <= 10 * 60,
      'remainingLabel': _format(seconds),
    };
  }

  String _format(int totalSeconds) {
    if (totalSeconds <= 0) return '0:00';
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    if (h >= 1) {
      return '${h}h ${m.toString().padLeft(2, '0')}m';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> syncVisit({
    required bool insideOrExiting,
    required String memberName,
    required String branch,
    required String status,
    required int remainingSeconds,
  }) {
    // Serialize — parallel createOrUpdate races create duplicate lock-screen cards.
    final previous = _inflight;
    late final Future<void> run;
    run = () async {
      if (previous != null) {
        try {
          await previous;
        } catch (_) {}
      }
      await _syncVisitBody(
        insideOrExiting: insideOrExiting,
        memberName: memberName,
        branch: branch,
        status: status,
        remainingSeconds: remainingSeconds,
      );
    }();
    _inflight = run;
    return run;
  }

  Future<void> _syncVisitBody({
    required bool insideOrExiting,
    required String memberName,
    required String branch,
    required String status,
    required int remainingSeconds,
  }) async {
    if (!_ready) return;
    if (!insideOrExiting || remainingSeconds < 0) {
      await _endBody();
      return;
    }

    try {
      final enabled = await _plugin.areActivitiesEnabled();
      if (!enabled) return;

      // If somehow multiple exist, collapse to one before upsert.
      final ids = await _plugin.getAllActivitiesIds();
      if (ids.length > 1) {
        await _plugin.endAllActivities();
      }

      final data = _payload(
        memberName: memberName,
        branch: branch,
        status: status,
        remainingSeconds: remainingSeconds,
      );

      await _plugin.createOrUpdateActivity(
        _activityId,
        data,
        removeWhenAppIsKilled: false,
        iOSEnableRemoteUpdates: false,
        staleIn: const Duration(hours: 8),
      );

      // Belt-and-suspenders: never leave more than one Live Activity alive.
      final after = await _plugin.getAllActivitiesIds();
      if (after.length > 1) {
        await _plugin.endAllActivities();
        await _plugin.createOrUpdateActivity(
          _activityId,
          data,
          removeWhenAppIsKilled: false,
          iOSEnableRemoteUpdates: false,
          staleIn: const Duration(hours: 8),
        );
      }
    } catch (_) {
      // Simulator / denied Live Activities — ignore.
    }
  }

  Future<void> end() {
    final previous = _inflight;
    late final Future<void> run;
    run = () async {
      if (previous != null) {
        try {
          await previous;
        } catch (_) {}
      }
      await _endBody();
    }();
    _inflight = run;
    return run;
  }

  Future<void> _endBody() async {
    if (!_ready) return;
    try {
      await _plugin.endAllActivities();
    } catch (_) {}
  }
}
