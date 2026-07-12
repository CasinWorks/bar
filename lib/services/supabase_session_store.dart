import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/club_session.dart';
import 'session_store_delegate.dart';

/// Cloud session store — syncs across member + bouncer phones via Supabase.
class SupabaseSessionStore extends SessionStoreDelegate {
  final _client = Supabase.instance.client;
  final Map<String, ClubSessionRecord> _cache = {};
  RealtimeChannel? _channel;

  @override
  bool get usesRealtime => true;

  @override
  Future<void> load() async {}

  @override
  Future<void> subscribeToSession(String? sessionId) async {
    _channel?.unsubscribe();
    if (sessionId == null) return;

    _channel = _client
        .channel('session:$sessionId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'club_sessions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: sessionId,
          ),
          callback: (payload) {
            final record = payload.newRecord;
            if (record.isEmpty) return;
            _cache[sessionId] = ClubSessionRecord.fromSupabaseRow(record);
            notifyListeners();
          },
        )
        .subscribe();
  }

  @override
  void unsubscribe() {
    _channel?.unsubscribe();
    _channel = null;
  }

  @override
  ClubSessionRecord? getSession(String id) => _cache[id];

  @override
  Future<ClubSessionRecord?> fetchSession(String id) async {
    final cached = _cache[id];
    if (cached != null) return cached;

    return fetchSessionFresh(id);
  }

  @override
  Future<ClubSessionRecord?> fetchSessionFresh(String id) async {
    final row = await _client.from('club_sessions').select().eq('id', id).maybeSingle();
    if (row == null) return null;

    final session = ClubSessionRecord.fromSupabaseRow(Map<String, dynamic>.from(row));
    _cache[id] = session;
    return session;
  }

  @override
  Future<ClubSessionRecord?> findByCode(String code) async {
    final normalized = code.trim().toUpperCase();
    final rows = await _client.from('club_sessions').select();
    for (final row in rows) {
      final session = ClubSessionRecord.fromSupabaseRow(row);
      if (session.displayCode == normalized) return session;
    }
    return null;
  }

  @override
  List<ClubSessionRecord> get activeSessions =>
      _cache.values.where((s) => s.phase != SessionPhase.completed).toList();

  @override
  Future<ClubSessionRecord?> fetchActiveSessionForMember(String memberId) async {
    final rows = await _client
        .from('club_sessions')
        .select()
        .eq('member_id', memberId)
        .neq('phase', ClubSessionRecord.phaseToDb(SessionPhase.completed));

    if (rows.isEmpty) return null;

    final sessions = rows
        .map((row) => ClubSessionRecord.fromSupabaseRow(Map<String, dynamic>.from(row)))
        .toList();
    final session = ClubSessionRecord.pickActiveForMember(sessions, memberId);
    if (session == null) return null;

    _cache[session.id] = session;
    return session;
  }

  @override
  Future<void> upsert(ClubSessionRecord session) async {
    await _client.from('club_sessions').upsert(session.toSupabaseRow());
    _cache[session.id] = session;
    notifyListeners();
  }

  @override
  Future<void> confirmEntry(String sessionId) async {
    final session = await fetchSessionFresh(sessionId);
    if (session == null || session.phase != SessionPhase.paidAwaitingEntry) return;

    await _client.from('club_sessions').update({
      'phase': ClubSessionRecord.phaseToDb(SessionPhase.insideClub),
      'remaining_seconds': session.remainingSeconds,
      'entered_at': DateTime.now().toIso8601String(),
    }).eq('id', sessionId);

    session.phase = SessionPhase.insideClub;
    session.enteredAt = DateTime.now();
    _cache[sessionId] = session;
    notifyListeners();
  }

  @override
  Future<void> requestExit(String sessionId) async {
    final session = await fetchSession(sessionId);
    if (session == null || session.phase != SessionPhase.insideClub) return;

    await _client.from('club_sessions').update({
      'phase': ClubSessionRecord.phaseToDb(SessionPhase.awaitingExitScan),
      'remaining_seconds': session.remainingSeconds,
    }).eq('id', sessionId);

    session.phase = SessionPhase.awaitingExitScan;
    _cache[sessionId] = session;
    notifyListeners();
  }

  @override
  Future<void> cancelExitRequest(String sessionId) async {
    final session = await fetchSession(sessionId);
    if (session == null || session.phase != SessionPhase.awaitingExitScan) return;

    await _client.from('club_sessions').update({
      'phase': ClubSessionRecord.phaseToDb(SessionPhase.insideClub),
    }).eq('id', sessionId);

    session.phase = SessionPhase.insideClub;
    _cache[sessionId] = session;
    notifyListeners();
  }

  @override
  Future<void> confirmExit(String sessionId) async {
    final session = await fetchSession(sessionId);
    if (session == null || session.phase != SessionPhase.awaitingExitScan) return;

    await _client.from('club_sessions').update({
      'phase': ClubSessionRecord.phaseToDb(SessionPhase.completed),
      'exited_at': DateTime.now().toIso8601String(),
    }).eq('id', sessionId);

    session.phase = SessionPhase.completed;
    session.exitedAt = DateTime.now();
    _cache[sessionId] = session;
    notifyListeners();
  }

  @override
  Future<void> updateRemaining(String sessionId, int seconds) async {
    final cached = _cache[sessionId];
    if (cached != null && seconds < cached.remainingSeconds - 3) {
      // Ignore stale timer writes that would wipe a recent purchase.
      return;
    }

    await _client.from('club_sessions').update({
      'remaining_seconds': seconds,
    }).eq('id', sessionId);

    final session = _cache[sessionId];
    if (session != null) {
      session.remainingSeconds = seconds;
      notifyListeners();
    }
  }

  @override
  Future<void> cancelSession(String sessionId) async {
    final session = await fetchSession(sessionId);
    if (session == null || session.phase != SessionPhase.paidAwaitingEntry) return;

    await _client.from('club_sessions').update({
      'phase': ClubSessionRecord.phaseToDb(SessionPhase.completed),
      'exited_at': DateTime.now().toIso8601String(),
    }).eq('id', sessionId);

    session.phase = SessionPhase.completed;
    session.exitedAt = DateTime.now();
    _cache[sessionId] = session;
    notifyListeners();
  }
}
