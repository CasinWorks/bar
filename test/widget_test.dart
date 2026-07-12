import 'package:flutter_test/flutter_test.dart';
import 'package:in_time_bartender/main.dart';

void main() {
  testWidgets('App launches Blind Tiger welcome screen', (WidgetTester tester) async {
    await tester.pumpWidget(const BlindTigerApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('THE BLIND TIGER'), findsOneWidget);
    expect(find.text('SIGN IN'), findsOneWidget);
    expect(find.text('CREATE MEMBER ACCOUNT'), findsOneWidget);
  });
}
