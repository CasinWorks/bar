import 'package:flutter/widgets.dart';

import '../../router/app_router.dart';

/// Resolves a context that can push routes for the app-wide alert hosts.
///
/// The hosts are mounted from `MaterialApp.builder`, which sits *above* the
/// router's [Navigator]; pushing a dialog with their own context throws
/// "Navigator operation requested with a context that does not include a
/// Navigator" and the overlay never appears. Prefer the router navigator and
/// only fall back to a context that actually has a navigator ancestor.
BuildContext? rootOverlayContext([BuildContext? fallback]) {
  final routerContext = AppRouter.navigatorKey.currentContext;
  if (routerContext != null && routerContext.mounted) return routerContext;
  if (fallback != null &&
      fallback.mounted &&
      Navigator.maybeOf(fallback, rootNavigator: true) != null) {
    return fallback;
  }
  return null;
}
