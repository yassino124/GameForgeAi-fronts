"use client";

import { useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { motion, AnimatePresence } from "framer-motion";
import { 
  Rocket, 
  Layers, 
  Zap, 
  Cpu, 
  Plus, 
  ExternalLink, 
  Clock, 
  Search,
  Trophy,
  Users,
  Gamepad2,
  Sparkles,
  Eye,
  Heart,
  TrendingUp,
  Star,
  ChevronRight,
  Lightbulb,
  Activity,
  Bell
} from "lucide-react";
import UserShell from "@/app/_components/UserShell";
import { API_BASE_URL, apiFetch, ApiError } from "@/lib/api";
import { getUserToken } from "@/lib/userAuth";
import InteractiveCharts from "@/app/_components/InteractiveCharts";
import AchievementSystem from "@/app/_components/AchievementSystem";
import GlobalActivityFeed from "@/app/_components/GlobalActivityFeed";
import AIStoryboard from "@/app/_components/AIStoryboard";

type Me = {
  id?: string;
  email?: string;
  username?: string;
  role?: string;
  subscription?: string;
  avatar?: string;
};

type StatsResponse = {
  projects?: number;
  templates?: number;
  downloads?: number;
  builds?: number;
  generations?: number;
};

type ProjectRow = {
  id?: string;
  _id?: string;
  name?: string;
  status?: string;
  buildTarget?: string;
  updatedAt?: string;
  createdAt?: string;
  thumbnailUrl?: string;
  previewImageUrl?: string;
  imageUrl?: string;
};

type GameFeedPost = {
  id?: string;
  _id?: string;
  title?: string;
  name?: string;
  likeCount?: number;
  playCount?: number;
  viewCount?: number;
  previewImageUrl?: string;
  previewImage?: string;
  thumbnailUrl?: string;
};

type TemplateRow = {
  id?: string;
  _id?: string;
  name?: string;
  title?: string;
  rating?: number;
  downloads?: number;
  likeCount?: number;
  previewImageUrl?: string;
  previewImage?: string;
  thumbnailUrl?: string;
};

function cx(...parts: Array<string | false | null | undefined>) {
  return parts.filter(Boolean).join(" ");
}

function resolveMediaUrl(raw?: string | null) {
  const s = String(raw ?? "").trim();
  if (!s) return "";
  if (s.startsWith("http://") || s.startsWith("https://")) return s;

  const base = String(API_BASE_URL || "").replace(/\/?api\/?$/, "");
  if (!base) return s;
  if (s.startsWith("/")) return `${base}${s}`;
  return `${base}/${s}`;
}

function asInt(v: any) {
  if (typeof v === "number" && Number.isFinite(v)) return Math.floor(v);
  return parseInt(String(v ?? "0"), 10) || 0;
}

function templateScore(t: TemplateRow) {
  const rating = Number((t as any)?.rating ?? 0) || 0;
  const downloads = asInt((t as any)?.downloads);
  const likes = asInt((t as any)?.likeCount);
  return rating * 40 + Math.sqrt(Math.max(0, downloads)) * 2.2 + likes * 3;
}

function timeAgo(raw?: string | null) {
  const s = (raw ?? "").trim();
  if (!s) return "Recently";
  const d = new Date(s);
  if (Number.isNaN(d.getTime())) return "Recently";
  const diffMs = Date.now() - d.getTime();
  const min = Math.floor(diffMs / 60000);
  if (min < 2) return "Just now";
  if (min < 60) return `${min} min ago`;
  const h = Math.floor(min / 60);
  if (h < 24) return `${h}h ago`;
  const days = Math.floor(h / 24);
  return `${days}d ago`;
}

function badgeForStatus(s: any) {
  const st = String(s || "").trim().toLowerCase();
  if (st === "ready") return { label: "READY", cls: "border-emerald-500/20 bg-emerald-500/10 text-emerald-300" };
  if (st === "building" || st === "queued") return { label: "BUILDING", cls: "border-indigo-500/20 bg-indigo-500/10 text-indigo-300" };
  if (st === "failed") return { label: "FAILED", cls: "border-red-500/20 bg-red-500/10 text-red-200" };
  return { label: (st || "draft").toUpperCase(), cls: "border-white/10 bg-white/5 text-zinc-300" };
}

function AICoachTip() {
  const AI_TIPS = [
    "Use 'Procedural Mesh' for infinite terrain variety.",
    "Optimize your WebGL builds by compressing textures.",
    "Add 'AI Navigation' to make your NPCs feel alive.",
    "Try the 'Cyberpunk' template for instant neon vibes.",
    "Connect your Discord to get real-time build alerts."
  ];

  const [tipIdx, setTipIdx] = useState(0);
  const [dismissed, setDismissed] = useState(false);
  const router = useRouter();
  
  useEffect(() => {
    const interval = setInterval(() => {
      setTipIdx((prev) => (prev + 1) % AI_TIPS.length);
    }, 8000);
    return () => clearInterval(interval);
  }, []);

  return (
    <AnimatePresence initial={false}>
      {!dismissed && (
        <motion.div
          layout
          initial={{ opacity: 0, y: 14, height: 0 }}
          animate={{ opacity: 1, y: 0, height: "auto" }}
          exit={{ opacity: 0, y: -8, height: 0 }}
          transition={{ duration: 0.5, ease: [0.16, 1, 0.3, 1] }}
          className="relative overflow-hidden rounded-[28px] border border-white/10 bg-[#0a0b14]/70 backdrop-blur-2xl px-8 py-7 shadow-[0_18px_55px_rgba(0,0,0,0.35)] group"
        >
          <div className="absolute inset-0 opacity-[0.18]">
            <div className="absolute inset-0 bg-[radial-gradient(circle_at_15%_35%,rgba(99,102,241,0.30),transparent_45%),radial-gradient(circle_at_85%_20%,rgba(217,70,239,0.22),transparent_45%)]" />
          </div>

          <motion.div
            aria-hidden
            animate={{ x: ["-140%", "140%"] }}
            transition={{ duration: 6.5, repeat: Infinity, ease: "linear" }}
            className="absolute inset-y-0 left-0 w-2/3 bg-gradient-to-r from-transparent via-white/6 to-transparent opacity-0 group-hover:opacity-100"
          />

          <div className="relative z-10 flex flex-col gap-5">
            <div className="flex items-center justify-between gap-4">
              <div className="flex items-center gap-3">
                <div className="h-10 w-10 rounded-[14px] bg-white/5 flex items-center justify-center border border-white/10">
                  <motion.div
                    animate={{ scale: [1, 1.12, 1], opacity: [0.7, 1, 0.7] }}
                    transition={{ duration: 2.2, repeat: Infinity, ease: "easeInOut" }}
                    className="h-6 w-6 rounded-[10px] bg-indigo-500/90 flex items-center justify-center shadow-[0_0_18px_rgba(99,102,241,0.35)]"
                  >
                    <Sparkles size={12} className="text-white" />
                  </motion.div>
                </div>
                <div className="flex items-center gap-2">
                  <span className="text-[10px] font-black uppercase tracking-[0.32em] text-indigo-300">AI Coach</span>
                  <span className="text-[10px] font-black uppercase tracking-[0.32em] text-zinc-600">/</span>
                  <span className="text-[10px] font-black uppercase tracking-[0.32em] text-zinc-500">Tip</span>
                </div>
              </div>
              <div className="h-10 w-10 rounded-[16px] bg-white/5 border border-white/10 flex items-center justify-center text-zinc-300/80">
                <Zap size={18} className="text-yellow-300 fill-yellow-300/40" />
              </div>
            </div>

            <AnimatePresence mode="wait">
              <motion.p
                key={tipIdx}
                initial={{ opacity: 0, x: 14 }}
                animate={{ opacity: 1, x: 0 }}
                exit={{ opacity: 0, x: -14 }}
                className="text-[18px] sm:text-xl font-bold text-white leading-snug"
              >
                "{AI_TIPS[tipIdx]}"
              </motion.p>
            </AnimatePresence>

            <div className="flex flex-wrap gap-3">
              <button
                onClick={() => router.push("/studio/ai/coach")}
                className="px-6 py-2.5 rounded-xl bg-indigo-500 text-white text-[10px] font-black uppercase tracking-widest hover:scale-[1.03] active:scale-[0.98] transition-transform shadow-[0_18px_36px_rgba(99,102,241,0.25)]"
              >
                Yes, teach me
              </button>
              <button
                onClick={() => setDismissed(true)}
                className="px-6 py-2.5 rounded-xl bg-white/5 text-zinc-400 text-[10px] font-black uppercase tracking-widest hover:bg-white/10 hover:text-zinc-200 transition-all"
              >
                Later
              </button>
            </div>
          </div>
        </motion.div>
      )}
    </AnimatePresence>
  );
}

function Sparkline({ values, color }: { values: number[]; color: string }) {
  const v = values.length ? values : [0, 0, 0, 0, 0, 0];
  const min = Math.min(...v);
  const max = Math.max(...v);
  const range = Math.max(1, max - min);

  const width = 140;
  const height = 48;
  const padding = 4;

  const points = v.map((n, i) => {
    const x = padding + (i * (width - padding * 2)) / Math.max(1, v.length - 1);
    const y = padding + (1 - (n - min) / range) * (height - padding * 2);
    return { x, y };
  });

  const pts = points.map((p) => `${p.x.toFixed(1)},${p.y.toFixed(1)}`).join(" ");
  const last = points[points.length - 1] || { x: width - padding, y: height / 2 };
  const gid = `gf_sp_${color.replace(/[^a-zA-Z0-9]/g, "").slice(0, 16) || "c"}`;

  return (
    <motion.svg
      viewBox={`0 0 ${width} ${height}`}
      width={width}
      height={height}
      className="block"
      aria-hidden
    >
      <defs>
        <linearGradient id={gid} x1="0" y1="0" x2="1" y2="0">
          <stop offset="0" stopColor={color} stopOpacity="0.15" />
          <stop offset="0.5" stopColor={color} stopOpacity="0.6" />
          <stop offset="1" stopColor={color} stopOpacity="0.15" />
        </linearGradient>
      </defs>

      <motion.polyline
        points={pts}
        fill="none"
        stroke={`url(#${gid})`}
        strokeWidth={4}
        strokeLinecap="round"
        strokeLinejoin="round"
        initial={{ pathLength: 0 }}
        animate={{ pathLength: 1 }}
        transition={{ duration: 1.05, ease: [0.16, 1, 0.3, 1] }}
      />
      <polyline points={pts} fill="none" stroke={color} strokeOpacity={0.6} strokeWidth={1.25} strokeLinecap="round" strokeLinejoin="round" />
      <motion.circle
        cx={last.x}
        cy={last.y}
        r={2.6}
        fill={color}
        initial={{ opacity: 0 }}
        animate={{ opacity: [0.5, 1, 0.6], r: [2.6, 3.6, 2.6] }}
        transition={{ duration: 1.8, repeat: Infinity, ease: "easeInOut" }}
      />
      <motion.circle
        cx={last.x}
        cy={last.y}
        r={8}
        fill={color}
        initial={{ opacity: 0.12 }}
        animate={{ opacity: [0.08, 0.2, 0.08] }}
        transition={{ duration: 2.2, repeat: Infinity, ease: "easeInOut" }}
      />
    </motion.svg>
  );
}

function TrendingArcade(props: {
  games: Array<{
    id: string;
    title: string;
    views: number;
    imageUrl: string;
  }>;
}) {
  const games = props.games;

  return (
    <div className="space-y-8">
      <div className="flex items-center justify-between">
        <h3 className="text-[16px] font-black text-white uppercase tracking-[0.4em] flex items-center gap-4">
          <div className="h-1 w-10 bg-indigo-500 rounded-full" />
          Trending Games
        </h3>
        <button className="text-[11px] font-black uppercase tracking-widest text-indigo-400 hover:text-indigo-300 transition-colors">SEE ALL</button>
      </div>
      <div className="flex gap-8 overflow-x-auto pb-6 no-scrollbar">
        {games.map((game, i) => (
          <motion.div 
            key={game.id || i}
            initial={{ opacity: 0, scale: 0.9 }}
            whileInView={{ opacity: 1, scale: 1 }}
            viewport={{ once: true }}
            transition={{ duration: 0.5, delay: i * 0.1 }}
            whileHover={{ y: -12, scale: 1.02 }}
            className="group relative min-w-[320px] aspect-square rounded-[48px] overflow-hidden border border-white/5 bg-[#0a0b14] shadow-[0_30px_60px_rgba(0,0,0,0.4)]"
          >
            {game.imageUrl ? (
              <img src={game.imageUrl} alt={game.title} className="w-full h-full object-cover opacity-70 group-hover:scale-110 group-hover:opacity-100 transition-all duration-1000" />
            ) : (
              <div className="absolute inset-0 bg-gradient-to-br from-indigo-500/20 via-fuchsia-500/10 to-black" />
            )}
            <div className="absolute inset-0 bg-gradient-to-t from-[#05060a] via-transparent to-transparent opacity-80" />
            <div className="absolute bottom-0 left-0 right-0 p-10">
              <h4 className="text-2xl font-bold text-white mb-3 leading-tight tracking-tight group-hover:text-indigo-300 transition-colors">{game.title}</h4>
              <div className="flex items-center justify-between pt-2 border-t border-white/5 mt-4">
                <div className="flex items-center gap-4">
                  <span className="flex items-center gap-2 text-[12px] text-zinc-400 font-bold uppercase tracking-widest">
                    <Eye size={16} className="text-zinc-500" /> {game.views}
                  </span>
                </div>
                <div className="h-12 w-12 rounded-[20px] bg-white/10 backdrop-blur-md border border-white/10 flex items-center justify-center text-white hover:bg-indigo-500 transition-colors">
                  <Heart size={20} className="text-white fill-white/20 group-hover:fill-white transition-all" />
                </div>
              </div>
            </div>
          </motion.div>
        ))}
      </div>
    </div>
  );
}

function BestPickTemplate(props: {
  template?: {
    id: string;
    name: string;
    downloads: number;
    imageUrl: string;
  } | null;
}) {
  const t = props.template;
  return (
    <div className="space-y-8">
      <div className="flex items-center justify-between">
        <h3 className="text-[16px] font-black text-white uppercase tracking-[0.4em] flex items-center gap-4">
          <div className="h-1 w-10 bg-fuchsia-500 rounded-full" />
          Top Rated Template
        </h3>
        <button className="text-[11px] font-black uppercase tracking-widest text-fuchsia-400 hover:text-fuchsia-300 transition-colors">BROWSE</button>
      </div>
      <motion.div 
        initial={{ opacity: 0, y: 30 }}
        whileInView={{ opacity: 1, y: 0 }}
        viewport={{ once: true }}
        whileHover={{ scale: 1.01, y: -5 }}
        className="relative h-[300px] rounded-[48px] overflow-hidden border border-white/5 group shadow-[0_40px_80px_rgba(0,0,0,0.5)]"
      >
        {t?.imageUrl ? (
          <img 
            src={t.imageUrl}
            alt={t.name || "Best Pick"}
            className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-1000 opacity-80 group-hover:opacity-100"
          />
        ) : (
          <div className="absolute inset-0 bg-gradient-to-br from-indigo-500/20 via-fuchsia-500/10 to-black" />
        )}
        <div className="absolute inset-0 bg-gradient-to-r from-black via-black/40 to-transparent" />
        <div className="absolute inset-0 p-12 flex flex-col justify-between items-start">
          <motion.div 
            animate={{ scale: [1, 1.05, 1] }}
            transition={{ duration: 2, repeat: Infinity }}
            className="px-6 py-2.5 rounded-full bg-indigo-500 text-white text-[11px] font-black uppercase tracking-[0.2em] shadow-[0_15px_30px_rgba(99,102,241,0.4)] border border-white/20"
          >
            BEST PICK
          </motion.div>
          <div className="flex justify-between items-end w-full">
            <div className="space-y-3">
              <h2 className="text-5xl font-black text-white tracking-tighter uppercase italic gf-chromatic">{t?.name || "—"}</h2>
              <div className="flex items-center gap-6">
                <div className="flex items-center gap-2">
                  <Star size={14} className="text-yellow-400 fill-yellow-400" />
                  <span className="text-[12px] font-black text-zinc-400 uppercase tracking-widest">Top rated</span>
                </div>
                <div className="h-1 w-1 rounded-full bg-zinc-600" />
                <div className="flex items-center gap-2">
                  <Zap size={14} className="text-indigo-400 fill-indigo-400" />
                  <span className="text-[12px] font-black text-zinc-400 uppercase tracking-widest">{t ? `${t.downloads} downloads` : "—"}</span>
                </div>
              </div>
            </div>
            <motion.div 
              whileHover={{ x: 10 }}
              className="h-16 w-16 rounded-[24px] bg-white/10 backdrop-blur-md border border-white/20 flex items-center justify-center text-white hover:bg-white/20 transition-all cursor-pointer"
            >
              <ChevronRight size={32} />
            </motion.div>
          </div>
        </div>
      </motion.div>
    </div>
  );
}

function GreetingCard({ username }: { username?: string }) {
  const hour = new Date().getHours();
  const greeting = hour < 12 ? "Good Morning" : hour < 18 ? "Good Afternoon" : "Good Evening";
  const router = useRouter();
  
  return (
    <motion.div 
      initial={{ opacity: 0, y: 30 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.8, ease: [0.16, 1, 0.3, 1] }}
      className="relative overflow-hidden rounded-[48px] border border-white/5 bg-[#0a0b14] p-8 lg:p-12 shadow-[0_40px_100px_rgba(0,0,0,0.6)] group"
    >
      {/* Cinematic Background Elements */}
      <div className="absolute inset-0 pointer-events-none">
        <motion.div 
          animate={{ 
            scale: [1, 1.2, 1],
            opacity: [0.1, 0.15, 0.1],
            x: [0, 50, 0],
            y: [0, 30, 0]
          }}
          transition={{ duration: 15, repeat: Infinity, ease: "easeInOut" }}
          className="absolute -right-20 -top-20 h-[500px] w-[500px] rounded-full bg-indigo-500/20 blur-[120px]" 
        />
        <motion.div 
          animate={{ 
            scale: [1.2, 1, 1.2],
            opacity: [0.05, 0.1, 0.05],
            x: [0, -40, 0],
            y: [0, -20, 0]
          }}
          transition={{ duration: 18, repeat: Infinity, ease: "easeInOut", delay: 2 }}
          className="absolute -left-20 -bottom-20 h-[400px] w-[400px] rounded-full bg-fuchsia-500/10 blur-[100px]" 
        />
      </div>
      
      <div className="relative z-10 flex flex-col lg:flex-row justify-between items-center gap-8">
        <div className="flex-1 space-y-7 text-center lg:text-left">
          <motion.div 
            initial={{ opacity: 0, x: -20 }}
            animate={{ opacity: 1, x: 0 }}
            transition={{ delay: 0.3 }}
            className="inline-flex items-center gap-3 rounded-full border border-indigo-500/30 bg-indigo-500/10 px-4 py-2 text-[10px] font-black uppercase tracking-[0.25em] text-indigo-300 shadow-[0_0_20px_rgba(99,102,241,0.2)]"
          >
            <Sparkles size={14} className="text-indigo-400 animate-pulse" />
            Neural Engine v4.0
            <div className="h-1 w-1 rounded-full bg-indigo-500/50" />
            <span className="text-indigo-400/80">Active</span>
          </motion.div>
          
          <div className="space-y-4">
            <motion.div 
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              transition={{ delay: 0.4 }}
              className="text-xs font-black text-zinc-500 uppercase tracking-[0.5em]"
            >
              {greeting}
            </motion.div>
            <motion.h1 
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.5, duration: 0.8 }}
              className="text-6xl lg:text-7xl font-black text-white tracking-tighter uppercase italic leading-[0.9] gf-chromatic"
            >
              {username || "Creator"}
            </motion.h1>
            <motion.p 
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              transition={{ delay: 0.6 }}
              className="mt-4 text-zinc-400 font-medium text-lg lg:text-xl max-w-xl mx-auto lg:mx-0 leading-relaxed"
            >
              Your next masterpiece is one prompt away.
            </motion.p>
          </div>
          
          <motion.div 
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.7 }}
            className="flex flex-wrap justify-center lg:justify-start gap-4 pt-2"
          >
            <button 
              onClick={() => router.push("/studio/projects/new")}
              className="group relative px-9 py-4 rounded-[22px] bg-indigo-500 text-white text-[11px] font-black uppercase tracking-widest hover:scale-105 active:scale-95 transition-all shadow-[0_20px_40px_rgba(99,102,241,0.3)] overflow-hidden"
            >
              <div className="absolute inset-0 bg-gradient-to-r from-transparent via-white/20 to-transparent -translate-x-full group-hover:translate-x-full transition-transform duration-1000 ease-in-out" />
              <span className="relative flex items-center gap-3">
                Forge New Game <Plus size={18} />
              </span>
            </button>
            <button 
              onClick={() => router.push("/studio/marketplace")}
              className="px-9 py-4 rounded-[22px] bg-white/5 text-zinc-300 text-[11px] font-black uppercase tracking-widest hover:bg-white/10 hover:text-white transition-all border border-white/10 backdrop-blur-md"
            >
              Browse Templates
            </button>
          </motion.div>
        </div>

        <motion.div 
          initial={{ opacity: 0, scale: 0.8, rotate: -10 }}
          animate={{ opacity: 1, scale: 1, rotate: 0 }}
          transition={{ delay: 0.5, duration: 1, type: "spring" }}
          className="relative lg:block"
        >
          <div className="relative group cursor-pointer">
            <motion.div 
              animate={{ 
                rotate: [0, 360],
                scale: [1, 1.1, 1]
              }}
              transition={{ duration: 20, repeat: Infinity, ease: "linear" }}
              className="absolute -inset-8 bg-gradient-to-tr from-indigo-500/30 to-fuchsia-500/30 blur-[40px] rounded-full opacity-50 group-hover:opacity-100 transition-opacity duration-700" 
            />
            <div className="relative h-44 w-44 lg:h-56 lg:w-56 rounded-[48px] bg-gradient-to-br from-[#1a1b2e] to-[#0a0b14] flex items-center justify-center border border-white/10 shadow-[0_30px_60px_rgba(0,0,0,0.5)] overflow-hidden">
              <motion.div 
                animate={{ 
                  y: [0, -10, 0],
                  filter: ["brightness(1) contrast(1)", "brightness(1.3) contrast(1.1)", "brightness(1) contrast(1)"]
                }}
                transition={{ duration: 4, repeat: Infinity, ease: "easeInOut" }}
                className="relative z-10 p-8 rounded-[32px] bg-gradient-to-br from-indigo-500 to-fuchsia-600 shadow-2xl"
              >
                <Cpu size={64} className="text-white drop-shadow-[0_0_20px_rgba(255,255,255,0.5)]" />
              </motion.div>
              
              {/* Internal decorative lines */}
              <div className="absolute inset-0 opacity-20">
                <div className="absolute top-0 left-1/2 w-px h-full bg-gradient-to-b from-transparent via-white to-transparent" />
                <div className="absolute top-1/2 left-0 w-full h-px bg-gradient-to-r from-transparent via-white to-transparent" />
              </div>
            </div>
          </div>
        </motion.div>
      </div>
    </motion.div>
  );
}

function PremiumStatsGrid({ stats, loading }: { stats: StatsResponse | null, loading: boolean }) {
  const fmt = (n: any) => {
    const v = typeof n === "number" ? n : parseFloat(String(n ?? ""));
    if (!Number.isFinite(v)) return "—";
    return new Intl.NumberFormat(undefined).format(Math.max(0, Math.floor(v)));
  };

  const spark = [
    [2, 3, 4, 6, 5, 7, 8, 9],
    [1, 2, 3, 3, 4, 5, 4, 6],
    [2, 2, 3, 5, 4, 6, 5, 7],
    [1, 3, 2, 4, 3, 5, 4, 6],
  ];

  const colorHex: Record<string, string> = {
    indigo: "#6366f1",
    emerald: "#10b981",
    cyan: "#22d3ee",
    fuchsia: "#d946ef",
  };

  const items = [
    { label: "Projects", value: fmt(stats?.projects), change: "+0.0%", icon: Rocket, color: "indigo" },
    { label: "Templates", value: fmt(stats?.templates), change: "+0.0%", icon: Layers, color: "emerald" },
    { label: "Downloads", value: fmt(stats?.downloads), change: "+0.0%", icon: ExternalLink, color: "cyan" },
    { label: "Generations", value: fmt(stats?.generations), change: "+0.0%", icon: Sparkles, color: "fuchsia" },
  ] as const;

  const accentRadial: Record<(typeof items)[number]["color"], string> = {
    indigo: "radial-gradient(circle at 18% 22%, rgba(99,102,241,0.40), transparent 45%)",
    emerald: "radial-gradient(circle at 18% 22%, rgba(16,185,129,0.34), transparent 45%)",
    cyan: "radial-gradient(circle at 18% 22%, rgba(34,211,238,0.30), transparent 45%)",
    fuchsia: "radial-gradient(circle at 18% 22%, rgba(217,70,239,0.34), transparent 45%)",
  };

  return (
    <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-8">
      {items.map((item, i) => (
        <motion.div
          key={i}
          initial={{ opacity: 0, y: 30 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6, delay: i * 0.1, ease: [0.16, 1, 0.3, 1] }}
          whileHover={{ y: -14, scale: 1.025, rotateX: 5, rotateY: -4 }}
          className="relative overflow-hidden rounded-[44px] border border-white/5 bg-[#0a0b14]/65 backdrop-blur-2xl p-10 group shadow-[0_20px_55px_rgba(0,0,0,0.35)] hover:shadow-[0_45px_110px_rgba(0,0,0,0.7)] transition-all duration-500 [transform-style:preserve-3d]"
        >
          <div className="absolute inset-0 opacity-[0.18]">
            <div className="absolute inset-0 bg-[radial-gradient(circle_at_20%_20%,rgba(99,102,241,0.35),transparent_35%),radial-gradient(circle_at_80%_10%,rgba(217,70,239,0.22),transparent_40%),radial-gradient(circle_at_60%_90%,rgba(34,211,238,0.18),transparent_40%)]" />
            <div className="absolute inset-0 bg-[linear-gradient(to_right,rgba(255,255,255,0.05),transparent_25%,rgba(255,255,255,0.03),transparent_70%)] opacity-0 group-hover:opacity-100 transition-opacity duration-700" />
          </div>

          <div className="absolute inset-0" style={{ background: accentRadial[item.color] }} />

          <div
            className="absolute -top-24 -right-24 h-56 w-56 rounded-full blur-[80px] opacity-0 group-hover:opacity-60 transition-opacity duration-700"
            style={{ background: colorHex[item.color] || "#6366f1" }}
          />
          <motion.div
            animate={{ x: ["-120%", "120%"] }}
            transition={{ duration: 5.5, repeat: Infinity, ease: "linear", delay: i * 0.4 }}
            className="absolute inset-y-0 left-0 w-2/3 bg-gradient-to-r from-transparent via-white/6 to-transparent opacity-0 group-hover:opacity-100"
          />
          
          <div className="flex justify-between items-start mb-12 relative z-10">
            <div className="flex items-center gap-4">
              <div className="h-16 w-16 rounded-[22px] bg-white/5 flex items-center justify-center border border-white/10 group-hover:scale-110 group-hover:rotate-6 transition-all duration-500">
                <item.icon size={26} className="text-zinc-300/90" />
              </div>
            </div>
            <div className="px-4 py-2 rounded-full text-[11px] font-black tracking-widest border border-white/10 bg-white/5 text-zinc-200/90 shadow-[0_0_18px_rgba(0,0,0,0.25)] flex items-center gap-2">
              <TrendingUp size={14} className="text-zinc-300/70" />
              {item.change}
            </div>
          </div>
          
          <div className="space-y-2 relative z-10">
            <div className="text-[11px] font-black text-zinc-500 uppercase tracking-[0.42em] mb-2">{item.label}</div>
            <div className="flex items-end gap-4">
              <div className="text-6xl font-black text-white tracking-tighter italic gf-chromatic leading-none">
                {loading ? "…" : item.value}
              </div>
              <motion.div
                animate={{ scale: [1, 1.55, 1], opacity: [0.35, 1, 0.35] }}
                transition={{ duration: 2.2, repeat: Infinity, ease: "easeInOut", delay: i * 0.2 }}
                className="mb-3 h-2 w-2 rounded-full bg-indigo-500 shadow-[0_0_18px_rgba(99,102,241,0.9)]"
              />
            </div>
          </div>

          <div className="relative z-10 mt-10 flex items-end justify-between">
            <div className="text-[10px] font-black uppercase tracking-[0.28em] text-zinc-500 leading-[1.6]">
              <div>LAST</div>
              <div>7</div>
              <div>DAYS</div>
            </div>
            <div className="opacity-85 group-hover:opacity-100 transition-opacity translate-z-[1px]">
              <Sparkline values={spark[i % spark.length]} color={colorHex[item.color] || "#6366f1"} />
            </div>
          </div>

          {/* Bottom scanning animation */}
          <div className="absolute bottom-0 left-0 right-0 h-1 overflow-hidden opacity-0 group-hover:opacity-100 transition-opacity">
             <motion.div 
               animate={{ x: ["-100%", "100%"] }}
               transition={{ duration: 2.5, repeat: Infinity, ease: "linear" }}
               className="h-full w-full bg-gradient-to-r from-transparent via-indigo-500/60 to-transparent" 
             />
          </div>
        </motion.div>
      ))}
    </div>
  );
}

function RecentProjectCard({ p, idx, router }: { p: ProjectRow; idx: number; router: any }) {
  const bid = String(p._id || p.id || "");
  const b = badgeForStatus(p.status);
  const thumb = resolveMediaUrl(p.thumbnailUrl || p.previewImageUrl || p.imageUrl);

  return (
    <motion.button
      key={bid || idx}
      initial={{ opacity: 0, y: 16 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.35, delay: idx * 0.04 }}
      whileHover={{ y: -10, scale: 1.02 }}
      onClick={() => bid && router.push(`/studio/projects/${encodeURIComponent(bid)}`)}
      className="text-left gf-holographic rounded-[32px] border border-white/5 bg-white/[0.02] transition-all duration-500 group relative overflow-hidden flex flex-col h-full"
    >
      <div className="relative h-40 w-full overflow-hidden">
        {thumb ? (
          <img 
            src={thumb} 
            alt={p.name || "Project"} 
            className="w-full h-full object-cover group-hover:scale-110 transition-transform duration-700 opacity-80 group-hover:opacity-100"
          />
        ) : (
          <div className="absolute inset-0 bg-gradient-to-br from-indigo-500/15 via-fuchsia-500/10 to-black" />
        )}
        <div className="absolute inset-0 bg-gradient-to-t from-[#05060a] via-transparent to-transparent" />
        <div className="absolute top-4 right-4">
          <div className={cx("shrink-0 rounded-full border px-3 py-1 text-[9px] font-black uppercase tracking-widest backdrop-blur-md", b.cls)}>
            {b.label}
          </div>
        </div>
      </div>

      <div className="p-8 pt-4 relative flex-1 flex flex-col">
        <div className="absolute inset-0 opacity-0 group-hover:opacity-100 transition-opacity duration-500">
          <div className="absolute -top-16 -right-16 h-56 w-56 rounded-full bg-indigo-500/10 blur-[70px]" />
          <div className="absolute -bottom-16 -left-16 h-56 w-56 rounded-full bg-fuchsia-500/10 blur-[80px]" />
        </div>

        <div className="relative z-10 flex-1">
          <div className="text-[10px] font-black uppercase tracking-[0.3em] text-zinc-500">
            {(p.buildTarget || "web").toString().toUpperCase()}
          </div>
          <div className="mt-2 text-lg font-bold text-white tracking-tight truncate">
            {(p.name || "Untitled Project").toString()}
          </div>
          <div className="mt-2 text-[10px] font-black uppercase tracking-widest text-zinc-500">
            Updated {timeAgo(p.updatedAt || p.createdAt)}
          </div>
        </div>

        <div className="relative z-10 mt-6 flex items-center justify-between">
          <div className="flex items-center gap-2">
            <div className="h-2 w-2 rounded-full bg-emerald-500 animate-pulse" />
            <div className="text-[10px] font-mono text-zinc-500">GF_NODE::{idx + 1}</div>
          </div>
          <div className="text-[10px] font-black uppercase tracking-widest text-indigo-300/80 group-hover:text-indigo-200 transition-colors flex items-center gap-2">
            Open <ChevronRight size={12} />
          </div>
        </div>

        <motion.div
          animate={{ y: ["-120%", "220%"] }}
          transition={{ duration: 4.5, repeat: Infinity, ease: "linear", delay: idx * 0.15 }}
          className="absolute inset-0 w-full h-1/2 bg-gradient-to-b from-transparent via-white/5 to-transparent pointer-events-none"
        />
      </div>
    </motion.button>
  );
}

export default function StudioHomePage() {
  const router = useRouter();
  const token = useMemo(() => getUserToken(), []);
  const [me, setMe] = useState<Me | null>(null);
  const [stats, setStats] = useState<StatsResponse | null>(null);
  const [recent, setRecent] = useState<ProjectRow[]>([]);
  const [trendingGames, setTrendingGames] = useState<Array<{ id: string; title: string; views: number; imageUrl: string }>>([]);
  const [bestTemplate, setBestTemplate] = useState<{ id: string; name: string; downloads: number; imageUrl: string } | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [mousePos, setMousePos] = useState({ x: 0, y: 0 });

  useEffect(() => {
    const handleMouseMove = (e: MouseEvent) => {
      setMousePos({ x: e.clientX, y: e.clientY });
    };
    window.addEventListener("mousemove", handleMouseMove);
    return () => window.removeEventListener("mousemove", handleMouseMove);
  }, []);

  useEffect(() => {
    let cancelled = false;
    async function load() {
      if (!token) return;
      setLoading(true);
      setError(null);
      try {
        const [meRes, s, p, gf, tpls] = await Promise.all([
          apiFetch<any>("/auth/profile", { method: "GET", token }).catch(() => null),
          apiFetch<any>("/users/me/stats", { method: "GET", token }).catch(() => null),
          apiFetch<any>("/projects", { method: "GET", token }).catch(() => null),
          apiFetch<any>("/game-feed?limit=30", { method: "GET", token }).catch(() => null),
          apiFetch<any>("/templates", { method: "GET", token }).catch(() => null),
        ]);

        const meData = (meRes && typeof meRes === "object" && "data" in meRes) ? (meRes as any).data : meRes;
        if (!cancelled && meData) setMe((meData?.user ?? meData) as Me);

        const statsData = (s && typeof s === "object" && "data" in s) ? (s as any).data : s;
        if (!cancelled && statsData) setStats((statsData?.data ?? statsData) as StatsResponse);

        const pdata = (p && typeof p === "object" && "data" in p) ? (p as any).data : p;
        const items = Array.isArray((pdata as any)?.data) ? (pdata as any).data : (Array.isArray(pdata) ? pdata : []);
        const list = (Array.isArray(items) ? items : [])
          .filter(Boolean)
          .map((x: any) => (x && typeof x === "object" ? (x as ProjectRow) : ({} as ProjectRow)));
        list.sort((a, b) => {
          const ad = String(a.updatedAt || a.createdAt || "");
          const bd = String(b.updatedAt || b.createdAt || "");
          return bd.localeCompare(ad);
        });
        if (!cancelled) setRecent(list.slice(0, 6));

        // Trending Games from backend game-feed
        const gfData = (gf && typeof gf === "object" && "data" in gf) ? (gf as any).data : gf;
        const gfItems = Array.isArray((gfData as any)?.data) ? (gfData as any).data : (Array.isArray(gfData) ? gfData : []);
        const posts = (Array.isArray(gfItems) ? gfItems : [])
          .filter(Boolean)
          .map((x: any) => (x && typeof x === "object" ? (x as GameFeedPost) : ({} as GameFeedPost)));

        function gameScore(p: GameFeedPost) {
          const likes = asInt((p as any)?.likeCount);
          const plays = asInt((p as any)?.playCount);
          const views = asInt((p as any)?.viewCount);
          const v = views > 0 ? views : plays;
          return likes * 3 + Math.sqrt(Math.max(0, v)) * 2.2;
        }

        posts.sort((a, b) => gameScore(b) - gameScore(a));
        const topGames = posts.slice(0, 3).map((p, idx) => {
          const id = String((p as any)?.id || (p as any)?._id || `post_${idx}`);
          const title = String((p as any)?.title || (p as any)?.name || "Game");
          const plays = asInt((p as any)?.playCount);
          const views = asInt((p as any)?.viewCount);
          const v = views > 0 ? views : plays;
          const rawImg = (p as any)?.previewImageUrl || (p as any)?.previewImage || (p as any)?.thumbnailUrl || "";
          const imageUrl = resolveMediaUrl(rawImg);
          return { id, title, views: v, imageUrl };
        });
        if (!cancelled) setTrendingGames(topGames);

        // Best Template from backend templates
        const tData = (tpls && typeof tpls === "object" && "data" in tpls) ? (tpls as any).data : tpls;
        const tItems = Array.isArray((tData as any)?.data) ? (tData as any).data : (Array.isArray(tData) ? tData : []);
        const templates = (Array.isArray(tItems) ? tItems : [])
          .filter(Boolean)
          .map((x: any) => (x && typeof x === "object" ? (x as TemplateRow) : ({} as TemplateRow)));

        templates.sort((a, b) => templateScore(b) - templateScore(a));
        const best = templates[0];
        if (!cancelled) {
          if (best) {
            const id = String((best as any)?.id || (best as any)?._id || "");
            const name = String((best as any)?.name || (best as any)?.title || "Template");
            const downloads = asInt((best as any)?.downloads);
            const rawImg = (best as any)?.previewImageUrl || (best as any)?.previewImage || (best as any)?.thumbnailUrl || "";
            const imageUrl = resolveMediaUrl(rawImg);
            setBestTemplate({ id: id || name, name, downloads, imageUrl });
          } else {
            setBestTemplate(null);
          }
        }
      } catch (e: any) {
        if (!cancelled) {
          if (e instanceof ApiError) setError(e.message);
          else setError(e?.message || "Failed to load dashboard");
        }
      } finally {
        if (!cancelled) setLoading(false);
      }
    }
    load();
    return () => {
      cancelled = true;
    };
  }, [token]);

  return (
    <UserShell 
      title="Dashboard" 
      subtitle="OVERVIEW"
      right={
        <div className="flex items-center gap-3">
          <button 
            onClick={() => router.push("/studio/notifications")}
            className="group relative flex h-10 w-10 items-center justify-center rounded-xl border border-white/5 bg-white/[0.02] text-zinc-400 hover:text-white hover:bg-white/10 transition-all shadow-lg overflow-hidden"
          >
            <div className="absolute inset-0 bg-gradient-to-br from-transparent via-white/5 to-transparent opacity-0 group-hover:opacity-100 transition-opacity" />
            <Bell size={20} className="relative z-10 transition-transform group-hover:rotate-12" />
            <span className="absolute top-2 right-2 h-2 w-2 rounded-full bg-indigo-500 shadow-[0_0_8px_rgba(99,102,241,0.8)] animate-pulse" />
          </button>

          <button 
            onClick={() => router.push("/studio/settings")}
            className="group relative flex h-10 w-10 items-center justify-center rounded-xl border border-white/5 bg-white/[0.02] hover:bg-white/10 transition-all shadow-lg overflow-hidden"
          >
            <div className="absolute inset-0 bg-gradient-to-br from-transparent via-indigo-500/10 to-transparent opacity-0 group-hover:opacity-100 transition-opacity" />
            {(me as any)?.avatar ? (
              <img 
                src={resolveMediaUrl((me as any).avatar)} 
                alt="Profile" 
                className="h-full w-full object-cover group-hover:scale-110 transition-transform duration-500" 
              />
            ) : (
              <div className="h-full w-full flex items-center justify-center bg-gradient-to-br from-indigo-500/20 to-purple-500/20 text-indigo-400 group-hover:text-white transition-colors">
                <Users size={18} />
              </div>
            )}
            <div className="absolute inset-0 border border-white/0 group-hover:border-white/10 rounded-xl transition-all" />
          </button>
        </div>
      }
    >
      <div className="fixed inset-0 pointer-events-none z-0 overflow-hidden">
        <motion.div 
          animate={{
            scale: [1, 1.15, 1],
            x: [0, 40, 0],
            y: [0, 30, 0],
          }}
          transition={{ duration: 25, repeat: Infinity, ease: "easeInOut" }}
          className="absolute -top-[10%] -right-[5%] w-[50%] h-[50%] rounded-full bg-indigo-500/5 blur-[120px]"
        />
        <motion.div 
          animate={{
            scale: [1.1, 1, 1.1],
            x: [0, -30, 0],
            y: [0, -20, 0],
          }}
          transition={{ duration: 30, repeat: Infinity, ease: "easeInOut", delay: 1 }}
          className="absolute -bottom-[5%] -left-[5%] w-[45%] h-[45%] rounded-full bg-fuchsia-500/5 blur-[130px]"
        />
        <div 
          className="absolute inset-0 opacity-[0.1]"
          style={{
            background: `radial-gradient(circle at ${mousePos.x}px ${mousePos.y}px, rgba(99, 102, 241, 0.12) 0%, transparent 35%)`
          }}
        />
      </div>

      {error ? <div className="mb-6 relative z-10 rounded-2xl border border-red-500/20 bg-red-500/10 px-4 py-3 text-sm text-red-200">{error}</div> : null}

      <div className="space-y-12 pt-8">
        {/* PRO MAX: Header Greeting Card */}
        <section className="animate-in fade-in slide-in-from-top-4 duration-700">
          <GreetingCard username={me?.username} />
        </section>

        <section className="animate-in fade-in slide-in-from-bottom-4 duration-700">
          <PremiumStatsGrid stats={stats} loading={loading} />
        </section>

        {/* PRO MAX: AI Coach Tip Section */}
        <section className="animate-in fade-in slide-in-from-bottom-4 duration-700">
          <AICoachTip />
        </section>

        <section className="animate-in fade-in slide-in-from-bottom-4 duration-700 delay-300">
          <div className="grid grid-cols-1 gap-12">
            <TrendingArcade games={trendingGames} />
            <BestPickTemplate template={bestTemplate} />
          </div>
        </section>

        <section className="animate-in fade-in slide-in-from-bottom-4 duration-700 delay-400">
          <div className="flex items-center justify-between mb-6">
            <h3 className="text-[11px] font-black text-white uppercase tracking-[0.3em] flex items-center gap-3">
              <div className="h-1 w-8 bg-fuchsia-500 rounded-full" />
              Recent Projects
            </h3>
            <button
              onClick={() => router.push("/studio/projects")}
              className="gf-btn rounded-xl px-4 py-2 text-[10px] font-black uppercase tracking-widest text-zinc-300 hover:text-white transition-all"
            >
              View all
            </button>
          </div>

          {recent.length === 0 ? (
            <div className="gf-panel rounded-[32px] p-10 border border-white/5 bg-white/[0.02]">
              <div className="text-sm font-bold text-white">No projects yet</div>
              <div className="mt-2 text-xs text-zinc-500 font-medium">Create your first project and it will appear here.</div>
              <button
                onClick={() => router.push("/studio/projects/new")}
                className="mt-6 gf-glow rounded-xl bg-indigo-500 px-5 py-2.5 text-xs font-black uppercase tracking-widest text-white transition-all hover:scale-105 active:scale-95"
              >
                New Project
              </button>
            </div>
          ) : (
            <div className="grid grid-cols-1 gap-6 md:grid-cols-2 xl:grid-cols-3">
              {recent.map((p, idx) => (
                <RecentProjectCard key={p._id || p.id || idx} p={p} idx={idx} router={router} />
              ))}
            </div>
          )}
        </section>

        <section className="animate-in fade-in slide-in-from-bottom-4 duration-700 delay-200">
          <div className="flex items-center justify-between mb-6">
            <h3 className="text-[11px] font-black text-white uppercase tracking-[0.3em] flex items-center gap-3">
              <div className="h-1 w-8 bg-indigo-500 rounded-full" />
              Creator Milestones
            </h3>
          </div>
          <AchievementSystem />
        </section>

        <section className="animate-in fade-in slide-in-from-bottom-4 duration-700 delay-200">
          <div className="flex items-center justify-between mb-6">
            <h3 className="text-[11px] font-black text-white uppercase tracking-[0.3em] flex items-center gap-3">
              <div className="h-1 w-8 bg-indigo-500 rounded-full" />
              Mission Architecture
            </h3>
          </div>
          <AIStoryboard />
        </section>

        <section className="grid grid-cols-1 gap-6 lg:grid-cols-3 animate-in fade-in slide-in-from-bottom-4 duration-700 delay-300">
          <div className="gf-panel-strong gf-stroke-gradient gf-glow-hover rounded-[40px] p-10 lg:col-span-2 relative overflow-hidden group">
            <div className="absolute top-0 right-0 p-10 opacity-[0.03] group-hover:opacity-[0.07] transition-opacity duration-500">
              <Rocket size={240} />
            </div>
            
            <div className="relative z-10">
              <div className="inline-flex items-center gap-2 rounded-full border border-indigo-500/20 bg-indigo-500/5 px-4 py-1.5 text-[10px] font-black uppercase tracking-widest text-indigo-400 mb-6">
                <Sparkles size={12} />
                Jump back in
              </div>
              <h2 className="text-3xl font-bold text-white tracking-tight">Ready to build?</h2>
              <p className="mt-3 max-w-md text-sm text-zinc-400 font-medium">Continue where you left off or explore community-made templates to fork.</p>
              
              <div className="mt-10 grid grid-cols-1 gap-4 sm:grid-cols-2">
                <button
                  onClick={() => router.push("/studio/projects/new")}
                  className="group relative flex flex-col justify-between overflow-hidden rounded-[28px] border border-white/5 bg-white/[0.03] p-6 text-left transition-all hover:bg-white/[0.06] hover:scale-[1.02] active:scale-[0.98]"
                >
                  <div className="h-10 w-10 rounded-2xl bg-indigo-500/20 flex items-center justify-center text-indigo-400 mb-8 transition-transform group-hover:-translate-y-1">
                    <Rocket size={20} />
                  </div>
                  <div>
                    <div className="text-sm font-bold text-white uppercase tracking-wider">Create project</div>
                    <div className="mt-1 text-xs text-zinc-500 font-medium">Start fresh logic</div>
                  </div>
                </button>
                <button
                  onClick={() => router.push("/studio/marketplace")}
                  className="group relative flex flex-col justify-between overflow-hidden rounded-[28px] border border-white/5 bg-white/[0.03] p-6 text-left transition-all hover:bg-white/[0.06] hover:scale-[1.02] active:scale-[0.98]"
                >
                  <div className="h-10 w-10 rounded-2xl bg-fuchsia-500/20 flex items-center justify-center text-fuchsia-400 mb-8 transition-transform group-hover:-translate-y-1">
                    <Layers size={20} />
                  </div>
                  <div>
                    <div className="text-sm font-bold text-white uppercase tracking-wider">Marketplace</div>
                    <div className="mt-1 text-xs text-zinc-500 font-medium">Browse templates</div>
                  </div>
                </button>
              </div>
            </div>
          </div>

          <div className="gf-panel gf-glow-hover rounded-[40px] p-10 flex flex-col justify-between group relative overflow-hidden">
            <div className="absolute inset-0 bg-gradient-to-br from-fuchsia-500/5 via-transparent to-transparent opacity-50" />
            <div className="relative z-10">
              <h2 className="text-xs font-black text-white uppercase tracking-[0.3em] mb-8 flex items-center gap-2">
                <Activity size={14} className="text-fuchsia-400" />
                System Health
              </h2>
              <div className="space-y-8">
                <div className="space-y-3">
                  <div className="flex justify-between items-end">
                    <span className="text-[10px] font-black text-zinc-500 uppercase tracking-widest">Build Pipeline</span>
                    <span className="text-xs font-mono text-emerald-400 font-bold">Stable</span>
                  </div>
                  <div className="h-1.5 w-full bg-white/5 rounded-full overflow-hidden border border-white/5">
                    <motion.div 
                      initial={{ width: 0 }}
                      animate={{ width: "98.2%" }}
                      transition={{ duration: 1.5, ease: "easeOut" }}
                      className="h-full bg-gradient-to-r from-emerald-500 to-teal-400 shadow-[0_0_10px_rgba(16,185,129,0.4)]" 
                    />
                  </div>
                </div>
                <div className="space-y-3">
                  <div className="flex justify-between items-end">
                    <span className="text-[10px] font-black text-zinc-500 uppercase tracking-widest">Credit Usage</span>
                    <span className="text-xs font-mono text-indigo-400 font-bold">420 GC</span>
                  </div>
                  <div className="h-1.5 w-full bg-white/5 rounded-full overflow-hidden border border-white/5">
                    <motion.div 
                      initial={{ width: 0 }}
                      animate={{ width: "40%" }}
                      transition={{ duration: 1.5, ease: "easeOut", delay: 0.2 }}
                      className="h-full bg-gradient-to-r from-indigo-500 to-fuchsia-500 shadow-[0_0_10px_rgba(99,102,241,0.4)]" 
                    />
                  </div>
                </div>
              </div>
            </div>
            
            <button 
              className="mt-10 w-full rounded-2xl bg-white/[0.03] border border-white/5 py-4 text-[10px] font-black uppercase tracking-[0.2em] text-zinc-400 transition hover:bg-white/[0.06] hover:text-white"
              onClick={() => router.push("/studio/wallet")}
            >
              View Wallet
            </button>
          </div>
        </section>

        <section className="animate-in fade-in slide-in-from-bottom-4 duration-700 delay-400">
          <div className="flex items-center justify-between mb-6">
            <h3 className="text-[11px] font-black text-white uppercase tracking-[0.3em] flex items-center gap-3">
              <div className="h-1 w-8 bg-indigo-500 rounded-full" />
              Live Feed
            </h3>
            <div className="text-[10px] font-black text-emerald-400 bg-emerald-500/10 px-2 py-1 rounded-lg uppercase tracking-widest animate-pulse">
              Streaming
            </div>
          </div>
          <GlobalActivityFeed />
        </section>
      </div>
    </UserShell>
  );
}
