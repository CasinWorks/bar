import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/club_session.dart';
import '../providers/app_state.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/member_tutorial_screen.dart';
import '../screens/auth/signup_screen.dart';
import '../screens/auth/verify_email_screen.dart';
import '../screens/legal/legal_document_screen.dart';
import '../screens/auth/welcome_screen.dart';
import '../models/event_models.dart';
import '../screens/events/event_guest_pass_screen.dart';
import '../screens/events/event_hub_screen.dart';
import '../screens/events/event_invite_screen.dart';
import '../screens/gate/entry_exit_gate_screen.dart';
import '../screens/lounge/active_lounge_screen.dart';
import '../screens/purchase/buy_time_checkout_screen.dart';
import '../screens/purchase/buy_time_screen.dart';
import '../screens/purchase/checkout_screen.dart';
import '../screens/purchase/pricing_screen.dart';
import '../screens/staff/bartender_bar_screen.dart';
import '../screens/staff/bartender_pos_screen.dart';
import '../screens/staff/bartender_tip_pad_screen.dart';
import '../screens/staff/door_scanner_screen.dart';
import '../screens/summary/summary_screen.dart';
import 'member_routes.dart';

class AppRouter {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static GoRouter create(AppState appState) {
    return GoRouter(
      navigatorKey: navigatorKey,
      initialLocation: '/',
      refreshListenable: appState,
      redirect: (context, state) {
        final app = appState;
        if (app.isLoading) return null;

        final loc = state.matchedLocation;
        final isPublic =
            loc == '/' ||
            loc == '/login' ||
            loc == '/signup' ||
            loc == '/verify-email' ||
            loc == '/event-invite' ||
            loc == '/privacy' ||
            loc == '/terms';

        if (!app.isAuthenticated && !isPublic) return '/';

        if (app.isAuthenticated &&
            (loc == '/' ||
                loc == '/login' ||
                loc == '/signup' ||
                loc == '/verify-email')) {
          if (app.needsMemberTutorial) return '/member-tutorial';
          return routeForAppState(app);
        }

        if (!app.isAuthenticated) return null;

        // Staff: door scanner + tip pad
        if (app.isStaff) {
          if (loc == '/staff' ||
              loc == '/staff/tip-pad' ||
              loc == '/staff/bar' ||
              loc == '/staff/pos') {
            return null;
          }
          return '/staff';
        }

        // First-run member briefing (skip if already mid-visit).
        if (app.needsMemberTutorial &&
            app.sessionPhase == SessionPhase.none &&
            !app.hasCheckoutReceipt) {
          if (loc != '/member-tutorial') return '/member-tutorial';
          return null;
        }

        if (loc == '/member-tutorial') {
          return routeForMemberState(app);
        }

        // Members cannot access staff scanner
        if (loc == '/staff') return routeForMemberState(app);

        // Exit receipt wins over every other member redirect.
        if (app.hasCheckoutReceipt ||
            app.sessionPhase == SessionPhase.completed) {
          if (loc != '/summary') return '/summary';
          return null;
        }

        // Guest Buy Time / in-app checkout temporarily disabled — loads happen at the club desk.
        if (loc == '/buy-time' ||
            loc == '/buy-time/checkout' ||
            loc == '/checkout') {
          if (app.sessionPhase == SessionPhase.paidAwaitingEntry) {
            return '/entry';
          }
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
            loc != '/checkout' &&
            loc != '/event-pass') {
          return loc == '/pricing' || loc == '/checkout' ? null : '/entry';
        }
        if (phase == SessionPhase.insideClub &&
            loc != '/exit' &&
            loc != '/event-pass' &&
            (loc == '/entry' ||
                loc == '/checkout' ||
                (loc == '/pricing' && !app.isTimeDepleted))) {
          return '/lounge';
        }
        if (phase == SessionPhase.awaitingExitScan &&
            loc != '/exit' &&
            loc != '/event-pass') {
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
        GoRoute(
          path: '/verify-email',
          builder: (context, state) {
            final email = state.uri.queryParameters['email'] ?? '';
            final name = state.uri.queryParameters['name'] ?? '';
            return VerifyEmailScreen(email: email, name: name);
          },
        ),
        GoRoute(
          path: '/event-invite',
          builder: (context, state) {
            final code = state.uri.queryParameters['code'];
            final token = state.uri.queryParameters['token'];
            return EventInviteScreen(initialCode: code, initialToken: token);
          },
        ),
        GoRoute(
          path: '/event-pass',
          builder: (context, state) {
            final invite = state.extra;
            if (invite is! EventInvitePreview) {
              return const EventHubScreen();
            }
            return EventGuestPassScreen(invite: invite);
          },
        ),
        GoRoute(
          path: '/member-tutorial',
          builder: (_, _) => const MemberTutorialScreen(),
        ),
        GoRoute(
          path: '/privacy',
          builder: (_, _) => const LegalDocumentScreen(
            title: 'Privacy Policy',
            assetPath: LegalDocumentScreen.privacyAsset,
          ),
        ),
        GoRoute(
          path: '/terms',
          builder: (_, _) => const LegalDocumentScreen(
            title: 'Terms of Use',
            assetPath: LegalDocumentScreen.termsAsset,
          ),
        ),
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
        GoRoute(path: '/events', builder: (_, _) => const EventHubScreen()),
        GoRoute(path: '/exit', builder: (_, _) => const ExitGateScreen()),
        GoRoute(path: '/summary', builder: (_, _) => const SummaryScreen()),
        GoRoute(path: '/staff', builder: (_, _) => const DoorScannerScreen()),
        GoRoute(
          path: '/staff/tip-pad',
          builder: (_, _) => const BartenderTipPadScreen(),
        ),
        GoRoute(
          path: '/staff/bar',
          builder: (_, _) => const BartenderBarScreen(),
        ),
        GoRoute(
          path: '/staff/pos',
          builder: (_, _) => const BartenderPosScreen(),
        ),
      ],
    );
  }
}
