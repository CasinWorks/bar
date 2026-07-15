import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/lattice_background.dart';
import '../../models/tip_pad_payload.dart';
import '../../models/time_gift.dart';
import '../../providers/app_state.dart';
import '../../services/time_gift_service.dart';
import 'time_transfer_overlay.dart';

/// Guest flow: scan bartender tip pad (NFC vibe) → pour minutes → fly animation.
class TipBartenderSheet extends StatefulWidget {
  const TipBartenderSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.neutral950,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const TipBartenderSheet(),
    );
  }

  @override
  State<TipBartenderSheet> createState() => _TipBartenderSheetState();
}

enum _TipPhase { scan, pour, transferring, done }

class _TipBartenderSheetState extends State<TipBartenderSheet> {
  final _scanner = MobileScannerController();
  _TipPhase _phase = _TipPhase.scan;
  TipPadPayload? _pad;
  GlassPour _pour = GlassPours.tips[0];
  bool _busy = false;
  String? _error;
  TimeGift? _gift;

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_phase != _TipPhase.scan) return;
    for (final b in capture.barcodes) {
      final raw = b.rawValue;
      if (raw == null) continue;
      final pad = TipPadPayload.tryDecode(raw);
      if (pad == null) continue;
      if (!pad.isFresh) {
        setState(() => _error = 'Tip pad expired — ask bartender to refresh.');
        continue;
      }
      _scanner.stop();
      setState(() {
        _pad = pad;
        _phase = _TipPhase.pour;
        _error = null;
      });
      return;
    }
  }

  Future<void> _sendTip() async {
    final pad = _pad;
    if (pad == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    final state = context.read<AppState>();
    final (gift, err) = await state.tipBartender(
      staffId: pad.staffId,
      staffName: pad.staffName,
      minutes: _pour.minutes,
    );

    if (!mounted) return;
    setState(() => _busy = false);

    if (err != null || gift == null) {
      setState(() => _error = err ?? 'Tip failed');
      return;
    }

    setState(() {
      _gift = gift;
      _phase = _TipPhase.transferring;
    });
  }

  void _onTransferDone() {
    setState(() => _phase = _TipPhase.done);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final height = MediaQuery.sizeOf(context).height * 0.92;

    return SizedBox(
      height: height,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.neutral500,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'TAP BARTENDER',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 18),
                ),
                Text(
                  'Hold your phone to their tip pad — same energy as NFC.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 11),
                ),
                const SizedBox(height: 8),
                Text(
                  'Spendable: ${state.formatDuration(state.ownedTimeSeconds)}',
                  style: TextStyle(
                    color: AppColors.timerNeon,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    shadows: AppColors.timerGlow(AppColors.timerNeon, intensity: 0.5),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(child: _body()),
              ],
            ),
          ),
          if (_phase == _TipPhase.transferring && _pad != null)
            TimeTransferOverlay(
              minutes: _pour.minutes,
              fromLabel: state.user?.name ?? 'You',
              toLabel: _pad!.staffName,
              onFinished: _onTransferDone,
            ),
        ],
      ),
    );
  }

  Widget _body() {
    return switch (_phase) {
      _TipPhase.scan => _ScanPhase(
          controller: _scanner,
          error: _error,
          onDetect: _onDetect,
        ),
      _TipPhase.pour => _PourPhase(
          pad: _pad!,
          pour: _pour,
          busy: _busy,
          error: _error,
          onSelect: (p) => setState(() => _pour = p),
          onSend: _sendTip,
          onRescan: () {
            setState(() {
              _phase = _TipPhase.scan;
              _pad = null;
              _error = null;
            });
            _scanner.start();
          },
        ),
      _TipPhase.transferring => const SizedBox.shrink(),
      _TipPhase.done => _DonePhase(
          gift: _gift!,
          bartender: _pad!.staffName,
          onClose: () => Navigator.pop(context),
        ),
    };
  }
}

class _ScanPhase extends StatelessWidget {
  const _ScanPhase({
    required this.controller,
    required this.onDetect,
    this.error,
  });

  final MobileScannerController controller;
  final void Function(BarcodeCapture) onDetect;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              alignment: Alignment.center,
              children: [
                MobileScanner(controller: controller, onDetect: onDetect),
                IgnorePointer(
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.goldBrushed, width: 3),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'SCAN TIP PAD',
                      style: TextStyle(
                        color: AppColors.goldBright,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 8),
          Text(error!, style: const TextStyle(color: AppColors.dangerRed, fontSize: 11)),
        ],
      ],
    );
  }
}

class _PourPhase extends StatelessWidget {
  const _PourPhase({
    required this.pad,
    required this.pour,
    required this.busy,
    required this.onSelect,
    required this.onSend,
    required this.onRescan,
    this.error,
  });

  final TipPadPayload pad;
  final GlassPour pour;
  final bool busy;
  final String? error;
  final ValueChanged<GlassPour> onSelect;
  final VoidCallback onSend;
  final VoidCallback onRescan;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LuxuryCard(
          highlighted: true,
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const Icon(Icons.person, color: AppColors.goldBright),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pad.staffName,
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                    ),
                    Text(
                      'Tip pad locked · ready to pour',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 10),
                    ),
                  ],
                ),
              ),
              TextButton(onPressed: onRescan, child: const Text('RESCAN')),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'HOW MUCH TIME?',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 9),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView(
            children: GlassPours.tips
                .map(
                  (p) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => onSelect(p),
                        borderRadius: BorderRadius.circular(12),
                        child: LuxuryCard(
                          highlighted: pour.id == p.id,
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${p.minutes} MIN · ${p.label}',
                                      style: const TextStyle(fontWeight: FontWeight.w900),
                                    ),
                                    Text(p.tagline, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 10)),
                                  ],
                                ),
                              ),
                              Icon(
                                pour.id == p.id ? Icons.check_circle : Icons.circle_outlined,
                                color: pour.id == p.id ? AppColors.goldBrushed : AppColors.neutral500,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        if (error != null) ...[
          Text(error!, style: const TextStyle(color: AppColors.dangerRed, fontSize: 11)),
          const SizedBox(height: 8),
        ],
        TigerButton(
          label: 'POUR ${pour.minutes}M TO ${pad.staffName.toUpperCase()}',
          icon: Icons.nfc,
          isLoading: busy,
          onPressed: busy ? null : onSend,
        ),
      ],
    );
  }
}

class _DonePhase extends StatelessWidget {
  const _DonePhase({
    required this.gift,
    required this.bartender,
    required this.onClose,
  });

  final TimeGift gift;
  final String bartender;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.check_circle, color: AppColors.successGreen, size: 64),
        const SizedBox(height: 16),
        Text(
          '${gift.minutes} MINUTES TIPPED',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 18),
        ),
        Text(
          'to $bartender — they just felt that pour.',
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        TigerButton(label: 'DONE', onPressed: onClose),
      ],
    );
  }
}
