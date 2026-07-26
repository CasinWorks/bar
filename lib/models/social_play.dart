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

  SocialPresence copyWith({bool? openToMeet, String? vibeTag, bool? isSelf}) {
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

enum FriendRequestStatus { pending, accepted, declined }

class FriendProfile {
  const FriendProfile({
    required this.memberId,
    required this.displayName,
    this.email,
    this.branch,
    this.vibeTag,
    this.updatedAt,
    this.isNearby = false,
  });

  final String memberId;
  final String displayName;
  final String? email;
  final String? branch;
  final String? vibeTag;
  final DateTime? updatedAt;
  final bool isNearby;

  factory FriendProfile.fromSupabaseRow(Map<String, dynamic> json) {
    return FriendProfile(
      memberId: (json['member_id'] ?? json['id']) as String,
      displayName: (json['display_name'] ?? json['name'] ?? 'Guest') as String,
      email: json['email'] as String?,
      branch: json['branch'] as String?,
      vibeTag: json['vibe_tag'] as String?,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
      isNearby: json['is_nearby'] as bool? ?? false,
    );
  }

  FriendProfile copyWith({bool? isNearby}) {
    return FriendProfile(
      memberId: memberId,
      displayName: displayName,
      email: email,
      branch: branch,
      vibeTag: vibeTag,
      updatedAt: updatedAt,
      isNearby: isNearby ?? this.isNearby,
    );
  }
}

class FriendRequest {
  const FriendRequest({
    required this.id,
    required this.requesterId,
    required this.requesterName,
    required this.recipientId,
    required this.recipientName,
    required this.status,
    this.createdAt,
    this.respondedAt,
    this.direction = 'inbound',
  });

  final String id;
  final String requesterId;
  final String requesterName;
  final String recipientId;
  final String recipientName;
  final FriendRequestStatus status;
  final DateTime? createdAt;
  final DateTime? respondedAt;
  final String direction;

  bool get isPending => status == FriendRequestStatus.pending;

  factory FriendRequest.fromSupabaseRow(Map<String, dynamic> json) {
    return FriendRequest(
      id: json['id'] as String,
      requesterId: json['requester_id'] as String,
      requesterName: json['requester_name'] as String? ?? 'Guest',
      recipientId: json['recipient_id'] as String,
      recipientName: json['recipient_name'] as String? ?? 'Guest',
      status: switch (json['status'] as String?) {
        'accepted' => FriendRequestStatus.accepted,
        'declined' => FriendRequestStatus.declined,
        _ => FriendRequestStatus.pending,
      },
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      respondedAt: json['responded_at'] != null
          ? DateTime.tryParse(json['responded_at'] as String)
          : null,
      direction: json['direction'] as String? ?? 'inbound',
    );
  }
}

class FriendPing {
  const FriendPing({
    required this.id,
    required this.senderId,
    required this.recipientId,
    required this.message,
    this.kind = 'friend_ping',
    this.senderName,
    this.createdAt,
    this.readAt,
  });

  final String id;
  final String senderId;
  final String recipientId;
  final String message;
  final String kind;
  final String? senderName;
  final DateTime? createdAt;
  final DateTime? readAt;

  bool get isUnread => readAt == null;
  bool get isChat => kind == 'chat';

  factory FriendPing.fromSupabaseRow(Map<String, dynamic> json) {
    return FriendPing(
      id: json['id'] as String,
      senderId: json['sender_id'] as String,
      recipientId: json['recipient_id'] as String,
      message: json['message'] as String? ?? '',
      kind: json['kind'] as String? ?? 'friend_ping',
      senderName: json['sender_name'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      readAt: json['read_at'] != null
          ? DateTime.tryParse(json['read_at'] as String)
          : null,
    );
  }
}

class FriendMessage {
  const FriendMessage({
    required this.id,
    required this.senderId,
    required this.recipientId,
    required this.body,
    this.senderName,
    this.createdAt,
    this.readAt,
  });

  final String id;
  final String senderId;
  final String recipientId;
  final String body;
  final String? senderName;
  final DateTime? createdAt;
  final DateTime? readAt;

  factory FriendMessage.fromSupabaseRow(Map<String, dynamic> json) {
    return FriendMessage(
      id: json['id'] as String,
      senderId: json['sender_id'] as String,
      recipientId: json['recipient_id'] as String,
      body: json['body'] as String? ?? '',
      senderName: json['sender_name'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      readAt: json['read_at'] != null
          ? DateTime.tryParse(json['read_at'] as String)
          : null,
    );
  }
}

class SafetyReport {
  const SafetyReport({
    required this.id,
    required this.category,
    required this.status,
    this.reportedMemberId,
    this.description,
    this.branch,
    this.createdAt,
  });

  final String id;
  final String category;
  final String status;
  final String? reportedMemberId;
  final String? description;
  final String? branch;
  final DateTime? createdAt;

  factory SafetyReport.fromSupabaseRow(Map<String, dynamic> json) {
    return SafetyReport(
      id: json['id'] as String,
      category: json['category'] as String? ?? 'other',
      status: json['status'] as String? ?? 'open',
      reportedMemberId: json['reported_member_id'] as String?,
      description: json['description'] as String?,
      branch: json['branch'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }
}

class RideAssistRequest {
  const RideAssistRequest({
    required this.id,
    required this.provider,
    required this.status,
    this.pickupBranch,
    this.destination,
    this.externalUrl,
    this.createdAt,
  });

  final String id;
  final String provider;
  final String status;
  final String? pickupBranch;
  final String? destination;
  final String? externalUrl;
  final DateTime? createdAt;

  factory RideAssistRequest.fromSupabaseRow(Map<String, dynamic> json) {
    return RideAssistRequest(
      id: json['id'] as String,
      provider: json['provider'] as String? ?? 'grab',
      status: json['status'] as String? ?? 'pending',
      pickupBranch: json['pickup_branch'] as String?,
      destination: json['destination'] as String?,
      externalUrl: json['external_url'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }
}

class InsuranceIncident {
  const InsuranceIncident({
    required this.id,
    required this.incidentType,
    required this.status,
    required this.consentToShare,
    this.reportId,
    this.partnerReference,
    this.createdAt,
  });

  final String id;
  final String incidentType;
  final String status;
  final bool consentToShare;
  final String? reportId;
  final String? partnerReference;
  final DateTime? createdAt;

  factory InsuranceIncident.fromSupabaseRow(Map<String, dynamic> json) {
    return InsuranceIncident(
      id: json['id'] as String,
      incidentType: json['incident_type'] as String? ?? 'general',
      status: json['status'] as String? ?? 'draft',
      consentToShare: json['consent_to_share'] as bool? ?? false,
      reportId: json['report_id'] as String?,
      partnerReference: json['partner_reference'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
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
