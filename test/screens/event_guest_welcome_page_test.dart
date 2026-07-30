import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:in_time_bartender/models/event_guest_welcome_alert.dart';
import 'package:in_time_bartender/screens/events/event_guest_welcome_page.dart';

void main() {
  const alert = EventGuestWelcomeAlert(
    id: 'evt_1@1700000000000',
    hostName: 'IAmDaddyTV',
    eventTitle: 'BIRTHDAY OF DIANA',
    branch: 'Cubao Branch',
    guestName: 'Giovanni Dela Cruz',
  );

  Future<void> openPage(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showEventGuestWelcomePage(context, alert: alert),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    // The seal pulses forever, so settle by hand instead of pumpAndSettle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('greets the guest with the event, host and venue', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await openPage(tester);

    expect(find.text("YOU'RE IN, GIOVANNI"), findsOneWidget);
    expect(find.text("WELCOME TO IAMDADDYTV'S PARTY"), findsOneWidget);
    expect(find.text('BIRTHDAY OF DIANA'), findsOneWidget);
    expect(find.text('IAmDaddyTV'), findsOneWidget);
    expect(find.text('Cubao Branch'), findsOneWidget);
    expect(find.text("let's go party!!"), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stays up until the guest taps the call to action', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await openPage(tester);

    // Long enough that an auto-dismiss timer would have fired.
    await tester.pump(const Duration(seconds: 8));
    expect(find.text("WELCOME TO IAMDADDYTV'S PARTY"), findsOneWidget);

    await tester.tap(find.text("let's go party!!"));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text("WELCOME TO IAMDADDYTV'S PARTY"), findsNothing);
  });
}
