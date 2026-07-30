import 'drink_order.dart';

/// Guest celebration payload when bartender marks a drink delivered.
class DrinkDeliveryAlert {
  const DrinkDeliveryAlert({
    required this.orderId,
    required this.drinkName,
    required this.chargeSource,
    required this.costSeconds,
    this.balanceBefore,
    this.balanceAfter,
    this.eventWalletBefore,
    this.eventWalletAfter,
    this.vipTabBefore,
    this.vipTabAfter,
    this.bartenderName,
    this.packageDrinksRemaining,
  });

  final String orderId;
  final String drinkName;
  final DrinkChargeSource chargeSource;
  final int costSeconds;
  final int? balanceBefore;
  final int? balanceAfter;
  final int? eventWalletBefore;
  final int? eventWalletAfter;
  final int? vipTabBefore;
  final int? vipTabAfter;
  final String? bartenderName;
  final int? packageDrinksRemaining;

  String get id => 'drink-delivered-$orderId';

  bool get showsTimeDeduction =>
      chargeSource == DrinkChargeSource.personalTime ||
      chargeSource == DrinkChargeSource.eventWallet ||
      chargeSource == DrinkChargeSource.vipRoomTab;

  int? get deductionFromSeconds => switch (chargeSource) {
    DrinkChargeSource.personalTime => balanceBefore,
    DrinkChargeSource.eventWallet => eventWalletBefore,
    DrinkChargeSource.vipRoomTab => vipTabBefore,
    _ => null,
  };

  int? get deductionToSeconds => switch (chargeSource) {
    DrinkChargeSource.personalTime => balanceAfter,
    DrinkChargeSource.eventWallet => eventWalletAfter,
    DrinkChargeSource.vipRoomTab => vipTabAfter,
    _ => null,
  };

  String get walletSourceLabel => switch (chargeSource) {
    DrinkChargeSource.personalTime => 'PERSONAL TIME',
    DrinkChargeSource.eventWallet => 'EVENT WALLET',
    DrinkChargeSource.vipRoomTab => 'VIP ROOM TAB',
    DrinkChargeSource.packageAllowance => 'PACKAGE ALLOWANCE',
    DrinkChargeSource.cashAtBar => 'CASH AT BAR',
  };

  String get settlementTitle => switch (chargeSource) {
    DrinkChargeSource.packageAllowance => 'INCLUDED DRINK USED',
    DrinkChargeSource.cashAtBar => 'CASH AT BAR',
    _ => 'TIME DEDUCTED',
  };

  String get settlementAmountLabel {
    if (!showsTimeDeduction) return '';
    final from = deductionFromSeconds;
    final to = deductionToSeconds;
    final seconds = from != null && to != null
        ? (from - to).abs()
        : costSeconds.abs();
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainder = seconds % 60;
    if (hours > 0) {
      return '−$hours:${minutes.toString().padLeft(2, '0')}:'
          '${remainder.toString().padLeft(2, '0')}';
    }
    return '−$minutes:${remainder.toString().padLeft(2, '0')}';
  }

  String get settlementDetail => switch (chargeSource) {
    DrinkChargeSource.personalTime => 'Deducted from your personal wallet',
    DrinkChargeSource.eventWallet => 'Deducted from the event wallet',
    DrinkChargeSource.vipRoomTab => 'Added to your VIP room time tab',
    DrinkChargeSource.packageAllowance =>
      'Included drink consumed · ${packageDrinksRemaining ?? 0} remaining',
    DrinkChargeSource.cashAtBar =>
      'No time deducted · settle directly with the bartender',
  };
}
