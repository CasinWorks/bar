import 'package:flutter_test/flutter_test.dart';
import 'package:in_time_bartender/models/event_guest_welcome_alert.dart';

void main() {
  group('shouldEnqueueEventGuestWelcome', () {
    bool call({
      bool isInsideClub = true,
      bool isStaff = false,
      String? eventId = 'evt_1',
      String? welcomeKey = 'evt_1@1000',
      bool isCheckedIn = true,
      bool isEventOn = true,
      Set<String> welcomed = const {},
      Iterable<String> queued = const [],
      String? eventBranch = 'Cubao Branch',
      String? sessionBranch = 'Cubao Branch',
    }) => shouldEnqueueEventGuestWelcome(
      isInsideClub: isInsideClub,
      isStaff: isStaff,
      eventId: eventId,
      welcomeKey: welcomeKey,
      isCheckedIn: isCheckedIn,
      isEventOn: isEventOn,
      welcomedKeys: welcomed,
      queuedKeys: queued,
      eventBranch: eventBranch,
      sessionBranch: sessionBranch,
    );

    test('welcomes a checked-in guest inside the club', () {
      expect(call(), isTrue);
    });

    test('waits until the door scan lands', () {
      expect(call(isCheckedIn: false), isFalse);
    });

    test('welcomes a guest who was checked in earlier in the night', () {
      // Nothing here depends on how recent the scan was — only that the event
      // is still running and this scan has not been welcomed yet.
      expect(call(welcomeKey: 'evt_1@1000', welcomed: const {}), isTrue);
    });

    test('stops welcoming once the event is over', () {
      expect(call(isEventOn: false), isFalse);
    });

    test('never fires outside the club or for staff devices', () {
      expect(call(isInsideClub: false), isFalse);
      expect(call(isStaff: true), isFalse);
    });

    test('ignores members with no active event', () {
      expect(call(eventId: null), isFalse);
      expect(call(eventId: ''), isFalse);
    });

    test('shows once per door scan even across sessions and restarts', () {
      expect(call(welcomed: {'evt_1@1000'}), isFalse);
    });

    test('welcomes again when the guest is re-scanned at the door', () {
      expect(call(welcomeKey: 'evt_1@2000', welcomed: {'evt_1@1000'}), isTrue);
    });

    test('ignores attendance with no resolvable scan key', () {
      expect(call(welcomeKey: null), isFalse);
      expect(call(welcomeKey: ''), isFalse);
    });

    test('does not double-queue the same scan', () {
      expect(call(queued: ['evt_1@1000']), isFalse);
      expect(call(queued: ['evt_1@2000']), isTrue);
    });

    test('blocks welcome when event branch does not match session branch', () {
      expect(
        call(eventBranch: 'Cubao Branch', sessionBranch: 'Tomas Morato'),
        isFalse,
      );
    });

    test('allows welcome when session branch is unknown', () {
      expect(call(sessionBranch: null), isTrue);
      expect(call(sessionBranch: '  '), isTrue);
    });

    test('matches branch labels case-insensitively', () {
      expect(
        call(eventBranch: 'cubao branch', sessionBranch: 'Cubao Branch'),
        isTrue,
      );
    });
  });

  group('eventBranchMatchesSession', () {
    test('requires an event branch when the session has one', () {
      expect(
        eventBranchMatchesSession(
          eventBranch: null,
          sessionBranch: 'Cubao Branch',
        ),
        isFalse,
      );
    });
  });
}
