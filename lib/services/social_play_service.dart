import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/supabase_config.dart';
import '../models/social_play.dart';

class SocialPlayException implements Exception {
  SocialPlayException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Opt-in presence + meet toasts + duo lobbies.
/// Cloud when Supabase is configured; otherwise in-memory for demos.
class SocialPlayService {
  SocialPlayService();

  bool get usesCloud => SupabaseConfig.isConfigured;

  SupabaseClient? get _client =>
      usesCloud ? Supabase.instance.client : null;

  final Map<String, SocialPresence> _localPresence = {};
  final Map<String, SocialMeet> _localMeets = {};
  final _rng = Random();

  static const _ambientGuests = [
    SocialPresence(
      memberId: 'ambient-lexi',
      displayName: 'Lexi',
      branch: '',
      vibeTag: 'Jazz · First night',
      openToMeet: true,
    ),
    SocialPresence(
      memberId: 'ambient-marco',
      displayName: 'Marco',
      branch: '',
      vibeTag: 'Down for a duel',
      openToMeet: true,
    ),
    SocialPresence(
      memberId: 'ambient-sasha',
      displayName: 'Sasha',
      branch: '',
      vibeTag: 'Looking for a toast',
      openToMeet: true,
    ),
  ];

  Future<SocialPresence> setOpenToMeet({
    required bool open,
    required String branch,
    required String displayName,
    required String memberId,
    String? sessionId,
    String vibeTag = 'Looking for a toast',
  }) async {
    if (!usesCloud) {
      final row = SocialPresence(
        memberId: memberId,
        displayName: displayName,
        branch: branch,
        vibeTag: vibeTag,
        openToMeet: open,
        sessionId: sessionId,
        updatedAt: DateTime.now(),
        isSelf: true,
      );
      if (open) {
        _localPresence[memberId] = row;
      } else {
        _localPresence.remove(memberId);
      }
      return row;
    }

    try {
      final row = await _client!.rpc(
        'set_open_to_meet',
        params: {
          'p_open': open,
          'p_branch': branch,
          'p_session_id': sessionId,
          'p_vibe_tag': vibeTag,
        },
      );
      return SocialPresence.fromSupabaseRow(
        Map<String, dynamic>.from(row as Map),
      ).copyWith(isSelf: true);
    } catch (e) {
      throw SocialPlayException(_mapError(e));
    }
  }

  Future<List<SocialPresence>> listWhosInside({
    required String branch,
    String? selfId,
  }) async {
    if (!usesCloud) {
      final live = _localPresence.values
          .where((p) => p.openToMeet && p.branch == branch)
          .toList();
      final ambient = _ambientGuests
          .map(
            (g) => SocialPresence(
              memberId: g.memberId,
              displayName: g.displayName,
              branch: branch,
              vibeTag: g.vibeTag,
              openToMeet: true,
            ),
          )
          .where((g) => selfId == null || g.memberId != selfId)
          .toList();
      return [...live, ...ambient];
    }

    try {
      final rows = await _client!.rpc(
        'list_whos_inside',
        params: {'p_branch': branch},
      );
      final list = (rows as List)
          .map(
            (r) => SocialPresence.fromSupabaseRow(
              Map<String, dynamic>.from(r as Map),
            ),
          )
          .map((p) => p.copyWith(isSelf: p.memberId == selfId))
          .toList();

      // Soft-fill atmosphere when the room is quiet.
      if (list.where((p) => !p.isSelf).length < 2) {
        final extras = _ambientGuests
            .take(2)
            .map(
              (g) => SocialPresence(
                memberId: g.memberId,
                displayName: g.displayName,
                branch: branch,
                vibeTag: g.vibeTag,
                openToMeet: true,
              ),
            );
        return [...list, ...extras];
      }
      return list;
    } catch (_) {
      return _ambientGuests
          .map(
            (g) => SocialPresence(
              memberId: g.memberId,
              displayName: g.displayName,
              branch: branch,
              vibeTag: g.vibeTag,
              openToMeet: true,
            ),
          )
          .toList();
    }
  }

  Future<SocialMeet> raiseMeet({
    required int seconds,
    required MeetKind kind,
    required String hostId,
    required String hostName,
  }) async {
    if (!usesCloud) {
      final code =
          'MEET-${_rng.nextInt(0xFFFF).toRadixString(16).toUpperCase().padLeft(4, '0')}';
      final meet = SocialMeet(
        id: 'local-meet-${DateTime.now().millisecondsSinceEpoch}',
        hostId: hostId,
        hostName: hostName,
        seconds: seconds,
        kind: kind,
        status: MeetStatus.pending,
        icebreaker: IcebreakerPrompts.pick(_rng.nextInt(9999)),
        code: code,
        createdAt: DateTime.now(),
      );
      _localMeets[code] = meet;
      return meet;
    }

    try {
      final row = await _client!.rpc(
        'raise_meet',
        params: {
          'p_seconds': seconds,
          'p_kind': kind == MeetKind.duoBeat ? 'duo_beat' : 'meet_toast',
        },
      );
      return SocialMeet.fromSupabaseRow(Map<String, dynamic>.from(row as Map));
    } catch (e) {
      throw SocialPlayException(_mapError(e));
    }
  }

  Future<SocialMeet> joinMeet({
    required String code,
    required String guestId,
    required String guestName,
  }) async {
    final normalized = code.trim().toUpperCase();
    if (!usesCloud) {
      final meet = _localMeets[normalized];
      if (meet == null) {
        throw SocialPlayException('Meet code not found.');
      }
      if (meet.status != MeetStatus.pending) {
        throw SocialPlayException('Meet already claimed.');
      }
      if (meet.hostId == guestId) {
        throw SocialPlayException("You can't join your own meet.");
      }
      final matched = SocialMeet(
        id: meet.id,
        hostId: meet.hostId,
        hostName: meet.hostName,
        guestId: guestId,
        guestName: guestName,
        seconds: meet.seconds,
        kind: meet.kind,
        status: MeetStatus.matched,
        icebreaker: meet.icebreaker,
        code: meet.code,
        createdAt: meet.createdAt,
        matchedAt: DateTime.now(),
      );
      _localMeets[normalized] = matched;
      return matched;
    }

    try {
      final row = await _client!.rpc(
        'join_meet',
        params: {'p_code': normalized},
      );
      return SocialMeet.fromSupabaseRow(Map<String, dynamic>.from(row as Map));
    } catch (e) {
      throw SocialPlayException(_mapError(e));
    }
  }

  Future<SocialMeet> completeIcebreaker(String meetId) async {
    if (!usesCloud) {
      final entry = _localMeets.entries.where((e) => e.value.id == meetId);
      if (entry.isEmpty) {
        throw SocialPlayException('Meet not found.');
      }
      final meet = entry.first.value;
      final done = SocialMeet(
        id: meet.id,
        hostId: meet.hostId,
        hostName: meet.hostName,
        guestId: meet.guestId,
        guestName: meet.guestName,
        seconds: meet.seconds,
        kind: meet.kind,
        status: MeetStatus.completed,
        icebreaker: meet.icebreaker,
        code: meet.code,
        hostScore: meet.hostScore,
        guestScore: meet.guestScore,
        winnerId: meet.winnerId,
        createdAt: meet.createdAt,
        matchedAt: meet.matchedAt,
        completedAt: DateTime.now(),
      );
      if (meet.code != null) _localMeets[meet.code!] = done;
      return done;
    }

    try {
      final row = await _client!.rpc(
        'complete_meet_icebreaker',
        params: {'p_meet_id': meetId},
      );
      return SocialMeet.fromSupabaseRow(Map<String, dynamic>.from(row as Map));
    } catch (e) {
      throw SocialPlayException(_mapError(e));
    }
  }

  Future<SocialMeet> submitDuoScore({
    required String meetId,
    required int score,
    required String memberId,
  }) async {
    if (!usesCloud) {
      final entry = _localMeets.entries.where((e) => e.value.id == meetId);
      if (entry.isEmpty) {
        throw SocialPlayException('Meet not found.');
      }
      var meet = entry.first.value;
      final isHost = meet.hostId == memberId;
      var hostScore = meet.hostScore;
      var guestScore = meet.guestScore;
      if (isHost) {
        hostScore = score;
      } else {
        guestScore = score;
      }

      String? winnerId;
      var status = meet.status;
      DateTime? completedAt = meet.completedAt;
      if (hostScore != null && guestScore != null) {
        if (hostScore > guestScore) {
          winnerId = meet.hostId;
        } else if (guestScore > hostScore) {
          winnerId = meet.guestId;
        }
        status = MeetStatus.completed;
        completedAt = DateTime.now();
      }

      meet = SocialMeet(
        id: meet.id,
        hostId: meet.hostId,
        hostName: meet.hostName,
        guestId: meet.guestId,
        guestName: meet.guestName,
        seconds: meet.seconds,
        kind: meet.kind,
        status: status,
        icebreaker: meet.icebreaker,
        code: meet.code,
        hostScore: hostScore,
        guestScore: guestScore,
        winnerId: winnerId,
        createdAt: meet.createdAt,
        matchedAt: meet.matchedAt,
        completedAt: completedAt,
      );
      if (meet.code != null) _localMeets[meet.code!] = meet;
      return meet;
    }

    try {
      final row = await _client!.rpc(
        'submit_duo_score',
        params: {
          'p_meet_id': meetId,
          'p_score': score,
        },
      );
      return SocialMeet.fromSupabaseRow(Map<String, dynamic>.from(row as Map));
    } catch (e) {
      throw SocialPlayException(_mapError(e));
    }
  }

  Future<SocialMeet?> fetchMeetByCode(String code) async {
    final normalized = code.trim().toUpperCase();
    if (!usesCloud) {
      return _localMeets[normalized];
    }
    try {
      final row = await _client!.rpc(
        'fetch_meet_by_code',
        params: {'p_code': normalized},
      );
      if (row == null) return null;
      return SocialMeet.fromSupabaseRow(Map<String, dynamic>.from(row as Map));
    } catch (_) {
      return null;
    }
  }

  /// Clear opt-in on exit / logout.
  Future<void> clearPresence() async {
    if (!usesCloud) {
      _localPresence.clear();
      return;
    }
    final uid = _client?.auth.currentUser?.id;
    if (uid == null) return;
    try {
      await _client!
          .from('social_presence')
          .update({
            'open_to_meet': false,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('member_id', uid);
    } catch (_) {}
  }

  String _mapError(Object error) {
    final message = error.toString();
    if (message.contains('Not enough time')) {
      return 'Not enough time for that pour.';
    }
    if (message.contains('not found') || message.contains('already claimed')) {
      return 'That meet code is invalid or already used.';
    }
    if (message.contains('your own')) {
      return "You can't join your own meet.";
    }
    if (message.contains('Minimum')) {
      return 'Minimum pour is 1 minute.';
    }
    if (message.contains('Maximum')) {
      return 'Maximum meet pour is 10 minutes.';
    }
    return 'Could not complete social play. Check connection and try again.';
  }
}
