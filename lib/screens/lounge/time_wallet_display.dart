import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/quest_system.dart';

/// Shows Liquid / Banked / Reserved time breakdown.
class TimeWalletDisplay extends StatelessWidget {
  const TimeWalletDisplay({
    super.key,
    required this.snapshot,
    this.compact = false,
  });

  final TimeWalletSnapshot snapshot;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Row(
        children: [
          _MiniPill(
            type: TimeCurrencyType.liquid,
            minutes: snapshot.liquidMinutes,
            live: snapshot.isInsideClub,
          ),
          const SizedBox(width: 6),
          _MiniPill(
            type: TimeCurrencyType.banked,
            minutes: snapshot.bankedMinutes,
          ),
          if (snapshot.reservedMinutes > 0) ...[
            const SizedBox(width: 6),
            _MiniPill(
              type: TimeCurrencyType.reserved,
              minutes: snapshot.reservedMinutes,
            ),
          ],
          if (snapshot.hasActiveVipRoom) ...[
            const SizedBox(width: 6),
            _MiniPill(
              type: TimeCurrencyType.vipRoom,
              minutes: snapshot.vipRoomMinutes,
            ),
          ],
        ],
      );
    }

    return Column(
      children: [
        _TimeRow(
          type: TimeCurrencyType.liquid,
          minutes: snapshot.liquidMinutes,
          live: snapshot.isInsideClub,
        ),
        const SizedBox(height: 6),
        _TimeRow(
          type: TimeCurrencyType.banked,
          minutes: snapshot.bankedMinutes,
        ),
        if (snapshot.reservedMinutes > 0) ...[
          const SizedBox(height: 6),
          _TimeRow(
            type: TimeCurrencyType.reserved,
            minutes: snapshot.reservedMinutes,
          ),
        ],
        if (snapshot.hasActiveVipRoom) ...[
          const SizedBox(height: 6),
          _TimeRow(
            type: TimeCurrencyType.vipRoom,
            minutes: snapshot.vipRoomMinutes,
            subtitleOverride: snapshot.activeVipRoomName,
          ),
        ],
      ],
    );
  }
}

class _MiniPill extends StatelessWidget {
  const _MiniPill({
    required this.type,
    required this.minutes,
    this.live = false,
  });

  final TimeCurrencyType type;
  final int minutes;
  final bool live;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: type.accentColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: type.accentColor.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(type.icon, size: 10, color: type.accentColor),
          const SizedBox(width: 3),
          Text(
            live && type == TimeCurrencyType.liquid
                ? '${minutes}m LIVE'
                : '${minutes}m',
            style: TextStyle(
              fontSize: 7,
              fontWeight: FontWeight.w900,
              color: type.accentColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeRow extends StatelessWidget {
  const _TimeRow({
    required this.type,
    required this.minutes,
    this.live = false,
    this.subtitleOverride,
  });

  final TimeCurrencyType type;
  final int minutes;
  final bool live;
  final String? subtitleOverride;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(type.icon, size: 14, color: type.accentColor),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    type.label.toUpperCase(),
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      color: type.accentColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                  if (live && type == TimeCurrencyType.liquid) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.tigerRed.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: const Text(
                        'LIVE',
                        style: TextStyle(
                          fontSize: 6,
                          fontWeight: FontWeight.w900,
                          color: AppColors.tigerRed,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Text(
                subtitleOverride ?? type.subtitle,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontSize: 8),
              ),
            ],
          ),
        ),
        Text(
          '${minutes}m',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: type.accentColor,
          ),
        ),
      ],
    );
  }
}

/// Three simple rules of the Time Economy.
class TimeEconomyRulesCard extends StatelessWidget {
  const TimeEconomyRulesCard({super.key});

  static const rules = [
    ('Money buys time', Icons.payments),
    ('Time creates reputation', Icons.trending_up),
    ('Reputation unlocks experiences money cannot buy', Icons.auto_awesome),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'THREE SIMPLE RULES',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 8),
        ),
        const SizedBox(height: 6),
        ...rules.asMap().entries.map(
          (e) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Text(
                  '${e.key + 1}.',
                  style: const TextStyle(
                    color: AppColors.goldBright,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(e.value.$2, size: 12, color: AppColors.goldBrushed),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(e.value.$1, style: const TextStyle(fontSize: 10)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
