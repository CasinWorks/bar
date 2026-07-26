import 'package:flutter/foundation.dart';
import '../models/club_session.dart';

abstract class SessionStoreDelegate extends ChangeNotifier {
  bool get usesRealtime;

  Future<void> load();
  Future<void> subscribeToSession(String? sessionId);
  void unsubscribe();

  ClubSessionRecord? getSession(String id);
  Future<ClubSessionRecord?> fetchSession(String id);
  Future<ClubSessionRecord?> fetchSessionFresh(String id);
  Future<ClubSessionRecord?> findByCode(String code);
  List<ClubSessionRecord> get activeSessions;
  Future<ClubSessionRecord?> fetchActiveSessionForMember(String memberId);
  Future<int> completeStaleSessions({String? memberId});

  Future<void> upsert(ClubSessionRecord session);
  Future<void> confirmEntry(String sessionId);
  Future<void> requestExit(String sessionId);
  Future<void> confirmExit(String sessionId);
  Future<void> cancelExitRequest(String sessionId);
  Future<void> updateRemaining(String sessionId, int seconds);
  Future<void> cancelSession(String sessionId);
}
