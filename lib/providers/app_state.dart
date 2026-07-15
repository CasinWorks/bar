import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../data/mock_data.dart';
import '../models/blind_tiger_models.dart';
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
import '../models/time_gift.dart';
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
  })  : _auth = authService ?? AuthService(),
        _payment = paymentService ?? PaymentService(),
        _qr = qrService ?? QrService(),
        _sessionStore = sessionStore ?? SessionStore.instance,
        _gifts = timeGiftService ?? TimeGiftService(),
        _leaderboardService = leaderboardService ?? LeaderboardService(),
        _liveActivity = liveActivityService ?? TimeLiveActivityService(),
        _sounds = soundService ?? TigerSoundService.instance,
        _social = socialPlayService ?? SocialPlayService();

  final AuthService _auth;
  final PaymentService _payment;
  final QrService _qr;
  final SessionStore _sessionStore;
  final TimeGiftService _gifts;
  final LeaderboardService _leaderboardService;
  final TimeLiveActivityService _liveActivity;
  final TigerSoundService _sounds;
  final SocialPlayService _social;
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
  void Function(StaffTipReceived)? _staffTipCallback;
  int _staffTipWatchBalance = 0;
  String? _lastHandledTipId;
  DateTime? _lastHandledTipAt;
  QrPayload? _currentQr;
  int _timerSyncDebt = 0;
  int _drinksOrdered = 0;
  int _localTimeMutations = 0;
  PendingWalletCredit? _pendingWalletCredit;
  /// Frozen receipt after exit scan — survives until [beginNewVisit].
  ClubSessionRecord? _checkoutReceipt;
  static const _checkoutReceiptKey = 'checkout_receipt_v1';
  int? _lastLiveActivitySeconds;
  bool _timerLowSoundPlayed = false;

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

  bool get isLoading => _isLoading;
  bool get usesCloud => _auth.usesSupabase;
  MemberUser? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get isStaff => _user?.isStaff ?? false;
  bool get isMember => _user?.isMember ?? false;
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

  int get currentRank {
    for (final user in _leaderboard) {
      if (user.isCurrentUser) return user.rank;
    }
    return _leaderboard.length;
  }

  MemberTier get memberTier => MemberTierThresholds.tierForSeconds(spendableTimeSeconds);

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
      isMember &&
      sessionPhase == SessionPhase.none &&
      timeBalance > 0;

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    await _sessionStore.load();
    await _sounds.ensureLoaded();
    await _liveActivity.init();
    _user = await _auth.getCurrentUser();
    _sessionStore.addListener(_onSessionStoreChanged);

    if (_user != null && _user!.isMember) {
      await _loadPersistedCheckoutReceipt();
      if (_checkoutReceipt == null) {
        await _restoreActiveSession();
      }
      _syncLiveActivity();
    }

    _startCurrencyRealtime();

    _isLoading = false;
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
    } else if (_session!.phase == SessionPhase.awaitingExitScan) {
      if (timeBalance > 0) {
        _startTimer();
      }
      _startQrRefresh(QrPurpose.exit);
    } else if (_session!.phase == SessionPhase.paidAwaitingEntry) {
      _startQrRefresh(QrPurpose.entry);
      _startSyncPolling();
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
      _syncTimer?.cancel();
      unawaited(_sounds.playDoorLatch());
      _onEnteredClub();
    }

    if (previousPhase == SessionPhase.awaitingExitScan &&
        updated.phase == SessionPhase.insideClub) {
      _startTimer();
      _startQrRefresh(QrPurpose.exit);
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
      drinksOrdered: session.drinksOrdered > 0 ? session.drinksOrdered : _drinksOrdered,
      enteredAt: session.enteredAt != null
          ? ClubSessionRecord.correctToLocal(session.enteredAt!)
          : null,
      // Stamp exit from the device clock — don't trust a skewed DB timestamptz alone.
      exitedAt: DateTime.now(),
    );
    _session = _checkoutReceipt;
    _currentQr = null;
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
            _checkoutReceipt!.enteredAt =
                ClubSessionRecord.correctToLocal(fresh!.enteredAt!);
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
    notifyListeners();
  }

  Future<MemberUser> signUp({
    required String name,
    required String email,
    required String password,
    required DateTime birthdate,
  }) async {
    _user = await _auth.signUp(
      name: name,
      email: email,
      password: password,
      birthdate: birthdate,
    );
    notifyListeners();
    return _user!;
  }

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

    _startCurrencyRealtime();

    notifyListeners();
    return _user!;
  }

  void _startCurrencyRealtime() {
    if (!usesCloud || _user == null) return;

    _auth.startProfileCurrencyWatch((user) {
      unawaited(_onRemoteProfileCurrency(user));
    });
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
    await _flushWalletTimerSync();
    _timer?.cancel();
    _qrRefreshTimer?.cancel();
    _syncTimer?.cancel();
    _sessionStore.unsubscribe();
    await _clearSocialPresence();
    await _auth.logout();
    _user = null;
    _session = null;
    await _clearPersistedCheckoutReceipt();
    _currentQr = null;
    _drinksOrdered = 0;
    _loungeInitialized = false;
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
    notifyListeners();
  }

  void completeMiniGame(MiniGame game, int points) {
    if (!canSpendTime) return;
    _addPoints(points);
    if (game.id == 'game-1' || game.id == 'game-3') {
      _progressChallenge('chal-3', by: 1);
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

    final updated = _leaderboard
        .map((u) {
          final seconds = u.isCurrentUser ? spendableTimeSeconds : (u.timeBalance ?? 0);
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
        })
        .toList()
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
    _timerLowSoundPlayed = false;
    unawaited(_liveActivity.end());
    notifyListeners();
  }

  Future<void> cancelPendingPass() async {
    if (_session == null || _session!.phase != SessionPhase.paidAwaitingEntry) return;

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
      final existing = await _sessionStore.fetchActiveSessionForMember(_user!.id);
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
    );
    await _sessionStore.upsert(_session!);
    await _sessionStore.subscribeToSession(sessionId);
    _startQrRefresh(QrPurpose.entry);
    _startSyncPolling();
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

    notifyListeners();
    return result;
  }

  Future<PaymentResult> purchaseAndLoadTime(int minutes) => purchaseTime(minutes);

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
    if (_session == null || _session!.phase != SessionPhase.awaitingExitScan) return;

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
    _timerSyncDebt = 0;
    try {
      _user = await _auth.setTimeBalance(timeBalance);
    } catch (_) {
      // Best effort — realtime profile watch will reconcile.
    }
  }

  void _startTimer() {
    _timer?.cancel();
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

      if (_timerSyncDebt >= 5) {
        await _flushWalletTimerSync();
      } else if (!usesCloud) {
        await _auth.setTimeBalance(timeBalance);
      }

      notifyListeners();
    });
  }

  void _maybeWarnTimerLow() {
    final phase = _session?.phase;
    if (phase != SessionPhase.insideClub &&
        phase != SessionPhase.awaitingExitScan) {
      return;
    }
    if (timeBalance > 0 && timeBalance <= 10 * 60) {
      if (!_timerLowSoundPlayed) {
        _timerLowSoundPlayed = true;
        unawaited(_sounds.playTimerLow());
        _syncLiveActivity(force: true);
      }
    } else if (timeBalance > 10 * 60) {
      _timerLowSoundPlayed = false;
    }
  }

  /// Push time-as-currency into Dynamic Island / Lock Screen / Apple Watch.
  void _syncLiveActivity({bool force = false}) {
    final phase = sessionPhase;
    final inside = phase == SessionPhase.insideClub ||
        phase == SessionPhase.awaitingExitScan;
    if (!inside || _checkoutReceipt != null) {
      unawaited(_liveActivity.end());
      _lastLiveActivitySeconds = null;
      return;
    }

    final seconds = timeBalance;
    final useLiveCountdown =
        seconds > 0 && seconds <= TimeLiveActivityService.liveCountdownMaxSeconds;
    if (!force && _lastLiveActivitySeconds != null) {
      final delta = (seconds - _lastLiveActivitySeconds!).abs();
      // Native countdown needs rare updates; big wallet labels refresh ~each minute.
      if (useLiveCountdown && delta < 4) return;
      if (!useLiveCountdown && delta < 60) return;
    }
    _lastLiveActivitySeconds = seconds;

    final status = phase == SessionPhase.awaitingExitScan
        ? 'AWAITING EXIT'
        : (seconds <= 10 * 60 ? 'TIME RUNNING LOW' : 'INSIDE THE CLUB');

    unawaited(
      _liveActivity.syncVisit(
        insideOrExiting: true,
        memberName: _user?.name ?? _session?.memberName ?? 'Guest',
        branch: _session?.branch ?? _selectedBranch,
        status: status,
        remainingSeconds: seconds,
      ),
    );
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

  Future<bool> orderDrink(Drink drink) async {
    if (!canSpendTime) return false;
    if (timeBalance < drink.timeCostSeconds) {
      unawaited(_sounds.playSoftThud());
      return false;
    }

    _timer?.cancel();
    try {
      _user = await _auth.deductTimeBalance(drink.timeCostSeconds);
    } catch (_) {
      unawaited(_sounds.playSoftThud());
      return false;
    }

    _drinksOrdered++;
    if (_session != null) {
      _session!.drinksOrdered = _drinksOrdered;
      await _sessionStore.upsert(_session!);
    }
    unawaited(_sounds.playGlassClink());
    _syncLiveActivity(force: true);
    if (_session?.phase == SessionPhase.insideClub && timeBalance > 0) {
      _startTimer();
    }
    _progressChallenge('chal-2', by: 1);
    _addPoints(10);
    _addFeedEvent("just ordered a ${drink.name} at the Main Bar!");
    notifyListeners();
    return true;
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

    try {
      final gift = await _gifts.raiseToast(seconds: seconds, message: message);
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
      _syncLiveActivity(force: true);
      notifyListeners();
      return (gift, null);
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

    try {
      final gift = await _gifts.tipHouse(seconds: seconds, message: message);
      if (usesCloud) {
        _user = await _auth.refreshProfile() ?? _user;
      } else {
        _user = await _auth.deductTimeBalance(seconds);
      }
      _addFeedEvent('tipped the house ${_formatMinutes(seconds)} — class act');
      _addPoints(8);
      _progressChallenge('chal-6', by: 1);
      unawaited(_sounds.playGlassClink());
      _syncLiveActivity(force: true);
      notifyListeners();
      return (gift, null);
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

    try {
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
      _syncLiveActivity(force: true);
      notifyListeners();
      return (gift, null);
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
        tip.tipSeconds == (_staffTipWatchBalance < tip.toBalance
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
      _whosInside = await _social.listWhosInside(
        branch: branch,
        selfId: _user?.id,
      );
      notifyListeners();
    } catch (_) {}
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
    final seconds = minutes * 60;
    if (timeBalance < seconds) {
      return (null, 'Not enough time. Need ${_formatMinutes(seconds)}.');
    }

    try {
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
      final label = kind == MeetKind.duoBeat ? 'duo Beat Sync' : 'Toast to Meet';
      _addFeedEvent(
        'raised a $label${meet.code != null ? ' — code ${meet.code}' : ''}',
      );
      _addPoints(6);
      unawaited(_sounds.playGlassClink());
      _syncLiveActivity(force: true);
      notifyListeners();
      return (meet, null);
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
        if (meet.status == MeetStatus.completed && meet.kind == MeetKind.duoBeat) {
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
    final draw = meet.winnerId == null &&
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
    _stopCurrencyRealtime();
    _timer?.cancel();
    _qrRefreshTimer?.cancel();
    _syncTimer?.cancel();
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
