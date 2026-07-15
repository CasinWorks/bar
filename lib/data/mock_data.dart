import '../models/blind_tiger_models.dart';

abstract final class MockData {
  static const hairOptions = [
    AvatarOption(id: 'hair-1', name: 'Dapper Pompadour', path: 'DP'),
    AvatarOption(id: 'hair-2', name: 'Jazz Age Finger Waves', path: 'JW'),
    AvatarOption(id: 'hair-3', name: 'Modern Slickback', path: 'MS'),
    AvatarOption(id: 'hair-4', name: 'Disheveled Shag', path: 'DS'),
    AvatarOption(id: 'hair-5', name: 'Tiger-Stripe Fedora', path: 'TF'),
  ];

  static const eyesOptions = [
    AvatarOption(id: 'eyes-1', name: 'Classic Aviators', path: 'CA'),
    AvatarOption(id: 'eyes-2', name: 'Cat-Eye Sunglasses', path: 'CE'),
    AvatarOption(id: 'eyes-3', name: 'Smoky Velvet Eyes', path: 'SV'),
    AvatarOption(id: 'eyes-4', name: 'Intimate Monocle', path: 'IM'),
    AvatarOption(id: 'eyes-5', name: 'Vintage Wayfarers', path: 'VW'),
  ];

  static const accessoryOptions = [
    AvatarOption(id: 'acc-1', name: 'Gold Tiger Lapel Pin', path: 'GP'),
    AvatarOption(id: 'acc-2', name: 'Retro Velvet Choker', path: 'RC'),
    AvatarOption(id: 'acc-3', name: 'Cuban Cigar', path: 'CC'),
    AvatarOption(id: 'acc-4', name: 'Saxophone Lapel Badge', path: 'SL'),
    AvatarOption(id: 'acc-5', name: 'Pearl Drop Earring', path: 'PE'),
  ];

  static const presetColors = [
    PresetColor(code: 0xFFD97706, name: 'Tiger Orange'),
    PresetColor(code: 0xFF8B0000, name: 'Velvet Burgundy'),
    PresetColor(code: 0xFF0F766E, name: 'Emerald Teal'),
    PresetColor(code: 0xFF7C3AED, name: 'Neon Violet'),
    PresetColor(code: 0xFFB45309, name: 'Brass Gold'),
  ];

  static const priceTiers = [
    PriceTier(
      id: 'tier-30',
      duration: 30,
      price: 500,
      tagline: 'STANDARD COVER',
      valueProp: 'Covers cover charge. Includes 1 complementary speakeasy cocktail.',
    ),
    PriceTier(
      id: 'tier-60',
      duration: 60,
      price: 900,
      tagline: 'SOCIALITE PASS',
      valueProp: 'Most popular! Perfect for cocktails & early DJ set access.',
      popular: true,
    ),
    PriceTier(
      id: 'tier-90',
      duration: 90,
      price: 1350,
      tagline: 'EMPEROR TIGER',
      valueProp: 'VIP table lounge reservation. Secret room access + double points rate.',
    ),
  ];

  static const timePackages = [
    TimePackage(
      id: 'time-30',
      minutes: 30,
      label: '30 MIN',
      tagline: 'Quick top-up for one more round',
    ),
    TimePackage(
      id: 'time-60',
      minutes: 60,
      label: '60 MIN',
      tagline: 'Most popular — keeps the night going',
      popular: true,
    ),
    TimePackage(
      id: 'time-90',
      minutes: 90,
      label: '90 MIN',
      tagline: 'Extended lounge access',
    ),
    TimePackage(
      id: 'time-120',
      minutes: 120,
      label: '120 MIN',
      tagline: 'Emperor reserve — maximum runway',
    ),
  ];

  static const drinks = [
    Drink(
      id: 'drink-1',
      name: "Tiger's Eye Old Fashioned",
      category: DrinkCategory.spirits,
      description:
          'Single-barrel bourbon infused with local toasted pandan leaves, aromatic bitters, wild orange oil, and a hand-carved ice sphere.',
      price: '₱480',
      flavor: 'Rich, Toasty, Citrusy',
      abv: '18% ABV',
      badge: 'Signature',
      ingredients: [
        'Pandan-infused Bourbon',
        'Angostura Bitters',
        'Orange Oil Blend',
        'Dehydrated Orange Wheel',
        'Clear Ice Sphere',
      ],
      bartenderQuote: '"Watch the gold leaf catch the light. Sip slow, let the smoke settle."',
      imageColorStart: 0xFFD97706,
      imageColorEnd: 0xFF78350F,
      timeCostSeconds: 900,
    ),
    Drink(
      id: 'drink-2',
      name: 'Manila Dusk Sour',
      category: DrinkCategory.spirits,
      description:
          'Premium Lambanog combined with fresh calamansi juice, butterfly pea flower syrup, wild forest honey, and egg white foam.',
      price: '₱450',
      flavor: 'Earthy, Sweet & Sour',
      abv: '14% ABV',
      badge: 'Local Favorite',
      ingredients: [
        'Premium Lambanog',
        'Fresh Calamansi',
        'Butterfly Pea Extract',
        'Wild Forest Honey',
        'Silky Foam topping',
      ],
      bartenderQuote: '"Like a Manila sunset, it shifts from deep purple to sunset amber as you sip."',
      imageColorStart: 0xFF9333EA,
      imageColorEnd: 0xFF78350F,
      timeCostSeconds: 720,
    ),
    Drink(
      id: 'drink-3',
      name: 'The Velvet Midnight',
      category: DrinkCategory.spirits,
      description:
          'Spiced dark rum mixed with cold brew coffee, local tablea cacao reduction, cardamom pods, and toasted salted coconut flakes.',
      price: '₱520',
      flavor: 'Bold, Bitter-sweet, Spiced',
      abv: '15% ABV',
      badge: "Bartender's Choice",
      ingredients: [
        'Spiced Dark Rum',
        'Cold Brew Coffee Liqueur',
        'Tablea Chocolate Syrup',
        'Cardamom Essence',
        'Toasted Coconut flakes',
      ],
      bartenderQuote: '"For those who find their rhythm only after the acoustic guitar fades."',
      imageColorStart: 0xFF1A0A0A,
      imageColorEnd: 0xFF4D0000,
      timeCostSeconds: 600,
    ),
    Drink(
      id: 'drink-4',
      name: 'Jazz Age Highball',
      category: DrinkCategory.spirits,
      description:
          'Blended Japanese whiskey, clear carbonated jasmine green tea, fresh ginger root infusion, and a tall block of crystal-clear ice.',
      price: '₱380',
      flavor: 'Crisp, Effervescent, Herbaceous',
      abv: '11% ABV',
      ingredients: [
        'Suntory Toki Whiskey',
        'Jasmine Green Tea Soda',
        'Fresh Ginger Extract',
        'Lemon Zest Twist',
      ],
      bartenderQuote: '"Clean, light, and sharp enough to keep your mind active for the vinyl DJ set."',
      imageColorStart: 0xFFC5A059,
      imageColorEnd: 0xFF2A2000,
      timeCostSeconds: 480,
    ),
    Drink(
      id: 'drink-5',
      name: 'San Miguel Tiger Draft',
      category: DrinkCategory.beer,
      description:
          'An exclusive draft lager crafted specifically for The Blind Tiger. Crisp, served sub-zero in an amber stoneware stein.',
      price: '₱200',
      flavor: 'Crisp, Refreshing, Malt-forward',
      abv: '5.0% ABV',
      badge: 'Microclub Volume',
      ingredients: [
        'Local Premium Malt',
        'Centennial Hops',
        'Filtered Spring Water',
        'Tiger Oak Infusion',
      ],
      bartenderQuote: '"Pouring continuously from midnight till the closing bell."',
      imageColorStart: 0xFFCA8A04,
      imageColorEnd: 0xFF78350F,
      timeCostSeconds: 300,
    ),
  ];

  static List<Challenge> initialChallenges() => [
        Challenge(
          id: 'chal-1',
          title: 'Secret Door Access',
          icon: 'door',
          targetCount: 1,
          points: 20,
          category: ChallengeCategory.social,
        ),
        Challenge(
          id: 'chal-2',
          title: 'Mixology Tasting',
          icon: 'drink',
          targetCount: 2,
          points: 25,
          category: ChallengeCategory.drink,
        ),
        Challenge(
          id: 'chal-3',
          title: 'Spin the Vinyl',
          icon: 'game',
          targetCount: 1,
          points: 15,
          category: ChallengeCategory.game,
        ),
        Challenge(
          id: 'chal-4',
          title: 'Toast 2 Strangers',
          icon: 'social',
          targetCount: 2,
          points: 30,
          category: ChallengeCategory.social,
        ),
        Challenge(
          id: 'chal-5',
          title: 'Win a Duo Beat',
          icon: 'game',
          targetCount: 1,
          points: 35,
          category: ChallengeCategory.game,
        ),
        Challenge(
          id: 'chal-6',
          title: 'Tip the House',
          icon: 'drink',
          targetCount: 1,
          points: 20,
          category: ChallengeCategory.social,
        ),
      ];

  static List<FeedEvent> initialFeedEvents() => [
        FeedEvent(
          id: 'event-1',
          avatarSeed: const AvatarSeed(
            hair: 'TF',
            eyes: 'SV',
            accessory: 'GP',
            color: 0xFFD97706,
          ),
          userName: 'ManilaMogul',
          userRank: '#1',
          isFriend: true,
          timeAgo: '2m ago',
          eventText: "just ordered a Tiger's Eye Old Fashioned at the Main Bar!",
          likes: {'luxe': 12, 'salute': 5, 'gold': 4},
        ),
        FeedEvent(
          id: 'event-2',
          avatarSeed: const AvatarSeed(
            hair: 'MS',
            eyes: 'IM',
            accessory: 'CC',
            color: 0xFF8B0000,
          ),
          userName: 'JazzSasha_9',
          userRank: '#4',
          isFriend: false,
          timeAgo: '5m ago',
          eventText: 'unlocked the Elite Socialite status badge in Speakeasy Mode.',
          likes: {'luxe': 4, 'salute': 15, 'gold': 11},
        ),
        FeedEvent(
          id: 'event-3',
          avatarSeed: const AvatarSeed(
            hair: 'JW',
            eyes: 'CE',
            accessory: 'PE',
            color: 0xFF0F766E,
          ),
          userName: 'DiscoDiva',
          userRank: '#5',
          isFriend: true,
          timeAgo: '8m ago',
          eventText:
              'ordered a round of Manila Dusk Sours! The table transition is heating up.',
          likes: {'luxe': 18, 'salute': 2, 'gold': 8},
        ),
      ];

  static List<LeaderboardUser> initialLeaderboard() => [
        LeaderboardUser(
          rank: 1,
          name: 'TigerSovereign',
          points: 420,
          tier: MemberTier.vvip,
          avatarColor: 0xFF7C3AED,
          avatarGlyph: 'VV',
          timeBalance: 400 * 3600,
        ),
        LeaderboardUser(
          rank: 2,
          name: 'ManilaMogul',
          points: 310,
          tier: MemberTier.platinum,
          avatarColor: 0xFFD97706,
          avatarGlyph: 'BT1',
          timeBalance: 21600,
        ),
        LeaderboardUser(
          rank: 2,
          name: 'Tetsuo_V',
          points: 240,
          tier: MemberTier.platinum,
          avatarColor: 0xFF7C3AED,
          avatarGlyph: 'BT2',
          timeBalance: 14400,
        ),
        LeaderboardUser(
          rank: 3,
          name: 'JazzSasha_9',
          points: 195,
          tier: MemberTier.gold,
          avatarColor: 0xFF8B0000,
          avatarGlyph: 'BT3',
          timeBalance: 10800,
        ),
        LeaderboardUser(
          rank: 4,
          name: 'Suki_Tiger',
          points: 180,
          tier: MemberTier.gold,
          avatarColor: 0xFFB45309,
          avatarGlyph: 'BT4',
          timeBalance: 7200,
        ),
        LeaderboardUser(
          rank: 5,
          name: 'DiscoDiva',
          points: 165,
          tier: MemberTier.gold,
          avatarColor: 0xFF0F766E,
          avatarGlyph: 'BT5',
          timeBalance: 5400,
        ),
        LeaderboardUser(
          rank: 6,
          name: 'Kusanagi_M',
          points: 145,
          tier: MemberTier.silver,
          avatarColor: 0xFFD97706,
          avatarGlyph: 'BT6',
          timeBalance: 4500,
        ),
        LeaderboardUser(
          rank: 7,
          name: 'You (Socialite)',
          points: 108,
          tier: MemberTier.silver,
          isCurrentUser: true,
          avatarColor: 0xFF8B0000,
          avatarGlyph: 'U1',
          timeBalance: 3600,
        ),
        LeaderboardUser(
          rank: 8,
          name: 'Vince_Beat',
          points: 95,
          tier: MemberTier.silver,
          avatarColor: 0xFF7C3AED,
          avatarGlyph: 'BT8',
          timeBalance: 2700,
        ),
        LeaderboardUser(
          rank: 9,
          name: 'ChronoSam',
          points: 80,
          tier: MemberTier.bronze,
          avatarColor: 0xFFB45309,
          avatarGlyph: 'BT9',
          timeBalance: 1800,
        ),
        LeaderboardUser(
          rank: 10,
          name: 'LoungeQueen',
          points: 60,
          tier: MemberTier.bronze,
          avatarColor: 0xFF555555,
          avatarGlyph: 'BT0',
          timeBalance: 900,
        ),
      ];

  static const miniGames = [
    MiniGame(
      id: 'game-1',
      title: 'Spin the Vinyl',
      description:
          'Bet some Reservation minutes. Spin the retro vinyl turntable to align beats and score point multipliers!',
      points: 15,
      icon: 'roulette',
    ),
    MiniGame(
      id: 'game-2',
      title: 'Mixology Secret',
      description:
          "Listen to the bartender's recipe clues and try to guess the hidden signature cocktail!",
      points: 20,
      icon: 'guess',
    ),
    MiniGame(
      id: 'game-3',
      title: 'Beat Synchronizer',
      description:
          'Tap in perfect rhythm with the flashing neon lights to gain maximum style points!',
      points: 25,
      icon: 'shot',
    ),
    MiniGame(
      id: 'game-4',
      title: 'High-Deck Card',
      description:
          'Draw a vintage card from the Blind Tiger deck to win entry passes and table credits.',
      points: 10,
      icon: 'card',
    ),
    MiniGame(
      id: 'game-5',
      title: 'Cipher Passcode',
      description: 'Solve the rotary padlock puzzle to unlock the VIP cellar lounge.',
      points: 15,
      icon: 'cipher',
    ),
    MiniGame(
      id: 'game-6',
      title: "The Director's Safe",
      description: 'Locked cabinet holding high-value complimentary bottle service tickets.',
      points: 100,
      icon: 'mystery',
      locked: true,
      lockRequirement: 'Reach 150+ points tonight',
    ),
  ];

  static const clubBranches = [
    ClubBranch(
      id: 'bgc',
      name: 'BGC Secret Cellar',
      city: 'Taguig',
      icon: '🍷',
      ambience: 'Intimate Leather & Velvet',
    ),
    ClubBranch(
      id: 'poblacion',
      name: 'Poblacion Velvet Room',
      city: 'Makati',
      icon: '🎷',
      ambience: 'Retro Vinyl & Dim Amber',
    ),
    ClubBranch(
      id: 'glasshouse',
      name: 'Makati Glasshouse',
      city: 'Makati',
      icon: '🌴',
      ambience: 'Imperial Decadent Lounge',
    ),
    ClubBranch(
      id: 'tomas',
      name: 'Tomas Morato Lounge',
      city: 'Quezon City',
      icon: '🥃',
      ambience: 'Acoustic Jazz Hideout',
    ),
  ];
}
