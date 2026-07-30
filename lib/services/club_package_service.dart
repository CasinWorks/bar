import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/supabase_config.dart';
import '../models/club_packages.dart';

/// Loads active entry packages from Supabase `time_packages`.
class ClubPackageService {
  ClubPackageService();

  bool get usesCloud => SupabaseConfig.isConfigured;

  SupabaseClient? get _client => usesCloud ? Supabase.instance.client : null;

  Future<List<ClubPackage>> listActivePackages() async {
    final client = _client;
    if (client == null) return ClubPackages.defaults;

    try {
      final rows = await client
          .from('time_packages')
          .select(
            'slug, name, price_peso, duration_minutes, included_drinks, '
            'target_guest, tagline, popular, sort_order, active',
          )
          .eq('active', true)
          .order('sort_order')
          .order('name');

      final packages = rows
          .map(
            (row) =>
                ClubPackage.fromSupabaseRow(Map<String, dynamic>.from(row)),
          )
          .where((pkg) => pkg.slug.isNotEmpty && pkg.name.isNotEmpty)
          .toList();

      if (packages.isEmpty) return ClubPackages.defaults;
      ClubPackages.replaceCatalog(packages);
      return packages;
    } catch (e) {
      debugPrint('ClubPackageService: listActivePackages failed: $e');
      return ClubPackages.defaults;
    }
  }
}
