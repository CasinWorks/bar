import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/animated_time_display.dart';
import '../../core/widgets/lattice_background.dart';
import '../../core/widgets/time_refill_overlay.dart';
import '../../models/staff_tip_received.dart';
import '../../models/tip_pad_payload.dart';
import '../../providers/app_state.dart';
import '../lounge/time_transfer_overlay.dart';

/// Staff tip pad — guest "taps" (scans) this like NFC.
class BartenderTipPadScreen extends StatefulWidget {
  const BartenderTipPadScreen({super.key});

  @override
  State<BartenderTipPadScreen> createState() => _BartenderTipPadScreenState();
}

class _BartenderTipPadScreenState extends State<BartenderTipPadScreen>
    with SingleTickerProviderStateMixin {
  late String _qrData;
  Timer? _refresh;
  late final AnimationController _pulse;
  late final Animation<double> _pulseScale;
  StaffTipReceived? _incomingTip;
  bool _showingOverlay = false;
  AppState? _appState;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseScale = Tween(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
    _qrData = '{}';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshPad();
      _refresh = Timer.periodic(const Duration(seconds: 45), (_) => _refreshPad());
      _appState = context.read<AppState>();
      _appState!.startStaffTipWatch(_onTipReceived);
    });
  }

  Future<void> _onTipReceived(StaffTipReceived tip) async {
    if (!mounted || _showingOverlay || _incomingTip != null) return;

    setState(() => _incomingTip = tip);
  }

  Future<void> _onTransferFinished() async {
    final tip = _incomingTip;
    if (tip == null || !mounted) return;

    setState(() => _incomingTip = null);
    if (_showingOverlay) return;

    _showingOverlay = true;
    await TimeRefillOverlay.show(
      context,
      fromSeconds: tip.fromBalance,
      toSeconds: tip.toBalance,
      title: 'TIP RECEIVED',
      subtitle: tip.guestName != null
          ? '${tip.guestName} poured ${tip.tipMinutes}m to your pad'
          : 'A guest poured ${tip.tipMinutes}m to your pad',
    );
    if (mounted) _showingOverlay = false;
  }

  void _refreshPad() {
    final user = context.read<AppState>().user;
    if (user == null) return;
    setState(() {
      _qrData = TipPadPayload(
        staffId: user.id,
        staffName: user.name,
        timestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      ).encode();
    });
  }

  @override
  void dispose() {
    _appState?.stopStaffTipWatch();
    _refresh?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final name = state.user?.name ?? 'Bartender';
    final tip = _incomingTip;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tip Pad'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          LatticeBackground(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(
                      'HOLD NEAR GUEST PHONE',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            letterSpacing: 2,
                            color: AppColors.goldBright,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Works like NFC — guest opens Tip Bar and scans this pad.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 11),
                      textAlign: TextAlign.center,
                    ),
                    const Spacer(),
                    ScaleTransition(
                      scale: _pulseScale,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: AppColors.goldBrushed, width: 4),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.goldBright.withValues(alpha: 0.35),
                              blurRadius: 40,
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Text(
                              'TIP · $name'.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 12),
                            QrImageView(
                              data: _qrData,
                              version: QrVersions.auto,
                              size: 240,
                              backgroundColor: Colors.white,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'NFC TIP PAD',
                              style: TextStyle(
                                color: AppColors.crimson,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    LuxuryCard(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          const Icon(Icons.account_balance_wallet, color: AppColors.timerNeon),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'TIPS RECEIVED',
                                  style: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 9),
                                ),
                                AnimatedTimeDisplay(
                                  seconds: state.timeBalance,
                                  color: AppColors.timerNeon,
                                  fontSize: 18,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (tip != null)
            TimeTransferOverlay(
              minutes: tip.tipMinutes,
              fromLabel: tip.guestName ?? 'Guest',
              toLabel: name,
              title: 'TIP RECEIVED · INCOMING',
              onFinished: _onTransferFinished,
            ),
        ],
      ),
    );
  }
}
