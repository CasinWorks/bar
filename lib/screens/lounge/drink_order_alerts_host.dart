import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_state.dart';
import '../../core/widgets/drink_order_overlay.dart';
import '../../core/widgets/root_overlay_context.dart';

/// Presents drink delivery celebrations when the bartender marks an order served.
class DrinkOrderAlertsHost extends StatefulWidget {
  const DrinkOrderAlertsHost({super.key, required this.child});

  final Widget child;

  @override
  State<DrinkOrderAlertsHost> createState() => _DrinkOrderAlertsHostState();
}

class _DrinkOrderAlertsHostState extends State<DrinkOrderAlertsHost> {
  String? _showingAlertId;
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
    if (_presenting) return;
    final alert = app.pendingDrinkDeliveryAlert;
    if (alert == null || alert.id == _showingAlertId) return;

    final navContext = rootOverlayContext(context);
    if (navContext == null) return;

    _presenting = true;
    _showingAlertId = alert.id;

    try {
      await DrinkOrderOverlay.showDelivered(navContext, alert: alert);
    } finally {
      _presenting = false;
    }

    if (mounted) {
      context.read<AppState>().clearPendingDrinkDeliveryAlert();
    } else {
      app.clearPendingDrinkDeliveryAlert();
    }
    _showingAlertId = null;
  }
}
