import 'package:flutter_test/flutter_test.dart';
import 'package:in_time_bartender/models/event_models.dart';

void main() {
  group('ClubEventRecord.fromJson', () {
    test('parses minimum pax and wallet contract fields', () {
      final event = ClubEventRecord.fromJson({
        'id': 'evt_1',
        'title': 'Rooftop Session',
        'branch': 'BGC',
        'starts_at': '2030-08-10T12:00:00Z',
        'ends_at': '2030-08-10T16:00:00Z',
        'event_type': 'brand_party',
        'approval_status': 'approved',
        'minimum_pax': 18,
        'wallet_seconds': 5400,
        'wallet_low_threshold_seconds': 1800,
        'wallet_total_extended_seconds': 900,
        'wallet_consumed_seconds': 2700,
      });

      expect(event.minimumPax, 18);
      expect(event.walletSeconds, 5400);
      expect(event.walletLowThresholdSeconds, 1800);
      expect(event.walletTotalExtendedSeconds, 900);
      expect(event.walletConsumedSeconds, 2700);
      expect(event.walletStartingSeconds, 7200);
      expect(event.walletAllocatedSeconds, 8100);
      expect(event.isWalletLow, isFalse);
    });

    test('accepts camelCase minimumPax fallback and clamps negatives', () {
      final event = ClubEventRecord.fromJson({
        'id': 'evt_2',
        'starts_at': '2030-08-10T12:00:00Z',
        'event_type': 'birthday',
        'approval_status': 'pending_review',
        'minimumPax': 12,
        'wallet_seconds': 0,
        'wallet_total_extended_seconds': 600,
        'wallet_consumed_seconds': 0,
      });

      expect(event.minimumPax, 12);
      expect(event.walletStartingSeconds, 0);
      expect(event.walletAllocatedSeconds, 600);
      expect(event.isWalletLow, isTrue);
    });
  });

  group('EventInvitePreview.fromJson', () {
    test('parses token/code invite preview payload fields', () {
      final invite = EventInvitePreview.fromJson({
        'invite_id': 'inv_1',
        'event_guest_id': 'guest_1',
        'event_id': 'evt_1',
        'title': 'Listening Party',
        'branch': 'Cubao',
        'starts_at': '2030-08-10T12:00:00Z',
        'ends_at': '2030-08-10T16:00:00Z',
        'event_type': 'listening_party',
        'approval_status': 'approved',
        'minimum_pax': 15,
        'host_id': 'host_1',
        'host_name': 'DJ Host',
        'guest_name': 'Chris',
        'guest_email': 'guest@example.com',
        'guest_phone': '+639171234567',
        'status': 'checked_in',
        'accepted_at': '2030-08-01T00:00:00Z',
        'checked_in_at': '2030-08-10T12:30:00Z',
        'accepted_via': 'token',
      });

      expect(invite.inviteId, 'inv_1');
      expect(invite.eventGuestId, 'guest_1');
      expect(invite.minimumPax, 15);
      expect(invite.guestEmail, 'guest@example.com');
      expect(invite.guestPhone, '+639171234567');
      expect(invite.acceptedVia, 'token');
      expect(invite.isAccepted, isTrue);
      expect(invite.isCheckedIn, isTrue);
    });

    test('falls back to legacy email and phone payload keys', () {
      final invite = EventInvitePreview.fromJson({
        'invite_id': 'inv_2',
        'event_id': 'evt_2',
        'starts_at': '2030-08-10T12:00:00Z',
        'event_type': 'after_party',
        'approval_status': 'approved',
        'host_name': 'Host',
        'guest_name': 'Guest',
        'status': 'registered',
        'email': 'legacy@example.com',
        'phone': '09171234567',
      });

      expect(invite.guestEmail, 'legacy@example.com');
      expect(invite.guestPhone, '09171234567');
      expect(invite.isAccepted, isTrue);
      expect(invite.isCheckedIn, isFalse);
    });
  });

  group('ActiveEventAttendance.fromJson', () {
    test('parses a checked-in guest row', () {
      final attendance = ActiveEventAttendance.fromJson({
        'event_id': 'evt_live',
        'invite_id': 'inv_live',
        'title': 'Album Launch',
        'branch': 'Cubao',
        'starts_at': '2030-08-10T12:00:00Z',
        'host_name': 'Ana',
        'wallet_seconds': 3600,
        'status': 'checked_in',
        'checked_in_at': '2030-08-10T12:05:00Z',
        'last_checked_in_at': '2030-08-10T12:05:00Z',
        'guest_name': 'Giovanni',
      });

      expect(attendance.isCheckedIn, isTrue);
      expect(attendance.hostName, 'Ana');
      expect(attendance.checkedInAt, isNotNull);
      expect(attendance.guestName, 'Giovanni');
      expect(
        attendance.welcomeKey,
        'evt_live@${DateTime.utc(2030, 8, 10, 12, 5).millisecondsSinceEpoch}',
      );
    });

    test('welcome key follows the latest door scan, not first arrival', () {
      final first = ActiveEventAttendance.fromJson({
        'event_id': 'evt_live',
        'title': 'Album Launch',
        'starts_at': '2030-08-10T12:00:00Z',
        'status': 'checked_in',
        'checked_in_at': '2030-08-10T12:05:00Z',
        'last_checked_in_at': '2030-08-10T12:05:00Z',
      });
      final rescanned = ActiveEventAttendance.fromJson({
        'event_id': 'evt_live',
        'title': 'Album Launch',
        'starts_at': '2030-08-10T12:00:00Z',
        'status': 'checked_in',
        'checked_in_at': '2030-08-10T12:05:00Z',
        'last_checked_in_at': '2030-08-10T23:40:00Z',
      });

      expect(first.welcomeKey, isNot(rescanned.welcomeKey));
    });

    test('welcome key falls back to the event id before any check-in', () {
      final attendance = ActiveEventAttendance.fromJson({
        'event_id': 'evt_live',
        'title': 'Album Launch',
        'starts_at': '2030-08-10T12:00:00Z',
        'status': 'accepted',
      });

      expect(attendance.welcomeKey, 'evt_live');
    });

    test('survives guest rows that have no invite row', () {
      final attendance = ActiveEventAttendance.fromJson({
        'event_id': 'evt_live',
        'title': 'Album Launch',
        'starts_at': '2030-08-10T12:00:00Z',
        'status': 'accepted',
      });

      expect(attendance.inviteId, isEmpty);
      expect(attendance.isCheckedIn, isFalse);
    });
  });

  group('offline cache round trips', () {
    test('an invite survives toJson/fromJson unchanged', () {
      final original = EventInvitePreview.fromJson({
        'invite_id': 'inv_1',
        'event_guest_id': 'guest_1',
        'event_id': 'evt_1',
        'title': 'BIRTHDAY OF DIANA',
        'branch': 'Cubao Branch',
        'starts_at': '2026-07-28T12:00:00Z',
        'ends_at': '2026-07-28T20:00:00Z',
        'event_type': 'birthday',
        'approval_status': 'approved',
        'minimum_pax': 10,
        'host_name': 'IAmDaddyTV',
        'guest_name': 'Giovanni',
        'status': 'checked_in',
        'checked_in_at': '2026-07-29T12:17:00Z',
        'invite_code': 'ABC123',
      });

      final restored = EventInvitePreview.fromJson(original.toJson());

      expect(restored.inviteId, original.inviteId);
      expect(restored.title, original.title);
      expect(restored.branch, original.branch);
      expect(restored.startsAt, original.startsAt);
      expect(restored.endsAt, original.endsAt);
      expect(restored.eventType, original.eventType);
      expect(restored.approvalStatus, original.approvalStatus);
      expect(restored.hostName, original.hostName);
      expect(restored.status, original.status);
      expect(restored.checkedInAt, original.checkedInAt);
      expect(restored.inviteCode, original.inviteCode);
      expect(restored.isCheckedIn, isTrue);
    });

    test('a hosted event survives toJson/fromJson unchanged', () {
      final original = ClubEventRecord.fromJson({
        'id': 'evt_1',
        'title': 'Album Launch',
        'branch': 'Cubao Branch',
        'starts_at': '2026-07-28T12:00:00Z',
        'ends_at': '2026-07-29T02:00:00Z',
        'event_type': 'album_launch',
        'approval_status': 'approved',
        'status': 'live',
        'wallet_seconds': 3600,
        'wallet_total_extended_seconds': 1800,
        'wallet_consumed_seconds': 600,
        'minimum_pax': 12,
      });

      final restored = ClubEventRecord.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.startsAt, original.startsAt);
      expect(restored.endsAt, original.endsAt);
      expect(restored.eventType, original.eventType);
      expect(restored.approvalStatus, original.approvalStatus);
      expect(restored.status, original.status);
      expect(restored.walletSeconds, original.walletSeconds);
      expect(restored.walletConsumedSeconds, original.walletConsumedSeconds);
      expect(restored.minimumPax, original.minimumPax);
    });

    test('attendance survives toJson/fromJson with its scan key', () {
      final original = ActiveEventAttendance.fromJson({
        'event_id': 'evt_1',
        'invite_id': 'inv_1',
        'title': 'BIRTHDAY OF DIANA',
        'branch': 'Cubao Branch',
        'starts_at': '2026-07-28T12:00:00Z',
        'ends_at': '2026-07-29T18:00:00Z',
        'host_name': 'IAmDaddyTV',
        'wallet_seconds': 1800,
        'status': 'checked_in',
        'checked_in_at': '2026-07-29T12:17:00Z',
        'last_checked_in_at': '2026-07-29T12:17:00Z',
        'guest_name': 'Giovanni',
      });

      final restored = ActiveEventAttendance.fromJson(original.toJson());

      expect(restored.welcomeKey, original.welcomeKey);
      expect(restored.endsAt, original.endsAt);
      expect(restored.guestName, 'Giovanni');
      expect(restored.isCheckedIn, isTrue);
    });
  });

  group('HostedEventWalletSummary', () {
    test('computes ratio and depletion safely', () {
      final event = ClubEventRecord.fromJson({
        'id': 'evt_3',
        'starts_at': '2030-08-10T12:00:00Z',
        'event_type': 'private_social',
        'approval_status': 'approved',
        'wallet_seconds': 600,
        'wallet_total_extended_seconds': 600,
        'wallet_consumed_seconds': 1200,
      });
      final summary = HostedEventWalletSummary(
        event: event,
        remainingSeconds: 0,
        lowThresholdSeconds: 900,
      );

      expect(summary.startingSeconds, 1200);
      expect(summary.allocatedSeconds, 1800);
      expect(summary.remainingMinutes, 0);
      expect(summary.lowThresholdMinutes, 15);
      expect(summary.isDepleted, isTrue);
      expect(summary.isLow, isTrue);
      expect(summary.remainingRatio, 0);
    });
  });

  group('StaffEventCheckInResult.fromJson', () {
    test('parses staff_check_in_event_guest RPC payload keys', () {
      final result = StaffEventCheckInResult.fromJson({
        'event_id': 'evt_9',
        'event_title': 'Private Social',
        'event_branch': 'Cubao Branch',
        'event_guest_id': 'guest_9',
        'invite_id': 'inv_9',
        'guest_name': 'Alex',
        'host_id': 'host_9',
        'host_name': 'Sam',
        'checked_in_at': '2030-08-10T12:30:00Z',
        'club_session_id': 'sess_9',
        'session_branch': 'Cubao Branch',
      });

      expect(result.eventId, 'evt_9');
      expect(result.eventTitle, 'Private Social');
      expect(result.guestEntryId, 'guest_9');
      expect(result.guestName, 'Alex');
      expect(result.hostName, 'Sam');
      expect(result.hostId, 'host_9');
      expect(result.eventBranch, 'Cubao Branch');
      expect(result.sessionBranch, 'Cubao Branch');
      expect(result.checkedInAt, isNotNull);
    });

    test('accepts legacy guest_entry_id alias', () {
      final result = StaffEventCheckInResult.fromJson({
        'event_id': 'evt_10',
        'event_title': 'Legacy',
        'guest_entry_id': 'guest_10',
        'guest_name': 'Blair',
        'host_name': 'Host',
      });

      expect(result.guestEntryId, 'guest_10');
    });
  });

  group('EventRuntimeLifecycle window', () {
    final startsAt = DateTime.utc(2030, 8, 10, 12);
    final endsAt = DateTime.utc(2030, 8, 10, 16);

    ClubEventRecord build({String? status}) => ClubEventRecord(
      id: 'evt_life',
      title: 'Lifecycle',
      branch: 'BGC',
      startsAt: startsAt.toLocal(),
      endsAt: endsAt.toLocal(),
      eventType: ClubEventType.privateSocial,
      approvalStatus: EventApprovalStatus.approved,
      status: status,
    );

    test('scheduled before start', () {
      final now = startsAt.subtract(const Duration(hours: 1)).toLocal();
      expect(build().runtimeLifecycle(now), EventRuntimeLifecycle.scheduled);
      expect(build().isActiveNow, isFalse);
    });

    test('live at starts_at inclusive', () {
      final now = startsAt.toLocal();
      expect(build().runtimeLifecycle(now), EventRuntimeLifecycle.live);
    });

    test('live during window and completed at ends_at exclusive', () {
      final mid = startsAt.add(const Duration(hours: 2)).toLocal();
      final atEnd = endsAt.toLocal();
      final after = endsAt.add(const Duration(minutes: 1)).toLocal();

      expect(build().runtimeLifecycle(mid), EventRuntimeLifecycle.live);
      expect(build().runtimeLifecycle(atEnd), EventRuntimeLifecycle.completed);
      expect(build().runtimeLifecycle(after), EventRuntimeLifecycle.completed);
    });

    test('cancelled overrides the time window', () {
      final mid = startsAt.add(const Duration(hours: 1)).toLocal();
      expect(
        build(status: 'cancelled').runtimeLifecycle(mid),
        EventRuntimeLifecycle.cancelled,
      );
    });
  });
}
