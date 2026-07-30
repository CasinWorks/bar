import 'package:flutter_test/flutter_test.dart';
import 'package:in_time_bartender/models/club_session.dart';

void main() {
  test('toSupabaseRow includes VIP room columns used by upsert', () {
    final session = ClubSessionRecord(
      id: '11111111-1111-1111-1111-111111111111',
      memberId: '22222222-2222-2222-2222-222222222222',
      memberName: 'Guest',
      purchasedSeconds: 0,
      amountPaid: 0,
      branch: 'Cubao Branch',
      activeVipRoomSlug: 'velvet-couch',
      vipRoomTimeSeconds: 1800,
      vipRoomDrinkMinutesSpent: 12,
    );

    final row = session.toSupabaseRow();
    expect(row['active_vip_room_slug'], 'velvet-couch');
    expect(row['vip_room_time_seconds'], 1800);
    expect(row['vip_room_drink_minutes_spent'], 12);
    expect(row['phase'], 'paid_awaiting_entry');
  });

  test('fromSupabaseRow tolerates missing VIP columns', () {
    final session = ClubSessionRecord.fromSupabaseRow({
      'id': '11111111-1111-1111-1111-111111111111',
      'member_id': '22222222-2222-2222-2222-222222222222',
      'member_name': 'Guest',
      'purchased_seconds': 3600,
      'amount_paid': 0,
      'branch': 'Cubao Branch',
      'phase': 'paid_awaiting_entry',
      'remaining_seconds': 0,
    });

    expect(session.activeVipRoomSlug, isNull);
    expect(session.vipRoomTimeSeconds, 0);
    expect(session.vipRoomDrinkMinutesSpent, 0);
  });
}
