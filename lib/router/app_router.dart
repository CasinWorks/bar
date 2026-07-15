import 'package:go_router/go_router.dart';
import '../models/club_session.dart';
import '../providers/app_state.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/signup_screen.dart';
import '../screens/auth/welcome_screen.dart';
import '../screens/gate/entry_exit_gate_screen.dart';
import '../screens/lounge/active_lounge_screen.dart';
import '../screens/purchase/buy_time_checkout_screen.dart';
import '../screens/purchase/buy_time_screen.dart';
import '../screens/purchase/checkout_screen.dart';
import '../screens/purchase/pricing_screen.dart';
import '../screens/staff/bartender_tip_pad_screen.dart';
import '../screens/staff/door_scanner_screen.dart';
import '../screens/summary/summary_screen.dart';
import 'member_routes.dart';

class AppRouter {
  static GoRouter create(AppState appState) {
    return GoRouter(
      initialLocation: '/',
      refreshListenable: appState,
      redirect: (context, state) {
        final app = appState;
        if (app.isLoading) return null;

        final loc = state.matchedLocation;
        final isPublic = loc == '/' || loc == '/login' || loc == '/signup';

        if (!app.isAuthenticated && !isPublic) return '/';

        if (app.isAuthenticated && (loc == '/' || loc == '/login' || loc == '/signup')) {
          return routeForAppState(app);
        }

        if (!app.isAuthenticated) return null;

        // Staff: door scanner + tip pad
        if (app.isStaff) {
          if (loc == '/staff' || loc == '/staff/tip-pad') return null;
          return '/staff';
        }

        // Members cannot access staff scanner
        if (loc == '/staff') return routeForMemberState(app);

        // Exit receipt wins over every other member redirect.
        if (app.hasCheckoutReceipt || app.sessionPhase == SessionPhase.completed) {
          if (loc != '/summary') return '/summary';
          return null;
        }

        // Guest Buy Time / in-app checkout temporarily disabled — loads happen at the club desk.
        if (loc == '/buy-time' || loc == '/buy-time/checkout' || loc == '/checkout') {
          if (app.sessionPhase == SessionPhase.paidAwaitingEntry) return '/entry';
          if (app.sessionPhase == SessionPhase.insideClub) return '/lounge';
          if (app.hasCheckoutReceipt ||
              app.sessionPhase == SessionPhase.completed) {
            return '/summary';
          }
          return '/pricing';
        }

        final phase = app.sessionPhase;
        if (phase == SessionPhase.paidAwaitingEntry &&
            loc != '/entry' &&
            loc != '/checkout') {
          return loc == '/pricing' || loc == '/checkout' ? null : '/entry';
        }
        if (phase == SessionPhase.insideClub &&
            loc != '/exit' &&
            (loc == '/entry' ||
                loc == '/checkout' ||
                (loc == '/pricing' && !app.isTimeDepleted))) {
          return '/lounge';
        }
        if (phase == SessionPhase.awaitingExitScan && loc != '/exit') {
          return '/exit';
        }
        if (phase == SessionPhase.none && loc == '/lounge') {
          return '/pricing';
        }

        return null;
      },
      routes: [
        GoRoute(path: '/', builder: (_, _) => const WelcomeScreen()),
        GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
        GoRoute(path: '/signup', builder: (_, _) => const SignupScreen()),
        GoRoute(path: '/pricing', builder: (_, _) => const PricingScreen()),
        GoRoute(path: '/checkout', builder: (_, _) => const CheckoutScreen()),
        // Routes kept so deep links don't crash; redirect above sends guests away.
        GoRoute(path: '/buy-time', builder: (_, _) => const BuyTimeScreen()),
        GoRoute(
          path: '/buy-time/checkout',
          builder: (_, _) => const BuyTimeCheckoutScreen(),
        ),
        GoRoute(path: '/entry', builder: (_, _) => const EntryGateScreen()),
        GoRoute(path: '/lounge', builder: (_, _) => const ActiveLoungeScreen()),
        GoRoute(path: '/exit', builder: (_, _) => const ExitGateScreen()),
        GoRoute(path: '/summary', builder: (_, _) => const SummaryScreen()),
        GoRoute(path: '/staff', builder: (_, _) => const DoorScannerScreen()),
        GoRoute(
          path: '/staff/tip-pad',
          builder: (_, _) => const BartenderTipPadScreen(),
        ),
      ],
    );
  }
}
