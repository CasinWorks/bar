import '../../models/event_models.dart';

enum EventAgendaKind { invite, hosted }

/// One row in the Events & Calendar agenda — an invite you received or an
/// event you host, normalised so the calendar can treat them the same.
class EventAgendaEntry {
  const EventAgendaEntry({
    required this.kind,
    required this.id,
    required this.title,
    required this.branch,
    required this.startsAt,
    required this.subtitle,
    required this.lifecycle,
    required this.approvalStatus,
    this.endsAt,
    this.invite,
    this.hosted,
  });

  final EventAgendaKind kind;
  final String id;
  final String title;
  final String branch;
  final DateTime startsAt;
  final DateTime? endsAt;
  final String subtitle;
  final EventRuntimeLifecycle lifecycle;
  final EventApprovalStatus approvalStatus;
  final EventInvitePreview? invite;
  final ClubEventRecord? hosted;

  bool get isHosted => kind == EventAgendaKind.hosted;
  bool get isLive => lifecycle == EventRuntimeLifecycle.live;

  /// Recomputed from the event window so the calendar can reason about any
  /// moment, not just the instant the agenda was built.
  EventRuntimeLifecycle lifecycleAt(DateTime now) =>
      EventRuntimeLifecycleX.fromWindow(
        startsAt: startsAt,
        endsAt: endsAt,
        now: now,
        persistedStatus: hosted?.status,
      );

  factory EventAgendaEntry.fromInvite(EventInvitePreview invite) =>
      EventAgendaEntry(
        kind: EventAgendaKind.invite,
        id: 'invite-${invite.inviteId}',
        title: invite.title,
        branch: invite.branch,
        startsAt: invite.startsAt,
        endsAt: invite.endsAt,
        subtitle: 'Hosted by ${invite.hostName}',
        lifecycle: invite.runtimeLifecycle(),
        approvalStatus: invite.approvalStatus,
        invite: invite,
      );

  factory EventAgendaEntry.fromHosted(ClubEventRecord event) =>
      EventAgendaEntry(
        kind: EventAgendaKind.hosted,
        id: 'hosted-${event.id}',
        title: event.title,
        branch: event.branch,
        startsAt: event.startsAt,
        endsAt: event.endsAt,
        subtitle: 'You are hosting · ${event.eventType.label}',
        lifecycle: event.runtimeLifecycle(),
        approvalStatus: event.approvalStatus,
        hosted: event,
      );
}

DateTime dayOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

/// Agenda for the whole hub, newest-first inside each day.
List<EventAgendaEntry> buildEventAgenda({
  required List<EventInvitePreview> invites,
  required List<ClubEventRecord> hostedEvents,
}) {
  final hostedIds = hostedEvents.map((event) => event.id).toSet();
  final entries = <EventAgendaEntry>[
    // Host membership also creates an invite/guest row — keep the hosted
    // card as the single surface instead of duplicating the night.
    ...invites
        .where((invite) => !hostedIds.contains(invite.eventId))
        .map(EventAgendaEntry.fromInvite),
    ...hostedEvents.map(EventAgendaEntry.fromHosted),
  ]..sort((a, b) => a.startsAt.compareTo(b.startsAt));
  return entries;
}

/// A night that runs past midnight can only span so many days before the row
/// is bad data; this keeps one broken event from flooding the calendar.
const int _maxEntrySpanDays = 62;

/// Last local day an entry occupies. An event ending exactly at midnight stops
/// on the previous day, and anything still running always reaches today so a
/// guest at the venue sees tonight's event on today.
DateTime entryLastDay(EventAgendaEntry entry, DateTime now) {
  final firstDay = dayOnly(entry.startsAt);
  final endsAt = entry.endsAt;
  var lastDay = firstDay;
  if (endsAt != null && endsAt.isAfter(entry.startsAt)) {
    lastDay = dayOnly(endsAt.subtract(const Duration(microseconds: 1)));
  }
  if (entry.lifecycleAt(now) == EventRuntimeLifecycle.live) {
    final today = dayOnly(now);
    if (today.isAfter(lastDay)) lastDay = today;
  }
  final cap = firstDay.add(const Duration(days: _maxEntrySpanDays));
  return lastDay.isAfter(cap) ? cap : lastDay;
}

bool entryCoversDay(EventAgendaEntry entry, DateTime day, {DateTime? now}) {
  final target = dayOnly(day);
  if (target.isBefore(dayOnly(entry.startsAt))) return false;
  return !target.isAfter(entryLastDay(entry, now ?? DateTime.now()));
}

List<EventAgendaEntry> entriesOnDay(
  List<EventAgendaEntry> entries,
  DateTime day, {
  DateTime? now,
}) {
  final reference = now ?? DateTime.now();
  return entries
      .where((entry) => entryCoversDay(entry, day, now: reference))
      .toList(growable: false);
}

/// Days that have at least one event — drives the calendar dots. Every day an
/// event touches is marked, not just the day it starts.
Set<DateTime> agendaMarkedDays(
  List<EventAgendaEntry> entries, {
  DateTime? now,
}) {
  final reference = now ?? DateTime.now();
  final days = <DateTime>{};
  for (final entry in entries) {
    final firstDay = dayOnly(entry.startsAt);
    final lastDay = entryLastDay(entry, reference);
    for (
      var day = firstDay;
      !day.isAfter(lastDay);
      day = dayOnly(day.add(const Duration(days: 1, hours: 12)))
    ) {
      days.add(day);
    }
  }
  return days;
}

/// Events that have not started yet. Anything already running belongs to a day
/// in the agenda instead of being announced as "next up".
List<EventAgendaEntry> upcomingEntries(
  List<EventAgendaEntry> entries, {
  DateTime? now,
  int limit = 3,
}) {
  final reference = now ?? DateTime.now();
  return entries
      .where((entry) => entry.startsAt.isAfter(reference))
      .take(limit)
      .toList(growable: false);
}
