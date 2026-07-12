import React, { useState } from 'react';
import { Copy, Check, Eye, HelpCircle, Code, MessageCircle, Sliders, CheckSquare } from 'lucide-react';

export default function SpecsDoc() {
  const [copiedColor, setCopiedColor] = useState<string | null>(null);
  const [activeTab, setActiveTab] = useState<'system' | 'interactions' | 'copy' | 'checklist'>('system');

  const copyToClipboard = (hex: string) => {
    navigator.clipboard.writeText(hex);
    setCopiedColor(hex);
    setTimeout(() => setCopiedColor(null), 2000);
  };

  const colors = [
    { hex: '#D97706', name: 'Tiger Orange', desc: 'Primary branding, neon glowing indicators, core state overlays' },
    { hex: '#8B0000', name: 'Velvet Burgundy', desc: 'Speakeasy cosy lounge backdrop, secondary buttons, warm lamps' },
    { hex: '#C5A059', name: 'Brushed Brass Gold', desc: 'Art Deco trim, borders, dividers, luxury tier text and badges' },
    { hex: '#0F766E', name: 'Emerald Teal', desc: 'Muted active states, leather chair textures, vintage cocktail accents' },
    { hex: '#E5C180', name: 'Bright Deco Gold', desc: 'High-contrast text highlights, claim buttons, premium labels' },
    { hex: '#7C3AED', name: 'Neon Purple / Violet', desc: 'Midnight Microclub state, strobe light overlays, bottle service badges' },
    { hex: '#B45309', name: 'Brass Amber', desc: 'Warning timer states, ambient light filters, retro warm lighting' },
    { hex: '#050000', name: 'Speakeasy Absolute Black', desc: 'Base device mockup, system drawers, pure solid shadow backings' },
  ];

  return (
    <div id="designer-suite-panel" className="bg-gradient-to-b from-[#1E0F00] to-[#050000] border-l border-[#C5A059]/30 text-neutral-300 h-full overflow-y-auto flex flex-col font-sans relative chinese-cloud">
      {/* Panel Header */}
      <div className="p-5 border-b border-[#C5A059]/20 bg-gradient-to-r from-[#2A1000] to-[#0C0000]">
        <div className="flex items-center gap-2">
          <span className="p-1.5 rounded-md bg-[#8B0000]/20 text-[#E5C180] border border-[#C5A059]/30 animate-pulse">
            <Code className="w-5 h-5" />
          </span>
          <div>
            <h2 className="text-sm font-serif font-black text-white tracking-widest">THE BLIND TIGER DESIGN SUITE</h2>
            <p className="text-[10px] text-[#C5A059] font-serif uppercase tracking-wider">Luxury Club UX/UI Specifications & Visual Tokens</p>
          </div>
        </div>

        {/* Tab Selection */}
        <div className="flex gap-1 mt-4 bg-[#0A0000] p-1 rounded-lg border border-[#C5A059]/15 text-[10px]">
          <button
            onClick={() => setActiveTab('system')}
            className={`flex-1 py-1.5 rounded-md transition-all font-serif font-bold tracking-wider flex items-center justify-center gap-1 cursor-pointer ${
              activeTab === 'system' ? 'bg-gradient-to-r from-[#B45309] to-[#8B0000] text-[#E5C180] border border-[#C5A059]/30' : 'hover:bg-neutral-900 text-neutral-400'
            }`}
          >
            <Sliders className="w-3 h-3" />
            Palette
          </button>
          <button
            onClick={() => setActiveTab('interactions')}
            className={`flex-1 py-1.5 rounded-md transition-all font-serif font-bold tracking-wider flex items-center justify-center gap-1 cursor-pointer ${
              activeTab === 'interactions' ? 'bg-gradient-to-r from-[#B45309] to-[#8B0000] text-[#E5C180] border border-[#C5A059]/30' : 'hover:bg-neutral-900 text-neutral-400'
            }`}
          >
            <Eye className="w-3 h-3" />
            Behaviors
          </button>
          <button
            onClick={() => setActiveTab('copy')}
            className={`flex-1 py-1.5 rounded-md transition-all font-serif font-bold tracking-wider flex items-center justify-center gap-1 cursor-pointer ${
              activeTab === 'copy' ? 'bg-gradient-to-r from-[#B45309] to-[#8B0000] text-[#E5C180] border border-[#C5A059]/30' : 'hover:bg-neutral-900 text-neutral-400'
            }`}
          >
            <MessageCircle className="w-3 h-3" />
            Tone
          </button>
          <button
            onClick={() => setActiveTab('checklist')}
            className={`flex-1 py-1.5 rounded-md transition-all font-serif font-bold tracking-wider flex items-center justify-center gap-1 cursor-pointer ${
              activeTab === 'checklist' ? 'bg-gradient-to-r from-[#B45309] to-[#8B0000] text-[#E5C180] border border-[#C5A059]/30' : 'hover:bg-neutral-900 text-neutral-400'
            }`}
          >
            <CheckSquare className="w-3 h-3" />
            Assets
          </button>
        </div>
      </div>

      {/* Content Area */}
      <div className="p-5 flex-1 space-y-6">
        
        {/* TAB 1: DESIGN SYSTEM PALETTE */}
        {activeTab === 'system' && (
          <div className="space-y-4">
            <div>
              <h3 className="text-xs font-serif font-bold text-white uppercase tracking-wider mb-1">Authentic 1920s Art Deco & Tiger Palette</h3>
              <p className="text-[11px] text-neutral-400">
                A warm, atmospheric jazz-lounge aesthetic with brushed brass grids, retro tiger stripes, and electric nightclub tones.
              </p>
            </div>

            <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
              {colors.map((color) => (
                <button
                  key={color.hex}
                  onClick={() => copyToClipboard(color.hex)}
                  className="flex items-center gap-2.5 p-2 bg-[#2A1500]/60 hover:bg-[#3D1D00]/80 rounded-lg border border-[#C5A059]/15 text-left transition-all group cursor-pointer"
                >
                  <div
                    className="w-7 h-7 rounded-md shrink-0 shadow-inner relative flex items-center justify-center border border-[#C5A059]/30"
                    style={{ backgroundColor: color.hex }}
                  >
                    {copiedColor === color.hex && (
                      <Check className="w-3.5 h-3.5 text-neutral-900 bg-white rounded-full p-0.5" />
                    )}
                  </div>
                  <div className="min-w-0">
                    <div className="flex items-center gap-1.5">
                      <span className="text-[11px] font-semibold text-white truncate">{color.name}</span>
                      <Copy className="w-2.5 h-2.5 text-neutral-500 group-hover:text-[#E5C180] shrink-0 transition-colors" />
                    </div>
                    <code className="text-[9px] text-[#E5C180] font-mono">{color.hex}</code>
                  </div>
                </button>
              ))}
            </div>

            <div className="p-3.5 bg-[#1C0F00]/80 rounded-lg border border-[#C5A059]/20 space-y-2">
              <span className="text-xs font-bold text-[#E5C180] uppercase tracking-wider flex items-center gap-1 font-serif">
                <HelpCircle className="w-3.5 h-3.5 text-[#C5A059]" /> Typography & Architectural Style
              </span>
              <ul className="text-xs text-neutral-300 space-y-1.5 list-disc pl-4 leading-relaxed font-sans">
                <li>
                  <strong className="text-white">Timer Countdown:</strong> Retro high-definition monospace typeface mimicking high-end smartwatch reservation passes and secret code pads.
                </li>
                <li>
                  <strong className="text-white">Headings & Accent:</strong> Luxurious Art Deco serif (<span className="font-serif">Cinzel / Playfair</span>) representing Manila high-society club elegance.
                </li>
                <li>
                  <strong className="text-white">Wallpaper Motif:</strong> Art Deco repeating brass archways (<span className="text-[#C5A059]">chinese-cloud</span>) and gold diamond lattice structures.
                </li>
              </ul>
            </div>
          </div>
        )}

        {/* TAB 2: BEHAVIORS */}
        {activeTab === 'interactions' && (
          <div className="space-y-4">
            <div>
              <h3 className="text-xs font-serif font-bold text-white uppercase tracking-wider mb-1">Dual Nightlife State Machine</h3>
              <p className="text-[11px] text-neutral-400">
                How the application visually and functionally transforms at midnight from Speakeasy Mode to Microclub Mode.
              </p>
            </div>

            {/* Midnight Transformation specs */}
            <div className="bg-[#1C0F00]/80 rounded-lg border border-[#C5A059]/20 p-4 space-y-3">
              <h4 className="text-xs font-bold text-[#E5C180] uppercase tracking-wider font-serif">1. Midnight Transformation Flow</h4>
              <div className="space-y-2 text-xs">
                <div className="p-2.5 bg-[#0D0500]/90 rounded border-l-4 border-amber-600 flex justify-between items-center">
                  <div>
                    <span className="font-serif font-bold text-white block">🌶️ Speakeasy Mode (8PM - 12AM)</span>
                    <span className="text-neutral-400">Warm brass/amber glowing lounge, retro jazz ambiance, seated tables (max 30 capacity), high-margin craft storytelling mixology.</span>
                  </div>
                  <span className="text-[9px] font-mono bg-[#1E0F00] px-1.5 py-0.5 rounded text-amber-500 font-bold">ACTIVE</span>
                </div>
                <div className="p-2.5 bg-[#0D0500]/90 rounded border-l-4 border-violet-600 flex justify-between items-center">
                  <div>
                    <span className="font-serif font-bold text-white block">🕺 Microclub Mode (12AM - 4AM)</span>
                    <span className="text-neutral-400">Flashes to intense neon purple and tiger-orange strobe, energetic vinyl DJs (disco, soul, Latin), standing room (max 50 capacity), volume beers & VIP bottle service.</span>
                  </div>
                  <span className="text-[9px] font-mono bg-[#1E0F00] px-1.5 py-0.5 rounded text-violet-400 font-bold">TRANSITION</span>
                </div>
              </div>
            </div>

            {/* Easing specs */}
            <div className="bg-[#1C0F00]/80 rounded-lg border border-[#C5A059]/20 p-4 space-y-2">
              <h4 className="text-xs font-bold text-white uppercase tracking-wider font-serif">2. Capacity & Exclusivity Throttles</h4>
              <div className="font-mono text-[10px] space-y-1.5 text-neutral-400">
                <div className="flex justify-between border-b border-neutral-900 pb-1">
                  <span>Speakeasy Seating Cap</span>
                  <span className="text-white">30 Seated Max (Ensures premium bespoke mixology)</span>
                </div>
                <div className="flex justify-between border-b border-neutral-900 pb-1">
                  <span>Microclub Standing Cap</span>
                  <span className="text-white">50 Pax Max (Packed tight like a Tokyo basement)</span>
                </div>
                <div className="flex justify-between border-b border-neutral-900 pb-1">
                  <span>Wallet Freezing Easing</span>
                  <span className="text-white">Freeze countdown instantly on checkout / check-out</span>
                </div>
                <div className="flex justify-between">
                  <span>Strobe Light Frequency</span>
                  <span className="text-white">0.4s CSS linear keyframe loops under Microclub Mode</span>
                </div>
              </div>
            </div>
          </div>
        )}

        {/* TAB 3: TONE */}
        {activeTab === 'copy' && (
          <div className="space-y-4">
            <div>
              <h3 className="text-xs font-serif font-bold text-white uppercase tracking-wider mb-1">Nightlife Tone & Copybook</h3>
              <p className="text-[11px] text-neutral-400">
                Exclusive vocabulary replacing generic tech labels with high-end club lingo.
              </p>
            </div>

            <div className="space-y-3 text-xs">
              <div className="p-3 bg-[#1C0F00]/80 border border-[#C5A059]/15 rounded-lg space-y-1">
                <span className="text-[9px] font-bold text-[#C5A059] uppercase block font-serif">Interactive Copy Translation</span>
                <p className="text-white font-medium">“SOLVE ENTRY PASSWORD”</p>
                <p className="text-neutral-400">Unlocks the unmarked green secret door to start the simulation.</p>
                <p className="text-white font-medium">“BUY TIGER PASSPORT”</p>
                <p className="text-neutral-400">Premium checkout to gain reservation hours (30, 60, or 90 minutes).</p>
                <p className="text-white font-medium">“RESERVATION COUNTDOWN (-15 MIN)”</p>
                <p className="text-neutral-400">Session timer decrease for drink mixology ordering.</p>
              </div>

              <div className="p-3 bg-[#1C0F00]/80 border border-[#C5A059]/15 rounded-lg space-y-1.5">
                <span className="text-[9px] font-bold text-[#C5A059] uppercase block font-serif">Discerning Socialite Classes</span>
                <div className="flex gap-2 flex-wrap">
                  <span className="px-2 py-0.5 bg-[#8B0000]/30 text-[#E5C180] border border-[#C5A059]/30 rounded text-[10px] font-serif font-bold">EMPEROR TIGER 👑</span>
                  <span className="px-2 py-0.5 bg-[#8B0000]/30 text-neutral-300 border border-[#C5A059]/15 rounded text-[10px] font-serif font-bold">DISCERNING VIP 🍸</span>
                  <span className="px-2 py-0.5 bg-[#8B0000]/30 text-neutral-400 border border-neutral-800 rounded text-[10px] font-serif font-bold">SOCIALITE GUEST 🐯</span>
                </div>
              </div>
            </div>
          </div>
        )}

        {/* TAB 4: SPECIFICATION CHECKLIST */}
        {activeTab === 'checklist' && (
          <div className="space-y-4">
            <div>
              <h3 className="text-xs font-serif font-bold text-white uppercase tracking-wider mb-1">Compliance Checklist</h3>
              <p className="text-[11px] text-neutral-400">
                Verified visual and interactive mechanics for premium Manila nightlife.
              </p>
            </div>

            <div className="space-y-1.5">
              {[
                { label: 'Brushed Brass Art Deco Wallpaper', desc: 'Custom repeatable SVG diamond grid backgrounds integrated.' },
                { label: 'Double Mode Midnight Strobe', desc: 'Simulated clock transitions UI color schemes instantly.' },
                { label: 'Unmarked Secret Entry Flow', desc: 'A password gate simulating the authentic door-knock.' },
                { label: 'Socialite Leaderboard', desc: 'Real-time ranks sorted by remaining table time currency.' },
                { label: 'Craft Cocktail Catalog with Story', desc: 'Drinks with rich Manila ingredients, ABV, and pricing in active minutes.' },
                { label: 'Turntable Vinyl Mini-Game', desc: 'Fully playable spin game rewarding user credits.' },
                { label: 'Simulated Live Table Feed', desc: 'Dynamic events notifying users when others order bottle service.' },
                { label: 'Secure GCash/PayMaya Sandbox', desc: 'High-fidelity payment simulator with discount triggers.' },
              ].map((item, i) => (
                <div key={i} className="flex gap-2.5 p-2 bg-[#1C0F00]/50 border border-[#C5A059]/15 rounded-lg text-xs items-start">
                  <input
                    type="checkbox"
                    defaultChecked
                    className="mt-0.5 rounded border-[#C5A059]/30 text-[#8B0000] focus:ring-[#8B0000] bg-neutral-900"
                  />
                  <div>
                    <span className="font-serif font-bold text-white block">{item.label}</span>
                    <span className="text-neutral-400 text-[10px]">{item.desc}</span>
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}

      </div>

      {/* Panel Footer */}
      <div className="p-4 bg-[#0A0500] border-t border-[#C5A059]/20 text-center text-[10px] text-[#C5A059] font-serif uppercase tracking-wider">
        The Blind Tiger Social Club © 2026. Guard Your Hours.
      </div>
    </div>
  );
}
