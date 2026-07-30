enum ClubEventType {
  birthday,
  listeningParty,
  brandParty,
  albumLaunch,
  afterParty,
  privateSocial,
}

extension ClubEventTypeX on ClubEventType {
  String get dbValue => switch (this) {
    ClubEventType.birthday => 'birthday',
    ClubEventType.listeningParty => 'listening_party',
    ClubEventType.brandParty => 'brand_party',
    ClubEventType.albumLaunch => 'album_launch',
    ClubEventType.afterParty => 'after_party',
    ClubEventType.privateSocial => 'private_social',
  };

  String get label => switch (this) {
    ClubEventType.birthday => 'Birthday',
    ClubEventType.listeningParty => 'Listening Party',
    ClubEventType.brandParty => 'Brand Party',
    ClubEventType.albumLaunch => 'Album Launch',
    ClubEventType.afterParty => 'After Party',
    ClubEventType.privateSocial => 'Private Social',
  };

  static ClubEventType fromDb(String? raw) => switch (raw) {
    'birthday' => ClubEventType.birthday,
    'listening_party' => ClubEventType.listeningParty,
    'brand_party' => ClubEventType.brandParty,
    'album_launch' => ClubEventType.albumLaunch,
    'after_party' => ClubEventType.afterParty,
    _ => ClubEventType.privateSocial,
  };
}

/// Runtime calendar phase derived from starts_at / ends_at (not approval).
enum EventRuntimeLifecycle { scheduled, live, completed, cancelled }

extension EventRuntimeLifecycleX on EventRuntimeLifecycle {
  String get dbValue => switch (this) {
    EventRuntimeLifecycle.scheduled => 'scheduled',
    EventRuntimeLifecycle.live => 'live',
    EventRuntimeLifecycle.completed => 'completed',
    EventRuntimeLifecycle.cancelled => 'cancelled',
  };

  String get label => switch (this) {
    EventRuntimeLifecycle.scheduled => 'Scheduled',
    EventRuntimeLifecycle.live => 'Live',
    EventRuntimeLifecycle.completed => 'Completed',
    EventRuntimeLifecycle.cancelled => 'Cancelled',
  };

  /// Half-open window: [startsAt, endsAt). Cancelled wins over time.
  static EventRuntimeLifecycle fromWindow({
    required DateTime startsAt,
    DateTime? endsAt,
    required DateTime now,
    String? persistedStatus,
  }) {
    if (persistedStatus == 'cancelled') {
      return EventRuntimeLifecycle.cancelled;
    }
    if (endsAt != null && !now.isBefore(endsAt)) {
      return EventRuntimeLifecycle.completed;
    }
    if (!startsAt.isAfter(now)) {
      return EventRuntimeLifecycle.live;
    }
    return EventRuntimeLifecycle.scheduled;
  }
}

enum EventApprovalStatus { pendingReview, approved, rejected, needsRevision }

extension EventApprovalStatusX on EventApprovalStatus {
  String get dbValue => switch (this) {
    EventApprovalStatus.pendingReview => 'pending_review',
    EventApprovalStatus.approved => 'approved',
    EventApprovalStatus.rejected => 'rejected',
    EventApprovalStatus.needsRevision => 'needs_revision',
  };

  String get label => switch (this) {
    EventApprovalStatus.pendingReview => 'Pending review',
    EventApprovalStatus.approved => 'Approved',
    EventApprovalStatus.rejected => 'Rejected',
    EventApprovalStatus.needsRevision => 'Needs revision',
  };

  static EventApprovalStatus fromDb(String? raw) => switch (raw) {
    'approved' => EventApprovalStatus.approved,
    'rejected' => EventApprovalStatus.rejected,
    'needs_revision' => EventApprovalStatus.needsRevision,
    _ => EventApprovalStatus.pendingReview,
  };
}

class EventGuestDraft {
  const EventGuestDraft({required this.name, this.email, this.phone});

  final String name;
  final String? email;
  final String? phone;

  Map<String, dynamic> toJson() => {
    'name': name,
    'email': email,
    'phone': phone,
  };
}

class HostedEventRequestDraft {
  const HostedEventRequestDraft({
    required this.title,
    required this.branch,
    required this.eventType,
    required this.startsAt,
    required this.endsAt,
    required this.expectedPax,
    required this.walletMinutes,
    this.invites = const [],
  });

  static const int minimumPax = 10;
  static const int minimumWalletMinutes = 60;
  static const Duration minimumLeadTime = Duration(days: 7);

  final String title;
  final String branch;
  final ClubEventType eventType;
  final DateTime startsAt;
  final DateTime endsAt;
  final int expectedPax;
  final int walletMinutes;
  final List<EventGuestDraft> invites;

  bool get hasMinimumPax => expectedPax >= minimumPax;
  bool get hasMinimumLeadTime =>
      !startsAt.isBefore(DateTime.now().add(minimumLeadTime));
  bool get hasValidWindow => endsAt.isAfter(startsAt);
  bool get hasValidWallet => walletMinutes >= minimumWalletMinutes;
  int get walletSeconds => walletMinutes * 60;
}

class ClubEventRecord {
  const ClubEventRecord({
    required this.id,
    required this.title,
    required this.branch,
    required this.startsAt,
    this.endsAt,
    required this.eventType,
    required this.approvalStatus,
    this.description,
    this.hostId,
    this.hostName,
    this.hostEmail,
    this.hostPhone,
    this.requestNotes,
    this.adminReviewNotes,
    this.capacity,
    this.minimumPax,
    this.walletSeconds = 0,
    this.walletLowThresholdSeconds = 1800,
    this.walletTotalExtendedSeconds = 0,
    this.walletConsumedSeconds = 0,
    this.status,
  });

  final String id;
  final String title;
  final String branch;
  final DateTime startsAt;
  final DateTime? endsAt;
  final ClubEventType eventType;
  final EventApprovalStatus approvalStatus;
  final String? status;
  final String? description;
  final String? hostId;
  final String? hostName;
  final String? hostEmail;
  final String? hostPhone;
  final String? requestNotes;
  final String? adminReviewNotes;
  final int? capacity;
  final int? minimumPax;
  final int walletSeconds;
  final int walletLowThresholdSeconds;
  final int walletTotalExtendedSeconds;
  final int walletConsumedSeconds;

  bool get isApproved =>
      approvalStatus == EventApprovalStatus.approved || status == 'live';

  /// Half-open window matching backend `is_event_active`: starts_at <= now < ends_at.
  bool get isActiveNow =>
      runtimeLifecycle(DateTime.now()) == EventRuntimeLifecycle.live;

  EventRuntimeLifecycle runtimeLifecycle([DateTime? now]) =>
      EventRuntimeLifecycleX.fromWindow(
        startsAt: startsAt,
        endsAt: endsAt,
        now: now ?? DateTime.now(),
        persistedStatus: status,
      );

  int get walletStartingSeconds {
    final computed =
        walletSeconds + walletConsumedSeconds - walletTotalExtendedSeconds;
    return computed < 0 ? 0 : computed;
  }

  int get walletAllocatedSeconds =>
      walletStartingSeconds + walletTotalExtendedSeconds;
  bool get isWalletLow => walletSeconds <= walletLowThresholdSeconds;

  ClubEventRecord copyWith({
    int? walletSeconds,
    int? walletConsumedSeconds,
    int? walletTotalExtendedSeconds,
    String? status,
  }) => ClubEventRecord(
    id: id,
    title: title,
    branch: branch,
    startsAt: startsAt,
    endsAt: endsAt,
    eventType: eventType,
    approvalStatus: approvalStatus,
    description: description,
    hostId: hostId,
    hostName: hostName,
    hostEmail: hostEmail,
    hostPhone: hostPhone,
    requestNotes: requestNotes,
    adminReviewNotes: adminReviewNotes,
    capacity: capacity,
    minimumPax: minimumPax,
    walletSeconds: walletSeconds ?? this.walletSeconds,
    walletLowThresholdSeconds: walletLowThresholdSeconds,
    walletTotalExtendedSeconds:
        walletTotalExtendedSeconds ?? this.walletTotalExtendedSeconds,
    walletConsumedSeconds: walletConsumedSeconds ?? this.walletConsumedSeconds,
    status: status ?? this.status,
  );

  factory ClubEventRecord.fromJson(Map<String, dynamic> json) =>
      ClubEventRecord(
        id: json['id'] as String,
        title: json['title'] as String? ?? 'Event',
        branch: json['branch'] as String? ?? 'Blind Tiger',
        startsAt: DateTime.parse(json['starts_at'] as String).toLocal(),
        endsAt: json['ends_at'] != null
            ? DateTime.parse(json['ends_at'] as String).toLocal()
            : null,
        eventType: ClubEventTypeX.fromDb(json['event_type'] as String?),
        approvalStatus: EventApprovalStatusX.fromDb(
          json['approval_status'] as String?,
        ),
        description: json['description'] as String?,
        hostId: json['host_id'] as String?,
        hostName: json['host_name'] as String?,
        hostEmail: json['host_email'] as String?,
        hostPhone: json['host_phone'] as String?,
        requestNotes: json['request_notes'] as String?,
        adminReviewNotes: json['admin_review_notes'] as String?,
        capacity: json['capacity'] as int?,
        minimumPax: (json['minimum_pax'] ?? json['minimumPax']) as int?,
        walletSeconds: json['wallet_seconds'] as int? ?? 0,
        walletLowThresholdSeconds:
            json['wallet_low_threshold_seconds'] as int? ?? 1800,
        walletTotalExtendedSeconds:
            json['wallet_total_extended_seconds'] as int? ?? 0,
        walletConsumedSeconds: json['wallet_consumed_seconds'] as int? ?? 0,
        status: json['status'] as String?,
      );

  /// Round-trips through [ClubEventRecord.fromJson] for the offline cache.
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'branch': branch,
    'starts_at': startsAt.toUtc().toIso8601String(),
    'ends_at': endsAt?.toUtc().toIso8601String(),
    'event_type': eventType.dbValue,
    'approval_status': approvalStatus.dbValue,
    'description': description,
    'host_id': hostId,
    'host_name': hostName,
    'host_email': hostEmail,
    'host_phone': hostPhone,
    'request_notes': requestNotes,
    'admin_review_notes': adminReviewNotes,
    'capacity': capacity,
    'minimum_pax': minimumPax,
    'wallet_seconds': walletSeconds,
    'wallet_low_threshold_seconds': walletLowThresholdSeconds,
    'wallet_total_extended_seconds': walletTotalExtendedSeconds,
    'wallet_consumed_seconds': walletConsumedSeconds,
    'status': status,
  };
}

class HostedEventWalletSummary {
  const HostedEventWalletSummary({
    required this.event,
    required this.remainingSeconds,
    required this.lowThresholdSeconds,
  });

  final ClubEventRecord event;
  final int remainingSeconds;
  final int lowThresholdSeconds;

  int get startingSeconds => event.walletStartingSeconds;
  int get allocatedSeconds => event.walletAllocatedSeconds;
  int get extendedSeconds => event.walletTotalExtendedSeconds;
  int get consumedSeconds => event.walletConsumedSeconds;
  int get remainingMinutes => (remainingSeconds / 60).ceil();
  int get lowThresholdMinutes => (lowThresholdSeconds / 60).ceil();
  bool get isDepleted => remainingSeconds <= 0;
  bool get isLow => remainingSeconds <= lowThresholdSeconds;
  double get remainingRatio {
    if (allocatedSeconds <= 0) return 0;
    return (remainingSeconds / allocatedSeconds).clamp(0, 1).toDouble();
  }
}

class EventInvitePreview {
  const EventInvitePreview({
    required this.inviteId,
    this.eventGuestId,
    required this.eventId,
    required this.title,
    required this.branch,
    required this.startsAt,
    this.endsAt,
    required this.eventType,
    required this.approvalStatus,
    this.minimumPax,
    required this.hostName,
    required this.guestName,
    required this.status,
    this.acceptedAt,
    this.checkedInAt,
    this.lastCheckedInAt,
    this.acceptedVia,
    this.guestEmail,
    this.guestPhone,
    this.hostId,
    this.description,
    this.inviteCode,
  });

  final String inviteId;
  final String? eventGuestId;
  final String eventId;
  final String title;
  final String branch;
  final DateTime startsAt;
  final DateTime? endsAt;
  final ClubEventType eventType;
  final EventApprovalStatus approvalStatus;
  final int? minimumPax;
  final String hostName;
  final String guestName;
  final String status;
  final DateTime? acceptedAt;
  final DateTime? checkedInAt;

  /// Moves on every door scan, unlike [checkedInAt] which keeps the guest's
  /// first arrival time.
  final DateTime? lastCheckedInAt;
  final String? acceptedVia;
  final String? guestEmail;
  final String? guestPhone;
  final String? hostId;
  final String? description;
  final String? inviteCode;

  bool get isAccepted =>
      status == 'registered' ||
      status == 'confirmed' ||
      status == 'accepted' ||
      status == 'checked_in';
  bool get isCheckedIn => status == 'checked_in';

  /// Same identity as [ActiveEventAttendance.welcomeKey] so a welcome raised
  /// from either source is only ever delivered once.
  String get welcomeKey => eventWelcomeKey(
    eventId: eventId,
    scannedAt: lastCheckedInAt ?? checkedInAt,
  );

  bool isOnForDoorCheckIn(DateTime now) =>
      eventIsOnForDoorCheckIn(startsAt: startsAt, endsAt: endsAt, now: now);

  EventRuntimeLifecycle runtimeLifecycle([DateTime? now]) =>
      EventRuntimeLifecycleX.fromWindow(
        startsAt: startsAt,
        endsAt: endsAt,
        now: now ?? DateTime.now(),
      );

  factory EventInvitePreview.fromJson(Map<String, dynamic> json) =>
      EventInvitePreview(
        // Admin-created guests can exist with no invite row, so the guest row
        // (then the event) stands in — dropping them hid the event entirely.
        inviteId:
            (json['invite_id'] ??
                    json['event_guest_id'] ??
                    json['event_id'] as String)
                as String,
        eventGuestId: json['event_guest_id'] as String?,
        eventId: json['event_id'] as String,
        title: json['title'] as String? ?? 'Event',
        branch: json['branch'] as String? ?? 'Blind Tiger',
        startsAt: DateTime.parse(json['starts_at'] as String).toLocal(),
        endsAt: json['ends_at'] != null
            ? DateTime.parse(json['ends_at'] as String).toLocal()
            : null,
        eventType: ClubEventTypeX.fromDb(json['event_type'] as String?),
        approvalStatus: EventApprovalStatusX.fromDb(
          json['approval_status'] as String?,
        ),
        minimumPax: (json['minimum_pax'] ?? json['minimumPax']) as int?,
        hostName: json['host_name'] as String? ?? 'Host',
        guestName: json['guest_name'] as String? ?? 'Guest',
        status: json['status'] as String? ?? 'invited',
        acceptedAt: json['accepted_at'] != null
            ? DateTime.parse(json['accepted_at'] as String).toLocal()
            : null,
        checkedInAt: json['checked_in_at'] != null
            ? DateTime.parse(json['checked_in_at'] as String).toLocal()
            : null,
        lastCheckedInAt: json['last_checked_in_at'] != null
            ? DateTime.parse(json['last_checked_in_at'] as String).toLocal()
            : null,
        acceptedVia: json['accepted_via'] as String?,
        guestEmail: json['guest_email'] as String? ?? json['email'] as String?,
        guestPhone: json['guest_phone'] as String? ?? json['phone'] as String?,
        hostId: json['host_id'] as String?,
        description: json['description'] as String?,
        inviteCode: json['invite_code'] as String?,
      );

  /// Round-trips through [EventInvitePreview.fromJson] for the offline cache.
  Map<String, dynamic> toJson() => {
    'invite_id': inviteId,
    'event_guest_id': eventGuestId,
    'event_id': eventId,
    'title': title,
    'branch': branch,
    'starts_at': startsAt.toUtc().toIso8601String(),
    'ends_at': endsAt?.toUtc().toIso8601String(),
    'event_type': eventType.dbValue,
    'approval_status': approvalStatus.dbValue,
    'minimum_pax': minimumPax,
    'host_name': hostName,
    'guest_name': guestName,
    'status': status,
    'accepted_at': acceptedAt?.toUtc().toIso8601String(),
    'checked_in_at': checkedInAt?.toUtc().toIso8601String(),
    'last_checked_in_at': lastCheckedInAt?.toUtc().toIso8601String(),
    'accepted_via': acceptedVia,
    'guest_email': guestEmail,
    'guest_phone': guestPhone,
    'host_id': hostId,
    'description': description,
    'invite_code': inviteCode,
  };
}

/// Identifies one door check-in so the welcome page can be delivered once per
/// scan. Shared by every source that can raise the welcome, so the attendance
/// row and the invite row never disagree about what has been delivered.
String eventWelcomeKey({required String eventId, DateTime? scannedAt}) =>
    scannedAt == null
    ? eventId
    : '$eventId@${scannedAt.toUtc().millisecondsSinceEpoch}';

/// True while a guest could still be checked in for this event — mirrors the
/// backend `is_event_on_for_door_checkin`: live now, or starting later today
/// and not finished.
bool eventIsOnForDoorCheckIn({
  required DateTime startsAt,
  DateTime? endsAt,
  required DateTime now,
}) {
  if (endsAt != null && !now.isBefore(endsAt)) return false;
  if (!startsAt.isAfter(now)) return true;
  return startsAt.year == now.year &&
      startsAt.month == now.month &&
      startsAt.day == now.day;
}

class ActiveEventAttendance {
  const ActiveEventAttendance({
    required this.eventId,
    required this.inviteId,
    required this.title,
    required this.branch,
    required this.startsAt,
    required this.hostName,
    required this.walletSeconds,
    required this.walletLowThresholdSeconds,
    required this.status,
    this.endsAt,
    this.checkedInAt,
    this.lastCheckedInAt,
    this.guestName,
    this.hostId,
    this.isHost = false,
  });

  final String eventId;
  final String inviteId;
  final String title;
  final String branch;
  final DateTime startsAt;
  final DateTime? endsAt;
  final String hostName;
  final int walletSeconds;
  final int walletLowThresholdSeconds;
  final String status;
  final DateTime? checkedInAt;

  /// Moves on every door scan, unlike [checkedInAt] which keeps the guest's
  /// first arrival time.
  final DateTime? lastCheckedInAt;
  final String? guestName;
  final String? hostId;
  final bool isHost;

  bool get isCheckedIn => status == 'checked_in';
  bool get isLowOnWallet => walletSeconds <= walletLowThresholdSeconds;

  /// True while the event window is live (starts_at <= now < ends_at).
  bool isLiveNow([DateTime? now]) {
    final at = now ?? DateTime.now();
    if (startsAt.isAfter(at)) return false;
    if (endsAt != null && !at.isBefore(endsAt!)) return false;
    return true;
  }

  /// Identifies one door scan so the welcome page replays on a re-scan but
  /// never on a plain refresh of the same scan.
  String get welcomeKey => eventWelcomeKey(
    eventId: eventId,
    scannedAt: lastCheckedInAt ?? checkedInAt,
  );

  bool isOnForDoorCheckIn(DateTime now) =>
      eventIsOnForDoorCheckIn(startsAt: startsAt, endsAt: endsAt, now: now);

  factory ActiveEventAttendance.fromJson(Map<String, dynamic> json) =>
      ActiveEventAttendance(
        eventId: json['event_id'] as String,
        // Guests added straight to the list have no invite row — that must
        // never stop the door check-in from reaching the guest.
        inviteId: json['invite_id'] as String? ?? '',
        title: json['title'] as String? ?? 'Event',
        branch: json['branch'] as String? ?? 'Blind Tiger',
        startsAt: DateTime.parse(json['starts_at'] as String).toLocal(),
        endsAt: json['ends_at'] != null
            ? DateTime.parse(json['ends_at'] as String).toLocal()
            : null,
        hostName: json['host_name'] as String? ?? 'Host',
        walletSeconds: json['wallet_seconds'] as int? ?? 0,
        walletLowThresholdSeconds:
            json['wallet_low_threshold_seconds'] as int? ?? 1800,
        status: json['status'] as String? ?? 'invited',
        checkedInAt: json['checked_in_at'] != null
            ? DateTime.parse(json['checked_in_at'] as String).toLocal()
            : null,
        lastCheckedInAt: json['last_checked_in_at'] != null
            ? DateTime.parse(json['last_checked_in_at'] as String).toLocal()
            : null,
        guestName: json['guest_name'] as String?,
        hostId: json['host_id'] as String?,
        isHost: json['is_host'] as bool? ?? false,
      );

  /// Round-trips through [ActiveEventAttendance.fromJson] for the offline
  /// cache, so the hub can render tonight's event before the RPC answers.
  Map<String, dynamic> toJson() => {
    'event_id': eventId,
    'invite_id': inviteId,
    'title': title,
    'branch': branch,
    'starts_at': startsAt.toUtc().toIso8601String(),
    'ends_at': endsAt?.toUtc().toIso8601String(),
    'host_name': hostName,
    'wallet_seconds': walletSeconds,
    'wallet_low_threshold_seconds': walletLowThresholdSeconds,
    'status': status,
    'checked_in_at': checkedInAt?.toUtc().toIso8601String(),
    'last_checked_in_at': lastCheckedInAt?.toUtc().toIso8601String(),
    'guest_name': guestName,
    'host_id': hostId,
    'is_host': isHost,
  };

  ActiveEventAttendance copyWith({
    int? walletSeconds,
    String? status,
    DateTime? checkedInAt,
    DateTime? lastCheckedInAt,
    bool? isHost,
  }) => ActiveEventAttendance(
    eventId: eventId,
    inviteId: inviteId,
    title: title,
    branch: branch,
    startsAt: startsAt,
    endsAt: endsAt,
    hostName: hostName,
    walletSeconds: walletSeconds ?? this.walletSeconds,
    walletLowThresholdSeconds: walletLowThresholdSeconds,
    status: status ?? this.status,
    checkedInAt: checkedInAt ?? this.checkedInAt,
    lastCheckedInAt: lastCheckedInAt ?? this.lastCheckedInAt,
    guestName: guestName,
    hostId: hostId,
    isHost: isHost ?? this.isHost,
  );
}

class StaffEventCheckInResult {
  const StaffEventCheckInResult({
    required this.eventId,
    required this.eventTitle,
    required this.guestEntryId,
    required this.guestName,
    required this.hostName,
    this.hostId,
    this.checkedInAt,
    this.eventBranch,
    this.sessionBranch,
  });

  final String eventId;
  final String eventTitle;
  final String guestEntryId;
  final String guestName;
  final String hostName;
  final String? hostId;
  final DateTime? checkedInAt;
  final String? eventBranch;
  final String? sessionBranch;

  /// Door overlay label — "[host]'s party".
  String get partyLabel {
    final host = hostName.trim();
    if (host.isEmpty) return eventTitle;
    return host.toLowerCase().endsWith('s') ? "$host' party" : "$host's party";
  }

  factory StaffEventCheckInResult.fromJson(Map<String, dynamic> json) =>
      StaffEventCheckInResult(
        eventId: json['event_id'] as String,
        eventTitle: json['event_title'] as String? ?? 'Event',
        // RPC returns event_guest_id; accept guest_entry_id as a legacy alias.
        guestEntryId:
            (json['event_guest_id'] ?? json['guest_entry_id']) as String,
        guestName: json['guest_name'] as String? ?? 'Guest',
        hostName: json['host_name'] as String? ?? 'Host',
        hostId: json['host_id'] as String?,
        checkedInAt: json['checked_in_at'] != null
            ? DateTime.parse(json['checked_in_at'] as String).toLocal()
            : null,
        eventBranch: json['event_branch'] as String?,
        sessionBranch: json['session_branch'] as String?,
      );
}

/// Invite minted by a host for a guest — includes shareable code + token.
class HostedEventInviteResult {
  const HostedEventInviteResult({
    required this.inviteId,
    required this.eventId,
    required this.guestName,
    required this.inviteCode,
    required this.inviteToken,
    required this.status,
    required this.title,
    required this.branch,
    required this.startsAt,
    this.endsAt,
    this.guestEmail,
    this.guestPhone,
    this.hostName,
  });

  final String inviteId;
  final String eventId;
  final String guestName;
  final String inviteCode;
  final String inviteToken;
  final String status;
  final String title;
  final String branch;
  final DateTime startsAt;
  final DateTime? endsAt;
  final String? guestEmail;
  final String? guestPhone;
  final String? hostName;

  String get sharePath =>
      Uri(path: '/event-invite', queryParameters: {'code': inviteCode})
          .toString();

  String get deepLink => 'blindtiger://event-invite?code=$inviteCode';

  factory HostedEventInviteResult.fromJson(Map<String, dynamic> json) =>
      HostedEventInviteResult(
        inviteId: json['invite_id'] as String,
        eventId: json['event_id'] as String,
        guestName: json['guest_name'] as String? ?? 'Guest',
        inviteCode: (json['invite_code'] as String? ?? '').toUpperCase(),
        inviteToken: json['invite_token'] as String? ?? '',
        status: json['status'] as String? ?? 'pending',
        title: json['title'] as String? ?? 'Event',
        branch: json['branch'] as String? ?? 'Blind Tiger',
        startsAt: DateTime.parse(json['starts_at'] as String).toLocal(),
        endsAt: json['ends_at'] != null
            ? DateTime.parse(json['ends_at'] as String).toLocal()
            : null,
        guestEmail: json['guest_email'] as String?,
        guestPhone: json['guest_phone'] as String?,
        hostName: json['host_name'] as String?,
      );
}

/// Row from list_event_invites for the host guest-management sheet.
class HostedEventInviteRow {
  const HostedEventInviteRow({
    required this.id,
    required this.guestName,
    required this.status,
    required this.inviteCode,
    this.guestEmail,
    this.inviteToken,
    this.acceptedAt,
  });

  final String id;
  final String guestName;
  final String status;
  final String inviteCode;
  final String? guestEmail;
  final String? inviteToken;
  final DateTime? acceptedAt;

  bool get isHostInvite => false;

  factory HostedEventInviteRow.fromJson(Map<String, dynamic> json) =>
      HostedEventInviteRow(
        id: json['id'] as String,
        guestName: json['guest_name'] as String? ?? 'Guest',
        status: json['status'] as String? ?? 'pending',
        inviteCode: (json['invite_code'] as String? ?? '').toUpperCase(),
        guestEmail: json['guest_email'] as String?,
        inviteToken: json['invite_token'] as String?,
        acceptedAt: json['accepted_at'] != null
            ? DateTime.parse(json['accepted_at'] as String).toLocal()
            : null,
      );
}
