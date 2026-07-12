enum SessionPhase {
  none,
  paidAwaitingEntry,
  insideClub,
  awaitingExitScan,
  completed,
}

class ClubSessionRecord {
  ClubSessionRecord({
    required this.id,
    required this.memberId,
    required this.memberName,
    required this.purchasedSeconds,
    required this.amountPaid,
    required this.branch,
    this.phase = SessionPhase.paidAwaitingEntry,
    this.remainingSeconds = 0,
    this.drinksOrdered = 0,
    this.enteredAt,
    this.exitedAt,
  });

  final String id;
  final String memberId;
  final String memberName;
  int purchasedSeconds;
  int amountPaid;
  final String branch;
  SessionPhase phase;
  int remainingSeconds;
  int drinksOrdered;
  DateTime? enteredAt;
  DateTime? exitedAt;

  String get displayCode => id.replaceAll('-', '').substring(0, 8).toUpperCase();

  /// Prefer an in-club visit over a stale unpaid entry pass.
  static ClubSessionRecord? pickActiveForMember(
    Iterable<ClubSessionRecord> sessions,
    String memberId,
  ) {
    final active = sessions
        .where((s) => s.memberId == memberId && s.phase != SessionPhase.completed)
        .toList();
    if (active.isEmpty) return null;

    int priority(SessionPhase phase) => switch (phase) {
          SessionPhase.insideClub => 0,
          SessionPhase.awaitingExitScan => 1,
          SessionPhase.paidAwaitingEntry => 2,
          _ => 99,
        };

    active.sort((a, b) => priority(a.phase).compareTo(priority(b.phase)));
    return active.first;
  }

  static String phaseToDb(SessionPhase phase) {
    switch (phase) {
      case SessionPhase.none:
        return 'none';
      case SessionPhase.paidAwaitingEntry:
        return 'paid_awaiting_entry';
      case SessionPhase.insideClub:
        return 'inside_club';
      case SessionPhase.awaitingExitScan:
        return 'awaiting_exit_scan';
      case SessionPhase.completed:
        return 'completed';
    }
  }

  static SessionPhase phaseFromDb(String value) {
    switch (value) {
      case 'paid_awaiting_entry':
        return SessionPhase.paidAwaitingEntry;
      case 'inside_club':
        return SessionPhase.insideClub;
      case 'awaiting_exit_scan':
        return SessionPhase.awaitingExitScan;
      case 'completed':
        return SessionPhase.completed;
      default:
        return SessionPhase.none;
    }
  }

  Map<String, dynamic> toSupabaseRow() => {
        'id': id,
        'member_id': memberId,
        'member_name': memberName,
        'purchased_seconds': purchasedSeconds,
        'amount_paid': amountPaid,
        'branch': branch,
        'phase': phaseToDb(phase),
        'remaining_seconds': remainingSeconds,
        'drinks_ordered': drinksOrdered,
        'entered_at': enteredAt?.toIso8601String(),
        'exited_at': exitedAt?.toIso8601String(),
      };

  factory ClubSessionRecord.fromSupabaseRow(Map<String, dynamic> json) {
    return ClubSessionRecord(
      id: json['id'] as String,
      memberId: json['member_id'] as String,
      memberName: json['member_name'] as String,
      purchasedSeconds: json['purchased_seconds'] as int,
      amountPaid: json['amount_paid'] as int,
      branch: json['branch'] as String,
      phase: phaseFromDb(json['phase'] as String),
      remainingSeconds: json['remaining_seconds'] as int? ?? 0,
      drinksOrdered: json['drinks_ordered'] as int? ?? 0,
      enteredAt: json['entered_at'] != null
          ? DateTime.parse(json['entered_at'] as String)
          : null,
      exitedAt: json['exited_at'] != null
          ? DateTime.parse(json['exited_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'memberId': memberId,
        'memberName': memberName,
        'purchasedSeconds': purchasedSeconds,
        'amountPaid': amountPaid,
        'branch': branch,
        'phase': phase.name,
        'remainingSeconds': remainingSeconds,
        'drinksOrdered': drinksOrdered,
        'enteredAt': enteredAt?.toIso8601String(),
        'exitedAt': exitedAt?.toIso8601String(),
      };

  factory ClubSessionRecord.fromJson(Map<String, dynamic> json) {
    return ClubSessionRecord(
      id: json['id'] as String,
      memberId: json['memberId'] as String,
      memberName: json['memberName'] as String,
      purchasedSeconds: json['purchasedSeconds'] as int,
      amountPaid: json['amountPaid'] as int,
      branch: json['branch'] as String,
      phase: SessionPhase.values.byName(json['phase'] as String),
      remainingSeconds: json['remainingSeconds'] as int? ?? 0,
      drinksOrdered: json['drinksOrdered'] as int? ?? 0,
      enteredAt: json['enteredAt'] != null
          ? DateTime.parse(json['enteredAt'] as String)
          : null,
      exitedAt: json['exitedAt'] != null
          ? DateTime.parse(json['exitedAt'] as String)
          : null,
    );
  }

  ClubSessionRecord copyWith({
    SessionPhase? phase,
    int? remainingSeconds,
    int? purchasedSeconds,
    int? amountPaid,
    int? drinksOrdered,
    DateTime? enteredAt,
    DateTime? exitedAt,
  }) {
    return ClubSessionRecord(
      id: id,
      memberId: memberId,
      memberName: memberName,
      purchasedSeconds: purchasedSeconds ?? this.purchasedSeconds,
      amountPaid: amountPaid ?? this.amountPaid,
      branch: branch,
      phase: phase ?? this.phase,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      drinksOrdered: drinksOrdered ?? this.drinksOrdered,
      enteredAt: enteredAt ?? this.enteredAt,
      exitedAt: exitedAt ?? this.exitedAt,
    );
  }
}
