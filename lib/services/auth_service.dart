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

  SupabaseClient? get _client => usesSupabase ? Supabase.instance.client : null;

  Future<MemberUser?> getCurrentUser() async {
    if (usesSupabase) {
      final session = await _resolvedSession();
      if (session == null) return null;
      final user = session.user;
      try {
        return await _fetchProfile(user.id);
      } on AccessDeniedException {
        // Banned / wrong surface — wipe the session so they can't loop.
        await logout();
        return null;
      } catch (_) {
        // Network / missing row / transient errors must NOT sign the member out.
        // Keep the persisted Supabase session and hydrate from auth metadata.
        try {
          return await _ensureProfile(user);
        } on AccessDeniedException {
          await logout();
          return null;
        } catch (_) {
          return _memberFromAuthUser(user);
        }
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_userKey);
    if (raw == null) return null;
    return MemberUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  /// Prefer the live session; if the access token is stale, ask GoTrue to refresh.
  Future<Session?> _resolvedSession() async {
    final client = _client;
    if (client == null) return null;

    final current = client.auth.currentSession;
    if (current == null) return null;
    if (!current.isExpired) return current;

    try {
      final refreshed = await client.auth.refreshSession();
      return refreshed.session ?? client.auth.currentSession;
    } catch (_) {
      // Keep whatever is still on disk — a later call may succeed.
      return client.auth.currentSession;
    }
  }

  MemberUser _memberFromAuthUser(User authUser) {
    final metadata = authUser.userMetadata ?? {};
    final birthRaw = metadata['birthdate'] as String?;
    return MemberUser(
      id: authUser.id,
      name: (metadata['name'] as String?)?.trim().isNotEmpty == true
          ? metadata['name'] as String
          : (authUser.email ?? 'Member'),
      email: authUser.email ?? '',
      birthdate: birthRaw != null ? DateTime.tryParse(birthRaw) : null,
      role: isSuperAdminEmail(authUser.email)
          ? UserRole.admin
          : MemberUser.parseRole(metadata['role'] as String?),
    );
  }

  Future<SignUpResult> signUp({
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
      final AuthResponse response;
      try {
        response = await _client!.auth.signUp(
          email: user.email,
          password: password,
          data: {
            'name': user.name,
            'birthdate': birthdate.toIso8601String().split('T').first,
            'role': UserRole.member.name,
          },
        );
      } catch (e) {
        final msg = e.toString().toLowerCase();
        if (msg.contains('already registered') ||
            msg.contains('already been registered')) {
          throw AuthException(
            'That email already has a pass. Sign in instead.',
          );
        }
        throw AuthException(
          'Sign up failed. Check your connection and try again.',
        );
      }

      final authUser = response.user;
      if (authUser == null) {
        throw AuthException('Sign up failed. Please try again.');
      }

      // Supabase confirm-email ON → no session until the link is opened.
      if (response.session == null) {
        return SignUpResult.needsEmailVerification(
          email: user.email,
          name: user.name,
        );
      }

      final member = await _ensureProfile(authUser);
      return SignUpResult.signedIn(member);
    }

    final member = await _localSignUp(user: user, password: password);
    return SignUpResult.signedIn(member);
  }

  Future<void> resendSignupConfirmation(String email) async {
    if (!usesSupabase) return;
    try {
      await _client!.auth.resend(
        type: OtpType.signup,
        email: email.trim().toLowerCase(),
      );
    } catch (_) {
      throw AuthException(
        'Could not resend the email. Wait a moment and try again.',
      );
    }
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

  /// Verifies the current password, then updates it in Supabase Auth (or local).
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final next = newPassword.trim();
    if (next.length < 8) {
      throw AuthException('New password must be at least 8 characters.');
    }
    if (currentPassword == next) {
      throw AuthException('New password must be different from the current one.');
    }

    if (usesSupabase) {
      final session = _client!.auth.currentSession;
      final email = session?.user.email;
      if (session == null || email == null || email.isEmpty) {
        throw AuthException('Not signed in.');
      }

      try {
        await _client!.auth.signInWithPassword(
          email: email,
          password: currentPassword,
        );
      } catch (_) {
        throw AuthException('Current password is incorrect.');
      }

      try {
        await _client!.auth.updateUser(UserAttributes(password: next));
      } catch (e) {
        throw AuthException(_mapSupabaseError(e));
      }
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_userKey);
    if (raw == null) throw AuthException('Not signed in.');
    final user = MemberUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    final accounts = _readAccounts(prefs);
    final account = accounts[user.email];
    if (account == null || account['hash'] != _hashPassword(currentPassword)) {
      throw AuthException('Current password is incorrect.');
    }
    account['hash'] = _hashPassword(next);
    await prefs.setString(_authKey, jsonEncode(accounts));
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
                fromMemberName:
                    record['from_member_name'] as String? ?? 'Guest',
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
      try {
        final row = await _client!.rpc(
          'spend_time_balance',
          params: {'p_seconds': seconds},
        );
        if (row is Map<String, dynamic>) {
          return MemberUser.fromSupabaseProfile(row);
        }
        return _fetchProfile(user.id);
      } catch (e) {
        // Fallback when migration 021 is not applied yet — conditional update.
        final msg = e.toString().toLowerCase();
        if (msg.contains('not enough time') ||
            msg.contains('enough time balance')) {
          throw AuthException('Not enough time balance.');
        }
        if (user.timeBalanceSeconds < seconds) {
          throw AuthException('Not enough time balance.');
        }
        final next = user.timeBalanceSeconds - seconds;
        final updated = await _client!
            .from('profiles')
            .update({'time_balance_seconds': next})
            .eq('id', user.id)
            .gte('time_balance_seconds', seconds)
            .select()
            .maybeSingle();
        if (updated == null) {
          throw AuthException('Not enough time balance.');
        }
        return MemberUser.fromSupabaseProfile(updated);
      }
    }

    return _updateLocalUserBalance(-seconds);
  }

  /// Relative timer sync — subtract debt without absolute overwrite.
  Future<MemberUser> applyTimerDebt(int seconds) async {
    if (seconds <= 0) return (await getCurrentUser())!;

    if (usesSupabase) {
      final user = await getCurrentUser();
      if (user == null) throw AuthException('Not signed in.');
      try {
        final row = await _client!.rpc(
          'apply_timer_debt',
          params: {'p_seconds': seconds},
        );
        if (row is Map<String, dynamic>) {
          return MemberUser.fromSupabaseProfile(row);
        }
        return _fetchProfile(user.id);
      } catch (_) {
        final next = (user.timeBalanceSeconds - seconds).clamp(0, 1 << 31);
        await _client!
            .from('profiles')
            .update({'time_balance_seconds': next})
            .eq('id', user.id);
        return _fetchProfile(user.id);
      }
    }

    return _updateLocalUserBalance(-seconds);
  }

  Future<MemberUser> consumeIncludedDrink({String? sessionId}) async {
    if (usesSupabase) {
      final user = await getCurrentUser();
      if (user == null) throw AuthException('Not signed in.');
      try {
        final row = await _client!.rpc(
          'consume_included_drink',
          params: {'p_session_id': sessionId},
        );
        if (row is Map<String, dynamic>) {
          return MemberUser.fromSupabaseProfile(row);
        }
        return _fetchProfile(user.id);
      } catch (e) {
        final msg = e.toString().toLowerCase();
        if (msg.contains('no package drinks')) {
          throw AuthException('No package drinks remaining.');
        }
        if (user.includedDrinksRemaining < 1) {
          throw AuthException('No package drinks remaining.');
        }
        final next = user.includedDrinksRemaining - 1;
        await _client!
            .from('profiles')
            .update({'included_drinks_remaining': next})
            .eq('id', user.id)
            .gte('included_drinks_remaining', 1);
        return _fetchProfile(user.id);
      }
    }

    final current = await getCurrentUser();
    if (current == null) throw AuthException('Not signed in.');
    if (current.includedDrinksRemaining < 1) {
      throw AuthException('No package drinks remaining.');
    }
    return _updateLocalUserDrinks(current.includedDrinksRemaining - 1);
  }

  Future<MemberUser> redeemVenueActivity({
    required String activitySlug,
    required int minutes,
    String? sessionId,
  }) async {
    if (usesSupabase) {
      final user = await getCurrentUser();
      if (user == null) throw AuthException('Not signed in.');
      try {
        final row = await _client!.rpc(
          'redeem_venue_activity',
          params: {
            'p_activity_slug': activitySlug,
            'p_session_id': sessionId,
            'p_minutes': minutes,
          },
        );
        if (row is Map<String, dynamic>) {
          return MemberUser.fromSupabaseProfile(row);
        }
        return _fetchProfile(user.id);
      } catch (e) {
        final msg = e.toString().toLowerCase();
        if (msg.contains('not enough time')) {
          throw AuthException('Not enough time balance.');
        }
        return deductTimeBalance(minutes * 60);
      }
    }

    return deductTimeBalance(minutes * 60);
  }

  /// Set wallet balance directly (admin / local restore only).
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

    return _updateLocalUserBalance(
      clamped - (await getCurrentUser())!.timeBalanceSeconds,
    );
  }

  Future<MemberUser> _updateLocalUserDrinks(int remaining) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_userKey);
    if (raw == null) throw AuthException('Not signed in.');

    final user = MemberUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    final updated = user.copyWith(
      includedDrinksRemaining: remaining.clamp(0, 1 << 31),
    );
    await prefs.setString(_userKey, jsonEncode(updated.toJson()));

    final accounts = _readAccounts(prefs);
    final account = accounts[user.email];
    if (account != null) {
      account['user'] = updated.toJson();
      await prefs.setString(_authKey, jsonEncode(accounts));
    }

    return updated;
  }

  /// Persist a fully updated local user row (demo / offline mode).
  Future<MemberUser> persistLocalUser(MemberUser user) async {
    if (usesSupabase) return user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
    final accounts = _readAccounts(prefs);
    final account = accounts[user.email];
    if (account != null) {
      account['user'] = user.toJson();
      await prefs.setString(_authKey, jsonEncode(accounts));
    }
    return user;
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
    } on AccessDeniedException {
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
    } on AccessDeniedException {
      rethrow;
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException(_mapSupabaseError(e));
    }
  }

  void _validateMobileAccess(MemberUser user) {
    if (user.isBanned) {
      throw AccessDeniedException(
        'Your account has been suspended. Contact the club for assistance.',
      );
    }
    // Founder operates both surfaces for demos.
    if (isSuperAdminEmail(user.email)) return;
    if (user.isAdmin) {
      throw AccessDeniedException(
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
    if (message.contains('SocketException') ||
        message.contains('Failed host lookup')) {
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

class SignUpResult {
  const SignUpResult._({
    required this.email,
    required this.name,
    required this.needsEmailVerification,
    this.user,
  });

  factory SignUpResult.signedIn(MemberUser user) => SignUpResult._(
    email: user.email,
    name: user.name,
    needsEmailVerification: false,
    user: user,
  );

  factory SignUpResult.needsEmailVerification({
    required String email,
    required String name,
  }) => SignUpResult._(email: email, name: name, needsEmailVerification: true);

  final String email;
  final String name;
  final bool needsEmailVerification;
  final MemberUser? user;
}

/// Thrown when the account must not use the mobile app (banned / admin console).
class AccessDeniedException extends AuthException {
  AccessDeniedException(super.message);
}

class AuthException implements Exception {
  AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}
