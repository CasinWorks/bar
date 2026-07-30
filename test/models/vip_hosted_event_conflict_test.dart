import 'package:flutter_test/flutter_test.dart';
import 'package:in_time_bartender/models/event_models.dart';
import 'package:in_time_bartender/models/vip_hosted_event_conflict.dart';

ClubEventRecord _event({
  required DateTime startsAt,
  DateTime? endsAt,
  EventApprovalStatus approval = EventApprovalStatus.approved,
  String? status,
}) => ClubEventRecord(
  id: 'evt_1',
  title: 'Host Night',
  branch: 'Cubao',
  startsAt: startsAt,
  endsAt: endsAt,
  eventType: ClubEventType.privateSocial,
  approvalStatus: approval,
  walletSeconds: 7200,
  status: status,
);

void main() {
  group('VipHostedEventConflict', () {
    test('blocks VIP when hosting a live approved event', () {
      final now = DateTime.now();
      final live = _event(
        startsAt: now.subtract(const Duration(minutes: 10)),
        endsAt: now.add(const Duration(hours: 2)),
      );

      expect(
        VipHostedEventConflict.blocksVipBooking(activeHostedEvent: live),
        isTrue,
      );
      expect(
        VipHostedEventConflict.shouldClearActiveVip(
          activeHostedEvent: live,
          isInVipRoom: true,
        ),
        isTrue,
      );
      expect(
        VipHostedEventConflict.shouldClearActiveVip(
          activeHostedEvent: live,
          isInVipRoom: false,
        ),
        isFalse,
      );
    });

    test('does not block when there is no active hosted event', () {
      expect(
        VipHostedEventConflict.blocksVipBooking(activeHostedEvent: null),
        isFalse,
      );
      expect(
        VipHostedEventConflict.shouldClearActiveVip(
          activeHostedEvent: null,
          isInVipRoom: true,
        ),
        isFalse,
      );
    });

    test('bookingBlockedMessage is actionable', () {
      expect(
        VipHostedEventConflict.bookingBlockedMessage.toLowerCase(),
        contains('vip'),
      );
      expect(
        VipHostedEventConflict.bookingBlockedMessage.toLowerCase(),
        contains('hosting'),
      );
    });
  });
}
