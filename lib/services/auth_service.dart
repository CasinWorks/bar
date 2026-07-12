import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;
import '../core/config/super_admin.dart';
import '../core/config/supabase_config.dart';
import '../models/member_user.dart';

class StaffTipEvent {
  const StaffTipEvent({
    required this.transferId,
    required this.seconds,
    required this.fromMemberName,
  });

  final String transferId;
  final int seconds;
  final String fromMemberName;
}

class AuthService {
  static const _userKey = 'member_user';
  static const _authKey = 'auth_accounts';

  RealtimeChannel? _staffTipChannel;
  RealtimeChannel? _profileCurrencyChannel;
  void Function(StaffTipEvent event)? _onStaffTip;
  void Function(MemberUser user)? _onProfileCurrency;

  bool get usesSupabase => SupabaseConfig.isConfigured;

  SupabaseClient? get _client =>
      usesSupabase ? Supabase.instance.client : null;

  Future<MemberUser?> getCurrentUser() async {
    if (usesSupabase) {
      final session = _client!.auth.currentSession;
      if (session == null) return null;
      final user = session.user;
      try {
        return await _fetchProfile(user.id);
      } on AuthException {
        await logout();
        return null;
      } catch (_) {
        return _ensureProfile(user);
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_userKey);
    if (raw == null) return null;
    return MemberUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<MemberUser> signUp({
    required String name,
    required String email,
    required String password,
    required DateTime birthdate,
  }) async {
    final user = MemberUser(
      id: 'pending',
      name: name.trim(),
      email: email.trim().toLowerCase(),
      birthdate: birthdate,
      role: UserRole.member,
    );

    if (!user.isOfAge) {
      throw AuthException('You must be 21 or older to enter The Blind Tiger.');
    }

    if (usesSupabase) {
      final response = await _client!.auth.signUp(
        email: user.email,
        password: password,
        data: {
          'name': user.name,
          'birthdate': birthdate.toIso8601String().split('T').first,
          'role': UserRole.member.name,
        },
      );

      final authUser = response.user;
      if (authUser == null) {
        throw AuthException('Sign up failed. Please try again.');
      }

      if (response.session == null) {
        throw AuthException('Check your email to confirm your account, then sign in.');
      }

      return _ensureProfile(authUser);
    }

    return _localSignUp(user: user, password: password);
  }

  Future<MemberUser> login({
    required String email,
    required String password,
  }) async {
    final normalized = email.trim().toLowerCase();

    if (usesSupabase) {
      AuthResponse response;
      try {
        response = await _client!.auth.signInWithPassword(
          email: normalized,
          password: password,
        );
      } catch (_) {
        throw AuthException('Invalid email or password.');
      }

      final authUser = response.user;
      if (authUser == null) {
        throw AuthException('Invalid email or password.');
      }

      return _ensureProfile(authUser);
    }

    return _localLogin(email: normalized, password: password);
  }

  Future<void> logout() async {
    stopStaffTipWatch();
    stopProfileCurrencyWatch();
    if (usesSupabase) {
      await _client!.auth.signOut();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
  }

  /// Live wallet balance from Supabase profiles (time_balance_seconds).
  void startProfileCurrencyWatch(void Function(MemberUser user) onUpdate) {
    stopProfileCurrencyWatch();
    if (!usesSupabase) return;

    final userId = _client!.auth.currentUser?.id;
    if (userId == null) return;

    _onProfileCurrency = onUpdate;
    _profileCurrencyChannel = _client!
        .channel('profile-currency:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'profiles',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: userId,
          ),
          callback: (_) async {
            final fresh = await refreshProfile();
            if (fresh != null) _onProfileCurrency?.call(fresh);
          },
        )
        .subscribe();
  }

  void stopProfileCurrencyWatch() {
    _profileCurrencyChannel?.unsubscribe();
    _profileCurrencyChannel = null;
    _onProfileCurrency = null;
  }

  /// Live tip detection for bartender tip pad (realtime transfer insert).
  void startStaffTipWatch({
    required String staffId,
    required void Function(StaffTipEvent event) onTip,
  }) {
    stopStaffTipWatch();
    _onStaffTip = onTip;

    if (!usesSupabase) return;

    _staffTipChannel = _client!
        .channel('staff-tips:$staffId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'time_transfers',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'to_member_id',
            value: staffId,
          ),
          callback: (payload) {
            final record = payload.newRecord;
            if (record['kind'] != 'tip_staff') return;
            final id = record['id'] as String?;
            final seconds = record['seconds'] as int?;
            if (id == null || seconds == null || seconds <= 0) return;
            _onStaffTip?.call(
              StaffTipEvent(
                transferId: id,
                seconds: seconds,
                fromMemberName: record['from_member_name'] as String? ?? 'Guest',
              ),
            );
          },
        )
        .subscribe();
  }

  void stopStaffTipWatch() {
    _staffTipChannel?.unsubscribe();
    _staffTipChannel = null;
    _onStaffTip = null;
  }

  Future<MemberUser?> refreshProfile() async {
    if (usesSupabase) {
      final session = _client!.auth.currentSession;
      if (session == null) return null;
      return _fetchProfile(session.user.id);
    }

    return getCurrentUser();
  }

  Future<MemberUser> addTimeBalance(int seconds) async {
    if (seconds <= 0) return (await getCurrentUser())!;

    if (usesSupabase) {
      final user = await getCurrentUser();
      if (user == null) throw AuthException('Not signed in.');
      final next = user.timeBalanceSeconds + seconds;
      await _client!
          .from('profiles')
          .update({'time_balance_seconds': next})
          .eq('id', user.id);
      return _fetchProfile(user.id);
    }

    return _updateLocalUserBalance(seconds);
  }

  Future<MemberUser> deductTimeBalance(int seconds) async {
    if (seconds <= 0) return (await getCurrentUser())!;

    if (usesSupabase) {
      final user = await getCurrentUser();
      if (user == null) throw AuthException('Not signed in.');
      if (user.timeBalanceSeconds < seconds) {
        throw AuthException('Not enough time balance.');
      }
      final next = user.timeBalanceSeconds - seconds;
      await _client!
          .from('profiles')
          .update({'time_balance_seconds': next})
          .eq('id', user.id);
      return _fetchProfile(user.id);
    }

    return _updateLocalUserBalance(-seconds);
  }

  /// Set wallet balance directly (used by lounge timer sync).
  Future<MemberUser> setTimeBalance(int seconds) async {
    final clamped = seconds.clamp(0, 1 << 31);

    if (usesSupabase) {
      final user = await getCurrentUser();
      if (user == null) throw AuthException('Not signed in.');
      await _client!
          .from('profiles')
          .update({'time_balance_seconds': clamped})
          .eq('id', user.id);
      return _fetchProfile(user.id);
    }

    return _updateLocalUserBalance(clamped - (await getCurrentUser())!.timeBalanceSeconds);
  }

  Future<MemberUser> _updateLocalUserBalance(int delta) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_userKey);
    if (raw == null) throw AuthException('Not signed in.');

    final user = MemberUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    final next = (user.timeBalanceSeconds + delta).clamp(0, 1 << 31);
    final updated = user.copyWith(timeBalanceSeconds: next);
    await prefs.setString(_userKey, jsonEncode(updated.toJson()));

    final accounts = _readAccounts(prefs);
    final account = accounts[user.email];
    if (account != null) {
      account['user'] = updated.toJson();
      await prefs.setString(_authKey, jsonEncode(accounts));
    }

    return updated;
  }

  Future<MemberUser> _ensureProfile(User authUser) async {
    try {
      return await _fetchProfile(authUser.id);
    } on AuthException {
      // Banned / role policy — never treat as "missing profile".
      rethrow;
    } catch (_) {
      final metadata = authUser.userMetadata ?? {};
      try {
        // Never include `role` here — upsert would overwrite admin/hr/staff
        // back to member and lock you out of the admin console.
        final row = <String, dynamic>{
          'id': authUser.id,
          'name': metadata['name'] ?? '',
          'email': authUser.email ?? '',
          'birthdate': metadata['birthdate'],
        };
        // New founder rows must land as admin.
        if (isSuperAdminEmail(authUser.email)) {
          row['role'] = UserRole.admin.name;
        }
        await _client!.from('profiles').upsert(row);
      } catch (e) {
        throw AuthException(_mapSupabaseError(e));
      }
      return _fetchProfile(authUser.id);
    }
  }

  Future<MemberUser> _fetchProfile(String userId) async {
    try {
      final row = await _client!
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();

      var user = MemberUser.fromSupabaseProfile(row);

      // Self-heal founder demotions before mobile/admin access checks.
      if (isSuperAdminEmail(user.email) && user.role != UserRole.admin) {
        await _client!
            .from('profiles')
            .update({'role': UserRole.admin.name})
            .eq('id', userId);
        user = user.copyWith(role: UserRole.admin);
      }

      _validateMobileAccess(user);
      return user;
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException(_mapSupabaseError(e));
    }
  }

  void _validateMobileAccess(MemberUser user) {
    if (user.isBanned) {
      throw AuthException(
        'Your account has been suspended. Contact the club for assistance.',
      );
    }
    // Founder operates both surfaces for demos.
    if (isSuperAdminEmail(user.email)) return;
    if (user.isAdmin) {
      throw AuthException(
        'Admin and HR accounts use the Blind Tiger web console, not the mobile app.',
      );
    }
  }

  String _mapSupabaseError(Object error) {
    final message = error.toString();
    if (message.contains('infinite recursion')) {
      return 'Database policy error. Run supabase/migrations/003_fix_rls_recursion.sql in Supabase SQL Editor.';
    }
    if (message.contains('relation') && message.contains('does not exist')) {
      return 'Database not set up. Run supabase/migrations/001_initial.sql in Supabase SQL Editor.';
    }
    if (message.contains('SocketException') || message.contains('Failed host lookup')) {
      return 'No internet connection. Check Wi‑Fi or cellular and try again.';
    }
    return 'Could not reach the server. Check your connection and Supabase setup.';
  }

  Future<MemberUser> _localSignUp({
    required MemberUser user,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final accounts = _readAccounts(prefs);

    if (accounts.containsKey(user.email)) {
      throw AuthException('An account with this email already exists.');
    }

    final saved = MemberUser(
      id: 'mem_${DateTime.now().millisecondsSinceEpoch}',
      name: user.name,
      email: user.email,
      birthdate: user.birthdate,
      role: UserRole.member,
    );

    accounts[user.email] = {
      'hash': _hashPassword(password),
      'user': saved.toJson(),
    };
    await prefs.setString(_authKey, jsonEncode(accounts));
    await prefs.setString(_userKey, jsonEncode(saved.toJson()));
    return saved;
  }

  Future<MemberUser> _localLogin({
    required String email,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final accounts = _readAccounts(prefs);
    final account = accounts[email];

    if (account == null || account['hash'] != _hashPassword(password)) {
      throw AuthException('Invalid email or password.');
    }

    final user = MemberUser.fromJson(account['user'] as Map<String, dynamic>);
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
    return user;
  }

  Map<String, Map<String, dynamic>> _readAccounts(SharedPreferences prefs) {
    final raw = prefs.getString(_authKey);
    if (raw == null) return {};
    return Map<String, Map<String, dynamic>>.from(
      (jsonDecode(raw) as Map).map(
        (k, v) => MapEntry(k as String, Map<String, dynamic>.from(v as Map)),
      ),
    );
  }

  String _hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }
}

class AuthException implements Exception {
  AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}
