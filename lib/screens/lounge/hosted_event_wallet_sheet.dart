import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/lattice_background.dart';
import '../../models/event_models.dart';
import '../../providers/app_state.dart';

class HostedEventWalletSheet extends StatefulWidget {
  const HostedEventWalletSheet({super.key, this.promptOnOpen = false});

  final bool promptOnOpen;

  static Future<void> show(BuildContext context, {bool promptOnOpen = false}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.charcoal,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => HostedEventWalletSheet(promptOnOpen: promptOnOpen),
    );
  }

  @override
  State<HostedEventWalletSheet> createState() => _HostedEventWalletSheetState();
}

class _HostedEventWalletSheetState extends State<HostedEventWalletSheet> {
  static const List<int> _extensionOptions = [15, 30, 60];

  bool _didAcknowledgePrompt = false;
  bool _busy = false;
  String? _message;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didAcknowledgePrompt || !widget.promptOnOpen) return;
    _didAcknowledgePrompt = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AppState>().acknowledgeHostedEventWalletPrompt();
    });
  }

  Future<void> _extendWallet(
    int minutes,
    HostedEventWalletSummary summary,
  ) async {
    setState(() {
      _busy = true;
      _message = null;
    });

    final state = context.read<AppState>();
    final (event, error) = await state.extendHostedEventWallet(
      eventId: summary.event.id,
      minutes: minutes,
    );
    if (!mounted) return;

    setState(() {
      _busy = false;
      _message =
          error ??
          '+$minutes min added to ${event?.title ?? summary.event.title}';
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final summary = state.hostedEventWalletSummary;

    if (summary == null) {
      return Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          24 + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SheetHandle(),
            const SizedBox(height: 16),
            Text(
              'HOST EVENT WALLET',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontSize: 16),
            ),
            const SizedBox(height: 12),
            const LuxuryCard(
              padding: EdgeInsets.all(14),
              child: Text(
                'No active hosted event wallet is available right now.',
                style: TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(height: 16),
            TigerButton(
              label: 'CLOSE',
              secondary: true,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
    }

    final accent = summary.isDepleted
        ? AppColors.dangerRed
        : summary.isLow
        ? AppColors.goldBright
        : AppColors.successGreen;
    final remainingLabel = state.formatDuration(summary.remainingSeconds);
    final thresholdLabel = state.formatDuration(summary.lowThresholdSeconds);
    final consumedLabel = state.formatDuration(summary.consumedSeconds);
    final extendedLabel = state.formatDuration(summary.extendedSeconds);
    final allocatedLabel = state.formatDuration(summary.allocatedSeconds);
    final startingLabel = state.formatDuration(summary.startingSeconds);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        24 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SheetHandle(),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.account_balance_wallet, color: accent, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'HOST EVENT WALLET',
                      style: Theme.of(
                        context,
                      ).textTheme.headlineMedium?.copyWith(fontSize: 16),
                    ),
                    Text(
                      summary.event.title,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LuxuryCard(
            highlighted: summary.isLow,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _WalletMetric(
                        label: 'EVENT BALANCE',
                        value: remainingLabel,
                        color: accent,
                      ),
                    ),
                    Expanded(
                      child: _WalletMetric(
                        label: 'LOW PROMPT',
                        value: thresholdLabel,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _WalletMetric(
                        label: 'SPENT',
                        value: consumedLabel,
                        color: AppColors.textLight,
                      ),
                    ),
                    Expanded(
                      child: _WalletMetric(
                        label: 'EXTENDED',
                        value: extendedLabel,
                        color: AppColors.goldBright,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 8,
                    value: summary.remainingRatio,
                    backgroundColor: AppColors.darkSteel,
                    valueColor: AlwaysStoppedAnimation<Color>(accent),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Started with $startingLabel · total funded $allocatedLabel',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 10,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  summary.isDepleted
                      ? 'Event time is depleted. Guests fall back to their own wallet unless product rules say otherwise.'
                      : summary.isLow
                      ? 'You are near depletion. Extend time now to keep the event wallet funded.'
                      : 'Event wallet is healthy. This balance is separate from your personal time.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontSize: 11),
                ),
                if (summary.isLow) ...[
                  const SizedBox(height: 12),
                  TigerButton(
                    label: summary.isDepleted
                        ? 'ADD TIME NOW'
                        : 'EXTEND BEFORE DEPLETION',
                    icon: Icons.add_alarm,
                    onPressed: state.usesCloud && !_busy
                        ? () => _extendWallet(15, summary)
                        : null,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          LuxuryCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'EXTEND TIME',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontSize: 8),
                ),
                const SizedBox(height: 8),
                Text(
                  state.usesCloud
                      ? 'Pragmatic MVP: trigger the existing extend-wallet backend action with preset minute packs.'
                      : 'Supabase is required to extend the hosted event wallet from the app.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontSize: 10),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _extensionOptions.map((minutes) {
                    return OutlinedButton.icon(
                      onPressed: state.usesCloud && !_busy
                          ? () => _extendWallet(minutes, summary)
                          : null,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.goldBright,
                        side: const BorderSide(color: AppColors.goldBright),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                      ),
                      icon: const Icon(Icons.add_alarm, size: 16),
                      label: Text('+$minutes min'),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          if (_message != null) ...[
            const SizedBox(height: 12),
            Text(
              _message!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _message!.startsWith('+')
                    ? AppColors.successGreen
                    : AppColors.tigerRed,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 16),
          TigerButton(
            label: _busy ? 'UPDATING…' : 'CLOSE',
            secondary: true,
            onPressed: _busy ? null : () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.darkSteel,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _WalletMetric extends StatelessWidget {
  const _WalletMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 8),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ],
    );
  }
}
