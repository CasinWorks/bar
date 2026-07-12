import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/supabase_config.dart';
import '../models/time_gift.dart';

class TimeGiftException implements Exception {
  TimeGiftException(this.message);
  final String message;
  @override
  String toString() => message;
}

class TimeGiftService {
  bool get usesCloud => SupabaseConfig.isConfigured;

  SupabaseClient? get _client =>
      usesCloud ? Supabase.instance.client : null;

  Future<TimeGift> raiseToast({
    required int seconds,
    String? message,
  }) async {
    if (!usesCloud) {
      return TimeGift(
        id: 'local-${DateTime.now().millisecondsSinceEpoch}',
        fromMemberId: 'local',
        fromMemberName: 'You',
        seconds: seconds,
        kind: TimeGiftKind.toast,
        status: TimeGiftStatus.pending,
        code: 'GLASS-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
        message: message,
        createdAt: DateTime.now(),
      );
    }

    try {
      final row = await _client!.rpc(
        'raise_a_toast',
        params: {
          'p_seconds': seconds,
          'p_message': message,
        },
      );
      return TimeGift.fromSupabaseRow(Map<String, dynamic>.from(row as Map));
    } catch (e) {
      throw TimeGiftException(_mapError(e));
    }
  }

  Future<TimeGift> tipHouse({
    required int seconds,
    String? message,
  }) async {
    if (!usesCloud) {
      return TimeGift(
        id: 'local-tip-${DateTime.now().millisecondsSinceEpoch}',
        fromMemberId: 'local',
        fromMemberName: 'You',
        seconds: seconds,
        kind: TimeGiftKind.tipHouse,
        status: TimeGiftStatus.completed,
        message: message,
        createdAt: DateTime.now(),
      );
    }

    try {
      final row = await _client!.rpc(
        'tip_the_house',
        params: {
          'p_seconds': seconds,
          'p_message': message,
        },
      );
      return TimeGift.fromSupabaseRow(Map<String, dynamic>.from(row as Map));
    } catch (e) {
      throw TimeGiftException(_mapError(e));
    }
  }

  Future<TimeGift> tipBartender({
    required String staffId,
    required int seconds,
    String? message,
  }) async {
    if (!usesCloud) {
      return TimeGift(
        id: 'local-staff-${DateTime.now().millisecondsSinceEpoch}',
        fromMemberId: 'local',
        fromMemberName: 'You',
        toMemberId: staffId,
        toMemberName: 'Bartender',
        seconds: seconds,
        kind: TimeGiftKind.tipStaff,
        status: TimeGiftStatus.completed,
        message: message,
        createdAt: DateTime.now(),
        claimedAt: DateTime.now(),
      );
    }

    try {
      final row = await _client!.rpc(
        'tip_bartender',
        params: {
          'p_staff_id': staffId,
          'p_seconds': seconds,
          'p_message': message,
        },
      );
      return TimeGift.fromSupabaseRow(Map<String, dynamic>.from(row as Map));
    } catch (e) {
      throw TimeGiftException(_mapError(e));
    }
  }

  Future<TimeGift> claimToast(String code) async {
    if (!usesCloud) {
      throw TimeGiftException('Cloud required to claim a toast.');
    }

    try {
      final row = await _client!.rpc(
        'claim_a_toast',
        params: {'p_code': code.trim().toUpperCase()},
      );
      return TimeGift.fromSupabaseRow(Map<String, dynamic>.from(row as Map));
    } catch (e) {
      throw TimeGiftException(_mapError(e));
    }
  }

  String _mapError(Object error) {
    final message = error.toString();
    if (message.contains('Not enough time')) {
      return 'Not enough time for that pour.';
    }
    if (message.contains('already claimed') || message.contains('not found')) {
      return 'That glass was already claimed or the code is invalid.';
    }
    if (message.contains('your own toast') || message.contains('tip yourself')) {
      return 'You can\'t tip or claim your own pad.';
    }
    if (message.contains('Bartender tip pad') || message.contains('not found')) {
      return 'Tip pad not found — ask the bartender to show their pad again.';
    }
    if (message.contains('Minimum')) {
      return 'Minimum pour is 1 minute.';
    }
    if (message.contains('Maximum')) {
      return 'Maximum toast is 60 minutes.';
    }
    return 'Could not complete Pass the Glass. Check connection and try again.';
  }
}

/// Preset pours for the sheet.
abstract final class GlassPours {
  static const toast = [
    GlassPour(
      id: 'pour-5',
      minutes: 5,
      label: 'NIP',
      tagline: 'A quick cheers',
    ),
    GlassPour(
      id: 'pour-15',
      minutes: 15,
      label: 'GLASS',
      tagline: 'A proper round',
    ),
    GlassPour(
      id: 'pour-30',
      minutes: 30,
      label: 'BOTTLE',
      tagline: 'Keep the night open',
    ),
  ];

  static const tips = [
    GlassPour(
      id: 'tip-5',
      minutes: 5,
      label: 'APPRECIATION',
      tagline: 'Thank the house',
    ),
    GlassPour(
      id: 'tip-10',
      minutes: 10,
      label: 'GRATITUDE',
      tagline: 'For the service',
    ),
    GlassPour(
      id: 'tip-20',
      minutes: 20,
      label: 'STANDING OVATION',
      tagline: 'Legendary night',
    ),
  ];
}
