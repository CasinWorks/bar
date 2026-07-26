import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/lattice_background.dart';
import '../../core/widgets/tiger_motion.dart';
import '../../models/meet_pad_payload.dart';
import '../../models/social_play.dart';
import '../../providers/app_state.dart';
import 'duo_beat_modal.dart';

enum _MeetMode { choose, showPad, scanPad, icebreaker }

/// Toast to Meet via Meet Pad QR (tip-pad energy — no typing).
class ToastToMeetSheet extends StatefulWidget {
  const ToastToMeetSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.neutral950,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const ToastToMeetSheet(),
    );
  }

  @override
  State<ToastToMeetSheet> createState() => _ToastToMeetSheetState();
}

class _ToastToMeetSheetState extends State<ToastToMeetSheet>
    with SingleTickerProviderStateMixin {
  _MeetMode _mode = _MeetMode.choose;
  bool _busy = false;
  String? _error;
  SocialMeet? _meet;
  Timer? _poll;
  late final AnimationController _pulse;
  MobileScannerController? _scanner;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _poll?.cancel();
    _pulse.dispose();
    _scanner?.dispose();
    super.dispose();
  }

  void _startPoll() {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 3), (_) async {
      await context.read<AppState>().refreshActiveMeet();
      if (!mounted) return;
      final meet = context.read<AppState>().activeMeet;
      if (meet != null) {
        setState(() {
          _meet = meet;
          if (meet.isMatched && meet.kind == MeetKind.toast) {
            _mode = _MeetMode.icebreaker;
            _poll?.cancel();
          }
        });
      }
    });
  }

  Future<void> _raiseAndShow() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final (meet, err) = await context.read<AppState>().raiseMeetToast(
      minutes: 2,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = err;
      _meet = meet;
      if (meet != null) {
        _mode = _MeetMode.showPad;
        _startPoll();
      }
    });
  }

  void _openScanner() {
    _scanner?.dispose();
    _scanner = MobileScannerController();
    setState(() {
      _mode = _MeetMode.scanPad;
      _error = null;
    });
  }

  Future<void> _onScan(BarcodeCapture capture) async {
    if (_busy || _mode != _MeetMode.scanPad) return;
    for (final b in capture.barcodes) {
      final raw = b.rawValue;
      if (raw == null) continue;
      final pad = MeetPadPayload.tryDecode(raw);
      if (pad == null) continue;
      if (!pad.isFresh) {
        setState(() => _error = 'Meet pad expired — ask them to raise again.');
        continue;
      }
      if (pad.kind != MeetKind.toast) {
        setState(
          () => _error = 'That pad is for Duo Beat — open Duo Beat Sync.',
        );
        continue;
      }
      setState(() => _busy = true);
      await _scanner?.stop();
      if (!mounted) return;
      final (meet, err) = await context.read<AppState>().joinMeet(pad.code);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = err;
        _meet = meet;
        if (meet != null && meet.isMatched) {
          _mode = _MeetMode.icebreaker;
        }
      });
      return;
    }
  }

  Future<void> _completeIcebreaker() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final (meet, err) = await context.read<AppState>().completeMeetIcebreaker();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = err;
      _meet = meet ?? _meet;
    });
  }

  String get _qrData {
    final meet = _meet;
    final user = context.read<AppState>().user;
    if (meet?.code == null || user == null) return '{}';
    return MeetPadPayload(
      code: meet!.code!,
      hostName: user.name,
      kind: MeetKind.toast,
      timestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    ).encode();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final meet = _meet ?? state.activeMeet;
    final height = MediaQuery.sizeOf(context).height * 0.88;

    return SizedBox(
      height: height,
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 12,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
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
            const SizedBox(height: 14),
            Text(
              'TOAST TO MEET',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Spend 2 minutes. Show or scan a Meet Pad — unlock an icebreaker.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontSize: 11),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Expanded(child: _body(state, meet)),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(
                  color: AppColors.tigerOrange,
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _body(AppState state, SocialMeet? meet) {
    if (_mode == _MeetMode.icebreaker && meet != null) {
      return FadeSlideIn(
        child: _IcebreakerView(
          meet: meet,
          selfId: state.user?.id,
          busy: _busy,
          onComplete: _completeIcebreaker,
        ),
      );
    }
    if (_mode == _MeetMode.showPad && meet?.code != null) {
      return FadeSlideIn(
        child: _ShowPadView(
          qrData: _qrData,
          pulse: _pulse,
          waiting: !meet!.isMatched,
          matchedName: meet.guestName,
          subtitle: 'Hold for someone Open to Meet — they scan this pad.',
        ),
      );
    }
    if (_mode == _MeetMode.scanPad) {
      return FadeSlideIn(
        child: _ScanPadView(
          controller: _scanner!,
          busy: _busy,
          onDetect: _onScan,
          onBack: () {
            _scanner?.dispose();
            _scanner = null;
            setState(() => _mode = _MeetMode.choose);
          },
        ),
      );
    }

    return FadeSlideIn(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          TigerButton(
            label: _busy ? 'RAISING…' : 'SHOW MEET PAD (2 MIN)',
            icon: Icons.qr_code_2,
            onPressed: _busy || !state.canSpendTime ? null : _raiseAndShow,
          ),
          const SizedBox(height: 12),
          TigerButton(
            label: 'SCAN TO MEET',
            icon: Icons.qr_code_scanner,
            secondary: true,
            onPressed: _busy || !state.canSpendTime ? null : _openScanner,
          ),
          const Spacer(),
          Text(
            'Same energy as Tip Bar — no codes to type.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontSize: 10),
          ),
        ],
      ),
    );
  }
}

/// Duo Beat via Meet Pad QR.
class DuoBeatSheet extends StatefulWidget {
  const DuoBeatSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.neutral950,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const DuoBeatSheet(),
    );
  }

  @override
  State<DuoBeatSheet> createState() => _DuoBeatSheetState();
}

enum _DuoMode { choose, showPad, scanPad, ready }

class _DuoBeatSheetState extends State<DuoBeatSheet>
    with SingleTickerProviderStateMixin {
  _DuoMode _mode = _DuoMode.choose;
  bool _busy = false;
  String? _error;
  SocialMeet? _meet;
  Timer? _poll;
  late final AnimationController _pulse;
  MobileScannerController? _scanner;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _poll?.cancel();
    _pulse.dispose();
    _scanner?.dispose();
    super.dispose();
  }

  void _startPoll() {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 3), (_) async {
      await context.read<AppState>().refreshActiveMeet();
      if (!mounted) return;
      final meet = context.read<AppState>().activeMeet;
      if (meet != null) {
        setState(() {
          _meet = meet;
          if (meet.isMatched) {
            _mode = _DuoMode.ready;
            _poll?.cancel();
          }
        });
      }
    });
  }

  Future<void> _host() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final (meet, err) = await context.read<AppState>().raiseDuoBeat(minutes: 2);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = err;
      _meet = meet;
      if (meet != null) {
        _mode = _DuoMode.showPad;
        _startPoll();
      }
    });
  }

  void _openScanner() {
    _scanner?.dispose();
    _scanner = MobileScannerController();
    setState(() {
      _mode = _DuoMode.scanPad;
      _error = null;
    });
  }

  Future<void> _onScan(BarcodeCapture capture) async {
    if (_busy || _mode != _DuoMode.scanPad) return;
    for (final b in capture.barcodes) {
      final raw = b.rawValue;
      if (raw == null) continue;
      final pad = MeetPadPayload.tryDecode(raw);
      if (pad == null) continue;
      if (!pad.isFresh) {
        setState(() => _error = 'Meet pad expired — ask them to host again.');
        continue;
      }
      if (pad.kind != MeetKind.duoBeat) {
        setState(() => _error = 'That pad is a Toast — open Toast to Meet.');
        continue;
      }
      setState(() => _busy = true);
      await _scanner?.stop();
      if (!mounted) return;
      final (meet, err) = await context.read<AppState>().joinMeet(pad.code);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = err;
        _meet = meet;
        if (meet != null && meet.isMatched) _mode = _DuoMode.ready;
      });
      if (meet != null && meet.isMatched && mounted) {
        await DuoBeatModal.show(context);
        if (!mounted) return;
        Navigator.pop(context);
      }
      return;
    }
  }

  String get _qrData {
    final meet = _meet;
    final user = context.read<AppState>().user;
    if (meet?.code == null || user == null) return '{}';
    return MeetPadPayload(
      code: meet!.code!,
      hostName: user.name,
      kind: MeetKind.duoBeat,
      timestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    ).encode();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final meet =
        _meet ??
        (state.activeMeet?.kind == MeetKind.duoBeat ? state.activeMeet : null);
    final height = MediaQuery.sizeOf(context).height * 0.88;

    return SizedBox(
      height: height,
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 12,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'DUO BEAT SYNC',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Stake 2 minutes. Show or scan a pad. Race to 8 taps.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontSize: 11),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Expanded(child: _body(state, meet)),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(
                  color: AppColors.tigerOrange,
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _body(AppState state, SocialMeet? meet) {
    if (_mode == _DuoMode.ready && meet != null && meet.isMatched) {
      return FadeSlideIn(
        child: Column(
          children: [
            const Spacer(),
            Text(
              'Matched with ${meet.guestName ?? meet.hostName}',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TigerButton(
              label: 'PLAY NOW',
              icon: Icons.music_note,
              onPressed: () async {
                await DuoBeatModal.show(context);
                if (!mounted) return;
                Navigator.pop(context);
              },
            ),
            const Spacer(),
          ],
        ),
      );
    }
    if (_mode == _DuoMode.showPad && meet?.code != null) {
      return FadeSlideIn(
        child: _ShowPadView(
          qrData: _qrData,
          pulse: _pulse,
          waiting: !meet!.isMatched,
          matchedName: meet.guestName,
          subtitle: 'Challenger scans this pad to duel.',
        ),
      );
    }
    if (_mode == _DuoMode.scanPad) {
      return FadeSlideIn(
        child: _ScanPadView(
          controller: _scanner!,
          busy: _busy,
          onDetect: _onScan,
          onBack: () {
            _scanner?.dispose();
            _scanner = null;
            setState(() => _mode = _DuoMode.choose);
          },
        ),
      );
    }

    return FadeSlideIn(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          TigerButton(
            label: _busy ? '…' : 'HOST DUEL — SHOW PAD (2 MIN)',
            icon: Icons.qr_code_2,
            onPressed: _busy || !state.canSpendTime ? null : _host,
          ),
          const SizedBox(height: 12),
          TigerButton(
            label: 'SCAN TO JOIN DUEL',
            icon: Icons.qr_code_scanner,
            secondary: true,
            onPressed: _busy || !state.canSpendTime ? null : _openScanner,
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

class _ShowPadView extends StatelessWidget {
  const _ShowPadView({
    required this.qrData,
    required this.pulse,
    required this.waiting,
    required this.subtitle,
    this.matchedName,
  });

  final String qrData;
  final AnimationController pulse;
  final bool waiting;
  final String subtitle;
  final String? matchedName;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'YOUR MEET PAD',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 9),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Center(
            child: ScaleTransition(
              scale: Tween(begin: 0.97, end: 1.03).animate(
                CurvedAnimation(parent: pulse, curve: Curves.easeInOut),
              ),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.timerNeon.withValues(alpha: 0.35),
                      blurRadius: 24,
                    ),
                  ],
                ),
                child: QrImageView(
                  data: qrData,
                  size: 220,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
          ),
        ),
        Text(
          waiting ? subtitle : 'Matched with ${matchedName ?? 'guest'}',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 11),
        ),
        if (waiting) ...[
          const SizedBox(height: 8),
          const Text(
            'Waiting for a scan…',
            style: TextStyle(
              color: AppColors.timerNeon,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ],
    );
  }
}

class _ScanPadView extends StatelessWidget {
  const _ScanPadView({
    required this.controller,
    required this.onDetect,
    required this.onBack,
    required this.busy,
  });

  final MobileScannerController controller;
  final void Function(BarcodeCapture) onDetect;
  final VoidCallback onBack;
  final bool busy;

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
                      border: Border.all(color: AppColors.timerNeon, width: 2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                if (busy)
                  const ColoredBox(
                    color: Color(0x88000000),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.timerNeon,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Hold over their Meet Pad',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 11),
        ),
        TextButton(onPressed: onBack, child: const Text('BACK')),
      ],
    );
  }
}

class _IcebreakerView extends StatelessWidget {
  const _IcebreakerView({
    required this.meet,
    required this.busy,
    required this.onComplete,
    this.selfId,
  });

  final SocialMeet meet;
  final String? selfId;
  final bool busy;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final other = meet.hostId == selfId
        ? (meet.guestName ?? 'guest')
        : meet.hostName;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FadeSlideIn(
          child: LuxuryCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ICEBREAKER',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontSize: 9,
                    color: AppColors.goldBright,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  meet.icebreaker,
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(height: 1.35),
                ),
                const SizedBox(height: 12),
                Text(
                  'With $other',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontSize: 10),
                ),
              ],
            ),
          ),
        ),
        const Spacer(),
        if (meet.status != MeetStatus.completed)
          TigerButton(
            label: busy ? '…' : 'WE TALKED — COMPLETE',
            onPressed: busy ? null : onComplete,
          )
        else
          const Text(
            'ICEBREAKER COMPLETE',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.successGreen,
              fontWeight: FontWeight.bold,
            ),
          ),
      ],
    );
  }
}
