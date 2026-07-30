import 'package:flutter_test/flutter_test.dart';
import 'package:in_time_bartender/models/drink_order.dart';

void main() {
  group('resolveDrinkChargeSource', () {
    DrinkChargeSource resolve({
      bool payWithCash = false,
      bool inVipRoom = false,
      bool isStandardDrink = true,
      int packageDrinksAvailable = 0,
      bool eventWalletCovers = false,
    }) {
      return resolveDrinkChargeSource(
        payWithCash: payWithCash,
        inVipRoom: inVipRoom,
        isStandardDrink: isStandardDrink,
        packageDrinksAvailable: packageDrinksAvailable,
        eventWalletCovers: eventWalletCovers,
      );
    }

    test('standard drink rides the allowance while units remain', () {
      expect(
        resolve(packageDrinksAvailable: 1),
        DrinkChargeSource.packageAllowance,
      );
    });

    test('exhausted allowance falls back to personal time, never free', () {
      expect(
        resolve(packageDrinksAvailable: 0),
        DrinkChargeSource.personalTime,
      );
    });

    test('event wallet wins over personal package while the party covers', () {
      expect(
        resolve(packageDrinksAvailable: 2, eventWalletCovers: true),
        DrinkChargeSource.eventWallet,
      );
    });

    test('exhausted allowance prefers the event wallet when it can cover', () {
      expect(
        resolve(packageDrinksAvailable: 0, eventWalletCovers: true),
        DrinkChargeSource.eventWallet,
      );
    });

    test('VIP room tab takes precedence over the event wallet', () {
      expect(
        resolve(inVipRoom: true, packageDrinksAvailable: 3, eventWalletCovers: true),
        DrinkChargeSource.vipRoomTab,
      );
    });

    test('cash wins over everything', () {
      expect(
        resolve(
          payWithCash: true,
          inVipRoom: true,
          packageDrinksAvailable: 3,
          eventWalletCovers: true,
        ),
        DrinkChargeSource.cashAtBar,
      );
    });

    test('premium drink never claims a package unit', () {
      expect(
        resolve(isStandardDrink: false, packageDrinksAvailable: 4),
        DrinkChargeSource.personalTime,
      );
    });

    test('premium drink still books the event wallet when it covers', () {
      expect(
        resolve(
          isStandardDrink: false,
          packageDrinksAvailable: 4,
          eventWalletCovers: true,
        ),
        DrinkChargeSource.eventWallet,
      );
    });
  });

  group('drinkSettlementFallbackChain', () {
    test('package drink falls back to event wallet then personal time', () {
      expect(drinkSettlementFallbackChain(DrinkChargeSource.packageAllowance), [
        DrinkChargeSource.packageAllowance,
        DrinkChargeSource.eventWallet,
        DrinkChargeSource.personalTime,
      ]);
    });

    test('VIP tab falls back when the guest left the room', () {
      expect(drinkSettlementFallbackChain(DrinkChargeSource.vipRoomTab), [
        DrinkChargeSource.vipRoomTab,
        DrinkChargeSource.eventWallet,
        DrinkChargeSource.personalTime,
      ]);
    });

    test('event wallet falls back to personal time', () {
      expect(drinkSettlementFallbackChain(DrinkChargeSource.eventWallet), [
        DrinkChargeSource.eventWallet,
        DrinkChargeSource.personalTime,
      ]);
    });

    test('cash never consumes a balance', () {
      expect(drinkSettlementFallbackChain(DrinkChargeSource.cashAtBar), [
        DrinkChargeSource.cashAtBar,
      ]);
    });

    test('personal time does not raid the package allowance', () {
      expect(drinkSettlementFallbackChain(DrinkChargeSource.personalTime), [
        DrinkChargeSource.personalTime,
      ]);
    });

    test('every chain starts with the booked source', () {
      for (final source in DrinkChargeSource.values) {
        expect(drinkSettlementFallbackChain(source).first, source);
      }
    });
  });
}
