import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/lattice_background.dart';
import '../../models/drink_pay_payload.dart';
import '../../providers/app_state.dart';

/// Guest flow: scan bartender POS payment QR → wallet settles → delivery overlay.
class PayBarSheet extends StatefulWidget {
  const PayBarSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.neutral950,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const PayBarSheet(),
    );
  }

  @override
  State<PayBarSheet> createState() => _PayBarSheetState();
}

class _PayBarSheetState extends State<PayBarSheet> {
  final _scanner = MobileScannerController();
  bool _busy = false;
  String? _error;
  bool _done = false;

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_busy || _done) return;
    for (final b in capture.barcodes) {
      final raw = b.rawValue;
      if (raw == null) continue;
      final payload = DrinkPayPayload.tryDecode(raw);
      if (payload == null) continue;

      final state = context.read<AppState>();
      setState(() {
        _busy = true;
        _error = null;
      });
      await _scanner.stop();

      final (result, err) = await state.payDrinkPosTicket(payload);
      if (!mounted) return;

      if (err != null || result == null) {
        setState(() {
          _busy = false;
          _error = err ?? 'Payment failed';
        });
        await _scanner.start();
        return;
      }

      setState(() {
        _busy = false;
        _done = true;
      });
      Navigator.pop(context);
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final inside = context.watch<AppState>().isInsideClub;

    return LatticeBackground(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.textMuted.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              'PAY AT THE BAR',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              inside
                  ? 'Scan the bartender’s payment QR to buy your drinks with time.'
                  : 'Scan in at the door before you can pay at the bar.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 16),
            if (!inside)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Icon(Icons.lock_outline, size: 48, color: AppColors.textMuted),
              )
            else
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      MobileScanner(
                        controller: _scanner,
                        onDetect: _onDetect,
                      ),
                      if (_busy)
                        Container(
                          color: Colors.black54,
                          alignment: Alignment.center,
                          child: const CircularProgressIndicator(),
                        ),
                    ],
                  ),
                ),
              ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.crimson, fontSize: 12),
              ),
            ],
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
}
