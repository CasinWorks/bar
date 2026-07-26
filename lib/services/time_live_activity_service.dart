import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Dynamic Island / Lock Screen / Apple Watch Live Activity for time-as-currency.
///
/// Uses a native ActivityKit bridge that puts timer/member fields in ContentState.
/// That is required for Apple Watch (watchOS 11 Smart Stack): the Watch re-renders
/// the `.small` family remotely and cannot read iPhone App Group UserDefaults.
class TimeLiveActivityService {
  TimeLiveActivityService();

  static const appGroupId = 'group.com.intime.inTimeBartender';
  static const _activityId = 'blind-tiger-time';
  static const _channel = MethodChannel(
    'com.intime.inTimeBartender/live_activity',
  );
  static const _tokenChannel = EventChannel(
    'com.intime.inTimeBartender/live_activity_tokens',
  );

  /// Native countdown is clearest under ~36h; above that we show the wallet label
  /// (e.g. "423h 12m") so Island/Watch never silently clamp to ~7 days.
  static const liveCountdownMaxSeconds = 36 * 3600;

  bool _ready = false;
  Future<void>? _inflight;
  StreamSubscription<dynamic>? _tokenSub;
  String? _liveActivityPushToken;
  String? _pushToStartToken;
  void Function(String token, {required String kind})? onPushToken;

  String? get liveActivityPushToken => _liveActivityPushToken;
  String? get pushToStartToken => _pushToStartToken;
  bool get isReady => _ready;

  Future<void> init() async {
    if (kIsWeb || !Platform.isIOS) return;
    try {
      try {
        await _channel.invokeMethod<void>('endAll');
      } catch (e) {
        debugPrint('LiveActivity endAll on init: $e');
      }
      _ready = true;

      _tokenSub?.cancel();
      _tokenSub = _tokenChannel.receiveBroadcastStream().listen((event) {
        if (event is! Map) return;
        final kind = event['kind'] as String?;
        final token = event['token'] as String?;
        if (kind == null || token == null || token.isEmpty) return;
        if (kind == 'live_activity') {
          _liveActivityPushToken = token;
        } else if (kind == 'live_activity_start') {
          _pushToStartToken = token;
        }
        onPushToken?.call(token, kind: kind);
      });
    } catch (e, st) {
      _ready = false;
      debugPrint('LiveActivity init failed: $e\n$st');
    }
  }

  Map<String, dynamic> _payload({
    required String memberName,
    required String branch,
    required String status,
    required int remainingSeconds,
    String? socialAlertTitle,
    String? socialAlertBody,
    String? socialAlertSender,
  }) {
    final now = DateTime.now();
    final seconds = remainingSeconds < 0 ? 0 : remainingSeconds;
    // Typical club packages are ≤8h; timerInterval ticks without app wakes.
    // Above 36h we send a static remainingLabel (demo mega-wallets only) — that
    // label only refreshes when we sync ContentState (not every second).
    final useLiveCountdown = seconds > 0 && seconds <= liveCountdownMaxSeconds;
    final end = now.add(Duration(seconds: seconds == 0 ? 1 : seconds));
    final hasSocial = socialAlertTitle != null && socialAlertTitle.isNotEmpty;
    return {
      'memberName': memberName,
      'branch': branch,
      'status': status,
      // Doubles survive MethodChannel → Swift NSNumber more reliably than Int64 ms.
      'timerStartMs': now.millisecondsSinceEpoch.toDouble(),
      'timerEndMs': end.millisecondsSinceEpoch.toDouble(),
      // Small int — bridge falls back to this if ms timestamps ever fail to decode.
      'remainingSeconds': seconds,
      'useLiveCountdown': useLiveCountdown,
      'urgent': seconds > 0 && seconds <= 10 * 60,
      'remainingLabel': _format(seconds),
      'hasSocialAlert': hasSocial,
      'socialAlertTitle': socialAlertTitle ?? '',
      'socialAlertBody': socialAlertBody ?? '',
      'socialAlertSender': socialAlertSender ?? '',
      'activityId': _activityId,
      'staleInMinutes': 8 * 60,
      // Prefer push tokens when entitlements are present; bridge falls back locally.
      'enableRemoteUpdates': true,
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
    String? socialAlertTitle,
    String? socialAlertBody,
    String? socialAlertSender,
    bool withSystemAlert = false,
  }) {
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
        socialAlertTitle: socialAlertTitle,
        socialAlertBody: socialAlertBody,
        socialAlertSender: socialAlertSender,
        withSystemAlert: withSystemAlert,
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
    String? socialAlertTitle,
    String? socialAlertBody,
    String? socialAlertSender,
    bool withSystemAlert = false,
  }) async {
    if (!_ready) {
      await init();
      if (!_ready) return;
    }
    if (!insideOrExiting || remainingSeconds < 0) {
      await _endBody();
      return;
    }

    try {
      final enabled = await _channel.invokeMethod<bool>('areActivitiesEnabled');
      if (enabled != true) {
        debugPrint('LiveActivity: disabled in iOS Settings');
        return;
      }

      final data = _payload(
        memberName: memberName,
        branch: branch,
        status: status,
        remainingSeconds: remainingSeconds,
        socialAlertTitle: socialAlertTitle,
        socialAlertBody: socialAlertBody,
        socialAlertSender: socialAlertSender,
      );
      data['withSystemAlert'] = withSystemAlert;

      await _channel.invokeMethod<String>('sync', data);
    } catch (e, st) {
      debugPrint('LiveActivity sync failed: $e\n$st');
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
      await _channel.invokeMethod<void>('endAll');
    } catch (e) {
      debugPrint('LiveActivity end failed: $e');
    }
  }
}
