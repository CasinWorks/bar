import 'event_models.dart';

/// Case-insensitive trim match for venue branch labels on events vs sessions.
bool eventBranchMatchesSession({
  required String? eventBranch,
  required String? sessionBranch,
}) {
  final session = sessionBranch?.trim().toLowerCase() ?? '';
  if (session.isEmpty) return true;
  final event = eventBranch?.trim().toLowerCase() ?? '';
  if (event.isEmpty) return false;
  return event == session;
}

/// Where a pending welcome was resolved from.
enum EventWelcomeSource { attendance, invite }

/// The event a guest should be welcomed to, normalised so the welcome does not
/// depend on a single backend read.
///
/// `get_active_event_for_member` filters on approval, the door window *and* a
/// branch lookup against the member's club session, so it can answer null while
/// the guest is demonstrably checked in. The invite list carries the same
/// check-in status with none of those filters, so it is used as the fallback.
class EventWelcomeCandidate {
  const EventWelcomeCandidate({
    required this.source,
    required this.eventId,
    required this.welcomeKey,
    required this.eventTitle,
    required this.hostName,
    required this.branch,
    required this.isCheckedIn,
    required this.isEventOn,
    this.guestName,
  });

  final EventWelcomeSource source;
  final String eventId;
  final String welcomeKey;
  final String eventTitle;
  final String hostName;
  final String branch;

  /// Door staff have already scanned this guest in for the event.
  final bool isCheckedIn;

  /// The event is still on, so a welcome is still meaningful.
  final bool isEventOn;
  final String? guestName;

  EventGuestWelcomeAlert toAlert() => EventGuestWelcomeAlert(
    id: welcomeKey,
    hostName: hostName,
    eventTitle: eventTitle,
    branch: branch,
    guestName: guestName,
  );
}

/// Picks the event this member should be welcomed to, preferring the richer
/// attendance row and falling back to their invite list.
EventWelcomeCandidate? resolveEventWelcomeCandidate({
  required ActiveEventAttendance? attendance,
  required List<EventInvitePreview> invites,
  required String? sessionBranch,
  required DateTime now,
}) {
  bool branchFits(String? eventBranch) => eventBranchMatchesSession(
    eventBranch: eventBranch,
    sessionBranch: sessionBranch,
  );

  if (attendance != null &&
      branchFits(attendance.branch) &&
      attendance.isOnForDoorCheckIn(now)) {
    return EventWelcomeCandidate(
      source: EventWelcomeSource.attendance,
      eventId: attendance.eventId,
      welcomeKey: attendance.welcomeKey,
      eventTitle: attendance.title,
      hostName: attendance.hostName,
      branch: attendance.branch,
      isCheckedIn: attendance.isCheckedIn,
      isEventOn: true,
      guestName: attendance.guestName,
    );
  }

  final eligible =
      invites
          .where(
            (invite) =>
                invite.isAccepted &&
                branchFits(invite.branch) &&
                invite.isOnForDoorCheckIn(now),
          )
          .toList()
        // Checked-in first, then the event starting soonest — the night the
        // guest is actually standing in.
        ..sort((a, b) {
          if (a.isCheckedIn != b.isCheckedIn) return a.isCheckedIn ? -1 : 1;
          return a.startsAt.compareTo(b.startsAt);
        });

  if (eligible.isEmpty) return null;
  final invite = eligible.first;
  return EventWelcomeCandidate(
    source: EventWelcomeSource.invite,
    eventId: invite.eventId,
    welcomeKey: invite.welcomeKey,
    eventTitle: invite.title,
    hostName: invite.hostName,
    branch: invite.branch,
    isCheckedIn: invite.isCheckedIn,
    isEventOn: true,
    guestName: invite.guestName,
  );
}

/// Decides whether a checked-in guest should be shown the welcome page.
///
/// The guest is welcomed for as long as the event is still on, so a check-in
/// that landed earlier in the night (or while the app was closed) is not lost.
/// Dedupe is keyed on the door scan ([welcomeKey]), not the event, so a
/// restart, a re-login, or another refresh of the same scan cannot replay the
/// welcome — while a fresh scan at the door always does.
bool shouldEnqueueEventGuestWelcome({
  required bool isInsideClub,
  required bool isStaff,
  required String? eventId,
  required String? welcomeKey,
  required bool isCheckedIn,
  required bool isEventOn,
  required Set<String> welcomedKeys,
  required Iterable<String> queuedKeys,
  String? eventBranch,
  String? sessionBranch,
}) {
  if (!isInsideClub || isStaff) return false;
  if (eventId == null || eventId.isEmpty) return false;
  if (welcomeKey == null || welcomeKey.isEmpty) return false;
  if (!isCheckedIn || !isEventOn) return false;
  if (!eventBranchMatchesSession(
    eventBranch: eventBranch,
    sessionBranch: sessionBranch,
  )) {
    return false;
  }
  if (welcomedKeys.contains(welcomeKey)) return false;
  return !queuedKeys.contains(welcomeKey);
}

/// Guest-facing welcome shown after staff door check-in for an event invite.
class EventGuestWelcomeAlert {
  const EventGuestWelcomeAlert({
    required this.id,
    required this.hostName,
    required this.eventTitle,
    this.branch,
    this.guestName,
  });

  /// Stable id for dedup — the door scan key of the resolved candidate.
  final String id;
  final String hostName;
  final String eventTitle;
  final String? branch;
  final String? guestName;

  /// Big door-payoff line — host's party, not a generic event label.
  String get shout {
    final host = hostName.trim();
    if (host.isEmpty) return 'WELCOME TO THE PARTY';
    final upper = host.toUpperCase();
    final possessive = upper.endsWith('S') ? "$upper'" : "$upper'S";
    return 'WELCOME TO $possessive PARTY';
  }

  String get headline {
    final host = hostName.trim();
    if (host.isEmpty) return 'Welcome to the party!';
    final possessive = host.toLowerCase().endsWith('s') ? "$host'" : "$host's";
    return 'Welcome to $possessive party!';
  }

  String get ctaLabel => "let's go party!!";

  String get body => "You're on the guest list — enjoy the night.";

  /// First name only; the door greeting reads better than a full legal name.
  String? get greetingName {
    final trimmed = guestName?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed.split(RegExp(r'\s+')).first;
  }
}
