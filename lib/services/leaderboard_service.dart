import 'dart:convert';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/admin_api_config.dart';
import '../core/config/supabase_config.dart';
import '../models/blind_tiger_models.dart';

class ClubRanking {
  const ClubRanking({
    required this.id,
    required this.rank,
    required this.name,
    required this.timeBalanceSeconds,
    required this.isCurrentUser,
    this.role = 'member',
  });

  final String id;
  final int rank;
  final String name;
  final int timeBalanceSeconds;
  final bool isCurrentUser;
  final String role;
}

class LeaderboardService {
  Future<List<ClubRanking>> fetchRankings({int limit = 50}) async {
    if (!SupabaseConfig.isConfigured || !AdminApiConfig.isConfigured) {
      return const [];
    }

    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    if (token == null || token.isEmpty) return const [];

    final uri = Uri.parse('${AdminApiConfig.url}/api/leaderboard').replace(
      queryParameters: {'limit': '$limit'},
    );

    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close().timeout(const Duration(seconds: 12));
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Leaderboard failed (${response.statusCode})');
      }

      final json = jsonDecode(body) as Map<String, dynamic>;
      final rows = (json['rankings'] as List<dynamic>? ?? const []);
      return rows.map((raw) {
        final row = Map<String, dynamic>.from(raw as Map);
        return ClubRanking(
          id: row['id'] as String,
          rank: row['rank'] as int? ?? 0,
          name: row['name'] as String? ?? 'Guest',
          timeBalanceSeconds: row['timeBalanceSeconds'] as int? ?? 0,
          isCurrentUser: row['isCurrentUser'] as bool? ?? false,
          role: row['role'] as String? ?? 'member',
        );
      }).toList();
    } finally {
      client.close(force: true);
    }
  }

  List<LeaderboardUser> toLeaderboardUsers(List<ClubRanking> rankings) {
    const palette = <int>[
      0xFF8B0000,
      0xFFC5A059,
      0xFFD97706,
      0xFF7C3AED,
      0xFF2ECC71,
      0xFFB22222,
      0xFF8E6E35,
    ];

    return [
      for (var i = 0; i < rankings.length; i++)
        LeaderboardUser(
          rank: rankings[i].rank,
          name: rankings[i].name,
          points: rankings[i].timeBalanceSeconds ~/ 60,
          tier: MemberTierThresholds.tierForSeconds(rankings[i].timeBalanceSeconds),
          isCurrentUser: rankings[i].isCurrentUser,
          avatarColor: palette[i % palette.length],
          avatarGlyph: rankings[i].name.isNotEmpty
              ? rankings[i].name.substring(0, 1).toUpperCase()
              : '?',
          timeBalance: rankings[i].timeBalanceSeconds,
        ),
    ];
  }
}
