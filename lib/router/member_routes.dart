import '../models/club_session.dart';
import '../providers/app_state.dart';

String routeForAppState(AppState state) {
  if (!state.isAuthenticated) return '/';

  if (state.isStaff) return '/staff';

  return routeForMemberState(state);
}

String routeForMemberState(AppState state) {
  if (!state.isAuthenticated || state.isStaff) return '/';

  // Active / completed visits always win over a pending event invite deep link.
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
      break;
  }

  if (state.hasCheckoutReceipt) return '/summary';

  final pendingInviteLocation = state.pendingEventInviteLocation;
  if (pendingInviteLocation != null && state.acceptedEventInvite == null) {
    return pendingInviteLocation;
  }

  return '/pricing';
}
