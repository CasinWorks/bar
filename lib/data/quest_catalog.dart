import '../models/quest_system.dart';

abstract final class QuestCatalog {
  static List<ClubQuest> icebreakerQuests() => [
    ClubQuest(
      id: 'ice-1',
      title: 'Stranger No More',
      objective: 'Introduce yourself to 3 new people',
      category: QuestCategory.icebreaker,
      targetCount: 3,
      rewards: const [
        QuestReward(type: QuestRewardType.liquidMinutes, amount: 5),
      ],
    ),
    ClubQuest(
      id: 'ice-2',
      title: 'Cheers!',
      objective: 'Toast with someone you\'ve never met',
      category: QuestCategory.icebreaker,
      targetCount: 1,
      rewards: const [QuestReward(type: QuestRewardType.xp, amount: 25)],
    ),
    ClubQuest(
      id: 'ice-3',
      title: 'Tiger Greeting',
      objective: 'Learn someone\'s first name and hometown',
      category: QuestCategory.icebreaker,
      targetCount: 1,
      rewards: const [
        QuestReward(type: QuestRewardType.badge, badgeId: 'tiger_greeting'),
      ],
    ),
    ClubQuest(
      id: 'ice-4',
      title: 'Table Hopper',
      objective: 'Visit 3 different tables',
      category: QuestCategory.icebreaker,
      targetCount: 3,
      rewards: const [
        QuestReward(type: QuestRewardType.liquidMinutes, amount: 3),
      ],
    ),
  ];

  static List<ClubQuest> socialQuests() => [
    ClubQuest(
      id: 'soc-1',
      title: 'Form the Pack',
      objective: 'Create a group of 5 strangers',
      category: QuestCategory.social,
      targetCount: 5,
      rewards: const [
        QuestReward(type: QuestRewardType.liquidMinutes, amount: 10),
      ],
    ),
    ClubQuest(
      id: 'soc-2',
      title: 'Story Swap',
      objective: 'Share your funniest travel story',
      category: QuestCategory.social,
      targetCount: 1,
      rewards: const [QuestReward(type: QuestRewardType.xp, amount: 40)],
    ),
    ClubQuest(
      id: 'soc-3',
      title: 'Blind Vote',
      objective: 'Let others vote for the best storyteller',
      category: QuestCategory.social,
      targetCount: 1,
      rewards: const [
        QuestReward(
          type: QuestRewardType.rareBadge,
          badgeId: 'storyteller_crown',
        ),
      ],
    ),
    ClubQuest(
      id: 'soc-4',
      title: 'Dance Circle',
      objective: 'Dance with someone new',
      category: QuestCategory.social,
      targetCount: 1,
      rewards: const [
        QuestReward(type: QuestRewardType.liquidMinutes, amount: 8),
      ],
    ),
  ];

  static List<ClubQuest> teamQuests() => [
    ClubQuest(
      id: 'team-1',
      title: 'Tiger Hunt',
      objective: 'Find hidden QR codes around the club',
      category: QuestCategory.team,
      targetCount: 3,
      rewards: const [
        QuestReward(type: QuestRewardType.bankedMinutes, amount: 15),
        QuestReward(type: QuestRewardType.xp, amount: 50),
      ],
    ),
    ClubQuest(
      id: 'team-2',
      title: 'Time Heist',
      objective: 'Solve clues before the countdown ends',
      category: QuestCategory.team,
      targetCount: 1,
      rewards: const [
        QuestReward(type: QuestRewardType.liquidMinutes, amount: 20),
      ],
    ),
    ClubQuest(
      id: 'team-3',
      title: 'Escape the Clock',
      objective: 'Puzzle game against other teams',
      category: QuestCategory.team,
      targetCount: 1,
      rewards: const [
        QuestReward(type: QuestRewardType.bankedMinutes, amount: 25),
      ],
    ),
    ClubQuest(
      id: 'team-4',
      title: 'Beat the Dealer',
      objective: 'Win against the bartender\'s challenge',
      category: QuestCategory.team,
      targetCount: 1,
      rewards: const [
        QuestReward(type: QuestRewardType.liquidMinutes, amount: 12),
        QuestReward(type: QuestRewardType.xp, amount: 35),
      ],
    ),
  ];

  static List<ClubQuest> weeklyMovieQuests() {
    final theme = _currentMovieTheme();
    return [
      ClubQuest(
        id: 'movie-week',
        title: theme.$1,
        objective: theme.$2,
        category: QuestCategory.weeklyMovie,
        targetCount: 1,
        isWeekly: true,
        movieTheme: theme.$3,
        rewards: const [
          QuestReward(type: QuestRewardType.bankedMinutes, amount: 30),
          QuestReward(type: QuestRewardType.xp, amount: 75),
        ],
      ),
    ];
  }

  static (String, String, String) _currentMovieTheme() {
    final week = DateTime.now().day ~/ 7;
    return switch (week % 5) {
      0 => (
        'Golden Ticket',
        'Find the Golden Ticket hidden in the club',
        'Charlie & the Chocolate Factory',
      ),
      1 => (
        'Continental Contract',
        'Complete 3 secret missions tonight',
        'John Wick',
      ),
      2 => (
        'Red Light Games',
        'Win 2 party mini-games with strangers',
        'Squid Game',
      ),
      3 => (
        'Ocean\'s Heist',
        'Team puzzle — crack the vault code',
        'Ocean\'s Eleven',
      ),
      _ => (
        'Wonderland Clues',
        'Follow hidden Wonderland clues to the tea room',
        'Alice in Wonderland',
      ),
    };
  }

  static const mysteryPool = [
    ('Find someone celebrating a birthday', 'birthday_finder'),
    ('Make three people laugh', 'comedian'),
    ('Find someone wearing red', 'red_hunter'),
    ('Convince someone to dance', 'dance_convincer'),
    ('High-five five strangers', 'high_fiver'),
    ('Find someone from another country', 'globe_trotter'),
    ('Compliment a stranger\'s outfit', 'style_spotter'),
    ('Learn a dance move from someone', 'move_learner'),
  ];

  static ClubQuest mysteryQuestFor(String memberId) {
    final hash = memberId.hashCode.abs();
    final pick = mysteryPool[hash % mysteryPool.length];
    return ClubQuest(
      id: 'mystery-$memberId',
      title: 'Your Secret Mission',
      objective: pick.$1,
      category: QuestCategory.mystery,
      targetCount: 1,
      hidden: true,
      rewards: const [
        QuestReward(type: QuestRewardType.bankedMinutes, amount: 10),
        QuestReward(type: QuestRewardType.xp, amount: 30),
      ],
    );
  }

  static List<ClubQuest> reputationQuests() => [
    ClubQuest(
      id: 'rep-1',
      title: 'Rise to Hunter',
      objective: 'Reach Hunter reputation (100 XP)',
      category: QuestCategory.reputation,
      targetCount: 100,
      rewards: const [
        QuestReward(type: QuestRewardType.badge, badgeId: 'hunter_rank'),
      ],
    ),
    ClubQuest(
      id: 'rep-2',
      title: 'Alpha Status',
      objective: 'Reach Alpha reputation (300 XP)',
      category: QuestCategory.reputation,
      targetCount: 300,
      rewards: const [
        QuestReward(type: QuestRewardType.badge, badgeId: 'alpha_rank'),
      ],
    ),
    ClubQuest(
      id: 'rep-3',
      title: 'White Tiger',
      objective: 'Reach White Tiger reputation (750 XP)',
      category: QuestCategory.reputation,
      targetCount: 750,
      rewards: const [
        QuestReward(type: QuestRewardType.rareBadge, badgeId: 'white_tiger'),
      ],
    ),
  ];

  static List<ClubQuest> timeQuests() => [
    ClubQuest(
      id: 'time-1',
      title: 'Kindness',
      objective: 'Gift 10 minutes to another guest',
      category: QuestCategory.timeQuest,
      targetCount: 10,
      rewards: const [
        QuestReward(type: QuestRewardType.badge, badgeId: 'kindness'),
      ],
    ),
    ClubQuest(
      id: 'time-2',
      title: 'Social Butterfly',
      objective: 'Receive time from a stranger',
      category: QuestCategory.timeQuest,
      targetCount: 1,
      rewards: const [
        QuestReward(type: QuestRewardType.badge, badgeId: 'social_time'),
      ],
    ),
    ClubQuest(
      id: 'time-3',
      title: 'Precision',
      objective: 'End the night with exactly 00:00',
      category: QuestCategory.timeQuest,
      targetCount: 1,
      rewards: const [
        QuestReward(type: QuestRewardType.badge, badgeId: 'precision'),
      ],
    ),
    ClubQuest(
      id: 'time-4',
      title: 'Time Investor',
      objective: 'Save 60 unused minutes across visits',
      category: QuestCategory.timeQuest,
      targetCount: 60,
      rewards: const [
        QuestReward(type: QuestRewardType.badge, badgeId: 'time_investor'),
      ],
    ),
    ClubQuest(
      id: 'time-5',
      title: 'Philanthropist',
      objective: 'Donate time to the community pool',
      category: QuestCategory.timeQuest,
      targetCount: 15,
      rewards: const [
        QuestReward(type: QuestRewardType.badge, badgeId: 'philanthropist'),
      ],
    ),
  ];

  static List<ClubQuest> allVisibleQuests() => [
    ...icebreakerQuests(),
    ...socialQuests(),
    ...teamQuests(),
    ...weeklyMovieQuests(),
    ...reputationQuests(),
    ...timeQuests(),
  ];

  static Map<LeaderboardCategory, List<CompetitiveRanking>> mockRankings(
    String? currentUserName,
  ) {
    final you = currentUserName ?? 'You';
    return {
      LeaderboardCategory.mostSocial: [
        CompetitiveRanking(
          rank: 1,
          name: 'ManilaMogul',
          score: 24,
          category: LeaderboardCategory.mostSocial,
          avatarGlyph: 'M',
        ),
        CompetitiveRanking(
          rank: 2,
          name: you,
          score: 18,
          category: LeaderboardCategory.mostSocial,
          isCurrentUser: true,
          avatarGlyph: 'Y',
        ),
        CompetitiveRanking(
          rank: 3,
          name: 'JazzSasha_9',
          score: 15,
          category: LeaderboardCategory.mostSocial,
          avatarGlyph: 'J',
        ),
      ],
      LeaderboardCategory.bestDancer: [
        CompetitiveRanking(
          rank: 1,
          name: 'DiscoDiva',
          score: 12,
          category: LeaderboardCategory.bestDancer,
          avatarGlyph: 'D',
        ),
        CompetitiveRanking(
          rank: 2,
          name: you,
          score: 8,
          category: LeaderboardCategory.bestDancer,
          isCurrentUser: true,
          avatarGlyph: 'Y',
        ),
        CompetitiveRanking(
          rank: 3,
          name: 'Vince_Beat',
          score: 7,
          category: LeaderboardCategory.bestDancer,
          avatarGlyph: 'V',
        ),
      ],
      LeaderboardCategory.mostQuestsCompleted: [
        CompetitiveRanking(
          rank: 1,
          name: you,
          score: 6,
          category: LeaderboardCategory.mostQuestsCompleted,
          isCurrentUser: true,
          avatarGlyph: 'Y',
        ),
        CompetitiveRanking(
          rank: 2,
          name: 'TigerSovereign',
          score: 5,
          category: LeaderboardCategory.mostQuestsCompleted,
          avatarGlyph: 'T',
        ),
        CompetitiveRanking(
          rank: 3,
          name: 'Suki_Tiger',
          score: 4,
          category: LeaderboardCategory.mostQuestsCompleted,
          avatarGlyph: 'S',
        ),
      ],
      LeaderboardCategory.mostIntroductions: [
        CompetitiveRanking(
          rank: 1,
          name: 'LoungeQueen',
          score: 31,
          category: LeaderboardCategory.mostIntroductions,
          avatarGlyph: 'L',
        ),
        CompetitiveRanking(
          rank: 2,
          name: you,
          score: 22,
          category: LeaderboardCategory.mostIntroductions,
          isCurrentUser: true,
          avatarGlyph: 'Y',
        ),
        CompetitiveRanking(
          rank: 3,
          name: 'ChronoSam',
          score: 19,
          category: LeaderboardCategory.mostIntroductions,
          avatarGlyph: 'C',
        ),
      ],
      LeaderboardCategory.longestConsecutiveVisit: [
        CompetitiveRanking(
          rank: 1,
          name: 'TigerSovereign',
          score: 12,
          category: LeaderboardCategory.longestConsecutiveVisit,
          avatarGlyph: 'T',
        ),
        CompetitiveRanking(
          rank: 2,
          name: you,
          score: 8,
          category: LeaderboardCategory.longestConsecutiveVisit,
          isCurrentUser: true,
          avatarGlyph: 'Y',
        ),
        CompetitiveRanking(
          rank: 3,
          name: 'ManilaMogul',
          score: 6,
          category: LeaderboardCategory.longestConsecutiveVisit,
          avatarGlyph: 'M',
        ),
      ],
      LeaderboardCategory.fastestQuestFinisher: [
        CompetitiveRanking(
          rank: 1,
          name: you,
          score: 4,
          category: LeaderboardCategory.fastestQuestFinisher,
          isCurrentUser: true,
          avatarGlyph: 'Y',
        ),
        CompetitiveRanking(
          rank: 2,
          name: 'Kusanagi_M',
          score: 6,
          category: LeaderboardCategory.fastestQuestFinisher,
          avatarGlyph: 'K',
        ),
        CompetitiveRanking(
          rank: 3,
          name: 'Vince_Beat',
          score: 8,
          category: LeaderboardCategory.fastestQuestFinisher,
          avatarGlyph: 'V',
        ),
      ],
    };
  }
}
