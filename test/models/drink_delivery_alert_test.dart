import 'package:flutter_test/flutter_test.dart';
import 'package:in_time_bartender/models/drink_delivery_alert.dart';
import 'package:in_time_bartender/models/drink_order.dart';

DrinkDeliveryAlert _alert(
  DrinkChargeSource source, {
  int costSeconds = 300,
  int? balanceBefore,
  int? balanceAfter,
  int? eventWalletBefore,
  int? eventWalletAfter,
  int? vipTabBefore,
  int? vipTabAfter,
  int? packageDrinksRemaining,
}) => DrinkDeliveryAlert(
  orderId: 'order-1',
  drinkName: 'Negroni',
  chargeSource: source,
  costSeconds: costSeconds,
  balanceBefore: balanceBefore,
  balanceAfter: balanceAfter,
  eventWalletBefore: eventWalletBefore,
  eventWalletAfter: eventWalletAfter,
  vipTabBefore: vipTabBefore,
  vipTabAfter: vipTabAfter,
  packageDrinksRemaining: packageDrinksRemaining,
);

void main() {
  group('DrinkDeliveryAlert settlement presentation', () {
    test('personal time uses the confirmed wallet delta', () {
      final alert = _alert(
        DrinkChargeSource.personalTime,
        costSeconds: 999,
        balanceBefore: 2100,
        balanceAfter: 1800,
      );

      expect(alert.deductionFromSeconds, 2100);
      expect(alert.deductionToSeconds, 1800);
      expect(alert.settlementAmountLabel, '−5:00');
      expect(alert.walletSourceLabel, 'PERSONAL TIME');
    });

    test('event wallet supplies a real countdown', () {
      final alert = _alert(
        DrinkChargeSource.eventWallet,
        eventWalletBefore: 3600,
        eventWalletAfter: 3240,
      );

      expect(alert.showsTimeDeduction, isTrue);
      expect(alert.deductionFromSeconds, 3600);
      expect(alert.deductionToSeconds, 3240);
      expect(alert.settlementAmountLabel, '−6:00');
      expect(alert.walletSourceLabel, 'EVENT WALLET');
    });

    test('VIP tab uses VIP snapshots rather than personal time', () {
      final alert = _alert(
        DrinkChargeSource.vipRoomTab,
        vipTabBefore: 900,
        vipTabAfter: 600,
      );

      expect(alert.deductionFromSeconds, 900);
      expect(alert.deductionToSeconds, 600);
      expect(alert.walletSourceLabel, 'VIP ROOM TAB');
    });

    test('package allowance reports units without a time deduction', () {
      final alert = _alert(
        DrinkChargeSource.packageAllowance,
        packageDrinksRemaining: 2,
      );

      expect(alert.showsTimeDeduction, isFalse);
      expect(alert.settlementTitle, 'INCLUDED DRINK USED');
      expect(alert.settlementDetail, contains('2 remaining'));
    });

    test('cash explicitly reports no time deduction', () {
      final alert = _alert(DrinkChargeSource.cashAtBar);

      expect(alert.showsTimeDeduction, isFalse);
      expect(alert.settlementTitle, 'CASH AT BAR');
      expect(alert.settlementDetail, contains('No time deducted'));
    });
  });
}
