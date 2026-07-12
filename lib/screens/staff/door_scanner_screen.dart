import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/lattice_background.dart';
import '../../models/club_session.dart';
import '../../models/qr_payload.dart';
import '../../providers/app_state.dart';

import 'bartender_tip_pad_screen.dart';

enum _ScannerPhase { scanning, pending, success }

class DoorScannerScreen extends StatefulWidget {
  const DoorScannerScreen({super.key});

  @override
  State<DoorScannerScreen> createState() => _DoorScannerScreenState();
}

class _DoorScannerScreenState extends State<DoorScannerScreen>
    with SingleTickerProviderStateMixin {
  final _codeController = TextEditingController();
  final _scannerController = MobileScannerController();

  late final AnimationController _successAnim;
  late final Animation<double> _successScale;
  late final Animation<double> _successFade;

  _ScannerPhase _phase = _ScannerPhase.scanning;
  QrPayload? _pendingPayload;
  String? _pendingManualLabel;
  String? _lastResult;
  String? _error;

  @override
  void initState() {
    super.initState();
    _successAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _successScale = CurvedAnimation(parent: _successAnim, curve: Curves.elasticOut);
    _successFade = CurvedAnimation(
      parent: _successAnim,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    _scannerController.dispose();
    _successAnim.dispose();
    super.dispose();
  }

  Future<void> _pauseScanner() async {
    await _scannerController.stop();
  }

  Future<void> _resumeScanner() async {
    if (!mounted) return;
    await _scannerController.start();
  }

  void _onQrDetected(BarcodeCapture capture) {
    if (_phase != _ScannerPhase.scanning) return;

    for (final b in capture.barcodes) {
      final raw = b.rawValue;
      if (raw == null) continue;
      final payload = context.read<AppState>().validateScannedQr(raw);
      if (payload == null) continue;

      _pauseScanner();
      setState(() {
        _pendingPayload = payload;
        _pendingManualLabel = null;
        _phase = _ScannerPhase.pending;
        _error = null;
        _lastResult = null;
      });
      return;
    }
  }

  Future<void> _lookupManualCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    final state = context.read<AppState>();
    final session = await state.lookupSessionByCode(code);
    if (!mounted) return;

    if (session == null) {
      setState(() => _error = 'Session code not found.');
      return;
    }

    final purpose = switch (session.phase) {
      SessionPhase.paidAwaitingEntry => QrPurpose.entry,
      SessionPhase.awaitingExitScan => QrPurpose.exit,
      SessionPhase.insideClub => QrPurpose.exit,
      _ => null,
    };

    if (purpose == null) {
      setState(() => _error = 'Guest is not at entry or exit gate.');
      return;
    }

    await _pauseScanner();
    setState(() {
      _pendingPayload = QrPayload(
        userId: session.memberId,
        sessionId: session.id,
        timestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        signature: 'manual',
        purpose: purpose,
        memberName: session.memberName,
      );
      _pendingManualLabel = code.toUpperCase();
      _phase = _ScannerPhase.pending;
      _error = null;
    });
  }

  Future<void> _confirmPending() async {
    final payload = _pendingPayload;
    if (payload == null) return;

    final state = context.read<AppState>();
    final error = await state.staffConfirmScan(payload);

    if (!mounted) return;

    if (error != null) {
      setState(() {
        _error = error;
        _pendingPayload = null;
        _pendingManualLabel = null;
        _phase = _ScannerPhase.scanning;
      });
      await _resumeScanner();
      return;
    }

    final label = payload.purpose == QrPurpose.entry ? 'ENTRY' : 'EXIT';
    setState(() {
      _lastResult = '${payload.memberName} — $label confirmed';
      _pendingPayload = null;
      _pendingManualLabel = null;
      _codeController.clear();
      _phase = _ScannerPhase.success;
      _error = null;
    });
    await _successAnim.forward(from: 0);
  }

  void _cancelPending() {
    setState(() {
      _pendingPayload = null;
      _pendingManualLabel = null;
      _phase = _ScannerPhase.scanning;
      _error = null;
    });
    _resumeScanner();
  }

  void _readyForNextGuest() {
    _successAnim.reset();
    setState(() {
      _lastResult = null;
      _phase = _ScannerPhase.scanning;
      _error = null;
    });
    _resumeScanner();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Door Scanner'),
            if (state.user != null)
              Text(
                state.user!.name,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 11),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.nfc),
            tooltip: 'Tip pad',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const BartenderTipPadScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () async {
              await state.logout();
              if (context.mounted) context.go('/');
            },
          ),
        ],
      ),
      body: LatticeBackground(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: _StatusBanner(phase: _phase),
            ),
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: MobileScanner(
                        controller: _scannerController,
                        onDetect: _onQrDetected,
                      ),
                    ),
                    if (_phase == _ScannerPhase.scanning)
                      IgnorePointer(
                        child: Container(
                          margin: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.goldBrushed, width: 2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    if (_phase == _ScannerPhase.pending && _pendingPayload != null)
                      _PendingOverlay(
                        payload: _pendingPayload!,
                        manualCode: _pendingManualLabel,
                        onConfirm: _confirmPending,
                        onCancel: _cancelPending,
                      ),
                    if (_phase == _ScannerPhase.success)
                      _SuccessOverlay(
                        message: _lastResult ?? 'Confirmed',
                        scale: _successScale,
                        fade: _successFade,
                        onReady: _readyForNextGuest,
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null) ...[
                    Text(_error!, style: const TextStyle(color: AppColors.dangerRed)),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    'Manual session code',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 9),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _codeController,
                          enabled: _phase == _ScannerPhase.scanning,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(hintText: 'XXXXXXXX'),
                          onSubmitted: (_) => _lookupManualCode(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _phase == _ScannerPhase.scanning ? _lookupManualCode : null,
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.crimson),
                        child: const Text('LOOKUP'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.phase});
  final _ScannerPhase phase;

  @override
  Widget build(BuildContext context) {
    final (color, text, icon) = switch (phase) {
      _ScannerPhase.scanning => (
          AppColors.successGreen,
          'Ready — scan any guest QR (entry or exit auto-detected)',
          Icons.qr_code_scanner,
        ),
      _ScannerPhase.pending => (
          AppColors.goldBright,
          'Review guest — confirm or cancel if miscanned',
          Icons.pending_actions,
        ),
      _ScannerPhase.success => (
          AppColors.successGreen,
          'Confirmed — tap button below when ready for next guest',
          Icons.check_circle,
        ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 11, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingOverlay extends StatelessWidget {
  const _PendingOverlay({
    required this.payload,
    required this.onConfirm,
    required this.onCancel,
    this.manualCode,
  });

  final QrPayload payload;
  final String? manualCode;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final isEntry = payload.purpose == QrPurpose.entry;
    final color = isEntry ? AppColors.successGreen : AppColors.tigerOrange;
    final action = isEntry ? 'ENTRY' : 'EXIT';

    return Container(
      color: Colors.black.withValues(alpha: 0.88),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isEntry ? Icons.door_front_door : Icons.logout, color: color, size: 48),
            const SizedBox(height: 12),
            Text(action, style: TextStyle(color: color, fontWeight: FontWeight.w900, letterSpacing: 3, fontSize: 14)),
            const SizedBox(height: 8),
            Text(
              payload.memberName,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            if (manualCode != null)
              Text('Code: $manualCode', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            Text(
              'Confirm this scan is correct',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 11),
            ),
            const SizedBox(height: 24),
            TigerButton(label: 'CONFIRM $action', icon: Icons.check, onPressed: onConfirm),
            const SizedBox(height: 10),
            TigerButton(
              label: 'CANCEL — MISCAN',
              icon: Icons.close,
              secondary: true,
              onPressed: onCancel,
            ),
          ],
        ),
      ),
    );
  }
}

class _SuccessOverlay extends StatelessWidget {
  const _SuccessOverlay({
    required this.message,
    required this.scale,
    required this.fade,
    required this.onReady,
  });

  final String message;
  final Animation<double> scale;
  final Animation<double> fade;
  final VoidCallback onReady;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.88),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FadeTransition(
              opacity: fade,
              child: ScaleTransition(
                scale: scale,
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.successGreen.withValues(alpha: 0.2),
                    border: Border.all(color: AppColors.successGreen, width: 3),
                  ),
                  child: const Icon(Icons.check, color: AppColors.successGreen, size: 48),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'SCAN SUCCESSFUL',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.successGreen,
                    letterSpacing: 2,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            TigerButton(
              label: 'CONFIRM — SCAN NEXT GUEST',
              icon: Icons.qr_code_scanner,
              onPressed: onReady,
            ),
          ],
        ),
      ),
    );
  }
}
