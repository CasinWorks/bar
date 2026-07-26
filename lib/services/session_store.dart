import '../core/config/supabase_config.dart';
import '../models/club_session.dart';
import 'local_session_store.dart';
import 'session_store_delegate.dart';
import 'supabase_session_store.dart';

class SessionStore extends SessionStoreDelegate {
  SessionStore._() : _delegate = _createDelegate();

  static final SessionStore instance = SessionStore._();

  final SessionStoreDelegate _delegate;

  static SessionStoreDelegate _createDelegate() {
    if (SupabaseConfig.isConfigured) {
      return SupabaseSessionStore();
    }
    return LocalSessionStore();
  }

  @override
  bool get usesRealtime => _delegate.usesRealtime;

  @override
  Future<void> load() => _delegate.load();

  @override
  Future<void> subscribeToSession(String? sessionId) =>
      _delegate.subscribeToSession(sessionId);

  @override
  void unsubscribe() => _delegate.unsubscribe();

  @override
  ClubSessionRecord? getSession(String id) => _delegate.getSession(id);

  @override
  Future<ClubSessionRecord?> fetchSession(String id) =>
      _delegate.fetchSession(id);

  @override
  Future<ClubSessionRecord?> fetchSessionFresh(String id) =>
      _delegate.fetchSessionFresh(id);

  @override
  Future<ClubSessionRecord?> findByCode(String code) =>
      _delegate.findByCode(code);

  @override
  List<ClubSessionRecord> get activeSessions => _delegate.activeSessions;

  @override
  Future<ClubSessionRecord?> fetchActiveSessionForMember(String memberId) =>
      _delegate.fetchActiveSessionForMember(memberId);

  @override
  Future<int> completeStaleSessions({String? memberId}) =>
      _delegate.completeStaleSessions(memberId: memberId);

  @override
  Future<void> upsert(ClubSessionRecord session) => _delegate.upsert(session);

  @override
  Future<void> confirmEntry(String sessionId) =>
      _delegate.confirmEntry(sessionId);

  @override
  Future<void> requestExit(String sessionId) =>
      _delegate.requestExit(sessionId);

  @override
  Future<void> cancelExitRequest(String sessionId) =>
      _delegate.cancelExitRequest(sessionId);

  @override
  Future<void> confirmExit(String sessionId) =>
      _delegate.confirmExit(sessionId);

  @override
  Future<void> updateRemaining(String sessionId, int seconds) =>
      _delegate.updateRemaining(sessionId, seconds);

  @override
  Future<void> cancelSession(String sessionId) =>
      _delegate.cancelSession(sessionId);

  @override
  void addListener(void Function() listener) => _delegate.addListener(listener);

  @override
  void removeListener(void Function() listener) =>
      _delegate.removeListener(listener);
}
