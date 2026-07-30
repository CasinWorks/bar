import 'package:add_2_calendar/add_2_calendar.dart' as calendar;

import '../models/event_models.dart';

class DeviceCalendarService {
  const DeviceCalendarService();

  Future<void> saveInvite(EventInvitePreview invite) => saveEvent(
    title: invite.title,
    branch: invite.branch,
    startsAt: invite.startsAt,
    endsAt: invite.endsAt,
    description: _description(
      'Hosted by ${invite.hostName}',
      invite.description,
    ),
  );

  Future<void> saveHostedEvent(ClubEventRecord event) => saveEvent(
    title: event.title,
    branch: event.branch,
    startsAt: event.startsAt,
    endsAt: event.endsAt,
    description: _description(
      'You are hosting · ${event.eventType.label}',
      event.description,
    ),
  );

  Future<void> saveEvent({
    required String title,
    required String branch,
    required DateTime startsAt,
    DateTime? endsAt,
    String description = '',
  }) {
    final event = calendar.Event(
      title: title,
      description: description,
      location: branch,
      startDate: startsAt,
      endDate: endsAt ?? startsAt.add(const Duration(hours: 2)),
      iosParams: const calendar.IOSParams(reminder: Duration(hours: 2)),
      androidParams: const calendar.AndroidParams(emailInvites: []),
    );
    return calendar.Add2Calendar.addEvent2Cal(event);
  }

  String _description(String headline, String? notes) {
    final parts = <String>[
      headline,
      if ((notes ?? '').trim().isNotEmpty) notes!.trim(),
    ];
    return parts.join('\n\n');
  }
}
