import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_time_bartender/core/config/supabase_config.dart';
import 'package:in_time_bartender/core/theme/app_theme.dart';
import 'package:in_time_bartender/models/event_models.dart';
import 'package:in_time_bartender/models/qr_payload.dart';
import 'package:in_time_bartender/providers/app_state.dart';
import 'package:in_time_bartender/screens/events/event_guest_pass_screen.dart';
import 'package:in_time_bartender/services/qr_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

EventInvitePreview _acceptedInvite({String status = 'accepted'}) =>
    EventInvitePreview.fromJson({
      'invite_id': 'inv_1',
      'event_id': 'evt_1',
      'title': 'Birthday Night',
      'branch': 'Cubao',
      'starts_at': DateTime.now()
          .add(const Duration(days: 1))
          .toUtc()
          .toIso8601String(),
      'ends_at': DateTime.now()
          .add(const Duration(days: 1, hours: 4))
          .toUtc()
          .toIso8601String(),
      'event_type': 'birthday',
      'approval_status': 'approved',
      'host_name': 'Ana',
      'guest_name': 'Chris',
      'status': status,
      'invite_code': 'VIP-NOT-FOR-PASS',
      if (status == 'checked_in')
        'checked_in_at': DateTime.now().toUtc().toIso8601String(),
    });

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

  testWidgets('guest pass shows door QR copy and hides invite code', (
    tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: AppState(qrService: QrService()),
        child: MaterialApp(
          theme: AppTheme.dark,
          home: EventGuestPassScreen(invite: _acceptedInvite()),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Show this QR at the door'), findsNothing);
    expect(find.text('Member pass required'), findsOneWidget);
    expect(find.text('VIP-NOT-FOR-PASS'), findsNothing);
    expect(find.textContaining('Staff scan once'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('checked-in pass still offers re-scan welcome copy', (
    tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: AppState(qrService: QrService()),
        child: MaterialApp(
          theme: AppTheme.dark,
          home: EventGuestPassScreen(
            invite: _acceptedInvite(status: 'checked_in'),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('CHECKED IN'), findsOneWidget);
    expect(find.textContaining("Ana's party"), findsOneWidget);
    expect(find.textContaining('replay your welcome'), findsOneWidget);
    expect(find.text('VIP-NOT-FOR-PASS'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('createEntryCheckInQr uses entry purpose payload shape', () {
    final qr = QrService();
    final state = AppState(qrService: qr);

    expect(state.createEntryCheckInQr(), isNull);

    final payload = qr.createPayload(
      userId: 'member_1',
      sessionId: 'sess_1',
      memberName: 'Chris',
      purpose: QrPurpose.entry,
    );

    expect(payload.purpose.name, 'entry');
    expect(payload.encode(), contains('"purpose":"entry"'));
    expect(payload.encode(), contains('"user_id":"member_1"'));
    expect(payload.encode(), contains('"session_id":"sess_1"'));
  });
}
