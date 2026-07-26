import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/lattice_background.dart';
import '../../models/social_play.dart';
import '../../providers/app_state.dart';
import 'friend_requests_sheet.dart';

class AddFriendSheet extends StatefulWidget {
  const AddFriendSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddFriendSheet(),
    );
  }

  @override
  State<AddFriendSheet> createState() => _AddFriendSheetState();
}

class _AddFriendSheetState extends State<AddFriendSheet> {
  final _controller = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().searchFriendCandidates('');
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() => _busy = true);
    final error = await context.read<AppState>().searchFriendCandidates(
      _controller.text,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) _snack(error);
  }

  Future<void> _add(FriendProfile profile) async {
    setState(() => _busy = true);
    final error = await context.read<AppState>().sendFriendRequest(profile);
    if (!mounted) return;
    setState(() => _busy = false);
    _snack(error ?? 'Friend request sent to ${profile.displayName}.');
  }

  void _snack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
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
                      'Add Friend',
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
                'Search by name, email, or phone. Nearby only unlocks after both of you accept.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontSize: 11),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _controller,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _search(),
                decoration: const InputDecoration(
                  labelText: 'Search member',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TigerButton(
                      label: _busy ? 'SEARCHING...' : 'SEARCH',
                      icon: Icons.person_search,
                      onPressed: _busy ? null : _search,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TigerButton(
                      label: 'REQUESTS',
                      icon: Icons.inbox,
                      secondary: true,
                      onPressed: () => FriendRequestsSheet.show(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 360),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    if (state.friendSearchResults.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 18),
                        child: Text(
                          'No matches yet. Try a name, email, or phone.',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      )
                    else
                      ...state.friendSearchResults.map(
                        (profile) => _FriendCandidateTile(
                          profile: profile,
                          onAdd: _busy ? null : () => _add(profile),
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

class _FriendCandidateTile extends StatelessWidget {
  const _FriendCandidateTile({required this.profile, required this.onAdd});
  final FriendProfile profile;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: LuxuryCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.goldBrushed.withValues(alpha: 0.24),
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
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    profile.email ?? 'Blind Tiger member',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(onPressed: onAdd, child: const Text('ADD')),
          ],
        ),
      ),
    );
  }
}
