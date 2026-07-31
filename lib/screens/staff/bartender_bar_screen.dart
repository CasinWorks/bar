import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/lattice_background.dart';
import '../../models/drink_order.dart';
import '../../providers/app_state.dart';
import 'bartender_pos_screen.dart';

/// Bartender queue — confirm pours and mark drinks delivered.
class BartenderBarScreen extends StatefulWidget {
  const BartenderBarScreen({super.key});

  @override
  State<BartenderBarScreen> createState() => _BartenderBarScreenState();
}

class _BartenderBarScreenState extends State<BartenderBarScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AppState>().refreshDrinkOrderQueue();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final orders = state.staffPendingDrinkOrders;

    return Scaffold(
      body: LatticeBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.arrow_back,
                        color: AppColors.offWhite,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'BAR QUEUE',
                            style: Theme.of(
                              context,
                            ).textTheme.headlineMedium?.copyWith(fontSize: 18),
                          ),
                          Text(
                            '${orders.length} active order${orders.length == 1 ? '' : 's'}',
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.copyWith(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const BartenderPosScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.point_of_sale, size: 18),
                      label: const Text('POS'),
                    ),
                    if (state.isWalletBusy)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: orders.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.local_bar,
                              size: 48,
                              color: AppColors.textMuted.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No drinks waiting',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Use POS for bar-side orders, or wait for lounge sends',
                              textAlign: TextAlign.center,
                              style: Theme.of(
                                context,
                              ).textTheme.bodyMedium?.copyWith(fontSize: 11),
                            ),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => const BartenderPosScreen(),
                                  ),
                                );
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.crimson,
                              ),
                              child: const Text('START ORDER'),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: orders.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          return _OrderCard(order: orders[index]);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderCard extends StatefulWidget {
  const _OrderCard({required this.order});

  final DrinkOrder order;

  @override
  State<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<_OrderCard> {
  bool _busy = false;

  Future<void> _startPouring() async {
    if (_busy) return;
    setState(() => _busy = true);
    await context.read<AppState>().staffStartPreparingDrink(widget.order.id);
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _serve() async {
    if (_busy) return;
    setState(() => _busy = true);
    final err = await context.read<AppState>().staffFulfillDrinkOrder(
      widget.order.id,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${widget.order.drinkName} served to ${widget.order.memberName}',
          ),
        ),
      );
    }
  }

  Future<void> _cancel() async {
    if (_busy) return;
    setState(() => _busy = true);
    await context.read<AppState>().staffCancelDrinkOrder(widget.order.id);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final preparing = order.status == DrinkOrderStatus.preparing;
    final age = DateTime.now().difference(order.orderedAt);
    final ageLabel = age.inMinutes < 1 ? 'Just now' : '${age.inMinutes}m ago';

    return LuxuryCard(
      highlighted: preparing,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _statusColor(order.status).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _statusColor(order.status)),
                ),
                child: Text(
                  order.status.label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    color: _statusColor(order.status),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                ageLabel,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontSize: 9),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            order.drinkName,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            order.memberName,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.goldBright,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _chargeLine(order),
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontSize: 10),
          ),
          if (order.vipRoomName != null) ...[
            const SizedBox(height: 4),
            Text(
              order.vipRoomName!,
              style: const TextStyle(
                fontSize: 9,
                color: Color(0xFF9B59B6),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              if (order.status == DrinkOrderStatus.pending)
                Expanded(
                  child: TigerButton(
                    label: 'START POURING',
                    icon: Icons.water_drop,
                    secondary: true,
                    isLoading: _busy,
                    onPressed: _busy ? null : _startPouring,
                  ),
                ),
              if (order.status == DrinkOrderStatus.pending)
                const SizedBox(width: 8),
              Expanded(
                child: TigerButton(
                  label: 'SERVE',
                  icon: Icons.check,
                  isLoading: _busy,
                  onPressed: _busy ? null : _serve,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _busy ? null : _cancel,
              child: const Text(
                'Cancel order',
                style: TextStyle(fontSize: 10, color: AppColors.textMuted),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(DrinkOrderStatus status) => switch (status) {
    DrinkOrderStatus.pending => AppColors.goldBright,
    DrinkOrderStatus.preparing => AppColors.tigerOrange,
    DrinkOrderStatus.delivered => AppColors.timerNeon,
    DrinkOrderStatus.cancelled => AppColors.textMuted,
  };

  String _chargeLine(DrinkOrder order) {
    if (order.chargeSource == DrinkChargeSource.cashAtBar) {
      return 'Pay at bar · no time charge';
    }
    if (order.chargeSource == DrinkChargeSource.packageAllowance) {
      return 'Package drink · 1 allowance on serve';
    }
    if (order.costSeconds <= 0) return order.chargeSource.shortLabel;
    return '${order.chargeSource.shortLabel} · −${order.costSeconds ~/ 60} min on serve';
  }
}
