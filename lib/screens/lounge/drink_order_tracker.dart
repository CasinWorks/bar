import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../models/drink_order.dart';
import '../../providers/app_state.dart';

/// Persistent guest tracker while drinks are waiting at the bar.
class DrinkOrderTracker extends StatelessWidget {
  const DrinkOrderTracker({super.key});

  @override
  Widget build(BuildContext context) {
    final orders = context.watch<AppState>().activeDrinkOrders;
    if (orders.isEmpty) return const SizedBox.shrink();

    return Column(
      children: orders.map((order) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: _TrackerPill(order: order),
        );
      }).toList(),
    );
  }
}

class _TrackerPill extends StatefulWidget {
  const _TrackerPill({required this.order});

  final DrinkOrder order;

  @override
  State<_TrackerPill> createState() => _TrackerPillState();
}

class _TrackerPillState extends State<_TrackerPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final preparing = order.status == DrinkOrderStatus.preparing;
    final accent = preparing ? AppColors.tigerOrange : AppColors.goldBright;

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.08 + _pulse.value * 0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: accent.withValues(alpha: 0.45 + _pulse.value * 0.25),
            ),
          ),
          child: child,
        );
      },
      child: Row(
        children: [
          Icon(
            preparing ? Icons.water_drop : Icons.hourglass_top,
            size: 16,
            color: accent,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.drinkName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
                Text(
                  order.status.label,
                  style: TextStyle(fontSize: 9, color: accent),
                ),
              ],
            ),
          ),
          if (preparing)
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: accent),
            ),
        ],
      ),
    );
  }
}
