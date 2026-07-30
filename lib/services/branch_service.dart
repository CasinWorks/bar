import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/supabase_config.dart';
import '../models/branch_location.dart';

class BranchService {
  BranchService();

  static const defaultBranches = [
    BranchLocation(
      id: 'default-cubao-branch',
      slug: 'cubao-branch',
      name: 'Cubao Branch',
      sortOrder: 1,
      isActive: true,
      isDefault: true,
    ),
    BranchLocation(
      id: 'default-tomas-morato',
      slug: 'tomas-morato',
      name: 'Tomas Morato',
      sortOrder: 2,
      isActive: true,
      isDefault: false,
    ),
  ];

  bool get usesCloud => SupabaseConfig.isConfigured;

  SupabaseClient? get _client => usesCloud ? Supabase.instance.client : null;

  Future<List<BranchLocation>> listActiveBranches() async {
    final client = _client;
    if (client == null) return defaultBranches;

    try {
      final rows = await client
          .from('branches')
          .select('id, slug, name, sort_order, is_active, is_default')
          .eq('is_active', true)
          .order('sort_order')
          .order('name');
      final branches = rows
          .map(
            (row) =>
                BranchLocation.fromSupabaseRow(Map<String, dynamic>.from(row)),
          )
          .where((branch) => branch.name.trim().isNotEmpty)
          .toList();
      return branches.isEmpty ? defaultBranches : branches;
    } catch (e) {
      debugPrint('BranchService: listActiveBranches failed: $e');
      return defaultBranches;
    }
  }
}
