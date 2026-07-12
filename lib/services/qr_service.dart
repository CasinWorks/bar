import 'dart:convert';
import 'package:crypto/crypto.dart' show sha256;
import '../models/qr_payload.dart';

class QrService {
  String generateSignature({
    required String userId,
    required String sessionId,
    required int timestamp,
    required QrPurpose purpose,
  }) {
    final data = '$userId:$sessionId:$timestamp:${purpose.name}:blindtiger';
    return sha256.convert(utf8.encode(data)).toString().substring(0, 16);
  }

  QrPayload createPayload({
    required String userId,
    required String sessionId,
    required String memberName,
    required QrPurpose purpose,
  }) {
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final signature = generateSignature(
      userId: userId,
      sessionId: sessionId,
      timestamp: timestamp,
      purpose: purpose,
    );
    return QrPayload(
      userId: userId,
      sessionId: sessionId,
      timestamp: timestamp,
      signature: signature,
      purpose: purpose,
      memberName: memberName,
    );
  }

  bool validate(QrPayload payload) {
    final expected = generateSignature(
      userId: payload.userId,
      sessionId: payload.sessionId,
      timestamp: payload.timestamp,
      purpose: payload.purpose,
    );
    if (payload.signature != expected) return false;

    final age = DateTime.now().millisecondsSinceEpoch ~/ 1000 - payload.timestamp;
    return age < 120; // 2-minute QR refresh window
  }
}
