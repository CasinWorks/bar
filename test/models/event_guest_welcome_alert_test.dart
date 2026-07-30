import 'package:flutter_test/flutter_test.dart';

import 'package:in_time_bartender/models/event_guest_welcome_alert.dart';

void main() {
  group('EventGuestWelcomeAlert', () {
    test('formats host and event title for the welcome overlay', () {
      const alert = EventGuestWelcomeAlert(
        id: 'evt_1',
        hostName: 'Sam',
        eventTitle: 'Birthday Bash',
      );

      expect(alert.shout, "WELCOME TO SAM'S PARTY");
      expect(alert.headline, "Welcome to Sam's party!");
      expect(alert.ctaLabel, "let's go party!!");
      expect(alert.body, "You're on the guest list — enjoy the night.");
    });

    test('a resolved candidate carries the event details into the alert', () {
      final alert = const EventWelcomeCandidate(
        source: EventWelcomeSource.attendance,
        eventId: 'evt_2',
        welcomeKey: 'evt_2@1700000000000',
        eventTitle: 'Private Social',
        hostName: 'Jordan',
        branch: 'Cubao Branch',
        isCheckedIn: true,
        isEventOn: true,
        guestName: 'Giovanni Dela Cruz',
      ).toAlert();

      expect(alert.id, 'evt_2@1700000000000');
      expect(alert.shout, "WELCOME TO JORDAN'S PARTY");
      expect(alert.headline, "Welcome to Jordan's party!");
      expect(alert.ctaLabel, "let's go party!!");
      expect(alert.branch, 'Cubao Branch');
      expect(alert.greetingName, 'Giovanni');
    });

    test('greetingName is null when the guest name is missing or blank', () {
      const noName = EventGuestWelcomeAlert(
        id: 'evt_3@1',
        hostName: 'Sam',
        eventTitle: 'Birthday Bash',
      );
      const blankName = EventGuestWelcomeAlert(
        id: 'evt_3@1',
        hostName: 'Sam',
        eventTitle: 'Birthday Bash',
        guestName: '   ',
      );

      expect(noName.greetingName, isNull);
      expect(blankName.greetingName, isNull);
    });
  });
}
