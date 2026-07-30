import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:in_time_bartender/core/widgets/root_overlay_context.dart';
import 'package:in_time_bartender/router/app_router.dart';

GoRouter _router() => GoRouter(
  navigatorKey: AppRouter.navigatorKey,
  routes: [
    GoRoute(
      path: '/',
      builder: (_, _) => const Scaffold(body: Text('home')),
    ),
  ],
);

void main() {
  group('rootOverlayContext', () {
    testWidgets('MaterialApp.builder context alone cannot push a dialog', (
      tester,
    ) async {
      late BuildContext builderContext;
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: _router(),
          builder: (context, child) {
            builderContext = context;
            return child ?? const SizedBox.shrink();
          },
        ),
      );

      expect(
        Navigator.maybeOf(builderContext, rootNavigator: true),
        isNull,
        reason: 'global alert hosts sit above the router navigator',
      );
    });

    testWidgets('resolves the router navigator so overlays can present', (
      tester,
    ) async {
      late BuildContext builderContext;
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: _router(),
          builder: (context, child) {
            builderContext = context;
            return child ?? const SizedBox.shrink();
          },
        ),
      );

      final navContext = rootOverlayContext(builderContext);
      expect(navContext, isNotNull);

      unawaitedDialog(navContext!);
      await tester.pumpAndSettle();

      expect(find.text('welcome overlay'), findsOneWidget);
    });
  });
}

void unawaitedDialog(BuildContext context) {
  showGeneralDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    pageBuilder: (_, _, _) => const Material(
      color: Colors.transparent,
      child: Text('welcome overlay'),
    ),
  );
}
