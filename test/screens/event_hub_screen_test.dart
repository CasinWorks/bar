import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_time_bartender/core/config/supabase_config.dart';
import 'package:in_time_bartender/core/theme/app_theme.dart';
import 'package:in_time_bartender/providers/app_state.dart';
import 'package:in_time_bartender/screens/events/event_hub_screen.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    if (SupabaseConfig.isConfigured) {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        publishableKey: SupabaseConfig.anonKey,
      );
    }
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('renders the compact hub on a small screen without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: AppState(),
        child: MaterialApp(theme: AppTheme.dark, home: const EventHubScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('EVENTS & CALENDAR'), findsOneWidget);
    expect(find.text('REQUEST AN EVENT'), findsOneWidget);
    expect(find.text('Nothing booked on this day.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('date strip picks a day and the month grid is opt-in', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: AppState(),
        child: MaterialApp(theme: AppTheme.dark, home: const EventHubScreen()),
      ),
    );
    await tester.pump();

    // Month grid is collapsed by default so the calendar stays compact.
    expect(find.byTooltip('Previous month'), findsNothing);

    final tomorrow = DateTime.now().add(const Duration(days: 1));
    await tester.tap(find.text('${tomorrow.day}').first);
    await tester.pump();
    expect(
      find.text(DateFormat('EEE, MMM d').format(tomorrow).toUpperCase()),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Show month'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byTooltip('Previous month'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('request form stays collapsed until asked for', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: AppState(),
        child: MaterialApp(theme: AppTheme.dark, home: const EventHubScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Event title'), findsNothing);

    await tester.tap(find.text('REQUEST AN EVENT'));
    // The lattice backdrop animates forever, so settle by hand.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Event title'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
