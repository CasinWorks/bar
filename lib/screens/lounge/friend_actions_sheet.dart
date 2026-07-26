import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/lattice_background.dart';
import '../../models/social_play.dart';
import '../../providers/app_state.dart';
import 'add_friend_sheet.dart';
import 'friend_chat_sheet.dart';
import 'insurance_incident_sheet.dart';
import 'ride_assist_sheet.dart';
import 'safety_report_sheet.dart';

class FriendActionsSheet extends StatefulWidget {
  const FriendActionsSheet({super.key, required this.profile});

  final FriendProfile profile;

  static Future<void> show(BuildContext context, FriendProfile profile) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FriendActionsSheet(profile: profile),
    );
  }

  @override
  State<FriendActionsSheet> createState() => _FriendActionsSheetState();
}

class _FriendActionsSheetState extends State<FriendActionsSheet> {
  bool? _isFriend;
  bool _checking = true;

  FriendProfile get profile => widget.profile;

  @override
  void initState() {
    super.initState();
    _loadFriendship();
  }

  Future<void> _loadFriendship() async {
    final ok = await context.read<AppState>().areFriendsWith(profile.memberId);
    if (!mounted) return;
    setState(() {
      _isFriend = ok;
      _checking = false;
    });
  }

  Future<void> _notify(BuildContext context, String message) async {
    if (_isFriend != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add them as a friend first — then you can ping.'),
        ),
      );
      return;
    }
    final error = await context.read<AppState>().notifyFriend(profile, message);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? 'Ping sent to ${profile.displayName}.')),
    );
  }

  Future<void> _block(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Block ${profile.displayName}?'),
        content: const Text(
          'You will disappear from each other’s social surfaces and notifications.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Block'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final error = await context.read<AppState>().blockMember(
      profile.memberId,
      reason: 'member_requested',
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? '${profile.displayName} blocked.')),
    );
    if (error == null) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final friends = _isFriend == true;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LuxuryCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.goldBrushed.withValues(
                      alpha: 0.24,
                    ),
                    child: Text(
                      profile.displayName.isNotEmpty
                          ? profile.displayName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(color: AppColors.goldBright),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.displayName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _checking
                              ? 'Checking friendship…'
                              : friends
                                  ? (profile.vibeTag ?? 'Friend')
                                  : 'Not friends yet — add to ping or chat',
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (_checking)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                )
              else if (friends) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _PingChip(
                      label: "I'm here",
                      onTap: () => _notify(context, "I'm here"),
                    ),
                    _PingChip(
                      label: 'Meet near bar',
                      onTap: () => _notify(context, 'Meet near bar'),
                    ),
                    _PingChip(
                      label: 'Leaving soon',
                      onTap: () => _notify(context, 'Leaving soon'),
                    ),
                    _PingChip(
                      label: 'Need help',
                      danger: true,
                      onTap: () => _notify(context, 'Need help'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TigerButton(
                  label: 'CHAT',
                  icon: Icons.chat_bubble_outline,
                  onPressed: () {
                    final profile = this.profile;
                    final overlay = Navigator.of(context).overlay?.context;
                    Navigator.pop(context);
                    if (overlay != null) {
                      FriendChatSheet.show(overlay, profile);
                    }
                  },
                ),
                const SizedBox(height: 8),
              ] else ...[
                TigerButton(
                  label: 'ADD FRIEND',
                  icon: Icons.person_add_alt_1,
                  onPressed: () {
                    Navigator.pop(context);
                    AddFriendSheet.show(context);
                  },
                ),
                const SizedBox(height: 8),
              ],
              TigerButton(
                label: 'REPORT / STRANGER DANGER',
                icon: Icons.report,
                secondary: true,
                onPressed: () => SafetyReportSheet.show(
                  context,
                  reportedMemberId: profile.memberId,
                  reportedMemberName: profile.displayName,
                ),
              ),
              const SizedBox(height: 8),
              TigerButton(
                label: 'GET A RIDE',
                icon: Icons.local_taxi,
                secondary: true,
                onPressed: () => RideAssistSheet.show(context),
              ),
              const SizedBox(height: 8),
              TigerButton(
                label: 'INSURANCE INCIDENT',
                icon: Icons.health_and_safety,
                secondary: true,
                onPressed: () => InsuranceIncidentSheet.show(context),
              ),
              const SizedBox(height: 8),
              TigerButton(
                label: 'BLOCK',
                icon: Icons.block,
                secondary: true,
                onPressed: () => _block(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PingChip extends StatelessWidget {
  const _PingChip({
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      onPressed: onTap,
      label: Text(label),
      avatar: Icon(
        danger ? Icons.sos : Icons.notifications_active,
        size: 16,
        color: danger ? AppColors.dangerRed : AppColors.goldBright,
      ),
      backgroundColor: danger
          ? AppColors.dangerRed.withValues(alpha: 0.16)
          : AppColors.goldBrushed.withValues(alpha: 0.16),
      labelStyle: const TextStyle(color: AppColors.textLight, fontSize: 11),
      side: BorderSide(
        color: danger
            ? AppColors.dangerRed.withValues(alpha: 0.45)
            : AppColors.goldBrushed.withValues(alpha: 0.35),
      ),
    );
  }
}
