import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/lattice_background.dart';
import '../../models/blind_tiger_models.dart';
import '../../models/drink_catalog.dart';
import '../../models/drink_pay_payload.dart';
import '../../providers/app_state.dart';
import '../../services/drink_catalog_service.dart';
import '../../services/drink_pos_service.dart';

/// Bartender POS — Start Order → large drink tiles → qty → payment QR.
class BartenderPosScreen extends StatefulWidget {
  const BartenderPosScreen({super.key});

  @override
  State<BartenderPosScreen> createState() => _BartenderPosScreenState();
}

enum _PosPhase { catalog, payment, paid }

class _BartenderPosScreenState extends State<BartenderPosScreen> {
  final Map<String, int> _qtyBySlug = {};
  _PosPhase _phase = _PosPhase.catalog;
  bool _loadingMenu = true;
  bool _busy = false;
  String? _error;
  DrinkPosTicket? _ticket;
  DrinkPayPayload? _payload;
  RealtimeChannel? _ticketWatch;
  List<Drink> _drinks = DrinkCatalog.active;

  @override
  void initState() {
    super.initState();
    _loadMenu();
  }

  Future<void> _loadMenu() async {
    final drinks = await DrinkCatalogService().listActiveDrinks();
    if (!mounted) return;
    setState(() {
      _drinks = drinks;
      _loadingMenu = false;
    });
  }

  int get _totalItems => _qtyBySlug.values.fold(0, (a, b) => a + b);

  int get _previewSeconds {
    var total = 0;
    for (final drink in _drinks) {
      final qty = _qtyBySlug[drink.slug] ?? 0;
      if (qty <= 0) continue;
      if (drink.isPremium || drink.timeCostSeconds > 0) {
        total += drink.timeCostSeconds * qty;
      }
    }
    return total;
  }

  void _bump(Drink drink, int delta) {
    final next = (_qtyBySlug[drink.slug] ?? 0) + delta;
    setState(() {
      if (next <= 0) {
        _qtyBySlug.remove(drink.slug);
      } else {
        _qtyBySlug[drink.slug] = next.clamp(1, 20);
      }
      _error = null;
    });
  }

  List<DrinkPosCartLine> _cartLines() {
    final lines = <DrinkPosCartLine>[];
    for (final drink in _drinks) {
      final qty = _qtyBySlug[drink.slug] ?? 0;
      if (qty > 0) lines.add(DrinkPosCartLine(drink: drink, quantity: qty));
    }
    return lines;
  }

  Future<void> _startPayment() async {
    if (_busy || _totalItems == 0) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final state = context.read<AppState>();
    final (ticket, payload, err) = await state.staffCreateDrinkPosTicket(
      _cartLines(),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null || ticket == null || payload == null) {
      setState(() => _error = err ?? 'Could not start payment.');
      return;
    }

    await _ticketWatch?.unsubscribe();
    _ticketWatch = state.watchDrinkPosTicket(
      ticketId: ticket.id,
      onUpdate: (updated) {
        if (!mounted) return;
        if (updated.isPaid) {
          setState(() {
            _ticket = updated;
            _phase = _PosPhase.paid;
          });
        }
      },
    );

    setState(() {
      _ticket = ticket;
      _payload = payload;
      _phase = _PosPhase.payment;
    });
  }

  Future<void> _cancelPayment() async {
    final ticket = _ticket;
    if (ticket != null) {
      await context.read<AppState>().staffCancelDrinkPosTicket(ticket.id);
    }
    await _ticketWatch?.unsubscribe();
    _ticketWatch = null;
    if (!mounted) return;
    setState(() {
      _phase = _PosPhase.catalog;
      _ticket = null;
      _payload = null;
      _error = null;
    });
  }

  void _newOrder() {
    _ticketWatch?.unsubscribe();
    _ticketWatch = null;
    setState(() {
      _qtyBySlug.clear();
      _phase = _PosPhase.catalog;
      _ticket = null;
      _payload = null;
      _error = null;
    });
  }

  @override
  void dispose() {
    _ticketWatch?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LatticeBackground(
        child: SafeArea(
          child: switch (_phase) {
            _PosPhase.catalog => _buildCatalog(context),
            _PosPhase.payment => _buildPayment(context),
            _PosPhase.paid => _buildPaid(context),
          },
        ),
      ),
    );
  }

  Widget _buildCatalog(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 16, 8),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: AppColors.offWhite),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BAR POS',
                      style: Theme.of(
                        context,
                      ).textTheme.headlineMedium?.copyWith(fontSize: 18),
                    ),
                    Text(
                      _totalItems == 0
                          ? 'Start order · pick drinks'
                          : '$_totalItems item${_totalItems == 1 ? '' : 's'}'
                                '${_previewSeconds > 0 ? ' · ~${_previewSeconds ~/ 60}m time' : ''}',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _error!,
              style: const TextStyle(color: AppColors.crimson, fontSize: 12),
            ),
          ),
        Expanded(
          child: _loadingMenu
              ? const Center(child: CircularProgressIndicator())
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.92,
                  ),
                  itemCount: _drinks.length,
                  itemBuilder: (context, index) {
                    final drink = _drinks[index];
                    final qty = _qtyBySlug[drink.slug] ?? 0;
                    return _DrinkPosTile(
                      drink: drink,
                      quantity: qty,
                      onAdd: () => _bump(drink, 1),
                      onRemove: () => _bump(drink, -1),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SizedBox(
            height: 56,
            child: FilledButton(
              onPressed: _totalItems == 0 || _busy ? null : _startPayment,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.crimson,
                disabledBackgroundColor: AppColors.darkSteel,
              ),
              child: Text(
                _busy
                    ? 'CREATING…'
                    : _totalItems == 0
                    ? 'START ORDER'
                    : 'CHARGE · $_totalItems  →  SHOW QR',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPayment(BuildContext context) {
    final payload = _payload;
    final ticket = _ticket;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              TextButton(
                onPressed: _cancelPayment,
                child: const Text('Cancel order'),
              ),
              const Spacer(),
              Text(
                'AWAITING SCAN',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.antiqueGold,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            'Guest scans to pay',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${ticket?.lineCount ?? _totalItems} drink${(ticket?.lineCount ?? _totalItems) == 1 ? '' : 's'}'
            '${_previewSeconds > 0 ? ' · up to ${_previewSeconds ~/ 60}m' : ''}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: QrImageView(
              data: payload?.encode() ?? '{}',
              size: 240,
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Hold for the guest camera · expires in 10 minutes',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: 12,
              color: AppColors.textMuted,
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildPaid(BuildContext context) {
    final ticket = _ticket;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Spacer(),
          const Icon(Icons.check_circle, color: Color(0xFF2ECC71), size: 72),
          const SizedBox(height: 16),
          Text(
            'PAID',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontSize: 28,
              color: const Color(0xFF2ECC71),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            ticket?.paidByMemberName != null
                ? '${ticket!.paidByMemberName} · pour it'
                : 'Guest paid · pour it',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if ((ticket?.chargedSeconds ?? 0) > 0) ...[
            const SizedBox(height: 6),
            Text(
              '−${ticket!.chargedSeconds ~/ 60} min from their wallet',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.antiqueGold,
              ),
            ),
          ],
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: _newOrder,
              style: FilledButton.styleFrom(backgroundColor: AppColors.crimson),
              child: const Text(
                'NEW ORDER',
                style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _posPriceLabel(Drink drink) {
  final parts = <String>[];
  if (drink.price.isNotEmpty &&
      drink.price != '—' &&
      drink.price != 'Included') {
    parts.add(drink.price);
  }
  if (drink.isStandard && drink.timeCostSeconds <= 0) {
    parts.add('Package');
  } else if (drink.timeCostSeconds > 0) {
    parts.add('−${drink.timeCostSeconds ~/ 60}m');
  }
  if (parts.isEmpty) return drink.isStandard ? 'Package drink' : '—';
  return parts.toSet().join(' · ');
}

class _DrinkPosTile extends StatelessWidget {
  const _DrinkPosTile({
    required this.drink,
    required this.quantity,
    required this.onAdd,
    required this.onRemove,
  });

  final Drink drink;
  final int quantity;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final selected = quantity > 0;
    return Material(
      color: selected ? AppColors.crimson.withValues(alpha: 0.18) : AppColors.neutral900,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onAdd,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? AppColors.crimson
                  : AppColors.antiqueGold.withValues(alpha: 0.25),
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      drink.badge ?? (drink.isStandard ? 'PACKAGE' : 'PREMIUM'),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                        color: drink.isStandard ? AppColors.antiqueGold : AppColors.crimson,
                      ),
                    ),
                  ),
                  if (selected)
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: AppColors.crimson,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$quantity',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ),
                ],
              ),
              const Spacer(),
              Text(
                drink.name,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _posPriceLabel(drink),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _QtyChip(icon: Icons.remove, onTap: quantity > 0 ? onRemove : null),
                  const SizedBox(width: 8),
                  _QtyChip(icon: Icons.add, onTap: onAdd),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QtyChip extends StatelessWidget {
  const _QtyChip({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 36,
        height: 32,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.antiqueGold.withValues(alpha: 0.35)),
        ),
        child: Icon(
          icon,
          size: 18,
          color: onTap == null ? AppColors.textMuted : AppColors.offWhite,
        ),
      ),
    );
  }
}
