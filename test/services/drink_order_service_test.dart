import 'package:flutter_test/flutter_test.dart';
import 'package:in_time_bartender/models/drink_order.dart';
import 'package:in_time_bartender/services/drink_order_service.dart';

DrinkOrder _order({
  required String id,
  DrinkOrderStatus status = DrinkOrderStatus.pending,
  bool settled = false,
  String sessionId = 'session',
  DateTime? orderedAt,
}) {
  return DrinkOrder(
    id: id,
    sessionId: sessionId,
    memberId: 'member',
    memberName: 'Guest',
    drinkId: 'drink',
    drinkName: 'Negroni',
    chargeSource: DrinkChargeSource.personalTime,
    costSeconds: 600,
    status: status,
    orderedAt: orderedAt ?? DateTime(2026, 1, 1),
    settled: settled,
  );
}

void main() {
  group('mergeCloudDrinkOrders', () {
    test('cloud rows replace stale local pending ghosts', () {
      final local = {
        'ghost': _order(id: 'ghost'),
        'live': _order(id: 'live', status: DrinkOrderStatus.preparing),
      };
      final cloud = {
        'live': _order(id: 'live', status: DrinkOrderStatus.delivered),
      };

      mergeCloudDrinkOrders(local: local, cloud: cloud);

      expect(local.containsKey('ghost'), isFalse);
      expect(local['live']!.status, DrinkOrderStatus.delivered);
    });

    test('drops local delivered-unsettled when cloud already settled it', () {
      final local = {
        'done': _order(id: 'done', status: DrinkOrderStatus.delivered),
      };

      mergeCloudDrinkOrders(local: local, cloud: {});

      expect(local, isEmpty);
    });

    test('keeps in-flight local pending while cloud write is outstanding', () {
      final local = {'new': _order(id: 'new')};

      mergeCloudDrinkOrders(
        local: local,
        cloud: {},
        pendingCloudWrites: {'new'},
      );

      expect(local.containsKey('new'), isTrue);
    });

    test('removes cancelled orders from cache when absent from cloud', () {
      final local = {
        'old': _order(id: 'old', status: DrinkOrderStatus.cancelled),
      };

      mergeCloudDrinkOrders(local: local, cloud: {});

      expect(local.containsKey('old'), isFalse);
    });
  });

  group('isStaleDrinkOrderForMember', () {
    final now = DateTime(2026, 1, 1, 22, 0);

    test('keeps a fresh order from the live visit', () {
      final order = _order(
        id: 'live',
        orderedAt: now.subtract(const Duration(minutes: 3)),
      );

      expect(
        isStaleDrinkOrderForMember(order, activeSessionId: 'session', now: now),
        isFalse,
      );
    });

    test('keeps a delivered order awaiting settlement in the live visit', () {
      final order = _order(
        id: 'served',
        status: DrinkOrderStatus.delivered,
        orderedAt: now.subtract(const Duration(minutes: 5)),
      );

      expect(
        isStaleDrinkOrderForMember(order, activeSessionId: 'session', now: now),
        isFalse,
      );
    });

    test('drops orders belonging to an earlier visit', () {
      final order = _order(
        id: 'last-night',
        sessionId: 'other-session',
        orderedAt: now.subtract(const Duration(minutes: 3)),
      );

      expect(
        isStaleDrinkOrderForMember(order, activeSessionId: 'session', now: now),
        isTrue,
      );
    });

    test('drops everything open when there is no live visit', () {
      final order = _order(
        id: 'orphan',
        orderedAt: now.subtract(const Duration(minutes: 1)),
      );

      expect(
        isStaleDrinkOrderForMember(order, activeSessionId: null, now: now),
        isTrue,
      );
    });

    test('drops orders the bartender never closed out', () {
      final order = _order(
        id: 'forgotten',
        orderedAt: now.subtract(const Duration(hours: 5)),
      );

      expect(
        isStaleDrinkOrderForMember(order, activeSessionId: 'session', now: now),
        isTrue,
      );
    });

    test('keeps an unsettled delivery from an earlier visit so it can be '
        'charged on the next sync', () {
      final order = _order(
        id: 'served-yesterday',
        status: DrinkOrderStatus.delivered,
        sessionId: 'other-session',
        orderedAt: now.subtract(const Duration(hours: 4)),
      );
      order.deliveredAt = now.subtract(const Duration(hours: 4));

      expect(
        isStaleDrinkOrderForMember(order, activeSessionId: 'session', now: now),
        isFalse,
      );
    });

    test('drops an unsettled delivery past the grace window', () {
      final order = _order(
        id: 'never-charged',
        status: DrinkOrderStatus.delivered,
        orderedAt: now.subtract(const Duration(hours: 20)),
      );
      order.deliveredAt = now.subtract(const Duration(hours: 20));

      expect(
        isStaleDrinkOrderForMember(order, activeSessionId: 'session', now: now),
        isTrue,
      );
    });

    test('drops already settled deliveries', () {
      final order = _order(
        id: 'done',
        status: DrinkOrderStatus.delivered,
        settled: true,
        orderedAt: now,
      );

      expect(
        isStaleDrinkOrderForMember(order, activeSessionId: 'session', now: now),
        isTrue,
      );
    });
  });
}
