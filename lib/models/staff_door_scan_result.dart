import 'event_models.dart';
import 'qr_payload.dart';

class StaffDoorScanResult {
  const StaffDoorScanResult({
    required this.memberName,
    required this.purpose,
    this.eventCheckIn,
    this.eventCheckInError,
    this.alreadyInside = false,
  });

  final String memberName;
  final QrPurpose purpose;
  final StaffEventCheckInResult? eventCheckIn;

  /// Set when the event guest RPC failed so the door team can act on it
  /// instead of the guest silently missing their welcome.
  final String? eventCheckInError;

  /// Entry scan on a member who was already inside — session untouched.
  final bool alreadyInside;

  bool get isEntry => purpose == QrPurpose.entry;
  bool get hasEventCheckIn => eventCheckIn != null;

  String get actionLabel => isEntry ? 'ENTRY' : 'EXIT';

  String get successMessage {
    if (hasEventCheckIn) {
      final party = eventCheckIn!.partyLabel;
      if (alreadyInside) {
        return '$memberName — invited to $party';
      }
      return '$memberName — entry confirmed · invited to $party';
    }
    if (alreadyInside) return '$memberName - already inside';
    return '$memberName - $actionLabel confirmed';
  }
}
