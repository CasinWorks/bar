import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/lattice_background.dart';
import '../../data/mock_data.dart';
import '../../models/club_packages.dart';
import '../../models/club_session.dart';
import '../../providers/app_state.dart';
import '../lounge/pass_the_glass_sheet.dart';

/// Package + wallet home — time is your currency.
class PricingScreen extends StatefulWidget {
  const PricingScreen({super.key});

  @override
  State<PricingScreen> createState() => _PricingScreenState();
}

class _PricingScreenState extends State<PricingScreen> {
  Timer? _walletPoll;
  bool _starting = false;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_pullWallet());
      _walletPoll = Timer.periodic(const Duration(seconds: 3), (_) {
        unawaited(_pullWallet(silent: true));
      });
    });
  }

  @override
  void dispose() {
    _walletPoll?.cancel();
    super.dispose();
  }

  Future<void> _pullWallet({bool silent = false}) async {
    final state = context.read<AppState>();
    if (state.sessionPhase != SessionPhase.none &&
        state.sessionPhase != SessionPhase.insideClub) {
      return;
    }
    if (!silent && mounted) setState(() => _refreshing = true);
    await state.refreshWalletFromCloud();
    if (!silent && mounted) setState(() => _refreshing = false);
  }

  Future<void> _enterWithBalance() async {
    if (_starting) return;
    setState(() => _starting = true);
    HapticFeedback.mediumImpact();
    try {
      final state = context.read<AppState>();
      await state.refreshWalletFromCloud();
      final ok = await state.startVisitWithTimeBalance();
      if (!mounted) return;
      if (ok) {
        final phase = state.sessionPhase;
        context.go(phase == SessionPhase.insideClub ? '/lounge' : '/entry');
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final extendingPass = state.sessionPhase == SessionPhase.insideClub;
    final balance = state.timeBalance;
    final hasWallet = balance > 0;
    final loadLabel = state.formatDuration(balance);
    final pkg = ClubPackages.bySlug(state.user?.activePackageSlug);
    final drinksLeft = state.drinksAllowanceRemaining;
    final band = AppColors.timerBand(balance ~/ 60);
    final bandColor = AppColors.timerBandColor(balance ~/ 60);

    return Scaffold(
      appBar: extendingPass
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go('/lounge'),
              ),
              title: const Text('EXTEND YOUR TIME'),
            )
          : null,
      body: LatticeBackground(
        child: SafeArea(
          child: RefreshIndicator(
            color: AppColors.tigerRed,
            onRefresh: () => _pullWallet(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'BLIND TIGER',
                    style: GoogleFonts.raleway(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 4,
                      color: AppColors.tigerRed,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    extendingPass
                        ? 'Extend your time.'
                        : hasWallet
                            ? 'Your time starts now.'
                            : 'TIME IS YOUR CURRENCY',
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                          fontSize: 28,
                          height: 1.1,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    extendingPass
                        ? 'Ask the house to load another package. New minutes land live.'
                        : hasWallet
                            ? 'Wallet ready — check in when you arrive.'
                            : 'Choose a package at the desk. Minutes and drinks credit to your phone.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.textMuted,
                        ),
                  ),
                  const SizedBox(height: 20),
                  if (hasWallet) ...[
                    LuxuryCard(
                      highlighted: true,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 24,
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'WALLET',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              loadLabel,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.raleway(
                                fontSize: 40,
                                fontWeight: FontWeight.w800,
                                height: 1.0,
                                color: bandColor,
                                letterSpacing: 0.5,
                                shadows: AppColors.timerGlow(bandColor),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              band.guestHint,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            if (pkg != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                pkg.name.toUpperCase(),
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(color: AppColors.offWhite),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Text(
                              drinksLeft > 0
                                  ? '$drinksLeft drinks remaining'
                                  : 'No package drinks left — premium available',
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: AppColors.antiqueGold),
                            ),
                            if (_refreshing) ...[
                              const SizedBox(height: 12),
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.tigerRed,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Text(
                    'ENTRY PACKAGES',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 10),
                  ...ClubPackages.all.map((p) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _PackageCard(pkg: p),
                      )),
                  const SizedBox(height: 8),
                  Text(
                    'Guests only notice the meter when it matters — green, yellow, then red.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 11),
                  ),
                  const SizedBox(height: 16),
                  _BranchPicker(state: state),
                  const SizedBox(height: 20),
                  if (hasWallet && !extendingPass) ...[
                    TigerButton(
                      label: state.canSkipDoorQr
                          ? 'ENTER THE CLUB'
                          : 'SHOW ENTRY PASS',
                      icon: state.canSkipDoorQr
                          ? Icons.door_front_door
                          : Icons.qr_code_2_rounded,
                      isLoading: _starting,
                      onPressed: _starting ? null : _enterWithBalance,
                    ),
                    const SizedBox(height: 10),
                    TigerButton(
                      label: 'PASS THE GLASS',
                      icon: Icons.local_bar,
                      secondary: true,
                      onPressed: () => PassTheGlassSheet.show(context),
                    ),
                  ] else if (extendingPass) ...[
                    TigerButton(
                      label: 'BACK TO LOUNGE',
                      icon: Icons.arrow_back,
                      onPressed: () => context.go('/lounge'),
                    ),
                  ] else ...[
                    LuxuryCard(
                      child: Column(
                        children: [
                          const Icon(Icons.storefront, color: AppColors.tigerRed, size: 28),
                          const SizedBox(height: 8),
                          Text(
                            'BUY TIME AT THE DESK',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Tell the house your package. Your phone updates live — pull down to refresh.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Center(
                    child: TextButton(
                      onPressed: () async {
                        await state.logout();
                        if (context.mounted) context.go('/');
                      },
                      child: Text(
                        'Sign out',
                        style: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.8)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PackageCard extends StatelessWidget {
  const _PackageCard({required this.pkg});
  final ClubPackage pkg;

  @override
  Widget build(BuildContext context) {
    return LuxuryCard(
      highlighted: pkg.popular,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      pkg.name.toUpperCase(),
                      style: GoogleFonts.raleway(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                        fontSize: 13,
                        color: AppColors.offWhite,
                      ),
                    ),
                    if (pkg.popular) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.tigerRed.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'MOST GUESTS',
                          style: GoogleFonts.montserrat(
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            color: AppColors.tigerRed,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${pkg.durationLabel} · ${pkg.drinksLabel}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Text(
                  pkg.targetGuest,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 10),
                ),
              ],
            ),
          ),
          Text(
            '₱${pkg.pricePeso}',
            style: GoogleFonts.raleway(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.tigerRed,
            ),
          ),
        ],
      ),
    );
  }
}

class _BranchPicker extends StatelessWidget {
  const _BranchPicker({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('BRANCH', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: MockData.clubBranches.map((b) {
            final selected = state.selectedBranch == b.name;
            return ChoiceChip(
              label: Text(b.name),
              selected: selected,
              onSelected: (_) => state.setSelectedBranch(b.name),
              selectedColor: AppColors.tigerRed.withValues(alpha: 0.35),
              backgroundColor: AppColors.charcoal,
              labelStyle: TextStyle(
                color: selected ? AppColors.offWhite : AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              side: BorderSide(
                color: selected ? AppColors.tigerRed : AppColors.darkSteel,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
