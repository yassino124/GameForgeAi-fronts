"use client";

import { motion } from "framer-motion";
import { Trophy, Star, Zap, Target, Award, Rocket } from "lucide-react";

const ACHIEVEMENTS = [
  { id: 1, title: "First Forge", desc: "Completed your first build", icon: Rocket, color: "#6366f1", unlocked: true },
  { id: 2, title: "Speed Demon", desc: "Build latency under 50ms", icon: Zap, color: "#f59e0b", unlocked: true },
  { id: 3, title: "Market Pro", desc: "1k+ downloads reached", icon: Star, color: "#10b981", unlocked: false },
  { id: 4, title: "Neural Master", desc: "10 AI logic generations", icon: Cpu, color: "#ec4899", unlocked: true },
];

function Cpu({ size, className }: { size?: number, className?: string }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className={className}>
      <rect x="4" y="4" width="16" height="16" rx="2" />
      <path d="M9 9h6v6H9z" />
      <path d="M15 2v2" /><path d="M15 20v2" /><path d="M9 2v2" /><path d="M9 20v2" />
      <path d="M20 15h2" /><path d="M2 15h2" /><path d="M20 9h2" /><path d="M2 9h2" />
    </svg>
  );
}

export default function AchievementSystem() {
  return (
    <div className="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-4 gap-4 mt-6">
      {ACHIEVEMENTS.map((a, i) => (
        <motion.div
          key={a.id}
          initial={{ opacity: 0, scale: 0.9 }}
          animate={{ opacity: 1, scale: 1 }}
          transition={{ delay: i * 0.1 }}
          className={`gf-panel-strong p-4 rounded-3xl border transition-all relative overflow-hidden group ${
            a.unlocked ? "border-white/10 bg-white/[0.03]" : "border-white/5 bg-black/40 grayscale opacity-50"
          }`}
        >
          {a.unlocked && (
            <div className="absolute inset-0 bg-gradient-to-br from-indigo-500/5 to-transparent pointer-events-none" />
          )}
          
          <div className="flex items-center gap-4 relative z-10">
            <div 
              className="h-12 w-12 rounded-2xl flex items-center justify-center shadow-lg"
              style={{ 
                backgroundColor: a.unlocked ? `${a.color}22` : "rgba(255,255,255,0.05)",
                color: a.unlocked ? a.color : "#52525b"
              }}
            >
              <a.icon size={24} strokeWidth={a.unlocked ? 2.5 : 2} />
            </div>
            <div className="min-w-0 flex-1">
              <div className="text-xs font-black text-white uppercase tracking-tight truncate">{a.title}</div>
              <div className="text-[10px] text-zinc-500 font-medium truncate">{a.desc}</div>
            </div>
            {a.unlocked && (
              <motion.div 
                animate={{ scale: [1, 1.2, 1] }}
                transition={{ duration: 2, repeat: Infinity }}
                className="h-1.5 w-1.5 rounded-full bg-emerald-500 shadow-[0_0_8px_rgba(16,185,129,0.8)] shrink-0" 
              />
            )}
          </div>
        </motion.div>
      ))}
    </div>
  );
}
