import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/app_state.dart';
import 'root_overlay_context.dart';
import 'time_refill_overlay.dart';

/// Global host — plays the cash-desk “time landed” celebration on any screen.
class WalletCreditCelebrationHost extends StatefulWidget {
  const WalletCreditCelebrationHost({super.key, required this.child});

  final Widget child;

  @override
  State<WalletCreditCelebrationHost> createState() =>
      _WalletCreditCelebrationHostState();
}

class _WalletCreditCelebrationHostState
    extends State<WalletCreditCelebrationHost> {
  bool _showing = false;
  PendingWalletCredit? _lastShown;

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, app, _) {
        // Never cover the exit checkout receipt with a wallet pour overlay.
        if (app.hasCheckoutReceipt) {
          return widget.child;
        }

        final pending = app.pendingWalletCredit;
        final isNew =
            pending != null &&
            (pending.fromSeconds != _lastShown?.fromSeconds ||
                pending.toSeconds != _lastShown?.toSeconds);
        if (pending != null &&
            !_showing &&
            isNew &&
            (pending.toSeconds - pending.fromSeconds) > 3) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _present(context, app, pending);
          });
        }
        return widget.child;
      },
    );
  }

  Future<void> _present(
    BuildContext context,
    AppState app,
    PendingWalletCredit pending,
  ) async {
    if (!mounted || _showing) return;
    if (rootOverlayContext(context) == null) return;
    _showing = true;
    _lastShown = pending;
    app.clearPendingWalletCredit();

    HapticFeedback.heavyImpact();
    await Future<void>.delayed(const Duration(milliseconds: 40));
    HapticFeedback.mediumImpact();

    if (!context.mounted) {
      _showing = false;
      return;
    }
    final navContext = rootOverlayContext(context);
    if (navContext == null) {
      _showing = false;
      return;
    }

    await TimeRefillOverlay.show(
      navContext,
      fromSeconds: pending.fromSeconds,
      toSeconds: pending.toSeconds,
      title: pending.title ?? 'TIME LANDED',
      subtitle: pending.subtitle ?? 'Cash desk · wallet updated live',
    );

    if (mounted) {
      HapticFeedback.lightImpact();
      setState(() => _showing = false);
    } else {
      _showing = false;
    }
  }
}
