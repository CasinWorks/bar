import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../core/config/door_qr_bypass.dart' as door_qr;
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
import '../models/time_gift.dart';
import '../models/time_low_alert.dart';
import '../models/social_play.dart';

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
       _push = pushNotificationService ?? PushNotificationService();

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
  final _uuid = const Uuid();

  bool _isLoading = true;
  MemberUser? _user;
  ClubSessionRecord? _session;
  PriceTier _selectedTier = MockData.priceTiers[1];
  int _selectedTimeMinutes = MockData.timePackages[1].minutes;
  String _selectedTimePackageId = MockData.timePackages[1].id;
  PaymentMethod _paymentMethod = PaymentMethod.gcash;
  String _selectedBranch = MockData.clubBranches.first.name;

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
  bool _timeLowThresholdsSeeded = false;
  String? _lastAnnouncedBand;

  AvatarConfig _avatar = const AvatarConfig();
  int _points = 108;
  LoungeTab _activeTab = LoungeTab.challenges;
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

  static const _tutorialSeenPrefix = 'member_tutorial_seen_v1_';

  bool get isLoading => _isLoading;
  bool get usesCloud => _auth.usesSupabase;
  MemberUser? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get isStaff => _user?.isStaff ?? false;
  bool get isMember => _user?.isMember ?? false;
  /// Entry door QR may be skipped for allowlisted emails / VIP whitelist.
  bool get canSkipDoorQr => door_qr.canSkipDoorQrScan(
        email: _user?.email,
        isWhitelisted: _user?.isWhitelisted ?? false,
      );
  bool get needsMemberTutorial =>
      _needsMemberTutorial && isMember && !isStaff;
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
  String get selectedBranch => _selectedBranch;
  QrPayload? get currentQr => _currentQr;
  int get timeRemaining => timeBalance;

  int get drinksOrdered => _drinksOrdered;
  PendingWalletCredit? get pendingWalletCredit => _pendingWalletCredit;
  Duration get remaining => Duration(seconds: timeRemaining);
  AvatarConfig get avatar => _avatar;
  int get points => _points;
  LoungeTab get activeTab => _activeTab;
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
  int get pendingInboundRequestCount => _friendRequests
      .where(
        (r) =>
            r.direction == 'inbound' && r.status == FriendRequestStatus.pending,
      )
      .length;
  SafetyReport? get lastSafetyReport => _lastSafetyReport;
  RideAssistRequest? get lastRideAssistRequest => _lastRideAssistRequest;
  InsuranceIncident? get lastInsuranceIncident => _lastInsuranceIncident;

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
      _session?.phase == SessionPhase.insideClub && timeBalance <= 0;

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

    await _sessionStore.load();
    await _sounds.ensureLoaded();
    await _liveActivity.init();
    await _initPushDelivery();
    _user = await _auth.getCurrentUser();
    _sessionStore.addListener(_onSessionStoreChanged);

    if (_user != null && _user!.isMember) {
      await _loadPersistedCheckoutReceipt();
      if (_checkoutReceipt == null) {
        await _restoreActiveSession();
      }
      _syncLiveActivity();
      await _refreshTutorialFlag();
      startSocialInboxPolling();
      unawaited(_registerPushTokens());
    }

    _startCurrencyRealtime();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _initPushDelivery() async {
    _liveActivity.onPushToken = (token, {required kind}) {
      unawaited(_safety.registerPushToken(
        token: token,
        kind: kind,
        platform: _pushPlatform,
        environment: kDebugMode ? 'sandbox' : 'production',
        bundleId: 'com.intime.inTimeBartender',
      ));
    };
    _push.onDeviceToken = (token) {
      unawaited(_safety.registerPushToken(
        token: token,
        kind: 'fcm',
        platform: _pushPlatform,
        environment: kDebugMode ? 'sandbox' : 'production',
        bundleId: 'com.intime.inTimeBartender',
      ));
    };
    _push.onApnsToken = (token) {
      unawaited(_safety.registerPushToken(
        token: token,
        kind: 'apns',
        platform: 'ios',
        environment: kDebugMode ? 'sandbox' : 'production',
        bundleId: 'com.intime.inTimeBartender',
      ));
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
    await _sessionStore.subscribeToSession(fresh.id);

    if (_session!.phase == SessionPhase.insideClub) {
      _initLoungeState();
      if (timeBalance > 0) {
        _startTimer();
      }
      _startQrRefresh(QrPurpose.exit);
      _scheduleAutoBadgeOut(_session);
      startSocialInboxPolling();
      _syncLiveActivity(force: true);
    } else if (_session!.phase == SessionPhase.awaitingExitScan) {
      if (timeBalance > 0) {
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
    _resetTimeLowWarnings();
    _lastAnnouncedBand = null;
    unawaited(_clearSocialPresence());
    unawaited(_persistCheckoutReceipt());
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
    if (_session?.phase == SessionPhase.insideClub && timeBalance > 0) {
      _startTimer();
    }
    _scheduleAutoBadgeOut(_session);
    startSocialInboxPolling();
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
    _startCurrencyRealtime();
    startSocialInboxPolling();
    unawaited(_registerPushTokens());

    notifyListeners();
    return _user!;
  }

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

  void _stopCurrencyRealtime() {
    _auth.stopProfileCurrencyWatch();
  }

  Future<void> logout() async {
    _stopCurrencyRealtime();
    stopSocialInboxPolling();
    _clearSocialAlertQueues();
    await _flushWalletTimerSync();
    _timer?.cancel();
    _qrRefreshTimer?.cancel();
    _syncTimer?.cancel();
    _sessionStore.unsubscribe();
    await _clearSocialPresence();
    await _safety.clearPushTokens();
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
    unawaited(_liveActivity.end());
    notifyListeners();
  }

  void _initLoungeState() {
    if (_loungeInitialized) return;
    _loungeInitialized = true;
    _avatar = AvatarConfig(name: _user?.name ?? 'Socialite');
    _challenges = MockData.initialChallenges();
    _feedEvents = MockData.initialFeedEvents();
    _leaderboard = [];
    _progressChallenge('chal-1', by: 1); // entered club
    unawaited(refreshLeaderboard());
  }

  void setActiveTab(LoungeTab tab) {
    _activeTab = tab;
    if (tab == LoungeTab.leaderboard) {
      unawaited(refreshLeaderboard());
    }
    notifyListeners();
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
    _addFeedEvent(
      'earned +$minutes min${source != null ? ' · $source' : ''}',
    );
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
    _qrRefreshTimer?.cancel();
    _syncTimer?.cancel();
    _sessionStore.unsubscribe();
    _session = null;
    unawaited(_clearPersistedCheckoutReceipt());
    unawaited(_clearSocialPresence());
    _currentQr = null;
    _drinksOrdered = 0;
    _loungeInitialized = false;
    _resetTimeLowWarnings();
    _lastAnnouncedBand = null;
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
    _selectedBranch = branch;
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

    final existing = await _sessionStore.fetchActiveSessionForMember(_user!.id);
    if (existing != null) {
      await _applyRestoredSession(existing);
      notifyListeners();
      return true;
    }

    final sessionId = _uuid.v4();
    _session = ClubSessionRecord(
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
    await _sessionStore.upsert(_session!);
    await _sessionStore.subscribeToSession(sessionId);
    _startQrRefresh(QrPurpose.entry);
    _startSyncPolling();
    await _maybeSkipEntryDoorScan();
    notifyListeners();
    return true;
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
    if (_session?.phase == SessionPhase.insideClub && timeBalance > 0) {
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
    if (timeBalance > 0) {
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

  Future<String?> staffConfirmScan(QrPayload payload) async {
    var session = await _sessionStore.fetchSession(payload.sessionId);
    if (session == null) return 'Session not found.';

    if (payload.purpose == QrPurpose.entry) {
      if (session.phase != SessionPhase.paidAwaitingEntry) {
        return 'Not awaiting entry scan.';
      }
      await _sessionStore.confirmEntry(session.id);
      return null;
    }

    if (payload.purpose == QrPurpose.exit) {
      if (session.phase == SessionPhase.insideClub) {
        await _sessionStore.requestExit(session.id);
        session = await _sessionStore.fetchSession(session.id) ?? session;
      }
      if (session.phase != SessionPhase.awaitingExitScan) {
        return 'Guest is not ready to exit yet.';
      }
      await _sessionStore.confirmExit(session.id);
      return null;
    }

    return 'Invalid QR purpose.';
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

  /// Serialize wallet spends: pause meter → flush debt → mutate → resume.
  Future<T?> _runExclusiveWallet<T>(
    Future<T> Function() action, {
    T? onBusy,
  }) async {
    if (_walletBusy) return onBusy;
    _walletBusy = true;
    final shouldResume = _session?.phase == SessionPhase.insideClub ||
        _session?.phase == SessionPhase.awaitingExitScan;
    _timer?.cancel();
    try {
      await _flushWalletTimerSync();
      return await _withLocalTimeMutation(action);
    } finally {
      _walletBusy = false;
      if (shouldResume && timeBalance > 0) {
        _startTimer();
      }
      _maybeWarnTimerLow();
      _syncLiveActivity(force: true);
      notifyListeners();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    // Seed once per visit so restore/resume doesn't dump every mark already below.
    if (!_timeLowThresholdsSeeded) {
      _seedTimeLowThresholdsAlreadyPast();
      _timeLowThresholdsSeeded = true;
    }
    _syncLiveActivity(force: true);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (_session == null) return;
      final phase = _session!.phase;
      // Meter runs until door staff completes the exit scan — not when QR is shown.
      if (phase != SessionPhase.insideClub &&
          phase != SessionPhase.awaitingExitScan) {
        return;
      }

      if (timeBalance <= 0) {
        await _flushWalletTimerSync();
        _timer?.cancel();
        _syncLiveActivity(force: true);
        notifyListeners();
        return;
      }

      _user = _user!.copyWith(timeBalanceSeconds: timeBalance - 1);
      _timerSyncDebt++;
      _maybeWarnTimerLow();
      // Throttled: live timerInterval needs rare re-anchors; static mega-wallet
      // labels refresh about once a minute while foregrounded.
      _syncLiveActivity();

      if (_timerSyncDebt >= 5) {
        await _flushWalletTimerSync();
      } else if (!usesCloud) {
        await _auth.setTimeBalance(timeBalance);
      }

      notifyListeners();
    });
  }

  void _maybeWarnTimerLow() {
    _maybeAnnounceTimerBand();
    final phase = _session?.phase;
    if (phase != SessionPhase.insideClub &&
        phase != SessionPhase.awaitingExitScan) {
      return;
    }

    final seconds = timeBalance;
    if (seconds <= 0) return;

    // Climbing back above a mark (buy / gift) re-arms that threshold.
    for (final minutes in TimeLowAlert.thresholds) {
      if (seconds > minutes * 60) {
        _firedTimeLowThresholds.remove(minutes);
        _pushedAlertIds.remove('time-low-$minutes');
        _timeLowAlertQueue
            .removeWhere((a) => a.minutesThreshold == minutes);
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
    if (_timeLowAlertQueue
        .any((a) => a.minutesThreshold == alert.minutesThreshold)) {
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
    final time = pendingTimeLowAlert;
    if (time != null) {
      _surfaceTimeLowHead(time);
    }
  }

  /// Push time-as-currency into Dynamic Island / Lock Screen / Apple Watch.
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
    final status = _liveSocialTitle ?? baseStatus;

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
      unawaited(
        _push.showSocialAlert(id: id, title: title, body: body),
      );
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

  String formatDuration(int totalSeconds) {
    if (totalSeconds <= 0) return '0:00';
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
    return '${m}m ${s.toString().padLeft(2, '0')}s';
  }

  Future<bool> orderDrink(Drink drink, {bool payWithCash = false}) async {
    if (!isInsideClub) return false;
    if (_walletBusy) return false;

    final result = await _runExclusiveWallet<bool>(() async {
      if (drink.isStandard) {
        if (drinksAllowanceRemaining < 1) {
          unawaited(_sounds.playSoftThud());
          return false;
        }
        try {
          if (usesCloud) {
            _user = await _auth.consumeIncludedDrink(sessionId: _session?.id);
            if (_session != null) {
              _session!.includedDrinksRemaining =
                  _user?.includedDrinksRemaining ?? 0;
            }
          } else {
            final next = (drinksAllowanceRemaining - 1).clamp(0, 1 << 31);
            if (_session != null) {
              _session!.includedDrinksRemaining = next;
            }
            if (_user != null) {
              _user = _user!.copyWith(includedDrinksRemaining: next);
              await _auth.persistLocalUser(_user!);
            }
          }
        } catch (_) {
          unawaited(_sounds.playSoftThud());
          return false;
        }
      } else if (payWithCash) {
        // Premium paid at bar — track order only, no minute burn.
      } else {
        if (timeBalance < drink.timeCostSeconds) {
          unawaited(_sounds.playSoftThud());
          return false;
        }
        try {
          _user = await _auth.deductTimeBalance(drink.timeCostSeconds);
        } catch (_) {
          unawaited(_sounds.playSoftThud());
          return false;
        }
      }

      _drinksOrdered++;
      if (_session != null) {
        _session!.drinksOrdered = _drinksOrdered;
        await _sessionStore.upsert(_session!);
      }
      unawaited(_sounds.playGlassClink());
      _progressChallenge('chal-2', by: 1);
      _addPoints(10);
      _addFeedEvent("just ordered a ${drink.name} at the Main Bar!");
      return true;
    }, onBusy: false);

    return result ?? false;
  }

  int get drinksAllowanceRemaining {
    if (_session != null) return _session!.includedDrinksRemaining;
    return _user?.includedDrinksRemaining ?? 0;
  }

  /// Spend minutes on a venue experience (VIP Lounge, VVIP Room, etc.).
  Future<bool> redeemVenueActivity(VenueActivity activity) async {
    if (!canSpendTime || _session == null) return false;
    if (_walletBusy) return false;

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

  TimerBand get currentTimerBand =>
      AppColors.timerBand(timeBalance ~/ 60);

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
        final gift =
            await _gifts.raiseToast(seconds: seconds, message: message);
        if (usesCloud) {
          _user = await _auth.refreshProfile() ?? _user;
        } else {
          _user = await _auth.deductTimeBalance(seconds);
        }
        _addFeedEvent(
          'raised a ${minutes}m toast${gift.code != null ? ' — find me for ${gift.code}' : ''}',
        );
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
        final gift =
            await _gifts.tipHouse(seconds: seconds, message: message);
        if (usesCloud) {
          _user = await _auth.refreshProfile() ?? _user;
        } else {
          _user = await _auth.deductTimeBalance(seconds);
        }
        _addFeedEvent('tipped the house ${_formatMinutes(seconds)} — class act');
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
      final outcome = await _runExclusiveWallet<(SocialMeet?, String?)>(() async {
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
      }, onBusy: (null, 'Hang on — another spend is still processing.'));
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
      }
      final other = meet.hostName;
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

  @override
  void dispose() {
    stopStaffTipWatch();
    stopPresencePolling();
    stopSocialInboxPolling();
    _stopCurrencyRealtime();
    _timer?.cancel();
    _qrRefreshTimer?.cancel();
    _syncTimer?.cancel();
    _autoBadgeOutTimer?.cancel();
    unawaited(_liveActivity.end());
    _sessionStore.unsubscribe();
    _sessionStore.removeListener(_onSessionStoreChanged);
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
