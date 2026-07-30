/// Bartender-confirmed drink order — time is charged only when served.
enum DrinkOrderStatus { pending, preparing, delivered, cancelled }

enum DrinkChargeSource {
  personalTime,
  eventWallet,
  vipRoomTab,
  packageAllowance,
  cashAtBar,
}

extension DrinkOrderStatusLabel on DrinkOrderStatus {
  String get label => switch (this) {
    DrinkOrderStatus.pending => 'Waiting at bar',
    DrinkOrderStatus.preparing => 'Being poured',
    DrinkOrderStatus.delivered => 'Delivered',
    DrinkOrderStatus.cancelled => 'Cancelled',
  };
}

extension DrinkChargeSourceLabel on DrinkChargeSource {
  String get shortLabel => switch (this) {
    DrinkChargeSource.personalTime => 'Personal time',
    DrinkChargeSource.eventWallet => 'Event wallet',
    DrinkChargeSource.vipRoomTab => 'VIP room tab',
    DrinkChargeSource.packageAllowance => 'Package drink',
    DrinkChargeSource.cashAtBar => 'Pay at bar',
  };
}

/// Resolves which balance a new drink order is booked against.
///
/// When an event wallet can cover the pour, it wins over the member's personal
/// package allowance so party drinks debit shared event time — not personal
/// package units. VIP room tab still wins while occupied; cash always wins.
DrinkChargeSource resolveDrinkChargeSource({
  required bool payWithCash,
  required bool inVipRoom,
  required bool isStandardDrink,
  required int packageDrinksAvailable,
  required bool eventWalletCovers,
}) {
  if (payWithCash) return DrinkChargeSource.cashAtBar;
  if (inVipRoom) return DrinkChargeSource.vipRoomTab;
  if (eventWalletCovers) return DrinkChargeSource.eventWallet;
  if (isStandardDrink && packageDrinksAvailable > 0) {
    return DrinkChargeSource.packageAllowance;
  }
  return DrinkChargeSource.personalTime;
}

/// Charge sources tried in order when a delivered order is settled.
///
/// The booked source is attempted first; the fallbacks exist so a drink that
/// was already handed to the guest is never poured for free when the booked
/// balance ran dry between ordering and serving.
List<DrinkChargeSource> drinkSettlementFallbackChain(
  DrinkChargeSource booked,
) => switch (booked) {
  DrinkChargeSource.cashAtBar => const [DrinkChargeSource.cashAtBar],
  DrinkChargeSource.packageAllowance => const [
    DrinkChargeSource.packageAllowance,
    DrinkChargeSource.eventWallet,
    DrinkChargeSource.personalTime,
  ],
  DrinkChargeSource.vipRoomTab => const [
    DrinkChargeSource.vipRoomTab,
    DrinkChargeSource.eventWallet,
    DrinkChargeSource.personalTime,
  ],
  DrinkChargeSource.eventWallet => const [
    DrinkChargeSource.eventWallet,
    DrinkChargeSource.personalTime,
  ],
  DrinkChargeSource.personalTime => const [DrinkChargeSource.personalTime],
};

class DrinkOrder {
  DrinkOrder({
    required this.id,
    required this.sessionId,
    required this.memberId,
    required this.memberName,
    required this.drinkId,
    required this.drinkName,
    required this.chargeSource,
    required this.costSeconds,
    this.payWithCash = false,
    this.status = DrinkOrderStatus.pending,
    required this.orderedAt,
    this.preparingAt,
    this.deliveredAt,
    this.fulfilledByStaffId,
    this.fulfilledByStaffName,
    this.vipRoomName,
    this.eventId,
    this.settled = false,
  });

  final String id;
  final String sessionId;
  final String memberId;
  final String memberName;
  final String drinkId;
  final String drinkName;
  final DrinkChargeSource chargeSource;
  final int costSeconds;
  final bool payWithCash;
  DrinkOrderStatus status;
  final DateTime orderedAt;
  DateTime? preparingAt;
  DateTime? deliveredAt;
  String? fulfilledByStaffId;
  String? fulfilledByStaffName;
  final String? vipRoomName;
  final String? eventId;
  bool settled;

  bool get isActive =>
      status == DrinkOrderStatus.pending ||
      status == DrinkOrderStatus.preparing;

  Map<String, dynamic> toSupabaseRow() => {
    'id': id,
    'session_id': sessionId,
    'member_id': memberId,
    'member_name': memberName,
    'drink_id': drinkId,
    'drink_name': drinkName,
    'charge_source': chargeSource.name,
    'cost_seconds': costSeconds,
    'pay_with_cash': payWithCash,
    'status': status.name,
    'ordered_at': orderedAt.toUtc().toIso8601String(),
    'preparing_at': preparingAt?.toUtc().toIso8601String(),
    'delivered_at': deliveredAt?.toUtc().toIso8601String(),
    'fulfilled_by_staff_id': fulfilledByStaffId,
    'fulfilled_by_staff_name': fulfilledByStaffName,
    'vip_room_name': vipRoomName,
    'event_id': eventId,
    'settled': settled,
  };

  factory DrinkOrder.fromSupabaseRow(Map<String, dynamic> json) => DrinkOrder(
    id: json['id'] as String,
    sessionId: json['session_id'] as String,
    memberId: json['member_id'] as String,
    memberName: json['member_name'] as String,
    drinkId: json['drink_id'] as String,
    drinkName: json['drink_name'] as String,
    chargeSource: DrinkChargeSource.values.byName(
      json['charge_source'] as String,
    ),
    costSeconds: json['cost_seconds'] as int? ?? 0,
    payWithCash: json['pay_with_cash'] as bool? ?? false,
    status: DrinkOrderStatus.values.byName(json['status'] as String),
    orderedAt: DateTime.parse(json['ordered_at'] as String).toLocal(),
    preparingAt: json['preparing_at'] != null
        ? DateTime.parse(json['preparing_at'] as String).toLocal()
        : null,
    deliveredAt: json['delivered_at'] != null
        ? DateTime.parse(json['delivered_at'] as String).toLocal()
        : null,
    fulfilledByStaffId: json['fulfilled_by_staff_id'] as String?,
    fulfilledByStaffName: json['fulfilled_by_staff_name'] as String?,
    vipRoomName: json['vip_room_name'] as String?,
    eventId: json['event_id'] as String?,
    settled: json['settled'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'sessionId': sessionId,
    'memberId': memberId,
    'memberName': memberName,
    'drinkId': drinkId,
    'drinkName': drinkName,
    'chargeSource': chargeSource.name,
    'costSeconds': costSeconds,
    'payWithCash': payWithCash,
    'status': status.name,
    'orderedAt': orderedAt.toUtc().toIso8601String(),
    'preparingAt': preparingAt?.toUtc().toIso8601String(),
    'deliveredAt': deliveredAt?.toUtc().toIso8601String(),
    'fulfilledByStaffId': fulfilledByStaffId,
    'fulfilledByStaffName': fulfilledByStaffName,
    'vipRoomName': vipRoomName,
    'eventId': eventId,
    'settled': settled,
  };

  factory DrinkOrder.fromJson(Map<String, dynamic> json) => DrinkOrder(
    id: json['id'] as String,
    sessionId: json['sessionId'] as String,
    memberId: json['memberId'] as String,
    memberName: json['memberName'] as String,
    drinkId: json['drinkId'] as String,
    drinkName: json['drinkName'] as String,
    chargeSource: DrinkChargeSource.values.byName(
      json['chargeSource'] as String,
    ),
    costSeconds: json['costSeconds'] as int? ?? 0,
    payWithCash: json['payWithCash'] as bool? ?? false,
    status: DrinkOrderStatus.values.byName(json['status'] as String),
    orderedAt: DateTime.parse(json['orderedAt'] as String).toLocal(),
    preparingAt: json['preparingAt'] != null
        ? DateTime.parse(json['preparingAt'] as String).toLocal()
        : null,
    deliveredAt: json['deliveredAt'] != null
        ? DateTime.parse(json['deliveredAt'] as String).toLocal()
        : null,
    fulfilledByStaffId: json['fulfilledByStaffId'] as String?,
    fulfilledByStaffName: json['fulfilledByStaffName'] as String?,
    vipRoomName: json['vipRoomName'] as String?,
    eventId: json['eventId'] as String?,
    settled: json['settled'] as bool? ?? false,
  );

  DrinkOrder copyWith({
    DrinkOrderStatus? status,
    DateTime? preparingAt,
    DateTime? deliveredAt,
    String? fulfilledByStaffId,
    String? fulfilledByStaffName,
    bool? settled,
  }) => DrinkOrder(
    id: id,
    sessionId: sessionId,
    memberId: memberId,
    memberName: memberName,
    drinkId: drinkId,
    drinkName: drinkName,
    chargeSource: chargeSource,
    costSeconds: costSeconds,
    payWithCash: payWithCash,
    status: status ?? this.status,
    orderedAt: orderedAt,
    preparingAt: preparingAt ?? this.preparingAt,
    deliveredAt: deliveredAt ?? this.deliveredAt,
    fulfilledByStaffId: fulfilledByStaffId ?? this.fulfilledByStaffId,
    fulfilledByStaffName: fulfilledByStaffName ?? this.fulfilledByStaffName,
    vipRoomName: vipRoomName,
    eventId: eventId,
    settled: settled ?? this.settled,
  );
}
