import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/supabase_config.dart';
import '../data/mock_data.dart';
import '../models/blind_tiger_models.dart';
import '../models/drink_catalog.dart';

/// Loads active drinks from Supabase `drink_catalog`.
class DrinkCatalogService {
  DrinkCatalogService();

  bool get usesCloud => SupabaseConfig.isConfigured;

  SupabaseClient? get _client => usesCloud ? Supabase.instance.client : null;

  Future<List<Drink>> listActiveDrinks() async {
    final client = _client;
    if (client == null) {
      DrinkCatalog.replaceCatalog(MockData.drinks);
      return DrinkCatalog.active;
    }

    try {
      final rows = await client
          .from('drink_catalog')
          .select(
            'id, slug, name, kind, time_cost_seconds, price_peso, category, '
            'description, flavor, abv, badge, ingredients, bartender_quote, '
            'image_color_start, image_color_end, active, sort_order',
          )
          .eq('active', true)
          .order('sort_order')
          .order('name');

      final drinks = rows
          .map((row) => Drink.fromCatalogRow(Map<String, dynamic>.from(row)))
          .where((d) => d.slug.isNotEmpty && d.name.isNotEmpty)
          .toList();

      if (drinks.isEmpty) {
        DrinkCatalog.replaceCatalog(MockData.drinks);
        return DrinkCatalog.active;
      }
      DrinkCatalog.replaceCatalog(drinks);
      return drinks;
    } catch (e) {
      debugPrint('DrinkCatalogService: listActiveDrinks failed: $e');
      DrinkCatalog.replaceCatalog(MockData.drinks);
      return DrinkCatalog.active;
    }
  }
}
