enum TimeGiftKind { toast, tipHouse, tipStaff }

enum TimeGiftStatus { pending, claimed, completed }

class TimeGift {
  const TimeGift({
    required this.id,
    required this.fromMemberId,
    required this.fromMemberName,
    required this.seconds,
    required this.kind,
    required this.status,
    this.toMemberId,
    this.toMemberName,
    this.code,
    this.message,
    this.createdAt,
    this.claimedAt,
  });

  final String id;
  final String fromMemberId;
  final String fromMemberName;
  final String? toMemberId;
  final String? toMemberName;
  final int seconds;
  final TimeGiftKind kind;
  final TimeGiftStatus status;
  final String? code;
  final String? message;
  final DateTime? createdAt;
  final DateTime? claimedAt;

  int get minutes => seconds ~/ 60;

  factory TimeGift.fromSupabaseRow(Map<String, dynamic> json) {
    return TimeGift(
      id: json['id'] as String,
      fromMemberId: json['from_member_id'] as String,
      fromMemberName: json['from_member_name'] as String? ?? '',
      toMemberId: json['to_member_id'] as String?,
      toMemberName: json['to_member_name'] as String?,
      seconds: json['seconds'] as int,
      kind: switch (json['kind'] as String?) {
        'tip_house' => TimeGiftKind.tipHouse,
        'tip_staff' => TimeGiftKind.tipStaff,
        _ => TimeGiftKind.toast,
      },
      status: switch (json['status'] as String?) {
        'claimed' => TimeGiftStatus.claimed,
        'completed' => TimeGiftStatus.completed,
        _ => TimeGiftStatus.pending,
      },
      code: json['code'] as String?,
      message: json['message'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      claimedAt: json['claimed_at'] != null
          ? DateTime.tryParse(json['claimed_at'] as String)
          : null,
    );
  }
}

/// Curated toast / tip amounts for Pass the Glass.
class GlassPour {
  const GlassPour({
    required this.id,
    required this.minutes,
    required this.label,
    required this.tagline,
  });

  final String id;
  final int minutes;
  final String label;
  final String tagline;

  int get seconds => minutes * 60;
}
