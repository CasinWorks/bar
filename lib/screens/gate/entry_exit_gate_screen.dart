import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../models/club_session.dart';
import '../../core/widgets/lattice_background.dart';
import '../../models/qr_payload.dart';
import '../../providers/app_state.dart';

class EntryGateScreen extends StatefulWidget {
  const EntryGateScreen({super.key});

  @override
  State<EntryGateScreen> createState() => _EntryGateScreenState();
}

class _EntryGateScreenState extends State<EntryGateScreen> {
  bool _autoSkipStarted = false;

  void _maybeAutoSkipDoorScan(AppState state) {
    if (_autoSkipStarted) return;
    if (!state.canSkipDoorQr) return;
    if (state.sessionPhase != SessionPhase.paidAwaitingEntry) return;
    _autoSkipStarted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final ok = await context.read<AppState>().debugBypassDoorScan();
      if (!mounted || !ok) return;
      context.go('/lounge');
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final session = state.session;
    final qr = state.currentQr;
    _maybeAutoSkipDoorScan(state);

    if (session == null || qr == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/pricing');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (state.sessionPhase == SessionPhase.insideClub) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/lounge');
      });
    }

    final skipQr = state.canSkipDoorQr;

    return Scaffold(
      body: LatticeBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                _SecretDoorKnock(
                  child: Column(
                    children: [
                      const Icon(
                        Icons.door_front_door,
                        color: AppColors.goldBright,
                        size: 40,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        skipQr ? 'ENTERING…' : 'ENTRY GATE',
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                    ],
                  ),
                  onUnlocked: () async {
                    final ok = await state.debugBypassDoorScan();
                    if (!context.mounted || !ok) return;
                    context.go('/lounge');
                  },
                ),
                Text(
                  skipQr
                      ? 'VIP entry — no door scan needed'
                      : 'Present this QR to door staff to enter',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                if (skipQr)
                  const Expanded(
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.goldBrushed,
                      ),
                    ),
                  )
                else ...[
                _QrCard(data: qr.encode(), purpose: QrPurpose.entry),
                const SizedBox(height: 16),
                LuxuryCard(
                  child: Column(
                    children: [
                      Text(
                        'SESSION CODE',
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(fontSize: 9),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        session.displayCode,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${session.memberName} • ${session.branch}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      Text(
                        session.amountPaid > 0
                            ? '${session.purchasedSeconds ~/ 60} min pass • ₱${session.amountPaid}'
                            : '${session.purchasedSeconds ~/ 60} min • from wallet',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: AppColors.goldBright),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.goldBrushed,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Waiting for door scan… Your timer starts after entry.',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'QR refreshes every 45 seconds for security',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontSize: 10),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TigerButton(
                        label: 'GO BACK',
                        icon: Icons.arrow_back,
                        secondary: true,
                        onPressed: () => _showEntryCancelDialog(context, state),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TigerButton(
                        label: 'SIGN OUT',
                        icon: Icons.logout,
                        secondary: true,
                        onPressed: () => _signOutFromEntry(context, state),
                      ),
                    ),
                  ],
                ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showEntryCancelDialog(
    BuildContext context,
    AppState state,
  ) async {
    final fromWallet = (state.session?.amountPaid ?? 0) == 0;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel entry?'),
        content: Text(
          fromWallet
              ? 'Your time will go back to your wallet. You can enter again whenever you\'re ready.'
              : 'Your pass will be voided and remaining time returns to your wallet.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Go Back'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    await state.cancelPendingPass();
    if (context.mounted) context.go('/pricing');
  }

  Future<void> _signOutFromEntry(BuildContext context, AppState state) async {
    await state.cancelPendingPass();
    await state.logout();
    if (context.mounted) context.go('/');
  }
}

class ExitGateScreen extends StatelessWidget {
  const ExitGateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final session = state.session;
    final qr = state.currentQr;

    if (state.hasCheckoutReceipt ||
        state.sessionPhase == SessionPhase.completed ||
        session == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        if (state.hasCheckoutReceipt ||
            state.sessionPhase == SessionPhase.completed) {
          context.go('/summary');
        } else {
          context.go('/pricing');
        }
      });
      return const SizedBox.shrink();
    }

    return Scaffold(
      body: LatticeBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                _SecretDoorKnock(
                  child: Column(
                    children: [
                      const Icon(
                        Icons.logout,
                        color: AppColors.tigerOrange,
                        size: 40,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'EXIT GATE',
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                    ],
                  ),
                  onUnlocked: () async {
                    final ok = await state.debugBypassDoorScan();
                    if (!context.mounted || !ok) return;
                    context.go('/summary');
                  },
                ),
                Text(
                  'Present this QR to door staff to leave',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                if (qr != null) _QrCard(data: qr.encode(), purpose: QrPurpose.exit),
                const SizedBox(height: 16),
                LuxuryCard(
                  child: Column(
                    children: [
                      Text(
                        'EXIT CODE',
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(fontSize: 9),
                      ),
                      Text(
                        session.displayCode,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Time remaining: ${state.formatDuration(state.timeRemaining)}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: AppColors.timerNeon,
                              shadows: AppColors.timerGlow(
                                AppColors.timerNeon,
                                intensity: 0.7,
                              ),
                            ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    const Icon(Icons.shield, color: AppColors.goldBright, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Time still counts until door staff scans. Holding this QR does not pause the meter.',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TigerButton(
                        label: 'STAY IN CLUB',
                        icon: Icons.undo,
                        secondary: true,
                        onPressed: () async {
                          await state.cancelExitRequest();
                          if (context.mounted) context.go('/lounge');
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TigerButton(
                        label: 'SIGN OUT',
                        icon: Icons.logout,
                        secondary: true,
                        onPressed: () async {
                          await state.logout();
                          if (context.mounted) context.go('/');
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Triple-tap the door header to skip staff scan (2-phone testing).
class _SecretDoorKnock extends StatefulWidget {
  const _SecretDoorKnock({
    required this.child,
    required this.onUnlocked,
  });

  final Widget child;
  final Future<void> Function() onUnlocked;

  @override
  State<_SecretDoorKnock> createState() => _SecretDoorKnockState();
}

class _SecretDoorKnockState extends State<_SecretDoorKnock> {
  int _taps = 0;
  DateTime? _lastTap;
  bool _busy = false;

  Future<void> _onTap() async {
    if (_busy) return;
    final now = DateTime.now();
    if (_lastTap == null ||
        now.difference(_lastTap!) > const Duration(milliseconds: 1200)) {
      _taps = 1;
    } else {
      _taps += 1;
    }
    _lastTap = now;
    HapticFeedback.selectionClick();

    if (_taps < 3) return;
    _taps = 0;
    _busy = true;
    HapticFeedback.heavyImpact();
    try {
      await widget.onUnlocked();
    } finally {
      if (mounted) _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
        child: widget.child,
      ),
    );
  }
}

class _QrCard extends StatelessWidget {
  const _QrCard({required this.data, required this.purpose});

  final String data;
  final QrPurpose purpose;

  @override
  Widget build(BuildContext context) {
    final color =
        purpose == QrPurpose.entry ? AppColors.successGreen : AppColors.tigerOrange;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color, width: 3),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 20)],
      ),
      child: Column(
        children: [
          Text(
            purpose == QrPurpose.entry ? 'ENTRY PASS' : 'EXIT PASS',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 8),
          QrImageView(data: data, version: QrVersions.auto, size: 220),
        ],
      ),
    );
  }
}
