import 'package:flutter_test/flutter_test.dart';
import 'package:in_time_bartender/models/event_models.dart';
import 'package:in_time_bartender/screens/events/event_agenda.dart';

EventInvitePreview _invite({
  required String id,
  required DateTime startsAt,
  DateTime? endsAt,
  bool openEnded = false,
  String status = 'accepted',
}) => EventInvitePreview.fromJson({
  'invite_id': id,
  'event_id': 'evt_$id',
  'title': 'Invite $id',
  'branch': 'Cubao',
  'starts_at': startsAt.toUtc().toIso8601String(),
  'ends_at': openEnded
      ? null
      : (endsAt ?? startsAt.add(const Duration(hours: 3)))
            .toUtc()
            .toIso8601String(),
  'event_type': 'birthday',
  'approval_status': 'approved',
  'host_name': 'Ana',
  'guest_name': 'Chris',
  'status': status,
  'invite_code': 'CODE$id',
});

ClubEventRecord _hosted({
  required String id,
  required DateTime startsAt,
  DateTime? endsAt,
}) => ClubEventRecord.fromJson({
  'id': id,
  'title': 'Hosted $id',
  'branch': 'Cubao',
  'starts_at': startsAt.toUtc().toIso8601String(),
  'ends_at': (endsAt ?? startsAt.add(const Duration(hours: 4)))
      .toUtc()
      .toIso8601String(),
  'event_type': 'brand_party',
  'approval_status': 'approved',
});

void main() {
  // Fixed local reference so day-span maths cannot drift with the clock.
  final now = DateTime(2026, 7, 29, 20, 30);
  final today = DateTime(2026, 7, 29);
  final yesterday = DateTime(2026, 7, 28);
  final tomorrow = DateTime(2026, 7, 30);

  group('buildEventAgenda', () {
    test('merges invites and hosted events sorted by start time', () {
      final agenda = buildEventAgenda(
        invites: [_invite(id: 'b', startsAt: tomorrow.add(_at(21)))],
        hostedEvents: [_hosted(id: 'a', startsAt: today.add(_at(21)))],
      );

      expect(agenda.map((entry) => entry.id), ['hosted-a', 'invite-b']);
      expect(agenda.first.isHosted, isTrue);
      expect(agenda.last.subtitle, 'Hosted by Ana');
    });

    test('drops host self-invite when the same event is already hosted', () {
      final agenda = buildEventAgenda(
        invites: [
          _invite(id: 'a', startsAt: today.add(_at(21))),
          _invite(id: 'b', startsAt: tomorrow.add(_at(21))),
        ],
        hostedEvents: [_hosted(id: 'evt_a', startsAt: today.add(_at(21)))],
      );

      // Invite event_id is evt_$id, so invite 'a' shares the hosted id.
      expect(agenda.map((entry) => entry.id), ['hosted-evt_a', 'invite-b']);
    });

    test('filters entries down to the selected day', () {
      final agenda = buildEventAgenda(
        invites: [_invite(id: 'b', startsAt: tomorrow.add(_at(21)))],
        hostedEvents: [_hosted(id: 'a', startsAt: today.add(_at(14)))],
      );

      expect(entriesOnDay(agenda, today, now: now).single.id, 'hosted-a');
      expect(entriesOnDay(agenda, tomorrow, now: now).single.id, 'invite-b');
      expect(
        entriesOnDay(agenda, today.add(const Duration(days: 9)), now: now),
        isEmpty,
      );
    });

    test('marks every day that has an event for the calendar dots', () {
      final agenda = buildEventAgenda(
        invites: [_invite(id: 'b', startsAt: tomorrow.add(_at(21)))],
        hostedEvents: [_hosted(id: 'a', startsAt: today.add(_at(14)))],
      );

      expect(agendaMarkedDays(agenda, now: now), {today, tomorrow});
    });

    test('upcoming skips events that already finished', () {
      final agenda = buildEventAgenda(
        invites: [
          _invite(
            id: 'past',
            startsAt: today.subtract(const Duration(days: 3)),
          ),
          _invite(id: 'next', startsAt: tomorrow.add(_at(21))),
        ],
        hostedEvents: const [],
      );

      expect(upcomingEntries(agenda, now: now).map((entry) => entry.id), [
        'invite-next',
      ]);
    });
  });

  group('events that cross midnight', () {
    test('a night that runs into today shows on both days', () {
      final agenda = buildEventAgenda(
        invites: [
          _invite(
            id: 'overnight',
            startsAt: yesterday.add(_at(20)),
            endsAt: today.add(_at(2)),
          ),
        ],
        hostedEvents: const [],
      );

      expect(
        entriesOnDay(agenda, yesterday, now: now).single.id,
        'invite-overnight',
      );
      expect(
        entriesOnDay(agenda, today, now: now).single.id,
        'invite-overnight',
      );
      expect(agendaMarkedDays(agenda, now: now), {yesterday, today});
    });

    test('an event ending at midnight does not leak into the next day', () {
      final agenda = buildEventAgenda(
        invites: [
          _invite(id: 'clean', startsAt: yesterday.add(_at(20)), endsAt: today),
        ],
        hostedEvents: const [],
      );

      expect(agendaMarkedDays(agenda, now: now), {yesterday});
      expect(entriesOnDay(agenda, today, now: now), isEmpty);
    });

    test('a still-live event spans every day up to its end', () {
      final agenda = buildEventAgenda(
        invites: [
          _invite(
            id: 'live',
            startsAt: yesterday.add(_at(20)),
            endsAt: tomorrow.add(_at(4)),
          ),
        ],
        hostedEvents: const [],
      );

      expect(agendaMarkedDays(agenda, now: now), {yesterday, today, tomorrow});
    });

    test('an open-ended event that already started reaches today', () {
      final agenda = buildEventAgenda(
        invites: [
          _invite(
            id: 'open',
            startsAt: yesterday.add(_at(20)),
            openEnded: true,
          ),
        ],
        hostedEvents: const [],
      );

      expect(entriesOnDay(agenda, today, now: now).single.id, 'invite-open');
    });

    test('a live event is not announced as next up', () {
      final agenda = buildEventAgenda(
        invites: [
          _invite(
            id: 'live',
            startsAt: yesterday.add(_at(20)),
            endsAt: tomorrow.add(_at(4)),
          ),
        ],
        hostedEvents: const [],
      );

      expect(upcomingEntries(agenda, now: now), isEmpty);
    });
  });

  test('accepted guest rows count as accepted invites', () {
    final invite = _invite(id: 'x', startsAt: tomorrow);
    expect(invite.isAccepted, isTrue);
    expect(
      _invite(id: 'y', startsAt: tomorrow, status: 'invited').isAccepted,
      isFalse,
    );
  });
}

Duration _at(int hour) => Duration(hours: hour);
