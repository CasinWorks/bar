import React from 'react';
import { 
  Sliders, FastForward, Award, Coffee, RefreshCw, AlertCircle, 
  Plus, Play, CheckCircle, ChevronRight, Volume2, ShieldAlert, Clock, Music
} from 'lucide-react';
import { AvatarConfig, PriceTier, Challenge, FeedEvent, LeaderboardUser } from '../types';

interface ControlPanelProps {
  currentScreen: 'onboarding' | 'avatar' | 'pricing' | 'checkout' | 'active' | 'summary';
  setScreen: (screen: 'onboarding' | 'avatar' | 'pricing' | 'checkout' | 'active' | 'summary') => void;
  timeRemaining: number;
  setTimeRemaining: React.Dispatch<React.SetStateAction<number>>;
  timeSpeed: number;
  setTimeSpeed: (speed: number) => void;
  points: number;
  setPoints: React.Dispatch<React.SetStateAction<number>>;
  drinksOrdered: number;
  setDrinksOrdered: (count: number) => void;
  challenges: Challenge[];
  setChallenges: React.Dispatch<React.SetStateAction<Challenge[]>>;
  feedEvents: FeedEvent[];
  setFeedEvents: React.Dispatch<React.SetStateAction<FeedEvent[]>>;
  avatar: AvatarConfig;
  triggerPointsToast: (amount: number, reason: string) => void;
  isCheckedIn: boolean;
  setIsCheckedIn: (val: boolean) => void;
  currentBranch: string;
  setCurrentBranch: (branch: string) => void;
  currentHour: number;
  setCurrentHour: (hour: number) => void;
}

export default function ControlPanel({
  currentScreen,
  setScreen,
  timeRemaining,
  setTimeRemaining,
  timeSpeed,
  setTimeSpeed,
  points,
  setPoints,
  drinksOrdered,
  setDrinksOrdered,
  challenges,
  setChallenges,
  feedEvents,
  setFeedEvents,
  avatar,
  triggerPointsToast,
  isCheckedIn,
  setIsCheckedIn,
  currentBranch,
  setCurrentBranch,
  currentHour,
  setCurrentHour,
}: ControlPanelProps) {

  // Force critical state (e.g. 4 minutes 50 seconds remaining)
  const handleForceCritical = () => {
    setTimeRemaining(290); // 4m 50s
    setScreen('active');
    triggerPointsToast(0, 'System Alert: Reservation went CRITICAL 🚨');
  };

  // Force warning state (e.g. 14 minutes 30 seconds remaining)
  const handleForceWarning = () => {
    setTimeRemaining(870); // 14m 30s
    setScreen('active');
    triggerPointsToast(0, 'System Alert: Reservation went WARNING ⚠️');
  };

  // Reset all state to defaults
  const handleReset = () => {
    setScreen('onboarding');
    setTimeRemaining(3600); // 1 hour
    setTimeSpeed(1);
    setPoints(108); // default starting points
    setDrinksOrdered(0);
    setCurrentHour(10); // 10:00 PM
    // Reset challenges count
    setChallenges(prev => prev.map(chal => ({ ...chal, currentCount: 0, claimed: false })));
    triggerPointsToast(0, 'Simulation State fully reset 🐯');
  };

  // Inject feed event
  const handleInjectFeedEvent = () => {
    const names = ['ManilaMogul', 'JazzSasha_9', 'DiscoDiva', 'Vince_Beat', 'LoungeQueen', 'PoblacionKing'];
    const selectedName = names[Math.floor(Math.random() * names.length)];
    const drinks = [
      "Tiger’s Eye Old Fashioned 🥃", 
      "Manila Dusk Sour 🍹", 
      "The Velvet Midnight ☕", 
      "Jazz Age Highball 🍋",
      "San Miguel Tiger Draft 🍺"
    ];
    const selectedDrink = drinks[Math.floor(Math.random() * drinks.length)];
    
    const newEvent: FeedEvent = {
      id: `inject-${Date.now()}`,
      avatarSeed: {
        hair: ['DP', 'JW', 'MS', 'DS', 'TF'][Math.floor(Math.random() * 5)],
        eyes: ['CA', 'CE', 'SV', 'IM', 'VW'][Math.floor(Math.random() * 5)],
        accessory: ['GP', 'RC', 'CC', 'SL', 'PE'][Math.floor(Math.random() * 5)],
        color: ['#D97706', '#8B0000', '#0F766E', '#7C3AED', '#B45309'][Math.floor(Math.random() * 5)]
      },
      userName: selectedName,
      userRank: `#${Math.floor(Math.random() * 4) + 1}`,
      isFriend: Math.random() > 0.5,
      timeAgo: 'Just now',
      eventText: `ordered a round of ${selectedDrink} at Table ${Math.floor(Math.random() * 12) + 1}!`,
      likes: { luxe: Math.floor(Math.random() * 5), salute: Math.floor(Math.random() * 3), gold: 0 },
    };

    setFeedEvents([newEvent, ...feedEvents]);
    triggerPointsToast(0, `Live feed order injected: ${selectedName}`);
  };

  // Simulate drinking (progress drink challenges)
  const handleSimulateDrink = () => {
    setDrinksOrdered(drinksOrdered + 1);
    
    setChallenges(prev => prev.map(chal => {
      if (chal.category === 'drink' && !chal.claimed) {
        return { ...chal, currentCount: Math.min(chal.targetCount, chal.currentCount + 1) };
      }
      return chal;
    }));

    triggerPointsToast(5, 'Cocktail ordered and prepared! 🍸');
    setPoints(p => p + 10);
  };

  // Add 25 Points directly
  const handleAddPoints = () => {
    setPoints(p => p + 25);
    triggerPointsToast(25, 'Admin points injection 🐯');
  };

  const getFormattedHour = (h: number) => {
    if (h === 12) return "12:00 AM (Midnight)";
    if (h > 12) return `${h - 12}:00 AM`;
    return `${h}:00 PM`;
  };

  return (
    <div id="speakeasy-console-container" className="bg-gradient-to-br from-[#1C0F00] to-[#050000] text-neutral-200 p-5 rounded-2xl border border-[#C5A059]/30 space-y-5 font-sans h-fit relative overflow-hidden shadow-crimson-glow chinese-cloud">
      
      {/* Header */}
      <div className="flex items-center gap-2 border-b border-[#C5A059]/20 pb-3">
        <Sliders className="w-5 h-5 text-[#E5C180]" />
        <div>
          <h3 className="text-sm font-serif font-black tracking-widest text-white uppercase flex items-center gap-1.5">
            BLIND TIGER MANAGER <span className="text-[8px] bg-gold-gradient text-black px-1 rounded font-sans font-bold">ADMIN</span>
          </h3>
          <p className="text-[10px] text-[#C5A059] font-mono">HYBRID FORMULA TELEMETRY OVERRIDES</p>
        </div>
      </div>

      {/* Hour Simulation Control */}
      <div className="space-y-2 bg-[#0C0500] p-3 rounded-xl border border-[#C5A059]/20">
        <div className="flex justify-between items-center text-xs">
          <span className="text-neutral-300 font-bold font-serif flex items-center gap-1">
            <Clock className="w-3.5 h-3.5 text-amber-500" /> Simulated Clock Hour:
          </span>
          <span className="font-mono text-[#E5C180] font-black">{getFormattedHour(currentHour)}</span>
        </div>
        
        <input 
          type="range" 
          min="8" 
          max="16" 
          value={currentHour} 
          onChange={(e) => {
            const h = parseInt(e.target.value);
            setCurrentHour(h);
            triggerPointsToast(0, `Simulated hour set to ${getFormattedHour(h)} ⏰`);
          }}
          className="w-full accent-amber-500 bg-neutral-900 h-2 rounded-lg cursor-pointer"
        />

        <div className="flex justify-between text-[9px] font-mono text-neutral-400">
          <span>8:00 PM (Speakeasy)</span>
          <span className="text-[#C5A059] font-serif">12AM Midnight (Microclub)</span>
          <span>4:00 AM</span>
        </div>
        <p className="text-[9px] text-neutral-400 leading-normal pt-1 border-t border-neutral-900">
          Slide past **12:00 AM (Midnight)** to see the entire companion app, visual atmosphere, crowd count, and menu transform into the high-energy **Microclub Mode**.
        </p>
      </div>

      {/* Screen Selector Jumper */}
      <div className="space-y-1.5">
        <label className="text-[10px] text-[#C5A059] font-bold uppercase tracking-widest block font-serif">Gate Screen Jumper</label>
        <div className="grid grid-cols-3 gap-1.5 text-[10px] font-mono">
          {[
            { id: 'onboarding', label: '1. Cover Door' },
            { id: 'avatar', label: '2. Identity' },
            { id: 'pricing', label: '3. Passport' },
            { id: 'checkout', label: '4. Register' },
            { id: 'active', label: '5. Lounge Hub' },
            { id: 'summary', label: '6. Receipt' },
          ].map((scr) => (
            <button
              key={scr.id}
              onClick={() => setScreen(scr.id as any)}
              className={`py-1.5 rounded border text-center transition-all cursor-pointer ${
                currentScreen === scr.id 
                  ? 'border-[#C5A059] text-[#E5C180] bg-[#8B0000]/30 font-bold shadow-[0_0_8px_rgba(197,160,89,0.25)]' 
                  : 'border-neutral-800 bg-[#0D0000]/50 text-neutral-400 hover:border-neutral-700 hover:text-white'
              }`}
            >
              {scr.label}
            </button>
          ))}
        </div>
      </div>

      {/* Time dilation */}
      <div className="space-y-2 bg-[#0D0000]/90 p-3 rounded-xl border border-[#C5A059]/20">
        <div className="flex justify-between items-center text-xs">
          <span className="text-neutral-300 font-bold font-serif">Timer Speed Multiplier:</span>
          <span className="font-mono text-[#E5C180] font-black">{timeSpeed}x Speed</span>
        </div>
        
        <div className="flex gap-2">
          {[1, 10, 60, 300].map((sp) => (
            <button
              key={sp}
              onClick={() => setTimeSpeed(sp)}
              className={`flex-1 py-1 rounded text-xs font-mono font-bold transition-all cursor-pointer ${
                timeSpeed === sp 
                  ? 'bg-gradient-to-r from-[#B45309] to-[#8B0000] text-white border border-[#C5A059]/40' 
                  : 'bg-neutral-900 hover:bg-neutral-800 text-neutral-400'
              }`}
            >
              {sp === 1 ? 'Real' : `${sp}x`}
            </button>
          ))}
        </div>
        <p className="text-[9px] text-neutral-400 leading-normal">
          Accelerate countdown decay to experience warning alert cycles rapidly (Warning <span className="text-amber-500 font-semibold">Yellow</span> at 15m, and Critical pulsing <span className="text-red-500 font-semibold">Red</span> at 5m).
        </p>
      </div>

      {/* Active Check-In & Branch */}
      <div className="space-y-2 bg-[#1A0000]/40 p-3 rounded-xl border border-[#C5A059]/15">
        <div className="flex justify-between items-center text-xs">
          <span className="text-neutral-300 font-bold font-serif">Check-In Status:</span>
          <span className={`font-mono font-black text-xs ${isCheckedIn ? 'text-emerald-400' : 'text-red-400'}`}>
            {isCheckedIn ? '✓ AT THE CLUB' : '❄️ PASS FROZEN'}
          </span>
        </div>
        
        <div className="grid grid-cols-2 gap-2 text-xs">
          <button
            onClick={() => {
              setIsCheckedIn(true);
              triggerPointsToast(0, 'Checked In via Telemetry Override 🐯');
            }}
            className={`py-1.5 rounded font-bold transition-colors cursor-pointer text-center ${isCheckedIn ? 'bg-gradient-to-r from-[#B45309] to-[#8B0000] text-white border border-[#C5A059]/40 shadow-sm' : 'bg-[#0D0000]/60 text-neutral-400 border border-neutral-900 hover:text-white'}`}
          >
            🐯 Check-In
          </button>
          <button
            onClick={() => {
              setIsCheckedIn(false);
              triggerPointsToast(0, 'Reservation Frozen via Override ❄️');
            }}
            className={`py-1.5 rounded font-bold transition-colors cursor-pointer text-center ${!isCheckedIn ? 'bg-gradient-to-r from-[#B45309] to-[#8B0000] text-white border border-[#C5A059]/40' : 'bg-[#0D0000]/60 text-neutral-400 border border-neutral-900 hover:text-white'}`}
          >
            ❄️ Freeze Pass
          </button>
        </div>

        <div className="pt-1.5 space-y-1 border-t border-[#C5A059]/15">
          <span className="text-[9px] text-[#C5A059] font-bold uppercase tracking-widest block font-serif">Active Lounge Venue</span>
          <div className="grid grid-cols-2 gap-1.5 text-[10px] font-mono">
            {[
              'BGC Secret Cellar',
              'Poblacion Velvet Room',
              'Makati Glasshouse',
              'Tomas Morato Lounge'
            ].map((br) => (
              <button
                key={br}
                onClick={() => {
                  setCurrentBranch(br);
                  triggerPointsToast(0, `Club venue set to ${br} 📍`);
                }}
                className={`py-1 rounded border text-center transition-all truncate px-1 cursor-pointer ${
                  currentBranch === br 
                    ? 'border-[#C5A059] text-[#E5C180] bg-[#8B0000]/20 font-bold' 
                    : 'border-neutral-900 bg-[#0A0000]/50 hover:border-neutral-800'
                }`}
              >
                {br.split(' ')[1]} {/* short name */}
              </button>
            ))}
          </div>
        </div>
      </div>

      {/* Quick Alerts and States */}
      <div className="space-y-1.5">
        <label className="text-[10px] text-[#C5A059] font-bold uppercase tracking-widest block font-serif">Trigger Alert states</label>
        <div className="grid grid-cols-2 gap-2">
          <button
            onClick={handleForceWarning}
            className="py-1.5 bg-neutral-950 hover:bg-neutral-900 border border-amber-900/40 rounded-xl text-xs text-amber-500 transition-all flex items-center justify-center gap-1.5 font-medium cursor-pointer"
          >
            <AlertCircle className="w-3.5 h-3.5" />
            Warning State (14:30)
          </button>
          <button
            onClick={handleForceCritical}
            className="py-1.5 bg-neutral-950 hover:bg-neutral-900 border border-red-900/40 rounded-xl text-xs text-red-500 transition-all flex items-center justify-center gap-1.5 font-medium cursor-pointer"
          >
            <ShieldAlert className="w-3.5 h-3.5" />
            Critical State (4:50)
          </button>
        </div>
      </div>

      {/* Trigger simulated interactions */}
      <div className="space-y-1.5">
        <label className="text-[10px] text-[#C5A059] font-bold uppercase tracking-widest block font-serif">Interactive Events</label>
        <div className="space-y-2">
          <button
            onClick={handleSimulateDrink}
            className="w-full py-2 bg-[#0D0000] hover:bg-[#1A0000] border border-[#C5A059]/20 rounded-xl text-xs text-white flex items-center justify-center gap-2 transition-all font-medium cursor-pointer"
          >
            <Coffee className="w-4 h-4 text-[#E5C180]" />
            Simulate Drinking (+1 Drink & Challenge)
          </button>

          <button
            onClick={handleInjectFeedEvent}
            className="w-full py-2 bg-[#0D0000] hover:bg-[#1A0000] border border-[#C5A059]/20 rounded-xl text-xs text-white flex items-center justify-center gap-2 transition-all font-medium cursor-pointer"
          >
            <Plus className="w-4 h-4 text-[#E5C180]" />
            Inject Simulated Live Order in Feed
          </button>

          <button
            onClick={handleAddPoints}
            className="w-full py-2 bg-[#0D0000] hover:bg-[#1A0000] border border-[#C5A059]/20 rounded-xl text-xs text-[#E5C180] flex items-center justify-center gap-2 transition-all font-medium cursor-pointer"
          >
            <FastForward className="w-4 h-4 text-[#C5A059]" />
            Inject +25 Points (Move Up Rankings)
          </button>
        </div>
      </div>

      {/* Reset State button */}
      <div className="border-t border-[#C5A059]/20 pt-3">
        <button
          onClick={handleReset}
          className="w-full py-2 bg-[#8B0000]/10 hover:bg-[#8B0000]/25 text-red-400 border border-[#8B0000]/25 hover:border-[#8B0000]/50 text-xs font-serif font-bold rounded-xl flex items-center justify-center gap-1.5 transition-all cursor-pointer"
        >
          <RefreshCw className="w-3.5 h-3.5" />
          RESET SIMULATION STATE
        </button>
      </div>

    </div>
  );
}
