import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/supabase_config.dart';
import '../models/blind_tiger_models.dart';

class DrinkPosCartLine {
  const DrinkPosCartLine({required this.drink, required this.quantity});

  final Drink drink;
  final int quantity;
}

class DrinkPosTicket {
  const DrinkPosTicket({
    required this.id,
    required this.staffId,
    required this.staffName,
    required this.lineCount,
    required this.status,
    required this.expiresAt,
    this.paidByMemberName,
    this.chargedSeconds = 0,
  });

  final String id;
  final String staffId;
  final String staffName;
  final int lineCount;
  final String status;
  final DateTime expiresAt;
  final String? paidByMemberName;
  final int chargedSeconds;

  bool get isAwaitingPayment => status == 'awaiting_payment';
  bool get isPaid => status == 'paid';

  factory DrinkPosTicket.fromRow(Map<String, dynamic> row) {
    return DrinkPosTicket(
      id: row['id'] as String,
      staffId: row['staff_id'] as String? ?? '',
      staffName: row['staff_name'] as String? ?? 'Bartender',
      lineCount: (row['line_count'] as num?)?.toInt() ?? 0,
      status: row['status'] as String? ?? 'awaiting_payment',
      expiresAt:
          DateTime.tryParse(row['expires_at'] as String? ?? '')?.toLocal() ??
          DateTime.now().add(const Duration(minutes: 10)),
      paidByMemberName: row['paid_by_member_name'] as String?,
      chargedSeconds: (row['charged_seconds'] as num?)?.toInt() ?? 0,
    );
  }
}

class DrinkPosPaymentResult {
  const DrinkPosPaymentResult({
    required this.ticketId,
    required this.drinkNames,
    required this.chargedSeconds,
    required this.balanceBefore,
    required this.balanceAfter,
    required this.packageDrinksBefore,
    required this.packageDrinksAfter,
    required this.staffName,
    this.alreadyPaid = false,
    this.packageDrinksUsed = 0,
  });

  final String ticketId;
  final String drinkNames;
  final int chargedSeconds;
  final int balanceBefore;
  final int balanceAfter;
  final int packageDrinksBefore;
  final int packageDrinksAfter;
  final String staffName;
  final bool alreadyPaid;
  final int packageDrinksUsed;

  factory DrinkPosPaymentResult.fromJson(Map<String, dynamic> json) {
    return DrinkPosPaymentResult(
      ticketId: json['ticket_id'] as String? ?? '',
      drinkNames: json['drink_names'] as String? ?? 'Drinks',
      chargedSeconds: (json['charged_seconds'] as num?)?.toInt() ?? 0,
      balanceBefore: (json['balance_before'] as num?)?.toInt() ?? 0,
      balanceAfter: (json['balance_after'] as num?)?.toInt() ?? 0,
      packageDrinksBefore: (json['package_drinks_before'] as num?)?.toInt() ?? 0,
      packageDrinksAfter: (json['package_drinks_after'] as num?)?.toInt() ?? 0,
      staffName: json['staff_name'] as String? ?? 'Bartender',
      alreadyPaid: json['already_paid'] == true,
      packageDrinksUsed: (json['package_drinks_used'] as num?)?.toInt() ?? 0,
    );
  }
}

class DrinkPosService {
  DrinkPosService();

  bool get usesCloud => SupabaseConfig.isConfigured;
  SupabaseClient? get _client => usesCloud ? Supabase.instance.client : null;

  Future<DrinkPosTicket> createTicket(List<DrinkPosCartLine> lines) async {
    final client = _client;
    if (client == null) {
      throw StateError('Cloud required for bartender POS.');
    }
    final items = lines
        .where((l) => l.quantity > 0)
        .map(
          (l) => {
            'slug': l.drink.slug,
            'quantity': l.quantity,
          },
        )
        .toList();
    if (items.isEmpty) throw StateError('Cart is empty.');

    final row = await client.rpc(
      'staff_create_drink_pos_ticket',
      params: {'p_items': items},
    );
    if (row is! Map) {
      throw StateError('Could not create POS ticket.');
    }
    return DrinkPosTicket.fromRow(Map<String, dynamic>.from(row));
  }

  Future<void> cancelTicket(String ticketId) async {
    final client = _client;
    if (client == null) return;
    try {
      await client.rpc(
        'staff_cancel_drink_pos_ticket',
        params: {'p_ticket_id': ticketId},
      );
    } catch (e) {
      debugPrint('DrinkPosService.cancelTicket: $e');
    }
  }

  Future<DrinkPosPaymentResult> payTicket(String ticketId) async {
    final client = _client;
    if (client == null) {
      throw StateError('Cloud required to pay at the bar.');
    }
    final row = await client.rpc(
      'pay_drink_pos_ticket',
      params: {'p_ticket_id': ticketId},
    );
    if (row is! Map) {
      throw StateError('Payment failed.');
    }
    return DrinkPosPaymentResult.fromJson(Map<String, dynamic>.from(row));
  }

  RealtimeChannel watchTicket({
    required String ticketId,
    required void Function(DrinkPosTicket ticket) onUpdate,
  }) {
    final client = _client!;
    final channel = client.channel('drink-pos-$ticketId');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'drink_pos_tickets',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: ticketId,
          ),
          callback: (payload) {
            final row = payload.newRecord;
            onUpdate(DrinkPosTicket.fromRow(Map<String, dynamic>.from(row)));
          },
        )
        .subscribe();
    return channel;
  }
}
