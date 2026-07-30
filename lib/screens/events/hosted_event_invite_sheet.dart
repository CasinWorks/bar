import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../models/event_models.dart';
import '../../providers/app_state.dart';

/// Host surface to mint unique guest invites and copy shareable codes.
class HostedEventInviteSheet extends StatefulWidget {
  const HostedEventInviteSheet({super.key, required this.event});

  final ClubEventRecord event;

  static Future<void> show(BuildContext context, ClubEventRecord event) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.charcoal,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => HostedEventInviteSheet(event: event),
    );
  }

  @override
  State<HostedEventInviteSheet> createState() => _HostedEventInviteSheetState();
}

class _HostedEventInviteSheetState extends State<HostedEventInviteSheet> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  List<HostedEventInviteRow> _invites = const [];
  bool _loading = true;
  bool _creating = false;
  String? _message;
  HostedEventInviteResult? _lastCreated;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _message = null;
    });
    final rows = await context.read<AppState>().listHostedEventInvites(
      widget.event.id,
    );
    if (!mounted) return;
    setState(() {
      _invites = rows;
      _loading = false;
    });
  }

  Future<void> _create() async {
    if (_creating) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _creating = true;
      _message = null;
      _lastCreated = null;
    });

    final (invite, error) = await context
        .read<AppState>()
        .createHostedEventInvite(
          eventId: widget.event.id,
          guestName: _nameController.text.trim(),
          guestEmail: _emailController.text.trim().isEmpty
              ? null
              : _emailController.text.trim(),
        );

    if (!mounted) return;

    setState(() {
      _creating = false;
      if (error != null) {
        _message = error;
      } else {
        _lastCreated = invite;
        _message = 'Invite created for ${invite?.guestName}.';
        _nameController.clear();
        _emailController.clear();
      }
    });

    if (error == null) {
      await _load();
    }
  }

  Future<void> _copy(String label, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$label copied')));
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.88;
    final event = widget.event;

    return SizedBox(
      height: height,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.darkSteel,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'INVITE GUESTS',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontSize: 18),
            ),
            Text(
              '${event.title} · unique code per guest',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Guest name',
                      hintText: 'Alex Rivera',
                    ),
                    validator: (value) {
                      if ((value ?? '').trim().length < 2) {
                        return 'Name required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Guest email (optional)',
                      hintText: 'Locks the invite to that account',
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _creating ? null : _create,
                      child: Text(_creating ? 'CREATING…' : 'CREATE INVITE'),
                    ),
                  ),
                ],
              ),
            ),
            if (_message != null) ...[
              const SizedBox(height: 10),
              Text(
                _message!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: _lastCreated != null
                      ? AppColors.successGreen
                      : AppColors.tigerOrange,
                ),
              ),
            ],
            if (_lastCreated != null) ...[
              const SizedBox(height: 10),
              _ShareCard(
                code: _lastCreated!.inviteCode,
                deepLink: _lastCreated!.deepLink,
                onCopyCode: () => _copy('Invite code', _lastCreated!.inviteCode),
                onCopyLink: () => _copy('Invite link', _lastCreated!.deepLink),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'GUEST LIST',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _invites.isEmpty
                  ? Text(
                      'No invites yet — create one above.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    )
                  : ListView.separated(
                      itemCount: _invites.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final row = _invites[index];
                        final isHostRow =
                            (row.guestEmail ?? '').toLowerCase() ==
                                (event.hostEmail ?? '').toLowerCase() &&
                            (event.hostEmail ?? '').isNotEmpty;
                        return _InviteTile(
                          row: row,
                          isHost: isHostRow ||
                              row.guestName.toLowerCase() ==
                                  (event.hostName ?? '').toLowerCase(),
                          onCopy: () => _copy('Invite code', row.inviteCode),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShareCard extends StatelessWidget {
  const _ShareCard({
    required this.code,
    required this.deepLink,
    required this.onCopyCode,
    required this.onCopyLink,
  });

  final String code;
  final String deepLink;
  final VoidCallback onCopyCode;
  final VoidCallback onCopyLink;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.neutral950,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.darkSteel),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CODE $code',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            deepLink,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontSize: 11),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton(
                onPressed: onCopyCode,
                child: const Text('Copy code'),
              ),
              OutlinedButton(
                onPressed: onCopyLink,
                child: const Text('Copy link'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InviteTile extends StatelessWidget {
  const _InviteTile({
    required this.row,
    required this.isHost,
    required this.onCopy,
  });

  final HostedEventInviteRow row;
  final bool isHost;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.neutral950,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.darkSteel),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isHost ? '${row.guestName} (you · host)' : row.guestName,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  '${row.inviteCode} · ${row.status}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onCopy,
            icon: const Icon(Icons.copy_rounded, size: 18),
            tooltip: 'Copy invite code',
          ),
        ],
      ),
    );
  }
}
