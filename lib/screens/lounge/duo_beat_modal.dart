import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/lattice_background.dart';
import '../../models/social_play.dart';
import '../../providers/app_state.dart';

/// Competitive Beat Synchronizer — lower elapsed ms to reach 8 taps wins.
class DuoBeatModal extends StatefulWidget {
  const DuoBeatModal({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const DuoBeatModal(),
    );
  }

  @override
  State<DuoBeatModal> createState() => _DuoBeatModalState();
}

class _DuoBeatModalState extends State<DuoBeatModal> {
  static const _targetTaps = 8;

  int _taps = 0;
  bool _started = false;
  bool _submitted = false;
  bool _busy = false;
  String? _error;
  DateTime? _start;
  int? _myMs;
  SocialMeet? _result;

  void _tap() {
    if (_submitted) return;
    if (!_started) {
      _started = true;
      _start = DateTime.now();
    }
    setState(() => _taps++);
    if (_taps >= _targetTaps) {
      final ms = DateTime.now().difference(_start!).inMilliseconds;
      // Score = inverted time (faster = higher). Cap for SQL int comfort.
      final score = (100000 - ms).clamp(0, 100000);
      _myMs = ms;
      unawaited(_submit(score));
    }
  }

  Future<void> _submit(int score) async {
    if (_submitted) return;
    setState(() {
      _submitted = true;
      _busy = true;
      _error = null;
    });
    final (meet, err) = await context.read<AppState>().submitDuoBeatScore(score);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = err;
      _result = meet;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final meet = _result ?? state.activeMeet;
    final waitingOpponent = _submitted &&
        meet != null &&
        meet.status != MeetStatus.completed;

    String? outcome;
    if (meet?.status == MeetStatus.completed && state.user != null) {
      if (meet!.winnerId == state.user!.id) {
        outcome = 'YOU WIN';
      } else if (meet.winnerId == null) {
        outcome = 'DRAW';
      } else {
        outcome = 'THEY WON';
      }
    }

    return Dialog(
      backgroundColor: AppColors.neutral950,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('DUO BEAT SYNC', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Tap $_targetTaps times as fast as you can.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 11),
            ),
            const SizedBox(height: 20),
            Text(
              'TAPS: $_taps / $_targetTaps',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Icon(
              Icons.music_note,
              size: 56,
              color: _taps.isOdd ? AppColors.tigerOrange : AppColors.timerNeon,
            ),
            if (_myMs != null) ...[
              const SizedBox(height: 8),
              Text(
                'Your time: ${(_myMs! / 1000).toStringAsFixed(2)}s',
                style: const TextStyle(color: AppColors.goldBright, fontSize: 12),
              ),
            ],
            if (waitingOpponent) ...[
              const SizedBox(height: 12),
              const Text(
                'Waiting for opponent score…',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
            if (outcome != null) ...[
              const SizedBox(height: 12),
              Text(
                outcome,
                style: TextStyle(
                  color: outcome == 'YOU WIN'
                      ? AppColors.timerNeon
                      : AppColors.goldBright,
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                ),
              ),
              if (meet != null)
                Text(
                  'You ${meet.hostId == state.user?.id ? meet.hostScore : meet.guestScore}'
                  ' · Them ${meet.hostId == state.user?.id ? meet.guestScore : meet.hostScore}',
                  style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: AppColors.tigerOrange, fontSize: 11)),
            ],
            const SizedBox(height: 16),
            if (!_submitted)
              TigerButton(
                label: _started ? 'TAP' : 'START · TAP',
                onPressed: _tap,
              )
            else if (outcome != null || (!_busy && _error != null))
              TigerButton(
                label: 'CLOSE',
                onPressed: () {
                  context.read<AppState>().clearActiveMeet();
                  Navigator.pop(context);
                },
              )
            else
              TigerButton(
                label: _busy ? '…' : 'REFRESH RESULT',
                onPressed: _busy
                    ? null
                    : () async {
                        setState(() => _busy = true);
                        await context.read<AppState>().refreshActiveMeet();
                        if (!mounted) return;
                        setState(() {
                          _busy = false;
                          _result = context.read<AppState>().activeMeet;
                        });
                      },
              ),
          ],
        ),
      ),
    );
  }
}
