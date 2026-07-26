import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/supabase_config.dart';
import 'core/observability/app_observability.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/wallet_credit_celebration_host.dart';
import 'providers/app_state.dart';
import 'router/app_router.dart';
import 'screens/lounge/social_alerts_host.dart';
import 'services/push_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppObservability.install();
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // Register before runApp so terminated/background FCM can wake a Dart isolate.
  if (!kIsWeb) {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    } catch (e) {
      debugPrint('Firebase early init skipped: $e');
    }
  }

  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.anonKey,
    );
  }

  runApp(const BlindTigerApp());
}

class BlindTigerApp extends StatefulWidget {
  const BlindTigerApp({super.key});

  @override
  State<BlindTigerApp> createState() => _BlindTigerAppState();
}

class _BlindTigerAppState extends State<BlindTigerApp>
    with WidgetsBindingObserver {
  late final AppState _appState;
  late final _router = AppRouter.create(_appState);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _appState = AppState()..initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _appState.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    _appState.setAppForeground(foreground);
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _appState,
      child: MaterialApp.router(
        title: 'Blind Tiger Club District',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        routerConfig: _router,
        builder: (context, child) {
          return SocialAlertsHost(
            child: WalletCreditCelebrationHost(
              child: child ?? const SizedBox.shrink(),
            ),
          );
        },
      ),
    );
  }
}
