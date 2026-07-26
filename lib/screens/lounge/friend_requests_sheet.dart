import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/lattice_background.dart';
import '../../models/social_play.dart';
import '../../providers/app_state.dart';

class FriendRequestsSheet extends StatefulWidget {
  const FriendRequestsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const FriendRequestsSheet(),
    );
  }

  @override
  State<FriendRequestsSheet> createState() => _FriendRequestsSheetState();
}

class _FriendRequestsSheetState extends State<FriendRequestsSheet> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().refreshFriendRequests();
    });
  }

  Future<void> _accept(FriendRequest request) async {
    setState(() => _busy = true);
    final error = await context.read<AppState>().acceptFriendRequest(request);
    if (!mounted) return;
    setState(() => _busy = false);
    _snack(error ?? 'Friend request accepted.');
  }

  Future<void> _decline(FriendRequest request) async {
    setState(() => _busy = true);
    final error = await context.read<AppState>().declineFriendRequest(request);
    if (!mounted) return;
    setState(() => _busy = false);
    _snack(error ?? 'Friend request declined.');
  }

  void _snack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final pending = state.friendRequests
        .where((r) => r.status == FriendRequestStatus.pending)
        .toList();

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
                  const Expanded(
                    child: Text(
                      'Friend Requests',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Text(
                'Only accepted mutual friends can appear nearby.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontSize: 11),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 420),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    if (pending.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 18),
                        child: Text(
                          'No pending requests.',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      )
                    else
                      ...pending.map(
                        (request) => _RequestTile(
                          request: request,
                          busy: _busy,
                          onAccept: () => _accept(request),
                          onDecline: () => _decline(request),
                        ),
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
}

class _RequestTile extends StatelessWidget {
  const _RequestTile({
    required this.request,
    required this.busy,
    required this.onAccept,
    required this.onDecline,
  });

  final FriendRequest request;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final isInbound = request.direction == 'inbound';
    final name = isInbound ? request.requesterName : request.recipientName;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: LuxuryCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(
              isInbound ? 'Wants to add you' : 'Waiting for acceptance',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
            if (isInbound) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TigerButton(
                      label: 'ACCEPT',
                      icon: Icons.check,
                      onPressed: busy ? null : onAccept,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TigerButton(
                      label: 'DECLINE',
                      icon: Icons.close,
                      secondary: true,
                      onPressed: busy ? null : onDecline,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
