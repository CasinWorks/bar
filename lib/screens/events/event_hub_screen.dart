import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/lattice_background.dart';
import '../../models/event_models.dart';
import '../../providers/app_state.dart';
import '../../router/member_routes.dart';
import '../../services/device_calendar_service.dart';
import '../lounge/hosted_event_wallet_sheet.dart';
import 'event_agenda.dart';
import 'event_guest_pass_screen.dart';
import 'hosted_event_invite_sheet.dart';

class EventHubScreen extends StatefulWidget {
  const EventHubScreen({super.key});

  @override
  State<EventHubScreen> createState() => _EventHubScreenState();
}

class _EventHubScreenState extends State<EventHubScreen> {
  static const List<int> _walletOptions = [60, 120, 180, 240, 360];
  static const int _stripDays = 21;

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _paxController = TextEditingController(text: '10');
  final _calendar = const DeviceCalendarService();

  ClubEventType _eventType = ClubEventType.privateSocial;
  String? _selectedBranch;
  DateTime? _startsAt;
  DateTime? _endsAt;
  int _walletMinutes = 120;
  bool _submitting = false;
  bool _showingHostedWalletPrompt = false;
  String? _submitMessage;

  late DateTime _selectedDay = dayOnly(DateTime.now());
  late DateTime _visibleMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
  );
  bool _monthExpanded = false;
  bool _requestOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = context.read<AppState>();
      _selectedBranch = state.session?.branch ?? state.selectedBranch;
      state.refreshEventState();
      setState(() {});
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _paxController.dispose();
    super.dispose();
  }

  HostedEventRequestDraft? get _draft {
    final startsAt = _startsAt;
    final endsAt = _endsAt;
    final branch = _selectedBranch;
    final expectedPax = int.tryParse(_paxController.text.trim());
    if (startsAt == null ||
        endsAt == null ||
        branch == null ||
        branch.isEmpty ||
        expectedPax == null) {
      return null;
    }
    return HostedEventRequestDraft(
      title: _titleController.text.trim(),
      branch: branch,
      eventType: _eventType,
      startsAt: startsAt,
      endsAt: endsAt,
      expectedPax: expectedPax,
      walletMinutes: _walletMinutes,
    );
  }

  Future<void> _refresh() => context.read<AppState>().refreshEventState();

  void _leaveScreen() {
    // This screen is entered with go() from the lounge, so there is often no
    // page to pop; fall back to wherever the member's session belongs.
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(routeForMemberState(context.read<AppState>()));
  }

  void _selectDay(DateTime day) {
    final normalized = dayOnly(day);
    setState(() {
      _selectedDay = normalized;
      _visibleMonth = DateTime(normalized.year, normalized.month);
    });
  }

  void _shiftMonth(int months) {
    setState(() {
      _visibleMonth = DateTime(
        _visibleMonth.year,
        _visibleMonth.month + months,
      );
    });
  }

  Future<void> _saveEntryToCalendar(EventAgendaEntry entry) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final invite = entry.invite;
      final hosted = entry.hosted;
      if (invite != null) {
        await _calendar.saveInvite(invite);
      } else if (hosted != null) {
        await _calendar.saveHostedEvent(hosted);
      }
      messenger.showSnackBar(
        const SnackBar(content: Text('Opening your device calendar…')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not open your device calendar.')),
      );
    }
  }

  void _openInvitePass(EventInvitePreview invite) {
    EventGuestPassScreen.open(context, invite);
  }

  void _openInviteReply(EventInvitePreview invite) {
    final code = invite.inviteCode?.trim();
    if (code == null || code.isEmpty) return;
    context.push(
      Uri(path: '/event-invite', queryParameters: {'code': code}).toString(),
    );
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final now = DateTime.now();
    final initial = isStart
        ? (_startsAt ?? now.add(const Duration(days: 7, hours: 2)))
        : (_endsAt ??
              (_startsAt ?? now.add(const Duration(days: 7, hours: 5))));

    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
      helpText: isStart ? 'Choose start date' : 'Choose end date',
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      helpText: isStart ? 'Choose start time' : 'Choose end time',
    );
    if (time == null || !mounted) return;

    final selected = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    setState(() {
      _submitMessage = null;
      if (isStart) {
        _startsAt = selected;
        if (_endsAt == null || !_endsAt!.isAfter(selected)) {
          _endsAt = selected.add(const Duration(hours: 4));
        }
      } else {
        _endsAt = selected;
      }
    });
  }

  Future<void> _submit() async {
    final draft = _draft;
    final form = _formKey.currentState;
    if (form == null || !form.validate() || draft == null) return;

    if (!draft.hasValidWindow) {
      setState(() {
        _submitMessage = 'End time must be after the start time.';
      });
      return;
    }
    if (!draft.hasMinimumPax) {
      setState(() {
        _submitMessage = 'Hosted events need at least 10 expected guests.';
      });
      return;
    }
    if (!draft.hasMinimumLeadTime) {
      setState(() {
        _submitMessage =
            'Hosted events must be requested at least 7 days ahead.';
      });
      return;
    }
    if (!draft.hasValidWallet) {
      setState(() {
        _submitMessage = 'Event wallet must start at 60 minutes or more.';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _submitMessage = null;
    });

    final state = context.read<AppState>();
    final (event, error) = await state.submitHostedEventRequest(
      title: draft.title,
      branch: draft.branch,
      eventType: draft.eventType,
      startsAt: draft.startsAt,
      endsAt: draft.endsAt,
      minimumPax: draft.expectedPax,
      walletMinutes: draft.walletMinutes,
      invites: draft.invites,
    );

    if (!mounted) return;

    setState(() {
      _submitting = false;
      _submitMessage =
          error ??
          '+${event?.title ?? draft.title} submitted for ${_statusLabel(EventApprovalStatus.pendingReview).toLowerCase()}.';
    });

    if (error == null) {
      _titleController.clear();
      _paxController.text = '${HostedEventRequestDraft.minimumPax}';
      _startsAt = null;
      _endsAt = null;
      _walletMinutes = 120;
      _eventType = ClubEventType.privateSocial;
      _selectedBranch = state.session?.branch ?? state.selectedBranch;
      _requestOpen = false;
    }
  }

  void _maybePromptHostedWallet(AppState state) {
    if (state.shouldPromptHostedEventWallet && !_showingHostedWalletPrompt) {
      _showingHostedWalletPrompt = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await HostedEventWalletSheet.show(context, promptOnOpen: true);
        if (mounted) {
          setState(() => _showingHostedWalletPrompt = false);
        }
      });
    } else if (!state.shouldPromptHostedEventWallet &&
        _showingHostedWalletPrompt) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _showingHostedWalletPrompt = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    _maybePromptHostedWallet(state);

    final agenda = buildEventAgenda(
      invites: state.eventInvites,
      hostedEvents: state.hostedEvents,
    );
    // One reference time for the whole frame so the dots, the day list and
    // "next up" cannot disagree about what is live.
    final now = DateTime.now();
    final marked = agendaMarkedDays(agenda, now: now);
    final dayEntries = entriesOnDay(agenda, _selectedDay, now: now);
    final upcoming = upcomingEntries(agenda, now: now);
    final pendingInvites = state.eventInvites
        .where((invite) => !invite.isAccepted)
        .toList(growable: false);
    final walletSummary = state.hostedEventWalletSummary;
    final attendance = state.activeEventAttendance;

    return Scaffold(
      body: LatticeBackground(
        animate: true,
        child: SafeArea(
          child: RefreshIndicator(
            color: AppColors.tigerRed,
            backgroundColor: AppColors.charcoal,
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                _HubHeader(onBack: _leaveScreen, onRefresh: _refresh),
                const SizedBox(height: 12),
                if (attendance != null) ...[
                  _TonightCard(attendance: attendance),
                  const SizedBox(height: 12),
                ],
                if (pendingInvites.isNotEmpty) ...[
                  _PendingInvitesBanner(
                    invites: pendingInvites,
                    onOpen: _openInviteReply,
                  ),
                  const SizedBox(height: 12),
                ],
                _CalendarCard(
                  selectedDay: _selectedDay,
                  visibleMonth: _visibleMonth,
                  markedDays: marked,
                  monthExpanded: _monthExpanded,
                  stripDays: _stripDays,
                  onSelectDay: _selectDay,
                  onShiftMonth: _shiftMonth,
                  onToggleMonth: () =>
                      setState(() => _monthExpanded = !_monthExpanded),
                  onToday: () => _selectDay(DateTime.now()),
                ),
                const SizedBox(height: 12),
                _AgendaSection(
                  selectedDay: _selectedDay,
                  entries: dayEntries,
                  upcoming: upcoming,
                  onSaveToCalendar: _saveEntryToCalendar,
                  onOpenPass: _openInvitePass,
                  onOpenInviteReply: _openInviteReply,
                  onSelectDay: _selectDay,
                ),
                if (walletSummary != null) ...[
                  const SizedBox(height: 12),
                  _HostedWalletOverview(summary: walletSummary),
                ],
                const SizedBox(height: 12),
                _RequestSection(
                  open: _requestOpen,
                  onToggle: () => setState(() => _requestOpen = !_requestOpen),
                  child: _buildRequestForm(state),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRequestForm(AppState state) {
    final branches = state.availableBranches;
    final selectedBranch =
        branches.any((branch) => branch.name == _selectedBranch)
        ? _selectedBranch
        : null;
    final draft = _draft;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _titleController,
            textCapitalization: TextCapitalization.words,
            decoration: _inputDecoration('Event title'),
            validator: (value) {
              final title = value?.trim() ?? '';
              if (title.length < 3) return 'Enter an event title.';
              return null;
            },
            onChanged: (_) => setState(() => _submitMessage = null),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: selectedBranch,
            isExpanded: true,
            dropdownColor: AppColors.charcoal,
            decoration: _inputDecoration('Branch'),
            items: branches
                .map(
                  (branch) => DropdownMenuItem<String>(
                    value: branch.name,
                    child: Text(branch.name),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _selectedBranch = value;
                _submitMessage = null;
              });
            },
            validator: (value) => (value == null || value.trim().isEmpty)
                ? 'Choose a branch.'
                : null,
          ),
          const SizedBox(height: 16),
          Text('EVENT TYPE', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ClubEventType.values.map((type) {
              final selected = _eventType == type;
              return ChoiceChip(
                label: Text(type.label),
                selected: selected,
                onSelected: (_) {
                  setState(() {
                    _eventType = type;
                    _submitMessage = null;
                  });
                },
                labelStyle: TextStyle(
                  color: selected ? AppColors.offWhite : AppColors.textMuted,
                  fontWeight: FontWeight.w700,
                ),
                selectedColor: AppColors.tigerRed,
                backgroundColor: AppColors.darkSteel,
                side: BorderSide(
                  color: selected ? AppColors.tigerRed : AppColors.darkSteel,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          _DateTimeField(
            label: 'Starts at',
            value: _startsAt,
            onPressed: () => _pickDateTime(isStart: true),
          ),
          const SizedBox(height: 12),
          _DateTimeField(
            label: 'Ends at',
            value: _endsAt,
            onPressed: () => _pickDateTime(isStart: false),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _paxController,
            keyboardType: TextInputType.number,
            decoration: _inputDecoration('Expected pax (min 10)'),
            validator: (value) {
              final pax = int.tryParse((value ?? '').trim());
              if (pax == null) return 'Enter your expected pax.';
              if (pax < HostedEventRequestDraft.minimumPax) {
                return 'Minimum pax is 10.';
              }
              return null;
            },
            onChanged: (_) => setState(() => _submitMessage = null),
          ),
          const SizedBox(height: 16),
          Text('EVENT WALLET', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _walletOptions.map((minutes) {
              final selected = _walletMinutes == minutes;
              return ChoiceChip(
                label: Text('${minutes ~/ 60}h'),
                selected: selected,
                onSelected: (_) {
                  setState(() {
                    _walletMinutes = minutes;
                    _submitMessage = null;
                  });
                },
                labelStyle: TextStyle(
                  color: selected ? AppColors.offWhite : AppColors.textMuted,
                  fontWeight: FontWeight.w700,
                ),
                selectedColor: AppColors.successGreen,
                backgroundColor: AppColors.darkSteel,
                side: BorderSide(
                  color: selected
                      ? AppColors.successGreen
                      : AppColors.darkSteel,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Text(
            '$_walletMinutes minutes of drink time for your guests. This is separate from your own wallet.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontSize: 11),
          ),
          if (draft != null) ...[
            const SizedBox(height: 16),
            LuxuryCard(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'REQUEST CHECK',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  _CheckRow(
                    label: '7-day lead time',
                    passed: draft.hasMinimumLeadTime,
                  ),
                  _CheckRow(
                    label: 'Minimum 10 pax',
                    passed: draft.hasMinimumPax,
                  ),
                  _CheckRow(
                    label: 'Valid event window',
                    passed: draft.hasValidWindow,
                  ),
                  _CheckRow(
                    label: 'Wallet 60+ minutes',
                    passed: draft.hasValidWallet,
                  ),
                ],
              ),
            ),
          ],
          if (_submitMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _submitMessage!,
              style: TextStyle(
                color: _submitMessage!.startsWith('+')
                    ? AppColors.successGreen
                    : AppColors.tigerRed,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
          const SizedBox(height: 16),
          TigerButton(
            label: _submitting ? 'SUBMITTING REQUEST…' : 'SUBMIT REQUEST',
            icon: Icons.send,
            onPressed: state.usesCloud && !_submitting ? _submit : null,
          ),
          if (!state.usesCloud) ...[
            const SizedBox(height: 10),
            Text(
              'Supabase must be configured to submit hosted event requests.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}

class _HubHeader extends StatelessWidget {
  const _HubHeader({required this.onBack, required this.onRefresh});

  final VoidCallback onBack;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          tooltip: 'Back',
          onPressed: onBack,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          icon: const Icon(
            Icons.arrow_back_ios_new,
            size: 18,
            color: AppColors.offWhite,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'EVENTS & CALENDAR',
                style: Theme.of(
                  context,
                ).textTheme.headlineMedium?.copyWith(fontSize: 19),
              ),
              Text(
                'Invites, nights you host, and your event wallet.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontSize: 11),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Refresh',
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh, size: 20, color: AppColors.textMuted),
        ),
      ],
    );
  }
}

class _TonightCard extends StatelessWidget {
  const _TonightCard({required this.attendance});

  final ActiveEventAttendance attendance;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final checkedIn = attendance.isCheckedIn;
    final accent = checkedIn ? AppColors.successGreen : AppColors.goldBright;

    return LuxuryCard(
      highlighted: true,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.celebration_outlined, color: accent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  checkedIn ? 'CHECKED IN TONIGHT' : 'ON THE LIST TONIGHT',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(color: accent),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "${attendance.hostName}'s ${attendance.title}",
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            checkedIn
                ? 'Door staff confirmed you · drinks can run on the host wallet.'
                : 'Show your QR at the door to be checked in for this event.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontSize: 11),
          ),
          if (attendance.walletSeconds > 0) ...[
            const SizedBox(height: 8),
            Text(
              'Host wallet left: ${state.formatDuration(attendance.walletSeconds)}',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontSize: 11, color: accent),
            ),
          ],
        ],
      ),
    );
  }
}

class _PendingInvitesBanner extends StatelessWidget {
  const _PendingInvitesBanner({required this.invites, required this.onOpen});

  final List<EventInvitePreview> invites;
  final void Function(EventInvitePreview invite) onOpen;

  @override
  Widget build(BuildContext context) {
    final first = invites.first;
    final more = invites.length - 1;

    return LuxuryCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const Icon(
            Icons.mark_email_unread_outlined,
            color: AppColors.goldBright,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invites.length == 1
                      ? '1 INVITE WAITING'
                      : '${invites.length} INVITES WAITING',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(color: AppColors.goldBright),
                ),
                const SizedBox(height: 4),
                Text(
                  more > 0
                      ? '${first.title} and $more more need your reply.'
                      : '${first.title} needs your reply.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: first.inviteCode == null ? null : () => onOpen(first),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.goldBright,
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            child: const Text('REVIEW'),
          ),
        ],
      ),
    );
  }
}

class _CalendarCard extends StatelessWidget {
  const _CalendarCard({
    required this.selectedDay,
    required this.visibleMonth,
    required this.markedDays,
    required this.monthExpanded,
    required this.stripDays,
    required this.onSelectDay,
    required this.onShiftMonth,
    required this.onToggleMonth,
    required this.onToday,
  });

  final DateTime selectedDay;
  final DateTime visibleMonth;
  final Set<DateTime> markedDays;
  final bool monthExpanded;
  final int stripDays;
  final void Function(DateTime day) onSelectDay;
  final void Function(int months) onShiftMonth;
  final VoidCallback onToggleMonth;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    final today = dayOnly(DateTime.now());
    final isToday = selectedDay == today;

    return LuxuryCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  DateFormat(
                    'MMMM yyyy',
                  ).format(monthExpanded ? visibleMonth : selectedDay),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.goldBrushed,
                  ),
                ),
              ),
              if (!isToday)
                TextButton(
                  onPressed: onToday,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.tigerRed,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('TODAY'),
                ),
              IconButton(
                tooltip: monthExpanded ? 'Hide month' : 'Show month',
                onPressed: onToggleMonth,
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  monthExpanded ? Icons.expand_less : Icons.calendar_month,
                  size: 20,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 62,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.zero,
              itemCount: stripDays,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final day = today.add(Duration(days: index));
                return _DayChip(
                  day: day,
                  selected: day == selectedDay,
                  isToday: day == today,
                  hasEvents: markedDays.contains(day),
                  onTap: () => onSelectDay(day),
                );
              },
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: monthExpanded
                ? Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: _MonthGrid(
                      month: visibleMonth,
                      selectedDay: selectedDay,
                      markedDays: markedDays,
                      onSelectDay: onSelectDay,
                      onShiftMonth: onShiftMonth,
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.day,
    required this.selected,
    required this.isToday,
    required this.hasEvents,
    required this.onTap,
  });

  final DateTime day;
  final bool selected;
  final bool isToday;
  final bool hasEvents;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = selected
        ? AppColors.tigerRed
        : isToday
        ? AppColors.goldBright
        : AppColors.darkSteel;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        width: 46,
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.tigerRed.withValues(alpha: 0.18)
              : AppColors.charcoal.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              DateFormat('E').format(day).substring(0, 1).toUpperCase(),
              style: TextStyle(
                fontSize: 9,
                letterSpacing: 1,
                fontWeight: FontWeight.w700,
                color: selected ? AppColors.offWhite : AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${day.day}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: selected
                    ? AppColors.offWhite
                    : isToday
                    ? AppColors.goldBright
                    : AppColors.offWhite,
              ),
            ),
            const SizedBox(height: 3),
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: hasEvents ? AppColors.goldBright : Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.selectedDay,
    required this.markedDays,
    required this.onSelectDay,
    required this.onShiftMonth,
  });

  final DateTime month;
  final DateTime selectedDay;
  final Set<DateTime> markedDays;
  final void Function(DateTime day) onSelectDay;
  final void Function(int months) onShiftMonth;

  @override
  Widget build(BuildContext context) {
    final today = dayOnly(DateTime.now());
    final firstOfMonth = DateTime(month.year, month.month);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leading = firstOfMonth.weekday % 7; // Sunday-first grid.
    final cells = <DateTime?>[
      ...List<DateTime?>.filled(leading, null),
      ...List<DateTime>.generate(
        daysInMonth,
        (index) => DateTime(month.year, month.month, index + 1),
      ),
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }

    return Column(
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Previous month',
              onPressed: () => onShiftMonth(-1),
              visualDensity: VisualDensity.compact,
              icon: const Icon(
                Icons.chevron_left,
                size: 20,
                color: AppColors.textMuted,
              ),
            ),
            Expanded(
              child: Text(
                DateFormat('MMMM yyyy').format(month),
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontSize: 12),
              ),
            ),
            IconButton(
              tooltip: 'Next month',
              onPressed: () => onShiftMonth(1),
              visualDensity: VisualDensity.compact,
              icon: const Icon(
                Icons.chevron_right,
                size: 20,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
        Row(
          children: const ['S', 'M', 'T', 'W', 'T', 'F', 'S']
              .map(
                (label) => Expanded(
                  child: Center(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 4),
        for (var row = 0; row < cells.length / 7; row++)
          Row(
            children: List.generate(7, (column) {
              final day = cells[row * 7 + column];
              if (day == null) {
                return const Expanded(child: SizedBox(height: 32));
              }
              final selected = day == selectedDay;
              return Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => onSelectDay(day),
                  child: Container(
                    height: 32,
                    margin: const EdgeInsets.all(1),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.tigerRed.withValues(alpha: 0.22)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: day == today
                          ? Border.all(
                              color: AppColors.goldBright.withValues(
                                alpha: 0.6,
                              ),
                            )
                          : null,
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Text(
                          '${day.day}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: selected
                                ? FontWeight.w900
                                : FontWeight.w600,
                            color: selected
                                ? AppColors.offWhite
                                : AppColors.textMuted,
                          ),
                        ),
                        if (markedDays.contains(day))
                          Positioned(
                            bottom: 4,
                            child: Container(
                              width: 4,
                              height: 4,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.goldBright,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
      ],
    );
  }
}

class _AgendaSection extends StatelessWidget {
  const _AgendaSection({
    required this.selectedDay,
    required this.entries,
    required this.upcoming,
    required this.onSaveToCalendar,
    required this.onOpenPass,
    required this.onOpenInviteReply,
    required this.onSelectDay,
  });

  final DateTime selectedDay;
  final List<EventAgendaEntry> entries;
  final List<EventAgendaEntry> upcoming;
  final Future<void> Function(EventAgendaEntry entry) onSaveToCalendar;
  final void Function(EventInvitePreview invite) onOpenPass;
  final void Function(EventInvitePreview invite) onOpenInviteReply;
  final void Function(DateTime day) onSelectDay;

  @override
  Widget build(BuildContext context) {
    final isToday = selectedDay == dayOnly(DateTime.now());
    final heading = isToday
        ? 'TODAY · ${DateFormat('MMM d').format(selectedDay)}'
        : DateFormat('EEE, MMM d').format(selectedDay).toUpperCase();

    return LuxuryCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            heading,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: AppColors.goldBrushed),
          ),
          const SizedBox(height: 10),
          if (entries.isNotEmpty)
            ...entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _AgendaCard(
                  entry: entry,
                  onSaveToCalendar: () => onSaveToCalendar(entry),
                  onOpenPass: onOpenPass,
                  onOpenInviteReply: onOpenInviteReply,
                ),
              ),
            )
          else ...[
            Text(
              'Nothing booked on this day.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontSize: 12),
            ),
            if (upcoming.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                'NEXT UP',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.textMuted,
                  fontSize: 9,
                ),
              ),
              const SizedBox(height: 8),
              ...upcoming.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _UpcomingRow(
                    entry: entry,
                    onTap: () => onSelectDay(entry.startsAt),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _UpcomingRow extends StatelessWidget {
  const _UpcomingRow({required this.entry, required this.onTap});

  final EventAgendaEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(
              entry.isHosted ? Icons.star_outline : Icons.mail_outline,
              size: 16,
              color: entry.isHosted ? AppColors.tigerRed : AppColors.goldBright,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                entry.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontSize: 12),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              DateFormat('MMM d').format(entry.startsAt),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 11,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AgendaCard extends StatelessWidget {
  const _AgendaCard({
    required this.entry,
    required this.onSaveToCalendar,
    required this.onOpenPass,
    required this.onOpenInviteReply,
  });

  final EventAgendaEntry entry;
  final VoidCallback onSaveToCalendar;
  final void Function(EventInvitePreview invite) onOpenPass;
  final void Function(EventInvitePreview invite) onOpenInviteReply;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final accent = entry.isHosted ? AppColors.tigerRed : AppColors.goldBright;
    final invite = entry.invite;
    final hosted = entry.hosted;
    final timeRange = _timeRange(entry);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.charcoal.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.darkSteel),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(width: 3, height: 34, color: accent),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.titleMedium?.copyWith(fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$timeRange · ${entry.branch}',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _Pill(
                label: entry.isHosted ? 'HOSTING' : 'INVITED',
                color: accent,
              ),
              if (entry.isLive)
                const _Pill(label: 'LIVE NOW', color: AppColors.successGreen),
              if (invite != null)
                _Pill(
                  label: invite.isCheckedIn
                      ? 'CHECKED IN'
                      : invite.isAccepted
                      ? 'ACCEPTED'
                      : 'NEEDS REPLY',
                  color: invite.isAccepted
                      ? AppColors.successGreen
                      : AppColors.tigerOrange,
                ),
              if (hosted != null)
                _Pill(
                  label: _statusLabel(hosted.approvalStatus).toUpperCase(),
                  color: _statusColor(hosted.approvalStatus),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            entry.subtitle,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontSize: 11),
          ),
          if (hosted != null && hosted.isApproved) ...[
            const SizedBox(height: 6),
            Text(
              'Event wallet: ${state.formatDuration(hosted.walletSeconds)} left · ${state.formatDuration(hosted.walletConsumedSeconds)} spent',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 11,
                color: hosted.isWalletLow
                    ? AppColors.goldBright
                    : AppColors.textMuted,
              ),
            ),
          ],
          if ((hosted?.adminReviewNotes ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              hosted!.adminReviewNotes!.trim(),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 11,
                color: AppColors.goldBright,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _CardAction(
                icon: Icons.calendar_today_outlined,
                label: 'Add to calendar',
                onPressed: onSaveToCalendar,
              ),
              if (invite != null && invite.isAccepted)
                _CardAction(
                  icon: Icons.qr_code_2_rounded,
                  label: 'View pass',
                  onPressed: () => onOpenPass(invite),
                ),
              if (invite != null &&
                  !invite.isAccepted &&
                  invite.inviteCode != null)
                _CardAction(
                  icon: Icons.mail_outline,
                  label: 'Reply to invite',
                  onPressed: () => onOpenInviteReply(invite),
                ),
              if (hosted != null && hosted.isApproved)
                _CardAction(
                  icon: Icons.person_add_alt_1_rounded,
                  label: 'Invite guests',
                  onPressed: () => HostedEventInviteSheet.show(context, hosted),
                ),
              if (hosted != null && hosted.isApproved)
                _CardAction(
                  icon: Icons.account_balance_wallet_outlined,
                  label: hosted.isWalletLow ? 'Extend wallet' : 'Event wallet',
                  onPressed: () => HostedEventWalletSheet.show(
                    context,
                    promptOnOpen: hosted.isWalletLow,
                  ),
                ),
              if (hosted != null && hosted.isApproved)
                Builder(
                  builder: (context) {
                    final hostInvite = state.eventInvites
                        .cast<EventInvitePreview?>()
                        .firstWhere(
                          (invite) => invite?.eventId == hosted.id,
                          orElse: () => null,
                        );
                    if (hostInvite == null || !hostInvite.isAccepted) {
                      return const SizedBox.shrink();
                    }
                    return _CardAction(
                      icon: Icons.qr_code_2_rounded,
                      label: 'Host pass',
                      onPressed: () => onOpenPass(hostInvite),
                    );
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _timeRange(EventAgendaEntry entry) {
    final time = DateFormat('h:mm a');
    final start = time.format(entry.startsAt);
    final end = entry.endsAt;
    return end == null ? start : '$start–${time.format(end)}';
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.8)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _CardAction extends StatelessWidget {
  const _CardAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.offWhite,
        side: const BorderSide(color: AppColors.darkSteel),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        visualDensity: VisualDensity.compact,
        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
      ),
      icon: Icon(icon, size: 15),
      label: Text(label),
    );
  }
}

class _RequestSection extends StatelessWidget {
  const _RequestSection({
    required this.open,
    required this.onToggle,
    required this.child,
  });

  final bool open;
  final VoidCallback onToggle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LuxuryCard(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  const Icon(
                    Icons.add_circle_outline,
                    size: 18,
                    color: AppColors.tigerRed,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'REQUEST AN EVENT',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '7 days lead time · minimum 10 pax · admin approval',
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    open ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: open
                ? Padding(padding: const EdgeInsets.only(top: 6), child: child)
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _HostedWalletOverview extends StatelessWidget {
  const _HostedWalletOverview({required this.summary});

  final HostedEventWalletSummary summary;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final accent = summary.isDepleted
        ? AppColors.dangerRed
        : summary.isLow
        ? AppColors.goldBright
        : AppColors.successGreen;

    return LuxuryCard(
      highlighted: summary.isLow,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_wallet, color: accent, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LIVE EVENT WALLET',
                      style: Theme.of(
                        context,
                      ).textTheme.labelLarge?.copyWith(color: accent),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      summary.event.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.titleMedium?.copyWith(fontSize: 15),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _WalletFact(
                  label: 'REMAINING',
                  value: state.formatDuration(summary.remainingSeconds),
                  color: accent,
                ),
              ),
              Expanded(
                child: _WalletFact(
                  label: 'SPENT',
                  value: state.formatDuration(summary.consumedSeconds),
                ),
              ),
              Expanded(
                child: _WalletFact(
                  label: 'EXTENDED',
                  value: state.formatDuration(summary.extendedSeconds),
                  color: AppColors.goldBright,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 6,
              value: summary.remainingRatio,
              backgroundColor: AppColors.darkSteel,
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            summary.isDepleted
                ? 'Empty — guests are paying their own time until you extend.'
                : summary.isLow
                ? 'Running low. Extend now so guest drinks stay covered.'
                : 'Healthy. Guest drinks are covered by this wallet.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontSize: 11),
          ),
          const SizedBox(height: 10),
          TigerButton(
            label: summary.isLow ? 'EXTEND NOW' : 'OPEN EVENT WALLET',
            icon: Icons.account_balance_wallet,
            onPressed: () => HostedEventWalletSheet.show(
              context,
              promptOnOpen: summary.isLow,
            ),
          ),
        ],
      ),
    );
  }
}

class _WalletFact extends StatelessWidget {
  const _WalletFact({
    required this.label,
    required this.value,
    this.color = AppColors.offWhite,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 8),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _DateTimeField extends StatelessWidget {
  const _DateTimeField({
    required this.label,
    required this.value,
    required this.onPressed,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final text = value == null
        ? 'Choose $label'
        : DateFormat('EEE, MMM d · h:mm a').format(value!);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onPressed,
      child: InputDecorator(
        decoration: _inputDecoration(label),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: value == null
                      ? AppColors.textMuted
                      : AppColors.offWhite,
                ),
              ),
            ),
            const Icon(Icons.calendar_month, color: AppColors.goldBright),
          ],
        ),
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.label, required this.passed});

  final String label;
  final bool passed;

  @override
  Widget build(BuildContext context) {
    final color = passed ? AppColors.successGreen : AppColors.tigerRed;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(
            passed ? Icons.check_circle : Icons.cancel,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

InputDecoration _inputDecoration(String label) {
  return InputDecoration(
    labelText: label,
    filled: true,
    fillColor: AppColors.charcoal,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
  );
}

String _statusLabel(EventApprovalStatus status) => switch (status) {
  EventApprovalStatus.pendingReview => 'Pending review',
  EventApprovalStatus.approved => 'Approved',
  EventApprovalStatus.rejected => 'Rejected',
  EventApprovalStatus.needsRevision => 'Needs revision',
};

Color _statusColor(EventApprovalStatus status) => switch (status) {
  EventApprovalStatus.pendingReview => AppColors.goldBright,
  EventApprovalStatus.approved => AppColors.successGreen,
  EventApprovalStatus.rejected => AppColors.dangerRed,
  EventApprovalStatus.needsRevision => AppColors.tigerOrange,
};
