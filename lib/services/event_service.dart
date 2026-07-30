import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/supabase_config.dart';
import '../models/event_guest_checkin_alert.dart';
import '../models/event_models.dart';

class EventService {
  EventService();

  bool get usesCloud => SupabaseConfig.isConfigured;

  SupabaseClient? get _client => usesCloud ? Supabase.instance.client : null;
  RealtimeChannel? _eventGuestChannel;
  RealtimeChannel? _hostedEventGuestChannel;

  Future<EventInvitePreview> previewInviteByCode(String code) async {
    final client = _client;
    if (client == null) {
      throw Exception('Supabase is required for event invites.');
    }

    final result = await client.rpc(
      'fetch_event_invite_by_code',
      params: {'p_code': code.trim()},
    );
    return EventInvitePreview.fromJson(
      Map<String, dynamic>.from(result as Map),
    );
  }

  Future<EventInvitePreview> previewInviteByToken(String token) async {
    final client = _client;
    if (client == null) {
      throw Exception('Supabase is required for event invites.');
    }

    final result = await client.rpc(
      'fetch_event_invite_by_token',
      params: {'p_token': token.trim()},
    );
    return EventInvitePreview.fromJson(
      Map<String, dynamic>.from(result as Map),
    );
  }

  Future<EventInvitePreview> acceptInvite(
    String code, {
    String acceptedVia = 'code',
  }) async {
    final client = _client;
    if (client == null) {
      throw Exception('Supabase is required for event invites.');
    }

    final result = await client.rpc(
      'accept_event_invite',
      params: {'p_code': code.trim(), 'p_accept_via': acceptedVia},
    );
    return EventInvitePreview.fromJson(
      Map<String, dynamic>.from(result as Map),
    );
  }

  Future<EventInvitePreview> acceptInviteByToken(String token) async {
    final client = _client;
    if (client == null) {
      throw Exception('Supabase is required for event invites.');
    }

    final result = await client.rpc(
      'accept_event_invite_by_token',
      params: {'p_token': token.trim()},
    );
    return EventInvitePreview.fromJson(
      Map<String, dynamic>.from(result as Map),
    );
  }

  /// Peers admin guest-list / pending invite rows whose email matches the
  /// signed-in profile. Safe no-op when migration 036 is not applied yet.
  Future<void> linkPendingGuestRowsForCurrentUser() async {
    final client = _client;
    final uid = client?.auth.currentUser?.id;
    if (client == null || uid == null) return;
    try {
      await client.rpc(
        'link_event_guest_rows_for_member',
        params: {'p_member_id': uid},
      );
    } catch (_) {
      // Older backends without 036 still work via admin member_id + 028 sync.
    }
  }

  Future<ClubEventRecord> submitEventRequest({
    required String title,
    required String branch,
    required ClubEventType eventType,
    required DateTime startsAt,
    required DateTime endsAt,
    required int minimumPax,
    int walletSeconds = 7200,
    List<EventGuestDraft> invites = const [],
  }) async {
    final client = _client;
    if (client == null) {
      throw Exception('Supabase is required for hosted events.');
    }

    final result = await client.rpc(
      'submit_event_request',
      params: {
        'p_title': title.trim(),
        'p_branch': branch,
        'p_event_type': eventType.dbValue,
        'p_starts_at': startsAt.toUtc().toIso8601String(),
        'p_ends_at': endsAt.toUtc().toIso8601String(),
        'p_minimum_pax': minimumPax,
        'p_wallet_seconds': walletSeconds,
        'p_invites': invites.map((guest) => guest.toJson()).toList(),
      },
    );
    return ClubEventRecord.fromJson(Map<String, dynamic>.from(result as Map));
  }

  Future<List<ClubEventRecord>> listHostedEvents() async {
    final client = _client;
    if (client == null) return const [];
    final result = await client.rpc('list_my_hosted_events');
    final rows = (result as List<dynamic>? ?? const []);
    return rows
        .map(
          (row) =>
              ClubEventRecord.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  Future<List<EventInvitePreview>> listMyInvites() async {
    final client = _client;
    if (client == null) return const [];
    final result = await client.rpc('list_my_event_invites');
    final rows = (result as List<dynamic>? ?? const []);
    return rows
        .map(
          (row) => EventInvitePreview.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
  }

  Future<ActiveEventAttendance?> fetchActiveAttendance() async {
    final client = _client;
    if (client == null) return null;
    final result = await client.rpc('get_active_event_for_member');
    if (result == null) return null;
    return ActiveEventAttendance.fromJson(
      Map<String, dynamic>.from(result as Map),
    );
  }

  Future<ClubEventRecord> extendEventWallet({
    required String eventId,
    required int minutes,
  }) async {
    final client = _client;
    if (client == null) {
      throw Exception('Supabase is required for hosted events.');
    }
    final result = await client.rpc(
      'extend_event_wallet',
      params: {'p_event_id': eventId, 'p_minutes': minutes},
    );
    return ClubEventRecord.fromJson(Map<String, dynamic>.from(result as Map));
  }

  Future<HostedEventInviteResult> createHostedEventInvite({
    required String eventId,
    required String guestName,
    String? guestEmail,
    String? guestPhone,
  }) async {
    final client = _client;
    if (client == null) {
      throw Exception('Supabase is required for hosted events.');
    }
    final result = await client.rpc(
      'create_hosted_event_invite',
      params: {
        'p_event_id': eventId,
        'p_guest_name': guestName.trim(),
        'p_guest_email': guestEmail?.trim(),
        'p_guest_phone': guestPhone?.trim(),
      },
    );
    return HostedEventInviteResult.fromJson(
      Map<String, dynamic>.from(result as Map),
    );
  }

  Future<List<HostedEventInviteRow>> listHostedEventInvites(
    String eventId,
  ) async {
    final client = _client;
    if (client == null) return const [];
    final result = await client.rpc(
      'list_event_invites',
      params: {'p_event_id': eventId},
    );
    final rows = (result as List<dynamic>? ?? const []);
    return rows
        .map(
          (row) => HostedEventInviteRow.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
  }

  Future<ActiveEventAttendance> consumeEventWalletForDrink({
    required String eventId,
    required String orderId,
    required int costSeconds,
  }) async {
    final client = _client;
    if (client == null) {
      throw Exception('Supabase is required for hosted events.');
    }
    final result = await client.rpc(
      'consume_event_wallet_for_drink',
      params: {
        'p_event_id': eventId,
        'p_order_id': orderId,
        'p_seconds': costSeconds,
      },
    );
    final map = Map<String, dynamic>.from(result as Map);
    final attendance = await fetchActiveAttendance();
    if (attendance == null) {
      throw Exception('Active event not found after wallet update.');
    }
    return attendance.copyWith(
      walletSeconds: map['wallet_seconds'] as int? ?? 0,
    );
  }

  /// Fires when this member's event guest row changes (e.g. door check-in).
  void startEventGuestWatch({
    required String memberId,
    required void Function() onChanged,
  }) {
    stopEventGuestWatch();
    final client = _client;
    if (client == null) return;

    _eventGuestChannel = client
        .channel('event-guest:$memberId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'event_guests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'member_id',
            value: memberId,
          ),
          callback: (_) => onChanged(),
        )
        .subscribe();
  }

  void stopEventGuestWatch() {
    _eventGuestChannel?.unsubscribe();
    _eventGuestChannel = null;
  }

  /// Fires when a guest on the host's active event checks in at the door.
  void startHostedEventGuestWatch({
    required String eventId,
    required void Function(Map<String, dynamic> guestRow) onGuestUpdated,
  }) {
    stopHostedEventGuestWatch();
    final client = _client;
    if (client == null) return;

    _hostedEventGuestChannel = client
        .channel('hosted-event-guests:$eventId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'event_guests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'event_id',
            value: eventId,
          ),
          callback: (payload) {
            final row = payload.newRecord;
            if (row.isEmpty) return;
            onGuestUpdated(Map<String, dynamic>.from(row));
          },
        )
        .subscribe();
  }

  void stopHostedEventGuestWatch() {
    _hostedEventGuestChannel?.unsubscribe();
    _hostedEventGuestChannel = null;
  }

  Future<List<EventGuestCheckinAlert>> listHostNotifications({
    bool unreadOnly = true,
  }) async {
    final client = _client;
    if (client == null) return const [];

    try {
      final rows = await client.rpc(
        'list_event_host_notifications',
        params: {'p_unread_only': unreadOnly, 'p_limit': 20},
      );
      return (rows as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map(
            (row) => EventGuestCheckinAlert.fromNotification(
              Map<String, dynamic>.from(row),
            ),
          )
          .where((alert) => alert.id.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> markHostNotificationRead(String notificationId) async {
    final client = _client;
    if (client == null) return;
    try {
      await client.rpc(
        'mark_notification_read',
        params: {'p_notification_id': notificationId},
      );
    } catch (_) {}
  }

  Future<StaffEventCheckInResult?> staffCheckInGuest({
    required String memberId,
    required String sessionId,
  }) async {
    final client = _client;
    if (client == null) return null;
    final result = await client.rpc(
      'staff_check_in_event_guest',
      params: {'p_member_id': memberId, 'p_session_id': sessionId},
    );
    if (result == null) return null;
    return StaffEventCheckInResult.fromJson(
      Map<String, dynamic>.from(result as Map),
    );
  }

  String friendlyError(Object error) {
    final message = error.toString();
    if (message.contains('Minimum extension is 15 minutes')) {
      return 'Event wallet extensions must be at least 15 minutes.';
    }
    if (message.contains('Hosted event not found')) {
      return 'This hosted event could not be found anymore.';
    }
    if (message.contains('7 days ahead')) {
      return 'Events must be requested at least 7 days in advance.';
    }
    if (message.contains('Event is not approved yet')) {
      return 'This invite is pending admin approval.';
    }
    if (message.contains('Invite email does not match')) {
      return 'Sign in with the invited email to accept this invite.';
    }
    if (message.contains('Invite already accepted')) {
      return 'This invite has already been accepted.';
    }
    if (message.contains('Invite not found')) {
      return 'That invite code was not found.';
    }
    if (message.contains('Event wallet needs more time')) {
      return 'The event wallet is out of time. Ask the host to extend it.';
    }
    if (message.contains('Only the host can invite')) {
      return 'Only the host can invite guests to this event.';
    }
    if (message.contains('Guest name is required')) {
      return 'Enter a guest name to create an invite.';
    }
    if (message.contains('not on this event guest list')) {
      return 'You need an accepted invite for this event before drinks can use the party wallet.';
    }
    return message.replaceFirst('Exception: ', '');
  }
}
