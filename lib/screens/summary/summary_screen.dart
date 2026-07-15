import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/lattice_background.dart';
import '../../models/club_session.dart';
import '../../providers/app_state.dart';

class SummaryScreen extends StatefulWidget {
  const SummaryScreen({super.key});

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  ClubSessionRecord? _frozenSession;
  int? _frozenBalance;
  String? _frozenFormattedBalance;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = context.read<AppState>();
    final live = state.checkoutReceipt ?? state.session;
    // Freeze once so later AppState churn cannot blank the receipt.
    if (_frozenSession == null && live != null) {
      _frozenSession = ClubSessionRecord(
        id: live.id,
        memberId: live.memberId,
        memberName: live.memberName,
        purchasedSeconds: live.purchasedSeconds,
        amountPaid: live.amountPaid,
        branch: live.branch,
        phase: SessionPhase.completed,
        remainingSeconds: live.remainingSeconds,
        drinksOrdered: live.drinksOrdered,
        enteredAt: live.enteredAt,
        exitedAt: live.exitedAt,
      );
    } else if (_frozenSession != null && live != null) {
      // Allow Entered/Exited to catch up after finalize refreshes the receipt.
      if (live.enteredAt != null) {
        _frozenSession!.enteredAt = live.enteredAt;
      }
      if (live.exitedAt != null) {
        _frozenSession!.exitedAt = live.exitedAt;
      }
      if (live.remainingSeconds > 0) {
        _frozenSession!.remainingSeconds = live.remainingSeconds;
      }
      if (live.drinksOrdered > _frozenSession!.drinksOrdered) {
        _frozenSession!.drinksOrdered = live.drinksOrdered;
      }
    }
    _frozenBalance ??= state.timeBalance;
    _frozenFormattedBalance ??= state.formatDuration(_frozenBalance!);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final session = _frozenSession ?? state.checkoutReceipt ?? state.session;
    final balance = _frozenBalance ?? state.timeBalance;
    final balanceLabel =
        _frozenFormattedBalance ?? state.formatDuration(balance);

    return Scaffold(
      body: LatticeBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Icon(Icons.check_circle, color: AppColors.successGreen, size: 48),
                const SizedBox(height: 12),
                Text('CHECKOUT COMPLETE', style: Theme.of(context).textTheme.headlineLarge),
                Text(
                  'Thank you for visiting The Blind Tiger.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (balance > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    '$balanceLabel saved to your time balance for your next visit.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.timerNeon,
                          fontSize: 11,
                          shadows: AppColors.timerGlow(AppColors.timerNeon, intensity: 0.45),
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 24),
                if (session != null)
                  LuxuryCard(
                    child: Column(
                      children: [
                        _Row('Member', session.memberName),
                        _Row('Branch', session.branch),
                        _Row('Pass', '${session.purchasedSeconds ~/ 60} minutes'),
                        _Row('Paid', '₱${session.amountPaid}'),
                        _Row(
                          'Time remaining',
                          state.formatDuration(
                            session.remainingSeconds > 0
                                ? session.remainingSeconds
                                : balance,
                          ),
                        ),
                        _Row('Drinks ordered', '${session.drinksOrdered}'),
                        if (session.enteredAt != null)
                          _Row('Entered', _formatTime(session.enteredAt!)),
                        if (session.exitedAt != null)
                          _Row('Exited', _formatTime(session.exitedAt!)),
                      ],
                    ),
                  )
                else
                  LuxuryCard(
                    child: Text(
                      'Visit details are still syncing…',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ),
                const Spacer(),
                if (state.canPurchaseNewPass)
                  TigerButton(
                    label: 'PURCHASE NEW PASS',
                    icon: Icons.add_circle_outline,
                    onPressed: () {
                      state.beginNewVisit();
                      context.go('/pricing');
                    },
                  )
                else ...[
                  TigerButton(
                    label: 'USE MY TIME BALANCE',
                    icon: Icons.account_balance_wallet,
                    onPressed: () {
                      state.beginNewVisit();
                      context.go('/pricing');
                    },
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  'Need more time? Ask the house to load minutes at the club.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 10),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () async {
                    await state.logout();
                    if (context.mounted) context.go('/');
                  },
                  child: const Text('Sign Out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final local = ClubSessionRecord.correctToLocal(dt);
    final h24 = local.hour;
    final h12 = h24 % 12 == 0 ? 12 : h24 % 12;
    final ampm = h24 >= 12 ? 'PM' : 'AM';
    final mm = local.minute.toString().padLeft(2, '0');
    return '$h12:$mm $ampm';
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}
