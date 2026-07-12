import '../models/club_session.dart';
import '../providers/app_state.dart';

String routeForAppState(AppState state) {
  if (!state.isAuthenticated) return '/';

  if (state.isStaff) return '/staff';

  return routeForMemberState(state);
}

String routeForMemberState(AppState state) {
  if (!state.isAuthenticated || state.isStaff) return '/';

  switch (state.sessionPhase) {
    case SessionPhase.paidAwaitingEntry:
      return '/entry';
    case SessionPhase.insideClub:
      return '/lounge';
    case SessionPhase.awaitingExitScan:
      return '/exit';
    case SessionPhase.completed:
      return '/summary';
    case SessionPhase.none:
      return '/pricing';
  }
}
