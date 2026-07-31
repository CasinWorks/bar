import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../core/config/door_qr_bypass.dart' as door_qr;
import '../core/config/super_admin.dart';
import '../core/theme/app_colors.dart';
import '../data/mock_data.dart';
import '../models/blind_tiger_models.dart';
import '../models/club_packages.dart';
import '../models/club_session.dart';
import '../models/member_user.dart';
import '../models/qr_payload.dart';
import '../models/staff_tip_received.dart';
import '../services/auth_service.dart';
import '../services/leaderboard_service.dart';
import '../services/payment_service.dart';
import '../services/qr_service.dart';
import '../services/session_store.dart';
import '../services/time_gift_service.dart';
import '../services/time_live_activity_service.dart';
import '../services/tiger_sound_service.dart';
import '../services/social_play_service.dart';
import '../services/safety_social_service.dart';
import '../services/push_notification_service.dart';
import '../services/branch_service.dart';
import '../services/club_package_service.dart';
import '../services/drink_catalog_service.dart';
import '../services/drink_pos_service.dart';
import '../services/deep_link_service.dart';
import '../models/drink_catalog.dart';
import '../models/drink_pay_payload.dart';
import '../models/time_gift.dart';
import '../models/time_low_alert.dart';
import '../models/drink_order.dart';
import '../models/drink_delivery_alert.dart';
import '../models/time_economy.dart';
import '../models/quest_system.dart';
import '../models/social_play.dart';
import '../models/branch_location.dart';
import '../models/event_models.dart';
import '../models/event_guest_checkin_alert.dart';
import '../models/event_guest_welcome_alert.dart';
import '../models/vip_hosted_event_conflict.dart';
import '../models/staff_door_scan_result.dart';
import '../data/quest_catalog.dart';
import '../services/time_economy_service.dart';
import '../services/drink_order_service.dart';
import '../services/event_service.dart';

class AppState extends ChangeNotifier {
  AppState({
    AuthService? authService,
    PaymentService? paymentService,
    QrService? qrService,
    SessionStore? sessionStore,
    TimeGiftService? timeGiftService,
    LeaderboardService? leaderboardService,
    TimeLiveActivityService? liveActivityService,
    TigerSoundService? soundService,
    SocialPlayService? socialPlayService,
    SafetySocialService? safetySocialService,
    PushNotificationService? pushNotificationService,
    BranchService? branchService,
    EventService? eventService,
  }) : _auth = authService ?? AuthService(),
       _payment = paymentService ?? PaymentService(),
       _qr = qrService ?? QrService(),
       _sessionStore = sessionStore ?? SessionStore.instance,
       _gifts = timeGiftService ?? TimeGiftService(),
       _leaderboardService = leaderboardService ?? LeaderboardService(),
       _liveActivity = liveActivityService ?? TimeLiveActivityService(),
       _sounds = soundService ?? TigerSoundService.instance,
       _social = socialPlayService ?? SocialPlayService(),
       _safety = safetySocialService ?? SafetySocialService(),
       _push = pushNotificationService ?? PushNotificationService(),
       _branches = branchService ?? BranchService(),
       _events = eventService ?? EventService();

  final AuthService _auth;
  final PaymentService _payment;
  final QrService _qr;
  final SessionStore _sessionStore;
  final TimeGiftService _gifts;
  final LeaderboardService _leaderboardService;
  final TimeLiveActivityService _liveActivity;
  final TigerSoundService _sounds;
  final SocialPlayService _social;
  final SafetySocialService _safety;
  final PushNotificationService _push;
  final BranchService _branches;
  final EventService _events;
  final _uuid = const Uuid();

  bool _isLoading = true;
  MemberUser? _user;
  ClubSessionRecord? _session;
  PriceTier _selectedTier = MockData.priceTiers[1];
  int _selectedTimeMinutes = MockData.timePackages[1].minutes;
  String _selectedTimePackageId = MockData.timePackages[1].id;
  PaymentMethod _paymentMethod = PaymentMethod.gcash;
  List<BranchLocation> _availableBranches = BranchService.defaultBranches;
  String _selectedBranch = BranchService.defaultBranches.first.name;

  Timer? _timer;
  Timer? _qrRefreshTimer;
  Timer? _syncTimer;
  Timer? _autoBadgeOutTimer;
  void Function(StaffTipReceived)? _staffTipCallback;
  int _staffTipWatchBalance = 0;
  String? _lastHandledTipId;
  DateTime? _lastHandledTipAt;
  QrPayload? _currentQr;
  int _timerSyncDebt = 0;

  /// Seconds of VIP room decay pending a session upsert (mirrors wallet debt).
  int _roomTimerSyncDebt = 0;
  int _drinksOrdered = 0;
  int _localTimeMutations = 0;
  bool _walletBusy = false;
  PendingWalletCredit? _pendingWalletCredit;

  /// Frozen receipt after exit scan — survives until [beginNewVisit].
  ClubSessionRecord? _checkoutReceipt;
  static const _checkoutReceiptKey = 'checkout_receipt_v1';
  int? _lastLiveActivitySeconds;
  bool _appInForeground = true;
  final Set<String> _pushedAlertIds = {};
  String? _liveSocialTitle;
  String? _liveSocialBody;
  String? _liveSocialSender;

  /// Thresholds (minutes) already warned for this descent; cleared when time
  /// climbs back above that mark (e.g. after buying more time).
  final Set<int> _firedTimeLowThresholds = {};
  final List<TimeLowAlert> _timeLowAlertQueue = [];
  final List<DrinkDeliveryAlert> _drinkDeliveryAlertQueue = [];
  final Set<String> _settlingDrinkOrderIds = {};
  bool _timeLowThresholdsSeeded = false;
  String? _lastAnnouncedBand;

  AvatarConfig _avatar = const AvatarConfig();
  int _points = 108;
  LoungeTab _activeTab = LoungeTab.timeEconomy;
  FriendProfile? _pendingChatProfile;
  List<Challenge> _challenges = [];
  List<FeedEvent> _feedEvents = [];
  List<LeaderboardUser> _leaderboard = [];
  bool _loungeInitialized = false;

  bool _openToMeet = false;
  String _vibeTag = SocialVibeTags.options[1];
  List<SocialPresence> _whosInside = [];
  SocialMeet? _activeMeet;
  Timer? _presencePoll;
  final Set<String> _awardedMeetCompletions = {};
  List<FriendProfile> _friendSearchResults = [];
  List<FriendRequest> _friendRequests = [];
  List<FriendProfile> _mutualFriendsNearby = [];
  final Set<String> _blockedMemberIds = {};
  FriendPing? _lastFriendPing;
  List<FriendPing> _incomingPings = [];

  /// FIFO queues — head is what [SocialAlertsHost] should show next.
  final List<FriendPing> _pingAlertQueue = [];
  final List<FriendRequest> _requestAlertQueue = [];
  final Set<String> _seenInboundRequestIds = {};
  final Set<String> _ackedPingIds = {};
  Timer? _socialInboxPoll;
  SafetyReport? _lastSafetyReport;
  RideAssistRequest? _lastRideAssistRequest;
  InsuranceIncident? _lastInsuranceIncident;
  bool _needsMemberTutorial = false;
  List<ClubEventRecord> _hostedEvents = [];
  List<EventInvitePreview> _eventInvites = [];
  ActiveEventAttendance? _activeEventAttendance;
  EventInvitePreview? _acceptedEventInvite;
  StaffEventCheckInResult? _lastStaffEventCheckIn;
  String? _pendingEventInviteCode;
  String? _pendingEventInviteLocation;
  String? _eventWalletPromptedForId;
  bool _eventSyncing = false;
  bool _eventRefreshQueued = false;
  final List<EventGuestWelcomeAlert> _eventGuestWelcomeQueue = [];
  final List<EventGuestCheckinAlert> _eventGuestCheckinQueue = [];
  final Set<String> _seenEventGuestCheckinIds = {};

  /// Door scans whose event welcome was already shown to this member.
  final Set<String> _welcomedScanKeys = {};
  static const _welcomedScansPrefix = 'event_welcome_shown_v2_';
  static const _eventCachePrefix = 'event_state_cache_v1_';
  Timer? _eventCheckInPoll;
  int _eventCheckInPollAttempts = 0;
  static const Duration _eventCheckInPollInterval = Duration(seconds: 5);

  /// 10 minutes of door-check-in watching — long enough for a slow scanner
  /// queue, short enough to never poll for the whole night.
  static const int _eventCheckInPollMaxAttempts = 120;

  // ─── Time Economy ───────────────────────────────────────────────────────
  List<NightTimelineEvent> _nightTimeline = [];
  List<ActiveTimeBuff> _activeBuffs = [];
  double _decayDebtFraction = 0;
  VisitRecap _visitRecap = VisitRecap();
  VisitRecap? _frozenVisitRecap;
  int _lifetimeVisits = 0;
  int _lifetimeMinutesBanked = 0;
  final Set<AchievementBadgeId> _unlockedBadges = {};
  int _visitStartBalance = 0;
  Timer? _economyRefreshTimer;
  static const _lifetimeVisitsKey = 'lifetime_visits_v1';
  static const _lifetimeMinutesKey = 'lifetime_minutes_v1';
  static const _unlockedBadgesKey = 'unlocked_badges_v1';
  static const _visitRecapKey = 'visit_recap_v1';
  static const _bankedTimeKey = 'banked_time_seconds_v1';
  static const _reputationXpKey = 'reputation_xp_v1';
  static const _questBadgesKey = 'quest_badges_v1';
  static const _tutorialSeenPrefix = 'member_tutorial_seen_v1_';

  // Quest system
  List<ClubQuest> _activeQuests = [];
  ClubQuest? _mysteryQuest;
  int _bankedTimeSeconds = 0;
  int _reservedTimeSeconds = 0;
  int _reputationXp = 0;
  final Set<String> _questBadges = {};
  Map<LeaderboardCategory, List<CompetitiveRanking>> _competitiveRankings = {};
  int _questsCompletedTonight = 0;
  int _savedMinutesAcrossVisits = 0;
  int _communityPoolDonatedMinutes = 0;

  bool get isLoading => _isLoading;
  bool get usesCloud => _auth.usesSupabase;
  MemberUser? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get isStaff => _user?.isStaff ?? false;
  bool get isMember => _user?.isMember ?? false;
  bool get usesMemberSurface => _user?.usesMemberSurface ?? false;

  /// Entry door QR may be skipped only for VIP-whitelisted members.
  /// Founder/admin accounts always require staff door scan.
  bool get canSkipDoorQr {
    final user = _user;
    if (user == null) return false;
    if (user.isAdmin || isSuperAdminEmail(user.email)) return false;
    return door_qr.canSkipDoorQrScan(isWhitelisted: user.isWhitelisted);
  }

  bool get needsMemberTutorial => _needsMemberTutorial && isMember && !isStaff;
  List<ClubEventRecord> get hostedEvents => List.unmodifiable(_hostedEvents);
  List<EventInvitePreview> get eventInvites => List.unmodifiable(_eventInvites);
  ActiveEventAttendance? get activeEventAttendance => _activeEventAttendance;
  EventInvitePreview? get acceptedEventInvite => _acceptedEventInvite;
  StaffEventCheckInResult? get lastStaffEventCheckIn => _lastStaffEventCheckIn;
  String? get pendingEventInviteCode => _pendingEventInviteCode;
  String? get pendingEventInviteLocation => _pendingEventInviteLocation;
  ClubEventRecord? get activeHostedEvent {
    for (final event in _hostedEvents) {
      if (event.isApproved && event.isActiveNow) return event;
    }
    return null;
  }

  /// Host of a live event — VIP / VVIP room booking is blocked.
  bool get blocksVipRoomDueToHostedEvent =>
      VipHostedEventConflict.blocksVipBooking(
        activeHostedEvent: activeHostedEvent,
      );

  bool get shouldPromptHostedEventWallet {
    final event = activeHostedEvent;
    if (event == null) return false;
    return event.walletSeconds <= event.walletLowThresholdSeconds &&
        _eventWalletPromptedForId != event.id;
  }

  HostedEventWalletSummary? get hostedEventWalletSummary {
    final event = activeHostedEvent;
    if (event == null) return null;
    return HostedEventWalletSummary(
      event: event,
      remainingSeconds: event.walletSeconds,
      lowThresholdSeconds: event.walletLowThresholdSeconds,
    );
  }

  ClubSessionRecord? get session => _session ?? _checkoutReceipt;
  bool get hasCheckoutReceipt => _checkoutReceipt != null;
  ClubSessionRecord? get checkoutReceipt => _checkoutReceipt;
  SessionPhase get sessionPhase {
    if (_checkoutReceipt != null) return SessionPhase.completed;
    return _session?.phase ?? SessionPhase.none;
  }

  PriceTier get selectedTier => _selectedTier;
  int get selectedTimeMinutes => _selectedTimeMinutes;
  String get selectedTimePackageId => _selectedTimePackageId;
  PaymentMethod get paymentMethod => _paymentMethod;
  List<BranchLocation> get availableBranches =>
      List.unmodifiable(_availableBranches);
  String get selectedBranch => _selectedBranch;
  QrPayload? get currentQr => _currentQr;
  int get timeRemaining => timeBalance;

  int get drinksOrdered => _drinksOrdered;
  PendingWalletCredit? get pendingWalletCredit => _pendingWalletCredit;
  Duration get remaining => Duration(seconds: timeRemaining);
  AvatarConfig get avatar => _avatar;
  int get points => _points;
  LoungeTab get activeTab => _activeTab;
  FriendProfile? get pendingChatProfile => _pendingChatProfile;
  List<Challenge> get challenges => List.unmodifiable(_challenges);
  List<FeedEvent> get feedEvents => List.unmodifiable(_feedEvents);
  List<LeaderboardUser> get leaderboard => List.unmodifiable(_leaderboard);
  bool get openToMeet => _openToMeet;
  String get vibeTag => _vibeTag;
  List<SocialPresence> get whosInside => List.unmodifiable(_whosInside);
  SocialMeet? get activeMeet => _activeMeet;
  List<FriendProfile> get friendSearchResults =>
      List.unmodifiable(_friendSearchResults);
  List<FriendRequest> get friendRequests => List.unmodifiable(_friendRequests);
  List<FriendProfile> get mutualFriendsNearby =>
      List.unmodifiable(_mutualFriendsNearby);
  FriendPing? get lastFriendPing => _lastFriendPing;
  List<FriendPing> get incomingPings => List.unmodifiable(_incomingPings);
  FriendPing? get pendingPingAlert =>
      _pingAlertQueue.isEmpty ? null : _pingAlertQueue.first;
  FriendRequest? get pendingRequestAlert =>
      _requestAlertQueue.isEmpty ? null : _requestAlertQueue.first;
  TimeLowAlert? get pendingTimeLowAlert =>
      _timeLowAlertQueue.isEmpty ? null : _timeLowAlertQueue.first;
  DrinkDeliveryAlert? get pendingDrinkDeliveryAlert =>
      _drinkDeliveryAlertQueue.isEmpty ? null : _drinkDeliveryAlertQueue.first;
  EventGuestWelcomeAlert? get pendingEventGuestWelcome =>
      _eventGuestWelcomeQueue.isEmpty ? null : _eventGuestWelcomeQueue.first;
  EventGuestCheckinAlert? get pendingEventGuestCheckinAlert =>
      _eventGuestCheckinQueue.isEmpty ? null : _eventGuestCheckinQueue.first;
  List<DrinkOrder> get activeDrinkOrders {
    if (_user == null) return const [];
    return _drinkOrders.activeForMember(_user!.id);
  }

  List<DrinkOrder> get staffPendingDrinkOrders =>
      _drinkOrders.pendingForStaff();

  final DrinkOrderService _drinkOrders = DrinkOrderService.instance;
  int get pendingInboundRequestCount => _friendRequests
      .where(
        (r) =>
            r.direction == 'inbound' && r.status == FriendRequestStatus.pending,
      )
      .length;
  SafetyReport? get lastSafetyReport => _lastSafetyReport;
  RideAssistRequest? get lastRideAssistRequest => _lastRideAssistRequest;
  InsuranceIncident? get lastInsuranceIncident => _lastInsuranceIncident;

  // Time Economy getters
  List<NightTimelineEvent> get nightTimeline =>
      List.unmodifiable(_nightTimeline);
  List<ActiveTimeBuff> get activeTimeBuffs => List.unmodifiable(_activeBuffs);
  VisitRecap get visitRecap => _frozenVisitRecap ?? _visitRecap;
  int get lifetimeVisits => _lifetimeVisits;
  int get lifetimeMinutesBanked => _lifetimeMinutesBanked;
  PlayerVisitTier get playerVisitTier =>
      PlayerVisitTierMeta.forVisits(_lifetimeVisits);
  List<AchievementBadge> get achievementBadges =>
      TimeEconomyService.allBadges(unlocked: _unlockedBadges);
  TimeEconomySnapshot get timeEconomySnapshot => TimeEconomyService.snapshot(
    now: DateTime.now(),
    walletSeconds: timeBalance,
    buffs: _activeBuffs,
    timeline: _nightTimeline,
  );

  TimeWalletSnapshot get timeWallet => TimeWalletSnapshot(
    liquidSeconds: isInsideClub ? timeBalance : 0,
    bankedSeconds: _bankedTimeSeconds,
    reservedSeconds: _reservedTimeSeconds,
    isInsideClub: isInsideClub,
    vipRoomSeconds: vipRoomTimeSeconds,
    activeVipRoomName: activeVipRoomName,
  );

  List<ClubQuest> get activeQuests => List.unmodifiable(_activeQuests);
  ClubQuest? get mysteryQuest => _mysteryQuest;
  int get reputationXp => _reputationXp;
  ReputationLevel get reputationLevel =>
      ReputationLevelMeta.forXp(_reputationXp);
  Map<LeaderboardCategory, List<CompetitiveRanking>> get competitiveRankings =>
      Map.unmodifiable(_competitiveRankings);
  Set<String> get questBadges => Set.unmodifiable(_questBadges);

  int get currentRank {
    for (final user in _leaderboard) {
      if (user.isCurrentUser) return user.rank;
    }
    return _leaderboard.length;
  }

  MemberTier get memberTier =>
      MemberTierThresholds.tierForSeconds(spendableTimeSeconds);

  bool get hasVipRoomAccess =>
      spendableTimeSeconds >= MemberTierThresholds.vipRoomSeconds;

  bool get hasVvipRoomAccess =>
      spendableTimeSeconds >= MemberTierThresholds.vvipRoomSeconds;

  /// Standard package drinks cost 5 min on the VIP room tab when timeCost is 0.
  static const standardDrinkVipTabSeconds = 300;

  bool get isInVipRoom => _session?.isInVipRoom ?? false;

  int get vipRoomTimeSeconds => _session?.vipRoomTimeSeconds ?? 0;

  String? get activeVipRoomName {
    final slug = _session?.activeVipRoomSlug;
    if (slug == null) return null;
    for (final a in VenueActivities.all) {
      if (a.slug == slug) return a.name;
    }
    return slug;
  }

  /// Time price of a drink when it cannot ride the package allowance — package
  /// drinks carry no minute cost of their own, so they fall back to the same
  /// flat rate the VIP room tab uses.
  int _drinkFallbackCostSeconds(Drink drink) {
    if (drink.timeCostSeconds > 0) return drink.timeCostSeconds;
    return standardDrinkVipTabSeconds;
  }

  /// Seconds charged for a drink order (0 for package/cash paths).
  int drinkOrderCostSeconds(Drink drink, {bool payWithCash = false}) {
    if (payWithCash) return 0;
    if (isInVipRoom) return _drinkFallbackCostSeconds(drink);
    if (_canCoverDrinkWithEventWallet(drink)) {
      return _drinkFallbackCostSeconds(drink);
    }
    if (drink.isStandard && drinksAllowanceAvailable > 0) return 0;
    return _drinkFallbackCostSeconds(drink);
  }

  bool _canCoverDrinkWithEventWallet(Drink drink) {
    final cost = _drinkFallbackCostSeconds(drink);
    final attendance = _activeEventAttendance;
    if (attendance != null &&
        attendance.isLiveNow() &&
        attendance.walletSeconds >= cost) {
      return true;
    }
    final hosted = activeHostedEvent;
    if (hosted != null && hosted.walletSeconds >= cost) return true;
    return false;
  }

  String? get _eventWalletEventId =>
      _activeEventAttendance?.eventId ?? activeHostedEvent?.id;

  int get _eventWalletSeconds {
    final hosted = activeHostedEvent;
    if (hosted != null) return hosted.walletSeconds;
    return _activeEventAttendance?.walletSeconds ?? 0;
  }

  /// True when this member should ride the shared event wallet timer.
  bool get _eventWalletDecayActive {
    final hosted = activeHostedEvent;
    if (hosted != null && hosted.walletSeconds > 0) return true;
    final attendance = _activeEventAttendance;
    if (attendance == null) return false;
    return attendance.isLiveNow() && attendance.walletSeconds > 0;
  }

  bool canAffordDrink(Drink drink, {bool payWithCash = false}) {
    if (!isInsideClub) return false;
    if (payWithCash) return true;
    if (isInVipRoom) {
      return vipRoomTimeSeconds >= _drinkFallbackCostSeconds(drink);
    }
    if (_canCoverDrinkWithEventWallet(drink)) return true;
    if (drink.isStandard && drinksAllowanceAvailable > 0) return true;
    return timeBalance >= _drinkFallbackCostSeconds(drink);
  }

  /// True when a standard drink has to be paid for because the package
  /// allowance is used up (or already committed to orders at the bar).
  bool drinkFallsBackToPaidTime(Drink drink) {
    if (!drink.isStandard || isInVipRoom) return false;
    if (_canCoverDrinkWithEventWallet(drink)) return false;
    return drinksAllowanceAvailable < 1;
  }

  static MemberTier _tierForSeconds(int seconds) =>
      MemberTierThresholds.tierForSeconds(seconds);

  @override
  void notifyListeners() {
    if (_loungeInitialized) {
      _recalculateLeaderboardRanks();
    }
    super.notifyListeners();
  }

  bool get hasPaidSession =>
      _session != null &&
      _session!.phase != SessionPhase.none &&
      _session!.phase != SessionPhase.completed;

  /// Pass is active until exit scan — time can hit zero while still inside.
  bool get hasActiveClubPass =>
      _session != null &&
      (_session!.phase == SessionPhase.insideClub ||
          _session!.phase == SessionPhase.awaitingExitScan ||
          _session!.phase == SessionPhase.paidAwaitingEntry);

  bool get isTimeDepleted =>
      _session?.phase == SessionPhase.insideClub && !_meterShouldRun;

  bool get canSpendTime =>
      _session?.phase == SessionPhase.insideClub && timeBalance > 0;

  bool get isInsideClub => _session?.phase == SessionPhase.insideClub;

  /// True while a wallet mutation (order, VIP, toast, tip) is in flight.
  bool get isWalletBusy => _walletBusy;

  int get timeBalance => _user?.timeBalanceSeconds ?? 0;

  static const int passPurchaseMinSeconds = 5 * 60;

  /// Wallet is the only time currency (admin, mobile, and DB stay in sync).
  int get totalLoadSeconds => timeBalance;

  bool get canPurchaseNewPass =>
      !hasActiveClubPass && timeBalance < passPurchaseMinSeconds;

  bool get hasActiveLoad => timeBalance >= passPurchaseMinSeconds;

  /// Spendable time right now — same as wallet everywhere.
  int get spendableTimeSeconds => timeBalance;

  /// Time available to spend in lounge / pass the glass flows.
  int get ownedTimeSeconds => spendableTimeSeconds;

  /// Time snapshot for purchase animations.
  int get activeTimeSeconds => spendableTimeSeconds;

  bool get canUseTimeBalance =>
      isMember && sessionPhase == SessionPhase.none && timeBalance > 0;

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    await Future.wait([
      _loadBranches(),
      ClubPackageService().listActivePackages(),
      DrinkCatalogService().listActiveDrinks(),
    ]);
    await _sessionStore.load();
    await _drinkOrders.ensureLoaded();
    _drinkOrders.addListener(_onDrinkOrdersChanged);
    await _sounds.ensureLoaded();
    await _liveActivity.init();
    await _initPushDelivery();
    _user = await _auth.getCurrentUser();
    _selectedBranch = _resolveBranchSelection(_user?.branch ?? _selectedBranch);
    _sessionStore.addListener(_onSessionStoreChanged);

    if (_user != null && _user!.isMember) {
      await _loadPersistedCheckoutReceipt();
      await _loadTimeEconomyProgress();
      if (_checkoutReceipt == null) {
        await _restoreActiveSession();
      }
      _syncLiveActivity();
      await _refreshTutorialFlag();
      await _loadWelcomedScanKeys();
      await _loadEventCache();
      await refreshEventState();
      if (isInsideClub) {
        // Restored a visit that is already inside — the door scan may have
        // landed while the app was closed.
        _syncEventCheckInWatch(restart: true);
        startEventAttendanceWatch();
      }
      startSocialInboxPolling();
      unawaited(_registerPushTokens());
    }

    // Sync after the visit is restored so the queue can be scoped to it.
    await _syncDrinkOrders();

    _startCurrencyRealtime();

    _isLoading = false;
    unawaited(_processDeliveredDrinkOrders());
    notifyListeners();
  }

  Future<void> _loadBranches({String? preferredName}) async {
    final fetched = await _branches.listActiveBranches();
    _availableBranches = fetched.isEmpty
        ? BranchService.defaultBranches
        : fetched;
    _selectedBranch = _resolveBranchSelection(preferredName ?? _selectedBranch);
  }

  String _resolveBranchSelection(String? preferred) {
    final names = _availableBranches.map((branch) => branch.name).toSet();
    if (preferred != null && names.contains(preferred)) {
      return preferred;
    }
    final userBranch = _user?.branch?.trim();
    if (userBranch != null && names.contains(userBranch)) {
      return userBranch;
    }
    final preferredDefault = _availableBranches
        .cast<BranchLocation?>()
        .firstWhere(
          (branch) => branch?.isDefault ?? false,
          orElse: () =>
              _availableBranches.isNotEmpty ? _availableBranches.first : null,
        );
    return preferredDefault?.name ?? BranchService.defaultBranches.first.name;
  }

  /// Session id of the visit in progress, or null when nothing is live — a
  /// completed visit must never leave orders looking like they wait at the bar.
  String? get _liveVisitSessionId {
    final session = _session;
    if (session == null) return null;
    if (session.phase == SessionPhase.completed) return null;
    if (_checkoutReceipt != null) return null;
    return session.id;
  }

  /// Staff own the whole queue; members only ever see their live visit.
  void _applyDrinkOrderScope() {
    if (_user == null) return;
    if (isStaff || _user!.isAdmin) {
      _drinkOrders.clearMemberScope();
    } else {
      _drinkOrders.setMemberScope(sessionId: _liveVisitSessionId);
    }
  }

  Future<void> _syncDrinkOrders() async {
    if (_user == null) return;
    _applyDrinkOrderScope();
    await _drinkOrders.syncAfterAuth();
  }

  void _onDrinkOrdersChanged() {
    unawaited(_processDeliveredDrinkOrders());
    _syncLiveActivity(force: true);
    notifyListeners();
  }

  void clearPendingDrinkDeliveryAlert() {
    if (_drinkDeliveryAlertQueue.isEmpty) return;
    _drinkDeliveryAlertQueue.removeAt(0);
    notifyListeners();
  }

  void clearPendingEventGuestWelcome() {
    if (_eventGuestWelcomeQueue.isEmpty) return;
    final alert = _eventGuestWelcomeQueue.removeAt(0);
    _welcomedScanKeys.add(alert.id);
    unawaited(_persistWelcomedScanKeys());
    notifyListeners();
  }

  Future<void> _initPushDelivery() async {
    _liveActivity.onPushToken = (token, {required kind}) {
      unawaited(
        _safety.registerPushToken(
          token: token,
          kind: kind,
          platform: _pushPlatform,
          environment: kDebugMode ? 'sandbox' : 'production',
          bundleId: 'com.intime.inTimeBartender',
        ),
      );
    };
    _push.onDeviceToken = (token) {
      unawaited(
        _safety.registerPushToken(
          token: token,
          kind: 'fcm',
          platform: _pushPlatform,
          environment: kDebugMode ? 'sandbox' : 'production',
          bundleId: 'com.intime.inTimeBartender',
        ),
      );
    };
    _push.onApnsToken = (token) {
      unawaited(
        _safety.registerPushToken(
          token: token,
          kind: 'apns',
          platform: 'ios',
          environment: kDebugMode ? 'sandbox' : 'production',
          bundleId: 'com.intime.inTimeBartender',
        ),
      );
    };
    // Foreground: refresh inbox so the island banner can show; skip OS local
    // banners (island is the in-app path). Background delivery stays on FCM/APNs.
    _push.shouldShowLocalInForeground = () => !_appInForeground;
    _push.onForegroundMessage = (_) {
      if (_user != null && _user!.isMember) {
        unawaited(refreshSocialInbox());
      }
    };
    await _push.init();
  }

  String get _pushPlatform =>
      defaultTargetPlatform == TargetPlatform.android ? 'android' : 'ios';

  Future<void> _registerPushTokens() async {
    await _push.refreshTokens();
    final token = _push.deviceToken;
    if (token != null && token.isNotEmpty) {
      await _safety.registerPushToken(
        token: token,
        kind: 'fcm',
        platform: _pushPlatform,
        environment: kDebugMode ? 'sandbox' : 'production',
        bundleId: 'com.intime.inTimeBartender',
      );
    }
    final apns = _push.apnsToken;
    if (apns != null && apns.isNotEmpty) {
      await _safety.registerPushToken(
        token: apns,
        kind: 'apns',
        platform: 'ios',
        environment: kDebugMode ? 'sandbox' : 'production',
        bundleId: 'com.intime.inTimeBartender',
      );
    }
    final live = _liveActivity.liveActivityPushToken;
    if (live != null && live.isNotEmpty) {
      await _safety.registerPushToken(
        token: live,
        kind: 'live_activity',
        platform: 'ios',
        environment: kDebugMode ? 'sandbox' : 'production',
        bundleId: 'com.intime.inTimeBartender',
      );
    }
  }

  /// Call from the root widget when app resumes / pauses.
  void setAppForeground(bool foreground) {
    _appInForeground = foreground;
    if (foreground) {
      unawaited(refreshSocialInbox());
      unawaited(refreshEventState());
      // Timers are throttled while suspended — rebuild the door-check-in watch
      // so a scan that happened in the background is picked up immediately.
      if (isInsideClub) {
        _syncEventCheckInWatch(restart: true);
        startEventAttendanceWatch();
      }
      if (_user != null) {
        unawaited(_syncDrinkOrders());
        // Re-pull wallet / profile so a cold resume still feels signed-in live.
        unawaited(refreshWalletFromCloud());
      }
      // Re-bind tokens after resume — APNs/FCM can rotate while suspended.
      if (_user != null && _user!.isMember) {
        unawaited(_registerPushTokens());
      }
      // Re-anchor Live Activity end date from the live wallet (Dart timer may have
      // paused while suspended; timerInterval keeps ticking from the last end date).
      _syncLiveActivity(force: true);
      // Surface any threshold crossed while backgrounded.
      if (_timeLowAlertQueue.isNotEmpty) notifyListeners();
    }
  }

  Future<void> _refreshTutorialFlag() async {
    if (_user == null || !_user!.isMember || _user!.isStaff) {
      _needsMemberTutorial = false;
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    _needsMemberTutorial =
        !(prefs.getBool('$_tutorialSeenPrefix${_user!.id}') ?? false);
  }

  Future<void> completeMemberTutorial() async {
    if (_user == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_tutorialSeenPrefix${_user!.id}', true);
    _needsMemberTutorial = false;
    notifyListeners();
  }

  Future<void> _restoreActiveSession() async {
    if (_user == null || !_user!.isMember) return;
    if (_checkoutReceipt != null) return;

    _user = await _auth.refreshProfile() ?? _user;

    final s = await _sessionStore.fetchActiveSessionForMember(_user!.id);
    if (s == null) {
      // Do not wipe a frozen checkout receipt while restoring.
      if (_checkoutReceipt == null) _session = null;
      return;
    }

    await _applyRestoredSession(s);
    _user = await _auth.refreshProfile() ?? _user;
  }

  Future<void> _applyRestoredSession(ClubSessionRecord s) async {
    final fresh = await _sessionStore.fetchSessionFresh(s.id) ?? s;
    _session = fresh;
    _drinksOrdered = fresh.drinksOrdered;
    _applyDrinkOrderScope();
    await _sessionStore.subscribeToSession(fresh.id);

    if (_session!.phase == SessionPhase.insideClub) {
      _initLoungeState();
      if (_meterShouldRun) {
        _startTimer();
      }
      _startQrRefresh(QrPurpose.exit);
      _scheduleAutoBadgeOut(_session);
      startSocialInboxPolling();
      _syncLiveActivity(force: true);
    } else if (_session!.phase == SessionPhase.awaitingExitScan) {
      if (_meterShouldRun) {
        _startTimer();
      }
      _startQrRefresh(QrPurpose.exit);
      _scheduleAutoBadgeOut(_session);
      _syncLiveActivity(force: true);
    } else if (_session!.phase == SessionPhase.paidAwaitingEntry) {
      _startQrRefresh(QrPurpose.entry);
      _startSyncPolling();
      _autoBadgeOutTimer?.cancel();
      await _maybeSkipEntryDoorScan();
    }
  }

  void _onSessionStoreChanged() {
    // Exit receipt is frozen — ignore further session sync so summary can't vanish.
    if (_checkoutReceipt != null) return;

    if (_session == null) return;
    final updated = _sessionStore.getSession(_session!.id);
    if (updated == null) return;

    final previousPhase = _session!.phase;

    // Capture BEFORE replacing _session, so we never lose awaiting→completed.
    if (previousPhase == SessionPhase.awaitingExitScan &&
        updated.phase == SessionPhase.completed) {
      _timer?.cancel();
      _qrRefreshTimer?.cancel();
      _syncTimer?.cancel();
      _captureCheckoutReceipt(updated);
      notifyListeners();
      unawaited(_finalizeCheckoutReceipt(updated));
      return;
    }

    // Also handle staff confirming exit while still marked inside (skip awaiting).
    if (previousPhase == SessionPhase.insideClub &&
        updated.phase == SessionPhase.completed) {
      _timer?.cancel();
      _qrRefreshTimer?.cancel();
      _syncTimer?.cancel();
      _captureCheckoutReceipt(updated);
      notifyListeners();
      unawaited(_finalizeCheckoutReceipt(updated));
      return;
    }

    _session = updated;
    _drinksOrdered = updated.drinksOrdered;

    if (previousPhase == SessionPhase.paidAwaitingEntry &&
        updated.phase == SessionPhase.insideClub) {
      _timer?.cancel();
      _initLoungeState();
      _startQrRefresh(QrPurpose.exit);
      _scheduleAutoBadgeOut(updated);
      _syncTimer?.cancel();
      unawaited(_sounds.playDoorLatch());
      _onEnteredClub();
    }

    if (previousPhase == SessionPhase.awaitingExitScan &&
        updated.phase == SessionPhase.insideClub) {
      _startTimer();
      _startQrRefresh(QrPurpose.exit);
      _scheduleAutoBadgeOut(updated);
    }

    if (updated.phase == SessionPhase.insideClub ||
        updated.phase == SessionPhase.awaitingExitScan) {
      _scheduleAutoBadgeOut(updated);
    } else {
      _autoBadgeOutTimer?.cancel();
    }

    notifyListeners();
    _syncLiveActivity(force: true);
  }

  void _captureCheckoutReceipt(ClubSessionRecord session) {
    _checkoutReceipt = ClubSessionRecord(
      id: session.id,
      memberId: session.memberId,
      memberName: session.memberName.isNotEmpty
          ? session.memberName
          : (_user?.name ?? 'Guest'),
      purchasedSeconds: session.purchasedSeconds,
      amountPaid: session.amountPaid,
      branch: session.branch,
      phase: SessionPhase.completed,
      remainingSeconds: timeBalance,
      drinksOrdered: session.drinksOrdered > 0
          ? session.drinksOrdered
          : _drinksOrdered,
      enteredAt: session.enteredAt != null
          ? ClubSessionRecord.correctToLocal(session.enteredAt!)
          : null,
      // Stamp exit from the device clock — don't trust a skewed DB timestamptz alone.
      exitedAt: DateTime.now(),
    );
    _session = _checkoutReceipt;
    _currentQr = null;
    _autoBadgeOutTimer?.cancel();
    // Visit is over — drop anything still queued so it cannot come back later.
    _applyDrinkOrderScope();
    stopEventAttendanceWatch();
    _eventGuestWelcomeQueue.clear();
    _resetTimeLowWarnings();
    _lastAnnouncedBand = null;
    unawaited(_clearSocialPresence());
    unawaited(_persistCheckoutReceipt());
    unawaited(_finalizeVisitEconomy());
    unawaited(_sounds.playCheckoutChime());
    unawaited(_liveActivity.end());
  }

  Future<void> _loadPersistedCheckoutReceipt() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_checkoutReceiptKey);
      if (raw == null || raw.isEmpty) return;
      final receipt = ClubSessionRecord.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      if (_user != null && receipt.memberId != _user!.id) {
        await prefs.remove(_checkoutReceiptKey);
        return;
      }
      _checkoutReceipt = receipt;
      _session = receipt;
      _currentQr = null;
    } catch (_) {
      // Corrupt receipt — ignore and continue normal restore.
    }
  }

  Future<void> _persistCheckoutReceipt() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_checkoutReceipt == null) {
        await prefs.remove(_checkoutReceiptKey);
        return;
      }
      await prefs.setString(
        _checkoutReceiptKey,
        jsonEncode(_checkoutReceipt!.toJson()),
      );
    } catch (_) {}
  }

  Future<void> _clearPersistedCheckoutReceipt() async {
    _checkoutReceipt = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_checkoutReceiptKey);
    } catch (_) {}
  }

  Future<void> _finalizeCheckoutReceipt(ClubSessionRecord session) async {
    _localTimeMutations++;
    _pendingWalletCredit = null;
    try {
      await _bankTimeForCompletedVisit(SessionPhase.awaitingExitScan, session);
      _pendingWalletCredit = null;
      if (_checkoutReceipt != null) {
        _checkoutReceipt!.remainingSeconds = timeBalance;
        // Re-read timestamps from DB so Entered/Exited match the staff scan clock.
        try {
          final fresh = await _sessionStore.fetchSessionFresh(session.id);
          if (fresh?.enteredAt != null) {
            _checkoutReceipt!.enteredAt = ClubSessionRecord.correctToLocal(
              fresh!.enteredAt!,
            );
          }
          // Keep device exit stamp unless DB exit is plausibly the same night.
          if (fresh?.exitedAt != null) {
            final fromDb = ClubSessionRecord.correctToLocal(fresh!.exitedAt!);
            final localExit = _checkoutReceipt!.exitedAt ?? DateTime.now();
            if (fromDb.difference(localExit).abs() < const Duration(hours: 2)) {
              _checkoutReceipt!.exitedAt = fromDb;
            }
          }
        } catch (_) {}
        _session = _checkoutReceipt;
        unawaited(_persistCheckoutReceipt());
      }
    } catch (_) {
      // Receipt already captured — never drop the summary on bank/sync errors.
    } finally {
      _localTimeMutations = mathMax(0, _localTimeMutations - 1);
      _pendingWalletCredit = null;
    }

    try {
      await _sessionStore.subscribeToSession(null);
    } catch (_) {}
    // Keep pointing at the frozen receipt forever until beginNewVisit.
    if (_checkoutReceipt != null) {
      _session = _checkoutReceipt;
    }
    notifyListeners();
  }

  Future<void> _onEnteredClub() async {
    if (_session?.phase == SessionPhase.insideClub && _meterShouldRun) {
      _startTimer();
    }
    _scheduleAutoBadgeOut(_session);
    startSocialInboxPolling();
    startEventAttendanceWatch();
    if (_user != null) {
      await _syncDrinkOrders();
      await _processDeliveredDrinkOrders();
      await refreshEventState();
      _syncEventCheckInWatch(restart: true);
    }
    notifyListeners();
  }

  void _scheduleAutoBadgeOut(ClubSessionRecord? session) {
    _autoBadgeOutTimer?.cancel();
    if (session == null || _checkoutReceipt != null) return;
    final autoExitAt = session.autoBadgeOutAt;
    if (autoExitAt == null) return;
    if (session.phase != SessionPhase.insideClub &&
        session.phase != SessionPhase.awaitingExitScan) {
      return;
    }

    final delay = autoExitAt.difference(DateTime.now());
    if (!delay.isNegative) {
      _autoBadgeOutTimer = Timer(delay, () {
        unawaited(_completeAutoBadgeOutIfNeeded());
      });
      return;
    }

    unawaited(_completeAutoBadgeOutIfNeeded());
  }

  Future<void> _completeAutoBadgeOutIfNeeded() async {
    final session = _session;
    if (session == null || _checkoutReceipt != null) return;
    if (!session.isAutoBadgeOutOverdue()) return;

    try {
      await _sessionStore.completeStaleSessions(memberId: _user?.id);
      final fresh = await _sessionStore.fetchSessionFresh(session.id);
      if (fresh == null || fresh.phase != SessionPhase.completed) return;

      _timer?.cancel();
      _qrRefreshTimer?.cancel();
      _syncTimer?.cancel();
      _autoBadgeOutTimer?.cancel();
      _captureCheckoutReceipt(fresh);
      notifyListeners();
      unawaited(_finalizeCheckoutReceipt(fresh));
    } catch (_) {
      _autoBadgeOutTimer?.cancel();
      _autoBadgeOutTimer = Timer(const Duration(minutes: 5), () {
        unawaited(_completeAutoBadgeOutIfNeeded());
      });
    }
  }

  Future<SignUpResult> signUp({
    required String name,
    required String email,
    required String password,
    required DateTime birthdate,
  }) async {
    final result = await _auth.signUp(
      name: name,
      email: email,
      password: password,
      birthdate: birthdate,
    );
    if (result.user != null) {
      _user = result.user;
      _needsMemberTutorial = true;
      _startCurrencyRealtime();
      unawaited(refreshEventState());
      notifyListeners();
    }
    return result;
  }

  Future<void> resendSignupConfirmation(String email) =>
      _auth.resendSignupConfirmation(email);

  Future<MemberUser> login({
    required String email,
    required String password,
  }) async {
    _user = await _auth.login(email: email, password: password);

    try {
      if (_user!.isMember) {
        await _restoreActiveSession();
      } else {
        _session = null;
        await _sessionStore.subscribeToSession(null);
      }
    } catch (_) {
      // Login succeeded — retry profile refresh without blocking entry.
      _user = await _auth.refreshProfile() ?? _user;
    }

    await _refreshTutorialFlag();
    await _loadWelcomedScanKeys();
    await _loadEventCache();
    await refreshEventState();
    if (isInsideClub) {
      _syncEventCheckInWatch(restart: true);
      startEventAttendanceWatch();
    }
    _startCurrencyRealtime();
    startSocialInboxPolling();
    unawaited(_registerPushTokens());
    await _syncDrinkOrders();
    await _processDeliveredDrinkOrders();

    notifyListeners();
    return _user!;
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _auth.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }

  /// Staff bar queue — pull latest orders from cloud / local cache.
  Future<void> refreshDrinkOrderQueue() => _syncDrinkOrders();

  void _startCurrencyRealtime() {
    if (!usesCloud || _user == null) return;

    _auth.startProfileCurrencyWatch((user) {
      unawaited(_onRemoteProfileCurrency(user));
    });
  }

  /// Pull latest wallet from Supabase (desk loads). Safe to call on a timer.
  Future<void> refreshWalletFromCloud() async {
    if (!usesCloud || _user == null) return;
    try {
      final fresh = await _auth.refreshProfile();
      if (fresh == null) return;
      final prev = _user!.timeBalanceSeconds;
      if (fresh.timeBalanceSeconds == prev) return;
      await _onRemoteProfileCurrency(fresh);
    } catch (_) {
      // Keep last known balance — next poll / realtime may succeed.
    }
  }

  /// Live desk / admin credits — celebrate meaningful increases from the cloud.
  Future<void> _onRemoteProfileCurrency(MemberUser user) async {
    // Exit checkout is locked — update wallet quietly, never overlay the receipt.
    if (_checkoutReceipt != null) {
      _user = user;
      _pendingWalletCredit = null;
      _checkoutReceipt!.remainingSeconds = user.timeBalanceSeconds;
      _session = _checkoutReceipt;
      notifyListeners();
      return;
    }

    final prev = _user?.timeBalanceSeconds ?? 0;
    final next = user.timeBalanceSeconds;
    final delta = next - prev;

    // Local timer ticks + sync debt: ignore tiny drift; apply real credits.
    if (delta.abs() <= 3 && _timerSyncDebt > 0 && _localTimeMutations == 0) {
      return;
    }

    if (delta > 3 && _localTimeMutations == 0) {
      _pendingWalletCredit = PendingWalletCredit(
        fromSeconds: prev,
        toSeconds: next,
        title: 'TIME LANDED',
        subtitle: 'Cash desk · wallet updated live',
      );
      _timerSyncDebt = 0;
      unawaited(_sounds.playTimePour());
    }

    _user = user;

    if (delta > 3) {
      _resumeTimerIfNeeded();
      _syncLiveActivity(force: true);
      _maybeWarnTimerLow();
    }

    notifyListeners();
  }

  void clearPendingWalletCredit() {
    if (_pendingWalletCredit == null) return;
    _pendingWalletCredit = null;
    notifyListeners();
  }

  Future<T> _withLocalTimeMutation<T>(Future<T> Function() action) async {
    _localTimeMutations++;
    try {
      return await action();
    } finally {
      _localTimeMutations = mathMax(0, _localTimeMutations - 1);
    }
  }

  static int mathMax(int a, int b) => a > b ? a : b;

  static int mathMin(int a, int b) => a < b ? a : b;

  void _stopCurrencyRealtime() {
    _auth.stopProfileCurrencyWatch();
  }

  Future<void> logout() async {
    // Captured before sign-out clears the user; the event cache is per member.
    final previousUserId = _user?.id;
    _stopCurrencyRealtime();
    stopSocialInboxPolling();
    stopEventAttendanceWatch();
    _clearSocialAlertQueues();
    await _flushWalletTimerSync();
    _timer?.cancel();
    _qrRefreshTimer?.cancel();
    _syncTimer?.cancel();
    _sessionStore.unsubscribe();
    await _clearSocialPresence();
    await _safety.clearPushTokens();
    _drinkOrders.stopRealtime();
    await _drinkOrders.clearCache();
    await _auth.logout();
    _user = null;
    _session = null;
    await _clearPersistedCheckoutReceipt();
    _currentQr = null;
    _drinksOrdered = 0;
    _loungeInitialized = false;
    _liveSocialTitle = null;
    _liveSocialBody = null;
    _liveSocialSender = null;
    _hostedEvents = [];
    _eventInvites = [];
    _activeEventAttendance = null;
    _acceptedEventInvite = null;
    _lastStaffEventCheckIn = null;
    _pendingEventInviteCode = null;
    _pendingEventInviteLocation = null;
    _eventWalletPromptedForId = null;
    _eventGuestWelcomeQueue.clear();
    _welcomedScanKeys.clear();
    await _clearEventCache(previousUserId);
    unawaited(_liveActivity.end());
    notifyListeners();
  }

  void setPendingEventInviteCode(String? code) {
    final trimmed = code?.trim();
    _pendingEventInviteCode = trimmed == null || trimmed.isEmpty
        ? null
        : trimmed.toUpperCase();
    _pendingEventInviteLocation = _pendingEventInviteCode == null
        ? null
        : Uri(
            path: '/event-invite',
            queryParameters: {'code': _pendingEventInviteCode!},
          ).toString();
    notifyListeners();
  }

  void setPendingEventInviteLocation(String? location) {
    final trimmed = location?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      _pendingEventInviteLocation = null;
      _pendingEventInviteCode = null;
      notifyListeners();
      return;
    }

    final normalizedLocation = DeepLinkService.mapInviteLocation(
      Uri.tryParse(trimmed),
    );
    if (normalizedLocation == null) return;
    final uri = Uri.parse(normalizedLocation);

    _pendingEventInviteLocation = Uri(
      path: '/event-invite',
      queryParameters: {
        if ((uri.queryParameters['token'] ?? '').trim().isNotEmpty)
          'token': uri.queryParameters['token']!.trim(),
        if ((uri.queryParameters['code'] ?? '').trim().isNotEmpty)
          'code': uri.queryParameters['code']!.trim().toUpperCase(),
      },
    ).toString();
    _pendingEventInviteCode =
        uri.queryParameters['code']?.trim().isNotEmpty == true
        ? uri.queryParameters['code']!.trim().toUpperCase()
        : null;
    notifyListeners();
  }

  void clearPendingEventInvite({bool clearAccepted = false}) {
    _pendingEventInviteCode = null;
    _pendingEventInviteLocation = null;
    if (clearAccepted) _acceptedEventInvite = null;
    notifyListeners();
  }

  void clearLastStaffEventCheckIn() {
    if (_lastStaffEventCheckIn == null) return;
    _lastStaffEventCheckIn = null;
    notifyListeners();
  }

  void acknowledgeHostedEventWalletPrompt() {
    final event = activeHostedEvent;
    if (event == null) return;
    _eventWalletPromptedForId = event.id;
    notifyListeners();
  }

  void startEventAttendanceWatch() {
    final userId = _user?.id;
    if (userId == null || !usesMemberSurface || isStaff) return;
    _events.startEventGuestWatch(
      memberId: userId,
      onChanged: () => unawaited(refreshEventState()),
    );
  }

  void stopEventAttendanceWatch() {
    _events.stopEventGuestWatch();
    _events.stopHostedEventGuestWatch();
    _eventCheckInPoll?.cancel();
    _eventCheckInPoll = null;
    _eventCheckInPollAttempts = 0;
  }

  void startHostedEventWatch() {
    final event = activeHostedEvent;
    if (event == null || !isInsideClub) {
      _events.stopHostedEventGuestWatch();
      return;
    }

    _events.startHostedEventGuestWatch(
      eventId: event.id,
      onGuestUpdated: (row) {
        if (row['status'] != 'checked_in') return;
        final guestId = row['id'] as String?;
        final guestName = row['guest_name'] as String? ?? 'A guest';
        if (guestId == null) return;
        _enqueueEventGuestCheckinAlert(
          EventGuestCheckinAlert.fromGuestRow(
            eventGuestId: guestId,
            guestName: guestName,
            eventTitle: event.title,
            eventId: event.id,
          ),
        );
      },
    );
  }

  Future<void> refreshEventHostAlerts() async {
    final user = _user;
    if (user == null || !user.usesMemberSurface) return;

    try {
      final alerts = await _events.listHostNotifications(unreadOnly: true);
      for (final alert in alerts) {
        _enqueueEventGuestCheckinAlert(alert);
      }
    } catch (_) {}
  }

  bool _enqueueEventGuestCheckinAlert(EventGuestCheckinAlert alert) {
    if (_seenEventGuestCheckinIds.contains(alert.id)) return false;
    if (_eventGuestCheckinQueue.any((item) => item.id == alert.id)) {
      return false;
    }

    final becameHead = _eventGuestCheckinQueue.isEmpty;
    _eventGuestCheckinQueue.add(alert);
    if (becameHead) _surfaceEventGuestCheckinHead(alert);
    notifyListeners();
    return true;
  }

  void _surfaceEventGuestCheckinHead(EventGuestCheckinAlert alert) {
    unawaited(_sounds.playKnock());
    _surfaceSocialDelivery(
      id: alert.id,
      title: alert.title,
      body: alert.body,
      senderName: alert.guestName,
      updateLive: true,
    );
  }

  void clearPendingEventGuestCheckinAlert() {
    if (_eventGuestCheckinQueue.isEmpty) return;
    final alert = _eventGuestCheckinQueue.removeAt(0);
    _seenEventGuestCheckinIds.add(alert.id);
    _clearLiveSocialAlert();
    if (_eventGuestCheckinQueue.isNotEmpty) {
      _surfaceEventGuestCheckinHead(_eventGuestCheckinQueue.first);
    } else {
      _promoteNextAlertSurface();
    }
    notifyListeners();
  }

  Future<void> acknowledgeEventGuestCheckinAlert(
    EventGuestCheckinAlert alert,
  ) async {
    _seenEventGuestCheckinIds.add(alert.id);
    _eventGuestCheckinQueue.removeWhere((item) => item.id == alert.id);
    _clearLiveSocialAlert();

    if (_eventGuestCheckinQueue.isNotEmpty) {
      _surfaceEventGuestCheckinHead(_eventGuestCheckinQueue.first);
    } else {
      _promoteNextAlertSurface();
    }
    notifyListeners();

    if (!alert.id.startsWith('guest-')) {
      await _events.markHostNotificationRead(alert.id);
    }
    if (_eventGuestCheckinQueue.isEmpty) {
      await refreshEventHostAlerts();
    }
  }

  /// Venue label used to scope event door check-in / welcome (session first).
  String? get _eventCheckInBranch => _session?.branch.trim().isNotEmpty == true
      ? _session!.branch
      : (_selectedBranch.trim().isEmpty ? null : _selectedBranch);

  /// The event this member should be welcomed to, from whichever read answered.
  EventWelcomeCandidate? get _eventWelcomeCandidate =>
      resolveEventWelcomeCandidate(
        attendance: _activeEventAttendance,
        invites: _eventInvites,
        sessionBranch: _eventCheckInBranch,
        now: DateTime.now(),
      );

  /// True while this member is inside the club waiting for (or already given)
  /// an event door check-in that has not been welcomed yet.
  bool get _awaitingEventCheckIn {
    if (!isInsideClub || isStaff) return false;
    final candidate = _eventWelcomeCandidate;
    if (candidate == null) return false;
    // Already scanned in: keep watching only until the welcome is delivered.
    if (candidate.isCheckedIn) {
      return !_welcomedScanKeys.contains(candidate.welcomeKey);
    }
    // On the list for tonight — the door scan can land at any moment.
    return true;
  }

  /// Keeps a short authoritative poll running while a door check-in is
  /// expected. Realtime on `event_guests` is the fast path; this is the
  /// fallback for devices where the socket never connects.
  void _syncEventCheckInWatch({bool restart = false}) {
    if (!_awaitingEventCheckIn || pendingEventGuestWelcome != null) {
      _eventCheckInPoll?.cancel();
      _eventCheckInPoll = null;
      _eventCheckInPollAttempts = 0;
      return;
    }

    if (restart) {
      _eventCheckInPoll?.cancel();
      _eventCheckInPoll = null;
      _eventCheckInPollAttempts = 0;
    }
    if (_eventCheckInPoll != null) return;

    // Immediate read so a check-in that landed while we were idle is not
    // delayed until the first periodic tick.
    unawaited(refreshEventState());

    _eventCheckInPoll = Timer.periodic(_eventCheckInPollInterval, (timer) {
      if (!_awaitingEventCheckIn || pendingEventGuestWelcome != null) {
        timer.cancel();
        _eventCheckInPoll = null;
        _eventCheckInPollAttempts = 0;
        return;
      }
      _eventCheckInPollAttempts += 1;
      if (_eventCheckInPollAttempts > _eventCheckInPollMaxAttempts) {
        timer.cancel();
        _eventCheckInPoll = null;
        return;
      }
      unawaited(refreshEventState());
    });
  }

  void _evaluateEventGuestWelcome() {
    final candidate = _eventWelcomeCandidate;
    if (!shouldEnqueueEventGuestWelcome(
      isInsideClub: isInsideClub,
      isStaff: isStaff,
      eventId: candidate?.eventId,
      welcomeKey: candidate?.welcomeKey,
      isCheckedIn: candidate?.isCheckedIn ?? false,
      isEventOn: candidate?.isEventOn ?? false,
      welcomedKeys: _welcomedScanKeys,
      queuedKeys: _eventGuestWelcomeQueue.map((alert) => alert.id),
      eventBranch: candidate?.branch,
      sessionBranch: _eventCheckInBranch,
    )) {
      return;
    }

    _eventGuestWelcomeQueue.add(candidate!.toAlert());
    _eventCheckInPoll?.cancel();
    _eventCheckInPoll = null;
    _eventCheckInPollAttempts = 0;
    notifyListeners();
  }

  /// Restores the last known invites, hosted events and attendance so the
  /// Events & Calendar hub is populated the moment it opens — before the RPCs
  /// answer, and even when the venue Wi-Fi is unusable.
  Future<void> _loadEventCache() async {
    final userId = _user?.id;
    if (userId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_eventCachePrefix$userId');
      if (raw == null || raw.isEmpty) return;
      final map = jsonDecode(raw) as Map<String, dynamic>;

      final invites = (map['invites'] as List<dynamic>? ?? const [])
          .map(
            (row) => EventInvitePreview.fromJson(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList();
      final hosted = (map['hosted'] as List<dynamic>? ?? const [])
          .map(
            (row) =>
                ClubEventRecord.fromJson(Map<String, dynamic>.from(row as Map)),
          )
          .toList();

      // Only adopt the cache where the live read has nothing yet, so a refresh
      // that already landed is never rolled back to stale rows.
      if (_eventInvites.isEmpty) _eventInvites = invites;
      if (_hostedEvents.isEmpty) _hostedEvents = hosted;

      final attendanceRow = map['attendance'];
      if (_activeEventAttendance == null && attendanceRow != null) {
        final attendance = ActiveEventAttendance.fromJson(
          Map<String, dynamic>.from(attendanceRow as Map),
        );
        if (_cachedAttendanceIsStillOn(attendance)) {
          _activeEventAttendance = attendance;
        }
      }
    } catch (_) {
      // Corrupt or outdated cache — the network read is the source of truth.
    }
  }

  /// A cached attendance row is only worth showing while the event could still
  /// be running; otherwise the hub would claim a finished night is tonight.
  bool _cachedAttendanceIsStillOn(ActiveEventAttendance attendance) {
    final now = DateTime.now();
    final endsAt = attendance.endsAt;
    if (endsAt != null) return now.isBefore(endsAt);
    return now.difference(attendance.startsAt) < const Duration(hours: 12);
  }

  Future<void> _persistEventCache() async {
    final userId = _user?.id;
    if (userId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '$_eventCachePrefix$userId',
        jsonEncode({
          'invites': _eventInvites
              .map((invite) => invite.toJson())
              .toList(growable: false),
          'hosted': _hostedEvents
              .map((event) => event.toJson())
              .toList(growable: false),
          'attendance': _activeEventAttendance?.toJson(),
        }),
      );
    } catch (_) {
      // Non-fatal: the hub still works, it just starts empty next launch.
    }
  }

  Future<void> _clearEventCache(String? userId) async {
    if (userId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_eventCachePrefix$userId');
    } catch (_) {}
  }

  Future<void> _loadWelcomedScanKeys() async {
    final userId = _user?.id;
    _welcomedScanKeys.clear();
    if (userId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _welcomedScanKeys.addAll(
        prefs.getStringList('$_welcomedScansPrefix$userId') ?? const [],
      );
    } catch (_) {
      // Fresh install / storage denied — dedupe falls back to in-memory only.
    }
  }

  Future<void> _persistWelcomedScanKeys() async {
    final userId = _user?.id;
    if (userId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      // Keep the list bounded; only the latest scan of an event can re-trigger.
      final recent = _welcomedScanKeys.toList();
      final trimmed = recent.length <= 20
          ? recent
          : recent.sublist(recent.length - 20);
      _welcomedScanKeys
        ..clear()
        ..addAll(trimmed);
      await prefs.setStringList('$_welcomedScansPrefix$userId', trimmed);
    } catch (_) {
      // Non-fatal: the in-memory set still prevents repeats this run.
    }
  }

  Future<void> refreshEventState() async {
    final user = _user;
    if (user == null || !user.usesMemberSurface) {
      _hostedEvents = [];
      _eventInvites = [];
      _activeEventAttendance = null;
      return;
    }
    // Coalesce instead of dropping — a skipped refresh used to lose the door
    // check-in that a poll tick was fetching.
    if (_eventSyncing) {
      _eventRefreshQueued = true;
      return;
    }
    _eventSyncing = true;
    try {
      // Attach any admin guest-list rows that match this account's email
      // before reading invites — otherwise FIESTA-style lists stay invisible.
      await _events.linkPendingGuestRowsForCurrentUser();

      // Each read is isolated so one failing RPC cannot blank the others.
      final results = await Future.wait<dynamic>([
        _guarded(_events.listHostedEvents, _hostedEvents),
        _guarded(_events.listMyInvites, _eventInvites),
        _guarded(_events.fetchActiveAttendance, _activeEventAttendance),
      ]);
      _hostedEvents = results[0] as List<ClubEventRecord>;
      _eventInvites = results[1] as List<EventInvitePreview>;
      _activeEventAttendance = results[2] as ActiveEventAttendance?;
      unawaited(_persistEventCache());
      _evaluateEventGuestWelcome();
      _syncEventCheckInWatch();
      startHostedEventWatch();
      unawaited(refreshEventHostAlerts());

      final activeHost = activeHostedEvent;
      if (activeHost == null ||
          activeHost.walletSeconds > activeHost.walletLowThresholdSeconds) {
        _eventWalletPromptedForId = null;
      }

      if (_acceptedEventInvite != null) {
        final refreshed = _eventInvites.cast<EventInvitePreview?>().firstWhere(
          (invite) => invite?.inviteId == _acceptedEventInvite!.inviteId,
          orElse: () => null,
        );
        if (refreshed != null) {
          _acceptedEventInvite = refreshed;
        }
      }

      // Host event wallet and VIP room tab cannot both be active.
      await _clearVipRoomIfHostedEventConflict();

      // Event wallet may become the active decay pool while already inside.
      if (_meterShouldRun && (_timer == null || !(_timer?.isActive ?? false))) {
        _startTimer();
      }
    } catch (_) {
      // Keep the last known event state so UI can degrade gracefully offline.
    } finally {
      _eventSyncing = false;
      notifyListeners();
      if (_eventRefreshQueued) {
        _eventRefreshQueued = false;
        unawaited(refreshEventState());
      }
    }
  }

  /// Runs [read] and falls back to [previous] when the RPC fails or the row
  /// cannot be parsed, so a partial backend outage degrades one section only.
  Future<T> _guarded<T>(Future<T> Function() read, T previous) async {
    try {
      return await read();
    } catch (error) {
      debugPrint('Event state read failed: $error');
      return previous;
    }
  }

  Future<(EventInvitePreview?, String?)> acceptEventInvite({
    String? code,
    String acceptedVia = 'code',
  }) async {
    final resolvedCode = (code ?? _pendingEventInviteCode)
        ?.trim()
        .toUpperCase();
    if (resolvedCode == null || resolvedCode.isEmpty) {
      return (null, 'Enter an invite code first.');
    }
    if (_user == null) return (null, 'Sign in to accept this invite.');
    try {
      final invite = await _events.acceptInvite(
        resolvedCode,
        acceptedVia: acceptedVia,
      );
      _pendingEventInviteCode = null;
      _pendingEventInviteLocation = null;
      _acceptedEventInvite = invite;
      await refreshEventState();
      _addFeedEvent('confirmed event invite for ${invite.title}');
      return (invite, null);
    } catch (error) {
      return (null, _events.friendlyError(error));
    }
  }

  Future<(EventInvitePreview?, String?)> acceptEventInviteByToken(
    String token,
  ) async {
    final trimmed = token.trim();
    if (trimmed.isEmpty) {
      return (null, 'Invite link is missing a token.');
    }
    if (_user == null) return (null, 'Sign in to accept this invite.');
    try {
      final invite = await _events.acceptInviteByToken(trimmed);
      _pendingEventInviteCode = null;
      _pendingEventInviteLocation = null;
      _acceptedEventInvite = invite;
      await refreshEventState();
      _addFeedEvent('confirmed event invite for ${invite.title}');
      return (invite, null);
    } catch (error) {
      return (null, _events.friendlyError(error));
    }
  }

  Future<EventInvitePreview?> previewEventInvite(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) return null;
    try {
      return await _events.previewInviteByCode(trimmed);
    } catch (_) {
      rethrow;
    }
  }

  Future<EventInvitePreview?> previewEventInviteByToken(String token) async {
    final trimmed = token.trim();
    if (trimmed.isEmpty) return null;
    try {
      return await _events.previewInviteByToken(trimmed);
    } catch (_) {
      rethrow;
    }
  }

  Future<(ClubEventRecord?, String?)> submitHostedEventRequest({
    required String title,
    required String branch,
    required ClubEventType eventType,
    required DateTime startsAt,
    required DateTime endsAt,
    required int minimumPax,
    required int walletMinutes,
    List<EventGuestDraft> invites = const [],
  }) async {
    try {
      final event = await _events.submitEventRequest(
        title: title,
        branch: branch,
        eventType: eventType,
        startsAt: startsAt,
        endsAt: endsAt,
        minimumPax: minimumPax,
        walletSeconds: walletMinutes * 60,
        invites: invites,
      );
      await refreshEventState();
      return (event, null);
    } catch (error) {
      return (null, _events.friendlyError(error));
    }
  }

  Future<(ClubEventRecord?, String?)> extendHostedEventWallet({
    required String eventId,
    required int minutes,
  }) async {
    try {
      final event = await _events.extendEventWallet(
        eventId: eventId,
        minutes: minutes,
      );
      _eventWalletPromptedForId = null;
      await refreshEventState();
      return (event, null);
    } catch (error) {
      return (null, _events.friendlyError(error));
    }
  }

  Future<(HostedEventInviteResult?, String?)> createHostedEventInvite({
    required String eventId,
    required String guestName,
    String? guestEmail,
    String? guestPhone,
  }) async {
    try {
      final invite = await _events.createHostedEventInvite(
        eventId: eventId,
        guestName: guestName,
        guestEmail: guestEmail,
        guestPhone: guestPhone,
      );
      await refreshEventState();
      return (invite, null);
    } catch (error) {
      return (null, _events.friendlyError(error));
    }
  }

  Future<List<HostedEventInviteRow>> listHostedEventInvites(
    String eventId,
  ) async {
    try {
      return await _events.listHostedEventInvites(eventId);
    } catch (_) {
      return const [];
    }
  }

  void _initLoungeState() {
    if (_loungeInitialized) return;
    _loungeInitialized = true;
    _avatar = AvatarConfig(name: _user?.name ?? 'Socialite');
    _challenges = MockData.initialChallenges();
    _feedEvents = MockData.initialFeedEvents();
    _leaderboard = [];
    _initTimeEconomyForVisit();
    _progressChallenge('chal-1', by: 1); // entered club
    unawaited(refreshLeaderboard());
  }

  void setActiveTab(LoungeTab tab) {
    _activeTab = tab;
    if (tab == LoungeTab.leaderboard) {
      unawaited(refreshLeaderboard());
      _refreshCompetitiveRankings();
    }
    if (tab == LoungeTab.chats) {
      unawaited(refreshFriendRequests());
    }
    notifyListeners();
  }

  void openChatsTab({FriendProfile? thread}) {
    _activeTab = LoungeTab.chats;
    _pendingChatProfile = thread;
    unawaited(refreshFriendRequests());
    notifyListeners();
  }

  FriendProfile? takePendingChatProfile() {
    final profile = _pendingChatProfile;
    _pendingChatProfile = null;
    return profile;
  }

  Future<void> refreshLeaderboard() async {
    try {
      final rankings = await _leaderboardService.fetchRankings();
      if (rankings.isEmpty) {
        _leaderboard = [
          LeaderboardUser(
            rank: 1,
            name: _user?.name ?? 'You',
            points: spendableTimeSeconds ~/ 60,
            tier: memberTier,
            isCurrentUser: true,
            avatarColor: _avatar.color,
            avatarGlyph: (_user?.name.isNotEmpty ?? false)
                ? _user!.name.substring(0, 1).toUpperCase()
                : 'Y',
            timeBalance: spendableTimeSeconds,
          ),
        ];
      } else {
        _leaderboard = _leaderboardService.toLeaderboardUsers(rankings);
        _recalculateLeaderboardRanks();
      }
    } catch (_) {
      if (_leaderboard.isEmpty && _user != null) {
        _leaderboard = [
          LeaderboardUser(
            rank: 1,
            name: _user!.name,
            points: spendableTimeSeconds ~/ 60,
            tier: memberTier,
            isCurrentUser: true,
            avatarColor: _avatar.color,
            avatarGlyph: _user!.name.isNotEmpty
                ? _user!.name.substring(0, 1).toUpperCase()
                : 'Y',
            timeBalance: spendableTimeSeconds,
          ),
        ];
      }
    }
    notifyListeners();
  }

  void setAvatar(AvatarConfig config) {
    _avatar = config;
    notifyListeners();
  }

  void claimChallenge(String id) {
    final i = _challenges.indexWhere((c) => c.id == id);
    if (i < 0) return;
    final chal = _challenges[i];
    if (!chal.isComplete || chal.claimed) return;
    _challenges[i] = chal.copyWith(claimed: true);
    _addPoints(chal.points);
    if (chal.bonusMinutes > 0) {
      unawaited(_creditBonusMinutes(chal.bonusMinutes, source: chal.title));
    }
    notifyListeners();
  }

  Future<void> _creditBonusMinutes(int minutes, {String? source}) async {
    if (minutes < 1 || _user == null) return;
    try {
      _user = await _withLocalTimeMutation(
        () => _auth.addTimeBalance(minutes * 60),
      );
    } catch (_) {
      return;
    }
    if (_session != null) {
      _session!.bonusMinutesEarned += minutes;
      unawaited(_sessionStore.upsert(_session!));
    }
    _addFeedEvent('earned +$minutes min${source != null ? ' · $source' : ''}');
  }

  void completeMiniGame(MiniGame game, int points) {
    if (!canSpendTime) return;
    _addPoints(points);
    if (game.id == 'game-1' || game.id == 'game-3') {
      _progressChallenge('chal-3', by: 1);
      unawaited(_creditBonusMinutes(30, source: 'Win Club Games'));
    }
    notifyListeners();
  }

  void reactToFeed(String eventId, String reaction) {
    if (!canSpendTime) return;
    final i = _feedEvents.indexWhere((e) => e.id == eventId);
    if (i < 0) return;
    final event = _feedEvents[i];
    if (event.userReacted != null) return;

    final likes = Map<String, int>.from(event.likes);
    likes[reaction] = (likes[reaction] ?? 0) + 1;
    _feedEvents[i] = FeedEvent(
      id: event.id,
      avatarSeed: event.avatarSeed,
      userName: event.userName,
      userRank: event.userRank,
      isFriend: event.isFriend,
      timeAgo: event.timeAgo,
      eventText: event.eventText,
      likes: likes,
      userReacted: reaction,
    );
    _addPoints(2);
    notifyListeners();
  }

  void _progressChallenge(String id, {int by = 1}) {
    final i = _challenges.indexWhere((c) => c.id == id);
    if (i < 0) return;
    final chal = _challenges[i];
    if (chal.claimed) return;
    _challenges[i] = chal.copyWith(
      currentCount: (chal.currentCount + by).clamp(0, chal.targetCount),
    );
  }

  void _addPoints(int amount) {
    _points += amount;
    _reputationXp += amount;
    _visitRecap.xpGained += amount;
    _syncReputationQuests();
    unawaited(_persistTimeEconomyProgress());
  }

  void _recalculateLeaderboardRanks() {
    if (_leaderboard.isEmpty) return;

    final updated =
        _leaderboard.map((u) {
            final seconds = u.isCurrentUser
                ? spendableTimeSeconds
                : (u.timeBalance ?? 0);
            return LeaderboardUser(
              rank: u.rank,
              name: u.isCurrentUser ? (_user?.name ?? u.name) : u.name,
              points: u.isCurrentUser ? _points : u.points,
              tier: _tierForSeconds(seconds),
              isCurrentUser: u.isCurrentUser,
              avatarColor: u.avatarColor,
              avatarGlyph: u.avatarGlyph,
              timeBalance: seconds,
            );
          }).toList()
          ..sort((a, b) => (b.timeBalance ?? 0).compareTo(a.timeBalance ?? 0));

    _leaderboard = [
      for (var i = 0; i < updated.length; i++)
        LeaderboardUser(
          rank: i + 1,
          name: updated[i].name,
          points: updated[i].points,
          tier: updated[i].tier,
          isCurrentUser: updated[i].isCurrentUser,
          avatarColor: updated[i].avatarColor,
          avatarGlyph: updated[i].avatarGlyph,
          timeBalance: updated[i].timeBalance,
        ),
    ];
  }

  void _addFeedEvent(String text) {
    final event = FeedEvent(
      id: 'event-${DateTime.now().millisecondsSinceEpoch}',
      avatarSeed: AvatarSeed(
        hair: _avatar.hair,
        eyes: _avatar.eyes,
        accessory: _avatar.accessory,
        color: _avatar.color,
      ),
      userName: _user?.name ?? 'You',
      userRank: '#$currentRank',
      isFriend: false,
      timeAgo: 'just now',
      eventText: text,
    );
    _feedEvents = [event, ..._feedEvents];
  }

  void beginNewVisit() {
    _timer?.cancel();
    _economyRefreshTimer?.cancel();
    _qrRefreshTimer?.cancel();
    _syncTimer?.cancel();
    stopEventAttendanceWatch();
    _sessionStore.unsubscribe();
    _session = null;
    _eventGuestWelcomeQueue.clear();
    unawaited(_clearPersistedCheckoutReceipt());
    unawaited(_clearSocialPresence());
    _currentQr = null;
    _drinksOrdered = 0;
    _loungeInitialized = false;
    _resetTimeLowWarnings();
    _lastAnnouncedBand = null;
    _frozenVisitRecap = null;
    _activeQuests = [];
    _mysteryQuest = null;
    _decayDebtFraction = 0;
    _roomTimerSyncDebt = 0;
    unawaited(_liveActivity.end());
    notifyListeners();
  }

  Future<void> cancelPendingPass() async {
    if (_session == null || _session!.phase != SessionPhase.paidAwaitingEntry) {
      return;
    }

    final refundSeconds = _session!.purchasedSeconds;

    await _sessionStore.cancelSession(_session!.id);
    _timer?.cancel();
    _qrRefreshTimer?.cancel();
    _syncTimer?.cancel();
    _sessionStore.unsubscribe();
    _session = null;
    _currentQr = null;
    _drinksOrdered = 0;

    if (refundSeconds > 0 && _user != null) {
      try {
        _user = await _auth.deductTimeBalance(refundSeconds);
      } catch (_) {
        // Session voided — best effort to remove reserved pass time from wallet.
      }
    }

    notifyListeners();
  }

  void setSelectedTier(PriceTier tier) {
    _selectedTier = tier;
    notifyListeners();
  }

  void selectTimePackage(TimePackage package) {
    _selectedTimePackageId = package.id;
    _selectedTimeMinutes = package.minutes;
    notifyListeners();
  }

  void setSelectedTimeMinutes(int minutes) {
    if (minutes < 1) return;
    _selectedTimeMinutes = minutes;
    _selectedTimePackageId = 'custom';
    notifyListeners();
  }

  void setPaymentMethod(PaymentMethod method) {
    _paymentMethod = method;
    notifyListeners();
  }

  void setSelectedBranch(String branch) {
    _selectedBranch = _resolveBranchSelection(branch);
    notifyListeners();
  }

  Future<void> refreshBranches() async {
    await _loadBranches(preferredName: _selectedBranch);
    notifyListeners();
  }

  Future<PaymentResult> purchasePass() async {
    if (_user == null || !_user!.isMember) return PaymentResult.failed;

    if (_session == null) {
      final existing = await _sessionStore.fetchActiveSessionForMember(
        _user!.id,
      );
      if (existing != null) {
        await _applyRestoredSession(existing);
      }
    }

    if (_session != null) {
      switch (_session!.phase) {
        case SessionPhase.insideClub:
        case SessionPhase.awaitingExitScan:
          if (!canPurchaseNewPass) return PaymentResult.failed;
          return _extendPassWithTier();
        case SessionPhase.paidAwaitingEntry:
          if (!canPurchaseNewPass) return PaymentResult.failed;
          return _extendPendingPassWithTier();
        case SessionPhase.none:
        case SessionPhase.completed:
          break;
      }
    }

    if (!canPurchaseNewPass) return PaymentResult.failed;

    final result = await _payment.processPayment(
      method: _paymentMethod,
      amount: _selectedTier.discountedPrice,
    );

    if (result == PaymentResult.success) {
      final seconds = _selectedTier.duration * 60;
      _user = await _withLocalTimeMutation(() => _auth.addTimeBalance(seconds));

      final sessionId = _uuid.v4();
      _session = ClubSessionRecord(
        id: sessionId,
        memberId: _user!.id,
        memberName: _user!.name,
        purchasedSeconds: seconds,
        amountPaid: _selectedTier.discountedPrice,
        branch: _selectedBranch,
        phase: SessionPhase.paidAwaitingEntry,
        remainingSeconds: 0,
      );
      await _sessionStore.upsert(_session!);
      await _sessionStore.subscribeToSession(sessionId);
      _startQrRefresh(QrPurpose.entry);
      _startSyncPolling();
      await _maybeSkipEntryDoorScan();
    }

    notifyListeners();
    return result;
  }

  Future<bool> startVisitWithTimeBalance() async {
    if (_user == null || timeBalance <= 0) return false;

    try {
      final existing = await _sessionStore.fetchActiveSessionForMember(
        _user!.id,
      );
      if (existing != null) {
        await _applyRestoredSession(existing);
        notifyListeners();
        return true;
      }

      final sessionId = _uuid.v4();
      final created = ClubSessionRecord(
        id: sessionId,
        memberId: _user!.id,
        memberName: _user!.name,
        purchasedSeconds: 0,
        amountPaid: 0,
        branch: _selectedBranch,
        phase: SessionPhase.paidAwaitingEntry,
        remainingSeconds: 0,
        packageSlug: _user!.activePackageSlug,
        includedDrinksRemaining: _user!.includedDrinksRemaining,
        includedDrinksTotal: _user!.includedDrinksTotal,
      );
      await _sessionStore.upsert(created);
      _session = created;
      await _sessionStore.subscribeToSession(sessionId);
      _startQrRefresh(QrPurpose.entry);
      _startSyncPolling();
      await _maybeSkipEntryDoorScan();
      notifyListeners();
      return true;
    } catch (error, stackTrace) {
      debugPrint('startVisitWithTimeBalance failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  Future<PaymentResult> _extendPassWithTier() async {
    final result = await _payment.processPayment(
      method: _paymentMethod,
      amount: _selectedTier.discountedPrice,
    );

    if (result == PaymentResult.success && _session != null) {
      final added = _selectedTier.duration * 60;
      _user = await _withLocalTimeMutation(() => _auth.addTimeBalance(added));
      _session!.purchasedSeconds += added;
      _session!.amountPaid += _selectedTier.discountedPrice;
      await _sessionStore.upsert(_session!);
      if (_session!.phase == SessionPhase.insideClub) {
        _resumeTimerIfNeeded();
      }
      _maybeWarnTimerLow();
    }

    notifyListeners();
    return result;
  }

  Future<PaymentResult> _extendPendingPassWithTier() async {
    final result = await _payment.processPayment(
      method: _paymentMethod,
      amount: _selectedTier.discountedPrice,
    );

    if (result == PaymentResult.success && _session != null) {
      final added = _selectedTier.duration * 60;
      _user = await _withLocalTimeMutation(() => _auth.addTimeBalance(added));
      _session!.purchasedSeconds += added;
      _session!.amountPaid += _selectedTier.discountedPrice;
      await _sessionStore.upsert(_session!);
    }

    notifyListeners();
    return result;
  }

  Future<PaymentResult> purchaseTime(int minutes) async {
    if (_user == null || minutes < 1) return PaymentResult.failed;

    final result = await _payment.processPayment(
      method: _paymentMethod,
      amount: AppTimePricing.discountedPriceForMinutes(minutes),
    );

    if (result != PaymentResult.success) return result;

    final seconds = minutes * 60;
    _user = await _withLocalTimeMutation(() => _auth.addTimeBalance(seconds));
    _maybeWarnTimerLow();

    notifyListeners();
    return result;
  }

  Future<PaymentResult> purchaseAndLoadTime(int minutes) =>
      purchaseTime(minutes);

  void _resumeTimerIfNeeded() {
    if (_meterShouldRun) {
      _startTimer();
      _startQrRefresh(QrPurpose.exit);
    }
  }

  Future<void> requestExit() async {
    if (_session == null || _session!.phase != SessionPhase.insideClub) return;

    // Keep the meter running — pause would let guests camp on the exit QR.
    await _sessionStore.requestExit(_session!.id);
    final updated = await _sessionStore.fetchSession(_session!.id);
    if (updated != null) _session = updated;
    if (_meterShouldRun) {
      _startTimer();
    }
    _startQrRefresh(QrPurpose.exit);
    _syncLiveActivity(force: true);
    notifyListeners();
  }

  Future<void> cancelExitRequest() async {
    if (_session == null || _session!.phase != SessionPhase.awaitingExitScan) {
      return;
    }

    await _sessionStore.cancelExitRequest(_session!.id);
    final updated = await _sessionStore.fetchSession(_session!.id);
    if (updated != null) {
      _session = updated;
    } else {
      _session!.phase = SessionPhase.insideClub;
    }
    _startTimer();
    _startQrRefresh(QrPurpose.exit);
    _syncLiveActivity(force: true);
    notifyListeners();
  }

  QrPayload? validateScannedQr(String raw) {
    final payload = QrPayload.decode(raw);
    if (payload == null) return null;
    if (!_qr.validate(payload)) return null;
    return payload;
  }

  Future<(StaffDoorScanResult?, String?)> staffConfirmScan(
    QrPayload payload,
  ) async {
    _lastStaffEventCheckIn = null;
    var session = await _sessionStore.fetchSession(payload.sessionId);
    if (session == null) return (null, 'Session not found.');

    if (payload.purpose == QrPurpose.entry) {
      final alreadyInside = session.phase == SessionPhase.insideClub;
      if (!alreadyInside && session.phase != SessionPhase.paidAwaitingEntry) {
        return (null, 'Not awaiting entry scan.');
      }
      if (!alreadyInside) {
        await _sessionStore.confirmEntry(session.id);
      }
      // Re-scanning a guest who is already inside must still be able to land
      // the event check-in — the RPC is idempotent on an existing guest row.
      final (checkIn, checkInError) = await _attemptStaffEventCheckIn(
        memberId: payload.userId,
        sessionId: payload.sessionId,
      );
      _lastStaffEventCheckIn = checkIn;
      notifyListeners();
      return (
        StaffDoorScanResult(
          memberName: payload.memberName,
          purpose: payload.purpose,
          eventCheckIn: checkIn,
          eventCheckInError: checkInError,
          alreadyInside: alreadyInside,
        ),
        null,
      );
    }

    if (payload.purpose == QrPurpose.exit) {
      if (session.phase == SessionPhase.insideClub) {
        await _sessionStore.requestExit(session.id);
        session = await _sessionStore.fetchSession(session.id) ?? session;
      }
      if (session.phase != SessionPhase.awaitingExitScan) {
        return (null, 'Guest is not ready to exit yet.');
      }
      await _sessionStore.confirmExit(session.id);
      notifyListeners();
      return (
        StaffDoorScanResult(
          memberName: payload.memberName,
          purpose: payload.purpose,
        ),
        null,
      );
    }

    return (null, 'Invalid QR purpose.');
  }

  /// Returns the check-in result, or a staff-readable error when the RPC
  /// failed. A member with no active event yields `(null, null)`.
  Future<(StaffEventCheckInResult?, String?)> _attemptStaffEventCheckIn({
    required String memberId,
    required String sessionId,
  }) async {
    try {
      final result = await _events.staffCheckInGuest(
        memberId: memberId,
        sessionId: sessionId,
      );
      return (result, null);
    } catch (error, stackTrace) {
      debugPrint('Staff event check-in skipped: $error');
      debugPrintStack(stackTrace: stackTrace);
      return (null, _events.friendlyError(error));
    }
  }

  Future<ClubSessionRecord?> lookupSessionByCode(String code) =>
      _sessionStore.findByCode(code);

  Future<String?> staffConfirmByCode(String code) async {
    var session = await _sessionStore.findByCode(code);
    if (session == null) return 'Session code not found.';

    if (session.phase == SessionPhase.paidAwaitingEntry) {
      await _sessionStore.confirmEntry(session.id);
      return null;
    }

    if (session.phase == SessionPhase.awaitingExitScan) {
      await _sessionStore.confirmExit(session.id);
      return null;
    }

    if (session.phase == SessionPhase.insideClub) {
      await _sessionStore.requestExit(session.id);
      session = await _sessionStore.fetchSession(session.id) ?? session;
      if (session.phase == SessionPhase.awaitingExitScan) {
        await _sessionStore.confirmExit(session.id);
        return null;
      }
    }

    return 'Guest is not at entry or exit gate.';
  }

  /// Auto-badge-in for allowlisted / VIP members — no staff door QR needed.
  Future<bool> _maybeSkipEntryDoorScan() async {
    if (!canSkipDoorQr) return false;
    if (_session?.phase != SessionPhase.paidAwaitingEntry) return false;
    return debugBypassDoorScan();
  }

  /// Hidden pilot/debug: triple-tap the door icon to skip staff QR scan.
  ///
  /// Applies lounge/exit locally because [ClubSessionRecord] is shared mutable
  /// with the session store — a same-device confirmEntry wouldn't fire the
  /// usual previous→next phase transition in [_onSessionStoreChanged].
  Future<bool> debugBypassDoorScan() async {
    final session = _session;
    if (session == null || _checkoutReceipt != null) return false;

    if (session.phase == SessionPhase.paidAwaitingEntry) {
      try {
        await _sessionStore.confirmEntry(session.id);
      } catch (_) {
        // Still enter locally so 2-phone friendship testing can continue.
      }
      session.phase = SessionPhase.insideClub;
      session.enteredAt ??= DateTime.now();
      _session = session;
      _timer?.cancel();
      _syncTimer?.cancel();
      _initLoungeState();
      _startQrRefresh(QrPurpose.exit);
      _scheduleAutoBadgeOut(session);
      unawaited(_sounds.playDoorLatch());
      await _onEnteredClub();
      notifyListeners();
      _syncLiveActivity(force: true);
      return true;
    }

    if (session.phase == SessionPhase.insideClub ||
        session.phase == SessionPhase.awaitingExitScan) {
      try {
        if (session.phase == SessionPhase.insideClub) {
          await _sessionStore.requestExit(session.id);
        }
        await _sessionStore.confirmExit(session.id);
      } catch (_) {
        // Fall through to local checkout.
      }
      _timer?.cancel();
      _qrRefreshTimer?.cancel();
      _syncTimer?.cancel();
      session.phase = SessionPhase.completed;
      session.exitedAt ??= DateTime.now();
      _captureCheckoutReceipt(session);
      notifyListeners();
      unawaited(_finalizeCheckoutReceipt(session));
      return true;
    }

    return false;
  }

  Future<void> _bankTimeForCompletedVisit(
    SessionPhase previousPhase,
    ClubSessionRecord session,
  ) async {
    if (previousPhase != SessionPhase.awaitingExitScan) return;
    await _flushWalletTimerSync();
    if (usesCloud) {
      _user = await _auth.refreshProfile() ?? _user;
    }
    notifyListeners();
  }

  Future<void> _flushWalletTimerSync() async {
    if (_user == null || _timerSyncDebt <= 0) return;
    final debt = _timerSyncDebt;
    _timerSyncDebt = 0;
    try {
      // Relative subtract — never absolute overwrite (won't undo RPC spends).
      _user = await _auth.applyTimerDebt(debt);
    } catch (_) {
      _timerSyncDebt += debt;
    }
  }

  Future<void> _flushRoomTimerSync() async {
    if (_session == null || _roomTimerSyncDebt <= 0) return;
    final debt = _roomTimerSyncDebt;
    _roomTimerSyncDebt = 0;
    try {
      await _sessionStore.upsert(_session!);
    } catch (_) {
      _roomTimerSyncDebt += debt;
    }
  }

  bool get _meterShouldRun {
    final phase = _session?.phase;
    if (phase != SessionPhase.insideClub &&
        phase != SessionPhase.awaitingExitScan) {
      return false;
    }
    return TimeEconomyService.decaySource(
          isInVipRoom: isInVipRoom,
          vipRoomSeconds: vipRoomTimeSeconds,
          eventWalletActive: _eventWalletDecayActive,
          eventWalletSeconds: _eventWalletSeconds,
          personalSeconds: timeBalance,
        ) !=
        TimeDecaySource.none;
  }

  /// Serialize wallet spends: pause meter → flush debt → mutate → resume.
  Future<T?> _runExclusiveWallet<T>(
    Future<T> Function() action, {
    T? onBusy,
  }) async {
    if (_walletBusy) return onBusy;
    _walletBusy = true;
    final shouldResume =
        _session?.phase == SessionPhase.insideClub ||
        _session?.phase == SessionPhase.awaitingExitScan;
    _timer?.cancel();
    try {
      await _flushWalletTimerSync();
      await _flushRoomTimerSync();
      return await _withLocalTimeMutation(action);
    } finally {
      _walletBusy = false;
      if (shouldResume && _meterShouldRun) {
        _startTimer();
      }
      _maybeWarnTimerLow();
      _syncLiveActivity(force: true);
      notifyListeners();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _economyRefreshTimer?.cancel();
    if (!_timeLowThresholdsSeeded) {
      _seedTimeLowThresholdsAlreadyPast();
      _timeLowThresholdsSeeded = true;
    }
    _tickTimeEconomy();
    _economyRefreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _tickTimeEconomy();
      if (_eventWalletDecayActive) {
        unawaited(refreshEventState());
      }
      notifyListeners();
    });
    _syncLiveActivity(force: true);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (_session == null) return;
      final phase = _session!.phase;
      if (phase != SessionPhase.insideClub &&
          phase != SessionPhase.awaitingExitScan) {
        return;
      }

      if (!_meterShouldRun) {
        await _flushWalletTimerSync();
        await _flushRoomTimerSync();
        _timer?.cancel();
        _syncLiveActivity(force: true);
        notifyListeners();
        return;
      }

      await _applyDynamicDecayTick();
      _maybeWarnTimerLow();
      _syncLiveActivity();

      if (_timerSyncDebt >= 5) {
        await _flushWalletTimerSync();
      } else if (!usesCloud && _timerSyncDebt > 0) {
        await _auth.setTimeBalance(timeBalance);
      }
      if (_roomTimerSyncDebt >= 5) {
        await _flushRoomTimerSync();
      }

      notifyListeners();
    });
  }

  Future<void> _applyDynamicDecayTick() async {
    final source = TimeEconomyService.decaySource(
      isInVipRoom: isInVipRoom,
      vipRoomSeconds: vipRoomTimeSeconds,
      eventWalletActive: _eventWalletDecayActive,
      eventWalletSeconds: _eventWalletSeconds,
      personalSeconds: timeBalance,
    );
    if (source == TimeDecaySource.none) return;
    if (source == TimeDecaySource.personal && _user == null) return;
    if (source == TimeDecaySource.vipRoom && _session == null) return;

    _tickFrozenBuffs();
    final club = TimeEconomyService.clubStateAt(DateTime.now());
    final rate = TimeEconomyService.decayPerRealSecond(
      window: club.window,
      buffs: _activeBuffs,
    );

    if (rate <= 0) return;

    _decayDebtFraction += rate;
    if (_decayDebtFraction < 1) return;

    final deduct = _decayDebtFraction.floor();
    _decayDebtFraction -= deduct;
    _visitRecap.minutesDecayedTonight += deduct ~/ 60;

    if (source == TimeDecaySource.vipRoom) {
      final before = vipRoomTimeSeconds;
      final after = (before - deduct).clamp(0, before);
      _session!.vipRoomTimeSeconds = after;
      _roomTimerSyncDebt += before - after;
      if (after <= 0) {
        final name = activeVipRoomName ?? 'VIP room';
        _session!.activeVipRoomSlug = null;
        _session!.vipRoomTimeSeconds = 0;
        _addFeedEvent('$name time ended — personal timer resumed');
        await _flushRoomTimerSync();
      }
      return;
    }

    if (source == TimeDecaySource.eventWallet) {
      _applyLocalEventWalletDecay(deduct);
      return;
    }

    _timerSyncDebt += deduct;
    _user = _user!.copyWith(
      timeBalanceSeconds: (timeBalance - deduct).clamp(0, timeBalance),
    );
  }

  /// Optimistic shared-wallet countdown between authoritative refreshes.
  /// Server [apply_event_wallet_passive_decay] remains the source of truth.
  void _applyLocalEventWalletDecay(int deduct) {
    if (deduct <= 0) return;
    final attendance = _activeEventAttendance;
    if (attendance != null && attendance.walletSeconds > 0) {
      final after = (attendance.walletSeconds - deduct).clamp(
        0,
        attendance.walletSeconds,
      );
      _activeEventAttendance = attendance.copyWith(walletSeconds: after);
    }
    final hostedId = activeHostedEvent?.id ?? attendance?.eventId;
    if (hostedId == null) return;
    _hostedEvents = [
      for (final event in _hostedEvents)
        if (event.id == hostedId)
          event.copyWith(
            walletSeconds: (event.walletSeconds - deduct).clamp(
              0,
              event.walletSeconds,
            ),
            walletConsumedSeconds: event.walletConsumedSeconds + deduct,
          )
        else
          event,
    ];
  }

  void _tickFrozenBuffs() {
    for (var i = 0; i < _activeBuffs.length; i++) {
      final buff = _activeBuffs[i];
      if (!buff.hasFrozenTime) continue;
      _activeBuffs[i] = buff.copyWith(
        frozenSecondsRemaining: (buff.frozenSecondsRemaining - 1).clamp(
          0,
          buff.frozenSecondsRemaining,
        ),
      );
    }
    _activeBuffs.removeWhere((b) => b.isExpired);
  }

  void _maybeWarnTimerLow() {
    _maybeAnnounceTimerBand();
    final phase = _session?.phase;
    if (phase != SessionPhase.insideClub &&
        phase != SessionPhase.awaitingExitScan) {
      return;
    }

    // Warn against the pool that is actively decaying (room / event / personal).
    final source = TimeEconomyService.decaySource(
      isInVipRoom: isInVipRoom,
      vipRoomSeconds: vipRoomTimeSeconds,
      eventWalletActive: _eventWalletDecayActive,
      eventWalletSeconds: _eventWalletSeconds,
      personalSeconds: timeBalance,
    );
    final seconds = switch (source) {
      TimeDecaySource.vipRoom => vipRoomTimeSeconds,
      TimeDecaySource.eventWallet => _eventWalletSeconds,
      TimeDecaySource.personal => timeBalance,
      TimeDecaySource.none => 0,
    };
    if (seconds <= 0) return;

    // Climbing back above a mark (buy / gift) re-arms that threshold.
    for (final minutes in TimeLowAlert.thresholds) {
      if (seconds > minutes * 60) {
        _firedTimeLowThresholds.remove(minutes);
        _pushedAlertIds.remove('time-low-$minutes');
        _timeLowAlertQueue.removeWhere((a) => a.minutesThreshold == minutes);
      }
    }

    // Crossing into marks: fire the most urgent newly crossed only (avoid banner
    // spam when a big spend drops past several thresholds at once).
    TimeLowAlert? mostUrgent;
    for (final minutes in TimeLowAlert.thresholds) {
      if (seconds > minutes * 60) continue;
      if (_firedTimeLowThresholds.contains(minutes)) continue;
      _firedTimeLowThresholds.add(minutes);
      final alert = TimeLowAlert(minutesThreshold: minutes);
      if (mostUrgent == null ||
          alert.minutesThreshold < mostUrgent.minutesThreshold) {
        mostUrgent = alert;
      }
    }
    if (mostUrgent != null) {
      _enqueueTimeLowAlert(mostUrgent);
    }
  }

  /// Don't replay thresholds already below when the timer first starts this visit.
  void _seedTimeLowThresholdsAlreadyPast() {
    final seconds = timeBalance;
    if (seconds <= 0) return;
    for (final minutes in TimeLowAlert.thresholds) {
      // Strict < so an exact mark (e.g. 30:00) can still fire once.
      if (seconds < minutes * 60) {
        _firedTimeLowThresholds.add(minutes);
      }
    }
  }

  void _resetTimeLowWarnings() {
    _firedTimeLowThresholds.clear();
    _timeLowAlertQueue.clear();
    _timeLowThresholdsSeeded = false;
    for (final minutes in TimeLowAlert.thresholds) {
      _pushedAlertIds.remove('time-low-$minutes');
    }
  }

  bool _enqueueTimeLowAlert(TimeLowAlert alert) {
    if (_timeLowAlertQueue.any(
      (a) => a.minutesThreshold == alert.minutesThreshold,
    )) {
      return false;
    }
    final becameHead = _timeLowAlertQueue.isEmpty;
    if (becameHead) {
      _timeLowAlertQueue.add(alert);
    } else {
      // Keep current head; sort the tail so more urgent (lower minutes) comes next.
      final head = _timeLowAlertQueue.first;
      final rest = _timeLowAlertQueue.sublist(1)..add(alert);
      rest.sort((a, b) => a.minutesThreshold.compareTo(b.minutesThreshold));
      _timeLowAlertQueue
        ..clear()
        ..add(head)
        ..addAll(rest);
    }
    if (becameHead) _surfaceTimeLowHead(alert);
    notifyListeners();
    return true;
  }

  void _surfaceTimeLowHead(TimeLowAlert alert) {
    if (_appInForeground && alert.isUrgent) {
      unawaited(_sounds.playTimerLow());
    }
    if (_pushedAlertIds.contains(alert.id)) return;
    _pushedAlertIds.add(alert.id);
    if (_pushedAlertIds.length > 400) {
      _pushedAlertIds.clear();
      _pushedAlertIds.add(alert.id);
    }

    if (!_appInForeground) {
      // Background: local banner + Live Activity system alert (no APNs job).
      unawaited(
        _push.showSocialAlert(
          id: alert.id,
          title: alert.title,
          body: alert.body,
        ),
      );
      _liveSocialTitle = alert.title;
      _liveSocialBody = alert.body;
      _liveSocialSender = null;
      _syncLiveActivity(force: true, withSystemAlert: true);
      return;
    }

    // Foreground: island banner owns UX; keep Live Activity in sync quietly.
    _syncLiveActivity(force: true);
  }

  void clearPendingTimeLowAlert() {
    if (_timeLowAlertQueue.isEmpty) return;
    _timeLowAlertQueue.removeAt(0);
    _clearLiveSocialAlert();
    _promoteNextAlertSurface();
    notifyListeners();
  }

  void _promoteNextAlertSurface() {
    // Prefer social Live Activity resurfacing; island host still shows time after.
    final request = pendingRequestAlert;
    if (request != null) {
      _surfaceRequestHead(request);
      return;
    }
    final ping = pendingPingAlert;
    if (ping != null) {
      _surfacePingHead(ping);
      return;
    }
    final guestCheckin = pendingEventGuestCheckinAlert;
    if (guestCheckin != null) {
      _surfaceEventGuestCheckinHead(guestCheckin);
      return;
    }
    final time = pendingTimeLowAlert;
    if (time != null) {
      _surfaceTimeLowHead(time);
    }
  }

  /// Push time-as-currency into Dynamic Island / Lock Screen / Apple Watch.
  String _liveActivityDrinkStatus(List<DrinkOrder> orders) {
    final preparing = orders.any((o) => o.status == DrinkOrderStatus.preparing);
    if (orders.length == 1) {
      return preparing ? 'POURING YOUR DRINK' : 'DRINK AT THE BAR';
    }
    return preparing
        ? '${orders.length} DRINKS IN PROGRESS'
        : '${orders.length} DRINKS AT BAR';
  }

  void _syncLiveActivity({bool force = false, bool withSystemAlert = false}) {
    final phase = sessionPhase;
    final inside =
        phase == SessionPhase.insideClub ||
        phase == SessionPhase.awaitingExitScan;
    if (!inside || _checkoutReceipt != null) {
      unawaited(_liveActivity.end());
      _lastLiveActivitySeconds = null;
      return;
    }

    final seconds = timeBalance;
    final useLiveCountdown =
        seconds > 0 &&
        seconds <= TimeLiveActivityService.liveCountdownMaxSeconds;
    if (!force &&
        !withSystemAlert &&
        _liveSocialTitle == null &&
        _lastLiveActivitySeconds != null) {
      final delta = (seconds - _lastLiveActivitySeconds!).abs();
      // Native countdown needs rare updates; big wallet labels refresh ~each minute.
      if (useLiveCountdown && delta < 4) return;
      if (!useLiveCountdown && delta < 60) return;
    }
    _lastLiveActivitySeconds = seconds;

    final baseStatus = phase == SessionPhase.awaitingExitScan
        ? 'AWAITING EXIT'
        : (seconds <= 10 * 60 ? 'TIME RUNNING LOW' : 'INSIDE THE CLUB');
    final drinkOrders = activeDrinkOrders;
    final status =
        _liveSocialTitle ??
        (drinkOrders.isNotEmpty
            ? _liveActivityDrinkStatus(drinkOrders)
            : baseStatus);

    unawaited(
      _liveActivity.syncVisit(
        insideOrExiting: true,
        memberName: _user?.name ?? _session?.memberName ?? 'Guest',
        branch: _session?.branch ?? _selectedBranch,
        status: status,
        remainingSeconds: seconds,
        socialAlertTitle: _liveSocialTitle,
        socialAlertBody: _liveSocialBody,
        socialAlertSender: _liveSocialSender,
        withSystemAlert: withSystemAlert,
      ),
    );
  }

  void _surfaceSocialDelivery({
    required String id,
    required String title,
    required String body,
    String? senderName,
    bool updateLive = true,
  }) {
    if (_pushedAlertIds.contains(id)) return;
    _pushedAlertIds.add(id);
    // Bound growth — IDs are only for deduping push/live surfaces.
    if (_pushedAlertIds.length > 400) {
      _pushedAlertIds.clear();
      _pushedAlertIds.add(id);
    }

    if (!_appInForeground) {
      unawaited(_push.showSocialAlert(id: id, title: title, body: body));
    }

    if (updateLive) {
      _liveSocialTitle = title;
      _liveSocialBody = body;
      _liveSocialSender = senderName;
      _syncLiveActivity(force: true, withSystemAlert: true);
    }
  }

  void _surfacePingHead(FriendPing ping) {
    final name = ping.senderName ?? 'Friend';
    unawaited(_sounds.playKnock());
    _surfaceSocialDelivery(
      id: ping.id,
      title: ping.isChat ? 'Message from $name' : 'Ping from $name',
      body: ping.message,
      senderName: name,
      updateLive: true,
    );
  }

  void _surfaceRequestHead(FriendRequest request) {
    _surfaceSocialDelivery(
      id: 'req-${request.id}',
      title: 'Friend request',
      body: '${request.requesterName} wants to add you.',
      senderName: request.requesterName,
      updateLive: true,
    );
  }

  /// Enqueue a ping for the island banner. Keeps current head stable;
  /// prefers status pings over chat in the waiting tail.
  bool _enqueuePingAlert(FriendPing ping) {
    if (_ackedPingIds.contains(ping.id)) return false;
    if (_pingAlertQueue.any((p) => p.id == ping.id)) return false;

    final becameHead = _pingAlertQueue.isEmpty;
    if (becameHead) {
      _pingAlertQueue.add(ping);
    } else {
      final head = _pingAlertQueue.first;
      final rest = _pingAlertQueue.sublist(1)..add(ping);
      rest.sort((a, b) {
        if (a.isChat != b.isChat) return a.isChat ? 1 : -1;
        final aAt = a.createdAt;
        final bAt = b.createdAt;
        if (aAt != null && bAt != null) return aAt.compareTo(bAt);
        return 0;
      });
      _pingAlertQueue
        ..clear()
        ..add(head)
        ..addAll(rest);
    }

    if (becameHead) _surfacePingHead(ping);
    return true;
  }

  bool _enqueueRequestAlert(FriendRequest request) {
    if (_seenInboundRequestIds.contains(request.id)) return false;
    if (_requestAlertQueue.any((r) => r.id == request.id)) return false;

    final becameHead = _requestAlertQueue.isEmpty;
    _requestAlertQueue.add(request);
    if (becameHead) _surfaceRequestHead(request);
    return true;
  }

  void _clearSocialAlertQueues() {
    _pingAlertQueue.clear();
    _requestAlertQueue.clear();
    _eventGuestCheckinQueue.clear();
    _seenEventGuestCheckinIds.clear();
    _incomingPings = [];
    _seenInboundRequestIds.clear();
    _ackedPingIds.clear();
    _pushedAlertIds.clear();
    _resetTimeLowWarnings();
    _clearLiveSocialAlert();
  }

  void _clearLiveSocialAlert() {
    if (_liveSocialTitle == null &&
        _liveSocialBody == null &&
        _liveSocialSender == null) {
      return;
    }
    _liveSocialTitle = null;
    _liveSocialBody = null;
    _liveSocialSender = null;
    _syncLiveActivity(force: true);
  }

  void _startQrRefresh(QrPurpose purpose) {
    _qrRefreshTimer?.cancel();
    _refreshQr(purpose);
    _qrRefreshTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      _refreshQr(purpose);
      notifyListeners();
    });
  }

  void _startSyncPolling() {
    if (_sessionStore.usesRealtime) return;

    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _onSessionStoreChanged();
    });
  }

  void _refreshQr(QrPurpose purpose) {
    if (_user == null || _session == null) return;
    _currentQr = _qr.createPayload(
      userId: _user!.id,
      sessionId: _session!.id,
      memberName: _user!.name,
      purpose: purpose,
    );
  }

  /// Entry-purpose QR for event guest passes and door check-in.
  ///
  /// Always uses [QrPurpose.entry] so staff can scan once for venue entry and
  /// event check-in, even when the member is already inside (exit QR otherwise).
  QrPayload? createEntryCheckInQr() {
    if (_user == null || _session == null) return null;
    return _qr.createPayload(
      userId: _user!.id,
      sessionId: _session!.id,
      memberName: _user!.name,
      purpose: QrPurpose.entry,
    );
  }

  String formatDuration(int totalSeconds) {
    if (totalSeconds <= 0) return '0:00';
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
    return '${m}m ${s.toString().padLeft(2, '0')}s';
  }

  DrinkChargeSource _chargeSourceForDrink(
    Drink drink, {
    required bool payWithCash,
  }) => resolveDrinkChargeSource(
    payWithCash: payWithCash,
    inVipRoom: isInVipRoom,
    isStandardDrink: drink.isStandard,
    packageDrinksAvailable: drinksAllowanceAvailable,
    eventWalletCovers: _canCoverDrinkWithEventWallet(drink),
  );

  /// Public preview of which balance a pour would book against.
  DrinkChargeSource chargeSourceForDrink(
    Drink drink, {
    bool payWithCash = false,
  }) => _chargeSourceForDrink(drink, payWithCash: payWithCash);

  /// Guest sends a drink order to the bar — nothing is charged until served.
  Future<DrinkOrder?> placeDrinkOrder(
    Drink drink, {
    bool payWithCash = false,
  }) async {
    if (!isInsideClub || _user == null || _session == null) return null;
    if (_walletBusy) return null;
    if (!canAffordDrink(drink, payWithCash: payWithCash)) return null;

    final chargeSource = _chargeSourceForDrink(drink, payWithCash: payWithCash);
    final costSeconds = drinkOrderCostSeconds(drink, payWithCash: payWithCash);

    DrinkOrder order;
    try {
      order = await _drinkOrders.placeOrder(
        sessionId: _session!.id,
        memberId: _user!.id,
        memberName: _user!.name,
        drinkId: drink.id,
        drinkName: drink.name,
        chargeSource: chargeSource,
        costSeconds: costSeconds,
        payWithCash: payWithCash,
        vipRoomName: isInVipRoom ? activeVipRoomName : null,
        eventId: chargeSource == DrinkChargeSource.eventWallet
            ? _eventWalletEventId
            : null,
      );
    } on StateError {
      return null;
    }

    _drinksOrdered++;
    _session!.drinksOrdered = _drinksOrdered;
    await _sessionStore.upsert(_session!);

    unawaited(_sounds.playGlassClink());
    final tabNote = isInVipRoom && !payWithCash
        ? ' · VIP room tab pending'
        : '';
    _addFeedEvent('ordered ${drink.name} — waiting at the bar$tabNote');
    _syncLiveActivity(force: true);
    notifyListeners();
    return order;
  }

  /// Staff: bartender starts pouring.
  Future<void> staffStartPreparingDrink(String orderId) async {
    await _drinkOrders.markPreparing(orderId);
  }

  /// Staff: mark served — guest device settles the charge.
  Future<String?> staffFulfillDrinkOrder(String orderId) async {
    if (!isStaff) return 'Staff only.';
    final order = _drinkOrders.getOrder(orderId);
    if (order == null || !order.isActive) return 'Order not found.';

    final delivered = await _drinkOrders.markDelivered(
      orderId: orderId,
      staffId: _user?.id,
      staffName: _user?.name,
    );
    // Never report a serve the bar queue did not record — the row would stay
    // pending in Supabase and reappear on the guest's phone later.
    if (delivered == null) {
      return 'Could not mark it served — check connection and try again.';
    }
    return null;
  }

  Future<void> staffCancelDrinkOrder(String orderId) async {
    if (!isStaff) return;
    await _drinkOrders.cancelOrder(orderId);
  }

  /// Guest settles delivered orders and enqueues celebration alerts.
  Future<void> _processDeliveredDrinkOrders() async {
    if (_user == null || isStaff) return;

    for (final order in _drinkOrders.allOrders) {
      if (order.memberId != _user!.id) continue;
      if (order.status != DrinkOrderStatus.delivered || order.settled) continue;
      if (_settlingDrinkOrderIds.contains(order.id)) continue;
      _settlingDrinkOrderIds.add(order.id);

      final alert = await _settleDrinkOrder(order);
      if (alert != null) {
        // The overlay is presentation-only: only enqueue it after the
        // authoritative order row confirms settlement. Settled rows are
        // excluded from hydration, so this cannot replay after relogin or a
        // reinstall.
        final settled = await _drinkOrders.markSettled(order.id);
        if (settled?.settled == true) {
          _drinkDeliveryAlertQueue.add(alert);
        }
      } else {
        // Still terminate the row — an unsettled delivery would otherwise come
        // back as a live order forever — but make the debt visible.
        _addFeedEvent(
          '${order.drinkName} served — no balance left to cover it, settle at the bar.',
        );
        await _drinkOrders.markSettled(order.id, reason: 'unpaid_balance');
      }
      _settlingDrinkOrderIds.remove(order.id);
      notifyListeners();
    }
  }

  /// Minutes a delivered order costs when settled against [source]. Package
  /// drinks book 0 seconds, so a fallback needs the drink's own time price.
  int _settlementCostSeconds(DrinkOrder order, DrinkChargeSource source) {
    if (source == DrinkChargeSource.packageAllowance ||
        source == DrinkChargeSource.cashAtBar) {
      return 0;
    }
    if (order.costSeconds > 0) return order.costSeconds;
    final catalogDrink = DrinkCatalog.bySlug(order.drinkId);
    if (catalogDrink != null) return _drinkFallbackCostSeconds(catalogDrink);
    return standardDrinkVipTabSeconds;
  }

  Future<DrinkDeliveryAlert?> _settleDrinkOrder(DrinkOrder order) async {
    int? balanceBefore;
    int? balanceAfter;
    int? eventWalletBefore;
    int? eventWalletAfter;
    int? vipBefore;
    int? vipAfter;
    int? packageRemaining;
    DrinkChargeSource? settledSource;
    var settledCostSeconds = 0;

    Future<bool> chargeVia(DrinkChargeSource source, int costSeconds) async {
      switch (source) {
        case DrinkChargeSource.eventWallet:
          final attendance = _activeEventAttendance;
          final eventId =
              order.eventId ?? attendance?.eventId ?? activeHostedEvent?.id;
          final available =
              attendance?.walletSeconds ?? activeHostedEvent?.walletSeconds ?? 0;
          if (eventId == null || available < costSeconds) return false;
          eventWalletBefore = available;
          try {
            _activeEventAttendance = await _events.consumeEventWalletForDrink(
              eventId: eventId,
              orderId: order.id,
              costSeconds: costSeconds,
            );
            eventWalletAfter = _activeEventAttendance?.walletSeconds;
            unawaited(refreshEventState());
          } catch (_) {
            eventWalletBefore = null;
            eventWalletAfter = null;
            return false;
          }
        case DrinkChargeSource.vipRoomTab:
          if (_session == null || !isInVipRoom) return false;
          if (vipRoomTimeSeconds < costSeconds) return false;
          vipBefore = vipRoomTimeSeconds;
          _session!.vipRoomTimeSeconds = (vipRoomTimeSeconds - costSeconds)
              .clamp(0, vipRoomTimeSeconds);
          _session!.vipRoomDrinkMinutesSpent += costSeconds ~/ 60;
          vipAfter = _session!.vipRoomTimeSeconds;
          await _sessionStore.upsert(_session!);
        case DrinkChargeSource.packageAllowance:
          if (drinksAllowanceRemaining < 1) return false;
          try {
            if (usesCloud) {
              _user = await _auth.consumeIncludedDrink(sessionId: _session?.id);
              if (_session != null) {
                _session!.includedDrinksRemaining =
                    _user?.includedDrinksRemaining ?? 0;
              }
            } else {
              final next = mathMax(0, drinksAllowanceRemaining - 1);
              if (_session != null) {
                _session!.includedDrinksRemaining = next;
              }
              if (_user != null) {
                _user = _user!.copyWith(includedDrinksRemaining: next);
                await _auth.persistLocalUser(_user!);
              }
            }
            packageRemaining = drinksAllowanceRemaining;
          } catch (_) {
            return false;
          }
        case DrinkChargeSource.cashAtBar:
          break;
        case DrinkChargeSource.personalTime:
          if (costSeconds <= 0) return false;
          if (timeBalance < costSeconds) return false;
          balanceBefore = timeBalance;
          try {
            _user = await _auth.deductTimeBalance(costSeconds);
            balanceAfter = timeBalance;
          } catch (_) {
            return false;
          }
      }
      return true;
    }

    final ok = await _runExclusiveWallet<bool>(() async {
      for (final source in drinkSettlementFallbackChain(order.chargeSource)) {
        final costSeconds = _settlementCostSeconds(order, source);
        if (await chargeVia(source, costSeconds)) {
          settledSource = source;
          settledCostSeconds = costSeconds;
          break;
        }
      }
      if (settledSource == null) return false;

      if (_session != null) {
        await _sessionStore.upsert(_session!);
      }
      unawaited(_sounds.playGlassClink());
      _progressChallenge('chal-2', by: 1);
      _addPoints(10);
      final note = switch (settledSource!) {
        DrinkChargeSource.vipRoomTab => ' (VIP room tab)',
        DrinkChargeSource.personalTime
            when order.chargeSource != DrinkChargeSource.personalTime =>
          ' (package allowance was empty — charged to your time)',
        DrinkChargeSource.eventWallet
            when order.chargeSource != DrinkChargeSource.eventWallet =>
          ' (charged to the event wallet)',
        _ => '',
      };
      _addFeedEvent('${order.drinkName} served$note!');
      return true;
    }, onBusy: false);

    if (ok != true) return null;

    return DrinkDeliveryAlert(
      orderId: order.id,
      drinkName: order.drinkName,
      chargeSource: settledSource ?? order.chargeSource,
      costSeconds: settledCostSeconds,
      balanceBefore: balanceBefore,
      balanceAfter: balanceAfter,
      eventWalletBefore: eventWalletBefore,
      eventWalletAfter: eventWalletAfter,
      vipTabBefore: vipBefore,
      vipTabAfter: vipAfter,
      bartenderName: order.fulfilledByStaffName,
      packageDrinksRemaining: packageRemaining,
    );
  }

  /// Legacy alias — routes to [placeDrinkOrder].
  Future<bool> orderDrink(Drink drink, {bool payWithCash = false}) async {
    final order = await placeDrinkOrder(drink, payWithCash: payWithCash);
    return order != null;
  }

  final _drinkPos = DrinkPosService();

  /// Staff POS: open a payment ticket for the cart (QR for guest scan).
  Future<(DrinkPosTicket?, DrinkPayPayload?, String?)> staffCreateDrinkPosTicket(
    List<DrinkPosCartLine> lines,
  ) async {
    if (!isStaff) return (null, null, 'Staff only.');
    if (_user == null) return (null, null, 'Not signed in.');
    try {
      final ticket = await _drinkPos.createTicket(lines);
      final payload = DrinkPayPayload(
        ticketId: ticket.id,
        staffId: ticket.staffId,
        staffName: ticket.staffName,
        timestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        lineCount: ticket.lineCount,
      );
      return (ticket, payload, null);
    } catch (e) {
      return (null, null, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> staffCancelDrinkPosTicket(String ticketId) async {
    if (!isStaff) return;
    await _drinkPos.cancelTicket(ticketId);
  }

  RealtimeChannel? watchDrinkPosTicket({
    required String ticketId,
    required void Function(DrinkPosTicket ticket) onUpdate,
  }) {
    if (!usesCloud) return null;
    return _drinkPos.watchTicket(ticketId: ticketId, onUpdate: onUpdate);
  }

  /// Guest: scan bartender POS QR and settle payment + celebration alert.
  Future<(DrinkPosPaymentResult?, String?)> payDrinkPosTicket(
    DrinkPayPayload payload,
  ) async {
    if (isStaff) return (null, 'Guests pay this QR.');
    if (!isInsideClub) {
      return (null, 'Scan in at the door before paying at the bar.');
    }
    if (!payload.isFresh) {
      return (null, 'Payment QR expired — ask the bartender to start a new order.');
    }

    try {
      final result = await _runExclusiveWallet<DrinkPosPaymentResult>(() async {
        final paid = await _drinkPos.payTicket(payload.ticketId);
        _user = await _auth.getCurrentUser() ?? _user;
        if (_session != null && _user != null) {
          _session!.includedDrinksRemaining = _user!.includedDrinksRemaining;
          await _sessionStore.upsert(_session!);
        }
        await _drinkOrders.refresh();
        return paid;
      });

      if (result == null) return (null, 'Wallet busy — try again.');

      final chargeSource = result.chargedSeconds > 0
          ? DrinkChargeSource.personalTime
          : DrinkChargeSource.packageAllowance;

      _drinkDeliveryAlertQueue.add(
        DrinkDeliveryAlert(
          orderId: result.ticketId,
          drinkName: result.drinkNames,
          chargeSource: chargeSource,
          costSeconds: result.chargedSeconds,
          balanceBefore: result.balanceBefore,
          balanceAfter: result.balanceAfter,
          bartenderName: result.staffName,
          packageDrinksRemaining: result.packageDrinksAfter,
        ),
      );
      _addFeedEvent('Paid at the bar · ${result.drinkNames}');
      unawaited(_sounds.playGlassClink());
      _syncLiveActivity(force: true);
      notifyListeners();
      return (result, null);
    } catch (e) {
      return (null, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// Allowance units still banked. The profile row is the server's truth, so a
  /// session row that never saw a burn (stale cache, reinstall, relogin) can
  /// never hand back drinks that were already consumed.
  int get drinksAllowanceRemaining {
    final profileRemaining = _user?.includedDrinksRemaining ?? 0;
    final session = _session;
    if (session == null) return profileRemaining;
    return mathMin(session.includedDrinksRemaining, profileRemaining);
  }

  /// Allowance units already committed to orders still waiting at the bar.
  ///
  /// The burn only happens when the bartender serves, so without this an
  /// allowance of 1 could be spent by every order queued before the first
  /// serve — every one of them poured free.
  int get reservedPackageDrinks {
    final memberId = _user?.id;
    if (memberId == null) return 0;
    return _drinkOrders
        .activeForMember(memberId)
        .where((o) => o.chargeSource == DrinkChargeSource.packageAllowance)
        .length;
  }

  /// Allowance a new order may claim.
  int get drinksAllowanceAvailable =>
      mathMax(0, drinksAllowanceRemaining - reservedPackageDrinks);

  /// Spend minutes on a venue experience (VIP Lounge, VVIP Room, etc.).
  Future<bool> redeemVenueActivity(VenueActivity activity) async {
    if (!canSpendTime || _session == null) return false;
    if (_walletBusy) return false;

    if (activity.isVipRoomExperience) {
      return _bookVipRoom(activity);
    }

    final costSeconds = activity.timeCostMinutes * 60;
    if (timeBalance < costSeconds) {
      unawaited(_sounds.playSoftThud());
      return false;
    }

    final result = await _runExclusiveWallet<bool>(() async {
      if (timeBalance < costSeconds) {
        unawaited(_sounds.playSoftThud());
        return false;
      }
      try {
        _user = await _auth.redeemVenueActivity(
          activitySlug: activity.slug,
          minutes: activity.timeCostMinutes,
          sessionId: _session!.id,
        );
      } catch (_) {
        unawaited(_sounds.playSoftThud());
        return false;
      }
      _session!.experiencesMinutesSpent += activity.timeCostMinutes;
      await _sessionStore.upsert(_session!);
      _addFeedEvent(
        'unlocked ${activity.name} (−${activity.timeCostMinutes} min)',
      );
      return true;
    }, onBusy: false);

    return result ?? false;
  }

  /// Book a VIP room/couch — loads room time (decays instead of personal while active).
  Future<bool> _bookVipRoom(VenueActivity activity) async {
    if (_session == null) return false;
    if (blocksVipRoomDueToHostedEvent) {
      unawaited(_sounds.playSoftThud());
      return false;
    }

    final tabSeconds = activity.timeCostMinutes * 60;

    final result = await _runExclusiveWallet<bool>(() async {
      if (blocksVipRoomDueToHostedEvent) {
        unawaited(_sounds.playSoftThud());
        return false;
      }
      _session!.activeVipRoomSlug = activity.slug;
      _session!.vipRoomTimeSeconds = tabSeconds;
      _session!.vipRoomDrinkMinutesSpent = 0;
      _roomTimerSyncDebt = 0;
      await _sessionStore.upsert(_session!);
      _addFeedEvent(
        'booked ${activity.name} · ${activity.timeCostMinutes} min room time loaded',
      );
      _addPoints(20);
      return true;
    }, onBusy: false);

    if (result == true) {
      // Resume meter even if personal wallet is empty — room time must decay.
      if (_meterShouldRun && (_timer == null || !_timer!.isActive)) {
        _startTimer();
      }
      notifyListeners();
    }
    return result ?? false;
  }

  Future<void> leaveVipRoom() async {
    if (_session == null || !isInVipRoom) return;
    final name = activeVipRoomName ?? 'VIP room';
    await _flushRoomTimerSync();
    _session!.activeVipRoomSlug = null;
    _session!.vipRoomTimeSeconds = 0;
    _roomTimerSyncDebt = 0;
    await _sessionStore.upsert(_session!);
    _addFeedEvent('left $name');
    // Personal timer resumes automatically on the next tick if balance remains.
    if (_meterShouldRun && (_timer == null || !_timer!.isActive)) {
      _startTimer();
    }
    notifyListeners();
  }

  /// Ends VIP occupancy when the member becomes host of a live event wallet.
  Future<void> _clearVipRoomIfHostedEventConflict() async {
    if (!VipHostedEventConflict.shouldClearActiveVip(
      activeHostedEvent: activeHostedEvent,
      isInVipRoom: isInVipRoom,
    )) {
      return;
    }
    if (_session == null) return;

    await _flushRoomTimerSync();
    _session!.activeVipRoomSlug = null;
    _session!.vipRoomTimeSeconds = 0;
    _roomTimerSyncDebt = 0;
    await _sessionStore.upsert(_session!);
    _addFeedEvent(VipHostedEventConflict.autoClearedFeedMessage);
    if (_meterShouldRun && (_timer == null || !_timer!.isActive)) {
      _startTimer();
    }
  }

  TimerBand get currentTimerBand => AppColors.timerBand(timeBalance ~/ 60);

  void _maybeAnnounceTimerBand() {
    if (sessionPhase != SessionPhase.insideClub &&
        sessionPhase != SessionPhase.awaitingExitScan) {
      return;
    }
    final band = currentTimerBand;
    final key = band.name;
    if (_lastAnnouncedBand == key) return;
    final previous = _lastAnnouncedBand;
    _lastAnnouncedBand = key;
    if (previous == null) return;
    // Soft notice on band change only (battery psychology).
    _addFeedEvent(band.guestHint);
  }

  String _formatMinutes(int seconds) {
    final m = seconds ~/ 60;
    return m == 1 ? '1 minute' : '$m minutes';
  }

  /// Raise a claimable toast code — lose minutes, roommate/friend can claim.
  Future<(TimeGift?, String?)> raiseToast({
    required int minutes,
    String? message,
  }) async {
    final seconds = minutes * 60;
    if (timeBalance < seconds) {
      return (null, 'Not enough time. Need ${_formatMinutes(seconds)}.');
    }
    if (_walletBusy) {
      return (null, 'Hang on — another spend is still processing.');
    }

    try {
      final outcome = await _runExclusiveWallet<(TimeGift?, String?)>(() async {
        if (timeBalance < seconds) {
          return (null, 'Not enough time. Need ${_formatMinutes(seconds)}.');
        }
        final gift = await _gifts.raiseToast(
          seconds: seconds,
          message: message,
        );
        if (usesCloud) {
          _user = await _auth.refreshProfile() ?? _user;
        } else {
          _user = await _auth.deductTimeBalance(seconds);
        }
        _addFeedEvent(
          'raised a ${minutes}m toast${gift.code != null ? ' — find me for ${gift.code}' : ''}',
        );
        _visitRecap.timeGiftedMinutes += minutes;
        _setQuestProgress('time-1', _visitRecap.timeGiftedMinutes);
        _addPoints(5);
        unawaited(_sounds.playGlassClink());
        return (gift, null);
      }, onBusy: (null, 'Hang on — another spend is still processing.'));
      return outcome ?? (null, 'Could not raise toast.');
    } on TimeGiftException catch (e) {
      return (null, e.message);
    } catch (_) {
      return (null, 'Could not raise toast.');
    }
  }

  /// Tip the house — pulse a thank-you into the tip jar (time spent, status social).
  Future<(TimeGift?, String?)> tipTheHouse({
    required int minutes,
    String? message,
  }) async {
    final seconds = minutes * 60;
    if (timeBalance < seconds) {
      return (null, 'Not enough time. Need ${_formatMinutes(seconds)}.');
    }
    if (_walletBusy) {
      return (null, 'Hang on — another spend is still processing.');
    }

    try {
      final outcome = await _runExclusiveWallet<(TimeGift?, String?)>(() async {
        if (timeBalance < seconds) {
          return (null, 'Not enough time. Need ${_formatMinutes(seconds)}.');
        }
        final gift = await _gifts.tipHouse(seconds: seconds, message: message);
        if (usesCloud) {
          _user = await _auth.refreshProfile() ?? _user;
        } else {
          _user = await _auth.deductTimeBalance(seconds);
        }
        _addFeedEvent(
          'tipped the house ${_formatMinutes(seconds)} — class act',
        );
        _addPoints(8);
        _progressChallenge('chal-6', by: 1);
        unawaited(_sounds.playGlassClink());
        return (gift, null);
      }, onBusy: (null, 'Hang on — another spend is still processing.'));
      return outcome ?? (null, 'Could not send tip.');
    } on TimeGiftException catch (e) {
      return (null, e.message);
    } catch (_) {
      return (null, 'Could not send tip.');
    }
  }

  /// Tip a specific bartender via NFC-style tip pad (QR).
  Future<(TimeGift?, String?)> tipBartender({
    required String staffId,
    required String staffName,
    required int minutes,
    String? message,
  }) async {
    final seconds = minutes * 60;
    if (timeBalance < seconds) {
      return (null, 'Not enough time. Need ${_formatMinutes(seconds)}.');
    }
    if (_walletBusy) {
      return (null, 'Hang on — another spend is still processing.');
    }

    try {
      final outcome = await _runExclusiveWallet<(TimeGift?, String?)>(() async {
        if (timeBalance < seconds) {
          return (null, 'Not enough time. Need ${_formatMinutes(seconds)}.');
        }
        final gift = await _gifts.tipBartender(
          staffId: staffId,
          seconds: seconds,
          message: message,
        );
        if (usesCloud) {
          _user = await _auth.refreshProfile() ?? _user;
        } else {
          _user = await _auth.deductTimeBalance(seconds);
        }
        _addFeedEvent(
          'tapped $staffName tip pad — ${_formatMinutes(seconds)} poured',
        );
        _addPoints(10);
        unawaited(_sounds.playGlassClink());
        return (gift, null);
      }, onBusy: (null, 'Hang on — another spend is still processing.'));
      return outcome ?? (null, 'Could not tip bartender.');
    } on TimeGiftException catch (e) {
      return (null, e.message);
    } catch (_) {
      return (null, 'Could not tip bartender.');
    }
  }

  void startStaffTipWatch(void Function(StaffTipReceived tip) onTip) {
    if (_user == null) return;

    _staffTipCallback = onTip;
    _staffTipWatchBalance = timeBalance;
    _lastHandledTipId = null;
    _lastHandledTipAt = null;

    _auth.startStaffTipWatch(
      staffId: _user!.id,
      onTip: (event) => _handleStaffTipEvent(event),
    );
  }

  void stopStaffTipWatch() {
    _auth.stopStaffTipWatch();
    _staffTipCallback = null;
  }

  Future<void> _handleStaffTipEvent(StaffTipEvent event) async {
    if (_staffTipCallback == null) return;

    _user = await _auth.refreshProfile() ?? _user;
    final after = timeBalance;
    final before = (after - event.seconds).clamp(0, after);

    _emitStaffTip(
      StaffTipReceived(
        tipSeconds: event.seconds,
        fromBalance: before,
        toBalance: after,
        guestName: event.fromMemberName,
        transferId: event.transferId,
      ),
    );
    notifyListeners();
  }

  void _emitStaffTip(StaffTipReceived tip) {
    final callback = _staffTipCallback;
    if (callback == null) return;

    final now = DateTime.now();
    if (tip.transferId != null && tip.transferId == _lastHandledTipId) return;
    if (_lastHandledTipAt != null &&
        now.difference(_lastHandledTipAt!) < const Duration(seconds: 3) &&
        tip.tipSeconds ==
            (_staffTipWatchBalance < tip.toBalance
                ? tip.toBalance - _staffTipWatchBalance
                : tip.tipSeconds)) {
      return;
    }

    _lastHandledTipId = tip.transferId;
    _lastHandledTipAt = now;
    _staffTipWatchBalance = tip.toBalance;
    callback(tip);
  }

  /// Claim a glass code — minutes land in wallet.
  Future<(TimeGift?, String?)> claimToast(String code) async {
    if (_user == null) return (null, 'Not signed in.');

    try {
      final gift = await _gifts.claimToast(code);
      _user = await _auth.refreshProfile() ?? _user;
      _addFeedEvent(
        'caught a ${gift.minutes}m toast from ${gift.fromMemberName}',
      );
      _visitRecap.timeReceivedMinutes += gift.minutes;
      _setQuestProgress('time-2', 1);
      _addPoints(3);
      notifyListeners();
      return (gift, null);
    } on TimeGiftException catch (e) {
      return (null, e.message);
    } catch (_) {
      return (null, 'Could not claim toast.');
    }
  }

  // ─── Social PLAY ─────────────────────────────────────────────────────────

  Future<void> setOpenToMeet(bool open, {String? vibeTag}) async {
    if (_user == null) return;
    if (open && !canSpendTime) return;

    final tag = vibeTag ?? _vibeTag;
    try {
      await _social.setOpenToMeet(
        open: open,
        branch: _session?.branch ?? _selectedBranch,
        displayName: _user!.name,
        memberId: _user!.id,
        sessionId: _session?.id,
        vibeTag: tag,
      );
      _openToMeet = open;
      _vibeTag = tag;
      if (open) {
        startPresencePolling();
      } else {
        stopPresencePolling();
      }
      await refreshWhosInside();
      notifyListeners();
    } on SocialPlayException {
      // Keep prior state.
    } catch (_) {}
  }

  void setVibeTag(String tag) {
    _vibeTag = tag;
    if (_openToMeet) {
      unawaited(setOpenToMeet(true, vibeTag: tag));
    } else {
      notifyListeners();
    }
  }

  void startPresencePolling() {
    _presencePoll?.cancel();
    unawaited(refreshWhosInside());
    _presencePoll = Timer.periodic(const Duration(seconds: 12), (_) {
      unawaited(refreshWhosInside());
    });
  }

  void stopPresencePolling() {
    _presencePoll?.cancel();
    _presencePoll = null;
  }

  Future<void> refreshWhosInside() async {
    final branch = _session?.branch ?? _selectedBranch;
    try {
      if (_openToMeet && !canSpendTime) {
        await _social.clearPresence();
        _openToMeet = false;
        _whosInside = [];
        notifyListeners();
        return;
      }

      if (_openToMeet && _user != null && canSpendTime) {
        await _social.setOpenToMeet(
          open: true,
          branch: branch,
          displayName: _user!.name,
          memberId: _user!.id,
          sessionId: _session?.id,
          vibeTag: _vibeTag,
        );
      }

      final list = await _social.listWhosInside(
        branch: branch,
        selfId: _user?.id,
      );
      _whosInside = list
          .where((p) => !_blockedMemberIds.contains(p.memberId))
          .toList();
      notifyListeners();
    } catch (_) {}
  }

  Future<String?> searchFriendCandidates(String query) async {
    final user = _user;
    if (user == null) return 'Not signed in.';
    try {
      _friendSearchResults = await _safety.searchMembers(
        query: query,
        selfId: user.id,
      );
      notifyListeners();
      return null;
    } on SafetySocialException catch (e) {
      return e.message;
    } catch (_) {
      return 'Could not search members.';
    }
  }

  Future<String?> sendFriendRequest(FriendProfile profile) async {
    final user = _user;
    if (user == null) return 'Not signed in.';
    try {
      await _safety.sendFriendRequest(
        recipientId: profile.memberId,
        recipientName: profile.displayName,
        requesterId: user.id,
        requesterName: user.name,
      );
      _friendSearchResults = _friendSearchResults
          .where((p) => p.memberId != profile.memberId)
          .toList();
      await refreshFriendRequests();
      notifyListeners();
      return null;
    } on SafetySocialException catch (e) {
      return e.message;
    } catch (_) {
      return 'Could not send friend request.';
    }
  }

  Future<void> refreshFriendRequests() async {
    final user = _user;
    if (user == null) return;
    try {
      _friendRequests = await _safety.listFriendRequests(selfId: user.id);
      for (final request in _friendRequests) {
        if (request.direction != 'inbound' ||
            request.status != FriendRequestStatus.pending) {
          continue;
        }
        _enqueueRequestAlert(request);
      }
      notifyListeners();
    } catch (_) {}
  }

  void clearPendingRequestAlert() {
    if (_requestAlertQueue.isEmpty) return;
    final cleared = _requestAlertQueue.removeAt(0);
    _seenInboundRequestIds.add(cleared.id);
    _clearLiveSocialAlert();
    _promoteNextAlertSurface();
    notifyListeners();
  }

  Future<void> refreshIncomingPings() async {
    final user = _user;
    if (user == null) return;
    try {
      final list = await _safety.listFriendNotifications(
        selfId: user.id,
        unreadOnly: true,
      );
      _incomingPings = list;

      for (final ping in list) {
        _enqueuePingAlert(ping);
      }

      notifyListeners();
    } catch (_) {}
  }

  void clearPendingPingAlert() {
    if (_pingAlertQueue.isEmpty) return;
    _pingAlertQueue.removeAt(0);
    _clearLiveSocialAlert();
    _promoteNextAlertSurface();
    notifyListeners();
  }

  /// Mark read, dequeue the modal, and promote the next unread ping if any.
  Future<void> acknowledgePing(FriendPing ping) async {
    final user = _user;
    if (user == null) return;

    _ackedPingIds.add(ping.id);
    _pingAlertQueue.removeWhere((p) => p.id == ping.id);
    _incomingPings = _incomingPings.where((p) => p.id != ping.id).toList();
    _clearLiveSocialAlert();

    // Promote next queued ping (already ordered); else scan inbox leftovers.
    if (_pingAlertQueue.isEmpty) {
      for (final candidate in _incomingPings) {
        if (_ackedPingIds.contains(candidate.id)) continue;
        _enqueuePingAlert(candidate);
        break;
      }
    } else {
      _surfacePingHead(_pingAlertQueue.first);
    }

    notifyListeners();

    try {
      await _safety.markNotificationRead(
        notificationId: ping.id,
        selfId: user.id,
      );
    } catch (_) {}

    if (_pingAlertQueue.isEmpty) {
      await refreshIncomingPings();
    }
  }

  Future<void> dismissPing(FriendPing ping) => acknowledgePing(ping);

  Future<void> refreshSocialInbox({bool includeNearby = false}) async {
    await Future.wait([
      refreshFriendRequests(),
      refreshIncomingPings(),
      refreshEventHostAlerts(),
      if (includeNearby) refreshMutualFriendsNearby(),
    ]);
  }

  void startSocialInboxPolling() {
    _socialInboxPoll?.cancel();
    final userId = _user?.id;
    if (userId != null) {
      _safety.startInboxWatch(
        selfId: userId,
        onChanged: () {
          // Realtime poke — pull unread immediately.
          unawaited(refreshSocialInbox());
        },
      );
    }
    unawaited(refreshSocialInbox(includeNearby: true));
    // Backup poll (realtime can miss events); keep this light and frequent.
    _socialInboxPoll = Timer.periodic(const Duration(seconds: 3), (_) {
      unawaited(refreshSocialInbox());
    });
  }

  void stopSocialInboxPolling() {
    _socialInboxPoll?.cancel();
    _socialInboxPoll = null;
    _safety.stopInboxWatch();
  }

  Future<bool> areFriendsWith(String memberId) async {
    final user = _user;
    if (user == null) return false;
    try {
      return await _safety.areFriends(otherId: memberId, selfId: user.id);
    } catch (_) {
      return false;
    }
  }

  Future<List<FriendMessage>> loadFriendChat(String friendId) async {
    final user = _user;
    if (user == null) return const [];
    try {
      return await _safety.listFriendMessages(
        friendId: friendId,
        selfId: user.id,
      );
    } on SafetySocialException {
      rethrow;
    } catch (e) {
      throw SafetySocialException('Could not load chat.');
    }
  }

  Future<List<FriendProfile>> listMyFriends() async {
    final user = _user;
    if (user == null) return const [];
    try {
      return await _safety.listMyFriends(selfId: user.id);
    } catch (_) {
      return const [];
    }
  }

  Future<String?> sendFriendChatMessage(String friendId, String body) async {
    final user = _user;
    if (user == null) return 'Not signed in.';
    try {
      await _safety.sendFriendMessage(
        friendId: friendId,
        selfId: user.id,
        body: body,
      );
      return null;
    } on SafetySocialException catch (e) {
      return e.message;
    } catch (_) {
      return 'Could not send message.';
    }
  }

  Future<String?> acceptFriendRequest(FriendRequest request) async {
    final user = _user;
    if (user == null) return 'Not signed in.';
    try {
      await _safety.acceptFriendRequest(requestId: request.id, selfId: user.id);
      await refreshFriendRequests();
      await refreshMutualFriendsNearby();
      notifyListeners();
      return null;
    } on SafetySocialException catch (e) {
      return e.message;
    } catch (_) {
      return 'Could not accept friend request.';
    }
  }

  Future<String?> declineFriendRequest(FriendRequest request) async {
    final user = _user;
    if (user == null) return 'Not signed in.';
    try {
      await _safety.declineFriendRequest(
        requestId: request.id,
        selfId: user.id,
      );
      await refreshFriendRequests();
      return null;
    } on SafetySocialException catch (e) {
      return e.message;
    } catch (_) {
      return 'Could not decline friend request.';
    }
  }

  Future<void> refreshMutualFriendsNearby() async {
    final user = _user;
    if (user == null) return;
    final branch = _session?.branch ?? _selectedBranch;
    try {
      _mutualFriendsNearby = await _safety.listMutualFriendsNearby(
        branch: branch,
        selfId: user.id,
      );
      notifyListeners();
    } catch (_) {}
  }

  Future<String?> notifyFriend(FriendProfile friend, String message) async {
    final user = _user;
    if (user == null) return 'Not signed in.';
    try {
      _lastFriendPing = await _safety.notifyFriend(
        friendId: friend.memberId,
        selfId: user.id,
        message: message,
      );
      // Private — never post pings to the public lounge feed.
      notifyListeners();
      return null;
    } on SafetySocialException catch (e) {
      return e.message;
    } catch (_) {
      return 'Could not notify friend.';
    }
  }

  Future<String?> blockMember(String memberId, {String? reason}) async {
    final user = _user;
    if (user == null) return 'Not signed in.';
    try {
      await _safety.blockMember(
        blockedId: memberId,
        selfId: user.id,
        reason: reason,
      );
      _blockedMemberIds.add(memberId);
      _whosInside = _whosInside.where((p) => p.memberId != memberId).toList();
      _mutualFriendsNearby = _mutualFriendsNearby
          .where((p) => p.memberId != memberId)
          .toList();
      _friendSearchResults = _friendSearchResults
          .where((p) => p.memberId != memberId)
          .toList();
      notifyListeners();
      return null;
    } on SafetySocialException catch (e) {
      return e.message;
    } catch (_) {
      return 'Could not block member.';
    }
  }

  Future<String?> submitSafetyReport({
    required String category,
    String? description,
    String? reportedMemberId,
  }) async {
    final branch = _session?.branch ?? _selectedBranch;
    try {
      _lastSafetyReport = await _safety.submitSafetyReport(
        category: category,
        branch: branch,
        description: description,
        reportedMemberId: reportedMemberId,
        sessionId: _session?.id,
      );
      notifyListeners();
      return null;
    } on SafetySocialException catch (e) {
      return e.message;
    } catch (_) {
      return 'Could not submit report.';
    }
  }

  Future<(RideAssistRequest?, String?)> requestRideAssist({
    required String destination,
  }) async {
    final branch = _session?.branch ?? _selectedBranch;
    try {
      final ride = await _safety.requestRideAssist(
        pickupBranch: branch,
        destination: destination,
      );
      _lastRideAssistRequest = ride;
      notifyListeners();
      return (ride, null);
    } on SafetySocialException catch (e) {
      return (null, e.message);
    } catch (_) {
      return (null, 'Could not request ride assistance.');
    }
  }

  Future<(InsuranceIncident?, String?)> createInsuranceIncident({
    required String incidentType,
    required bool consentToShare,
    String? reportId,
  }) async {
    try {
      final incident = await _safety.createInsuranceIncident(
        incidentType: incidentType,
        consentToShare: consentToShare,
        reportId: reportId,
      );
      _lastInsuranceIncident = incident;
      notifyListeners();
      return (incident, null);
    } on SafetySocialException catch (e) {
      return (null, e.message);
    } catch (_) {
      return (null, 'Could not create insurance incident.');
    }
  }

  Future<(SocialMeet?, String?)> raiseMeetToast({int minutes = 2}) async {
    return _raiseMeet(minutes: minutes, kind: MeetKind.toast);
  }

  Future<(SocialMeet?, String?)> raiseDuoBeat({int minutes = 2}) async {
    return _raiseMeet(minutes: minutes, kind: MeetKind.duoBeat);
  }

  Future<(SocialMeet?, String?)> _raiseMeet({
    required int minutes,
    required MeetKind kind,
  }) async {
    if (_user == null) return (null, 'Not signed in.');
    if (!canSpendTime) return (null, 'You need to be inside with time left.');
    if (_walletBusy) {
      return (null, 'Hang on — another spend is still processing.');
    }
    final seconds = minutes * 60;
    if (timeBalance < seconds) {
      return (null, 'Not enough time. Need ${_formatMinutes(seconds)}.');
    }

    try {
      final outcome = await _runExclusiveWallet<(SocialMeet?, String?)>(
        () async {
          if (timeBalance < seconds) {
            return (null, 'Not enough time. Need ${_formatMinutes(seconds)}.');
          }
          final meet = await _social.raiseMeet(
            seconds: seconds,
            kind: kind,
            hostId: _user!.id,
            hostName: _user!.name,
          );
          if (usesCloud) {
            _user = await _auth.refreshProfile() ?? _user;
          } else {
            _user = await _auth.deductTimeBalance(seconds);
          }
          _activeMeet = meet;
          final label = kind == MeetKind.duoBeat
              ? 'duo Beat Sync'
              : 'Toast to Meet';
          _addFeedEvent(
            'raised a $label${meet.code != null ? ' — code ${meet.code}' : ''}',
          );
          _addPoints(6);
          unawaited(_sounds.playGlassClink());
          return (meet, null);
        },
        onBusy: (null, 'Hang on — another spend is still processing.'),
      );
      return outcome ?? (null, 'Could not raise meet.');
    } on SocialPlayException catch (e) {
      return (null, e.message);
    } catch (_) {
      return (null, 'Could not raise meet.');
    }
  }

  Future<(SocialMeet?, String?)> joinMeet(String code) async {
    if (_user == null) return (null, 'Not signed in.');
    if (!canSpendTime) return (null, 'You need to be inside with time left.');

    try {
      final meet = await _social.joinMeet(
        code: code,
        guestId: _user!.id,
        guestName: _user!.name,
      );
      if (usesCloud) {
        _user = await _auth.refreshProfile() ?? _user;
      } else {
        // Local: credit guest the host's pour.
        _user = await _auth.addTimeBalance(meet.seconds);
      }
      _activeMeet = meet;
      if (meet.kind == MeetKind.toast) {
        _progressChallenge('chal-4', by: 1);
        _onQuestSocialAction('toast');
      }
      final other = meet.hostName;
      _recordPersonMet(other);
      _addFeedEvent(
        meet.kind == MeetKind.duoBeat
            ? 'joined $other for Duo Beat Sync'
            : 'toasted with $other — icebreaker unlocked',
      );
      _addPoints(10);
      unawaited(_sounds.playGlassClink());
      _syncLiveActivity(force: true);
      notifyListeners();
      return (meet, null);
    } on SocialPlayException catch (e) {
      return (null, e.message);
    } catch (_) {
      return (null, 'Could not join meet.');
    }
  }

  Future<(SocialMeet?, String?)> completeMeetIcebreaker() async {
    final meet = _activeMeet;
    if (meet == null) return (null, 'No active meet.');
    if (!meet.isMatched) return (null, 'Waiting for someone to join.');

    try {
      final done = await _social.completeIcebreaker(meet.id);
      _activeMeet = done;
      _addFeedEvent(
        'unlocked an icebreaker with ${done.hostId == _user?.id ? (done.guestName ?? 'a guest') : done.hostName}',
      );
      _onQuestSocialAction('meet');
      _addPoints(12);
      notifyListeners();
      return (done, null);
    } on SocialPlayException catch (e) {
      return (null, e.message);
    } catch (_) {
      return (null, 'Could not complete icebreaker.');
    }
  }

  Future<(SocialMeet?, String?)> submitDuoBeatScore(int score) async {
    final meet = _activeMeet;
    if (meet == null || _user == null) return (null, 'No active duo.');
    if (meet.kind != MeetKind.duoBeat) return (null, 'Not a duo game.');

    try {
      final updated = await _social.submitDuoScore(
        meetId: meet.id,
        score: score,
        memberId: _user!.id,
      );
      _activeMeet = updated;
      if (updated.status == MeetStatus.completed) {
        _awardDuoCompletion(updated);
      }
      notifyListeners();
      return (updated, null);
    } on SocialPlayException catch (e) {
      return (null, e.message);
    } catch (_) {
      return (null, 'Could not submit score.');
    }
  }

  String _opponentName(SocialMeet meet) {
    if (_user?.id == meet.hostId) return meet.guestName ?? 'guest';
    return meet.hostName;
  }

  void clearActiveMeet() {
    _activeMeet = null;
    notifyListeners();
  }

  Future<void> refreshActiveMeet() async {
    final code = _activeMeet?.code;
    if (code == null) return;
    final wasMatched = _activeMeet?.isMatched ?? false;
    try {
      final meet = await _social.fetchMeetByCode(code);
      if (meet != null) {
        _activeMeet = meet;
        // Host counts a stranger toast when someone joins their meet.
        if (!wasMatched &&
            meet.isMatched &&
            meet.kind == MeetKind.toast &&
            _user?.id == meet.hostId) {
          _progressChallenge('chal-4', by: 1);
        }
        if (meet.status == MeetStatus.completed &&
            meet.kind == MeetKind.duoBeat) {
          _awardDuoCompletion(meet);
        }
        notifyListeners();
      }
    } catch (_) {}
  }

  void _awardDuoCompletion(SocialMeet meet) {
    if (_user == null) return;
    if (_awardedMeetCompletions.contains(meet.id)) return;
    _awardedMeetCompletions.add(meet.id);
    final won = meet.winnerId == _user!.id;
    final draw =
        meet.winnerId == null &&
        meet.hostScore != null &&
        meet.guestScore != null;
    if (won) {
      _progressChallenge('chal-5', by: 1);
      _onQuestSocialAction('duo');
      _addPoints(25);
      _addFeedEvent('won Duo Beat Sync against ${_opponentName(meet)}');
    } else if (draw) {
      _addPoints(10);
      _addFeedEvent('tied Duo Beat Sync with ${_opponentName(meet)}');
    } else {
      _addPoints(8);
      _addFeedEvent('finished Duo Beat Sync with ${_opponentName(meet)}');
    }
  }

  Future<void> _clearSocialPresence() async {
    stopPresencePolling();
    _openToMeet = false;
    _whosInside = [];
    _activeMeet = null;
    try {
      await _social.clearPresence();
    } catch (_) {}
  }

  // ─── Time Economy & Quest System ─────────────────────────────────────────

  Future<void> _loadTimeEconomyProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _lifetimeVisits = prefs.getInt(_lifetimeVisitsKey) ?? 0;
      _lifetimeMinutesBanked = prefs.getInt(_lifetimeMinutesKey) ?? 0;
      _bankedTimeSeconds = prefs.getInt(_bankedTimeKey) ?? 0;
      _reputationXp = prefs.getInt(_reputationXpKey) ?? 0;
      _savedMinutesAcrossVisits = prefs.getInt('saved_minutes_v1') ?? 0;
      _communityPoolDonatedMinutes = prefs.getInt('pool_donated_v1') ?? 0;
      final badges = prefs.getStringList(_unlockedBadgesKey) ?? [];
      _unlockedBadges
        ..clear()
        ..addAll(badges.map((b) => AchievementBadgeId.values.byName(b)));
      final questBadges = prefs.getStringList(_questBadgesKey) ?? [];
      _questBadges
        ..clear()
        ..addAll(questBadges);
      final recapRaw = prefs.getString(_visitRecapKey);
      if (recapRaw != null) {
        _frozenVisitRecap = VisitRecap.fromJson(
          jsonDecode(recapRaw) as Map<String, dynamic>,
        );
      }
      _reservedTimeSeconds = _computeReservedTime();
      _refreshCompetitiveRankings();
    } catch (_) {}
  }

  Future<void> _persistTimeEconomyProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lifetimeVisitsKey, _lifetimeVisits);
      await prefs.setInt(_lifetimeMinutesKey, _lifetimeMinutesBanked);
      await prefs.setInt(_bankedTimeKey, _bankedTimeSeconds);
      await prefs.setInt(_reputationXpKey, _reputationXp);
      await prefs.setInt('saved_minutes_v1', _savedMinutesAcrossVisits);
      await prefs.setInt('pool_donated_v1', _communityPoolDonatedMinutes);
      await prefs.setStringList(
        _unlockedBadgesKey,
        _unlockedBadges.map((b) => b.name).toList(),
      );
      await prefs.setStringList(_questBadgesKey, _questBadges.toList());
    } catch (_) {}
  }

  int _computeReservedTime() {
    // Venue-controlled reserve — mock based on reputation.
    final base = switch (reputationLevel) {
      ReputationLevel.blindTigerLegend => 45,
      ReputationLevel.whiteTiger => 30,
      ReputationLevel.alpha => 20,
      ReputationLevel.hunter => 10,
      ReputationLevel.cub => 5,
    };
    return base * 60;
  }

  void _initTimeEconomyForVisit() {
    _visitRecap = VisitRecap();
    _visitStartBalance = timeBalance;
    _decayDebtFraction = 0;
    _questsCompletedTonight = 0;
    _nightTimeline = TimeEconomyService.buildNightTimeline();
    _activeBuffs = TimeEconomyService.defaultBuffsFor(_user);
    _reservedTimeSeconds = _computeReservedTime();
    _activeQuests = QuestCatalog.allVisibleQuests()
        .map((q) => q.copyWith())
        .toList();
    if (_user != null) {
      _mysteryQuest = QuestCatalog.mysteryQuestFor(_user!.id);
    }
    _syncReputationQuests();
    _refreshCompetitiveRankings();
    _tickTimeEconomy();
    _economyRefreshTimer?.cancel();
    _economyRefreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _tickTimeEconomy();
      if (_eventWalletDecayActive) {
        unawaited(refreshEventState());
      }
      notifyListeners();
    });
  }

  void _tickTimeEconomy() {
    final now = DateTime.now();
    TimeEconomyService.refreshTimelineStates(_nightTimeline, now);
    _syncReputationQuests();
    _checkTimeQuests();
  }

  void _refreshCompetitiveRankings() {
    _competitiveRankings = QuestCatalog.mockRankings(_user?.name);
  }

  void _syncReputationQuests() {
    for (var i = 0; i < _activeQuests.length; i++) {
      final q = _activeQuests[i];
      if (q.category != QuestCategory.reputation) continue;
      _activeQuests[i] = q.copyWith(currentCount: _reputationXp);
    }
  }

  void _checkTimeQuests() {
    _setQuestProgress('time-1', _visitRecap.timeGiftedMinutes);
    if (_visitRecap.timeReceivedMinutes > 0) {
      _setQuestProgress('time-2', 1);
    }
    _setQuestProgress('time-4', _savedMinutesAcrossVisits);
    _setQuestProgress('time-5', _communityPoolDonatedMinutes);
  }

  void _setQuestProgress(String id, int count) {
    final i = _activeQuests.indexWhere((q) => q.id == id);
    if (i < 0) return;
    final q = _activeQuests[i];
    if (q.claimed) return;
    _activeQuests[i] = q.copyWith(currentCount: count.clamp(0, q.targetCount));
  }

  void progressQuest(String id, {int by = 1}) {
    if (!canSpendTime && !isInsideClub) return;
    final i = _activeQuests.indexWhere((q) => q.id == id);
    if (i >= 0) {
      final q = _activeQuests[i];
      if (q.claimed || q.isComplete) return;
      _activeQuests[i] = q.copyWith(
        currentCount: (q.currentCount + by).clamp(0, q.targetCount),
      );
      notifyListeners();
      return;
    }
    if (_mysteryQuest?.id == id) {
      final m = _mysteryQuest!;
      if (!m.claimed && !m.isComplete) {
        _mysteryQuest = m.copyWith(
          currentCount: (m.currentCount + by).clamp(0, m.targetCount),
        );
        notifyListeners();
      }
    }
  }

  Future<void> claimQuest(String id) async {
    ClubQuest? quest;
    final i = _activeQuests.indexWhere((q) => q.id == id);
    if (i >= 0) {
      quest = _activeQuests[i];
    } else if (_mysteryQuest?.id == id) {
      quest = _mysteryQuest;
    }
    if (quest == null || !quest.isComplete || quest.claimed) return;

    for (final reward in quest.rewards) {
      await _applyQuestReward(reward);
    }

    if (i >= 0) {
      _activeQuests[i] = quest.copyWith(claimed: true);
    } else {
      _mysteryQuest = quest.copyWith(claimed: true);
    }
    _questsCompletedTonight++;
    _visitRecap.questsCompleted = _questsCompletedTonight;
    _addFeedEvent('completed quest "${quest.title}"');
    unawaited(_persistTimeEconomyProgress());
    notifyListeners();
  }

  Future<void> _applyQuestReward(QuestReward reward) async {
    switch (reward.type) {
      case QuestRewardType.liquidMinutes:
        if (_user != null && reward.amount > 0) {
          _user = await _withLocalTimeMutation(
            () => _auth.addTimeBalance(reward.amount * 60),
          );
          _visitRecap.timeReceivedMinutes += reward.amount;
        }
      case QuestRewardType.bankedMinutes:
        _bankedTimeSeconds += reward.amount * 60;
        _lifetimeMinutesBanked += reward.amount;
      case QuestRewardType.xp:
        _addPoints(reward.amount);
      case QuestRewardType.badge:
      case QuestRewardType.rareBadge:
        if (reward.badgeId != null) {
          _questBadges.add(reward.badgeId!);
          _visitRecap.achievementsUnlocked.add(
            AchievementBadgeId.socialButterfly,
          );
        }
    }
  }

  Future<String?> joinNightEvent(String eventId) async {
    if (!isInsideClub) return 'You must be inside the club.';
    final i = _nightTimeline.indexWhere((e) => e.id == eventId);
    if (i < 0) return 'Event not found.';
    final event = _nightTimeline[i];
    if (!event.isActive) return 'This event is not live right now.';
    if (event.isCompleted) return 'Already completed.';

    if (event.type == NightEventType.hiddenRoom && timeBalance < 90 * 60) {
      return 'Need >90 minutes. You have ${timeBalance ~/ 60} min.';
    }

    event.isJoined = true;
    event.isCompleted = true;
    event.participantCount++;

    final rewardMinutes = switch (event.type) {
      NightEventType.timeDrop => 15,
      NightEventType.mysteryPatron => 8,
      NightEventType.theVault => 12,
      NightEventType.timeMarket => 10,
      NightEventType.secretMissions => 5,
      NightEventType.hiddenRoom => 0,
    };
    event.rewardMinutes = rewardMinutes;

    if (rewardMinutes > 0) {
      _user = await _withLocalTimeMutation(
        () => _auth.addTimeBalance(rewardMinutes * 60),
      );
      _visitRecap.timeReceivedMinutes += rewardMinutes;
    }

    _visitRecap.eventsJoined++;
    _unlockBadge(AchievementBadgeId.lifeOfTheParty);
    _addPoints(15);
    _addFeedEvent('joined ${event.title}');
    if (event.type == NightEventType.secretMissions) {
      progressQuest('team-2');
    }
    notifyListeners();
    return rewardMinutes > 0
        ? '+$rewardMinutes minutes earned!'
        : 'Access granted!';
  }

  void _unlockBadge(AchievementBadgeId id) {
    if (_unlockedBadges.contains(id)) return;
    _unlockedBadges.add(id);
    if (!_visitRecap.achievementsUnlocked.contains(id)) {
      _visitRecap.achievementsUnlocked.add(id);
    }
    unawaited(_persistTimeEconomyProgress());
  }

  void _recordPersonMet(String name) {
    if (name.isEmpty) return;
    if (!_visitRecap.peopleMetNames.contains(name)) {
      _visitRecap.peopleMet++;
      _visitRecap.peopleMetNames.add(name);
      progressQuest('ice-1');
      progressQuest('soc-1');
      if (_visitRecap.peopleMet >= 5) {
        _unlockBadge(AchievementBadgeId.socialButterfly);
      }
    }
  }

  void _onQuestSocialAction(String action) {
    switch (action) {
      case 'toast':
        progressQuest('ice-2');
        progressQuest('soc-4');
      case 'meet':
        progressQuest('ice-3');
        progressQuest('soc-2');
      case 'duo':
        progressQuest('team-4');
    }
  }

  Future<void> _finalizeVisitEconomy() async {
    final remaining = timeBalance;
    if (remaining > 0) {
      _bankedTimeSeconds += remaining;
      _savedMinutesAcrossVisits += remaining ~/ 60;
      _lifetimeMinutesBanked += remaining ~/ 60;
    }
    if (remaining >= 60 * 60) {
      _unlockBadge(AchievementBadgeId.timeSaver);
    }
    if (_visitStartBalance > 0) {
      final spent = _visitStartBalance - remaining;
      _visitRecap.minutesSpentTonight = spent ~/ 60;
      if (spent >= 300 * 60) {
        _unlockBadge(AchievementBadgeId.bigSpender);
      }
    }
    if (remaining > 0 && remaining <= 120) {
      _unlockBadge(AchievementBadgeId.lastSecond);
      progressQuest('time-3');
      final tq = _activeQuests.indexWhere((q) => q.id == 'time-3');
      if (tq >= 0 && remaining == 0) {
        _activeQuests[tq] = _activeQuests[tq].copyWith(currentCount: 1);
      }
    }
    if (remaining == 0) {
      final tq = _activeQuests.indexWhere((q) => q.id == 'time-3');
      if (tq >= 0) {
        _activeQuests[tq] = _activeQuests[tq].copyWith(currentCount: 1);
      }
    }
    _lifetimeVisits++;
    _frozenVisitRecap = _visitRecap;
    await _persistVisitRecap();
    await _persistTimeEconomyProgress();
  }

  Future<void> _persistVisitRecap() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_visitRecapKey, jsonEncode(_visitRecap.toJson()));
    } catch (_) {}
  }

  Future<void> transferBankedToLiquid(int minutes) async {
    if (minutes < 1 || !isInsideClub) return;
    final seconds = minutes * 60;
    if (_bankedTimeSeconds < seconds) return;
    _bankedTimeSeconds -= seconds;
    _user = await _withLocalTimeMutation(() => _auth.addTimeBalance(seconds));
    _addFeedEvent('converted $minutes min banked → liquid');
    unawaited(_persistTimeEconomyProgress());
    notifyListeners();
  }

  Future<void> donateToCommunityPool(int minutes) async {
    if (minutes < 1) return;
    final seconds = minutes * 60;
    if (isInsideClub && timeBalance >= seconds) {
      _user = await _auth.deductTimeBalance(seconds);
    } else if (_bankedTimeSeconds >= seconds) {
      _bankedTimeSeconds -= seconds;
    } else {
      return;
    }
    _communityPoolDonatedMinutes += minutes;
    _setQuestProgress('time-5', _communityPoolDonatedMinutes);
    _addFeedEvent('donated $minutes min to the community pool');
    unawaited(_persistTimeEconomyProgress());
    notifyListeners();
  }

  @override
  void dispose() {
    stopStaffTipWatch();
    stopPresencePolling();
    stopSocialInboxPolling();
    stopEventAttendanceWatch();
    _stopCurrencyRealtime();
    _timer?.cancel();
    _qrRefreshTimer?.cancel();
    _syncTimer?.cancel();
    _autoBadgeOutTimer?.cancel();
    _economyRefreshTimer?.cancel();
    unawaited(_liveActivity.end());
    _sessionStore.unsubscribe();
    _sessionStore.removeListener(_onSessionStoreChanged);
    _drinkOrders.removeListener(_onDrinkOrdersChanged);
    unawaited(_clearSocialPresence());
    super.dispose();
  }
}

class PendingWalletCredit {
  const PendingWalletCredit({
    required this.fromSeconds,
    required this.toSeconds,
    this.title,
    this.subtitle,
  });

  final int fromSeconds;
  final int toSeconds;
  final String? title;
  final String? subtitle;
}
