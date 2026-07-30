import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/lattice_background.dart';
import '../../models/social_play.dart';
import '../../providers/app_state.dart';
import '../../services/safety_social_service.dart';

class FriendChatSheet extends StatefulWidget {
  const FriendChatSheet({super.key, required this.profile});

  final FriendProfile profile;

  static Future<void> show(BuildContext context, FriendProfile profile) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FriendChatSheet(profile: profile),
    );
  }

  @override
  State<FriendChatSheet> createState() => _FriendChatSheetState();
}

class _FriendChatSheetState extends State<FriendChatSheet> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  List<FriendMessage> _messages = [];
  bool _loading = true;
  bool _sending = false;
  String? _error;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _reload();
      _poll = Timer.periodic(
        const Duration(seconds: 4),
        (_) => _reload(silent: true),
      );
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _reload({bool silent = false}) async {
    if (!mounted) return;
    if (!silent) setState(() => _loading = true);
    try {
      final messages = await context.read<AppState>().loadFriendChat(
        widget.profile.memberId,
      );
      if (!mounted) return;
      final jumped = messages.length != _messages.length;
      setState(() {
        _messages = messages;
        _loading = false;
        if (!silent) _error = null;
      });
      if (jumped) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_scroll.hasClients) return;
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
        });
      }
    } on SafetySocialException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
        // Still allow composing if the thread is empty / first open.
        if (_messages.isEmpty) _messages = const [];
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load chat. Pull to retry.';
      });
    }
  }

  Future<void> _send() async {
    final body = _controller.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    final error = await context.read<AppState>().sendFriendChatMessage(
      widget.profile.memberId,
      body,
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    _controller.clear();
    await _reload(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    final selfId = context.watch<AppState>().user?.id;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: LuxuryCard(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.62,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Chat · ${widget.profile.displayName}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => _reload(),
                        icon: const Icon(Icons.refresh),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          color: AppColors.dangerRed,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  Expanded(
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : _messages.isEmpty
                        ? const Center(
                            child: Text(
                              'Say hello — private between friends.',
                              style: TextStyle(color: AppColors.textMuted),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : ListView.builder(
                            controller: _scroll,
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              final msg = _messages[index];
                              final mine = msg.senderId == selfId;
                              return Align(
                                alignment: mine
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  constraints: BoxConstraints(
                                    maxWidth:
                                        MediaQuery.sizeOf(context).width * 0.68,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    color: mine
                                        ? AppColors.goldBrushed.withValues(
                                            alpha: 0.28,
                                          )
                                        : const Color(0xFF24160C),
                                    border: Border.all(
                                      color: AppColors.goldBrushed.withValues(
                                        alpha: 0.25,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    msg.body,
                                    style: const TextStyle(
                                      color: AppColors.textLight,
                                      fontSize: 13,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          decoration: const InputDecoration(
                            hintText: 'Message…',
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: _sending ? null : _send,
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.goldBrushed,
                          foregroundColor: const Color(0xFF120A00),
                        ),
                        icon: _sending
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send_rounded),
                      ),
                    ],
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
