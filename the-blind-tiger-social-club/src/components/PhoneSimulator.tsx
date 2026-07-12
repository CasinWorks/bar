import React, { useState, useEffect, useRef } from 'react';
import { 
  Play, Pause, QrCode, Shield, Sparkles, ChevronRight, User, RefreshCw, Check, 
  Clock, Share2, Award, Zap, Heart, Flame, Users, Grid, Trophy, 
  Compass, Plus, HelpCircle, AlertTriangle, Send, X, Star, CreditCard, Music
} from 'lucide-react';
import { AvatarConfig, PriceTier, Challenge, FeedEvent, LeaderboardUser, Drink, MiniGame } from '../types';
import { 
  HAIR_OPTIONS, EYES_OPTIONS, ACCESSORY_OPTIONS, PRESET_COLORS, 
  PRICE_TIERS, INITIAL_DRINKS, INITIAL_CHALLENGES, INITIAL_FEED_EVENTS, 
  INITIAL_LEADERBOARD, MINI_GAMES_LIST 
} from '../mockData';

interface PhoneSimulatorProps {
  currentScreen: 'onboarding' | 'avatar' | 'pricing' | 'checkout' | 'active' | 'summary';
  setScreen: (screen: 'onboarding' | 'avatar' | 'pricing' | 'checkout' | 'active' | 'summary') => void;
  timeRemaining: number; // in seconds
  setTimeRemaining: React.Dispatch<React.SetStateAction<number>>;
  timeSpeed: number; // multiplier
  points: number;
  setPoints: React.Dispatch<React.SetStateAction<number>>;
  drinksOrdered: number;
  setDrinksOrdered: (count: number) => void;
  challenges: Challenge[];
  setChallenges: React.Dispatch<React.SetStateAction<Challenge[]>>;
  feedEvents: FeedEvent[];
  setFeedEvents: React.Dispatch<React.SetStateAction<FeedEvent[]>>;
  leaderboard: LeaderboardUser[];
  setLeaderboard: React.Dispatch<React.SetStateAction<LeaderboardUser[]>>;
  avatar: AvatarConfig;
  setAvatar: (avatar: AvatarConfig) => void;
  selectedTier: PriceTier;
  setSelectedTier: (tier: PriceTier) => void;
  triggerPointsToast: (amount: number, reason: string) => void;
  isCheckedIn: boolean;
  setIsCheckedIn: (checked: boolean) => void;
  currentBranch: string;
  setCurrentBranch: (branch: string) => void;
  currentHour: number;
  setCurrentHour: (hour: number) => void;
}

const renderIcon = (iconKey: string, isMidnight: boolean) => {
  const accentColor = isMidnight ? 'text-purple-400' : 'text-amber-500';
  switch (iconKey) {
    case 'drink':
      return <Sparkles className={`w-4 h-4 ${accentColor}`} />;
    case 'social':
      return <Users className="w-4 h-4 text-emerald-400" />;
    case 'game':
      return <Trophy className="w-4 h-4 text-amber-400" />;
    case 'explore':
      return <Flame className="w-4 h-4 text-rose-500" />;
    case 'roulette':
      return <Music className={`w-5 h-5 ${accentColor} animate-pulse`} />;
    case 'guess':
      return <HelpCircle className="w-5 h-5 text-emerald-400" />;
    case 'shot':
      return <Zap className="w-5 h-5 text-amber-500 animate-pulse" />;
    case 'card':
      return <Grid className="w-5 h-5 text-purple-400" />;
    case 'cipher':
      return <Sparkles className="w-5 h-5 text-emerald-400" />;
    case 'mystery':
      return <Award className="w-5 h-5 text-amber-400" />;
    default:
      return <Sparkles className={`w-4 h-4 ${accentColor}`} />;
  }
};

const getDrinkTimeCostSeconds = (drink: Drink): number => {
  switch (drink.id) {
    case 'drink-1': return 900; // 15 mins (Tiger's Eye)
    case 'drink-2': return 720; // 12 mins (Manila Dusk)
    case 'drink-3': return 600; // 10 mins (Velvet Midnight)
    case 'drink-4': return 480; // 8 mins (Jazz Age)
    case 'drink-5': return 300; // 5 mins (San Miguel)
    default: return 300;
  }
};

const formatSecondsToMins = (secs: number): string => {
  const m = Math.floor(secs / 60);
  return `${m} MINS`;
};

export default function PhoneSimulator({
  currentScreen,
  setScreen,
  timeRemaining,
  setTimeRemaining,
  timeSpeed,
  points,
  setPoints,
  drinksOrdered,
  setDrinksOrdered,
  challenges,
  setChallenges,
  feedEvents,
  setFeedEvents,
  leaderboard,
  setLeaderboard,
  avatar,
  setAvatar,
  selectedTier,
  setSelectedTier,
  triggerPointsToast,
  isCheckedIn,
  setIsCheckedIn,
  currentBranch,
  setCurrentBranch,
  currentHour,
  setCurrentHour,
}: PhoneSimulatorProps) {

  const [selectedDevice, setSelectedDevice] = useState<'phone' | 'apple' | 'android'>('phone');
  const [activeTab, setActiveTab] = useState<'games' | 'challenges' | 'social' | 'menu' | 'leaderboard'>('challenges');
  const [selectedPayment, setSelectedPayment] = useState<'visa' | 'gcash' | 'paymaya'>('gcash');
  const [avatarForm, setAvatarForm] = useState<AvatarConfig>(avatar);
  const [avatarTab, setAvatarTab] = useState<'hair' | 'eyes' | 'accessories'>('hair');
  const [showQrModal, setShowQrModal] = useState(false);
  const [selectedDrink, setSelectedDrink] = useState<Drink | null>(null);
  const [menuFilter, setMenuFilter] = useState<'All' | 'Spirits' | 'Wine' | 'Beer' | 'Non-Alc'>('All');
  
  // Mystery Password/Door Knock State
  const [passwordInput, setPasswordInput] = useState('');
  const [doorKnocks, setDoorKnocks] = useState(0);
  const [doorStatus, setDoorStatus] = useState<'locked' | 'unlocked' | 'wrong'>('locked');

  // Branch management
  const [showBranchSelector, setShowBranchSelector] = useState(false);
  const [showPausedOverlay, setShowPausedOverlay] = useState(false);
  const [watchQrOpen, setWatchQrOpen] = useState(false);

  const CLUB_BRANCHES = [
    { id: 'bgc', name: 'BGC Secret Cellar', city: 'Taguig', icon: '🍷', ambience: 'Intimate Leather & Velvet' },
    { id: 'poblacion', name: 'Poblacion Velvet Room', city: 'Makati', icon: '🎷', ambience: 'Retro Vinyl & Dim Amber' },
    { id: 'glasshouse', name: 'Makati Glasshouse', city: 'Makati', icon: '🌴', ambience: 'Imperial Decadent Lounge' },
    { id: 'tomas', name: 'Tomas Morato Lounge', city: 'Quezon City', icon: '🥃', ambience: 'Acoustic Jazz Hideout' }
  ];
  
  // Mini-game active modal
  const [activeGame, setActiveGame] = useState<MiniGame | null>(null);
  const [rouletteSpinning, setRouletteSpinning] = useState(false);
  const [rouletteResult, setRouletteResult] = useState<string | null>(null);
  const [guessInput, setGuessInput] = useState('');
  const [guessResult, setGuessResult] = useState<'correct' | 'wrong' | null>(null);
  const [shotTimerActive, setShotTimerActive] = useState(false);
  const [shotScore, setShotScore] = useState<number | null>(null);

  useEffect(() => {
    setAvatarForm(avatar);
  }, [avatar]);

  const isMidnight = currentHour >= 12;

  // Handle drink order action
  const handleOrderDrink = (drink: Drink) => {
    const timeCost = getDrinkTimeCostSeconds(drink);
    if (timeRemaining < timeCost) {
      triggerPointsToast(0, 'Your Reservation is too short! Buy more hours.');
      return;
    }

    setTimeRemaining(prev => Math.max(0, prev - timeCost));
    setDrinksOrdered(drinksOrdered + 1);
    
    // Progress drink challenges
    const updatedChallenges = challenges.map(chal => {
      if (chal.category === 'drink' && !chal.claimed) {
        const nextCount = Math.min(chal.targetCount, chal.currentCount + 1);
        return { ...chal, currentCount: nextCount };
      }
      return chal;
    });
    setChallenges(updatedChallenges);

    // Feed Event Inject
    const newEvent: FeedEvent = {
      id: `event-order-${Date.now()}`,
      avatarSeed: { hair: avatarForm.hair, eyes: avatarForm.eyes, accessory: avatarForm.accessory, color: avatarForm.color },
      userName: avatarForm.name || 'Anonymous',
      userRank: '#7',
      isFriend: false,
      timeAgo: 'Just now',
      eventText: `ordered a signature ${drink.name}! (${formatSecondsToMins(timeCost)} redeemed)`,
      likes: { luxe: 0, salute: 0, gold: 0 },
    };
    setFeedEvents([newEvent, ...feedEvents]);

    triggerPointsToast(10, `Ordered ${drink.name}! (-${formatSecondsToMins(timeCost)})`);
    setPoints(prev => prev + 10);
    setSelectedDrink(null);
  };

  // Claim Challenge rewards
  const handleClaimChallenge = (challengeId: string, pointsReward: number) => {
    setChallenges(prev => prev.map(chal => {
      if (chal.id === challengeId) {
        return { ...chal, claimed: true };
      }
      return chal;
    }));

    setPoints(prev => prev + pointsReward);
    triggerPointsToast(pointsReward, 'Exclusive Reward Unlocked!');
  };

  // Live feed reactions
  const handleReactFeed = (eventId: string, reaction: 'luxe' | 'salute' | 'gold') => {
    setFeedEvents(prev => prev.map(evt => {
      if (evt.id === eventId) {
        const currentLikes = { ...evt.likes };
        
        if (evt.userReacted === reaction) {
          currentLikes[reaction] = Math.max(0, currentLikes[reaction] - 1);
          return { ...evt, likes: currentLikes, userReacted: undefined };
        } else {
          currentLikes[reaction] = (currentLikes[reaction] || 0) + 1;
          if (evt.userReacted) {
            const prevReact = evt.userReacted as 'luxe' | 'salute' | 'gold';
            currentLikes[prevReact] = Math.max(0, currentLikes[prevReact] - 1);
          }
          return { ...evt, likes: currentLikes, userReacted: reaction };
        }
      }
      return evt;
    }));

    setPoints(prev => prev + 2);
    
    // Update Elite Socialite Challenge count
    setChallenges(prev => prev.map(chal => {
      if (chal.id === 'chal-4' && !chal.claimed) {
        return { ...chal, currentCount: Math.min(chal.targetCount, chal.currentCount + 1) };
      }
      return chal;
    }));
  };

  // Mini-game triggers
  const handlePlayGame = (game: MiniGame) => {
    if (game.locked && points < 150) return;
    if (!isCheckedIn) {
      setShowPausedOverlay(true);
      return;
    }
    setActiveGame(game);
    setRouletteResult(null);
    setGuessResult(null);
    setGuessInput('');
    setShotScore(null);
  };

  const spinTurntable = () => {
    if (rouletteSpinning) return;
    setRouletteSpinning(true);
    setRouletteResult(null);

    setTimeout(() => {
      setRouletteSpinning(false);
      const options = [
        { text: 'JACKPOT ALIGNED: +40 Points! 👑', points: 40 },
        { text: 'Chrono Boost: +10 Minutes! ⏳', points: 10, timeBonus: 600 },
        { text: 'Disco Scratch: +15 Points!', points: 15 },
        { text: 'House Rhythm: +25 Points!', points: 25 },
        { text: 'Off-beat: 0 points, but solid groove!', points: 0 }
      ];
      const selected = options[Math.floor(Math.random() * options.length)];
      setRouletteResult(selected.text);
      
      if (selected.points > 0) {
        setPoints(p => p + selected.points);
        triggerPointsToast(selected.points, 'Turntable Scratch Combo!');
      }
      if (selected.timeBonus) {
        setTimeRemaining(t => t + selected.timeBonus);
      }

      // Progress Game Challenge
      setChallenges(prev => prev.map(chal => {
        if (chal.id === 'chal-3' && !chal.claimed) {
          return { ...chal, currentCount: Math.min(chal.targetCount, chal.currentCount + 1) };
        }
        return chal;
      }));
    }, 2000);
  };

  const handleGuessSubmit = () => {
    const answer = guessInput.trim().toLowerCase();
    const correctAnswers = ["tiger's eye", 'tiger eye', 'old fashioned', 'tigers eye'];
    
    if (correctAnswers.some(ans => answer.includes(ans))) {
      setGuessResult('correct');
      setPoints(p => p + 25);
      triggerPointsToast(25, 'Recipe Unlocked!');
      
      setChallenges(prev => prev.map(chal => {
        if (chal.id === 'chal-3' && !chal.claimed) {
          return { ...chal, currentCount: Math.min(chal.targetCount, chal.currentCount + 1) };
        }
        return chal;
      }));
    } else {
      setGuessResult('wrong');
    }
  };

  const playShotChallenge = () => {
    if (shotTimerActive) return;
    setShotTimerActive(true);
    setShotScore(null);

    setTimeout(() => {
      setShotTimerActive(false);
      const score = Math.floor(Math.random() * 35) + 65; // 65-100%
      setShotScore(score);
      const pts = Math.floor(score / 3.5);
      setPoints(p => p + pts);
      triggerPointsToast(pts, `Grid Timing Sync: ${score}%`);

      setChallenges(prev => prev.map(chal => {
        if (chal.id === 'chal-3' && !chal.claimed) {
          return { ...chal, currentCount: Math.min(chal.targetCount, chal.currentCount + 1) };
        }
        return chal;
      }));
    }, 1200);
  };

  // Password Unlock Gate check
  const handlePasswordUnlock = () => {
    const pwd = passwordInput.trim().toUpperCase();
    if (pwd === 'TIGER' || pwd === 'BLIND TIGER') {
      setDoorStatus('unlocked');
      triggerPointsToast(15, 'Password Accepted! Door slides open.');
      setTimeout(() => {
        setScreen('avatar');
      }, 1200);
    } else {
      setDoorStatus('wrong');
      triggerPointsToast(0, 'Wrong Code. The peep-hole slides closed.');
    }
  };

  // Simulating Secret Knock knock
  const handleSecretKnock = () => {
    const nextKnocks = doorKnocks + 1;
    setDoorKnocks(nextKnocks);
    triggerPointsToast(0, `Knocked ${nextKnocks} time${nextKnocks > 1 ? 's' : ''}...`);

    if (nextKnocks === 3) {
      setDoorStatus('unlocked');
      triggerPointsToast(20, 'Unmarked Door Slides Open!');
      
      // Progress first challenge directly
      setChallenges(prev => prev.map(chal => {
        if (chal.id === 'chal-1') {
          return { ...chal, currentCount: 1 };
        }
        return chal;
      }));

      setTimeout(() => {
        setScreen('avatar');
      }, 1200);
    }
  };

  // MM:SS countdown format
  const formatTime = (totalSeconds: number) => {
    const m = Math.floor(totalSeconds / 60);
    const s = Math.floor(totalSeconds % 60);
    const ms = Math.floor(Math.random() * 99); 
    return {
      minutes: String(m).padStart(2, '0'),
      seconds: String(s).padStart(2, '0'),
      milliseconds: String(ms).padStart(2, '0')
    };
  };

  const { minutes, seconds, milliseconds } = formatTime(timeRemaining);

  // Time Alert indicators
  let timerColor = 'text-amber-500';
  let timerBg = 'bg-amber-950/10';
  let timerBorder = 'border-[#C5A059]/40';
  let timerGlow = 'shadow-[0_0_12px_rgba(217,119,6,0.15)]';
  let timerLabel = 'RESERVATION COUNTDOWN';

  if (!isCheckedIn) {
    timerColor = 'text-neutral-400';
    timerBg = 'bg-neutral-900/40';
    timerBorder = 'border-neutral-800';
    timerGlow = '';
    timerLabel = 'HOURS PRESERVED (FROZEN)';
  } else if (timeRemaining <= 300) { 
    timerColor = 'text-red-500';
    timerBg = 'bg-red-950/30';
    timerBorder = 'border-red-900/60';
    timerGlow = 'animate-pulse shadow-[0_0_20px_rgba(220,38,38,0.5)]';
    timerLabel = 'MEMBERSHIP EXPIRING ALARM 🚨';
  } else if (timeRemaining <= 900) { 
    timerColor = 'text-orange-500';
    timerBg = 'bg-orange-950/10';
    timerBorder = 'border-orange-500/30';
    timerGlow = 'animate-pulse shadow-[0_0_12px_rgba(249,115,22,0.35)]';
    timerLabel = 'RESERVATION RUNNING THIN';
  }

  // Filter Drinks Menu
  const filteredDrinks = INITIAL_DRINKS.filter(
    drink => menuFilter === 'All' || drink.category === menuFilter
  );

  // WATCH RENDERERS
  const renderAppleWatch = () => {
    const hrs = String(Math.floor(timeRemaining / 3600)).padStart(2, '0');
    const mins = String(Math.floor((timeRemaining % 3600) / 60)).padStart(2, '0');
    const secs = String(timeRemaining % 60).padStart(2, '0');

    let zoneTitle = isMidnight ? "TIGER DISCO DOCK" : "VINTAGE COUCH ZONE";
    let zoneCode = isMidnight ? "D2" : "S1";
    let zoneColorClass = isMidnight ? "text-purple-400 border-purple-500/30 bg-purple-500/5" : "text-amber-500 border-amber-500/30 bg-amber-500/5";
    let zoneGlow = isMidnight ? "shadow-[0_0_15px_rgba(124,58,237,0.3)]" : "shadow-[0_0_15px_rgba(217,119,6,0.3)]";
    let zoneProgress = isMidnight ? 90 : 45;

    return (
      <div className="relative mx-auto w-[285px] h-[350px] bg-[#0A0A0B] rounded-[48px] p-2.5 shadow-2xl border-[6px] border-neutral-800 overflow-hidden flex flex-col select-none">
        <div className="absolute top-12 -right-[5px] w-[6px] h-14 bg-neutral-800 rounded-l-md border-y border-l border-neutral-700 z-10"></div>
        <div className="absolute top-32 -right-[5px] w-[5px] h-10 bg-neutral-800 rounded-l-sm border-y border-l border-neutral-700 z-10"></div>

        <div className="flex-1 bg-black rounded-[38px] p-4 flex flex-col justify-between relative border border-neutral-900/50">
          <div className="flex justify-between items-center text-[8px] font-mono tracking-widest text-neutral-500 uppercase">
            <span>TIGER COMPANION</span>
            <span className="animate-pulse flex items-center gap-1">
              <span className={`w-1.5 h-1.5 rounded-full ${isCheckedIn ? 'bg-emerald-500' : 'bg-orange-500'}`}></span>
              {isCheckedIn ? 'ACTIVE' : 'PAUSED'}
            </span>
          </div>

          {watchQrOpen ? (
            <div className="flex-1 flex flex-col items-center justify-center p-2 text-center space-y-2">
              <span className="text-[9px] font-serif font-black text-amber-500 uppercase tracking-wider">TIGER SPEED-PASS</span>
              <div className="w-24 h-24 bg-white p-1 rounded-lg shadow-inner relative flex items-center justify-center">
                <div className="w-full h-full border border-black grid grid-cols-4 gap-1 p-1">
                  {[...Array(16)].map((_, i) => (
                    <div 
                      key={i} 
                      className={`rounded ${i % 3 === 0 || i % 5 === 1 ? 'bg-black' : 'bg-transparent'}`}
                    ></div>
                  ))}
                </div>
                <div className="absolute inset-x-0 h-0.5 bg-red-500 animate-bounce"></div>
              </div>
              <button 
                onClick={() => setWatchQrOpen(false)}
                className="px-3 py-1 bg-neutral-900 hover:bg-neutral-800 text-[8px] font-mono tracking-wider font-bold rounded-full text-white uppercase"
              >
                BACK TO PASS
              </button>
            </div>
          ) : (
            <div className="flex-1 flex flex-col justify-between pt-2">
              <div className="text-center space-y-1">
                <span className="text-[7px] text-neutral-500 font-mono tracking-widest block uppercase">Time Currency remaining</span>
                <div className="font-mono text-3xl text-amber-500 tracking-tighter font-black animate-pulse flex justify-center items-baseline gap-0.5">
                  <span className="text-neutral-700 text-xs tracking-normal mr-1">00:00:</span>
                  <span className="text-white">{mins}</span>
                  <span className="text-neutral-500 text-xl">:</span>
                  <span className="text-amber-500">{secs}</span>
                </div>
                <div className="flex justify-center gap-4 text-[7px] font-mono text-neutral-600 uppercase tracking-widest">
                  <span>Hr</span><span>Min</span><span>Sec</span>
                </div>
              </div>

              <div className={`p-2 rounded-xl border text-center ${zoneColorClass} ${zoneGlow} space-y-0.5 my-1`}>
                <span className="text-[7px] font-serif font-bold tracking-widest uppercase block text-neutral-400">CURRENT AREA</span>
                <div className="flex justify-between items-center px-1">
                  <span className="font-serif font-black text-[9px] tracking-wide text-white uppercase">{zoneTitle}</span>
                  <span className="text-[10px] font-mono font-black text-white">{zoneCode}</span>
                </div>
                <div className="w-full bg-neutral-950 h-1 rounded-full overflow-hidden mt-1">
                  <div className="bg-amber-500 h-full rounded-full transition-all duration-500" style={{ width: `${zoneProgress}%` }}></div>
                </div>
              </div>

              <div className="grid grid-cols-3 gap-1.5 text-[8px] font-mono font-bold tracking-wider">
                <button
                  onClick={() => {
                    setIsCheckedIn(!isCheckedIn);
                    triggerPointsToast(0, isCheckedIn ? 'Timer Frozen' : 'Lounge Resumed');
                  }}
                  className={`py-1.5 rounded-lg border text-center transition-colors truncate px-0.5 ${
                    isCheckedIn 
                      ? 'bg-neutral-900 border-orange-800 text-orange-400' 
                      : 'bg-amber-500 border-amber-400 text-black'
                  }`}
                >
                  {isCheckedIn ? '⏸ FREEZE' : '▶ RESUME'}
                </button>

                <button
                  onClick={() => setWatchQrOpen(true)}
                  className="py-1.5 bg-neutral-900 hover:bg-neutral-800 border border-neutral-800 rounded-lg text-white text-center"
                >
                  🎫 PASS
                </button>

                <button
                  onClick={() => {
                    setTimeRemaining(prev => prev + 900);
                    triggerPointsToast(0, 'Added 15 mins via Watch');
                  }}
                  className="py-1.5 bg-neutral-900 hover:bg-neutral-800 border border-amber-500/40 text-[#D4AF37] rounded-lg text-center"
                >
                  +15M
                </button>
              </div>
            </div>
          )}

          <div className="text-center text-[7px] text-neutral-600 uppercase tracking-widest">
            APPLE WEAR COMPANION
          </div>
        </div>
      </div>
    );
  };

  const renderAndroidWatch = () => {
    const mins = String(Math.floor((timeRemaining % 3600) / 60)).padStart(2, '0');
    const secs = String(timeRemaining % 60).padStart(2, '0');

    let zoneTitle = isMidnight ? "CLUB TIGER" : "SPEAKEASY BAR";
    let zoneCode = isMidnight ? "D2" : "S1";
    let zoneColorClass = isMidnight ? "text-purple-400" : "text-amber-500";
    let zoneProgress = isMidnight ? 90 : 45;

    return (
      <div className="relative mx-auto w-[300px] h-[300px] bg-[#0A0A0B] rounded-full p-3 shadow-2xl border-[8px] border-neutral-800 overflow-hidden flex flex-col justify-center items-center select-none">
        <div className="absolute top-1/2 -right-[5px] -translate-y-1/2 w-[5px] h-10 bg-neutral-800 rounded-l-md border-y border-l border-neutral-700 z-10"></div>

        <div className="w-full h-full bg-black rounded-full p-5 border border-neutral-900 flex flex-col justify-between items-center text-center relative overflow-hidden">
          <div className="absolute inset-2 rounded-full border border-dashed border-amber-500/5 animate-spin pointer-events-none" style={{ animationDuration: '120s' }}></div>

          {watchQrOpen ? (
            <div className="flex-1 flex flex-col items-center justify-center space-y-2 mt-4 z-10">
              <span className="text-[8px] font-serif font-bold text-amber-500 uppercase tracking-widest">SCAN COMPANION</span>
              <div className="w-20 h-20 bg-white p-1 rounded-md shadow-inner flex items-center justify-center">
                <div className="w-full h-full border border-black grid grid-cols-4 gap-0.5 p-0.5">
                  {[...Array(16)].map((_, i) => (
                    <div key={i} className={`rounded-sm ${i % 3 === 0 || i % 5 === 1 ? 'bg-black' : 'bg-transparent'}`}></div>
                  ))}
                </div>
              </div>
              <button
                onClick={() => setWatchQrOpen(false)}
                className="px-2.5 py-0.5 bg-neutral-900 border border-neutral-800 hover:bg-neutral-800 rounded-full text-[8px] font-mono tracking-wider font-bold text-neutral-300"
              >
                CLOSE
              </button>
            </div>
          ) : (
            <div className="flex-1 flex flex-col justify-between items-center pt-2 z-10 w-full">
              <div className="text-[7px] font-mono text-neutral-500 uppercase tracking-[0.2em]">
                {currentBranch.split(' ')[1] || 'TIGER'}
              </div>

              <div className="my-auto space-y-0.5">
                <div className="text-[6px] text-neutral-600 font-mono tracking-widest uppercase">TIGER WALLET</div>
                <div className="font-mono text-3xl text-amber-500 tracking-tight font-black animate-pulse">
                  {mins}:{secs}
                </div>
                <div className={`text-[7px] font-serif ${zoneColorClass} uppercase tracking-widest`}>
                  {zoneTitle} [{zoneCode}]
                </div>
              </div>

              <div className="w-24 bg-neutral-950 h-1 rounded-full overflow-hidden border border-neutral-900">
                <div className="bg-amber-500 h-full rounded-full" style={{ width: `${zoneProgress}%` }}></div>
              </div>

              <div className="grid grid-cols-3 gap-1 w-full max-w-[190px] text-[7px] font-mono font-bold uppercase tracking-wider mt-1.5">
                <button
                  onClick={() => {
                    setIsCheckedIn(!isCheckedIn);
                    triggerPointsToast(0, isCheckedIn ? 'Timer Frozen' : 'Lounge Resumed');
                  }}
                  className={`py-1 rounded-full border text-center transition-colors truncate ${
                    isCheckedIn 
                      ? 'bg-neutral-900 border-orange-800 text-orange-400' 
                      : 'bg-amber-500 border-amber-400 text-black'
                  }`}
                >
                  {isCheckedIn ? 'FREEZE' : 'RESUME'}
                </button>

                <button
                  onClick={() => setWatchQrOpen(true)}
                  className="py-1 bg-neutral-900 hover:bg-neutral-800 border border-neutral-800 rounded-full text-white text-center"
                >
                  PASS
                </button>

                <button
                  onClick={() => {
                    setTimeRemaining(prev => prev + 1800);
                    triggerPointsToast(0, 'Added 30 mins');
                  }}
                  className="py-1 bg-neutral-900 hover:bg-neutral-800 border border-amber-500/40 text-amber-500 rounded-full text-center"
                >
                  +30M
                </button>
              </div>

              <div className="text-[6px] text-neutral-600 uppercase tracking-widest mt-1">
                ANDROID COMPANION
              </div>
            </div>
          )}
        </div>
      </div>
    );
  };

  return (
    <div className="flex flex-col items-center w-full space-y-4">
      {/* Premium Device Selector */}
      <div className="flex bg-[#1C0F00]/95 p-1 rounded-xl border border-[#C5A059]/30 text-xs w-full max-w-[340px] shadow-lg">
        <button
          onClick={() => setSelectedDevice('phone')}
          className={`flex-1 py-1.5 rounded-lg font-mono font-bold transition-all text-[10px] tracking-widest ${selectedDevice === 'phone' ? 'bg-gradient-to-r from-[#B45309] to-[#8B0000] text-[#E5C180] border border-[#C5A059]/30 shadow-md shadow-crimson-glow' : 'text-neutral-500 hover:text-neutral-300'}`}
        >
          MOBILE
        </button>
        <button
          onClick={() => setSelectedDevice('apple')}
          className={`flex-1 py-1.5 rounded-lg font-mono font-bold transition-all text-[10px] tracking-widest ${selectedDevice === 'apple' ? 'bg-gradient-to-r from-[#E5C180] to-[#C5A059] text-black shadow-md' : 'text-neutral-500 hover:text-neutral-300'}`}
        >
          APPLE WATCH
        </button>
        <button
          onClick={() => setSelectedDevice('android')}
          className={`flex-1 py-1.5 rounded-lg font-mono font-bold transition-all text-[10px] tracking-widest ${selectedDevice === 'android' ? 'bg-gradient-to-r from-[#C5A059] to-[#8E6E35] text-black shadow-md' : 'text-neutral-500 hover:text-neutral-300'}`}
        >
          WEAR OS
        </button>
      </div>

      {selectedDevice === 'apple' ? (
        renderAppleWatch()
      ) : selectedDevice === 'android' ? (
        renderAndroidWatch()
      ) : (
        <div id="iphone-device-frame" className={`relative mx-auto w-[375px] h-[812px] bg-[#050000] rounded-[55px] p-3 shadow-2xl border-[10px] ${isMidnight ? 'border-purple-600/50 shadow-purple-glow' : 'border-[#C5A059]/50 shadow-crimson-glow'} overflow-hidden flex flex-col select-none chinese-lattice transition-all duration-1000`}>
      
      {/* iPhone Dynamic Island */}
      <div className="absolute top-4 left-1/2 -translate-x-1/2 w-28 h-7 bg-black rounded-3xl z-50 flex items-center justify-center border border-white/5 shadow-inner">
        <div className="w-2.5 h-2.5 bg-[#0e0224] rounded-full mr-12 border border-white/5"></div>
        <div className="w-8 h-1 bg-[#1a0230] rounded-full"></div>
      </div>

      {/* Screen Content Wrapper with Midnight Transition Backgrounds */}
      <div className={`flex-1 bg-gradient-to-b ${isMidnight ? 'from-[#1A033B] via-[#050012] to-[#0D0021]' : 'from-[#2A1000] via-[#050000] to-[#120500]'} rounded-[42px] overflow-hidden flex flex-col relative text-white border ${isMidnight ? 'border-purple-500/25' : 'border-[#C5A059]/25'} chinese-cloud transition-all duration-1000`}>
        
        {/* ======================================= */}
        {/* SCREEN 1: ONBOARDING WITH SECURE DOOR   */}
        {/* ======================================= */}
        {currentScreen === 'onboarding' && (
          <div className="flex-1 flex flex-col justify-between p-6 relative bg-gradient-to-b from-[#1C0500] via-[#050000] to-[#0A0000]">
            <div className="absolute top-10 right-10 w-24 h-24 bg-[#8B0000]/15 rounded-full blur-3xl"></div>
            <div className="absolute top-40 left-5 w-32 h-32 bg-amber-500/5 rounded-full blur-2xl"></div>

            {/* Top Logo */}
            <div className="mt-14 text-center">
              <div className="inline-block relative">
                <span className="font-serif text-xs tracking-[0.3em] text-[#E5C180] block mb-1">THE SOCIAL CLUB & SPEAKEASY</span>
                <h1 className="text-3xl font-serif font-black tracking-wider text-white">THE BLIND TIGER</h1>
                <div className="h-[2px] w-12 bg-[#C5A059] mx-auto mt-2"></div>
              </div>
              <p className="text-[10px] text-neutral-400 tracking-widest uppercase mt-2 font-mono">Manila's Hidden Sanctuary</p>
            </div>

            {/* Secret Entrance Interface */}
            <div className="my-auto flex flex-col items-center justify-center space-y-4 z-10">
              
              {doorStatus === 'unlocked' ? (
                <div className="w-36 h-36 rounded-full border-2 border-emerald-500 bg-emerald-950/20 flex flex-col items-center justify-center animate-pulse shadow-lg shadow-emerald-500/20">
                  <Check className="w-10 h-10 text-emerald-400" />
                  <span className="text-[9px] font-mono text-emerald-400 tracking-widest font-black uppercase mt-1">DOOR OPENED</span>
                </div>
              ) : (
                <div className="w-full space-y-3 px-2 text-center">
                  <span className="text-[9px] text-[#E5C180] font-bold uppercase tracking-widest block font-serif">Knock or Solve Passcode</span>
                  
                  {/* Knock button */}
                  <button 
                    onClick={handleSecretKnock}
                    className="mx-auto w-24 h-24 rounded-full border border-[#C5A059]/40 bg-neutral-950/80 hover:bg-[#8B0000]/20 flex flex-col items-center justify-center transition-all group active:scale-95 shadow-md"
                  >
                    <span className="text-2xl animate-pulse">✊</span>
                    <span className="text-[8px] font-mono text-[#C5A059] tracking-widest uppercase font-bold mt-1 group-hover:text-white">Knock 3x</span>
                  </button>

                  <div className="text-neutral-500 text-[10px]">or whisper keyphrase:</div>

                  {/* Password Input */}
                  <div className="flex gap-1.5 justify-center max-w-[240px] mx-auto">
                    <input 
                      type="text"
                      placeholder="Enter Password..."
                      value={passwordInput}
                      onChange={(e) => setPasswordInput(e.target.value)}
                      onKeyDown={(e) => e.key === 'Enter' && handlePasswordUnlock()}
                      className="bg-neutral-900/90 border border-[#C5A059]/25 text-white placeholder-neutral-600 rounded-lg py-1.5 px-3 text-xs w-full text-center focus:outline-none focus:border-[#C5A059] font-mono uppercase tracking-widest"
                    />
                    <button 
                      onClick={handlePasswordUnlock}
                      className="px-3 bg-[#8B0000]/60 border border-[#C5A059]/30 text-[#E5C180] rounded-lg text-xs font-bold hover:bg-[#8B0000]"
                    >
                      OK
                    </button>
                  </div>

                  <p className="text-[9px] text-neutral-500 font-mono italic">
                    (Hint: Solve entry puzzle in Spec Suite, or type "tiger")
                  </p>
                </div>
              )}
            </div>

            {/* Content & CTA Button */}
            <div className="space-y-4 z-10">
              <div className="space-y-2">
                <h3 className="text-base font-serif text-white tracking-wide font-bold text-center">Immersive Nightlife Simulation</h3>
                <div className="space-y-1.5 text-[11px] text-neutral-300 pl-4">
                  <div className="flex items-center gap-2">
                    <Sparkles className="w-3 h-3 text-[#E5C180] shrink-0" />
                    <span><strong>Storytelling Craft Concoctions</strong> paid with time</span>
                  </div>
                  <div className="flex items-center gap-2">
                    <Music className="w-3 h-3 text-amber-500 shrink-0" />
                    <span><strong>Midnight Shift</strong> to Microclub DJ vibes</span>
                  </div>
                </div>
              </div>

              <div>
                <button 
                  onClick={() => {
                    setDoorStatus('unlocked');
                    triggerPointsToast(0, 'Bouncer recognizes you. Welcome!');
                    setTimeout(() => setScreen('avatar'), 600);
                  }}
                  className="w-full h-11 rounded-xl bg-gradient-to-r from-[#8B0000] via-[#C5A059] to-[#8B0000] text-white font-bold tracking-wider text-xs shadow-md hover:brightness-110 active:scale-[0.98] transition-all flex items-center justify-center gap-1.5 border border-[#E5C180]/30 cursor-pointer"
                >
                  <Play className="w-3.5 h-3.5 fill-white" />
                  SKIP ENTRY CODE
                </button>
                <div className="text-center mt-2">
                  <span className="text-[8px] text-neutral-500 uppercase tracking-widest font-mono">Age 21+ Member Pass System</span>
                </div>
              </div>
            </div>
          </div>
        )}

        {/* ======================================= */}
        {/* SCREEN 2: AVATAR DESIGN                 */}
        {/* ======================================= */}
        {currentScreen === 'avatar' && (
          <div className="flex-1 flex flex-col justify-between p-5 pt-12">
            <div className="space-y-1">
              <h2 className="text-xl font-serif font-black tracking-wide text-white uppercase">Club Passport Identity</h2>
              <p className="text-xs text-neutral-400">Design your socialite persona for tonight's leaderboard</p>
            </div>

            {/* Circular Preview */}
            <div className="flex-1 flex flex-col items-center justify-center my-2">
              <div 
                className="w-40 h-40 rounded-full border-2 relative flex items-center justify-center bg-[#0C0500] transition-all duration-300 shadow-[0_0_20px_rgba(217,119,6,0.2)]"
                style={{ borderColor: avatarForm.color }}
              >
                <div className="absolute inset-1 rounded-full border border-dashed border-white/5 animate-spin" style={{ animationDuration: '60s' }}></div>
                
                <div className="flex flex-col items-center justify-center gap-1 font-mono text-center tracking-widest text-xs font-black">
                  <span className="text-xs text-neutral-400 bg-neutral-950 px-2 py-0.5 rounded border border-[#C5A059]/20 tracking-wider mb-1">{avatarForm.hair}</span>
                  <span className="text-xl text-white font-serif tracking-widest font-black uppercase mb-1">{avatarForm.eyes}</span>
                  <span className="text-[10px] text-neutral-300 italic font-medium">with {avatarForm.accessory}</span>
                </div>

                <div 
                  className="absolute bottom-1.5 px-2.5 py-0.5 rounded-full text-[9px] font-bold text-black font-mono shadow-md"
                  style={{ backgroundColor: avatarForm.color }}
                >
                  MEMBER #07
                </div>
              </div>

              {/* Codename */}
              <div className="mt-3.5 w-full max-w-[240px]">
                <label className="text-[9px] text-[#E5C180] font-semibold uppercase tracking-widest block text-center mb-1">MEMBER CODENAME</label>
                <input
                  type="text"
                  value={avatarForm.name}
                  onChange={(e) => setAvatarForm({ ...avatarForm, name: e.target.value })}
                  placeholder="NeonTiger_X"
                  className="w-full text-center bg-neutral-900 border border-[#C5A059]/30 text-white rounded-lg py-1 px-3 text-xs focus:outline-none focus:border-[#C5A059] font-mono"
                />
              </div>
            </div>

            {/* Config options */}
            <div className="space-y-3.5">
              <div className="flex bg-neutral-900 p-1 rounded-lg border border-[#C5A059]/20 text-xs">
                {['hair', 'eyes', 'acc.'].map((tab, idx) => {
                  const val = tab === 'acc.' ? 'accessories' : tab;
                  return (
                    <button
                      key={tab}
                      onClick={() => setAvatarTab(val as any)}
                      className={`flex-1 py-1 rounded-md text-[9px] font-bold tracking-widest uppercase transition-all cursor-pointer ${
                        avatarTab === val ? 'bg-[#8B0000]/40 text-[#E5C180] border border-[#C5A059]/30 shadow' : 'text-neutral-400 hover:text-white'
                      }`}
                    >
                      {tab}
                    </button>
                  );
                })}
              </div>

              {/* Carousel */}
              <div className="h-16 flex gap-2 overflow-x-auto pb-1 scrollbar-none">
                {avatarTab === 'hair' && HAIR_OPTIONS.map((opt) => (
                  <button
                    key={opt.id}
                    onClick={() => setAvatarForm({ ...avatarForm, hair: opt.path })}
                    className={`shrink-0 w-14 h-14 rounded-xl bg-neutral-950 border flex flex-col items-center justify-center transition-all cursor-pointer ${
                      avatarForm.hair === opt.path ? 'border-[#C5A059] bg-[#8B0000]/20 font-bold' : 'border-neutral-900'
                    }`}
                  >
                    <span className="font-mono text-xs font-black text-white">{opt.path}</span>
                    <span className="text-[7px] text-neutral-400 truncate max-w-[45px] mt-0.5">{opt.name.split(' ')[0]}</span>
                  </button>
                ))}

                {avatarTab === 'eyes' && EYES_OPTIONS.map((opt) => (
                  <button
                    key={opt.id}
                    onClick={() => setAvatarForm({ ...avatarForm, eyes: opt.path })}
                    className={`shrink-0 w-14 h-14 rounded-xl bg-neutral-950 border flex flex-col items-center justify-center transition-all cursor-pointer ${
                      avatarForm.eyes === opt.path ? 'border-[#C5A059] bg-[#8B0000]/20 font-bold' : 'border-neutral-900'
                    }`}
                  >
                    <span className="font-mono text-xs font-black text-white">{opt.path}</span>
                    <span className="text-[7px] text-neutral-400 truncate max-w-[45px] mt-0.5">{opt.name.split(' ')[0]}</span>
                  </button>
                ))}

                {avatarTab === 'accessories' && ACCESSORY_OPTIONS.map((opt) => (
                  <button
                    key={opt.id}
                    onClick={() => setAvatarForm({ ...avatarForm, accessory: opt.path })}
                    className={`shrink-0 w-14 h-14 rounded-xl bg-neutral-950 border flex flex-col items-center justify-center transition-all cursor-pointer ${
                      avatarForm.accessory === opt.path ? 'border-[#C5A059] bg-[#8B0000]/20 font-bold' : 'border-neutral-900'
                    }`}
                  >
                    <span className="font-mono text-xs font-black text-white">{opt.path}</span>
                    <span className="text-[7px] text-neutral-400 truncate max-w-[45px] mt-0.5">{opt.name.split(' ')[0]}</span>
                  </button>
                ))}
              </div>

              {/* Theme colors */}
              <div>
                <span className="text-[9px] text-neutral-500 font-bold uppercase tracking-widest block mb-1">MEMBER PIN COLOR</span>
                <div className="flex gap-2 justify-between">
                  {PRESET_COLORS.map((col) => (
                    <button
                      key={col.code}
                      onClick={() => setAvatarForm({ ...avatarForm, color: col.code })}
                      className="w-7 h-7 rounded-full border border-white/10 flex items-center justify-center relative shadow cursor-pointer"
                      style={{ backgroundColor: col.code }}
                    >
                      {avatarForm.color === col.code && (
                        <div className="w-2 h-2 bg-white rounded-full"></div>
                      )}
                    </button>
                  ))}
                </div>
              </div>

              <button
                onClick={() => {
                  setAvatar(avatarForm);
                  setScreen('pricing');
                }}
                className="w-full h-11 rounded-xl bg-gradient-to-r from-[#B45309] to-[#8B0000] text-[#E5C180] font-bold tracking-wider text-xs transition-all flex items-center justify-center gap-1.5 border border-[#C5A059]/40 shadow-crimson-glow cursor-pointer"
              >
                PROCEED TO LOUNGE HOURS
                <ChevronRight className="w-4 h-4" />
              </button>
            </div>
          </div>
        )}

        {/* ======================================= */}
        {/* SCREEN 3: TICKET/HOUR CHOICE            */}
        {/* ======================================= */}
        {currentScreen === 'pricing' && (
          <div className="flex-1 flex flex-col justify-between p-5 pt-12 overflow-y-auto">
            <div className="space-y-1">
              <h2 className="text-xl font-serif font-black tracking-wide text-white uppercase">Redeem Socialite Pass</h2>
              <p className="text-xs text-neutral-400">Buy reservation time to spend inside the club tonight</p>
            </div>

            <div className="my-2 bg-[#C5A059]/10 border border-[#C5A059]/40 rounded-xl p-2 flex items-center justify-between text-xs text-[#E5C180]">
              <span className="flex items-center gap-1.5 font-sans font-bold text-[10px]">
                <Users className="w-3.5 h-3.5 text-[#E5C180]" />
                GCash Referral Active
              </span>
              <span className="font-bold font-mono bg-[#C5A059] text-black px-1.5 py-0.5 rounded text-[9px]">15% OFF</span>
            </div>

            {/* Passes List */}
            <div className="space-y-2 my-1 flex-1 flex flex-col justify-center">
              {PRICE_TIERS.map((tier) => {
                const isSelected = selectedTier.id === tier.id;
                const discountedPrice = Math.floor(tier.price * 0.85);
                return (
                  <button
                    key={tier.id}
                    onClick={() => setSelectedTier(tier)}
                    className={`w-full text-left p-3 rounded-xl border transition-all flex justify-between items-center relative cursor-pointer ${
                      isSelected 
                        ? 'border-[#C5A059] bg-[#8B0000]/15 shadow-crimson-glow' 
                        : 'border-[#C5A059]/20 bg-neutral-900/60 hover:border-[#C5A059]/45'
                    }`}
                  >
                    {tier.popular && (
                      <span className="absolute -top-1.5 right-4 px-1.5 py-0.5 rounded bg-gradient-to-r from-amber-500 to-[#C5A059] text-black font-black text-[7px] tracking-wider uppercase font-sans">
                        RECOMMENDED
                      </span>
                    )}

                    <div className="space-y-0.5">
                      <div className="flex items-center gap-1">
                        <span className="text-xl font-black font-mono text-white">{tier.duration}</span>
                        <span className="text-[9px] text-neutral-400 font-mono tracking-wider font-bold">MINUTES</span>
                      </div>
                      <span className="text-[9px] text-[#E5C180] font-mono tracking-wider uppercase font-bold block">{tier.tagline}</span>
                      <p className="text-[9px] text-neutral-400 leading-tight pr-1">{tier.valueProp}</p>
                    </div>

                    <div className="text-right shrink-0">
                      <div className="text-[10px] text-neutral-500 line-through font-mono">₱{tier.price}</div>
                      <div className="text-base font-black font-mono text-[#E5C180]">₱{discountedPrice}</div>
                      <div className="mt-1 flex justify-end">
                        <div className={`w-3.5 h-3.5 rounded-full border flex items-center justify-center ${
                          isSelected ? 'border-[#C5A059] bg-[#8B0000]' : 'border-neutral-700 bg-neutral-950'
                        }`}>
                          {isSelected && <Check className="w-2 h-2 text-white stroke-[3px]" />}
                        </div>
                      </div>
                    </div>
                  </button>
                );
              })}
            </div>

            {/* Secure options */}
            <div className="space-y-2.5 bg-neutral-950/60 p-3 rounded-xl border border-[#C5A059]/20">
              <div className="flex justify-between text-[11px] font-mono">
                <span className="text-neutral-400">Total Charged:</span>
                <span className="text-[#E5C180] font-bold">₱{Math.floor(selectedTier.price * 0.85)} • {selectedTier.duration}m Club Pass</span>
              </div>

              <div>
                <span className="text-[8px] text-neutral-500 font-mono tracking-widest block mb-0.5 uppercase">Payment Method</span>
                <div className="grid grid-cols-3 gap-1.5">
                  {[
                    { id: 'gcash', label: 'GCASH', color: 'border-emerald-600 text-emerald-400' },
                    { id: 'paymaya', label: 'MAYA', color: 'border-blue-600 text-blue-400' },
                    { id: 'visa', label: 'VISA', color: 'border-[#C5A059] text-[#E5C180]' },
                  ].map((pay) => (
                    <button 
                      key={pay.id}
                      onClick={() => setSelectedPayment(pay.id as any)}
                      className={`py-1 rounded-lg border text-[8px] font-bold text-center tracking-wider transition-all flex items-center justify-center gap-0.5 cursor-pointer ${
                        selectedPayment === pay.id ? pay.color + ' bg-white/5 font-black' : 'border-neutral-800 text-neutral-400'
                      }`}
                    >
                      {pay.label}
                    </button>
                  ))}
                </div>
              </div>

              <button
                onClick={() => {
                  setTimeRemaining(selectedTier.duration * 60);
                  setScreen('checkout');
                  setTimeout(() => {
                    setScreen('active');
                  }, 2200);
                }}
                className="w-full h-10 rounded-xl bg-gradient-to-r from-[#B45309] to-[#8B0000] text-[#E5C180] font-bold tracking-wider text-xs transition-all flex items-center justify-center gap-1 border border-[#C5A059]/40 shadow-crimson-glow cursor-pointer"
              >
                <Shield className="w-3.5 h-3.5" />
                SECURE TRANSACTION
              </button>
            </div>
          </div>
        )}

        {/* ======================================= */}
        {/* SCREEN 4: LOADING CHECKOUT SCREEN       */}
        {/* ======================================= */}
        {currentScreen === 'checkout' && (
          <div className="flex-1 flex flex-col items-center justify-center p-6 bg-neutral-950">
            <div className="w-12 h-12 rounded-full border-t-2 border-[#C5A059] border-r-2 border-r-transparent animate-spin mb-4"></div>
            <p className="text-xs font-mono text-[#E5C180] tracking-widest uppercase">Securing Member Pass...</p>
            <p className="text-[10px] text-neutral-500 font-mono mt-1 uppercase">PROVISIONING SMART ID #7 • THE BLIND TIGER</p>
          </div>
        )}

        {/* ======================================= */}
        {/* SCREEN 5: MAIN LOUNGE HUB (ACTIVE)      */}
        {/* ======================================= */}
        {currentScreen === 'active' && (
          <div className="flex-1 flex flex-col justify-between overflow-hidden">
            
            {/* Top status bar */}
            <div className={`p-3 pt-12 pb-1.5 ${isMidnight ? 'bg-[#180330] border-purple-500/35' : 'bg-[#1C0A00] border-[#C5A059]/25'} flex justify-between items-center border-b transition-colors duration-1000`}>
              <div className="flex gap-1.5 items-center">
                <span className={`w-1.5 h-1.5 rounded-full ${isMidnight ? 'bg-purple-400 animate-ping' : 'bg-emerald-400 animate-pulse'} shrink-0`}></span>
                <span className="text-[8px] font-mono tracking-widest font-black text-neutral-300 uppercase">
                  {isMidnight ? 'MICROCLUB_SYS' : 'SPEAKEASY_SYS'}
                </span>
              </div>
              
              <div className="flex gap-1">
                <span className={`px-1.5 py-0.5 ${isMidnight ? 'bg-purple-950/80 text-purple-400 border-purple-800/40' : 'bg-[#8B0000]/30 text-[#E5C180] border-[#C5A059]/30'} rounded text-[7px] font-bold border`}>
                  {isMidnight ? '🕺 DANCING' : '🌶️ SEATED'}
                </span>
                <span className="px-1.5 py-0.5 bg-amber-500/10 text-amber-500 rounded text-[7px] font-bold border border-amber-500/10">LIVE CHRONO</span>
              </div>
            </div>

            {/* Timer concept display */}
            <div className={`p-4 mx-3 my-1.5 rounded-2xl bg-gradient-to-b from-[#1C0F00] to-[#050000] border text-center relative overflow-hidden transition-all duration-300 ${timerBorder} ${timerBg} ${timerGlow} chinese-lattice`}>
              <div className="absolute top-1 left-2 flex items-center gap-1">
                <span className="text-[7px] font-mono text-neutral-400 tracking-wider">TIGER PASSPORT v2.0</span>
                {!isCheckedIn && <span className="text-[7px] text-[#E5C180] font-bold bg-[#8B0000]/40 px-1 py-0.5 rounded border border-[#C5A059]/30 flex items-center gap-0.5"><Shield className="w-2 h-2 text-[#E5C180]" /> SAFE WALLET</span>}
                {isCheckedIn && <span className="text-[7px] text-emerald-400 font-bold bg-emerald-950/60 px-1 py-0.5 rounded border border-emerald-500/30 flex items-center gap-0.5">● COUNTDOWN LIVE</span>}
              </div>
              <div className="absolute top-1 right-2">
                <span className={`text-[7px] font-mono font-bold ${timerColor}`}>{timerLabel}</span>
              </div>

              {/* Countdown time */}
              <div className="my-2 py-0.5 flex flex-col items-center justify-center">
                <div className="flex items-baseline justify-center gap-1">
                  <span className={`text-5xl font-mono font-black tracking-tighter leading-none ${timerColor} drop-shadow-[0_0_12px_rgba(255,255,255,0.1)]`}>
                    {minutes}:{seconds}
                  </span>
                  <span className="text-neutral-500 font-mono text-lg font-bold tracking-widest leading-none">
                    .{milliseconds}
                  </span>
                </div>
                
                <div className="mt-1 flex items-center justify-center gap-1.5 text-[9px] font-mono font-bold tracking-wider">
                  {isCheckedIn ? (
                    <span className="text-emerald-400 flex items-center gap-1">
                      <span className="w-1 h-1 rounded-full bg-emerald-400 animate-ping"></span>
                      <Compass className="w-3 h-3 text-emerald-400 inline" /> {currentBranch}
                    </span>
                  ) : (
                    <span className="text-amber-500 flex items-center gap-1">
                      <Shield className="w-3 h-3 text-amber-500 inline mr-1" /> SECURE SAVER (Pass Paused)
                    </span>
                  )}
                </div>
              </div>

              <div className="mt-2 grid grid-cols-2 gap-2">
                {isCheckedIn ? (
                  <button 
                    onClick={() => {
                      setIsCheckedIn(false);
                      triggerPointsToast(0, 'Pass Frozen! Hours securely saved.');
                    }}
                    className="py-1.5 bg-[#8B0000]/30 hover:bg-[#8B0000]/50 border border-[#C5A059]/40 rounded-lg text-[8px] font-black tracking-widest text-[#E5C180] transition-all flex items-center justify-center gap-0.5 shadow cursor-pointer"
                  >
                    <Pause className="w-2.5 h-2.5 text-[#E5C180]" /> FREEZE PASS
                  </button>
                ) : (
                  <button 
                    onClick={() => setShowBranchSelector(true)}
                    className="py-1.5 bg-gradient-to-r from-amber-500 to-[#C5A059] text-black font-black tracking-widest text-[8px] rounded-lg transition-all flex items-center justify-center gap-0.5 shadow-md shadow-amber-500/20 animate-bounce cursor-pointer"
                  >
                    <Play className="w-2.5 h-2.5 text-black fill-black" /> ACTIVATE PASS
                  </button>
                )}
                
                <button 
                  onClick={() => setShowQrModal(true)}
                  className="py-1.5 bg-neutral-950 border border-[#C5A059]/30 hover:border-[#C5A059]/50 rounded-lg text-[8px] font-black tracking-widest text-[#E5C180] transition-all flex items-center justify-center gap-0.5 cursor-pointer"
                >
                  <QrCode className="w-2.5 h-2.5 text-[#E5C180]" /> DISPLAY QR
                </button>
              </div>
            </div>

            {/* Micro User bar */}
            <div className="px-4 py-1 bg-neutral-950/90 border-y border-[#C5A059]/25 flex justify-between items-center text-[11px]">
              <div className="flex items-center gap-1.5">
                <div 
                  className="w-4 h-4 rounded-full flex items-center justify-center text-[8px] font-bold shadow"
                  style={{ backgroundColor: avatarForm.color, color: '#000' }}
                >
                  {avatarForm.hair}
                </div>
                <span className="font-mono text-[10px] font-bold text-white truncate max-w-[80px]">
                  {avatarForm.name || 'Socialite'}
                </span>
              </div>
              <div className="flex gap-2.5 text-neutral-400">
                <span>Glasses: <strong className="text-white font-mono">{drinksOrdered}</strong></span>
                <span>Score: <strong className="text-[#E5C180] font-mono">{points} pts</strong></span>
              </div>
            </div>

            {/* Tab view area */}
            <div className="flex-1 overflow-y-auto px-3.5 py-2 space-y-3">
              
              {!isCheckedIn && (
                <div className="bg-[#8B0000]/15 border border-[#C5A059]/30 p-2 rounded-xl flex items-center justify-between gap-2 text-[9px] shadow-md">
                  <div className="flex items-center gap-1.5 min-w-0">
                    <Shield className="w-3.5 h-3.5 text-[#E5C180] shrink-0" />
                    <p className="text-neutral-200 leading-tight">
                      <strong>Chrono-Wallet Frozen</strong> • Check-In to order drinks
                    </p>
                  </div>
                  <button 
                    onClick={() => setShowBranchSelector(true)}
                    className="shrink-0 bg-[#C5A059] text-black px-2 py-0.5 text-[8px] font-black rounded uppercase tracking-wider transition-all cursor-pointer"
                  >
                    Check In
                  </button>
                </div>
              )}
              
              {/* TAB: GAMES */}
              {activeTab === 'games' && (
                <div className="space-y-3 pb-4">
                  <div className="flex justify-between items-center">
                    <h3 className="text-xs font-serif font-black text-white uppercase tracking-wider flex items-center gap-1">
                      <Music className="w-3.5 h-3.5 text-amber-500 animate-pulse" />
                      Lounge Entertainment
                    </h3>
                    <span className="text-[8px] text-neutral-400 font-mono">EARN FREE CREDITS</span>
                  </div>

                  <div className="grid grid-cols-2 gap-2">
                    {MINI_GAMES_LIST.map((game) => (
                      <button
                        key={game.id}
                        onClick={() => handlePlayGame(game)}
                        disabled={game.locked && points < 150}
                        className={`p-2.5 rounded-xl border text-left flex flex-col justify-between h-[105px] transition-all relative cursor-pointer ${
                          game.locked && points < 150
                            ? 'border-neutral-900 bg-neutral-950/40 opacity-50'
                            : 'border-[#C5A059]/20 bg-gradient-to-b from-[#1C0F00] to-[#050000] hover:border-[#C5A059]/45 active:scale-95'
                        }`}
                      >
                        <div className="flex justify-between items-start w-full">
                          {renderIcon(game.icon, isMidnight)}
                          <span className="text-[8px] font-mono font-bold text-[#E5C180] bg-[#8B0000]/40 px-1 py-0.5 rounded border border-[#C5A059]/20">
                            +{game.points} PTS
                          </span>
                        </div>

                        <div>
                          <span className="font-bold text-[11px] text-white block truncate">{game.title === "Spin the Vinyl" ? "Turntable Scratch" : game.title}</span>
                          <span className="text-[8px] text-neutral-400 line-clamp-2 mt-0.5 leading-snug">{game.description}</span>
                        </div>

                        {game.locked && points < 150 && (
                          <div className="absolute inset-0 bg-[#050000]/95 rounded-xl flex flex-col items-center justify-center p-2 text-center">
                            <span className="text-[10px] flex items-center gap-0.5 text-red-500 font-bold"><Shield className="w-2.5 h-2.5 text-red-500" /> LOCKED</span>
                            <span className="text-[8px] text-amber-500 mt-1">{game.lockRequirement}</span>
                          </div>
                        )}
                      </button>
                    ))}
                  </div>
                </div>
              )}

              {/* TAB: CHALLENGES */}
              {activeTab === 'challenges' && (
                <div className="space-y-2.5 pb-4">
                  <div className="flex justify-between items-center">
                    <h3 className="text-xs font-serif font-black text-white uppercase tracking-wider">Socialite Challenges</h3>
                    <span className="text-[8px] text-[#E5C180] font-mono font-bold">REDEEM LUXE REWARDS</span>
                  </div>

                  {challenges.map((chal) => {
                    const isComplete = chal.currentCount >= chal.targetCount;
                    const percent = Math.min(100, Math.floor((chal.currentCount / chal.targetCount) * 100));
                    return (
                      <div 
                        key={chal.id} 
                        className={`p-2.5 rounded-xl border transition-all flex items-center justify-between ${
                          chal.claimed 
                            ? 'border-neutral-900 bg-[#050000]/40 opacity-40' 
                            : isComplete 
                              ? 'border-emerald-500/40 bg-[#8B0000]/15 shadow-[0_0_10px_rgba(46,204,113,0.15)] animate-pulse' 
                              : 'border-[#C5A059]/20 bg-gradient-to-r from-[#1C0F00] to-[#050000]'
                        }`}
                      >
                        <div className="flex items-center gap-2.5 min-w-0">
                          <div className="w-8 h-8 bg-neutral-950 rounded-xl border border-neutral-900 flex items-center justify-center shrink-0">
                            {renderIcon(chal.icon, isMidnight)}
                          </div>
                          <div className="min-w-0">
                            <span className="font-bold text-[11px] text-white block truncate">{chal.title}</span>
                            <span className="text-[8px] text-neutral-400 font-mono block">
                              Progress: {chal.currentCount}/{chal.targetCount} ({percent}%)
                            </span>
                            
                            <div className="w-24 h-1 bg-neutral-950 rounded-full mt-1 overflow-hidden border border-neutral-900">
                              <div 
                                className="h-full bg-gradient-to-r from-amber-500 to-emerald-500 transition-all duration-500" 
                                style={{ width: `${percent}%` }}
                              ></div>
                            </div>
                          </div>
                        </div>

                        <div className="text-right pl-1 shrink-0">
                          <span className="text-[9px] font-mono font-bold text-[#E5C180] block">+{chal.points} pts</span>
                          {chal.claimed ? (
                            <span className="text-[8px] text-neutral-600 font-bold font-mono">CLAIMED</span>
                          ) : isComplete ? (
                            <button
                              onClick={() => handleClaimChallenge(chal.id, chal.points)}
                              className="mt-1 px-2.5 py-0.5 bg-gradient-to-r from-amber-500 to-[#C5A059] text-black font-black text-[8px] rounded hover:brightness-110 shadow animate-bounce cursor-pointer"
                            >
                              CLAIM
                            </button>
                          ) : (
                            <span className="text-[7px] text-neutral-500 block mt-0.5 font-mono">ACTIVE</span>
                          )}
                        </div>
                      </div>
                    );
                  })}
                </div>
              )}

              {/* TAB: SOCIAL */}
              {activeTab === 'social' && (
                <div className="space-y-3 pb-4">
                  <div className="flex justify-between items-center">
                    <h3 className="text-xs font-serif font-black text-white uppercase tracking-wider">Lounge Activity</h3>
                    <span className="text-[8px] text-neutral-400 font-mono">SECURE LIVE DECK</span>
                  </div>

                  {feedEvents.map((evt) => (
                    <div key={evt.id} className="p-2.5 rounded-xl border border-[#C5A059]/15 bg-gradient-to-b from-[#1C0F00] to-[#050000] flex gap-2.5">
                      <div 
                        className="w-8 h-8 rounded-full flex flex-col items-center justify-center shrink-0 border border-white/5"
                        style={{ backgroundColor: evt.avatarSeed.color }}
                      >
                        <span className="font-mono text-[8px] font-black text-black leading-none">{evt.avatarSeed.hair}</span>
                        <span className="font-mono text-[7px] font-black text-black leading-none mt-0.5">{evt.avatarSeed.eyes}</span>
                      </div>

                      <div className="flex-1 min-w-0 space-y-1">
                        <div className="flex items-center justify-between">
                          <div className="flex items-center gap-1.5">
                            <span className="font-bold text-[11px] text-white truncate max-w-[90px]">{evt.userName}</span>
                            <span className="text-[7px] text-neutral-400 bg-neutral-950 px-1 py-0.2 rounded font-mono border border-[#C5A059]/15">{evt.userRank}</span>
                          </div>
                          <span className="text-[8px] text-neutral-500 font-mono">{evt.timeAgo}</span>
                        </div>

                        <p className="text-[11px] text-neutral-300 leading-snug">{evt.eventText}</p>

                        <div className="pt-1 flex gap-1.5">
                          {(['luxe', 'salute', 'gold'] as const).map((r) => {
                            const reactCount = evt.likes[r] || 0;
                            const isChosen = evt.userReacted === r;
                            const getReactIcon = (key: 'luxe' | 'salute' | 'gold') => {
                              if (key === 'luxe') return <Flame className="w-2.5 h-2.5" />;
                              if (key === 'salute') return <Trophy className="w-2.5 h-2.5" />;
                              return <Star className="w-2.5 h-2.5" />;
                            };
                            return (
                              <button
                                key={r}
                                onClick={() => handleReactFeed(evt.id, r)}
                                        className={`px-2 py-0.5 rounded-full border text-[8px] font-mono transition-all flex items-center gap-0.5 cursor-pointer ${
                                  isChosen 
                                    ? 'bg-[#8B0000]/30 border-[#C5A059] text-white' 
                                    : 'bg-neutral-950 border-neutral-900 text-neutral-500 hover:text-white'
                                }`}
                              >
                                {getReactIcon(r)}
                                <span>{reactCount}</span>
                              </button>
                            );
                          })}
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              )}

              {/* TAB: MENU */}
              {activeTab === 'menu' && (
                <div className="space-y-3 pb-4">
                  <div className="flex justify-between items-center">
                    <h3 className="text-xs font-serif font-black text-white uppercase tracking-wider">Storytelling Concoctions</h3>
                    <span className="text-[8px] text-neutral-400 font-mono">DEDUCTS RESERVATION TIME</span>
                  </div>

                  <div className="flex gap-1 overflow-x-auto pb-1 scrollbar-none">
                    {['All', 'Spirits', 'Beer'].map((cat) => (
                      <button
                        key={cat}
                        onClick={() => setMenuFilter(cat as any)}
                        className={`px-2.5 py-0.5 rounded-full text-[8px] font-bold tracking-wider uppercase shrink-0 border transition-all cursor-pointer ${
                          menuFilter === cat 
                            ? 'bg-gradient-to-r from-amber-500 to-[#C5A059] text-black border-[#C5A059] font-black' 
                            : 'bg-neutral-950 border-neutral-800 text-neutral-400 hover:text-white'
                        }`}
                      >
                        {cat}
                      </button>
                    ))}
                  </div>

                  <div className="space-y-2">
                    {filteredDrinks.map((drink) => (
                      <button
                        key={drink.id}
                        onClick={() => setSelectedDrink(drink)}
                        className="w-full text-left p-2.5 rounded-xl border border-[#C5A059]/20 bg-[#1C0F00]/40 hover:border-[#C5A059]/45 transition-all flex gap-2.5 relative overflow-hidden group cursor-pointer"
                      >
                        <div className={`w-12 h-12 rounded-xl shrink-0 bg-gradient-to-br ${drink.imageColor} border border-white/5 flex items-center justify-center relative shadow-inner overflow-hidden`}>
                          <div className="absolute inset-x-0 bottom-0 h-2/3 bg-white/5 animate-pulse"></div>
                          <Sparkles className="w-4 h-4 text-[#E5C180]" />
                        </div>

                        <div className="flex-1 min-w-0 space-y-0.5">
                          <div className="flex justify-between items-start">
                            <span className="font-bold text-[11px] text-white block truncate pr-1">{drink.name}</span>
                            <div className="text-right shrink-0">
                              <span className="text-[10px] font-mono font-black text-[#E5C180] block leading-none">{drink.price}</span>
                              <span className="text-[8px] font-mono font-bold text-red-400 block mt-0.5">-{formatSecondsToMins(getDrinkTimeCostSeconds(drink))}</span>
                            </div>
                          </div>
                          
                          <p className="text-[9px] text-neutral-400 line-clamp-2 leading-tight pr-1">{drink.description}</p>
                          
                          <div className="flex gap-1.5 pt-0.5">
                            <span className="text-[7px] font-mono text-[#E5C180] bg-[#8B0000]/40 px-1 py-0.2 rounded border border-[#C5A059]/15">
                              {drink.abv}
                            </span>
                            <span className="text-[7px] font-mono text-neutral-400">
                              {drink.flavor.split(',')[0]}
                            </span>
                            {drink.badge && (
                              <span className="text-[7px] font-mono text-amber-500 font-bold">
                                {drink.badge}
                              </span>
                            )}
                          </div>
                        </div>
                      </button>
                    ))}
                  </div>
                </div>
              )}

              {/* TAB: LEADERBOARD */}
              {activeTab === 'leaderboard' && (
                <div className="space-y-3 pb-4">
                  <div className="flex justify-between items-center">
                    <h3 className="text-xs font-serif font-black text-white uppercase tracking-wider">Lounge Leaderboard</h3>
                    <span className="text-[8px] text-neutral-400 font-mono">SORTED BY RESERVED TIME</span>
                  </div>

                  <div className="p-2.5 rounded-xl border border-[#C5A059] bg-[#8B0000]/15 flex items-center justify-between shadow-md">
                    <div className="flex items-center gap-2">
                      <span className="text-xl font-black font-mono text-amber-500">#7</span>
                      <div className="w-8 h-8 rounded-full flex flex-col items-center justify-center bg-[#8B0000] border border-[#C5A059]/40">
                        <span className="font-mono text-[8px] font-black text-black leading-none">{avatarForm.hair}</span>
                        <span className="font-mono text-[7px] font-black text-black leading-none mt-0.5">{avatarForm.eyes}</span>
                      </div>
                      <div>
                        <span className="font-bold text-[11px] text-white block">You (Socialite)</span>
                        <span className="text-[8px] text-neutral-400 block font-mono">Unlock Gold tier with +50 points</span>
                      </div>
                    </div>
                    <div className="text-right">
                      <span className="text-xs font-black font-mono text-[#E5C180] block">{points} PTS</span>
                      <span className="text-[8px] text-neutral-500 uppercase font-mono block">Silver Tier</span>
                    </div>
                  </div>

                  <div className="space-y-1">
                    {leaderboard.map((user, i) => {
                      const medal = i === 0 ? '👑' : i === 1 ? '🥈' : i === 2 ? '🥉' : `#${user.rank}`;
                      const isMe = user.isCurrentUser;
                      return (
                        <div 
                          key={user.name} 
                          className={`p-2 rounded-lg border flex justify-between items-center text-xs ${
                            isMe 
                              ? 'border-[#C5A059] bg-[#8B0000]/20 shadow-sm' 
                              : 'border-neutral-900 bg-neutral-950/60'
                          }`}
                        >
                          <div className="flex items-center gap-2">
                            <span className="w-6 text-center font-bold font-mono text-[9px]">{medal}</span>
                            <div 
                              className="w-6 h-6 rounded-full flex items-center justify-center border border-white/5 text-[9px] font-mono font-bold bg-neutral-900"
                            >
                              {isMe ? avatarForm.hair : user.avatarGlyph}
                            </div>
                            <span className={`font-semibold truncate max-w-[100px] text-[11px] ${isMe ? 'text-amber-400 font-bold' : 'text-neutral-300'}`}>
                              {isMe ? (avatarForm.name || 'You') : user.name}
                            </span>
                          </div>

                          <div className="flex items-center gap-2">
                            <span className="font-bold font-mono text-[#E5C180] text-[10px]">
                              {isMe ? points : user.points} pts
                            </span>
                            <span className="text-[8px] text-neutral-500 uppercase font-mono">{user.tier}</span>
                          </div>
                        </div>
                      );
                    })}
                  </div>
                </div>
              )}

            </div>

            {/* Navigation Tabs */}
            <div className={`p-1.5 pb-4 ${isMidnight ? 'bg-[#180330] border-purple-500/35' : 'bg-[#1A0A00] border-[#C5A059]/25'} border-t flex justify-around transition-colors duration-1000`}>
              {[
                { tab: 'challenges', icon: <Award className="w-3.5 h-3.5" />, label: 'CHALLENGE' },
                { tab: 'games', icon: <Grid className="w-3.5 h-3.5" />, label: 'PLAY' },
                { tab: 'social', icon: <Users className="w-3.5 h-3.5" />, label: 'FEED' },
                { tab: 'menu', icon: <Sparkles className="w-3.5 h-3.5" />, label: 'MENU' },
                { tab: 'leaderboard', icon: <Trophy className="w-3.5 h-3.5" />, label: 'RANK' },
              ].map((item) => {
                const isActive = activeTab === item.tab;
                return (
                  <button
                    key={item.tab}
                    onClick={() => setActiveTab(item.tab as any)}
                    className="flex flex-col items-center py-1 select-none transition-all focus:outline-none cursor-pointer"
                  >
                    <span className={`transition-transform duration-300 ${isActive ? 'scale-125 text-amber-500' : 'text-neutral-500 hover:text-neutral-300'}`}>
                      {item.icon}
                    </span>
                    <span className={`text-[7px] font-bold mt-1 tracking-wider font-mono ${isActive ? 'text-amber-400' : 'text-neutral-500'}`}>
                      {item.label}
                    </span>
                  </button>
                );
              })}
            </div>

            <div className="bg-neutral-950 py-1 border-t border-neutral-900 text-center">
              <button 
                onClick={() => setScreen('summary')}
                className="text-[8px] text-neutral-600 font-mono uppercase tracking-widest hover:text-red-500 transition-colors cursor-pointer"
              >
                LEAVE THE BLIND TIGER
              </button>
            </div>

          </div>
        )}

        {/* ======================================= */}
        {/* SCREEN 6: RECEIPT SUMMARY               */}
        {/* ======================================= */}
        {currentScreen === 'summary' && (
          <div className="flex-1 flex flex-col justify-between p-5 pt-12 overflow-y-auto">
            
            <div className="text-center space-y-1">
              <span className="p-1.5 rounded-full bg-[#8B0000]/40 text-[#E5C180] border border-[#C5A059]/30 inline-block">
                <Award className="w-5 h-5 animate-bounce" />
              </span>
              <h2 className="text-xl font-serif font-black tracking-wide text-white uppercase">Checkout Receipt</h2>
              <p className="text-xs text-neutral-400">Your table hours have run their course tonight.</p>
            </div>

            {/* Stats */}
            <div className="bg-gradient-to-b from-[#1C0F00] to-[#050000] border border-[#C5A059]/25 p-4 rounded-2xl my-2 space-y-3 shadow-md">
              <span className="text-[8px] font-mono text-[#E5C180] tracking-widest block text-center font-bold uppercase">Membership Metrics</span>
              
              <div className="grid grid-cols-3 gap-2 text-center">
                <div className="p-2 bg-[#050000] rounded-xl border border-neutral-900">
                  <span className="text-lg font-mono font-black text-[#E5C180] block">{points}</span>
                  <span className="text-[7px] text-neutral-400 font-mono tracking-wider uppercase block">POINTS</span>
                </div>
                <div className="p-2 bg-[#050000] rounded-xl border border-neutral-900">
                  <span className="text-lg font-mono font-black text-white block">{drinksOrdered}</span>
                  <span className="text-[7px] text-neutral-400 font-mono tracking-wider uppercase block">DRINKS</span>
                </div>
                <div className="p-2 bg-[#050000] rounded-xl border border-neutral-900">
                  <span className="text-lg font-mono font-black text-emerald-400 block">3</span>
                  <span className="text-[7px] text-neutral-400 font-mono tracking-wider uppercase block">BADGES</span>
                </div>
              </div>

              <div className="space-y-1.5 pt-1">
                <span className="text-[8px] text-[#E5C180] font-bold uppercase tracking-widest block">Unlocked Ranks</span>
                <div className="flex justify-between items-center bg-[#050000] p-1.5 rounded-lg border border-neutral-900 text-[10px]">
                  <div className="flex items-center gap-1.5">
                    <Users className="w-3.5 h-3.5 text-emerald-400" />
                    <div>
                      <span className="font-bold text-white block">Elite Socialite</span>
                      <span className="text-neutral-500 text-[8px]">Interacted with full table feeds</span>
                    </div>
                  </div>
                  <span className="text-emerald-400 font-mono font-bold text-[8px]">UNLOCKED</span>
                </div>
                
                <div className="flex justify-between items-center bg-[#050000] p-1.5 rounded-lg border border-neutral-900 text-[10px]">
                  <div className="flex items-center gap-1.5">
                    <Flame className="w-3.5 h-3.5 text-rose-500" />
                    <div>
                      <span className="font-bold text-white block">VIP Patron</span>
                      <span className="text-neutral-500 text-[8px]">Redeemed premium draft drinks</span>
                    </div>
                  </div>
                  <span className="text-emerald-400 font-mono font-bold text-[8px]">UNLOCKED</span>
                </div>
              </div>
            </div>

            {/* referral code */}
            <div className="bg-[#C5A059]/5 border border-dashed border-[#C5A059]/30 rounded-xl p-3 text-center space-y-1">
              <span className="text-[9px] font-bold text-[#E5C180] tracking-wider font-serif uppercase">Refer Next Socialite</span>
              <p className="text-[9px] text-neutral-400 leading-normal">Share your invite code with friends. Both get 15 complimentary minutes at the bar!</p>
              <code className="text-xs text-white block font-mono bg-black py-0.5 rounded select-all cursor-pointer border border-[#C5A059]/20 font-bold">TIGER-MEMBER-07-VIP</code>
            </div>

            {/* CTA */}
            <div className="space-y-1.5 mt-2">
              <button 
                onClick={() => triggerPointsToast(0, "Instagram invite link copied!")}
                className="w-full h-10 bg-gradient-to-r from-[#B45309] to-[#8B0000] border border-[#C5A059]/40 text-[#E5C180] text-xs font-bold rounded-xl tracking-wider hover:brightness-110 flex items-center justify-center gap-1.5 transition-all shadow shadow-crimson-glow cursor-pointer"
              >
                <Share2 className="w-3 h-3" />
                POST REFERRAL CODE
              </button>

              <button 
                onClick={() => {
                  setTimeRemaining(30 * 60);
                  setScreen('active');
                  triggerPointsToast(10, 'Reservation extended successfully');
                }}
                className="w-full h-10 bg-neutral-900 border border-[#C5A059]/20 hover:border-[#C5A059]/45 text-white text-xs font-bold rounded-xl tracking-wider flex items-center justify-center gap-1 cursor-pointer"
              >
                <RefreshCw className="w-3 h-3 text-amber-500" />
                EXTEND RESERVATION (+30 MIN)
              </button>

              <button 
                onClick={() => {
                  setScreen('onboarding');
                  setDoorStatus('locked');
                  setDoorKnocks(0);
                }}
                className="w-full h-9 bg-[#120000] text-neutral-400 hover:text-white text-xs font-bold rounded-xl border border-neutral-900 transition-colors cursor-pointer"
              >
                Exit Simulation
              </button>
            </div>

          </div>
        )}

      </div>

      {/* OVERLAY: BRANCH SELECTOR */}
      {showBranchSelector && (
        <div className="absolute inset-x-3 bottom-3 top-3 bg-black/98 rounded-[42px] z-50 flex flex-col justify-between p-5 border border-[#C5A059]/35">
          <div>
            <div className="flex justify-between items-center mb-3">
              <span className="text-[8px] font-mono tracking-widest text-[#E5C180]">SELECT SANCTUARY BRANCH</span>
              <button 
                onClick={() => setShowBranchSelector(false)}
                className="p-1 bg-neutral-900 hover:bg-neutral-800 rounded-full text-white transition-all cursor-pointer"
              >
                <X className="w-3.5 h-3.5" />
              </button>
            </div>

            <div className="text-center space-y-1 mb-4">
              <Compass className="w-6 h-6 text-[#E5C180] mx-auto animate-spin" style={{ animationDuration: '6s' }} />
              <h3 className="text-sm font-serif font-black text-white uppercase">Check-In Club Branch</h3>
              <p className="text-[9px] text-neutral-400 max-w-[280px] mx-auto leading-normal">
                Check-in with GCash credentials. Your hours start counting down inside the club, allowing drink ordering.
              </p>
            </div>

            <div className="space-y-1.5">
              {CLUB_BRANCHES.map((branch) => {
                const isSelected = currentBranch === branch.name && isCheckedIn;
                return (
                  <button
                    key={branch.id}
                    onClick={() => {
                      setIsCheckedIn(true);
                      setCurrentBranch(branch.name);
                      triggerPointsToast(0, `Checked into ${branch.name}!`);
                      setShowBranchSelector(false);
                      setShowPausedOverlay(false); 
                    }}
                    className={`w-full text-left p-2.5 rounded-xl border transition-all flex items-center gap-2.5 cursor-pointer relative ${
                      isSelected 
                        ? 'border-emerald-500 bg-emerald-950/20 shadow-md' 
                        : 'border-[#C5A059]/25 bg-gradient-to-b from-[#1C0F00] to-[#0A0000] hover:border-[#C5A059]/40'
                    }`}
                  >
                    <div className="w-8 h-8 bg-neutral-950 rounded-xl border border-neutral-900 flex items-center justify-center shrink-0">
                      <span className="text-sm">{branch.icon}</span>
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="flex justify-between items-center">
                        <span className="font-bold text-[11px] text-white block truncate">{branch.name}</span>
                        <span className="text-[7px] text-neutral-400 font-mono tracking-wider bg-neutral-950 px-1 py-0.2 rounded uppercase">{branch.city}</span>
                      </div>
                      <span className="text-[8px] text-[#E5C180] font-mono block leading-none mt-0.5">{branch.ambience}</span>
                    </div>
                  </button>
                );
              })}
            </div>
          </div>

          <div className="mt-4 space-y-1.5">
            <button
              onClick={() => setShowBranchSelector(false)}
              className="w-full py-1.5 bg-neutral-950 text-neutral-400 hover:text-white text-[10px] font-semibold rounded-xl border border-neutral-900 cursor-pointer"
            >
              STAY PAUSED (Preserve Hours)
            </button>
          </div>
        </div>
      )}

      {/* OVERLAY: PAUSED ALERT */}
      {showPausedOverlay && (
        <div className="absolute inset-x-3 bottom-3 top-3 bg-black/98 rounded-[42px] z-50 flex flex-col justify-between p-6 border border-[#C5A059]/35">
          <div className="text-right">
            <button 
              onClick={() => setShowPausedOverlay(false)}
              className="p-1 bg-neutral-900 rounded-full text-white cursor-pointer"
            >
              <X className="w-3.5 h-3.5" />
            </button>
          </div>

          <div className="flex-1 flex flex-col items-center justify-center text-center space-y-3">
            <div className="w-12 h-12 rounded-full bg-[#8B0000]/30 border border-[#C5A059] flex items-center justify-center animate-pulse shadow-crimson-glow">
              <Clock className="w-5 h-5 text-[#E5C180]" />
            </div>
            
            <div className="space-y-1">
              <span className="text-[9px] font-mono tracking-widest text-amber-500 uppercase font-black">HOURS SECURELY PRESERVED</span>
              <h3 className="text-sm font-serif font-black text-white uppercase">Reservation Paused</h3>
              <p className="text-[10px] text-neutral-300 max-w-[240px] leading-relaxed">
                Drink ordering and turntable challenges are only active while checked-in to a speakeasy branch.
              </p>
            </div>
          </div>

          <div className="space-y-1.5 mt-4">
            <button
              onClick={() => {
                setShowPausedOverlay(false);
                setShowBranchSelector(true);
              }}
              className="w-full h-10 bg-gradient-to-r from-amber-500 to-[#C5A059] text-black font-black tracking-widest text-xs rounded-xl transition-all shadow-md flex items-center justify-center gap-1 cursor-pointer"
            >
              <Compass className="w-3.5 h-3.5 text-black" /> CHECK-IN NOW
            </button>
            <button
              onClick={() => setShowPausedOverlay(false)}
              className="w-full py-1.5 bg-neutral-950 text-neutral-400 hover:text-white text-[10px] font-semibold rounded-xl cursor-pointer"
            >
              BROWSE DISHES (Stay Paused)
            </button>
          </div>
        </div>
      )}

      {/* OVERLAY: ACTIVE COCKTAIL RECIPE VIEW */}
      {selectedDrink && (
        <div className="absolute inset-x-3 bottom-3 top-3 bg-black/98 rounded-[42px] z-50 flex flex-col justify-between p-5 overflow-y-auto border border-[#C5A059]/35">
          <div>
            <div className="flex justify-between items-center mb-3">
              <span className="text-[8px] font-mono tracking-widest text-[#E5C180]">MIXOLOGY RECIPE CARD</span>
              <button 
                onClick={() => setSelectedDrink(null)}
                className="p-1.5 bg-neutral-900 rounded-full text-white cursor-pointer"
              >
                <X className="w-3.5 h-3.5" />
              </button>
            </div>

            <div className={`w-full h-32 rounded-2xl bg-gradient-to-br ${selectedDrink.imageColor} border border-white/5 flex items-center justify-center relative overflow-hidden mb-3.5`}>
              <div className="absolute inset-0 bg-[radial-gradient(circle_at_center,rgba(255,255,255,0.05),transparent)]"></div>
              <Sparkles className="w-10 h-10 text-[#E5C180] animate-bounce" />
            </div>

            <div className="space-y-2.5">
              <div className="flex justify-between items-end">
                <div>
                  <h3 className="text-base font-serif font-black text-white">{selectedDrink.name}</h3>
                  <span className="text-[9px] text-[#E5C180] font-mono tracking-wider block">{selectedDrink.flavor}</span>
                </div>
                <div className="text-right">
                  <span className="text-xs font-mono font-black text-[#E5C180] block">{selectedDrink.price}</span>
                  <span className="text-[9px] font-mono font-bold text-red-400 block">- {formatSecondsToMins(getDrinkTimeCostSeconds(selectedDrink))} clock</span>
                </div>
              </div>

              <p className="text-[10.5px] text-neutral-300 leading-relaxed">{selectedDrink.description}</p>

              <blockquote className="border-l-2 border-[#C5A059] pl-2.5 py-1 text-[10.5px] italic text-[#E5C180] bg-[#8B0000]/10 rounded-r">
                {selectedDrink.bartenderQuote}
              </blockquote>

              <div className="space-y-1">
                <span className="text-[8px] text-neutral-500 font-bold uppercase tracking-widest block">Storytelling Ingredients</span>
                <div className="grid grid-cols-2 gap-1.5">
                  {selectedDrink.ingredients.map((ing) => (
                    <div key={ing} className="bg-neutral-950 p-1.5 rounded-lg text-[9px] text-white border border-neutral-900 flex items-center gap-1">
                      <Sparkles className="w-2 h-2 text-amber-500 shrink-0" />
                      <span className="truncate">{ing}</span>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          </div>

          <div className="space-y-2 mt-4">
            <button
              onClick={() => {
                if (!isCheckedIn) {
                  setShowPausedOverlay(true);
                } else if (timeRemaining < getDrinkTimeCostSeconds(selectedDrink)) {
                  triggerPointsToast(0, 'Insufficient Time! Extend your reservation first.');
                } else {
                  handleOrderDrink(selectedDrink);
                }
              }}
              className={`w-full h-10 text-black font-black tracking-widest text-[10px] rounded-xl flex items-center justify-center gap-1.5 transition-all border border-[#C5A059]/40 ${
                timeRemaining >= getDrinkTimeCostSeconds(selectedDrink)
                  ? 'bg-gradient-to-r from-amber-500 to-[#C5A059] hover:brightness-110 cursor-pointer shadow-md'
                  : 'bg-neutral-800 text-neutral-500 cursor-not-allowed border border-neutral-700'
              }`}
            >
              {timeRemaining >= getDrinkTimeCostSeconds(selectedDrink) ? (
                <>DEDUCT {formatSecondsToMins(getDrinkTimeCostSeconds(selectedDrink))} TIME</>
              ) : (
                <>INSUFFICIENT RESERVED TIME</>
              )}
            </button>
            <div className="text-center">
              <span className="text-[7.5px] text-neutral-500 font-mono">DRINK ORDERS DECREASE YOUR MAIN COUNTDOWN HOURS</span>
            </div>
          </div>
        </div>
      )}

      {/* OVERLAY: DISPLAY QR */}
      {showQrModal && (
        <div className="absolute inset-0 bg-black/98 z-50 flex flex-col justify-between p-6 border border-[#C5A059]/35">
          <div className="text-right">
            <button 
              onClick={() => setShowQrModal(false)}
              className="p-1.5 bg-neutral-900 rounded-full text-white cursor-pointer"
            >
              <X className="w-4 h-4" />
            </button>
          </div>

          <div className="flex-1 flex flex-col items-center justify-center text-center space-y-4">
            <span className="text-[9px] font-mono tracking-widest text-amber-500 block uppercase">Hold under Bartender scanner</span>
            
            <div className="p-3 bg-white rounded-3xl shadow-lg relative">
              <div className="w-40 h-40 bg-[#000] rounded-xl flex flex-col justify-between p-3 relative overflow-hidden">
                <div className="flex justify-between">
                  <div className="w-10 h-10 border-4 border-white"></div>
                  <div className="w-10 h-10 border-4 border-white"></div>
                </div>
                <div className="absolute inset-6 border border-amber-500 flex items-center justify-center font-mono text-[8px] text-white font-bold tracking-wider animate-pulse">
                  TIGER #07
                </div>
                <div className="flex justify-between">
                  <div className="w-10 h-10 border-4 border-white"></div>
                  <div className="w-5 h-5 bg-white self-end"></div>
                </div>
              </div>
            </div>

            <p className="text-[11px] text-neutral-300 max-w-[220px]">
              The bouncer and bartender terminal scans this key to authenticate your active table reservation.
            </p>
          </div>

          <div className="text-center">
            <span className="text-[8px] text-neutral-500 font-mono uppercase">Secure dynamic key v2.1</span>
          </div>
        </div>
      )}

      {/* OVERLAY: GAME PLAYING MODAL */}
      {activeGame && (
        <div className="absolute inset-x-3 bottom-3 top-3 bg-black/98 rounded-[42px] z-50 flex flex-col justify-between p-5 border border-[#C5A059]/35">
          <div>
            <div className="flex justify-between items-center mb-3">
              <span className="text-[8px] font-mono tracking-widest text-[#E5C180] uppercase">Speakeasy Cabaret Play</span>
              <button 
                onClick={() => {
                  setActiveGame(null);
                  setRouletteResult(null);
                  setGuessResult(null);
                  setShotScore(null);
                }}
                className="p-1.5 bg-neutral-900 rounded-full text-white cursor-pointer"
              >
                <X className="w-3.5 h-3.5" />
              </button>
            </div>

            <div className="text-center space-y-1">
              <div className="w-10 h-10 bg-neutral-950 border border-neutral-900 rounded-xl flex items-center justify-center mx-auto mb-1">
                {renderIcon(activeGame.icon, isMidnight)}
              </div>
              <h3 className="text-base font-serif font-black text-white">{activeGame.title}</h3>
              <p className="text-[10px] text-neutral-400 max-w-[240px] mx-auto leading-normal">{activeGame.description}</p>
            </div>

            {/* Render Game Specific Logic */}
            <div className="my-5 p-3.5 bg-neutral-950/80 rounded-2xl border border-[#C5A059]/20">
              
              {/* GAME 1: RETRO VINYL MULTIPLIER */}
              {activeGame.id === 'game-1' && (
                <div className="text-center space-y-3.5">
                  <div className="flex justify-center relative">
                    <div className={`w-28 h-28 rounded-full border-4 border-[#C5A059] flex items-center justify-center relative bg-black shadow-lg ${rouletteSpinning ? 'animate-spin' : ''}`} style={{ animationDuration: '2s' }}>
                      {/* turntable needle representation */}
                      <div className="absolute w-2.5 h-2.5 bg-amber-500 rounded-full"></div>
                      <div className="absolute top-2 w-1 h-8 bg-[#8B0000] rounded-full origin-bottom"></div>
                      <div className="w-14 h-14 rounded-full border-2 border-dashed border-neutral-800 flex items-center justify-center">
                        <Music className="w-4 h-4 text-amber-500" />
                      </div>
                    </div>
                  </div>

                  {rouletteResult ? (
                    <div className="p-2 bg-amber-500/10 border border-amber-500/30 rounded-lg text-[10px] text-amber-400 font-bold animate-pulse">
                      {rouletteResult}
                    </div>
                  ) : (
                    <p className="text-[9px] text-neutral-500">Tap spin to scratch the vinyl and align the tempo beats</p>
                  )}

                  <button
                    onClick={spinTurntable}
                    disabled={rouletteSpinning}
                    className="w-full py-1.5 bg-gradient-to-r from-amber-500 to-[#C5A059] text-black font-black text-[10px] rounded-xl hover:brightness-110 tracking-widest transition-all cursor-pointer"
                  >
                    {rouletteSpinning ? 'SPINNING DECK...' : 'SCRATCH THE VINYL'}
                  </button>
                </div>
              )}

              {/* GAME 2: COCKTAIL GUESS */}
              {activeGame.id === 'game-2' && (
                <div className="space-y-3.5">
                  <div className="space-y-1">
                    <span className="text-[8px] text-[#E5C180] font-bold uppercase block font-mono">BARTENDER'S HINT:</span>
                    <p className="text-[10px] text-neutral-300 italic bg-black p-2.5 rounded-lg border border-neutral-900 leading-relaxed">
                      "My first component is premium Single-barrel Bourbon, followed by pandan leaves infusion, aromatic bitters, orange oil, and a crystal ice sphere. What am I?"
                    </p>
                  </div>

                  {guessResult === 'correct' && (
                    <div className="p-2 bg-emerald-500/10 border border-emerald-500/30 rounded-lg text-[10px] text-emerald-400 text-center font-bold">
                      CORRECT! +25 points awarded!
                    </div>
                  )}

                  {guessResult === 'wrong' && (
                    <div className="p-2 bg-red-500/10 border border-red-500/30 rounded-lg text-[10px] text-rose-400 text-center font-bold">
                      INCORRECT. Hint: It's the "Tiger's Eye" cocktail.
                    </div>
                  )}

                  <div className="space-y-1.5">
                    <input
                      type="text"
                      value={guessInput}
                      onChange={(e) => setGuessInput(e.target.value)}
                      onKeyDown={(e) => e.key === 'Enter' && handleGuessSubmit()}
                      placeholder="Type signature drink name..."
                      className="w-full bg-[#050000] border border-neutral-800 text-white rounded-xl py-1.5 px-3 text-[11px] focus:outline-none focus:border-[#C5A059] text-center"
                    />
                    <button
                      onClick={handleGuessSubmit}
                      className="w-full py-1.5 bg-neutral-900 border border-neutral-800 text-white hover:border-[#C5A059] font-black text-[10px] rounded-xl tracking-widest transition-all cursor-pointer"
                    >
                      SUBMIT MIXOLOGY ANSWER
                    </button>
                  </div>
                </div>
              )}

              {/* GAME 3: BEAT SYNCHRONIZER */}
              {activeGame.id === 'game-3' && (
                <div className="text-center space-y-3.5">
                  <div className="flex justify-center">
                    <div className={`w-24 h-24 rounded-2xl border border-neutral-900 flex flex-col items-center justify-center relative bg-black overflow-hidden ${shotTimerActive ? 'ring-2 ring-purple-500' : ''}`}>
                      {shotTimerActive && (
                        <div className="absolute inset-0 bg-purple-500/20 animate-ping"></div>
                      )}
                      <Zap className={`w-6 h-6 ${shotTimerActive ? 'text-purple-400' : 'text-amber-500'}`} />
                      <span className="text-[7.5px] font-mono text-neutral-600 mt-1 uppercase tracking-wider">TAP ON NEON STROBE</span>
                    </div>
                  </div>

                  {shotScore !== null ? (
                    <div className="p-2 bg-emerald-500/10 border border-emerald-500/30 rounded-lg text-[10px] text-emerald-400 font-bold animate-pulse">
                      Timing accuracy: {shotScore}%! Unlocked +{Math.floor(shotScore/3.5)} pts!
                    </div>
                  ) : (
                    <p className="text-[9px] text-neutral-500 font-mono">Tap perfectly with the pulsing strobe light</p>
                  )}

                  <button
                    onClick={playShotChallenge}
                    disabled={shotTimerActive}
                    className="w-full py-1.5 bg-gradient-to-r from-[#B45309] to-[#8B0000] border border-[#C5A059]/30 text-[#E5C180] font-black text-[10px] rounded-xl hover:brightness-110 tracking-widest transition-all shadow cursor-pointer"
                  >
                    {shotTimerActive ? 'WAITING FOR BEAT...' : 'TAP ON THE BEAT!'}
                  </button>
                </div>
              )}

              {/* OTHER GAMES FALLBACK */}
              {activeGame.id !== 'game-1' && activeGame.id !== 'game-2' && activeGame.id !== 'game-3' && (
                <div className="text-center py-2 space-y-2.5">
                  <div className="w-8 h-8 bg-black rounded-xl border border-neutral-800 flex items-center justify-center mx-auto">
                    <Grid className="w-4 h-4 text-amber-500" />
                  </div>
                  <p className="text-[9px] text-neutral-400 leading-relaxed">Draw a high-end vintage card from The Blind Tiger deck to win entry passes and credits.</p>
                  <button
                    onClick={() => {
                      setPoints(p => p + 10);
                      triggerPointsToast(10, 'Card Drawn: +10 pts!');
                      setActiveGame(null);
                    }}
                    className="w-full py-1.5 bg-neutral-900 border border-neutral-800 hover:border-[#C5A059] text-white font-black text-[10px] rounded-xl cursor-pointer"
                  >
                    DRAW RANDOM DECK CARD (+10 pts)
                  </button>
                </div>
              )}

            </div>
          </div>

          <button
            onClick={() => {
              setActiveGame(null);
              setRouletteResult(null);
              setGuessResult(null);
              setShotScore(null);
            }}
            className="w-full py-1.5 bg-neutral-950 text-neutral-500 hover:text-white text-[10px] font-semibold rounded-xl border border-neutral-900 cursor-pointer"
          >
            RETURN TO SELECTION
          </button>
        </div>
      )}

        </div>
      )}
    </div>
  );
}
