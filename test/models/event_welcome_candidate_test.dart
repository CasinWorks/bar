import 'package:flutter_test/flutter_test.dart';

import 'package:in_time_bartender/models/event_guest_welcome_alert.dart';
import 'package:in_time_bartender/models/event_models.dart';

void main() {
  final now = DateTime(2026, 7, 29, 21, 30);

  ActiveEventAttendance attendance({
    String status = 'checked_in',
    String branch = 'Cubao Branch',
    DateTime? startsAt,
    DateTime? endsAt,
    DateTime? checkedInAt,
    DateTime? lastCheckedInAt,
  }) => ActiveEventAttendance(
    eventId: 'evt_live',
    inviteId: 'inv_live',
    title: 'Attendance Night',
    branch: branch,
    startsAt: startsAt ?? now.subtract(const Duration(hours: 2)),
    endsAt: endsAt,
    hostName: 'Diana',
    walletSeconds: 3600,
    walletLowThresholdSeconds: 600,
    status: status,
    checkedInAt: checkedInAt ?? now.subtract(const Duration(hours: 1)),
    lastCheckedInAt: lastCheckedInAt,
    guestName: 'Giovanni Dela Cruz',
  );

  EventInvitePreview invite({
    String eventId = 'evt_invite',
    String status = 'checked_in',
    String branch = 'Cubao Branch',
    String title = 'Invite Night',
    DateTime? startsAt,
    DateTime? endsAt,
    DateTime? checkedInAt,
    DateTime? lastCheckedInAt,
  }) => EventInvitePreview(
    inviteId: 'inv_$eventId',
    eventId: eventId,
    title: title,
    branch: branch,
    startsAt: startsAt ?? now.subtract(const Duration(hours: 2)),
    endsAt: endsAt,
    eventType: ClubEventType.birthday,
    approvalStatus: EventApprovalStatus.approved,
    hostName: 'Diana',
    guestName: 'Giovanni Dela Cruz',
    status: status,
    checkedInAt: checkedInAt,
    lastCheckedInAt: lastCheckedInAt,
  );

  group('resolveEventWelcomeCandidate', () {
    test('prefers the attendance row when the backend returns one', () {
      final candidate = resolveEventWelcomeCandidate(
        attendance: attendance(),
        invites: [invite()],
        sessionBranch: 'Cubao Branch',
        now: now,
      );

      expect(candidate!.source, EventWelcomeSource.attendance);
      expect(candidate.eventTitle, 'Attendance Night');
      expect(candidate.isCheckedIn, isTrue);
      expect(candidate.guestName, 'Giovanni Dela Cruz');
    });

    test('falls back to a checked-in invite when attendance reads null', () {
      // The field failure: the door scan succeeded but
      // `get_active_event_for_member` answered null, so the guest saw nothing.
      final candidate = resolveEventWelcomeCandidate(
        attendance: null,
        invites: [invite(checkedInAt: now.subtract(const Duration(hours: 1)))],
        sessionBranch: 'Cubao Branch',
        now: now,
      );

      expect(candidate!.source, EventWelcomeSource.invite);
      expect(candidate.eventId, 'evt_invite');
      expect(candidate.isCheckedIn, isTrue);
      expect(candidate.welcomeKey, isNot('evt_invite'));
    });

    test('welcomes a guest checked in hours earlier while the event runs', () {
      final candidate = resolveEventWelcomeCandidate(
        attendance: null,
        invites: [
          invite(
            startsAt: now.subtract(const Duration(hours: 6)),
            endsAt: now.add(const Duration(hours: 2)),
            checkedInAt: now.subtract(const Duration(hours: 5)),
          ),
        ],
        sessionBranch: 'Cubao Branch',
        now: now,
      );

      expect(candidate, isNotNull);
      expect(candidate!.isEventOn, isTrue);
    });

    test('drops the candidate once the event has ended', () {
      final candidate = resolveEventWelcomeCandidate(
        attendance: attendance(endsAt: now.subtract(const Duration(minutes: 1))),
        invites: [invite(endsAt: now.subtract(const Duration(minutes: 1)))],
        sessionBranch: 'Cubao Branch',
        now: now,
      );

      expect(candidate, isNull);
    });

    test('ignores events at another branch than the session', () {
      final candidate = resolveEventWelcomeCandidate(
        attendance: attendance(branch: 'Tomas Morato'),
        invites: [invite(branch: 'Tomas Morato')],
        sessionBranch: 'Cubao Branch',
        now: now,
      );

      expect(candidate, isNull);
    });

    test('reports an accepted invite that has not been scanned yet', () {
      final candidate = resolveEventWelcomeCandidate(
        attendance: null,
        invites: [invite(status: 'accepted')],
        sessionBranch: 'Cubao Branch',
        now: now,
      );

      expect(candidate!.isCheckedIn, isFalse);
      expect(candidate.welcomeKey, 'evt_invite');
    });

    test('picks the checked-in invite over one merely accepted', () {
      final candidate = resolveEventWelcomeCandidate(
        attendance: null,
        invites: [
          invite(
            eventId: 'evt_accepted',
            title: 'Accepted Night',
            status: 'accepted',
            startsAt: now.subtract(const Duration(hours: 3)),
          ),
          invite(
            eventId: 'evt_scanned',
            title: 'Scanned Night',
            checkedInAt: now.subtract(const Duration(minutes: 20)),
          ),
        ],
        sessionBranch: 'Cubao Branch',
        now: now,
      );

      expect(candidate!.eventTitle, 'Scanned Night');
    });

    test('keeps a guest on the list for an event starting later tonight', () {
      final candidate = resolveEventWelcomeCandidate(
        attendance: null,
        invites: [
          invite(status: 'accepted', startsAt: DateTime(2026, 7, 29, 23, 0)),
        ],
        sessionBranch: 'Cubao Branch',
        now: now,
      );

      expect(candidate, isNotNull);
      expect(candidate!.isCheckedIn, isFalse);
    });

    test('ignores declined invites', () {
      final candidate = resolveEventWelcomeCandidate(
        attendance: null,
        invites: [invite(status: 'declined')],
        sessionBranch: 'Cubao Branch',
        now: now,
      );

      expect(candidate, isNull);
    });

    test('invite and attendance agree on the welcome key for one scan', () {
      final scannedAt = now.subtract(const Duration(minutes: 15));
      final fromAttendance = resolveEventWelcomeCandidate(
        attendance: attendance(lastCheckedInAt: scannedAt),
        invites: const [],
        sessionBranch: 'Cubao Branch',
        now: now,
      );
      final fromInvite = resolveEventWelcomeCandidate(
        attendance: null,
        invites: [invite(eventId: 'evt_live', lastCheckedInAt: scannedAt)],
        sessionBranch: 'Cubao Branch',
        now: now,
      );

      expect(fromInvite!.welcomeKey, fromAttendance!.welcomeKey);
    });
  });
}
