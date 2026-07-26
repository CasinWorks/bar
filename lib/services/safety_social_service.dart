import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/supabase_config.dart';
import '../models/social_play.dart';
import 'insurance_partner_service.dart';
import 'ride_partner_service.dart';

class SafetySocialException implements Exception {
  SafetySocialException(this.message);
  final String message;
  @override
  String toString() => message;
}

class SafetySocialService {
  SafetySocialService({
    RidePartner? ridePartner,
    InsurancePartner? insurancePartner,
  }) : _ridePartner = ridePartner ?? const GrabDeepLinkPartner(),
       _insurancePartner = insurancePartner ?? const DemoInsurancePartner();

  bool _forceDemoMode = false;

  bool get usesCloud => SupabaseConfig.isConfigured && !_forceDemoMode;
  SupabaseClient? get _client => usesCloud ? Supabase.instance.client : null;

  final RidePartner _ridePartner;
  final InsurancePartner _insurancePartner;
  final _rng = Random();

  final Map<String, FriendProfile> _localProfiles = {
    'friend-lexi': const FriendProfile(
      memberId: 'friend-lexi',
      displayName: 'Lexi',
      email: 'lexi@blindtiger.local',
      branch: '',
      vibeTag: 'Jazz · First night',
      isNearby: true,
    ),
    'friend-marco': const FriendProfile(
      memberId: 'friend-marco',
      displayName: 'Marco',
      email: 'marco@blindtiger.local',
      branch: '',
      vibeTag: 'Down for a duel',
      isNearby: true,
    ),
    'friend-sasha': const FriendProfile(
      memberId: 'friend-sasha',
      displayName: 'Sasha',
      email: 'sasha@blindtiger.local',
      branch: '',
      vibeTag: 'Looking for a toast',
      isNearby: false,
    ),
  };
  final Map<String, FriendRequest> _localRequests = {};
  final Set<String> _localFriendships = {};
  final Set<String> _localBlocks = {};
  final List<FriendPing> _localPings = [];
  final List<FriendMessage> _localMessages = [];
  final List<SafetyReport> _localReports = [];
  final List<RideAssistRequest> _localRides = [];
  final List<InsuranceIncident> _localIncidents = [];

  RealtimeChannel? _inboxChannel;
  void Function()? _onInboxChanged;

  String _pair(String a, String b) {
    final ids = [a, b]..sort();
    return ids.join(':');
  }

  bool isBlockedLocal(String a, String b) =>
      _localBlocks.contains('$a:$b') || _localBlocks.contains('$b:$a');

  Future<List<FriendProfile>> searchMembers({
    required String query,
    required String selfId,
  }) async {
    if (!usesCloud) {
      final q = query.trim().toLowerCase();
      return _localProfiles.values
          .where((p) => p.memberId != selfId)
          .where((p) => !isBlockedLocal(selfId, p.memberId))
          .where(
            (p) =>
                q.isEmpty ||
                p.displayName.toLowerCase().contains(q) ||
                (p.email ?? '').toLowerCase().contains(q),
          )
          .toList();
    }

    try {
      final rows = await _client!.rpc(
        'search_friend_candidates',
        params: {'p_query': query},
      );
      return (rows as List)
          .map(
            (r) => FriendProfile.fromSupabaseRow(
              Map<String, dynamic>.from(r as Map),
            ),
          )
          .toList();
    } catch (e) {
      return _runInDemoIfUnavailable(
        e,
        () => searchMembers(query: query, selfId: selfId),
      );
    }
  }

  Future<FriendRequest> sendFriendRequest({
    required String recipientId,
    required String recipientName,
    required String requesterId,
    required String requesterName,
  }) async {
    if (!usesCloud) {
      if (recipientId == requesterId) {
        throw SafetySocialException('You cannot add yourself.');
      }
      if (isBlockedLocal(requesterId, recipientId)) {
        throw SafetySocialException('Friend request unavailable.');
      }
      final id = 'local-fr-${_rng.nextInt(999999)}';
      final request = FriendRequest(
        id: id,
        requesterId: requesterId,
        requesterName: requesterName,
        recipientId: recipientId,
        recipientName: recipientName,
        status: FriendRequestStatus.pending,
        createdAt: DateTime.now(),
        direction: 'outbound',
      );
      _localRequests[id] = request;
      return request;
    }

    try {
      final row = await _client!.rpc(
        'send_friend_request',
        params: {'p_recipient_id': recipientId},
      );
      return FriendRequest.fromSupabaseRow(
        Map<String, dynamic>.from(row as Map),
      );
    } catch (e) {
      return _runInDemoIfUnavailable(
        e,
        () => sendFriendRequest(
          recipientId: recipientId,
          recipientName: recipientName,
          requesterId: requesterId,
          requesterName: requesterName,
        ),
      );
    }
  }

  Future<List<FriendRequest>> listFriendRequests({
    required String selfId,
  }) async {
    if (!usesCloud) {
      return _localRequests.values
          .where((r) => r.requesterId == selfId || r.recipientId == selfId)
          .map(
            (r) => FriendRequest(
              id: r.id,
              requesterId: r.requesterId,
              requesterName: r.requesterName,
              recipientId: r.recipientId,
              recipientName: r.recipientName,
              status: r.status,
              createdAt: r.createdAt,
              respondedAt: r.respondedAt,
              direction: r.recipientId == selfId ? 'inbound' : 'outbound',
            ),
          )
          .toList();
    }

    try {
      final rows = await _client!.rpc('list_friend_requests');
      return (rows as List)
          .map(
            (r) => FriendRequest.fromSupabaseRow(
              Map<String, dynamic>.from(r as Map),
            ),
          )
          .toList();
    } catch (e) {
      return _runInDemoIfUnavailable(
        e,
        () => listFriendRequests(selfId: selfId),
      );
    }
  }

  Future<FriendRequest> acceptFriendRequest({
    required String requestId,
    required String selfId,
  }) async {
    if (!usesCloud) {
      final request = _localRequests[requestId];
      if (request == null || request.recipientId != selfId) {
        throw SafetySocialException('Friend request not found.');
      }
      _localFriendships.add(_pair(request.requesterId, request.recipientId));
      final accepted = FriendRequest(
        id: request.id,
        requesterId: request.requesterId,
        requesterName: request.requesterName,
        recipientId: request.recipientId,
        recipientName: request.recipientName,
        status: FriendRequestStatus.accepted,
        createdAt: request.createdAt,
        respondedAt: DateTime.now(),
        direction: 'inbound',
      );
      _localRequests[requestId] = accepted;
      return accepted;
    }

    try {
      final row = await _client!.rpc(
        'accept_friend_request',
        params: {'p_request_id': requestId},
      );
      return FriendRequest.fromSupabaseRow(
        Map<String, dynamic>.from(row as Map),
      );
    } catch (e) {
      return _runInDemoIfUnavailable(
        e,
        () => acceptFriendRequest(requestId: requestId, selfId: selfId),
      );
    }
  }

  Future<FriendRequest> declineFriendRequest({
    required String requestId,
    required String selfId,
  }) async {
    if (!usesCloud) {
      final request = _localRequests[requestId];
      if (request == null || request.recipientId != selfId) {
        throw SafetySocialException('Friend request not found.');
      }
      final declined = FriendRequest(
        id: request.id,
        requesterId: request.requesterId,
        requesterName: request.requesterName,
        recipientId: request.recipientId,
        recipientName: request.recipientName,
        status: FriendRequestStatus.declined,
        createdAt: request.createdAt,
        respondedAt: DateTime.now(),
        direction: 'inbound',
      );
      _localRequests[requestId] = declined;
      return declined;
    }

    try {
      final row = await _client!.rpc(
        'decline_friend_request',
        params: {'p_request_id': requestId},
      );
      return FriendRequest.fromSupabaseRow(
        Map<String, dynamic>.from(row as Map),
      );
    } catch (e) {
      return _runInDemoIfUnavailable(
        e,
        () => declineFriendRequest(requestId: requestId, selfId: selfId),
      );
    }
  }

  Future<List<FriendProfile>> listMutualFriendsNearby({
    required String branch,
    required String selfId,
  }) async {
    if (!usesCloud) {
      final seeded = _localFriendships.isEmpty
          ? {'friend-lexi', 'friend-marco'}
          : _localProfiles.keys.where(
              (id) => _localFriendships.contains(_pair(selfId, id)),
            );
      return seeded.where((id) => !isBlockedLocal(selfId, id)).map((id) {
        final p = _localProfiles[id]!;
        return FriendProfile(
          memberId: p.memberId,
          displayName: p.displayName,
          email: p.email,
          branch: branch,
          vibeTag: p.vibeTag,
          updatedAt: DateTime.now(),
          isNearby: true,
        );
      }).toList();
    }

    try {
      final rows = await _client!.rpc(
        'list_mutual_friends_nearby',
        params: {'p_branch': branch},
      );
      return (rows as List)
          .map(
            (r) => FriendProfile.fromSupabaseRow(
              Map<String, dynamic>.from(r as Map),
            ),
          )
          .toList();
    } catch (e) {
      return _runInDemoIfUnavailable(
        e,
        () => listMutualFriendsNearby(branch: branch, selfId: selfId),
      );
    }
  }

  Future<FriendPing> notifyFriend({
    required String friendId,
    required String selfId,
    required String message,
  }) async {
    if (!usesCloud) {
      if (isBlockedLocal(selfId, friendId)) {
        throw SafetySocialException('Notification unavailable.');
      }
      if (!_localFriendships.contains(_pair(selfId, friendId))) {
        throw SafetySocialException(
          'Add them as a friend first — then ping.',
        );
      }
      final ping = FriendPing(
        id: 'local-ping-${DateTime.now().millisecondsSinceEpoch}',
        senderId: selfId,
        recipientId: friendId,
        message: message,
        kind: 'friend_ping',
        senderName: 'You',
        createdAt: DateTime.now(),
      );
      _localPings.add(ping);
      return ping;
    }

    try {
      final row = await _client!.rpc(
        'notify_friend',
        params: {'p_friend_id': friendId, 'p_message': message},
      );
      return FriendPing.fromSupabaseRow(Map<String, dynamic>.from(row as Map));
    } catch (e) {
      return _runInDemoIfUnavailable(
        e,
        () =>
            notifyFriend(friendId: friendId, selfId: selfId, message: message),
      );
    }
  }

  Future<List<FriendPing>> listFriendNotifications({
    required String selfId,
    bool unreadOnly = false,
  }) async {
    if (!usesCloud) {
      return _localPings
          .where((p) => p.recipientId == selfId)
          .where((p) => !unreadOnly || p.isUnread)
          .toList()
        ..sort(
          (a, b) => (b.createdAt ?? DateTime(0)).compareTo(
            a.createdAt ?? DateTime(0),
          ),
        );
    }

    try {
      final rows = await _client!.rpc(
        'list_friend_notifications',
        params: {'p_unread_only': unreadOnly, 'p_limit': 30},
      );
      return (rows as List)
          .map(
            (r) => FriendPing.fromSupabaseRow(Map<String, dynamic>.from(r as Map)),
          )
          .toList();
    } catch (e) {
      return _runInDemoIfUnavailable(
        e,
        () => listFriendNotifications(selfId: selfId, unreadOnly: unreadOnly),
      );
    }
  }

  Future<void> markNotificationRead({
    required String notificationId,
    required String selfId,
  }) async {
    if (!usesCloud) {
      final idx = _localPings.indexWhere((p) => p.id == notificationId);
      if (idx >= 0) {
        final old = _localPings[idx];
        _localPings[idx] = FriendPing(
          id: old.id,
          senderId: old.senderId,
          recipientId: old.recipientId,
          message: old.message,
          kind: old.kind,
          senderName: old.senderName,
          createdAt: old.createdAt,
          readAt: DateTime.now(),
        );
      }
      return;
    }

    try {
      await _client!.rpc(
        'mark_notification_read',
        params: {'p_notification_id': notificationId},
      );
    } catch (e) {
      return _runInDemoIfUnavailable(
        e,
        () => markNotificationRead(
          notificationId: notificationId,
          selfId: selfId,
        ),
      );
    }
  }

  Future<bool> areFriends({
    required String otherId,
    required String selfId,
  }) async {
    if (!usesCloud) {
      return _localFriendships.contains(_pair(selfId, otherId));
    }

    try {
      final row = await _client!.rpc(
        'are_friends',
        params: {'p_other_id': otherId},
      );
      return row == true;
    } catch (e) {
      return _runInDemoIfUnavailable(
        e,
        () => areFriends(otherId: otherId, selfId: selfId),
      );
    }
  }

  Future<FriendMessage> sendFriendMessage({
    required String friendId,
    required String selfId,
    required String body,
  }) async {
    if (!usesCloud) {
      if (!_localFriendships.contains(_pair(selfId, friendId))) {
        throw SafetySocialException('Friend not found.');
      }
      final message = FriendMessage(
        id: 'local-msg-${DateTime.now().millisecondsSinceEpoch}',
        senderId: selfId,
        recipientId: friendId,
        body: body.trim(),
        senderName: 'You',
        createdAt: DateTime.now(),
      );
      _localMessages.add(message);
      _localPings.add(
        FriendPing(
          id: 'local-chat-${message.id}',
          senderId: selfId,
          recipientId: friendId,
          message: body.trim(),
          kind: 'chat',
          senderName: 'You',
          createdAt: DateTime.now(),
        ),
      );
      return message;
    }

    try {
      final row = await _client!.rpc(
        'send_friend_message',
        params: {'p_friend_id': friendId, 'p_body': body},
      );
      return FriendMessage.fromSupabaseRow(Map<String, dynamic>.from(row as Map));
    } catch (e) {
      return _runInDemoIfUnavailable(
        e,
        () => sendFriendMessage(
          friendId: friendId,
          selfId: selfId,
          body: body,
        ),
      );
    }
  }

  Future<List<FriendMessage>> listFriendMessages({
    required String friendId,
    required String selfId,
  }) async {
    if (!usesCloud) {
      return _localMessages
          .where(
            (m) =>
                (m.senderId == selfId && m.recipientId == friendId) ||
                (m.senderId == friendId && m.recipientId == selfId),
          )
          .toList()
        ..sort(
          (a, b) => (a.createdAt ?? DateTime(0)).compareTo(
            b.createdAt ?? DateTime(0),
          ),
        );
    }

    try {
      final rows = await _client!.rpc(
        'list_friend_messages',
        params: {'p_friend_id': friendId, 'p_limit': 80},
      );
      final list = rows as List? ?? const [];
      return list
          .map(
            (r) =>
                FriendMessage.fromSupabaseRow(Map<String, dynamic>.from(r as Map)),
          )
          .toList();
    } catch (e) {
      if (_isCloudSchemaUnavailable(e)) {
        return _runInDemoIfUnavailable(
          e,
          () => listFriendMessages(friendId: friendId, selfId: selfId),
        );
      }
      throw SafetySocialException(_mapError(e));
    }
  }

  Future<List<FriendProfile>> listMyFriends({required String selfId}) async {
    if (!usesCloud) {
      return _localProfiles.values
          .where((p) => _localFriendships.contains(_pair(selfId, p.memberId)))
          .toList();
    }

    try {
      final rows = await _client!.rpc('list_my_friends');
      final list = rows as List? ?? const [];
      return list
          .map(
            (r) =>
                FriendProfile.fromSupabaseRow(Map<String, dynamic>.from(r as Map)),
          )
          .toList();
    } catch (e) {
      if (_isCloudSchemaUnavailable(e)) {
        return _runInDemoIfUnavailable(
          e,
          () => listMyFriends(selfId: selfId),
        );
      }
      throw SafetySocialException(_mapError(e));
    }
  }

  Future<void> blockMember({
    required String blockedId,
    required String selfId,
    String? reason,
  }) async {
    if (!usesCloud) {
      _localBlocks.add('$selfId:$blockedId');
      _localFriendships.remove(_pair(selfId, blockedId));
      return;
    }

    try {
      await _client!.rpc(
        'block_member',
        params: {'p_blocked_id': blockedId, 'p_reason': reason},
      );
    } catch (e) {
      return _runInDemoIfUnavailable(
        e,
        () => blockMember(blockedId: blockedId, selfId: selfId, reason: reason),
      );
    }
  }

  Future<SafetyReport> submitSafetyReport({
    required String category,
    required String branch,
    String? description,
    String? reportedMemberId,
    String? sessionId,
  }) async {
    if (!usesCloud) {
      final report = SafetyReport(
        id: 'local-report-${DateTime.now().millisecondsSinceEpoch}',
        category: category,
        status: 'open',
        reportedMemberId: reportedMemberId,
        description: description,
        branch: branch,
        createdAt: DateTime.now(),
      );
      _localReports.add(report);
      return report;
    }

    try {
      final row = await _client!.rpc(
        'submit_safety_report',
        params: {
          'p_category': category,
          'p_description': description,
          'p_reported_member_id': reportedMemberId,
          'p_branch': branch,
          'p_session_id': sessionId,
        },
      );
      return SafetyReport.fromSupabaseRow(
        Map<String, dynamic>.from(row as Map),
      );
    } catch (e) {
      return _runInDemoIfUnavailable(
        e,
        () => submitSafetyReport(
          category: category,
          branch: branch,
          description: description,
          reportedMemberId: reportedMemberId,
          sessionId: sessionId,
        ),
      );
    }
  }

  Future<RideAssistRequest> requestRideAssist({
    required String pickupBranch,
    required String destination,
  }) async {
    final partner = await _ridePartner.requestRide(
      pickupBranch: pickupBranch,
      destination: destination,
    );
    if (!usesCloud) {
      final ride = RideAssistRequest(
        id: 'local-ride-${DateTime.now().millisecondsSinceEpoch}',
        provider: partner.provider,
        status: partner.status,
        pickupBranch: pickupBranch,
        destination: destination,
        externalUrl: partner.externalUrl,
        createdAt: DateTime.now(),
      );
      _localRides.add(ride);
      return ride;
    }

    try {
      final row = await _client!.rpc(
        'request_ride_assist',
        params: {
          'p_pickup_branch': pickupBranch,
          'p_destination': destination,
          'p_provider': partner.provider,
          'p_external_url': partner.externalUrl,
        },
      );
      return RideAssistRequest.fromSupabaseRow(
        Map<String, dynamic>.from(row as Map),
      );
    } catch (e) {
      return _runInDemoIfUnavailable(
        e,
        () => requestRideAssist(
          pickupBranch: pickupBranch,
          destination: destination,
        ),
      );
    }
  }

  Future<InsuranceIncident> createInsuranceIncident({
    required String incidentType,
    required bool consentToShare,
    String? reportId,
  }) async {
    final partner = await _insurancePartner.createIncident(
      incidentType: incidentType,
      consentToShare: consentToShare,
      reportId: reportId,
    );
    if (!usesCloud) {
      final incident = InsuranceIncident(
        id: 'local-ins-${DateTime.now().millisecondsSinceEpoch}',
        incidentType: incidentType,
        status: partner.status,
        consentToShare: consentToShare,
        reportId: reportId,
        partnerReference: partner.partnerReference,
        createdAt: DateTime.now(),
      );
      _localIncidents.add(incident);
      return incident;
    }

    try {
      final row = await _client!.rpc(
        'create_insurance_incident',
        params: {
          'p_incident_type': incidentType,
          'p_report_id': reportId,
          'p_consent_to_share': consentToShare,
        },
      );
      return InsuranceIncident.fromSupabaseRow(
        Map<String, dynamic>.from(row as Map),
      );
    } catch (e) {
      return _runInDemoIfUnavailable(
        e,
        () => createInsuranceIncident(
          incidentType: incidentType,
          consentToShare: consentToShare,
          reportId: reportId,
        ),
      );
    }
  }

  Future<void> registerPushToken({
    required String token,
    String kind = 'fcm',
    String platform = 'ios',
    String? bundleId,
    String environment = 'sandbox',
  }) async {
    if (!usesCloud) return;
    try {
      await _client!.rpc(
        'register_push_token',
        params: {
          'p_token': token,
          'p_kind': kind,
          'p_platform': platform,
          'p_bundle_id': bundleId,
          'p_environment': environment,
        },
      );
    } catch (_) {
      // Schema not applied yet — ignore until migration 018 is run.
    }
  }

  Future<void> clearPushTokens({String? token}) async {
    if (!usesCloud) return;
    try {
      await _client!.rpc(
        'clear_push_token',
        params: {'p_token': token},
      );
    } catch (_) {}
  }

  /// Instant alerts when a friend pings / messages / requests you.
  void startInboxWatch({
    required String selfId,
    required void Function() onChanged,
  }) {
    stopInboxWatch();
    _onInboxChanged = onChanged;
    if (!usesCloud) return;

    final client = _client;
    if (client == null) return;

    _inboxChannel = client
        .channel('social-inbox:$selfId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'member_notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'recipient_id',
            value: selfId,
          ),
          callback: (_) => _onInboxChanged?.call(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'friend_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'recipient_id',
            value: selfId,
          ),
          callback: (_) => _onInboxChanged?.call(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'friend_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'recipient_id',
            value: selfId,
          ),
          callback: (_) => _onInboxChanged?.call(),
        )
        .subscribe();
  }

  void stopInboxWatch() {
    _inboxChannel?.unsubscribe();
    _inboxChannel = null;
    _onInboxChanged = null;
  }

  Future<T> _runInDemoIfUnavailable<T>(
    Object error,
    Future<T> Function() action,
  ) async {
    if (_isCloudSchemaUnavailable(error)) {
      _forceDemoMode = true;
      return action();
    }
    throw SafetySocialException(_mapError(error));
  }

  bool _isCloudSchemaUnavailable(Object error) {
    final message = error.toString();
    return message.contains('PGRST202') ||
        message.contains('Could not find the function') ||
        message.contains('schema cache') ||
        (message.contains('relation') && message.contains('does not exist'));
  }

  String _mapError(Object error) {
    final message = error.toString();
    if (message.contains('Already friends')) return 'You are already friends.';
    if (message.contains('Friend not found')) {
      return 'Add them as a friend first — then you can ping or chat.';
    }
    if (message.contains('not found')) {
      return 'That request could not be found.';
    }
    if (message.contains('unavailable')) return 'That action is unavailable.';
    if (message.contains('yourself')) return 'You cannot choose yourself.';
    if (message.contains('empty')) return 'Message is empty.';
    return 'Could not complete safety/social action.';
  }
}
