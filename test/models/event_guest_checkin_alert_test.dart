import 'package:flutter_test/flutter_test.dart';

import 'package:in_time_bartender/models/event_guest_checkin_alert.dart';

void main() {
  group('EventGuestCheckinAlert', () {
    test('formats guest and event for host banner', () {
      const alert = EventGuestCheckinAlert(
        id: 'notif_1',
        guestName: 'Diana',
        eventTitle: 'Birthday Bash',
      );

      expect(alert.eyebrow, 'GUEST ARRIVED');
      expect(alert.title, 'Diana');
      expect(alert.body, contains('Birthday Bash'));
    });

    test('parses list_event_host_notifications payload', () {
      final alert = EventGuestCheckinAlert.fromNotification({
        'id': 'notif_2',
        'guest_name': 'Alex',
        'event_title': 'Private Social',
        'event_id': 'evt_1',
        'event_guest_id': 'guest_1',
        'message': 'Alex checked in for Private Social.',
      });

      expect(alert.guestName, 'Alex');
      expect(alert.eventTitle, 'Private Social');
      expect(alert.message, contains('checked in'));
    });
  });
}
