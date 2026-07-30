import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/root_overlay_context.dart';
import '../../providers/app_state.dart';
import '../events/event_guest_welcome_page.dart';

/// Presents the guest welcome page after event door check-in.
class EventGuestWelcomeHost extends StatefulWidget {
  const EventGuestWelcomeHost({super.key, required this.child});

  final Widget child;

  @override
  State<EventGuestWelcomeHost> createState() => _EventGuestWelcomeHostState();
}

class _EventGuestWelcomeHostState extends State<EventGuestWelcomeHost> {
  bool _presenting = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, app, _) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _tryPresent(app);
        });
        return widget.child;
      },
    );
  }

  Future<void> _tryPresent(AppState app) async {
    if (_presenting || app.hasCheckoutReceipt) return;
    final alert = app.pendingEventGuestWelcome;
    if (alert == null) return;

    // The router navigator may not be attached yet (cold start, redirect in
    // flight). Leave the alert queued and retry on the next notification.
    final navContext = rootOverlayContext(context);
    if (navContext == null) return;

    _presenting = true;
    try {
      await showEventGuestWelcomePage(navContext, alert: alert);
    } catch (error, stackTrace) {
      debugPrint('Event guest welcome page failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      _presenting = false;
    }

    // Dequeue even when the page failed so one bad frame cannot wedge the
    // queue. Only this door scan is marked delivered, so the next scan at the
    // door still gets its welcome.
    if (mounted) {
      context.read<AppState>().clearPendingEventGuestWelcome();
    } else {
      app.clearPendingEventGuestWelcome();
    }
  }
}
