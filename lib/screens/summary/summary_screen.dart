import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/lattice_background.dart';
import '../../models/club_session.dart';
import '../../models/time_economy.dart';
import '../../models/quest_system.dart';
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
        packageSlug: live.packageSlug,
        includedDrinksRemaining: live.includedDrinksRemaining,
        includedDrinksTotal: live.includedDrinksTotal,
        experiencesMinutesSpent: live.experiencesMinutesSpent,
        bonusMinutesEarned: live.bonusMinutesEarned,
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
    final recap = state.visitRecap;

    return Scaffold(
      body: LatticeBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Icon(
                  Icons.check_circle,
                  color: AppColors.successGreen,
                  size: 48,
                ),
                const SizedBox(height: 12),
                Text(
                  'YOUR NIGHT RECAP',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                Text(
                  'Time creates reputation. Reputation unlocks experiences.',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                LuxuryCard(
                  child: Column(
                    children: [
                      _Row('People met', '${recap.peopleMet}'),
                      _Row('XP gained', '+${recap.xpGained}'),
                      _Row('Time gifted', '${recap.timeGiftedMinutes} min'),
                      _Row('Time received', '${recap.timeReceivedMinutes} min'),
                      _Row('Events joined', '${recap.eventsJoined}'),
                      _Row('Quests completed', '${recap.questsCompleted}'),
                      _Row('Reputation', state.reputationLevel.label),
                      _Row(
                        'Banked time',
                        state.formatDuration(state.timeWallet.bankedSeconds),
                      ),
                    ],
                  ),
                ),
                if (recap.achievementsUnlocked.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  LuxuryCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ACHIEVEMENTS UNLOCKED',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 8),
                        ...recap.achievementsUnlocked.map(
                          (id) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                Icon(
                                  id.icon,
                                  size: 14,
                                  color: AppColors.goldBright,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  id.label,
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                if (session != null)
                  LuxuryCard(
                    child: Column(
                      children: [
                        _Row('Member', session.memberName),
                        _Row('Branch', session.branch),
                        if (session.packageSlug != null)
                          _Row('Package', session.packageSlug!),
                        _Row(
                          'Time remaining',
                          state.formatDuration(
                            session.remainingSeconds > 0
                                ? session.remainingSeconds
                                : balance,
                          ),
                        ),
                        _Row('Drinks ordered', '${session.drinksOrdered}'),
                        if (session.includedDrinksTotal > 0)
                          _Row(
                            'Drinks left',
                            '${session.includedDrinksRemaining} / ${session.includedDrinksTotal}',
                          ),
                        if (session.experiencesMinutesSpent > 0)
                          _Row(
                            'Experiences',
                            '−${session.experiencesMinutesSpent} min',
                          ),
                        if (session.bonusMinutesEarned > 0)
                          _Row(
                            'Bonus earned',
                            '+${session.bonusMinutesEarned} min',
                          ),
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
                const SizedBox(height: 24),
                if (balance > 0)
                  Text(
                    '$balanceLabel banked for your next visit.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.timerHealthy,
                      fontSize: 11,
                    ),
                    textAlign: TextAlign.center,
                  ),
                const SizedBox(height: 16),
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
                  'Need more time? Ask the house to load a package at the club.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontSize: 10),
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
                const SizedBox(height: 24),
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
