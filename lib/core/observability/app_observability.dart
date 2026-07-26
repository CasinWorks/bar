import 'package:flutter/foundation.dart';

/// Pilot observability hook. Wire Sentry here when `SENTRY_DSN` is available.
class AppObservability {
  static void install() {
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      previous?.call(details);
      if (kDebugMode) {
        debugPrint('[BlindTiger] ${details.exceptionAsString()}');
      }
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      if (kDebugMode) {
        debugPrint('[BlindTiger] $error\n$stack');
      }
      return true;
    };
  }
}
