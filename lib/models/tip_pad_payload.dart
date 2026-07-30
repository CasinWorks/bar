import 'dart:convert';

/// NFC-style tip pad QR shown on the bartender phone.
class TipPadPayload {
  const TipPadPayload({
    required this.staffId,
    required this.staffName,
    required this.timestamp,
  });

  final String staffId;
  final String staffName;
  final int timestamp;

  static const type = 'tip_pad';

  String encode() => jsonEncode({
    'type': type,
    'staff_id': staffId,
    'staff_name': staffName,
    'timestamp': timestamp,
  });

  static TipPadPayload? tryDecode(String raw) {
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      if (map['type'] != type) return null;
      final id = map['staff_id'] as String?;
      if (id == null || id.isEmpty) return null;
      return TipPadPayload(
        staffId: id,
        staffName: map['staff_name'] as String? ?? 'Bartender',
        timestamp: map['timestamp'] as int? ?? 0,
      );
    } catch (_) {
      return null;
    }
  }

  /// Tip pads rotate; accept for ~10 minutes so QR can stay on screen.
  bool get isFresh {
    if (timestamp == 0) return true;
    final age = DateTime.now().millisecondsSinceEpoch ~/ 1000 - timestamp;
    return age < 600;
  }
}
