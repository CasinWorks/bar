import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../core/config/supabase_config.dart';
import '../models/drink_order.dart';

/// A never-served order still open after this long is treated as abandoned.
///
/// Bartenders sometimes hand the glass over without tapping SERVE, and staff
/// devices can lose the write; without an age cut-off those rows stay `pending`
/// in Supabase forever and resurrect on every fresh install.
const drinkOrderStaleAfter = Duration(hours: 2);

/// How long a served-but-unsettled order stays chargeable.
///
/// The charge is applied by the guest's device, so it needs a window wide
/// enough to survive a phone that was asleep, offline, or reinstalled. Past it
/// the row is closed unpaid rather than left to resurface forever.
const unsettledDeliveryGrace = Duration(hours: 12);

/// True when a cloud row must no longer be tracked by the member's device.
///
/// [activeSessionId] is the member's in-progress visit, or null when there is
/// no live visit — nothing can be waiting at the bar without one. Unsettled
/// deliveries deliberately outlive their visit so the charge can still land.
@visibleForTesting
bool isStaleDrinkOrderForMember(
  DrinkOrder order, {
  required String? activeSessionId,
  required DateTime now,
  Duration maxAge = drinkOrderStaleAfter,
  Duration deliveredGrace = unsettledDeliveryGrace,
}) {
  if (order.status == DrinkOrderStatus.cancelled) return true;
  if (order.status == DrinkOrderStatus.delivered) {
    if (order.settled) return true;
    final servedAt = order.deliveredAt ?? order.orderedAt;
    return now.difference(servedAt) > deliveredGrace;
  }
  if (activeSessionId == null) return true;
  if (order.sessionId != activeSessionId) return true;
  return now.difference(order.orderedAt) > maxAge;
}

/// Applies cloud rows as source of truth and drops stale local queue ghosts.
@visibleForTesting
void mergeCloudDrinkOrders({
  required Map<String, DrinkOrder> local,
  required Map<String, DrinkOrder> cloud,
  Set<String> pendingCloudWrites = const {},
}) {
  local.addAll(cloud);

  final staleIds = local.keys.where((id) {
    if (cloud.containsKey(id)) return false;
    if (pendingCloudWrites.contains(id)) return false;
    final order = local[id]!;
    return order.isActive ||
        order.status == DrinkOrderStatus.cancelled ||
        (order.status == DrinkOrderStatus.delivered && !order.settled);
  }).toList();

  for (final id in staleIds) {
    local.remove(id);
  }
}

/// Shared drink order queue — Supabase is source of truth when configured.
class DrinkOrderService extends ChangeNotifier {
  DrinkOrderService._();

  static final DrinkOrderService instance = DrinkOrderService._();

  static const _storageKey = 'drink_orders_v1';
  final _orders = <String, DrinkOrder>{};
  final _pendingCloudWrites = <String>{};
  bool _loaded = false;
  RealtimeChannel? _realtimeChannel;

  /// Set on member devices so rows from past visits can never look live.
  /// Staff devices stay unscoped because they own the whole bar queue.
  bool _memberScoped = false;
  String? _memberSessionId;

  bool get usesCloud => SupabaseConfig.isConfigured;

  SupabaseClient? get _client => usesCloud ? Supabase.instance.client : null;

  List<DrinkOrder> get allOrders =>
      _orders.values.toList()
        ..sort((a, b) => b.orderedAt.compareTo(a.orderedAt));

  bool get _hasAuthSession => _client?.auth.currentSession != null;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    if (!usesCloud) {
      await _loadFromPrefs();
    }
    _loaded = true;
  }

  /// Reload queue from cloud (authenticated) or prefs (local pilot).
  Future<void> refresh() async {
    if (usesCloud) {
      // Without a session, RLS returns zero rows and merge would wipe the queue.
      if (!_hasAuthSession) return;
      await _syncFromCloud();
      _startRealtime();
    } else {
      _orders.clear();
      await _loadFromPrefs();
    }
    notifyListeners();
  }

  /// Call after auth so RLS-backed cloud sync returns the signed-in user's rows.
  Future<void> syncAfterAuth() => refresh();

  /// Restrict the queue to the member's in-progress visit. Pass null when the
  /// member has no live visit so leftovers from earlier nights are dropped.
  void setMemberScope({required String? sessionId}) {
    _memberScoped = true;
    _memberSessionId = sessionId;
    _pruneOutOfScopeOrders();
  }

  /// Staff bar queue owns every member's orders — no session scoping.
  void clearMemberScope() {
    _memberScoped = false;
    _memberSessionId = null;
  }

  void _pruneOutOfScopeOrders() {
    if (!_memberScoped) return;
    final now = DateTime.now();
    final stale = _orders.values
        .where((order) => !_pendingCloudWrites.contains(order.id))
        .where(
          (order) => isStaleDrinkOrderForMember(
            order,
            activeSessionId: _memberSessionId,
            now: now,
          ),
        )
        .map((order) => order.id)
        .toList();
    if (stale.isEmpty) return;
    for (final id in stale) {
      _orders.remove(id);
    }
    unawaited(_persist());
    notifyListeners();
  }

  Future<void> clearCache() async {
    _orders.clear();
    _pendingCloudWrites.clear();
    _loaded = false;
    clearMemberScope();
    stopRealtime();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
    notifyListeners();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null) return;
    final list = jsonDecode(raw) as List<dynamic>;
    for (final item in list) {
      final order = DrinkOrder.fromJson(item as Map<String, dynamic>);
      _orders[order.id] = order;
    }
  }

  Future<void> _persist() async {
    if (usesCloud) return;
    final prefs = await SharedPreferences.getInstance();
    final list = _orders.values.map((o) => o.toJson()).toList();
    await prefs.setString(_storageKey, jsonEncode(list));
  }

  /// Terminates abandoned rows in Supabase so they cannot resurrect later.
  Future<void> _closeStaleCloudOrders() async {
    final client = _client;
    if (client == null) return;
    try {
      await client.rpc(
        'close_stale_drink_orders',
        params: {
          'p_max_age_minutes': drinkOrderStaleAfter.inMinutes,
          'p_delivered_grace_minutes': unsettledDeliveryGrace.inMinutes,
        },
      );
    } catch (e) {
      // Migration 031 not applied yet — client-side scoping still hides them.
      debugPrint('DrinkOrderService: stale close skipped: $e');
    }
  }

  Future<void> _syncFromCloud() async {
    final client = _client;
    if (client == null) return;

    if (_memberScoped) {
      await _closeStaleCloudOrders();
    }

    try {
      final rows = await client
          .from('drink_orders')
          .select()
          .or(
            'status.in.(pending,preparing),and(status.eq.delivered,settled.eq.false)',
          );

      final cloudOrders = <String, DrinkOrder>{};
      final now = DateTime.now();
      for (final row in rows) {
        final order = DrinkOrder.fromSupabaseRow(
          Map<String, dynamic>.from(row as Map),
        );
        if (_memberScoped &&
            isStaleDrinkOrderForMember(
              order,
              activeSessionId: _memberSessionId,
              now: now,
            )) {
          continue;
        }
        cloudOrders[order.id] = order;
      }

      mergeCloudDrinkOrders(
        local: _orders,
        cloud: cloudOrders,
        pendingCloudWrites: _pendingCloudWrites,
      );
      await _persist();
    } catch (e) {
      debugPrint('DrinkOrderService: cloud sync failed: $e');
    }
  }

  void _startRealtime() {
    final client = _client;
    if (client == null) return;

    _realtimeChannel?.unsubscribe();
    _realtimeChannel = client
        .channel('drink-orders')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'drink_orders',
          callback: (payload) {
            final record = payload.newRecord;
            if (record.isEmpty) {
              final oldId = payload.oldRecord['id'] as String?;
              if (oldId != null) _orders.remove(oldId);
            } else {
              final order = DrinkOrder.fromSupabaseRow(
                Map<String, dynamic>.from(record),
              );
              final terminal = _memberScoped
                  ? isStaleDrinkOrderForMember(
                      order,
                      activeSessionId: _memberSessionId,
                      now: DateTime.now(),
                    )
                  : order.status == DrinkOrderStatus.cancelled ||
                        (order.status == DrinkOrderStatus.delivered &&
                            order.settled);
              if (terminal) {
                _orders.remove(order.id);
              } else {
                _orders[order.id] = order;
              }
            }
            unawaited(_persist());
            notifyListeners();
          },
        )
        .subscribe();
  }

  void stopRealtime() {
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = null;
  }

  Future<bool> _insertCloud(DrinkOrder order) async {
    final client = _client;
    if (client == null) return true;

    _pendingCloudWrites.add(order.id);
    try {
      await client.from('drink_orders').insert(order.toSupabaseRow());
      return true;
    } catch (e) {
      debugPrint('DrinkOrderService: cloud insert failed: $e');
      return false;
    } finally {
      _pendingCloudWrites.remove(order.id);
    }
  }

  Future<bool> _patchCloud(
    String orderId,
    Map<String, dynamic> fields, {
    String? requireStatus,
    List<String>? requireAnyStatus,
  }) async {
    final client = _client;
    if (client == null) return true;

    _pendingCloudWrites.add(orderId);
    try {
      var query = client.from('drink_orders').update(fields).eq('id', orderId);
      if (requireStatus != null) {
        query = query.eq('status', requireStatus);
      } else if (requireAnyStatus != null && requireAnyStatus.isNotEmpty) {
        query = query.inFilter('status', requireAnyStatus);
      }
      final rows = await query.select();
      if (rows.isEmpty) {
        debugPrint('DrinkOrderService: cloud patch no-op for $orderId');
        await _syncFromCloud();
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('DrinkOrderService: cloud patch failed: $e');
      return false;
    } finally {
      _pendingCloudWrites.remove(orderId);
    }
  }

  /// Runs a terminal-state RPC from migration 031. Returns null when the RPC is
  /// unavailable (migration not applied) so callers can use the legacy patch.
  Future<bool?> _callTerminalRpc(
    String name,
    Map<String, dynamic> params,
  ) async {
    final client = _client;
    if (client == null) return true;

    _pendingCloudWrites.add(params['p_order_id'] as String);
    try {
      final row = await client.rpc(name, params: params);
      return row != null;
    } on PostgrestException catch (e) {
      // 42883 = function does not exist; PGRST202 = not in the exposed schema.
      if (e.code == '42883' || e.code == 'PGRST202') {
        debugPrint('DrinkOrderService: $name missing, using table patch');
        return null;
      }
      debugPrint('DrinkOrderService: $name failed: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('DrinkOrderService: $name failed: $e');
      return null;
    } finally {
      _pendingCloudWrites.remove(params['p_order_id'] as String);
    }
  }

  List<DrinkOrder> pendingForStaff() =>
      _orders.values.where((o) => o.isActive).toList()
        ..sort((a, b) => a.orderedAt.compareTo(b.orderedAt));

  List<DrinkOrder> activeForMember(String memberId) =>
      _orders.values.where((o) => o.memberId == memberId && o.isActive).toList()
        ..sort((a, b) => a.orderedAt.compareTo(b.orderedAt));

  DrinkOrder? getOrder(String id) => _orders[id];

  Future<DrinkOrder> placeOrder({
    required String sessionId,
    required String memberId,
    required String memberName,
    required String drinkId,
    required String drinkName,
    required DrinkChargeSource chargeSource,
    required int costSeconds,
    bool payWithCash = false,
    String? vipRoomName,
    String? eventId,
  }) async {
    await ensureLoaded();
    final order = DrinkOrder(
      id: const Uuid().v4(),
      sessionId: sessionId,
      memberId: memberId,
      memberName: memberName,
      drinkId: drinkId,
      drinkName: drinkName,
      chargeSource: chargeSource,
      costSeconds: costSeconds,
      payWithCash: payWithCash,
      orderedAt: DateTime.now(),
      vipRoomName: vipRoomName,
      eventId: eventId,
    );
    _orders[order.id] = order;
    await _persist();
    final inserted = await _insertCloud(order);
    if (!inserted && usesCloud) {
      _orders.remove(order.id);
      await _persist();
      notifyListeners();
      throw StateError('Could not sync drink order to the bar queue.');
    }
    notifyListeners();
    return order;
  }

  Future<DrinkOrder?> markPreparing(String orderId) async {
    await ensureLoaded();
    final order = _orders[orderId];
    if (order == null || order.status != DrinkOrderStatus.pending) return null;

    final preparingAt = DateTime.now();
    final patched = await _patchCloud(orderId, {
      'status': DrinkOrderStatus.preparing.name,
      'preparing_at': preparingAt.toUtc().toIso8601String(),
    }, requireStatus: DrinkOrderStatus.pending.name);
    if (!patched) return _orders[orderId];

    final updated = order.copyWith(
      status: DrinkOrderStatus.preparing,
      preparingAt: preparingAt,
    );
    _orders[orderId] = updated;
    await _persist();
    notifyListeners();
    return updated;
  }

  /// Staff serve action. Returns null when the terminal write did not land, so
  /// the bartender is told to retry instead of seeing a false success.
  Future<DrinkOrder?> markDelivered({
    required String orderId,
    String? staffId,
    String? staffName,
  }) async {
    await ensureLoaded();
    final order = _orders[orderId];
    if (order == null || !order.isActive) return null;

    final deliveredAt = DateTime.now();
    final viaRpc = await _callTerminalRpc('staff_deliver_drink_order', {
      'p_order_id': orderId,
    });
    if (viaRpc == false) return null;

    if (viaRpc == null) {
      final patched = await _patchCloud(
        orderId,
        {
          'status': DrinkOrderStatus.delivered.name,
          'delivered_at': deliveredAt.toUtc().toIso8601String(),
          'fulfilled_by_staff_id': staffId,
          'fulfilled_by_staff_name': staffName,
        },
        requireAnyStatus: [
          DrinkOrderStatus.pending.name,
          DrinkOrderStatus.preparing.name,
        ],
      );
      if (!patched) return null;
    }

    final updated = order.copyWith(
      status: DrinkOrderStatus.delivered,
      deliveredAt: deliveredAt,
      fulfilledByStaffId: staffId,
      fulfilledByStaffName: staffName,
    );
    _orders[orderId] = updated;
    await _persist();
    notifyListeners();
    return updated;
  }

  Future<DrinkOrder?> cancelOrder(String orderId) async {
    await ensureLoaded();
    final order = _orders[orderId];
    if (order == null || !order.isActive) return null;

    final viaRpc = await _callTerminalRpc('staff_cancel_drink_order', {
      'p_order_id': orderId,
    });
    if (viaRpc == false) return _orders[orderId];

    if (viaRpc == null) {
      final patched = await _patchCloud(
        orderId,
        {'status': DrinkOrderStatus.cancelled.name},
        requireAnyStatus: [
          DrinkOrderStatus.pending.name,
          DrinkOrderStatus.preparing.name,
        ],
      );
      if (!patched) return _orders[orderId];
    }

    _orders.remove(orderId);
    await _persist();
    notifyListeners();
    return order.copyWith(status: DrinkOrderStatus.cancelled);
  }

  Future<DrinkOrder?> markSettled(
    String orderId, {
    String reason = 'member_settled',
  }) async {
    await ensureLoaded();
    final order = _orders[orderId];
    if (order == null) return null;

    final settledInCloud =
        await _callTerminalRpc('settle_drink_order', {
          'p_order_id': orderId,
          'p_reason': reason,
        }) ??
        await _patchCloud(orderId, {
          'settled': true,
        }, requireStatus: DrinkOrderStatus.delivered.name);

    if (settledInCloud != true) {
      if (_orders[orderId]?.settled == true) {
        _orders.remove(orderId);
        await _persist();
        notifyListeners();
      }
      return _orders[orderId];
    }

    if (order.status == DrinkOrderStatus.delivered) {
      _orders.remove(orderId);
    } else {
      _orders[orderId] = order.copyWith(settled: true);
    }
    await _persist();
    notifyListeners();
    return order.copyWith(settled: true);
  }
}
