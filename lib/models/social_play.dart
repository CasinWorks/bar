// Party socializing models — presence, meet toasts, duo lobbies.

class SocialPresence {
  const SocialPresence({
    required this.memberId,
    required this.displayName,
    required this.branch,
    required this.vibeTag,
    required this.openToMeet,
    this.sessionId,
    this.updatedAt,
    this.isSelf = false,
  });

  final String memberId;
  final String displayName;
  final String branch;
  final String vibeTag;
  final bool openToMeet;
  final String? sessionId;
  final DateTime? updatedAt;
  final bool isSelf;

  factory SocialPresence.fromSupabaseRow(Map<String, dynamic> json) {
    return SocialPresence(
      memberId: json['member_id'] as String,
      displayName: json['display_name'] as String? ?? 'Guest',
      branch: json['branch'] as String? ?? '',
      vibeTag: json['vibe_tag'] as String? ?? 'Open to a toast',
      openToMeet: json['open_to_meet'] as bool? ?? false,
      sessionId: json['session_id'] as String?,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  SocialPresence copyWith({
    bool? openToMeet,
    String? vibeTag,
    bool? isSelf,
  }) {
    return SocialPresence(
      memberId: memberId,
      displayName: displayName,
      branch: branch,
      vibeTag: vibeTag ?? this.vibeTag,
      openToMeet: openToMeet ?? this.openToMeet,
      sessionId: sessionId,
      updatedAt: updatedAt,
      isSelf: isSelf ?? this.isSelf,
    );
  }
}

enum MeetKind { toast, duoBeat }

enum MeetStatus { pending, matched, completed }

class SocialMeet {
  const SocialMeet({
    required this.id,
    required this.hostId,
    required this.hostName,
    required this.seconds,
    required this.kind,
    required this.status,
    required this.icebreaker,
    this.guestId,
    this.guestName,
    this.code,
    this.hostScore,
    this.guestScore,
    this.winnerId,
    this.createdAt,
    this.matchedAt,
    this.completedAt,
  });

  final String id;
  final String hostId;
  final String hostName;
  final String? guestId;
  final String? guestName;
  final int seconds;
  final MeetKind kind;
  final MeetStatus status;
  final String icebreaker;
  final String? code;
  final int? hostScore;
  final int? guestScore;
  final String? winnerId;
  final DateTime? createdAt;
  final DateTime? matchedAt;
  final DateTime? completedAt;

  int get minutes => seconds ~/ 60;

  bool get isMatched =>
      status == MeetStatus.matched || status == MeetStatus.completed;

  factory SocialMeet.fromSupabaseRow(Map<String, dynamic> json) {
    return SocialMeet(
      id: json['id'] as String,
      hostId: json['host_id'] as String,
      hostName: json['host_name'] as String? ?? '',
      guestId: json['guest_id'] as String?,
      guestName: json['guest_name'] as String?,
      seconds: json['seconds'] as int? ?? 60,
      kind: (json['kind'] as String?) == 'duo_beat'
          ? MeetKind.duoBeat
          : MeetKind.toast,
      status: switch (json['status'] as String?) {
        'matched' => MeetStatus.matched,
        'completed' => MeetStatus.completed,
        _ => MeetStatus.pending,
      },
      icebreaker: json['icebreaker'] as String? ?? '',
      code: json['code'] as String?,
      hostScore: json['host_score'] as int?,
      guestScore: json['guest_score'] as int?,
      winnerId: json['winner_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      matchedAt: json['matched_at'] != null
          ? DateTime.tryParse(json['matched_at'] as String)
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'] as String)
          : null,
    );
  }
}

/// Curated vibe tags for Open to Meet.
abstract final class SocialVibeTags {
  static const options = [
    'Jazz · First night',
    'Looking for a toast',
    'Here with the crew',
    'Vinyl & whiskey',
    'Down for a duel',
    'Quiet corner chat',
    'Celebrate with me',
    'Ask me anything',
  ];
}

/// Icebreaker prompts unlocked after Toast to Meet.
abstract final class IcebreakerPrompts {
  static const prompts = [
    'Ask them what song they’d freeze time for.',
    'What would you buy with one extra hour tonight?',
    'If this club had a secret password tonight, what should it be?',
    'Who in the room looks like they have the most minutes left?',
    'What’s the last thing you’d spend your final minute on?',
    'Name a cocktail after something you regret — and why.',
    'Would you trade 30 minutes for a stranger’s best story?',
    'What’s your “In Time” villain origin story?',
  ];

  static String pick([int? seed]) {
    final i = (seed ?? DateTime.now().millisecondsSinceEpoch) % prompts.length;
    return prompts[i.abs()];
  }
}
