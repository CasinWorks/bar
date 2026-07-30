import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/lattice_background.dart';
import '../../models/social_play.dart';
import '../../providers/app_state.dart';
import 'friend_chat_sheet.dart';

class FriendsChatsSheet extends StatefulWidget {
  const FriendsChatsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const FriendsChatsSheet(),
    );
  }

  @override
  State<FriendsChatsSheet> createState() => _FriendsChatsSheetState();
}

class _FriendsChatsSheetState extends State<FriendsChatsSheet> {
  List<FriendProfile> _friends = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final friends = await context.read<AppState>().listMyFriends();
      if (!mounted) return;
      setState(() {
        _friends = friends;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load friends.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LuxuryCard(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.55,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Chats',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _reload,
                      icon: const Icon(Icons.refresh),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const Text(
                  'Pick a friend to open a private chat.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
                const SizedBox(height: 12),
                if (_error != null)
                  Text(
                    _error!,
                    style: const TextStyle(color: AppColors.dangerRed),
                  ),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _friends.isEmpty
                      ? const Center(
                          child: Text(
                            'No friends yet. Add someone first.',
                            style: TextStyle(color: AppColors.textMuted),
                          ),
                        )
                      : ListView.separated(
                          itemCount: _friends.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final friend = _friends[index];
                            return ListTile(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: AppColors.goldBrushed.withValues(
                                    alpha: 0.25,
                                  ),
                                ),
                              ),
                              leading: CircleAvatar(
                                backgroundColor: AppColors.goldBrushed
                                    .withValues(alpha: 0.24),
                                child: Text(
                                  friend.displayName.isNotEmpty
                                      ? friend.displayName[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    color: AppColors.goldBright,
                                  ),
                                ),
                              ),
                              title: Text(friend.displayName),
                              subtitle: Text(
                                friend.isNearby
                                    ? 'Nearby · tap to chat'
                                    : 'Tap to chat',
                                style: const TextStyle(fontSize: 11),
                              ),
                              trailing: const Icon(
                                Icons.chat_bubble_outline,
                                color: AppColors.goldBright,
                              ),
                              onTap: () {
                                final overlay = Navigator.of(
                                  context,
                                ).overlay?.context;
                                Navigator.pop(context);
                                if (overlay != null) {
                                  FriendChatSheet.show(overlay, friend);
                                }
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
