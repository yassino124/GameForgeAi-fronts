"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { useQuery } from "@tanstack/react-query";
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
import { useAuthToken } from "@/lib/stores/authStore";
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

type StudioDashboardData = {
  me: Me | null;
  stats: StatsResponse | null;
  recent: ProjectRow[];
  trendingGames: Array<{ id: string; title: string; views: number; imageUrl: string }>;
  bestTemplate: { id: string; name: string; downloads: number; imageUrl: string } | null;
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
  if (st === "building" || st === "queued") return { label: "BUILDING", cls: "border-blue-500/20 bg-blue-600/10 text-blue-300" };
  if (st === "failed") return { label: "FAILED", cls: "border-red-500/20 bg-red-500/10 text-red-200" };
  return { label: (st || "draft").toUpperCase(), cls: "border-white/10 bg-white/5 text-zinc-300" };
}

function SectionLabel({ icon: Icon, text }: { icon: any; text: string }) {
  return (
    <div className="flex items-center gap-4">
      <div className="flex items-center gap-3">
        <div className="h-5 w-1 rounded-full bg-blue-500 shadow-[0_0_8px_rgba(37,99,235,0.6)]" />
        <div className="h-8 w-8 rounded-xl bg-blue-600/10 border border-blue-500/20 flex items-center justify-center">
          <Icon size={14} className="text-blue-400" />
        </div>
        <span className="text-[11px] font-black text-[var(--foreground)] uppercase tracking-[0.38em]">{text}</span>
      </div>
      <div className="flex-1 h-px bg-gradient-to-r from-white/[0.06] to-transparent" />
    </div>
  );
}

function AICoachTip() {
  const AI_TIPS = [
    { text: "Use procedural mesh generation for infinite terrain variety.", tag: "Performance" },
    { text: "Compress textures before WebGL export — cuts size by 60%.", tag: "Optimization" },
    { text: "Add AI Navigation meshes to make your NPCs feel truly alive.", tag: "AI" },
    { text: "The Cyberpunk template ships with a built-in neon shader.", tag: "Templates" },
    { text: "Connect Discord to receive real-time build status alerts.", tag: "Workflow" },
  ];

  const [tipIdx, setTipIdx] = useState(0);
  const [dismissed, setDismissed] = useState(false);
  const router = useRouter();

  useEffect(() => {
    const interval = setInterval(() => setTipIdx((p) => (p + 1) % AI_TIPS.length), 7000);
    return () => clearInterval(interval);
  }, []);

  if (dismissed) return null;

  const tip = AI_TIPS[tipIdx];

  return (
    <motion.div
      layout
      initial={{ opacity: 0, y: 10 }}
      animate={{ opacity: 1, y: 0 }}
      className="relative overflow-hidden rounded-[24px] border border-white/[0.07] bg-[var(--gf-panel-bg-strong)] px-6 py-5 group"
    >
      {/* Ambient glow */}
      <div className="absolute inset-0 bg-[radial-gradient(ellipse_at_left,rgba(37,99,235,0.08),transparent_60%)] pointer-events-none" />

      <div className="relative z-10 flex items-center gap-5">
        {/* Icon */}
        <div className="shrink-0 h-10 w-10 rounded-2xl bg-blue-600/15 border border-blue-500/20 flex items-center justify-center">
          <motion.div
            animate={{ scale: [1, 1.15, 1] }}
            transition={{ duration: 2.5, repeat: Infinity }}
          >
            <Sparkles size={16} className="text-blue-400" />
          </motion.div>
        </div>

        {/* Text */}
        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-2 mb-1">
            <span className="text-[9px] font-black uppercase tracking-[0.35em] text-blue-500">AI Coach</span>
            <span className="text-[9px] text-zinc-700">/</span>
            <span className="text-[9px] font-black uppercase tracking-[0.28em] text-zinc-600">{tip.tag}</span>
          </div>
          <AnimatePresence mode="wait">
            <motion.p
              key={tipIdx}
              initial={{ opacity: 0, x: 12 }}
              animate={{ opacity: 1, x: 0 }}
              exit={{ opacity: 0, x: -12 }}
              transition={{ duration: 0.35 }}
              className="text-[13px] font-semibold text-[var(--foreground)] leading-snug truncate"
            >
              {tip.text}
            </motion.p>
          </AnimatePresence>
        </div>

        {/* Tip counter dots */}
        <div className="shrink-0 flex gap-1">
          {AI_TIPS.map((_, i) => (
            <button
              key={i}
              onClick={() => setTipIdx(i)}
              className={`h-1.5 rounded-full transition-all duration-300 ${i === tipIdx ? "w-5 bg-blue-500" : "w-1.5 bg-white/15 hover:bg-white/30"
                }`}
            />
          ))}
        </div>

        {/* Actions */}
        <div className="shrink-0 flex items-center gap-2">
          <button
            onClick={() => router.push("/studio/ai/coach")}
            className="px-4 py-2 rounded-xl bg-blue-600/15 border border-blue-500/20 text-blue-300 text-[10px] font-black uppercase tracking-widest hover:bg-blue-600/25 transition-all"
          >
            Learn
          </button>
          <button
            onClick={() => setDismissed(true)}
            className="h-8 w-8 rounded-xl bg-white/[0.03] border border-white/[0.06] flex items-center justify-center text-zinc-600 hover:text-zinc-400 hover:bg-white/[0.06] transition-all text-base leading-none"
          >
            ×
          </button>
        </div>
      </div>
    </motion.div>
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
        <h3 className="text-[16px] font-black text-[var(--foreground)] uppercase tracking-[0.4em] flex items-center gap-4">
          <div className="h-1 w-10 bg-blue-600 rounded-full" />
          Trending Games
        </h3>
        <button className="text-[11px] font-black uppercase tracking-widest text-blue-400 hover:text-blue-300 transition-colors">SEE ALL</button>
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
            className="group relative min-w-[320px] aspect-square rounded-[48px] overflow-hidden border border-white/5 bg-[var(--gf-panel-bg-strong)] shadow-[0_30px_60px_rgba(0,0,0,0.4)]"
          >
            {game.imageUrl ? (
              <img src={game.imageUrl} alt={game.title} className="w-full h-full object-cover opacity-70 group-hover:scale-110 group-hover:opacity-100 transition-all duration-1000" />
            ) : (
              <div className="absolute inset-0 bg-gradient-to-br from-blue-600/20 via-sky-500/8 to-black" />
            )}
            <div className="absolute inset-0 bg-gradient-to-t from-[var(--gf-bg)] via-transparent to-transparent opacity-80" />
            <div className="absolute bottom-0 left-0 right-0 p-10">
              <h4 className="text-2xl font-bold text-[var(--foreground)] mb-3 leading-tight tracking-tight group-hover:text-blue-500 transition-colors">{game.title}</h4>
              <div className="flex items-center justify-between pt-2 border-t border-white/5 mt-4">
                <div className="flex items-center gap-4">
                  <span className="flex items-center gap-2 text-[12px] text-[var(--gf-text-muted)] font-bold uppercase tracking-widest">
                    <Eye size={16} className="text-zinc-500" /> {game.views}
                  </span>
                </div>
                <div className="h-12 w-12 rounded-[20px] bg-white/10 backdrop-blur-md border border-white/10 flex items-center justify-center text-[var(--foreground)] hover:bg-blue-600 transition-colors">
                  <Heart size={20} className="text-[var(--foreground)] fill-white/20 group-hover:fill-white transition-all" />
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
        <h3 className="text-[16px] font-black text-[var(--foreground)] uppercase tracking-[0.4em] flex items-center gap-4">
          <div className="h-1 w-10 bg-blue-500 rounded-full" />
          Top Rated Template
        </h3>
        <button className="text-[11px] font-black uppercase tracking-widest text-blue-400 hover:text-sky-300 transition-colors">BROWSE</button>
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
          <div className="absolute inset-0 bg-gradient-to-br from-blue-600/20 via-sky-500/10 to-black" />
        )}
        <div className="absolute inset-0 bg-gradient-to-r from-black via-black/40 to-transparent" />
        <div className="absolute inset-0 p-12 flex flex-col justify-between items-start">
          <motion.div
            animate={{ scale: [1, 1.05, 1] }}
            transition={{ duration: 2, repeat: Infinity }}
            className="px-6 py-2.5 rounded-full bg-blue-600 text-white text-[11px] font-black uppercase tracking-[0.2em] shadow-[0_15px_30px_rgba(37,99,235,0.4)] border border-white/20"
          >
            BEST PICK
          </motion.div>
          <div className="flex justify-between items-end w-full">
            <div className="space-y-3">
              <h2 className="text-5xl font-black text-[var(--foreground)] tracking-tighter uppercase italic gf-chromatic">{t?.name || "—"}</h2>
              <div className="flex items-center gap-6">
                <div className="flex items-center gap-2">
                  <Star size={14} className="text-yellow-400 fill-yellow-400" />
                  <span className="text-[12px] font-black text-zinc-400 uppercase tracking-widest">Top rated</span>
                </div>
                <div className="h-1 w-1 rounded-full bg-zinc-600" />
                <div className="flex items-center gap-2">
                  <Zap size={14} className="text-blue-400 fill-blue-400" />
                  <span className="text-[12px] font-black text-zinc-400 uppercase tracking-widest">{t ? `${t.downloads} downloads` : "—"}</span>
                </div>
              </div>
            </div>
            <motion.div
              whileHover={{ x: 10 }}
              className="h-16 w-16 rounded-[24px] bg-white/10 backdrop-blur-md border border-white/20 flex items-center justify-center text-[var(--foreground)] hover:bg-white/20 transition-all cursor-pointer"
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

  const particles = [
    { x: "8%", y: "15%", size: 2, delay: 0, dur: 6 },
    { x: "18%", y: "75%", size: 1.5, delay: 1.2, dur: 8 },
    { x: "35%", y: "25%", size: 1, delay: 2, dur: 7 },
    { x: "55%", y: "80%", size: 2.5, delay: 0.5, dur: 9 },
    { x: "70%", y: "10%", size: 1.5, delay: 3, dur: 6.5 },
    { x: "85%", y: "60%", size: 1, delay: 1.5, dur: 7.5 },
    { x: "92%", y: "30%", size: 2, delay: 2.5, dur: 8.5 },
    { x: "45%", y: "50%", size: 1, delay: 4, dur: 10 },
  ];

  return (
    <motion.div
      initial={{ opacity: 0, y: 24 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.7, ease: [0.16, 1, 0.3, 1] }}
      className="studio-hero relative overflow-hidden rounded-[44px] border border-white/[0.07] bg-[var(--gf-shell-bg)] shadow-[0_60px_120px_rgba(0,0,0,0.75)]"
    >
      {/* ── Fine grid ── */}
      <div
        className="pointer-events-none absolute inset-0 opacity-[0.055]"
        style={{
          backgroundImage: "linear-gradient(rgba(255,255,255,0.2) 1px, transparent 1px), linear-gradient(90deg, rgba(255,255,255,0.2) 1px, transparent 1px)",
          backgroundSize: "44px 44px",
        }}
      />

      {/* ── Noise texture overlay ── */}
      <div
        className="pointer-events-none absolute inset-0 opacity-[0.025]"
        style={{ backgroundImage: "url(\"data:image/svg+xml,%3Csvg viewBox='0 0 256 256' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='noise'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.9' numOctaves='4' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23noise)' opacity='1'/%3E%3C/svg%3E\")" }}
      />

      {/* ── Atmospheric glows ── */}
      <div className="pointer-events-none absolute inset-0">
        <motion.div
          animate={{ scale: [1, 1.18, 1], opacity: [0.2, 0.32, 0.2] }}
          transition={{ duration: 12, repeat: Infinity, ease: "easeInOut" }}
          className="absolute top-[-20%] left-1/2 -translate-x-1/2 h-[500px] w-[800px] rounded-full bg-blue-600/25 blur-[130px]"
        />
        <motion.div
          animate={{ scale: [1.1, 1, 1.1], opacity: [0.06, 0.12, 0.06] }}
          transition={{ duration: 16, repeat: Infinity, ease: "easeInOut", delay: 3 }}
          className="absolute -bottom-20 -left-10 h-[320px] w-[520px] rounded-full bg-sky-500/15 blur-[100px]"
        />
        <motion.div
          animate={{ scale: [1, 1.2, 1], opacity: [0.05, 0.10, 0.05] }}
          transition={{ duration: 18, repeat: Infinity, ease: "easeInOut", delay: 5 }}
          className="absolute -bottom-10 right-0 h-[280px] w-[400px] rounded-full bg-blue-800/12 blur-[90px]"
        />
      </div>

      {/* ── Floating particles ── */}
      <div className="pointer-events-none absolute inset-0">
        {particles.map((p, i) => (
          <motion.div
            key={i}
            animate={{ y: [0, -18, 0], opacity: [0.15, 0.55, 0.15] }}
            transition={{ duration: p.dur, repeat: Infinity, ease: "easeInOut", delay: p.delay }}
            className="absolute rounded-full bg-blue-400"
            style={{ left: p.x, top: p.y, width: p.size * 2, height: p.size * 2, boxShadow: `0 0 ${p.size * 6}px rgba(96,165,250,0.5)` }}
          />
        ))}
      </div>

      <div className="relative z-10 flex flex-col lg:flex-row items-center justify-between gap-10 px-10 py-14 lg:px-16 lg:py-16">
        {/* ── Left: text ── */}
        <div className="flex-1 space-y-9 text-center lg:text-left">

          {/* Badge */}
          <motion.div
            initial={{ opacity: 0, y: -10 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.15 }}
            className="inline-flex items-center gap-2.5 rounded-full border border-blue-500/22 bg-blue-600/8 px-4 py-1.5 text-[10px] font-black uppercase tracking-[0.3em] text-blue-300"
          >
            <motion.span
              animate={{ scale: [1, 1.4, 1], opacity: [0.7, 1, 0.7] }}
              transition={{ duration: 2, repeat: Infinity }}
              className="h-1.5 w-1.5 rounded-full bg-blue-400 shadow-[0_0_10px_rgba(96,165,250,0.9)]"
            />
            Studio Dashboard
            <span className="text-blue-500/50">·</span>
            <span className="text-blue-400/65">Active</span>
          </motion.div>

          {/* Greeting + Name */}
          <div>
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              transition={{ delay: 0.25 }}
              className="text-[10px] font-black text-zinc-700 uppercase tracking-[0.6em] mb-3"
            >
              {greeting}
            </motion.div>

            <motion.h1
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.35, duration: 0.65 }}
              className="studio-hero-title font-black tracking-tighter text-[var(--foreground)] leading-[0.88] uppercase"
              style={{ fontSize: "clamp(3.5rem, 8vw, 6.5rem)" }}
            >
              {username || "Creator"}<span className="text-blue-400">.</span>
            </motion.h1>

            <motion.p
              initial={{ opacity: 0, y: 8 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.5 }}
              className="mt-5 text-[var(--gf-text-muted)] font-medium text-xl max-w-sm mx-auto lg:mx-0 leading-relaxed"
            >
              Your next masterpiece is one prompt away.
            </motion.p>
          </div>

          {/* CTAs */}
          <motion.div
            initial={{ opacity: 0, y: 12 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.6 }}
            className="flex flex-wrap justify-center lg:justify-start gap-4"
          >
            <button
              onClick={() => router.push("/studio/projects/new")}
              className="group relative overflow-hidden flex items-center gap-3 px-9 py-4 rounded-2xl bg-blue-600 text-white text-[11px] font-black uppercase tracking-widest hover:bg-blue-500 transition-all shadow-[0_20px_48px_rgba(37,99,235,0.38)] hover:shadow-[0_28px_64px_rgba(37,99,235,0.52)]"
            >
              <div className="absolute inset-0 bg-gradient-to-r from-transparent via-white/25 to-transparent -translate-x-full group-hover:translate-x-full transition-transform duration-700" />
              <span className="relative">Forge New Game</span>
              <Plus size={16} className="relative" />
            </button>
            <button
              onClick={() => router.push("/studio/marketplace")}
              className="flex items-center gap-2 px-9 py-4 rounded-2xl bg-white/[0.04] text-zinc-300 text-[11px] font-black uppercase tracking-widest hover:bg-white/[0.09] hover:text-[var(--foreground)] transition-all border border-white/[0.08]"
            >
              Browse Templates
            </button>
          </motion.div>

          {/* Social proof strip */}
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ delay: 0.75 }}
            className="flex items-center gap-5 text-[10px] font-black text-zinc-600 uppercase tracking-widest"
          >
            <div className="flex items-center gap-1.5 px-3 mb-2 opacity-50 relative z-20">
              <div className="h-1.5 w-1.5 rounded-full bg-blue-500" />
              iOS · Android · WebGL
            </div>
            <div className="h-3 w-px bg-white/10" />
            <div>Ship in minutes</div>
          </motion.div>
        </div>

        {/* ── Right: live preview card ── */}
        <motion.div
          initial={{ opacity: 0, scale: 0.85, y: 24 }}
          animate={{ opacity: 1, scale: 1, y: 0 }}
          transition={{ delay: 0.4, duration: 0.9, type: "spring", stiffness: 180, damping: 22 }}
          className="relative shrink-0 hidden lg:block"
        >
          {/* Outer glow */}
          <motion.div
            animate={{ opacity: [0.4, 0.7, 0.4] }}
            transition={{ duration: 4, repeat: Infinity, ease: "easeInOut" }}
            className="absolute -inset-6 bg-blue-600/10 blur-[50px] rounded-[50%]"
          />

          <div className="studio-preview relative w-[290px] rounded-[32px] border border-white/[0.1] bg-[var(--gf-shell-bg)] backdrop-blur-2xl shadow-[0_40px_80px_rgba(0,0,0,0.7)] overflow-hidden">
            {/* Traffic lights header */}
            <div className="flex items-center gap-2 px-5 py-3.5 border-b border-white/[0.06] bg-white/[0.015]">
              <div className="flex gap-1.5">
                <div className="h-2.5 w-2.5 rounded-full bg-red-500/80" />
                <div className="h-2.5 w-2.5 rounded-full bg-amber-500/80" />
                <div className="h-2.5 w-2.5 rounded-full bg-blue-500/80 shadow-[0_0_12px_rgba(59,130,246,0.6)]" />
              </div>
              <div className="flex-1 text-center text-[9px] font-mono text-zinc-600 tracking-[0.12em]">
                gameforge.studio / build
              </div>
            </div>

            <div className="p-5 space-y-4">
              {/* Live badge row */}
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-2 rounded-full border border-blue-500/22 bg-blue-500/8 px-3 py-1 bg-[var(--gf-panel-bg-strong)]/60 backdrop-blur-xl">
                  <motion.div
                    animate={{ opacity: [1, 0.4, 1] }}
                    transition={{ duration: 2, repeat: Infinity, ease: "easeInOut" }}
                    className="h-1.5 w-1.5 rounded-full bg-blue-400 shadow-[0_0_10px_rgba(59,130,246,0.8)]"
                  />
                  <span className="text-[9px] font-black text-blue-300 uppercase tracking-widest">Live Preview</span>
                </div>
                <span className="text-[9px] font-black text-zinc-600 uppercase tracking-widest">WebGL · 60fps</span>
              </div>

              {/* Game preview */}
              <div className="relative h-36 rounded-2xl overflow-hidden bg-[var(--gf-panel-bg-strong)] border border-white/[0.05]">
                <div
                  className="absolute inset-0 opacity-[0.25]"
                  style={{
                    backgroundImage: "linear-gradient(rgba(37,99,235,0.25) 1px, transparent 1px), linear-gradient(90deg, rgba(37,99,235,0.25) 1px, transparent 1px)",
                    backgroundSize: "22px 22px",
                  }}
                />
                {/* Ambient corner glows */}
                <div className="absolute -top-8 -left-8 w-32 h-32 rounded-full bg-blue-600/15 blur-[30px]" />
                <div className="absolute -bottom-8 -right-8 w-32 h-32 rounded-full bg-sky-500/10 blur-[30px]" />
                <motion.div
                  animate={{ y: [0, -8, 0], rotate: [0, 3, 0] }}
                  transition={{ duration: 3.5, repeat: Infinity, ease: "easeInOut" }}
                  className="absolute inset-0 flex items-center justify-center"
                >
                  <div className="p-5 rounded-3xl bg-gradient-to-br from-blue-600 to-sky-500 shadow-[0_0_40px_rgba(37,99,235,0.55)]">
                    <Cpu size={40} className="text-white" />
                  </div>
                </motion.div>
              </div>

              {/* Build progress */}
              <div className="space-y-1.5">
                <div className="flex items-center justify-between">
                  <span className="text-[9px] font-black text-zinc-600 uppercase tracking-widest">Build Progress</span>
                  <span className="text-[9px] font-black text-blue-400">87%</span>
                </div>
                <div className="h-[3px] w-full bg-white/[0.05] rounded-full overflow-hidden">
                  <motion.div
                    initial={{ width: "0%" }}
                    animate={{ width: "87%" }}
                    transition={{ duration: 1.8, delay: 0.8, ease: "easeOut" }}
                    className="h-full bg-gradient-to-r from-blue-600 via-blue-400 to-sky-400 rounded-full"
                    style={{ boxShadow: "0 0 8px rgba(37,99,235,0.6)" }}
                  />
                </div>
              </div>

              {/* Stats */}
              <div className="grid grid-cols-3 gap-2">
                {[
                  { label: "Platforms", value: "5" },
                  { label: "Build ETA", value: "2m 14s" },
                  { label: "Size", value: "4.2 MB" },
                ].map((s) => (
                  <div key={s.label} className="text-center p-2 rounded-xl bg-white/[0.025] border border-white/[0.05]">
                    <div className="text-[13px] font-black text-[var(--foreground)]">{s.value}</div>
                    <div className="text-[8px] text-[var(--gf-text-muted)] uppercase tracking-widest mt-0.5">{s.label}</div>
                  </div>
                ))}
              </div>
            </div>
          </div>
        </motion.div>
      </div>

      {/* ── Bottom accent line ── */}
      <div className="absolute bottom-0 left-0 right-0 h-px bg-gradient-to-r from-transparent via-blue-500/30 to-transparent" />
    </motion.div>
  );
}

function PremiumStatsGrid({ stats, loading }: { stats: StatsResponse | null; loading: boolean }) {
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

  const cardConfig = [
    { label: "Projects", value: fmt(stats?.projects), icon: Rocket, color: "#2563eb", glow: "rgba(37,99,235,0.45)", radial: "radial-gradient(circle at 18% 22%, rgba(37,99,235,0.38), transparent 52%)", dot: "bg-blue-500", shimmer: "via-blue-400/10" },
    { label: "Templates", value: fmt(stats?.templates), icon: Layers, color: "#3b82f6", glow: "rgba(59,130,246,0.40)", radial: "radial-gradient(circle at 18% 22%, rgba(59,130,246,0.33), transparent 52%)", dot: "bg-blue-500", shimmer: "via-blue-400/10" },
    { label: "Downloads", value: fmt(stats?.downloads), icon: ExternalLink, color: "#22d3ee", glow: "rgba(34,211,238,0.38)", radial: "radial-gradient(circle at 18% 22%, rgba(34,211,238,0.30), transparent 52%)", dot: "bg-cyan-400", shimmer: "via-cyan-300/10" },
    { label: "Generations", value: fmt(stats?.generations), icon: Sparkles, color: "#f59e0b", glow: "rgba(245,158,11,0.38)", radial: "radial-gradient(circle at 18% 22%, rgba(245,158,11,0.28), transparent 52%)", dot: "bg-amber-400", shimmer: "via-amber-300/10" },
  ];

  return (
    <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6">
      {cardConfig.map((item, i) => (
        <motion.div
          key={i}
          initial={{ opacity: 0, y: 28 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.55, delay: i * 0.08, ease: [0.16, 1, 0.3, 1] }}
          whileHover={{ y: -10, scale: 1.025 }}
          className="relative overflow-hidden rounded-[36px] border border-white/[0.07] bg-[var(--gf-panel-bg-strong)]/80 backdrop-blur-2xl p-8 group shadow-[0_16px_48px_rgba(0,0,0,0.4)] hover:shadow-[0_32px_80px_rgba(0,0,0,0.65)] transition-all duration-500"
        >
          <div className="absolute inset-0" style={{ background: item.radial }} />
          <div className="absolute -top-20 -right-20 h-48 w-48 rounded-full blur-[70px] opacity-0 group-hover:opacity-55 transition-opacity duration-500" style={{ background: item.glow }} />
          <motion.div
            animate={{ x: ["-120%", "120%"] }}
            transition={{ duration: 4, repeat: Infinity, ease: "linear", delay: i * 0.5 }}
            className={`absolute inset-y-0 left-0 w-3/5 bg-gradient-to-r from-transparent ${item.shimmer} to-transparent opacity-0 group-hover:opacity-100`}
          />
          <div className="relative z-10 flex items-start justify-between mb-10">
            <div className="h-12 w-12 rounded-2xl flex items-center justify-center border border-white/[0.09] group-hover:scale-110 group-hover:rotate-3 transition-all duration-300" style={{ background: `${item.color}22`, boxShadow: `0 0 18px ${item.color}30` }}>
              <item.icon size={21} style={{ color: item.color }} />
            </div>
            <div className="flex items-center gap-1.5 px-2.5 py-1 rounded-full border border-white/[0.06] bg-white/[0.03] text-[9px] font-black tracking-widest" style={{ color: item.color }}>
              <motion.span animate={{ opacity: [0.5, 1, 0.5] }} transition={{ duration: 2, repeat: Infinity }} className="h-1 w-1 rounded-full" style={{ background: item.color }} />
              LIVE
            </div>
          </div>
          <div className="relative z-10 mb-1">
            <div className="text-[10px] font-black text-zinc-600 uppercase tracking-[0.38em] mb-2">{item.label}</div>
            <div className="flex items-end gap-3">
              <div className="text-5xl font-black text-[var(--foreground)] tracking-tighter leading-none">{loading ? <span className="text-zinc-700">—</span> : item.value}</div>
              <motion.div animate={{ scale: [1, 1.6, 1], opacity: [0.4, 1, 0.4] }} transition={{ duration: 2.5, repeat: Infinity, ease: "easeInOut", delay: i * 0.3 }} className={`mb-2 h-2 w-2 rounded-full shrink-0 ${item.dot}`} style={{ boxShadow: `0 0 12px ${item.color}` }} />
            </div>
          </div>
          <div className="relative z-10 mt-8 flex items-end justify-between">
            <div className="text-[9px] font-black uppercase tracking-[0.3em] text-zinc-600">Last 7 days</div>
            <div className="opacity-70 group-hover:opacity-100 transition-opacity"><Sparkline values={spark[i % spark.length]} color={item.color} /></div>
          </div>
          <div className="absolute bottom-0 left-0 right-0 h-px overflow-hidden opacity-0 group-hover:opacity-100 transition-opacity">
            <motion.div animate={{ x: ["-100%", "100%"] }} transition={{ duration: 2.2, repeat: Infinity, ease: "linear" }} className="h-full w-full" style={{ background: `linear-gradient(to right, transparent, ${item.color}80, transparent)` }} />
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
          <div className="absolute inset-0 bg-gradient-to-br from-blue-600/15 via-sky-500/8 to-black" />
        )}
        <div className="absolute inset-0 bg-gradient-to-t from-[var(--gf-bg)] via-transparent to-transparent" />
        <div className="absolute top-4 right-4">
          <div className={cx("shrink-0 rounded-full border px-3 py-1 text-[9px] font-black uppercase tracking-widest backdrop-blur-md", b.cls)}>
            {b.label}
          </div>
        </div>
      </div>

      <div className="p-8 pt-4 relative flex-1 flex flex-col">
        <div className="absolute inset-0 opacity-0 group-hover:opacity-100 transition-opacity duration-500">
          <div className="absolute -top-16 -right-16 h-56 w-56 rounded-full bg-blue-600/10 blur-[70px]" />
          <div className="absolute -bottom-16 -left-16 h-56 w-56 rounded-full bg-sky-500/8 blur-[80px]" />
        </div>

        <div className="relative z-10 flex-1">
          <div className="text-[10px] font-black uppercase tracking-[0.3em] text-zinc-500">
            {(p.buildTarget || "web").toString().toUpperCase()}
          </div>
          <div className="mt-2 text-lg font-bold text-[var(--foreground)] tracking-tight truncate">
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
          <div className="text-[10px] font-black uppercase tracking-widest text-blue-300/80 group-hover:text-blue-200 transition-colors flex items-center gap-2">
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
  const { token, hydrated } = useAuthToken();
  const [mousePos, setMousePos] = useState({ x: 0, y: 0 });

  useEffect(() => {
    const handleMouseMove = (e: MouseEvent) => {
      setMousePos({ x: e.clientX, y: e.clientY });
    };
    window.addEventListener("mousemove", handleMouseMove);
    return () => window.removeEventListener("mousemove", handleMouseMove);
  }, []);

  const dashboardQuery = useQuery<StudioDashboardData>({
    queryKey: ["studio-dashboard", token],
    enabled: hydrated && !!token,
    queryFn: async () => {
      const [meRes, s, p, gf, tpls] = await Promise.all([
        apiFetch<any>("/auth/profile", { method: "GET", token: token! }).catch(() => null),
        apiFetch<any>("/users/me/stats", { method: "GET", token: token! }).catch(() => null),
        apiFetch<any>("/projects", { method: "GET", token: token! }).catch(() => null),
        apiFetch<any>("/game-feed?limit=30", { method: "GET", token: token! }).catch(() => null),
        apiFetch<any>("/templates", { method: "GET", token: token! }).catch(() => null),
      ]);

      const meData = (meRes && typeof meRes === "object" && "data" in meRes) ? (meRes as any).data : meRes;
      const me = meData ? ((meData?.user ?? meData) as Me) : null;

      const statsData = (s && typeof s === "object" && "data" in s) ? (s as any).data : s;
      const stats = statsData ? ((statsData?.data ?? statsData) as StatsResponse) : null;

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
      const recent = list.slice(0, 6);

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
      const trendingGames = posts.slice(0, 3).map((p, idx) => {
        const id = String((p as any)?.id || (p as any)?._id || `post_${idx}`);
        const title = String((p as any)?.title || (p as any)?.name || "Game");
        const plays = asInt((p as any)?.playCount);
        const views = asInt((p as any)?.viewCount);
        const v = views > 0 ? views : plays;
        const rawImg = (p as any)?.previewImageUrl || (p as any)?.previewImage || (p as any)?.thumbnailUrl || "";
        const imageUrl = resolveMediaUrl(rawImg);
        return { id, title, views: v, imageUrl };
      });

      const tData = (tpls && typeof tpls === "object" && "data" in tpls) ? (tpls as any).data : tpls;
      const tItems = Array.isArray((tData as any)?.data) ? (tData as any).data : (Array.isArray(tData) ? tData : []);
      const templates = (Array.isArray(tItems) ? tItems : [])
        .filter(Boolean)
        .map((x: any) => (x && typeof x === "object" ? (x as TemplateRow) : ({} as TemplateRow)));

      templates.sort((a, b) => templateScore(b) - templateScore(a));
      const best = templates[0];
      const bestTemplate = best
        ? {
          id: String((best as any)?.id || (best as any)?._id || "") || String((best as any)?.name || (best as any)?.title || "Template"),
          name: String((best as any)?.name || (best as any)?.title || "Template"),
          downloads: asInt((best as any)?.downloads),
          imageUrl: resolveMediaUrl((best as any)?.previewImageUrl || (best as any)?.previewImage || (best as any)?.thumbnailUrl || ""),
        }
        : null;

      return { me, stats, recent, trendingGames, bestTemplate };
    },
  });

  const me = dashboardQuery.data?.me ?? null;
  const stats = dashboardQuery.data?.stats ?? null;
  const recent = dashboardQuery.data?.recent ?? [];
  const trendingGames = dashboardQuery.data?.trendingGames ?? [];
  const bestTemplate = dashboardQuery.data?.bestTemplate ?? null;
  const loading = !hydrated || dashboardQuery.isLoading;
  const error = dashboardQuery.error instanceof ApiError
    ? dashboardQuery.error.message
    : dashboardQuery.error instanceof Error
      ? dashboardQuery.error.message
      : null;

  return (
    <UserShell
      title="Dashboard"
      subtitle="OVERVIEW"
      right={
        <div className="flex items-center gap-3">
          <button
            onClick={() => router.push("/studio/notifications")}
            className="group relative flex h-10 w-10 items-center justify-center rounded-xl border border-white/[0.07] bg-white/[0.03] text-[var(--gf-text-muted)] hover:text-[var(--foreground)] hover:bg-white/[0.08] transition-all overflow-hidden"
          >
            <Bell size={18} className="relative z-10 transition-transform group-hover:rotate-12" />
            <span className="absolute top-2 right-2 h-1.5 w-1.5 rounded-full bg-blue-500 shadow-[0_0_6px_rgba(37,99,235,0.9)] animate-pulse" />
          </button>
          <button
            onClick={() => router.push("/studio/settings")}
            className="group relative flex h-10 w-10 items-center justify-center rounded-xl border border-white/[0.07] bg-white/[0.03] hover:bg-white/[0.08] transition-all overflow-hidden"
          >
            {(me as any)?.avatar ? (
              <img src={resolveMediaUrl((me as any).avatar)} alt="Profile" className="h-full w-full object-cover" />
            ) : (
              <div className="h-full w-full flex items-center justify-center text-zinc-500 group-hover:text-zinc-300 transition-colors">
                <Users size={16} />
              </div>
            )}
          </button>
        </div>
      }
    >
      {/* ── Global ambient glow ── */}
      <div className="fixed inset-0 pointer-events-none z-0 overflow-hidden">
        <motion.div
          animate={{ scale: [1, 1.15, 1], x: [0, 40, 0], y: [0, 30, 0] }}
          transition={{ duration: 25, repeat: Infinity, ease: "easeInOut" }}
          className="absolute -top-[10%] -right-[5%] w-[50%] h-[50%] rounded-full bg-blue-600/5 blur-[120px]"
        />
        <motion.div
          animate={{ scale: [1.1, 1, 1.1], x: [0, -30, 0], y: [0, -20, 0] }}
          transition={{ duration: 30, repeat: Infinity, ease: "easeInOut", delay: 1 }}
          className="absolute -bottom-[5%] -left-[5%] w-[45%] h-[45%] rounded-full bg-blue-600/4 blur-[130px]"
        />
        <div
          className="absolute inset-0 opacity-[0.08]"
          style={{ background: `radial-gradient(circle at ${mousePos.x}px ${mousePos.y}px, rgba(37,99,235,0.12) 0%, transparent 35%)` }}
        />
      </div>

      {error && (
        <div className="mb-6 relative z-10 rounded-2xl border border-red-500/20 bg-red-500/10 px-4 py-3 text-sm text-red-200">{error}</div>
      )}

      <div className="relative z-10 space-y-14 pt-6">

        {/* 1 ── HERO GREETING */}
        <motion.section initial={{ opacity: 0, y: -16 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.6 }}>
          <GreetingCard username={me?.username} />
        </motion.section>

        {/* 2 ── QUICK ACTIONS */}
        <motion.section initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.5, delay: 0.1 }}>
          <SectionLabel icon={Rocket} text="Quick Actions" />
          <div className="mt-5 grid grid-cols-1 gap-4 lg:grid-cols-3">

            {/* Primary CTA — Build a Game */}
            <button
              onClick={() => router.push("/studio/projects/new")}
              className="group relative overflow-hidden rounded-[28px] border border-blue-500/20 bg-blue-600/8 p-7 text-left transition-all hover:bg-blue-600/14 hover:border-blue-500/35 hover:scale-[1.015] active:scale-[0.985] lg:col-span-2"
            >
              <div className="absolute inset-0 bg-gradient-to-br from-blue-600/10 via-transparent to-sky-500/5 pointer-events-none" />
              <div className="absolute -top-24 -right-24 h-64 w-64 rounded-full bg-blue-600/10 blur-[80px] opacity-0 group-hover:opacity-100 transition-opacity duration-700" />
              <motion.div
                animate={{ x: ["-100%", "200%"] }}
                transition={{ duration: 3, repeat: Infinity, ease: "linear", repeatDelay: 5 }}
                className="absolute inset-0 w-1/3 bg-gradient-to-r from-transparent via-white/[0.05] to-transparent pointer-events-none"
              />
              <div className="relative z-10 flex items-center justify-between">
                <div className="flex items-center gap-5">
                  <div className="h-14 w-14 rounded-2xl bg-blue-600/20 border border-blue-500/30 flex items-center justify-center shadow-[0_0_24px_rgba(37,99,235,0.2)] group-hover:scale-110 transition-transform duration-300">
                    <Rocket size={24} className="text-blue-300" />
                  </div>
                  <div>
                    <div className="text-lg font-black text-[var(--foreground)] tracking-tight">Build a New Game</div>
                    <div className="text-xs text-zinc-500 font-medium mt-0.5">Describe it — we ship it to all platforms in minutes</div>
                  </div>
                </div>
                <div className="h-9 w-9 rounded-xl bg-blue-600/20 border border-blue-500/25 flex items-center justify-center text-blue-300 group-hover:translate-x-1 transition-transform shrink-0">
                  <ChevronRight size={18} />
                </div>
              </div>
            </button>

            {/* Secondary CTA — Marketplace */}
            <button
              onClick={() => router.push("/studio/marketplace")}
              className="group relative overflow-hidden rounded-[28px] border border-white/[0.08] bg-white/[0.02] p-7 text-left transition-all hover:bg-white/[0.05] hover:border-white/[0.14] hover:scale-[1.015] active:scale-[0.985]"
            >
              <div className="absolute inset-0 bg-gradient-to-br from-blue-500/5 via-transparent to-transparent pointer-events-none" />
              <div className="relative z-10">
                <div className="h-12 w-12 rounded-2xl bg-blue-500/12 border border-blue-500/18 flex items-center justify-center mb-6 group-hover:scale-110 transition-transform duration-300">
                  <Layers size={22} className="text-blue-400" />
                </div>
                <div className="text-base font-black text-[var(--foreground)] tracking-tight">Browse Templates</div>
                <div className="text-xs text-zinc-600 font-medium mt-1">Start with a proven foundation</div>
              </div>
            </button>
          </div>
        </motion.section>

        {/* 3 ── STATS GRID */}
        <motion.section initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.5, delay: 0.15 }}>
          <SectionLabel icon={Activity} text="Performance" />
          <div className="mt-5">
            <PremiumStatsGrid stats={stats} loading={loading} />
          </div>
        </motion.section>

        {/* 4 ── AI COACH TIP */}
        <motion.section initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.5, delay: 0.2 }}>
          <AICoachTip />
        </motion.section>

        {/* 5 ── RECENT PROJECTS + SYSTEM HEALTH */}
        <motion.section initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.5, delay: 0.25 }}>
          <div className="grid grid-cols-1 gap-8 lg:grid-cols-3">

            {/* Recent Projects — 2 cols */}
            <div className="lg:col-span-2">
              <div className="flex items-center justify-between mb-5">
                <SectionLabel icon={Gamepad2} text="Recent Projects" />
                <button
                  onClick={() => router.push("/studio/projects")}
                  className="text-[10px] font-black uppercase tracking-widest text-zinc-600 hover:text-blue-400 transition-colors flex items-center gap-1"
                >
                  View all <ChevronRight size={12} />
                </button>
              </div>

              {recent.length === 0 ? (
                <div className="relative overflow-hidden rounded-[24px] border border-white/[0.06] bg-[var(--gf-panel-bg-strong)] p-10 text-center">
                  <div className="absolute inset-0 bg-[radial-gradient(ellipse_at_center,rgba(37,99,235,0.05),transparent_70%)] pointer-events-none" />
                  <div className="relative z-10">
                    <div className="h-12 w-12 rounded-2xl bg-white/[0.04] border border-white/[0.07] flex items-center justify-center mx-auto mb-4">
                      <Gamepad2 size={22} className="text-zinc-600" />
                    </div>
                    <div className="text-sm font-bold text-[var(--foreground)] mb-1">No projects yet</div>
                    <div className="text-xs text-zinc-600 mb-6">Your first game is waiting to be built.</div>
                    <button
                      onClick={() => router.push("/studio/projects/new")}
                      className="px-6 py-3 rounded-2xl bg-blue-600 text-white text-[10px] font-black uppercase tracking-widest hover:bg-blue-500 transition-all"
                    >
                      Create your first project
                    </button>
                  </div>
                </div>
              ) : (
                <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
                  {recent.map((p, idx) => (
                    <RecentProjectCard key={p._id || p.id || idx} p={p} idx={idx} router={router} />
                  ))}
                </div>
              )}
            </div>

            {/* System Health — 1 col */}
            <div>
              <SectionLabel icon={Activity} text="System Health" />
              <div className="mt-5 rounded-[28px] border border-white/[0.07] bg-[var(--gf-panel-bg-strong)] p-7 space-y-7">
                {/* Ambient glow */}
                <div className="absolute inset-0 bg-gradient-to-br from-blue-600/3 via-transparent to-transparent rounded-[28px] pointer-events-none" />

                {[
                  { label: "Build Pipeline", value: "98.2%", bar: "98.2", color: "from-blue-500 to-sky-400", glow: "rgba(59,130,246,0.35)", status: "Stable", statusColor: "text-blue-400" },
                  { label: "AI Engine", value: "99.8%", bar: "99.8", color: "from-blue-600 to-sky-400", glow: "rgba(37,99,235,0.35)", status: "Online", statusColor: "text-blue-400" },
                  { label: "Credit Usage", value: "40%", bar: "40", color: "from-amber-500 to-orange-400", glow: "rgba(245,158,11,0.35)", status: "420 GC", statusColor: "text-amber-400" },
                ].map((item, i) => (
                  <div key={item.label} className="space-y-2.5">
                    <div className="flex items-center justify-between">
                      <span className="text-[10px] font-black text-zinc-500 uppercase tracking-[0.28em]">{item.label}</span>
                      <span className={`text-[11px] font-black ${item.statusColor}`}>{item.status}</span>
                    </div>
                    <div className="h-1 w-full bg-white/[0.05] rounded-full overflow-hidden">
                      <motion.div
                        initial={{ width: 0 }}
                        animate={{ width: `${item.bar}%` }}
                        transition={{ duration: 1.2, ease: "easeOut", delay: i * 0.15 }}
                        className={`h-full bg-gradient-to-r ${item.color} rounded-full`}
                        style={{ boxShadow: `0 0 8px ${item.glow}` }}
                      />
                    </div>
                  </div>
                ))}

                <button
                  onClick={() => router.push("/studio/wallet")}
                  className="w-full mt-2 rounded-xl border border-white/[0.06] bg-white/[0.02] py-3 text-[10px] font-black uppercase tracking-widest text-zinc-600 hover:text-[var(--foreground)] hover:bg-white/[0.05] hover:border-white/[0.10] transition-all"
                >
                  View Wallet
                </button>
              </div>
            </div>
          </div>
        </motion.section>

        {/* 6 ── TRENDING + BEST TEMPLATE */}
        <motion.section initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.5, delay: 0.3 }}>
          <div className="grid grid-cols-1 gap-12">
            <TrendingArcade games={trendingGames} />
            <BestPickTemplate template={bestTemplate} />
          </div>
        </motion.section>

        {/* 7 ── CREATOR MILESTONES */}
        <motion.section initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.5, delay: 0.35 }}>
          <SectionLabel icon={Trophy} text="Creator Milestones" />
          <div className="mt-5">
            <AchievementSystem />
          </div>
        </motion.section>

        {/* 8 ── MISSION ARCHITECTURE */}
        <motion.section initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.5, delay: 0.4 }}>
          <SectionLabel icon={Lightbulb} text="Mission Architecture" />
          <div className="mt-5">
            <AIStoryboard />
          </div>
        </motion.section>

        {/* 9 ── LIVE FEED */}
        <motion.section initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.5, delay: 0.45 }}>
          <div className="flex items-center justify-between mb-5">
            <SectionLabel icon={Activity} text="Live Feed" />
            <div className="flex items-center gap-1.5 px-2.5 py-1 rounded-lg bg-blue-500/10 border border-blue-500/20">
              <span className="h-1.5 w-1.5 rounded-full bg-blue-400 animate-pulse shadow-[0_0_8px_rgba(59,130,246,0.8)]" />
              <span className="text-[9px] font-black uppercase tracking-widest text-blue-400">Streaming</span>
            </div>
          </div>
          <GlobalActivityFeed />
        </motion.section>

      </div>
    </UserShell>
  );
}
