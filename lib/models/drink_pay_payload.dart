import 'dart:convert';

/// Payment QR shown on the bartender POS after Start Order → cart.
class DrinkPayPayload {
  const DrinkPayPayload({
    required this.ticketId,
    required this.staffId,
    required this.staffName,
    required this.timestamp,
    this.lineCount = 0,
  });

  final String ticketId;
  final String staffId;
  final String staffName;
  final int timestamp;
  final int lineCount;

  static const type = 'drink_pay';

  String encode() => jsonEncode({
    'type': type,
    'ticket_id': ticketId,
    'staff_id': staffId,
    'staff_name': staffName,
    'timestamp': timestamp,
    'line_count': lineCount,
  });

  static DrinkPayPayload? tryDecode(String raw) {
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      if (map['type'] != type) return null;
      final ticketId = map['ticket_id'] as String?;
      if (ticketId == null || ticketId.isEmpty) return null;
      return DrinkPayPayload(
        ticketId: ticketId,
        staffId: map['staff_id'] as String? ?? '',
        staffName: map['staff_name'] as String? ?? 'Bartender',
        timestamp: map['timestamp'] as int? ?? 0,
        lineCount: (map['line_count'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      return null;
    }
  }

  /// Tickets expire server-side at 10 minutes; keep client check aligned.
  bool get isFresh {
    if (timestamp == 0) return true;
    final age = DateTime.now().millisecondsSinceEpoch ~/ 1000 - timestamp;
    return age < 600;
  }
}
