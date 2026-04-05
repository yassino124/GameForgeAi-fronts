"use client";

import { motion } from "framer-motion";
import { 
  BarChart3, 
  TrendingUp, 
  Users, 
  Layers, 
  Zap, 
  ArrowUpRight, 
  Activity,
  History,
  MousePointer2
} from "lucide-react";

function AreaChart({ color }: { color: string }) {
  return (
    <div className="w-full h-24 relative overflow-hidden">
      <svg viewBox="0 0 400 100" className="w-full h-full opacity-40">
        <defs>
          <linearGradient id={`grad-${color}`} x1="0%" y1="0%" x2="0%" y2="100%">
            <stop offset="0%" style={{ stopColor: color, stopOpacity: 0.4 }} />
            <stop offset="100%" style={{ stopColor: color, stopOpacity: 0 }} />
          </linearGradient>
          <filter id="glow">
            <feGaussianBlur stdDeviation="2" result="blur" />
            <feComposite in="SourceGraphic" in2="blur" operator="over" />
          </filter>
        </defs>
        <motion.path
          initial={{ d: "M0,100 Q50,100 100,100 T200,100 T300,100 T400,100 L400,100 L0,100 Z" }}
          animate={{ d: "M0,80 Q50,20 100,70 T200,40 T300,60 T400,30 L400,100 L0,100 Z" }}
          transition={{ duration: 2, ease: "easeOut" }}
          fill={`url(#grad-${color})`}
        />
        <motion.path
          initial={{ pathLength: 0, opacity: 0 }}
          animate={{ pathLength: 1, opacity: 1 }}
          transition={{ duration: 2.5, ease: "easeInOut" }}
          d="M0,80 Q50,20 100,70 T200,40 T300,60 T400,30"
          fill="none"
          stroke={color}
          strokeWidth="3"
          filter="url(#glow)"
        />
      </svg>
      {/* Scanning line effect */}
      <motion.div 
        animate={{ x: ["-100%", "200%"] }}
        transition={{ duration: 3, repeat: Infinity, ease: "linear" }}
        className="absolute inset-0 w-1/2 bg-gradient-to-r from-transparent via-white/5 to-transparent skew-x-12 pointer-events-none"
      />
    </div>
  );
}

export default function InteractiveCharts() {
  return (
    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mt-8">
      {[
        { label: "Active Sessions", value: "1,284", change: "+12%", color: "#6366f1", icon: Users, delay: 0 },
        { label: "Build Velocity", value: "45ms", change: "Fast", color: "#ec4899", icon: Zap, delay: 0.1 },
        { label: "Community Mods", value: "842", change: "+5.4%", color: "#22d3ee", icon: Layers, delay: 0.2 },
        { label: "Market Growth", value: "$42.5k", change: "+22%", color: "#10b981", icon: TrendingUp, delay: 0.3 },
      ].map((stat, i) => (
        <motion.div
          initial={{ opacity: 0, scale: 0.9 }}
          animate={{ opacity: 1, scale: 1 }}
          transition={{ delay: stat.delay, type: "spring", stiffness: 200, damping: 20 }}
          whileHover={{ y: -5, scale: 1.02 }}
          key={i}
          className="gf-panel-strong gf-stroke-gradient p-6 rounded-[32px] relative overflow-hidden group cursor-pointer border border-white/5 hover:border-white/20 transition-all duration-500"
        >
          {/* Background Ambient Glow */}
          <div 
            className="absolute inset-0 opacity-0 group-hover:opacity-10 transition-opacity duration-700 pointer-events-none"
            style={{ background: `radial-gradient(600px circle at center, ${stat.color}, transparent 70%)` }}
          />

          <div className="relative z-10">
            <div className="flex justify-between items-start mb-6">
              <motion.div 
                whileHover={{ rotate: 12, scale: 1.1 }}
                className="p-3 rounded-2xl bg-white/5 text-zinc-400 group-hover:text-white group-hover:bg-white/10 transition-all duration-300 border border-white/5 group-hover:border-white/10"
              >
                <stat.icon size={22} />
              </motion.div>
              <div className="flex items-center gap-1 text-[10px] font-black text-emerald-400 bg-emerald-500/10 px-3 py-1 rounded-full border border-emerald-500/20 shadow-[0_0_15px_rgba(16,185,129,0.1)]">
                {stat.change} <ArrowUpRight size={12} />
              </div>
            </div>
            
            <div className="space-y-1">
              <div className="text-[10px] font-black text-zinc-500 uppercase tracking-[0.3em]">{stat.label}</div>
              <div className="text-3xl font-black text-white tracking-tight flex items-center gap-2">
                {stat.value}
                <motion.span 
                  animate={{ opacity: [0.4, 1, 0.4] }}
                  transition={{ duration: 2, repeat: Infinity }}
                  className="h-1.5 w-1.5 rounded-full"
                  style={{ backgroundColor: stat.color }}
                />
              </div>
            </div>
          </div>
          
          <div className="mt-6 -mx-6 -mb-6 pointer-events-none translate-y-2 group-hover:translate-y-0 transition-transform duration-700">
            <AreaChart color={stat.color} />
          </div>

          {/* Glass highlight */}
          <div className="absolute top-0 left-0 w-full h-full bg-gradient-to-br from-white/5 to-transparent pointer-events-none opacity-0 group-hover:opacity-100 transition-opacity duration-500" />
        </motion.div>
      ))}
    </div>
  );
}
