import 'dart:async';
import 'package:flutter/foundation.dart';
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
import '../models/time_gift.dart';

class AppState extends ChangeNotifier {
  AppState({
    AuthService? authService,
    PaymentService? paymentService,
    QrService? qrService,
    SessionStore? sessionStore,
    TimeGiftService? timeGiftService,
    LeaderboardService? leaderboardService,
  })  : _auth = authService ?? AuthService(),
        _payment = paymentService ?? PaymentService(),
        _qr = qrService ?? QrService(),
        _sessionStore = sessionStore ?? SessionStore.instance,
        _gifts = timeGiftService ?? TimeGiftService(),
        _leaderboardService = leaderboardService ?? LeaderboardService();

  final AuthService _auth;
  final PaymentService _payment;
  final QrService _qr;
  final SessionStore _sessionStore;
  final TimeGiftService _gifts;
  final LeaderboardService _leaderboardService;
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

  AvatarConfig _avatar = const AvatarConfig();
  int _points = 108;
  LoungeTab _activeTab = LoungeTab.challenges;
  List<Challenge> _challenges = [];
  List<FeedEvent> _feedEvents = [];
  List<LeaderboardUser> _leaderboard = [];
  bool _loungeInitialized = false;

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
    _user = await _auth.getCurrentUser();
    _sessionStore.addListener(_onSessionStoreChanged);

    if (_user != null && _user!.isMember) {
      await _restoreActiveSession();
    }

    _startCurrencyRealtime();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _restoreActiveSession() async {
    if (_user == null || !_user!.isMember) return;

    _user = await _auth.refreshProfile() ?? _user;

    final s = await _sessionStore.fetchActiveSessionForMember(_user!.id);
    if (s == null) {
      _session = null;
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
      _startQrRefresh(QrPurpose.exit);
    } else if (_session!.phase == SessionPhase.paidAwaitingEntry) {
      _startQrRefresh(QrPurpose.entry);
      _startSyncPolling();
    }
  }

  void _onSessionStoreChanged() {
    if (_session == null) return;
    final updated = _sessionStore.getSession(_session!.id);
    if (updated == null) return;

    final previousPhase = _session!.phase;

    _session = updated;
    _drinksOrdered = updated.drinksOrdered;

    if (previousPhase == SessionPhase.paidAwaitingEntry &&
        updated.phase == SessionPhase.insideClub) {
      _timer?.cancel();
      _initLoungeState();
      _startQrRefresh(QrPurpose.exit);
      _syncTimer?.cancel();
      _onEnteredClub();
    }

    if (previousPhase == SessionPhase.awaitingExitScan &&
        updated.phase == SessionPhase.completed) {
      _timer?.cancel();
      _qrRefreshTimer?.cancel();
      _syncTimer?.cancel();
      // Capture receipt immediately (sync) so routing never loses the summary.
      _captureCheckoutReceipt(updated);
      notifyListeners();
      unawaited(_finalizeCheckoutReceipt(updated));
      return;
    }

    if (previousPhase == SessionPhase.awaitingExitScan &&
        updated.phase == SessionPhase.insideClub) {
      _startTimer();
      _startQrRefresh(QrPurpose.exit);
    }

    notifyListeners();
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
      enteredAt: session.enteredAt,
      exitedAt: session.exitedAt ?? DateTime.now(),
    );
    _session = _checkoutReceipt;
    _currentQr = null;
  }

  Future<void> _finalizeCheckoutReceipt(ClubSessionRecord session) async {
    _localTimeMutations++;
    try {
      await _bankTimeForCompletedVisit(SessionPhase.awaitingExitScan, session);
      _pendingWalletCredit = null;
      if (_checkoutReceipt != null) {
        _checkoutReceipt!.remainingSeconds = timeBalance;
        _session = _checkoutReceipt;
      }
    } catch (_) {
      // Receipt already captured — never drop the summary on bank/sync errors.
    } finally {
      _localTimeMutations = mathMax(0, _localTimeMutations - 1);
    }

    try {
      await _sessionStore.subscribeToSession(null);
    } catch (_) {}
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
    }

    _user = user;

    if (delta > 3) {
      _resumeTimerIfNeeded();
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
    await _auth.logout();
    _user = null;
    _session = null;
    _checkoutReceipt = null;
    _currentQr = null;
    _drinksOrdered = 0;
    _loungeInitialized = false;
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
    _progressChallenge('chal-4', by: 1);
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
    _checkoutReceipt = null;
    _currentQr = null;
    _drinksOrdered = 0;
    _loungeInitialized = false;
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

    _timer?.cancel();
    await _sessionStore.requestExit(_session!.id);
    final updated = await _sessionStore.fetchSession(_session!.id);
    if (updated != null) _session = updated;
    _startQrRefresh(QrPurpose.exit);
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
    _timer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (_session == null || _session!.phase != SessionPhase.insideClub) return;

      if (timeBalance <= 0) {
        await _flushWalletTimerSync();
        _timer?.cancel();
        notifyListeners();
        return;
      }

      _user = _user!.copyWith(timeBalanceSeconds: timeBalance - 1);
      _timerSyncDebt++;

      if (_timerSyncDebt >= 5) {
        await _flushWalletTimerSync();
      } else if (!usesCloud) {
        await _auth.setTimeBalance(timeBalance);
      }

      notifyListeners();
    });
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
    if (timeBalance < drink.timeCostSeconds) return false;

    _timer?.cancel();
    try {
      _user = await _auth.deductTimeBalance(drink.timeCostSeconds);
    } catch (_) {
      return false;
    }

    _drinksOrdered++;
    if (_session != null) {
      _session!.drinksOrdered = _drinksOrdered;
      await _sessionStore.upsert(_session!);
    }
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

  @override
  void dispose() {
    stopStaffTipWatch();
    _stopCurrencyRealtime();
    _timer?.cancel();
    _qrRefreshTimer?.cancel();
    _syncTimer?.cancel();
    _sessionStore.unsubscribe();
    _sessionStore.removeListener(_onSessionStoreChanged);
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
