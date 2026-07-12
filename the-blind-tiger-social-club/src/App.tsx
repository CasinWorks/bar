import React, { useState, useEffect } from 'react';
import { 
  Sparkles, Flame, Trophy, Clock, ShieldCheck, HelpCircle, 
  ChevronRight, ArrowRight, Lightbulb, CheckSquare, Zap, Beer, Music
} from 'lucide-react';
import { AvatarConfig, Challenge, FeedEvent, LeaderboardUser, PriceTier } from './types';
import { 
  INITIAL_CHALLENGES, INITIAL_FEED_EVENTS, INITIAL_LEADERBOARD, PRICE_TIERS 
} from './mockData';
import PhoneSimulator from './components/PhoneSimulator';
import ControlPanel from './components/ControlPanel';
import SpecsDoc from './components/SpecsDoc';

export default function App() {
  // Navigation & Core States
  const [currentScreen, setScreen] = useState<'onboarding' | 'avatar' | 'pricing' | 'checkout' | 'active' | 'summary'>('onboarding');
  const [timeRemaining, setTimeRemaining] = useState<number>(3600); // 1 hour default
  const [timeSpeed, setTimeSpeed] = useState<number>(1);
  const [points, setPoints] = useState<number>(108); // starting score (Socialite VII)
  const [drinksOrdered, setDrinksOrdered] = useState<number>(0);
  const [isCheckedIn, setIsCheckedIn] = useState<boolean>(true);
  const [currentBranch, setCurrentBranch] = useState<string>("BGC Secret Cellar");
  
  // Simulated Clock Hour of the night (8 = 8PM, 12 = 12AM/Midnight, 16 = 4AM)
  const [currentHour, setCurrentHour] = useState<number>(10); 

  // Custom states
  const [challenges, setChallenges] = useState<Challenge[]>(INITIAL_CHALLENGES);
  const [feedEvents, setFeedEvents] = useState<FeedEvent[]>(INITIAL_FEED_EVENTS);
  const [leaderboard, setLeaderboard] = useState<LeaderboardUser[]>(INITIAL_LEADERBOARD);
  const [selectedTier, setSelectedTier] = useState<PriceTier>(PRICE_TIERS[1]); // Default 60 min
  
  // Custom Avatar matching Retro Blind Tiger
  const [avatar, setAvatar] = useState<AvatarConfig>({
    hair: 'TF', // Tiger-Stripe Fedora
    eyes: 'SV', // Smoky Velvet Eyes
    accessory: 'GP', // Gold Tiger Lapel Pin
    color: '#D97706', // Tiger Orange
    name: 'TigerGuest_07'
  });

  // Toast System for feedback
  const [toasts, setToasts] = useState<{ id: string; amount: number; reason: string }[]>([]);

  const triggerPointsToast = (amount: number, reason: string) => {
    const id = Math.random().toString(36).substring(2, 9);
    setToasts(prev => [...prev, { id, amount, reason }]);
    setTimeout(() => {
      setToasts(prev => prev.filter(t => t.id !== id));
    }, 3500);
  };

  // 1. Real-time Timer reduce loop
  useEffect(() => {
    const interval = setInterval(() => {
      if (currentScreen === 'active' && isCheckedIn) {
        setTimeRemaining(prev => {
          if (prev <= 1) {
            clearInterval(interval);
            setScreen('summary');
            return 0;
          }
          return prev - 1;
        });
      }
    }, 1000 / timeSpeed);

    return () => clearInterval(interval);
  }, [currentScreen, timeSpeed, isCheckedIn]);

  // 2. Real-time Leaderboard updater (sorting & tier updates based on active timeRemaining)
  useEffect(() => {
    setLeaderboard(prev => {
      const updated = prev.map(user => {
        if (user.isCurrentUser) {
          // Determine luxury tier based on remaining time currency
          let tier: 'Bronze' | 'Silver' | 'Gold' | 'Platinum' = 'Silver';
          if (timeRemaining >= 10800) tier = 'Platinum'; // > 3.0 Hours
          else if (timeRemaining >= 5400) tier = 'Gold'; // > 1.5 Hours
          else if (timeRemaining >= 2700) tier = 'Silver'; // > 45 mins
          else tier = 'Bronze'; // < 45 mins

          return { ...user, points, tier, timeBalance: timeRemaining };
        }
        return user;
      });

      // Sort by timeBalance descending
      const sorted = [...updated].sort((a, b) => {
        const balA = a.timeBalance ?? 0;
        const balB = b.timeBalance ?? 0;
        return balB - balA;
      });
      
      // Re-assign ranks
      return sorted.map((user, idx) => ({ ...user, rank: idx + 1 }));
    });
  }, [timeRemaining, points]);

  // Format hour number to elegant display string
  const getFormattedHourString = (h: number) => {
    if (h === 12) return "12:00 AM (MIDNIGHT)";
    if (h > 12) return `${h - 12}:00 AM`;
    return `${h}:00 PM`;
  };

  const isMidnightOrLater = currentHour >= 12;

  return (
    <div className="min-h-screen bg-[#050200] text-neutral-200 flex flex-col font-sans chinese-lattice transition-colors duration-1000">
      
      {/* Header Banner bar */}
      <header className={`bg-gradient-to-r ${isMidnightOrLater ? 'from-[#1A0933] to-[#0A0214] border-[#7C3AED]/40 shadow-purple-glow' : 'from-[#1A0A00] to-[#050200] border-[#C5A059]/30 shadow-crimson-glow'} border-b px-6 py-4 flex items-center justify-between sticky top-0 z-40 transition-all duration-1000`}>
        <div className="flex items-center gap-3">
          <div className={`w-10 h-10 rounded-xl bg-gradient-to-br ${isMidnightOrLater ? 'from-[#7C3AED] to-[#3B0764]' : 'from-[#D97706] to-[#78350F]'} border border-[#C5A059]/50 flex items-center justify-center font-bold text-[#E5C180] shadow-lg transition-all duration-1000`}>
            🐯
          </div>
          <div>
            <h1 className="text-sm font-serif font-bold text-white uppercase tracking-widest flex items-center gap-2">
              THE BLIND TIGER <span className={`text-[9px] ${isMidnightOrLater ? 'bg-purple-600 text-white animate-pulse' : 'bg-gold-gradient text-black'} px-2 py-0.5 rounded font-serif font-black tracking-widest transition-all duration-1000`}>
                {isMidnightOrLater ? '🕺 MICROCLUB MODE' : '🌶️ SPEAKEASY MODE'}
              </span>
            </h1>
            <p className="text-[11px] text-neutral-400 font-serif italic">
              "A hidden nightclub that transforms at midnight - cocktails first, dancing after."
            </p>
          </div>
        </div>

        {/* Outer Quick Info */}
        <div className="hidden md:flex items-center gap-6 text-xs font-mono">
          <div className="flex items-center gap-2">
            <span className={`w-2.5 h-2.5 rounded-full ${isMidnightOrLater ? 'bg-purple-500 animate-ping' : 'bg-amber-500 animate-pulse'}`}></span>
            <span className={`${isMidnightOrLater ? 'text-purple-400' : 'text-[#E5C180]'} font-bold transition-colors duration-1000`}>
              CLOCK: {getFormattedHourString(currentHour)}
            </span>
          </div>
          <div className="text-neutral-400 border-l border-[#C5A059]/30 pl-6 uppercase">
            ACTIVE GATE: <strong className="text-white uppercase font-serif tracking-wider">{currentScreen}</strong>
          </div>
        </div>
      </header>

      {/* Main Container Layout split */}
      <main className="flex-1 grid grid-cols-1 lg:grid-cols-12 gap-6 p-6 max-w-7xl w-full mx-auto">
        
        {/* Left Column: Phone Simulator View (col-span-4) */}
        <div className="lg:col-span-5 xl:col-span-4 flex flex-col items-center justify-center relative">
          
          {/* Subtle Ambient Glow behind phone */}
          <div className={`absolute w-[300px] h-[500px] ${isMidnightOrLater ? 'bg-[#7C3AED]/15' : 'bg-[#D97706]/10'} rounded-full blur-[100px] -z-10 pointer-events-none transition-all duration-1000`}></div>

          {/* Floating Points Toasts Stack */}
          <div className="absolute top-4 right-[-20px] z-50 flex flex-col gap-2 pointer-events-none max-w-[200px]">
            {toasts.map((t) => (
              <div 
                key={t.id} 
                className={`p-3 rounded-xl bg-gradient-to-br from-[#1A0A00] to-[#050200] border-2 ${isMidnightOrLater ? 'border-[#7C3AED]' : 'border-[#C5A059]'} shadow-lg text-xs animate-bounce chinese-cloud`}
              >
                <div className="flex items-center gap-1.5 text-[#E5C180] font-black">
                  <Sparkles className="w-3.5 h-3.5 text-[#E5C180]" />
                  <span className="font-serif">+{t.amount > 0 ? t.amount : '5'} PTS</span>
                </div>
                <p className="text-[10px] text-neutral-300 font-medium mt-0.5">{t.reason}</p>
              </div>
            ))}
          </div>

          <PhoneSimulator
            currentScreen={currentScreen}
            setScreen={setScreen}
            timeRemaining={timeRemaining}
            setTimeRemaining={setTimeRemaining}
            timeSpeed={timeSpeed}
            points={points}
            setPoints={setPoints}
            drinksOrdered={drinksOrdered}
            setDrinksOrdered={setDrinksOrdered}
            challenges={challenges}
            setChallenges={setChallenges}
            feedEvents={feedEvents}
            setFeedEvents={setFeedEvents}
            leaderboard={leaderboard}
            setLeaderboard={setLeaderboard}
            avatar={avatar}
            setAvatar={setAvatar}
            selectedTier={selectedTier}
            setSelectedTier={setSelectedTier}
            triggerPointsToast={triggerPointsToast}
            isCheckedIn={isCheckedIn}
            setIsCheckedIn={setIsCheckedIn}
            currentBranch={currentBranch}
            setCurrentBranch={setCurrentBranch}
            currentHour={currentHour}
            setCurrentHour={setCurrentHour}
          />

          <p className="text-center text-[11px] text-neutral-500 mt-3 italic font-mono">
            *Device frame simulates a premium Blind Tiger Member’s Smart Pass
          </p>
        </div>

        {/* Right Column: Split of Control Panel & Design System documentation (col-span-8) */}
        <div className="lg:col-span-7 xl:col-span-8 grid grid-cols-1 md:grid-cols-2 gap-6">
          
          {/* Controls column */}
          <div className="space-y-6 flex flex-col justify-start">
            
            <div className={`bg-gradient-to-br ${isMidnightOrLater ? 'from-[#17052E] to-[#05000C] border-[#7C3AED]/30' : 'from-[#1A0F00] to-[#050200] border-[#C5A059]/30'} border rounded-2xl p-5 space-y-4 shadow-lg relative overflow-hidden chinese-cloud transition-all duration-1000`}>
              <h3 className="text-sm font-serif font-bold text-white uppercase tracking-wider flex items-center gap-1.5">
                <Lightbulb className="text-[#E5C180] w-4 h-4" /> The Hybrid Formula
              </h3>
              <p className="text-xs text-neutral-300 leading-relaxed font-sans">
                {isMidnightOrLater ? (
                  <>
                    At midnight, the quiet lounge transitions to <strong className="text-purple-400 font-bold">Microclub Mode</strong>. Standing-room DJ sets (disco, soul, Latin) fill the floor, capacity increases to <strong className="text-white">50 pax</strong>, beer sells for ₱200, and guests can book VIP tables (₱5K min spend).
                  </>
                ) : (
                  <>
                    From 8PM to 12AM, the app operates in <strong className="text-[#E5C180] font-bold">Speakeasy Mode</strong>. An intimate, seated environment with a <strong className="text-white">30-comfort seat limit</strong>, serving storytelling craft cocktails (₱350-600) with a ₱500 cover charge.
                  </>
                )}
              </p>
              
              <div className="p-3 bg-[#050200]/90 rounded-xl border border-[#C5A059]/20 grid grid-cols-2 gap-2 text-center text-xs">
                <div>
                  <span className="text-[10px] text-neutral-400 font-mono block">ROOM CAPACITY</span>
                  <span className="font-serif font-bold text-white">
                    {isMidnightOrLater ? "42 / 50 PAX" : "18 / 30 SEATED"}
                  </span>
                </div>
                <div>
                  <span className="text-[10px] text-[#E5C180] font-mono block">ACTIVE ENTERTAINMENT</span>
                  <span className="font-serif font-bold text-[#E5C180] flex items-center justify-center gap-1">
                    <Music className="w-3 h-3 text-amber-500 animate-pulse" />
                    {isMidnightOrLater ? "Vinyl DJ Set" : "Live Jazz Trio"}
                  </span>
                </div>
              </div>
            </div>

            <ControlPanel
              currentScreen={currentScreen}
              setScreen={setScreen}
              timeRemaining={timeRemaining}
              setTimeRemaining={setTimeRemaining}
              timeSpeed={timeSpeed}
              setTimeSpeed={setTimeSpeed}
              points={points}
              setPoints={setPoints}
              drinksOrdered={drinksOrdered}
              setDrinksOrdered={setDrinksOrdered}
              challenges={challenges}
              setChallenges={setChallenges}
              feedEvents={feedEvents}
              setFeedEvents={setFeedEvents}
              avatar={avatar}
              triggerPointsToast={triggerPointsToast}
              isCheckedIn={isCheckedIn}
              setIsCheckedIn={setIsCheckedIn}
              currentBranch={currentBranch}
              setCurrentBranch={setCurrentBranch}
              currentHour={currentHour}
              setCurrentHour={setCurrentHour}
            />
          </div>

          {/* Docs/Specifications column */}
          <div className="rounded-2xl overflow-hidden border border-neutral-900 h-[640px] shadow-lg">
            <SpecsDoc />
          </div>

        </div>

      </main>

      {/* Footer copyright */}
      <footer className="bg-[#050200] border-t border-neutral-900 py-4 px-6 text-center text-xs text-neutral-600">
        Google AI Studio Build • The Blind Tiger Social Club UI/UX Mockup. Built with pristine layout, custom typography, and dynamic interactive state.
      </footer>
    </div>
  );
}
