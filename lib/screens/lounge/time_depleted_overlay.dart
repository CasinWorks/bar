import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/lattice_background.dart';
import '../../providers/app_state.dart';

/// Blocks the lounge when time currency is depleted. Pass stays active until exit scan.
class TimeDepletedOverlay extends StatelessWidget {
  const TimeDepletedOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Container(
      color: Colors.black.withValues(alpha: 0.92),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              const Icon(
                Icons.hourglass_disabled,
                color: AppColors.tigerOrange,
                size: 56,
              ),
              const SizedBox(height: 16),
              Text(
                'SOCIALITE PASS REQUIRED',
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Your time currency has run out. Ask the house to load more minutes, or request exit at the door.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Time is currency. It never expires — only spends down.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.goldBright,
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              Text(
                'SEE THE HOUSE FOR MORE TIME',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.goldBright,
                  fontWeight: FontWeight.w900,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Time loads are done at the club — not in the app.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontSize: 10),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              TigerButton(
                label: 'REQUEST EXIT',
                icon: Icons.logout,
                secondary: true,
                onPressed: () async {
                  await state.requestExit();
                  if (context.mounted) context.go('/exit');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
