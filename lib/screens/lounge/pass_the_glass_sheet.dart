import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/lattice_background.dart';
import '../../models/time_gift.dart';
import '../../providers/app_state.dart';
import '../../services/time_gift_service.dart';
import 'tip_bartender_sheet.dart';

enum _GlassTab { raise, tip, claim, bartender }

class PassTheGlassSheet extends StatefulWidget {
  const PassTheGlassSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.neutral950,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const PassTheGlassSheet(),
    );
  }

  @override
  State<PassTheGlassSheet> createState() => _PassTheGlassSheetState();
}

class _PassTheGlassSheetState extends State<PassTheGlassSheet> {
  _GlassTab _tab = _GlassTab.raise;
  GlassPour _toastPour = GlassPours.toast[1];
  GlassPour _tipPour = GlassPours.tips[0];
  final _messageController = TextEditingController();
  final _codeController = TextEditingController();
  bool _busy = false;
  String? _error;
  TimeGift? _raised;

  @override
  void dispose() {
    _messageController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _raise() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final state = context.read<AppState>();
    final (gift, err) = await state.raiseToast(
      minutes: _toastPour.minutes,
      message: _messageController.text.trim().isEmpty
          ? null
          : _messageController.text.trim(),
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = err;
      _raised = gift;
    });
  }

  Future<void> _tip() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final state = context.read<AppState>();
    final (gift, err) = await state.tipTheHouse(
      minutes: _tipPour.minutes,
      message: _messageController.text.trim().isEmpty
          ? null
          : _messageController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'You tipped the house ${_tipPour.minutes}m${gift?.message != null ? ' — "${gift!.message}"' : ''}. Cheers.',
        ),
      ),
    );
  }

  Future<void> _claim() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Enter a glass code like GLASS-A1B2');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final state = context.read<AppState>();
    final (gift, err) = await state.claimToast(code);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Caught ${gift!.minutes}m from ${gift.fromMemberName}. Time is on your account.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final spendable = state.ownedTimeSeconds;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.92,
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 24,
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
            const SizedBox(height: 16),
            Text(
              'PASS THE GLASS',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 18),
            ),
            Text(
              'Time is social currency — raise a toast, tip the house, or claim a glass.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 11),
            ),
            const SizedBox(height: 8),
            Text(
              'Spendable: ${state.formatDuration(spendable)}',
              style: const TextStyle(
                color: AppColors.successGreen,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _TabChip(
                  label: 'RAISE',
                  selected: _tab == _GlassTab.raise,
                  onTap: () => setState(() {
                    _tab = _GlassTab.raise;
                    _error = null;
                    _raised = null;
                  }),
                ),
                _TabChip(
                  label: 'HOUSE',
                  selected: _tab == _GlassTab.tip,
                  onTap: () => setState(() {
                    _tab = _GlassTab.tip;
                    _error = null;
                    _raised = null;
                  }),
                ),
                _TabChip(
                  label: 'CLAIM',
                  selected: _tab == _GlassTab.claim,
                  onTap: () => setState(() {
                    _tab = _GlassTab.claim;
                    _error = null;
                    _raised = null;
                  }),
                ),
                _TabChip(
                  label: 'NFC TIP',
                  selected: _tab == _GlassTab.bartender,
                  onTap: () {
                    Navigator.pop(context);
                    TipBartenderSheet.show(context);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_raised != null) _RaisedCodeCard(gift: _raised!) else ...[
              if (_tab == _GlassTab.raise) ...[
                Text(
                  'RAISE A TOAST',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 9),
                ),
                const SizedBox(height: 4),
                Text(
                  'Lock minutes into a glass code. Read it to a friend — they claim it and stay longer.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 10),
                ),
                const SizedBox(height: 12),
                ...GlassPours.toast.map(
                  (p) => _PourTile(
                    pour: p,
                    selected: _toastPour.id == p.id,
                    onTap: () => setState(() => _toastPour = p),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _messageController,
                  maxLength: 60,
                  decoration: const InputDecoration(
                    hintText: 'Optional note — "On me, keep dancing"',
                  ),
                ),
                if (_error != null) ...[
                  Text(_error!, style: const TextStyle(color: AppColors.dangerRed, fontSize: 11)),
                  const SizedBox(height: 8),
                ],
                TigerButton(
                  label: 'RAISE ${_toastPour.minutes}M TOAST',
                  icon: Icons.local_bar,
                  isLoading: _busy,
                  onPressed: _busy ? null : _raise,
                ),
              ],
              if (_tab == _GlassTab.tip) ...[
                Text(
                  'TIP THE HOUSE',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 9),
                ),
                const SizedBox(height: 4),
                Text(
                  'Thank bartenders & staff with minutes from your night. It burns bright — social status, not a receipt.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 10),
                ),
                const SizedBox(height: 12),
                ...GlassPours.tips.map(
                  (p) => _PourTile(
                    pour: p,
                    selected: _tipPour.id == p.id,
                    onTap: () => setState(() => _tipPour = p),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _messageController,
                  maxLength: 60,
                  decoration: const InputDecoration(
                    hintText: 'Optional — "Best Old Fashioned of my life"',
                  ),
                ),
                if (_error != null) ...[
                  Text(_error!, style: const TextStyle(color: AppColors.dangerRed, fontSize: 11)),
                  const SizedBox(height: 8),
                ],
                TigerButton(
                  label: 'TIP ${_tipPour.minutes}M TO THE HOUSE',
                  icon: Icons.favorite,
                  isLoading: _busy,
                  onPressed: _busy ? null : _tip,
                ),
              ],
              if (_tab == _GlassTab.claim) ...[
                Text(
                  'CLAIM A GLASS',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 9),
                ),
                const SizedBox(height: 4),
                Text(
                  'Someone raised a toast for you. Enter the code they shared — minutes refill your account.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 10),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _codeController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    hintText: 'GLASS-XXXX',
                    prefixIcon: Icon(Icons.qr_code_2),
                  ),
                ),
                const SizedBox(height: 12),
                if (_error != null) ...[
                  Text(_error!, style: const TextStyle(color: AppColors.dangerRed, fontSize: 11)),
                  const SizedBox(height: 8),
                ],
                TigerButton(
                  label: 'CLAIM TOAST',
                  icon: Icons.celebration,
                  isLoading: _busy,
                  onPressed: _busy ? null : _claim,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: selected ? AppColors.goldBrushed : AppColors.neutral900,
                ),
                color: selected
                    ? AppColors.goldBrushed.withValues(alpha: 0.15)
                    : Colors.transparent,
              ),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                  color: selected ? AppColors.goldBright : AppColors.neutral500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PourTile extends StatelessWidget {
  const _PourTile({
    required this.pour,
    required this.selected,
    required this.onTap,
  });

  final GlassPour pour;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: LuxuryCard(
            highlighted: selected,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${pour.minutes} MIN · ${pour.label}',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                      ),
                      Text(
                        pour.tagline,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 10),
                      ),
                    ],
                  ),
                ),
                Icon(
                  selected ? Icons.check_circle : Icons.circle_outlined,
                  color: selected ? AppColors.goldBrushed : AppColors.neutral500,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RaisedCodeCard extends StatelessWidget {
  const _RaisedCodeCard({required this.gift});

  final TimeGift gift;

  @override
  Widget build(BuildContext context) {
    final code = gift.code ?? '—';
    return LuxuryCard(
      highlighted: true,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Icon(Icons.local_bar, color: AppColors.goldBright, size: 40),
          const SizedBox(height: 12),
          Text(
            'TOAST RAISED',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.successGreen,
                  letterSpacing: 2,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '${gift.minutes} minutes locked in this glass',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          SelectableText(
            code,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
              color: AppColors.goldBright,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Whisper or flash this code — once claimed, it\'s gone.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 10),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          TigerButton(
            label: 'COPY CODE',
            icon: Icons.copy,
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: code));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Glass code copied')),
                );
              }
            },
          ),
          const SizedBox(height: 8),
          TigerButton(
            label: 'DONE',
            secondary: true,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}
