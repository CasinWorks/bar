/// Host-facing alert when an event guest checks in at the door.
class EventGuestCheckinAlert {
  const EventGuestCheckinAlert({
    required this.id,
    required this.guestName,
    required this.eventTitle,
    this.eventId,
    this.eventGuestId,
    this.message,
  });

  final String id;
  final String guestName;
  final String eventTitle;
  final String? eventId;
  final String? eventGuestId;
  final String? message;

  String get eyebrow => 'GUEST ARRIVED';
  String get title => guestName;
  String get body =>
      message ?? 'Checked in for $eventTitle. They are inside the club now.';

  factory EventGuestCheckinAlert.fromNotification(Map<String, dynamic> json) =>
      EventGuestCheckinAlert(
        id: json['id'] as String,
        guestName: json['guest_name'] as String? ?? 'A guest',
        eventTitle: json['event_title'] as String? ?? 'your event',
        eventId: json['event_id']?.toString(),
        eventGuestId: json['event_guest_id']?.toString(),
        message: json['message'] as String?,
      );

  factory EventGuestCheckinAlert.fromGuestRow({
    required String eventGuestId,
    required String guestName,
    required String eventTitle,
    String? eventId,
  }) => EventGuestCheckinAlert(
    id: 'guest-$eventGuestId',
    guestName: guestName,
    eventTitle: eventTitle,
    eventId: eventId,
    eventGuestId: eventGuestId,
  );
}
