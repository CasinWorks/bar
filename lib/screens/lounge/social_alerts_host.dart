import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../models/social_play.dart';
import '../../models/time_low_alert.dart';
import '../../providers/app_state.dart';
import '../../router/app_router.dart';
import 'friend_chat_sheet.dart';
import 'friend_requests_sheet.dart';

/// App-wide overlays — private alerts as a compact top banner (island / pill).
/// Never posts private friend/chat activity into the public lounge feed.
/// Does not block navigation or lounge chrome while visible.
class SocialAlertsHost extends StatefulWidget {
  const SocialAlertsHost({super.key, required this.child});

  final Widget child;

  @override
  State<SocialAlertsHost> createState() => _SocialAlertsHostState();
}

class _SocialAlertsHostState extends State<SocialAlertsHost>
    with SingleTickerProviderStateMixin {
  String? _showingRequestId;
  String? _showingPingId;
  String? _showingTimeLowId;
  _BannerPayload? _banner;
  bool _dismissing = false;
  Timer? _autoDismiss;
  late final AnimationController _enter;

  static const _autoDismissDuration = Duration(milliseconds: 4500);
  static const _timerAutoDismissDuration = Duration(milliseconds: 5500);

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
  }

  @override
  void dispose() {
    _autoDismiss?.cancel();
    _enter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, app, _) {
        // Schedule after this frame — never mark “shown” until present succeeds.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _tryPresentNext(app);
        });

        return Stack(
          children: [
            widget.child,
            if (_banner != null)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, -1.15),
                          end: Offset.zero,
                        ).animate(
                          CurvedAnimation(
                            parent: _enter,
                            curve: Curves.easeOutCubic,
                          ),
                        ),
                        child: FadeTransition(
                          opacity: _enter,
                          child: _IslandBanner(
                            payload: _banner!,
                            onTap: () => _onBannerTap(app),
                            onSwipeDismiss: () => _dismissBanner(
                              app,
                              opened: false,
                              animated: false,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _tryPresentNext(AppState app) {
    if (!mounted || _banner != null || _dismissing) return;

    // Social first — timer waits so friend/chat delivery stays intact.
    final request = app.pendingRequestAlert;
    if (request != null && request.id != _showingRequestId) {
      _presentRequest(app, request);
      return;
    }

    final ping = app.pendingPingAlert;
    if (ping != null && ping.id != _showingPingId) {
      _presentPing(app, ping);
      return;
    }

    final timeLow = app.pendingTimeLowAlert;
    if (timeLow != null && timeLow.id != _showingTimeLowId) {
      _presentTimeLow(app, timeLow);
    }
  }

  void _presentRequest(AppState app, FriendRequest request) {
    HapticFeedback.mediumImpact();
    _dismissing = false;
    _showingRequestId = request.id;
    setState(() {
      _banner = _BannerPayload.request(request);
    });
    _enter.forward(from: 0);
    _armAutoDismiss(app);
  }

  void _presentPing(AppState app, FriendPing ping) {
    HapticFeedback.mediumImpact();
    _dismissing = false;
    _showingPingId = ping.id;
    setState(() {
      _banner = _BannerPayload.ping(ping);
    });
    _enter.forward(from: 0);
    _armAutoDismiss(app);
  }

  void _presentTimeLow(AppState app, TimeLowAlert alert) {
    HapticFeedback.mediumImpact();
    _dismissing = false;
    _showingTimeLowId = alert.id;
    setState(() {
      _banner = _BannerPayload.timeLow(alert);
    });
    _enter.forward(from: 0);
    _armAutoDismiss(app, duration: _timerAutoDismissDuration);
  }

  void _armAutoDismiss(
    AppState app, {
    Duration duration = _autoDismissDuration,
  }) {
    _autoDismiss?.cancel();
    _autoDismiss = Timer(duration, () {
      if (!mounted || _banner == null || _dismissing) return;
      _dismissBanner(app, opened: false);
    });
  }

  Future<void> _onBannerTap(AppState app) async {
    final payload = _banner;
    if (payload == null || _dismissing) return;
    await _dismissBanner(app, opened: true);

    // Host sits above the navigator (MaterialApp.builder) — use the router key.
    final navContext = AppRouter.navigatorKey.currentContext;
    if (navContext == null || !navContext.mounted) return;

    if (payload.request != null) {
      FriendRequestsSheet.show(navContext);
      return;
    }
    final ping = payload.ping;
    if (ping != null) {
      final name = ping.senderName ?? 'Friend';
      FriendChatSheet.show(
        navContext,
        FriendProfile(memberId: ping.senderId, displayName: name),
      );
      return;
    }
    if (payload.timeLow != null) {
      GoRouter.of(navContext).go('/pricing');
    }
  }

  Future<void> _dismissBanner(
    AppState app, {
    required bool opened,
    bool animated = true,
  }) async {
    if (_dismissing) return;
    final payload = _banner;
    if (payload == null) return;

    _dismissing = true;
    _autoDismiss?.cancel();

    if (animated) {
      await _enter.reverse();
    } else {
      _enter.value = 0;
    }
    if (!mounted) return;

    setState(() => _banner = null);

    if (payload.request != null) {
      app.clearPendingRequestAlert();
      if (_showingRequestId == payload.request!.id) {
        _showingRequestId = null;
      }
    } else if (payload.ping != null) {
      await app.acknowledgePing(payload.ping!);
      if (_showingPingId == payload.ping!.id) {
        _showingPingId = null;
      }
    } else if (payload.timeLow != null) {
      app.clearPendingTimeLowAlert();
      if (_showingTimeLowId == payload.timeLow!.id) {
        _showingTimeLowId = null;
      }
    }

    _dismissing = false;

    // Always try the next queued alert after dismiss (tap or auto).
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _tryPresentNext(app);
      });
    }
  }
}

class _BannerPayload {
  const _BannerPayload._({
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.icon,
    required this.accent,
    this.request,
    this.ping,
    this.timeLow,
  });

  factory _BannerPayload.request(FriendRequest request) {
    return _BannerPayload._(
      eyebrow: 'FRIEND REQUEST',
      title: request.requesterName,
      body: 'wants to add you as a friend',
      icon: Icons.person_add_alt_1_rounded,
      accent: AppColors.goldBright,
      request: request,
    );
  }

  factory _BannerPayload.ping(FriendPing ping) {
    final name = ping.senderName ?? 'Friend';
    final isChat = ping.isChat;
    final isHelp = ping.message.toLowerCase().contains('need help');
    return _BannerPayload._(
      eyebrow: isChat
          ? 'MESSAGE'
          : isHelp
              ? 'NEED HELP'
              : 'PING',
      title: name,
      body: ping.message,
      icon: isHelp
          ? Icons.sos_rounded
          : isChat
              ? Icons.chat_bubble_rounded
              : Icons.campaign_rounded,
      accent: isHelp ? AppColors.dangerRed : AppColors.tigerRed,
      ping: ping,
    );
  }

  factory _BannerPayload.timeLow(TimeLowAlert alert) {
    return _BannerPayload._(
      eyebrow: alert.eyebrow,
      title: alert.title,
      body: alert.body,
      icon: alert.icon,
      accent: alert.accent,
      timeLow: alert,
    );
  }

  final String eyebrow;
  final String title;
  final String body;
  final IconData icon;
  final Color accent;
  final FriendRequest? request;
  final FriendPing? ping;
  final TimeLowAlert? timeLow;
}

/// Compact Dynamic Island–style pill under the status bar.
class _IslandBanner extends StatelessWidget {
  const _IslandBanner({
    required this.payload,
    required this.onTap,
    required this.onSwipeDismiss,
  });

  final _BannerPayload payload;
  final VoidCallback onTap;
  final VoidCallback onSwipeDismiss;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(
        'social-banner-${payload.request?.id ?? payload.ping?.id ?? payload.timeLow?.id}',
      ),
      direction: DismissDirection.up,
      onDismissed: (_) => onSwipeDismiss(),
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: payload.accent.withValues(alpha: 0.45),
                width: 1.25,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(AppColors.charcoal, payload.accent, 0.14)!,
                  AppColors.matteBlack,
                  const Color(0xFF0A0404),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: payload.accent.withValues(alpha: 0.28),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.55),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: payload.accent.withValues(alpha: 0.18),
                    border: Border.all(
                      color: payload.accent.withValues(alpha: 0.7),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(payload.icon, size: 20, color: payload.accent),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        payload.eyebrow,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.8,
                          color: AppColors.goldBrushed,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        payload.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.cinzel(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                          color: AppColors.textLight,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        payload.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          height: 1.25,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 22,
                  color: AppColors.textMuted.withValues(alpha: 0.7),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
