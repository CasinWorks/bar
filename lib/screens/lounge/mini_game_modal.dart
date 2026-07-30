import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/lattice_background.dart';
import '../../data/mock_data.dart';
import '../../models/blind_tiger_models.dart';
import '../../providers/app_state.dart';

class MiniGameModal extends StatefulWidget {
  const MiniGameModal({super.key, required this.game});

  final MiniGame game;

  static Future<void> show(BuildContext context, MiniGame game) {
    return showDialog<void>(
      context: context,
      builder: (_) => MiniGameModal(game: game),
    );
  }

  @override
  State<MiniGameModal> createState() => _MiniGameModalState();
}

class _MiniGameModalState extends State<MiniGameModal> {
  final _random = Random();
  bool _played = false;
  int? _wonPoints;
  int _beatTaps = 0;
  int? _selectedGuess;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.neutral950,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.game.title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              widget.game.description,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontSize: 11),
            ),
            const SizedBox(height: 20),
            _buildGameBody(context),
            if (_wonPoints != null) ...[
              const SizedBox(height: 12),
              Text(
                '+$_wonPoints PTS',
                style: const TextStyle(
                  color: AppColors.goldBright,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (widget.game.id == 'game-3' && !_played)
              TigerButton(label: 'TAP BEAT', onPressed: () => _play(context))
            else
              TigerButton(
                label: _played ? 'CLOSE' : 'PLAY',
                onPressed: () {
                  if (_played) {
                    Navigator.pop(context);
                  } else {
                    _play(context);
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameBody(BuildContext context) {
    switch (widget.game.id) {
      case 'game-1':
        return Icon(
          Icons.album,
          size: 80,
          color: _played ? AppColors.goldBright : AppColors.neutral500,
        );
      case 'game-2':
        return Column(
          children: MockData.drinks.take(3).map((d) {
            final selected = _selectedGuess == d.id.hashCode;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: OutlinedButton(
                onPressed: _played
                    ? null
                    : () => setState(() => _selectedGuess = d.id.hashCode),
                style: OutlinedButton.styleFrom(
                  foregroundColor: selected
                      ? AppColors.goldBright
                      : AppColors.textMuted,
                  side: BorderSide(
                    color: selected
                        ? AppColors.goldBrushed
                        : AppColors.neutral900,
                  ),
                ),
                child: Text(d.name, style: const TextStyle(fontSize: 10)),
              ),
            );
          }).toList(),
        );
      case 'game-3':
        return Column(
          children: [
            Text(
              'TAPS: $_beatTaps / 8',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Icon(
              Icons.music_note,
              size: 48,
              color: _beatTaps.isOdd
                  ? AppColors.tigerOrange
                  : AppColors.goldBrushed,
            ),
          ],
        );
      default:
        return const Icon(Icons.casino, size: 64, color: AppColors.goldBrushed);
    }
  }

  void _play(BuildContext context) {
    final state = context.read<AppState>();
    int points = widget.game.points;

    switch (widget.game.id) {
      case 'game-1':
        points = [5, 10, 15, 20, 25][_random.nextInt(5)];
        break;
      case 'game-2':
        if (_selectedGuess == null) return;
        points = _random.nextBool() ? widget.game.points : 5;
        break;
      case 'game-3':
        setState(() => _beatTaps++);
        if (_beatTaps < 8) return;
        points = widget.game.points;
        break;
      default:
        points = widget.game.points ~/ 2;
    }

    state.completeMiniGame(widget.game, points);
    setState(() {
      _played = true;
      _wonPoints = points;
    });
  }
}
