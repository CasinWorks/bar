import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_logo.dart';
import '../../core/widgets/lattice_background.dart';
import '../../models/club_packages.dart';
import '../../models/club_session.dart';
import '../../providers/app_state.dart';
import '../../services/club_package_service.dart';
import '../auth/member_profile_sheet.dart';
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
  bool _packagesExpanded = false;
  List<ClubPackage> _packages = ClubPackages.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_pullWallet());
      unawaited(_refreshPackages());
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

  Future<void> _refreshPackages() async {
    final packages = await ClubPackageService().listActivePackages();
    if (!mounted) return;
    setState(() => _packages = packages);
  }

  Future<void> _pullWallet({bool silent = false}) async {
    final state = context.read<AppState>();
    if (state.sessionPhase != SessionPhase.none &&
        state.sessionPhase != SessionPhase.insideClub) {
      return;
    }
    if (!silent && mounted) setState(() => _refreshing = true);
    await Future.wait([
      state.refreshWalletFromCloud(),
      if (!silent) _refreshPackages(),
    ]);
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
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not start your visit. Check your time balance and try again.',
            ),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not start your visit: $error')),
      );
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _signOut() async {
    final state = context.read<AppState>();
    await state.logout();
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final extendingPass = state.sessionPhase == SessionPhase.insideClub;
    final balance = state.timeBalance;
    final hasWallet = balance > 0;
    final loadLabel = state.formatDuration(balance);
    final pkg = ClubPackages.bySlug(state.user?.activePackageSlug);
    final drinksLeft = state.drinksAllowanceAvailable;
    final band = AppColors.timerBand(balance ~/ 60);
    final bandColor = AppColors.timerBandColor(balance ~/ 60);
    final firstName = _firstName(state.user?.name);

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
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                _Header(
                  onProfile: extendingPass
                      ? null
                      : () => MemberProfileSheet.show(context),
                  onSignOut: extendingPass ? null : _signOut,
                ),
                const SizedBox(height: 18),
                Text(
                  extendingPass
                      ? 'Extend your time.'
                      : hasWallet
                      ? (firstName != null
                            ? 'Ready, $firstName.'
                            : 'Wallet ready.')
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
                      ? 'Check in when you arrive — your meter starts at the door.'
                      : 'Choose a package at the desk. Minutes and drinks credit to your phone.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: AppColors.textMuted),
                ),
                const SizedBox(height: 22),
                if (hasWallet) ...[
                  _WalletCard(
                    loadLabel: loadLabel,
                    band: band,
                    bandColor: bandColor,
                    packageName: pkg?.name,
                    drinksLeft: drinksLeft,
                    refreshing: _refreshing,
                  ),
                  if (!extendingPass) ...[
                    const SizedBox(height: 18),
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
                    const SizedBox(height: 18),
                    _BranchPicker(state: state),
                    const SizedBox(height: 20),
                    _DeskPackagesSection(
                      packages: _packages,
                      expanded: _packagesExpanded,
                      onToggle: () => setState(
                        () => _packagesExpanded = !_packagesExpanded,
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 18),
                    _DeskPackagesSection(
                      packages: _packages,
                      expanded: true,
                      onToggle: null,
                      title: 'ENTRY PACKAGES',
                      subtitle: 'Tell the desk which load to add.',
                    ),
                    const SizedBox(height: 20),
                    TigerButton(
                      label: 'BACK TO LOUNGE',
                      icon: Icons.arrow_back,
                      onPressed: () => context.go('/lounge'),
                    ),
                  ],
                ] else ...[
                  Text(
                    'ENTRY PACKAGES',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 10),
                  ..._packages.map(
                    (p) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _PackageCard(pkg: p),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Guests only notice the meter when it matters — green, yellow, then red.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(fontSize: 11),
                  ),
                  const SizedBox(height: 16),
                  _BranchPicker(state: state),
                  const SizedBox(height: 20),
                  LuxuryCard(
                    child: Column(
                      children: [
                        const Icon(
                          Icons.storefront,
                          color: AppColors.tigerRed,
                          size: 28,
                        ),
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _firstName(String? fullName) {
    final trimmed = fullName?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed.split(RegExp(r'\s+')).first;
  }
}

class _Header extends StatelessWidget {
  const _Header({this.onProfile, this.onSignOut});

  final VoidCallback? onProfile;
  final VoidCallback? onSignOut;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const AppLogo(size: 32),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'BLIND TIGER',
            style: GoogleFonts.raleway(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 4,
              color: AppColors.tigerRed,
            ),
          ),
        ),
        if (onProfile != null)
          IconButton(
            tooltip: 'Profile',
            onPressed: onProfile,
            icon: Icon(
              Icons.person_outline_rounded,
              size: 22,
              color: AppColors.textMuted.withValues(alpha: 0.95),
            ),
          ),
        if (onSignOut != null)
          IconButton(
            tooltip: 'Sign out',
            onPressed: onSignOut,
            icon: Icon(
              Icons.logout_rounded,
              size: 20,
              color: AppColors.textMuted.withValues(alpha: 0.9),
            ),
          ),
      ],
    );
  }
}

class _WalletCard extends StatelessWidget {
  const _WalletCard({
    required this.loadLabel,
    required this.band,
    required this.bandColor,
    required this.packageName,
    required this.drinksLeft,
    required this.refreshing,
  });

  final String loadLabel;
  final TimerBand band;
  final Color bandColor;
  final String? packageName;
  final int drinksLeft;
  final bool refreshing;

  @override
  Widget build(BuildContext context) {
    return LuxuryCard(
      highlighted: true,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      child: SizedBox(
        width: double.infinity,
        child: Column(
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
                fontSize: 44,
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
            if (packageName != null) ...[
              const SizedBox(height: 10),
              Text(
                packageName!.toUpperCase(),
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: AppColors.offWhite),
              ),
            ],
            const SizedBox(height: 10),
            Text(
              drinksLeft > 0
                  ? '$drinksLeft drinks remaining'
                  : 'No package drinks left — premium available',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.antiqueGold),
            ),
            if (refreshing) ...[
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
    );
  }
}

class _DeskPackagesSection extends StatelessWidget {
  const _DeskPackagesSection({
    required this.packages,
    required this.expanded,
    required this.onToggle,
    this.title = 'DESK MENU',
    this.subtitle = 'Reference only — buy at the house, not in-app.',
  });

  final List<ClubPackage> packages;
  final bool expanded;
  final VoidCallback? onToggle;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: Theme.of(context).textTheme.labelLarge),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onToggle != null)
                  Icon(
                    expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: AppColors.textMuted,
                  ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Column(
              children: packages
                  .map(
                    (p) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _PackageCard(pkg: p),
                    ),
                  )
                  .toList(),
            ),
          ),
          crossFadeState: expanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 220),
        ),
      ],
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
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
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontSize: 10),
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
    final branches = state.availableBranches;
    final selectedBranch =
        branches.any((branch) => branch.name == state.selectedBranch)
        ? state.selectedBranch
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('BRANCH', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        if (branches.isEmpty)
          Text(
            'No branches available right now.',
            style: Theme.of(context).textTheme.bodyMedium,
          )
        else
          DropdownButtonFormField<String>(
            initialValue: selectedBranch,
            isExpanded: true,
            dropdownColor: AppColors.charcoal,
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.charcoal,
              hintText: 'Select a branch',
              hintStyle: TextStyle(
                color: AppColors.textMuted.withValues(alpha: 0.9),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.darkSteel),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.darkSteel),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.tigerRed),
              ),
            ),
            iconEnabledColor: AppColors.offWhite,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.offWhite),
            items: branches
                .map(
                  (branch) => DropdownMenuItem<String>(
                    value: branch.name,
                    child: Text(branch.name),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                state.setSelectedBranch(value);
              }
            },
          ),
      ],
    );
  }
}
