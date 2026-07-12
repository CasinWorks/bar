export interface AvatarConfig {
  hair: string;
  eyes: string;
  accessory: string;
  color: string;
  name: string;
}

export interface PriceTier {
  id: string;
  duration: number; // minutes
  price: number; // e.g. PHP
  tagline: string;
  valueProp: string;
  popular?: boolean;
}

export interface Challenge {
  id: string;
  title: string;
  icon: string;
  targetCount: number;
  currentCount: number;
  points: number;
  claimed: boolean;
  category: 'drink' | 'social' | 'game';
}

export interface FeedEvent {
  id: string;
  avatarSeed: { hair: string; eyes: string; accessory: string; color: string };
  userName: string;
  userRank: string;
  isFriend: boolean;
  timeAgo: string;
  eventText: string;
  likes: { [key: string]: number }; // counts of 🔥, 💯, 🎉
  userReacted?: string; // which reaction did current user pick
}

export interface LeaderboardUser {
  rank: number;
  name: string;
  points: number;
  tier: 'Platinum' | 'Gold' | 'Silver' | 'Bronze';
  isCurrentUser?: boolean;
  avatarColor: string;
  avatarGlyph: string;
  timeBalance?: number; // Time remaining in seconds
}

export interface Drink {
  id: string;
  name: string;
  category: 'Spirits' | 'Wine' | 'Beer' | 'Non-Alc';
  description: string;
  price: string;
  flavor: string;
  abv: string;
  badge?: string;
  ingredients: string[];
  bartenderQuote: string;
  imageColor: string; // color gradient to simulate neon liquid in glassware
}

export interface MiniGame {
  id: string;
  title: string;
  description: string;
  points: number;
  icon: string;
  locked?: boolean;
  lockRequirement?: string;
}
