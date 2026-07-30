import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/lattice_background.dart';
import '../../models/time_economy.dart';
import '../../providers/app_state.dart';

/// Interactive handler for live night timeline events.
class NightEventSheet extends StatefulWidget {
  const NightEventSheet({super.key, required this.event});

  final NightTimelineEvent event;

  static Future<void> show(BuildContext context, NightTimelineEvent event) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.charcoal,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => NightEventSheet(event: event),
    );
  }

  @override
  State<NightEventSheet> createState() => _NightEventSheetState();
}

class _NightEventSheetState extends State<NightEventSheet> {
  bool _busy = false;
  String? _message;

  Future<void> _join() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    final result = await context.read<AppState>().joinNightEvent(
      widget.event.id,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = result;
    });
    if (result != null && result.startsWith('+')) {
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final event =
        state.nightTimeline
            .where((e) => e.id == widget.event.id)
            .cast<NightTimelineEvent?>()
            .firstOrNull ??
        widget.event;
    final canJoin = event.isActive && !event.isCompleted;
    final minutes = state.timeBalance ~/ 60;

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
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.darkSteel,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(event.icon, color: AppColors.tigerRed, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title.toUpperCase(),
                      style: Theme.of(
                        context,
                      ).textTheme.headlineMedium?.copyWith(fontSize: 16),
                    ),
                    Text(
                      '${event.triggerLabel} · ${event.isActive ? 'LIVE NOW' : 'Scheduled'}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LuxuryCard(
            padding: const EdgeInsets.all(14),
            child: Text(
              event.description,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontSize: 12),
            ),
          ),
          const SizedBox(height: 12),
          if (event.type == NightEventType.hiddenRoom)
            LuxuryCard(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    minutes > 90 ? Icons.lock_open : Icons.lock,
                    color: minutes > 90
                        ? AppColors.successGreen
                        : AppColors.tigerRed,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      minutes > 90
                          ? 'You have $minutes min — entry unlocked.'
                          : 'Need >90 min. You have $minutes min.',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          if (_message != null) ...[
            const SizedBox(height: 10),
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
          if (event.isCompleted)
            const Center(
              child: Text(
                'EVENT COMPLETE',
                style: TextStyle(
                  color: AppColors.successGreen,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          else
            TigerButton(
              label: _actionLabel(event),
              icon: event.icon,
              onPressed: canJoin && !_busy ? _join : null,
            ),
          const SizedBox(height: 8),
          TigerButton(
            label: 'CLOSE',
            secondary: true,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  String _actionLabel(NightTimelineEvent event) {
    if (_busy) return 'PROCESSING…';
    return switch (event.type) {
      NightEventType.timeDrop => 'CLAIM TIME DROP',
      NightEventType.mysteryPatron => 'OPEN MYSTERY GIFT',
      NightEventType.theVault => 'CAST VOTE',
      NightEventType.timeMarket => 'PLACE BID',
      NightEventType.secretMissions => 'ACCEPT MISSION',
      NightEventType.hiddenRoom => 'ENTER HIDDEN ROOM',
    };
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    if (it.moveNext()) return it.current;
    return null;
  }
}
