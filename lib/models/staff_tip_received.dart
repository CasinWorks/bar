class StaffTipReceived {
  const StaffTipReceived({
    required this.tipSeconds,
    required this.fromBalance,
    required this.toBalance,
    this.guestName,
    this.transferId,
  });

  final int tipSeconds;
  final int fromBalance;
  final int toBalance;
  final String? guestName;
  final String? transferId;

  int get tipMinutes => (tipSeconds / 60).ceil();
}
