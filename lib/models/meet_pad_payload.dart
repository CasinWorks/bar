import 'dart:convert';

import 'social_play.dart';

/// Guest↔guest meet QR — same energy as the bartender tip pad.
class MeetPadPayload {
  const MeetPadPayload({
    required this.code,
    required this.hostName,
    required this.kind,
    required this.timestamp,
  });

  final String code;
  final String hostName;
  final MeetKind kind;
  final int timestamp;

  static const type = 'meet_pad';

  String encode() => jsonEncode({
    'type': type,
    'code': code,
    'host_name': hostName,
    'kind': kind == MeetKind.duoBeat ? 'duo_beat' : 'meet_toast',
    'timestamp': timestamp,
  });

  static MeetPadPayload? tryDecode(String raw) {
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      if (map['type'] != type) return null;
      final code = (map['code'] as String?)?.trim().toUpperCase();
      if (code == null || code.isEmpty) return null;
      return MeetPadPayload(
        code: code,
        hostName: map['host_name'] as String? ?? 'Guest',
        kind: (map['kind'] as String?) == 'duo_beat'
            ? MeetKind.duoBeat
            : MeetKind.toast,
        timestamp: map['timestamp'] as int? ?? 0,
      );
    } catch (_) {
      return null;
    }
  }

  /// Meet pads stay scannable for ~10 minutes.
  bool get isFresh {
    if (timestamp == 0) return true;
    final age = DateTime.now().millisecondsSinceEpoch ~/ 1000 - timestamp;
    return age < 600;
  }
}
