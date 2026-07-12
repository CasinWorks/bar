import { Drink, Challenge, FeedEvent, LeaderboardUser, PriceTier, MiniGame } from './types';

export const HAIR_OPTIONS = [
  { id: 'hair-1', name: 'Dapper Pompadour', path: 'DP' },
  { id: 'hair-2', name: 'Jazz Age Finger Waves', path: 'JW' },
  { id: 'hair-3', name: 'Modern Slickback', path: 'MS' },
  { id: 'hair-4', name: 'Disheveled Shag', path: 'DS' },
  { id: 'hair-5', name: 'Tiger-Stripe Fedora', path: 'TF' },
];

export const EYES_OPTIONS = [
  { id: 'eyes-1', name: 'Classic Aviators', path: 'CA' },
  { id: 'eyes-2', name: 'Cat-Eye Sunglasses', path: 'CE' },
  { id: 'eyes-3', name: 'Smoky Velvet Eyes', path: 'SV' },
  { id: 'eyes-4', name: 'Intimate Monocle', path: 'IM' },
  { id: 'eyes-5', name: 'Vintage Wayfarers', path: 'VW' },
];

export const ACCESSORY_OPTIONS = [
  { id: 'acc-1', name: 'Gold Tiger Lapel Pin', path: 'GP' },
  { id: 'acc-2', name: 'Retro Velvet Choker', path: 'RC' },
  { id: 'acc-3', name: 'Cuban Cigar', path: 'CC' },
  { id: 'acc-4', name: 'Saxophone Lapel Badge', path: 'SL' },
  { id: 'acc-5', name: 'Pearl Drop Earring', path: 'PE' },
];

export const PRESET_COLORS = [
  { code: '#D97706', name: 'Tiger Orange' },
  { code: '#8B0000', name: 'Velvet Burgundy' },
  { code: '#0F766E', name: 'Emerald Teal' },
  { code: '#7C3AED', name: 'Neon Violet' },
  { code: '#B45309', name: 'Brass Gold' },
];

export const PRICE_TIERS: PriceTier[] = [
  {
    id: 'tier-30',
    duration: 30,
    price: 500,
    tagline: 'STANDARD COVER',
    valueProp: 'Covers cover charge. Includes 1 complementary speakeasy cocktail.',
  },
  {
    id: 'tier-60',
    duration: 60,
    price: 900,
    tagline: 'SOCIALITE PASS',
    valueProp: 'Most popular! Perfect for cocktails & early DJ set access.',
    popular: true,
  },
  {
    id: 'tier-90',
    duration: 90,
    price: 1350,
    tagline: 'EMPEROR TIGER',
    valueProp: 'VIP table lounge reservation. Secret room access + double points rate.',
  },
];

export const INITIAL_DRINKS: Drink[] = [
  {
    id: 'drink-1',
    name: "Tiger’s Eye Old Fashioned",
    category: 'Spirits',
    description: 'Single-barrel bourbon infused with local toasted pandan leaves, aromatic bitters, a splash of wild orange oil, and a hand-carved ice sphere.',
    price: '₱480',
    flavor: 'Rich, Toasty, Citrusy',
    abv: '18% ABV',
    badge: 'Signature',
    ingredients: ['Pandan-infused Bourbon', 'Angostura Bitters', 'Orange Oil Blend', 'Dehydrated Orange Wheel', 'Clear Ice Sphere'],
    bartenderQuote: '“Watch the gold leaf catch the light. Sip slow, let the smoke settle.”',
    imageColor: 'from-amber-600 to-amber-950',
  },
  {
    id: 'drink-2',
    name: 'Manila Dusk Sour',
    category: 'Spirits',
    description: 'Premium Lambanog (coconut sap spirit) combined with fresh calamansi juice, organic butterfly pea flower syrup, wild forest honey, and egg white foam.',
    price: '₱450',
    flavor: 'Earthy, Sweet & Sour',
    abv: '14% ABV',
    badge: 'Local Favorite',
    ingredients: ['Premium Lambanog', 'Fresh Calamansi', 'Butterfly Pea Extract', 'Wild Forest Honey', 'Silky Foam topping'],
    bartenderQuote: '“Like a Manila sunset, it shifts from deep purple to sunset amber as you sip.”',
    imageColor: 'from-purple-600 to-amber-900',
  },
  {
    id: 'drink-3',
    name: 'The Velvet Midnight',
    category: 'Spirits',
    description: 'Spiced dark rum mixed with cold brew coffee, local tablea cacao reduction, cardamom pods, and a rim of toasted salted coconut flakes.',
    price: '₱520',
    flavor: 'Bold, Bitter-sweet, Spiced',
    abv: '15% ABV',
    badge: 'Bartender’s Choice',
    ingredients: ['Spiced Dark Rum', 'Cold Brew Coffee Liqueur', 'Tablea Chocolate Syrup', 'Cardamom Essence', 'Toasted Coconut flakes'],
    bartenderQuote: '“For those who find their rhythm only after the acoustic guitar fades.”',
    imageColor: 'from-[#1A0A0A] to-[#4D0000]',
  },
  {
    id: 'drink-4',
    name: 'Jazz Age Highball',
    category: 'Spirits',
    description: 'Blended Japanese whiskey, clear carbonated jasmine green tea, fresh ginger root infusion, and a single tall block of crystal-clear ice.',
    price: '₱380',
    flavor: 'Crisp, Effervescent, Herbaceous',
    abv: '11% ABV',
    ingredients: ['Suntory Toki Whiskey', 'Jasmine Green Tea Soda', 'Fresh Ginger Extract', 'Lemon Zest Twist'],
    bartenderQuote: '“Clean, light, and sharp enough to keep your mind active for the vinyl DJ set.”',
    imageColor: 'from-[#C5A059] to-[#2A2000]',
  },
  {
    id: 'drink-5',
    name: 'San Miguel Tiger Draft',
    category: 'Beer',
    description: 'An exclusive draft lager crafted specifically for The Blind Tiger. Crisp, served sub-zero in an amber stoneware stein.',
    price: '₱200',
    flavor: 'Crisp, Refreshing, Malt-forward',
    abv: '5.0% ABV',
    badge: 'Microclub Volume',
    ingredients: ['Local Premium Malt', 'Centennial Hops', 'Filtered Spring Water', 'Tiger Oak Infusion'],
    bartenderQuote: '“Pouring continuously from midnight till the closing bell.”',
    imageColor: 'from-yellow-600 to-amber-950',
  },
];

export const INITIAL_CHALLENGES: Challenge[] = [
  {
    id: 'chal-1',
    title: 'Secret Door Access',
    icon: 'door',
    targetCount: 1,
    currentCount: 0,
    points: 20,
    claimed: false,
    category: 'social',
  },
  {
    id: 'chal-2',
    title: 'Mixology Tasting',
    icon: 'drink',
    targetCount: 2,
    currentCount: 0,
    points: 25,
    claimed: false,
    category: 'drink',
  },
  {
    id: 'chal-3',
    title: 'Spin the Vinyl',
    icon: 'game',
    targetCount: 1,
    currentCount: 0,
    points: 15,
    claimed: false,
    category: 'game',
  },
  {
    id: 'chal-4',
    title: 'Elite Socialite',
    icon: 'social',
    targetCount: 3,
    currentCount: 0,
    points: 30,
    claimed: false,
    category: 'social',
  },
];

export const INITIAL_FEED_EVENTS: FeedEvent[] = [
  {
    id: 'event-1',
    avatarSeed: { hair: 'TF', eyes: 'SV', accessory: 'GP', color: '#D97706' },
    userName: 'ManilaMogul',
    userRank: '#1',
    isFriend: true,
    timeAgo: '2m ago',
    eventText: "just ordered a Tiger’s Eye Old Fashioned at the Main Bar!",
    likes: { luxe: 12, salute: 5, gold: 4 },
  },
  {
    id: 'event-2',
    avatarSeed: { hair: 'MS', eyes: 'IM', accessory: 'CC', color: '#8B0000' },
    userName: 'JazzSasha_9',
    userRank: '#4',
    isFriend: false,
    timeAgo: '5m ago',
    eventText: 'unlocked the Elite Socialite status badge in Speakeasy Mode.',
    likes: { luxe: 4, salute: 15, gold: 11 },
  },
  {
    id: 'event-3',
    avatarSeed: { hair: 'JW', eyes: 'CE', accessory: 'PE', color: '#0F766E' },
    userName: 'DiscoDiva',
    userRank: '#5',
    isFriend: true,
    timeAgo: '8m ago',
    eventText: 'ordered a round of Manila Dusk Sours! The table transition is heating up.',
    likes: { luxe: 18, salute: 2, gold: 8 },
  },
];

export const INITIAL_LEADERBOARD: LeaderboardUser[] = [
  { rank: 1, name: 'ManilaMogul', points: 310, tier: 'Platinum', avatarColor: '#D97706', avatarGlyph: 'BT1', timeBalance: 21600 },
  { rank: 2, name: 'Tetsuo_V', points: 240, tier: 'Platinum', avatarColor: '#7C3AED', avatarGlyph: 'BT2', timeBalance: 14400 },
  { rank: 3, name: 'JazzSasha_9', points: 195, tier: 'Gold', avatarColor: '#8B0000', avatarGlyph: 'BT3', timeBalance: 10800 },
  { rank: 4, name: 'Suki_Tiger', points: 180, tier: 'Gold', avatarColor: '#B45309', avatarGlyph: 'BT4', timeBalance: 7200 },
  { rank: 5, name: 'DiscoDiva', points: 165, tier: 'Gold', avatarColor: '#0F766E', avatarGlyph: 'BT5', timeBalance: 5400 },
  { rank: 6, name: 'Kusanagi_M', points: 145, tier: 'Silver', avatarColor: '#D97706', avatarGlyph: 'BT6', timeBalance: 4500 },
  { rank: 7, name: 'You (Socialite)', points: 108, tier: 'Silver', isCurrentUser: true, avatarColor: '#8B0000', avatarGlyph: 'U1', timeBalance: 3600 },
  { rank: 8, name: 'Vince_Beat', points: 95, tier: 'Silver', avatarColor: '#7C3AED', avatarGlyph: 'BT8', timeBalance: 2700 },
  { rank: 9, name: 'ChronoSam', points: 80, tier: 'Bronze', avatarColor: '#B45309', avatarGlyph: 'BT9', timeBalance: 1800 },
  { rank: 10, name: 'LoungeQueen', points: 60, tier: 'Bronze', avatarColor: '#555555', avatarGlyph: 'BT0', timeBalance: 900 },
];

export const MINI_GAMES_LIST: MiniGame[] = [
  {
    id: 'game-1',
    title: 'Spin the Vinyl',
    description: 'Bet some Reservation minutes. Spin the retro vinyl turntable to align beats and score point multipliers!',
    points: 15,
    icon: 'roulette',
  },
  {
    id: 'game-2',
    title: 'Mixology Secret',
    description: 'Listen to the bartender’s recipe clues and try to guess the hidden signature cocktail!',
    points: 20,
    icon: 'guess',
  },
  {
    id: 'game-3',
    title: 'Beat Synchronizer',
    description: 'Tap in perfect rhythm with the flashing neon lights to gain maximum style points!',
    points: 25,
    icon: 'shot',
  },
  {
    id: 'game-4',
    title: 'High-Deck Card',
    description: 'Draw a vintage card from the Blind Tiger deck to win entry passes and table credits.',
    points: 10,
    icon: 'card',
  },
  {
    id: 'game-5',
    title: 'Cipher Passcode',
    description: 'Solve the rotary rotary padlock puzzle to unlock the VIP cellar lounge.',
    points: 15,
    icon: 'cipher',
  },
  {
    id: 'game-6',
    title: 'The Director’s Safe',
    description: 'Locked cabinet holding high-value complimentary bottle service tickets.',
    points: 100,
    icon: 'mystery',
    locked: true,
    lockRequirement: 'Reach 150+ points tonight',
  },
];
