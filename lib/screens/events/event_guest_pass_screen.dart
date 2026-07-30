import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/lattice_background.dart';
import '../../core/widgets/member_entry_qr_card.dart';
import '../../models/event_models.dart';
import '../../models/qr_payload.dart';
import '../../providers/app_state.dart';

/// Night-of guest credential — scannable member entry QR, not an invite code.
class EventGuestPassScreen extends StatefulWidget {
  const EventGuestPassScreen({super.key, required this.invite});

  final EventInvitePreview invite;

  static void open(BuildContext context, EventInvitePreview invite) {
    context.push('/event-pass', extra: invite);
  }

  @override
  State<EventGuestPassScreen> createState() => _EventGuestPassScreenState();
}

class _EventGuestPassScreenState extends State<EventGuestPassScreen> {
  QrPayload? _qr;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _refreshQr();
      _refreshTimer = Timer.periodic(const Duration(seconds: 45), (_) {
        _refreshQr();
      });
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _refreshQr() {
    final payload = context.read<AppState>().createEntryCheckInQr();
    if (!mounted) return;
    setState(() => _qr = payload);
  }

  @override
  Widget build(BuildContext context) {
    final invite = widget.invite;
    final checkedIn = invite.isCheckedIn;
    final qr = _qr;

    return Scaffold(
      appBar: AppBar(title: const Text('Entry QR')),
      body: LatticeBackground(
        animate: true,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            children: [
              Text(
                invite.title,
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 6),
              Text(
                '${invite.eventType.label} · ${invite.branch}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              LuxuryCard(
                highlighted: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          checkedIn
                              ? Icons.check_circle
                              : Icons.qr_code_2_rounded,
                          color: checkedIn
                              ? AppColors.successGreen
                              : AppColors.goldBright,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            checkedIn ? 'CHECKED IN' : 'ENTRY QR',
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: checkedIn
                                      ? AppColors.successGreen
                                      : AppColors.goldBright,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (checkedIn)
                      Text(
                        'Door staff confirmed you for ${invite.hostName}\'s party. '
                        'Show this entry QR again anytime to replay your welcome.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      )
                    else if (qr != null) ...[
                      Text(
                        'Same entry QR as lounge — show it at the door',
                        style: Theme.of(
                          context,
                        ).textTheme.headlineMedium?.copyWith(fontSize: 20),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Staff scan once for venue entry and event check-in. '
                        'Your phone will celebrate the party welcome.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                    // Keep the entry QR after check-in so door staff can
                    // re-scan and migration 035 can replay the welcome.
                    if (qr != null) ...[
                      if (checkedIn) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Re-scan at the door to welcome you again.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                fontSize: 13,
                                color: AppColors.textMuted,
                              ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      MemberEntryQrCard(data: qr.encode()),
                      const SizedBox(height: 12),
                      Text(
                        'QR refreshes every 45 seconds for security.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ] else if (!checkedIn)
                      _NoMemberPassHint(
                        onGetPass: () => context.go('/pricing'),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              LuxuryCard(
                child: Column(
                  children: [
                    _PassDetailRow(
                      icon: Icons.person_outline,
                      label: 'Host',
                      value: invite.hostName,
                    ),
                    _PassDetailRow(
                      icon: Icons.badge_outlined,
                      label: 'Guest',
                      value: invite.guestName,
                    ),
                    _PassDetailRow(
                      icon: Icons.event_outlined,
                      label: 'Date',
                      value: DateFormat('EEEE, MMM d').format(invite.startsAt),
                    ),
                    _PassDetailRow(
                      icon: Icons.schedule,
                      label: 'Time',
                      value: _timeRange(invite),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _timeRange(EventInvitePreview invite) {
    final time = DateFormat('h:mm a');
    final start = time.format(invite.startsAt);
    final end = invite.endsAt != null ? time.format(invite.endsAt!) : null;
    return end == null ? start : '$start to $end';
  }
}

class _NoMemberPassHint extends StatelessWidget {
  const _NoMemberPassHint({required this.onGetPass});

  final VoidCallback onGetPass;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(
          Icons.qr_code_2_outlined,
          color: AppColors.goldBright,
          size: 40,
        ),
        const SizedBox(height: 12),
        Text(
          'Member pass required',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontSize: 20),
        ),
        const SizedBox(height: 8),
        Text(
          'Load time at the club desk to unlock your door QR. '
          'Your guest list spot is saved — bring this pass back once your member pass is active.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontSize: 13,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 16),
        TigerButton(
          label: 'VIEW MEMBER PASS OPTIONS',
          icon: Icons.wallet_outlined,
          secondary: true,
          onPressed: onGetPass,
        ),
      ],
    );
  }
}

class _PassDetailRow extends StatelessWidget {
  const _PassDetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: AppColors.goldBright, size: 18),
          const SizedBox(width: 10),
          SizedBox(
            width: 52,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyLarge),
          ),
        ],
      ),
    );
  }
}
