import 'dart:convert';

enum QrPurpose { entry, exit }

class QrPayload {
  const QrPayload({
    required this.userId,
    required this.sessionId,
    required this.timestamp,
    required this.signature,
    required this.purpose,
    required this.memberName,
  });

  final String userId;
  final String sessionId;
  final int timestamp;
  final String signature;
  final QrPurpose purpose;
  final String memberName;

  String encode() => jsonEncode({
        'user_id': userId,
        'session_id': sessionId,
        'timestamp': timestamp,
        'signature': signature,
        'purpose': purpose.name,
        'member_name': memberName,
      });

  static QrPayload? decode(String raw) {
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return QrPayload(
        userId: map['user_id'] as String,
        sessionId: map['session_id'] as String,
        timestamp: map['timestamp'] as int,
        signature: map['signature'] as String,
        purpose: QrPurpose.values.byName(
          map['purpose'] as String? ?? 'entry',
        ),
        memberName: map['member_name'] as String? ?? 'Guest',
      );
    } catch (_) {
      return null;
    }
  }
}
