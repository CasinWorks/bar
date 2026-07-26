import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_time_bartender/core/config/supabase_config.dart';
import 'package:in_time_bartender/main.dart';
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

  testWidgets('App launches Blind Tiger shell', (WidgetTester tester) async {
    await tester.pumpWidget(const BlindTigerApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
