import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_logo.dart';
import '../../core/widgets/lattice_background.dart';
import '../../models/event_models.dart';
import '../../providers/app_state.dart';
import '../../router/member_routes.dart';
import '../../services/device_calendar_service.dart';
import '../../services/event_service.dart';
import 'event_guest_pass_screen.dart';

class EventInviteScreen extends StatefulWidget {
  const EventInviteScreen({super.key, this.initialCode, this.initialToken});

  final String? initialCode;
  final String? initialToken;

  @override
  State<EventInviteScreen> createState() => _EventInviteScreenState();
}

class _EventInviteScreenState extends State<EventInviteScreen> {
  final _codeController = TextEditingController();
  final _calendar = const DeviceCalendarService();

  EventInvitePreview? _preview;
  bool _previewLoading = false;
  bool _accepting = false;
  bool _savingCalendar = false;
  String? _message;

  bool get _usesToken =>
      widget.initialToken != null && widget.initialToken!.trim().isNotEmpty;

  String? get _pendingInviteLocation {
    final query = <String, String>{};
    final token = widget.initialToken?.trim();
    final code = _codeController.text.trim().toUpperCase();
    if (token != null && token.isNotEmpty) query['token'] = token;
    if (code.isNotEmpty) query['code'] = code;
    if (query.isEmpty) return null;
    return Uri(path: '/event-invite', queryParameters: query).toString();
  }

  @override
  void initState() {
    super.initState();
    if (!_usesToken && (widget.initialCode?.trim().isNotEmpty ?? false)) {
      _codeController.text = widget.initialCode!.trim().toUpperCase();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_usesToken) {
        _loadPreviewByToken();
      } else if (_codeController.text.trim().isNotEmpty) {
        _loadPreview();
      }
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _loadPreview() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() {
        _preview = null;
        _message = 'Enter an invite code to preview the guest pass.';
      });
      return;
    }

    FocusScope.of(context).unfocus();
    context.read<AppState>().setPendingEventInviteCode(code);
    setState(() {
      _previewLoading = true;
      _message = null;
    });

    try {
      final preview = await context.read<AppState>().previewEventInvite(code);
      if (!mounted) return;
      setState(() {
        _preview = preview;
        _message = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _preview = null;
        _message = EventService().friendlyError(error);
      });
    } finally {
      if (mounted) {
        setState(() => _previewLoading = false);
      }
    }
  }

  Future<void> _loadPreviewByToken() async {
    final token = widget.initialToken?.trim() ?? '';
    if (token.isEmpty) return;
    setState(() {
      _previewLoading = true;
      _message = null;
    });
    try {
      final preview = await context.read<AppState>().previewEventInviteByToken(
        token,
      );
      if (!mounted) return;
      setState(() {
        _preview = preview;
        _message = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _preview = null;
        _message = EventService().friendlyError(error);
      });
    } finally {
      if (mounted) {
        setState(() => _previewLoading = false);
      }
    }
  }

  Future<void> _acceptInvite() async {
    setState(() {
      _accepting = true;
      _message = null;
    });

    final appState = context.read<AppState>();
    final result = _usesToken
        ? await appState.acceptEventInviteByToken(widget.initialToken!)
        : await appState.acceptEventInvite(
            code: _codeController.text,
            acceptedVia: 'in_app_code_entry',
          );

    if (!mounted) return;
    setState(() {
      _accepting = false;
      _preview = result.$1 ?? _preview;
      _message = result.$2;
    });
  }

  Future<void> _saveToCalendar() async {
    final invite = _resolvedInvite;
    if (invite == null) return;
    setState(() {
      _savingCalendar = true;
      _message = null;
    });
    try {
      await _calendar.saveInvite(invite);
      if (!mounted) return;
      setState(() => _message = 'Saved to your device calendar.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _message = 'Could not save the event to your calendar.');
    } finally {
      if (mounted) {
        setState(() => _savingCalendar = false);
      }
    }
  }

  void _goToAuth(String path) {
    final pendingInviteLocation = _pendingInviteLocation;
    if (pendingInviteLocation != null) {
      context.read<AppState>().setPendingEventInviteLocation(
        pendingInviteLocation,
      );
    }
    context.go(path);
  }

  EventInvitePreview? get _resolvedInvite {
    final appState = context.read<AppState>();
    final accepted = appState.acceptedEventInvite;
    if (accepted != null &&
        _preview != null &&
        accepted.inviteId == _preview!.inviteId) {
      return accepted;
    }
    if (accepted != null && _usesToken) return accepted;
    return _preview;
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final invite = _resolvedInvite;
    final isLoggedIn = appState.isAuthenticated;
    final isAccepted = invite?.isAccepted ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Guest Invite')),
      body: LatticeBackground(
        animate: true,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            children: [
              const Center(child: AppLogo(size: 68)),
              const SizedBox(height: 20),
              Text(
                isAccepted
                    ? 'You are on the guest list.'
                    : 'Accept a guest invite.',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 8),
              Text(
                isAccepted
                    ? 'Your confirmation is ready below, and you can save the night to your calendar.'
                    : 'Enter an invite code to preview your pass, then sign in to confirm your spot.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              if (!_usesToken && !isAccepted) ...[
                TextField(
                  controller: _codeController,
                  enabled: !_previewLoading && !_accepting,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) {
                    if (_message != null) setState(() => _message = null);
                  },
                  onSubmitted: (_) => _previewLoading ? null : _loadPreview(),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9-]')),
                    UpperCaseTextFormatter(),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Invite code',
                    hintText: 'Enter code',
                    prefixIcon: const Icon(Icons.confirmation_number_outlined),
                    suffixIcon: IconButton(
                      onPressed: _previewLoading || _accepting
                          ? null
                          : _loadPreview,
                      icon: const Icon(Icons.search),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TigerButton(
                  label: 'PREVIEW INVITE',
                  icon: Icons.visibility_outlined,
                  isLoading: _previewLoading,
                  onPressed: _previewLoading || _accepting
                      ? null
                      : _loadPreview,
                ),
                const SizedBox(height: 18),
              ],
              if (_previewLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (invite != null) ...[
                _InviteSummaryCard(invite: invite),
                const SizedBox(height: 16),
                if (isAccepted)
                  _AcceptedInviteCard(
                    invite: invite,
                    savingCalendar: _savingCalendar,
                    onSaveToCalendar: _saveToCalendar,
                    onOpenPass: () =>
                        EventGuestPassScreen.open(context, invite),
                    onContinue: isLoggedIn
                        ? () => context.go(
                            routeForAppState(context.read<AppState>()),
                          )
                        : null,
                  )
                else if (!isLoggedIn)
                  _AuthHandoffCard(
                    onLogin: () => _goToAuth('/login'),
                    onSignup: () => _goToAuth('/signup'),
                  )
                else
                  TigerButton(
                    label: 'ACCEPT INVITE',
                    icon: Icons.check_circle_outline,
                    isLoading: _accepting,
                    onPressed: _accepting ? null : _acceptInvite,
                  ),
              ],
              if (_message != null) ...[
                const SizedBox(height: 16),
                Text(
                  _message!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: _message!.toLowerCase().contains('saved')
                        ? AppColors.successGreen
                        : AppColors.dangerRed,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InviteSummaryCard extends StatelessWidget {
  const _InviteSummaryCard({required this.invite});

  final EventInvitePreview invite;

  @override
  Widget build(BuildContext context) {
    return LuxuryCard(
      highlighted: invite.isAccepted,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            invite.title,
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontSize: 22),
          ),
          const SizedBox(height: 6),
          Text(
            '${invite.eventType.label} at ${invite.branch}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          _InviteRow(
            icon: Icons.person_outline,
            label: 'Host',
            value: invite.hostName,
          ),
          _InviteRow(
            icon: Icons.event_outlined,
            label: 'Date',
            value: DateFormat('EEEE, MMM d').format(invite.startsAt),
          ),
          _InviteRow(
            icon: Icons.schedule,
            label: 'Time',
            value: _timeRange(invite),
          ),
          _InviteRow(
            icon: Icons.badge_outlined,
            label: 'Guest',
            value: invite.guestName,
          ),
          if ((invite.description ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              invite.description!.trim(),
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontSize: 13),
            ),
          ],
        ],
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

class _AcceptedInviteCard extends StatelessWidget {
  const _AcceptedInviteCard({
    required this.invite,
    required this.savingCalendar,
    required this.onSaveToCalendar,
    required this.onOpenPass,
    required this.onContinue,
  });

  final EventInvitePreview invite;
  final bool savingCalendar;
  final VoidCallback onSaveToCalendar;
  final VoidCallback onOpenPass;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        LuxuryCard(
          highlighted: true,
          child: Column(
            children: [
              const Icon(
                Icons.check_circle,
                color: AppColors.successGreen,
                size: 42,
              ),
              const SizedBox(height: 12),
              Text(
                'Invite confirmed',
                style: Theme.of(
                  context,
                ).textTheme.headlineMedium?.copyWith(fontSize: 20),
              ),
              const SizedBox(height: 8),
              Text(
                'You are confirmed for ${invite.title} with ${invite.hostName} on ${DateFormat('EEE, MMM d').format(invite.startsAt)} at ${DateFormat('h:mm a').format(invite.startsAt)}.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'At the door, show your normal entry QR — staff scan once for entry and event check-in.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TigerButton(
          label: 'SHOW GUEST PASS',
          icon: Icons.qr_code_2_rounded,
          onPressed: onOpenPass,
        ),
        const SizedBox(height: 8),
        TigerButton(
          label: 'SAVE TO CALENDAR',
          icon: Icons.calendar_today_outlined,
          isLoading: savingCalendar,
          secondary: true,
          onPressed: savingCalendar ? null : onSaveToCalendar,
        ),
        if (onContinue != null) ...[
          const SizedBox(height: 8),
          TigerButton(
            label: 'CONTINUE TO APP',
            secondary: true,
            onPressed: onContinue,
          ),
        ],
      ],
    );
  }
}

class _AuthHandoffCard extends StatelessWidget {
  const _AuthHandoffCard({required this.onLogin, required this.onSignup});

  final VoidCallback onLogin;
  final VoidCallback onSignup;

  @override
  Widget build(BuildContext context) {
    return LuxuryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sign in to claim this invite.',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontSize: 20),
          ),
          const SizedBox(height: 8),
          Text(
            'Your invite code will stay queued in the app so you can finish acceptance after login.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          TigerButton(label: 'SIGN IN', icon: Icons.login, onPressed: onLogin),
          const SizedBox(height: 8),
          TigerButton(
            label: 'CREATE ACCOUNT',
            secondary: true,
            icon: Icons.person_add_alt_1,
            onPressed: onSignup,
          ),
        ],
      ),
    );
  }
}

class _InviteRow extends StatelessWidget {
  const _InviteRow({
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

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
