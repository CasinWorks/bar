import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/club_session.dart';
import 'session_store_delegate.dart';

/// Local-only session store (single-device testing without Supabase).
class LocalSessionStore extends SessionStoreDelegate {
  static const _key = 'club_sessions';
  final Map<String, ClubSessionRecord> _sessions = {};

  @override
  bool get usesRealtime => false;

  @override
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return;
    final map = jsonDecode(raw) as Map<String, dynamic>;
    _sessions
      ..clear()
      ..addAll(map.map(
        (k, v) => MapEntry(k, ClubSessionRecord.fromJson(v as Map<String, dynamic>)),
      ));
    notifyListeners();
  }

  @override
  Future<void> subscribeToSession(String? sessionId) async {}

  @override
  void unsubscribe() {}

  @override
  ClubSessionRecord? getSession(String id) => _sessions[id];

  @override
  Future<ClubSessionRecord?> fetchSession(String id) async => _sessions[id];

  @override
  Future<ClubSessionRecord?> fetchSessionFresh(String id) async => _sessions[id];

  @override
  Future<ClubSessionRecord?> findByCode(String code) async {
    final upper = code.trim().toUpperCase();
    for (final s in _sessions.values) {
      if (s.displayCode == upper) return s;
    }
    return null;
  }

  @override
  List<ClubSessionRecord> get activeSessions => _sessions.values
      .where((s) =>
          s.phase == SessionPhase.paidAwaitingEntry ||
          s.phase == SessionPhase.insideClub ||
          s.phase == SessionPhase.awaitingExitScan)
      .toList();

  @override
  Future<ClubSessionRecord?> fetchActiveSessionForMember(String memberId) async {
    return ClubSessionRecord.pickActiveForMember(_sessions.values, memberId);
  }

  @override
  Future<void> upsert(ClubSessionRecord session) async {
    _sessions[session.id] = session;
    await _persist();
    notifyListeners();
  }

  @override
  Future<void> confirmEntry(String sessionId) async {
    final session = _sessions[sessionId];
    if (session == null || session.phase != SessionPhase.paidAwaitingEntry) return;

    session.phase = SessionPhase.insideClub;
    session.enteredAt = DateTime.now();
    await _persist();
    notifyListeners();
  }

  @override
  Future<void> requestExit(String sessionId) async {
    final session = _sessions[sessionId];
    if (session == null || session.phase != SessionPhase.insideClub) return;

    session.phase = SessionPhase.awaitingExitScan;
    await _persist();
    notifyListeners();
  }

  @override
  Future<void> cancelExitRequest(String sessionId) async {
    final session = _sessions[sessionId];
    if (session == null || session.phase != SessionPhase.awaitingExitScan) return;

    session.phase = SessionPhase.insideClub;
    await _persist();
    notifyListeners();
  }

  @override
  Future<void> confirmExit(String sessionId) async {
    final session = _sessions[sessionId];
    if (session == null || session.phase != SessionPhase.awaitingExitScan) return;

    session.phase = SessionPhase.completed;
    session.exitedAt = DateTime.now();
    await _persist();
    notifyListeners();
  }

  @override
  Future<void> updateRemaining(String sessionId, int seconds) async {
    final session = _sessions[sessionId];
    if (session == null) return;
    session.remainingSeconds = seconds;
    await _persist();
    notifyListeners();
  }

  @override
  Future<void> cancelSession(String sessionId) async {
    final session = _sessions[sessionId];
    if (session == null) return;
    if (session.phase != SessionPhase.paidAwaitingEntry) return;

    session.phase = SessionPhase.completed;
    session.exitedAt = DateTime.now();
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final map = _sessions.map((k, v) => MapEntry(k, v.toJson()));
    await prefs.setString(_key, jsonEncode(map));
  }
}
