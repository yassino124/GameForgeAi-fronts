"use client";

import {
  motion,
  useScroll,
  useTransform,
  AnimatePresence,
} from "framer-motion";
import { useRef, useState, useEffect, useCallback } from "react";
import {
  Rocket,
  ArrowRight,
  ChevronRight,
  Play,
  Gamepad2,
  Globe,
  Smartphone,
  Monitor,
  Zap,
  Shield,
  Users,
  Star,
  Clock,
  TrendingUp,
  Check,
  ArrowUpRight,
  Layers,
  Code2,
  Paintbrush,
  Music2,
  Cpu,
} from "lucide-react";
import { apiFetch } from "@/lib/api";
import { resolveMediaUrl } from "@/lib/media";
import { useQuery } from "@tanstack/react-query";
import ForgeLogo from "@/app/_components/ForgeLogo";
import { getUserToken } from "@/lib/userAuth";

// ─────────────────────────────────────────────────────────────
//  TYPES
// ─────────────────────────────────────────────────────────────
type Game = {
  id: string;
  title: string;
  genre: string;
  plays: string;
  img: string;
  author: string;
};

// ─────────────────────────────────────────────────────────────
//  CONSTANTS
// ─────────────────────────────────────────────────────────────
const FEATURED_GAMES: Game[] = [
  {
    id: "g1",
    title: "Neon Strike",
    genre: "Action",
    plays: "24k",
    author: "ByteWolf",
    img: "https://images.unsplash.com/photo-1542751371-adc38448a05e?auto=format&fit=crop&q=80&w=600",
  },
  {
    id: "g2",
    title: "Void Runner",
    genre: "Arcade",
    plays: "18k",
    author: "NullSpace",
    img: "https://images.unsplash.com/photo-1614850523296-d8c1af93d400?auto=format&fit=crop&q=80&w=600",
  },
  {
    id: "g3",
    title: "Cyber Trade",
    genre: "RPG",
    plays: "31k",
    author: "PXL_Dev",
    img: "https://images.unsplash.com/photo-1550745165-9bc0b252726f?auto=format&fit=crop&q=80&w=600",
  },
  {
    id: "g4",
    title: "Solar Rush",
    genre: "Racing",
    plays: "12k",
    author: "ArcadeKit",
    img: "https://images.unsplash.com/photo-1451187580459-43490279c0fa?auto=format&fit=crop&q=80&w=600",
  },
  {
    id: "g5",
    title: "Forest Hunt",
    genre: "Adventure",
    plays: "9k",
    author: "WildCode",
    img: "https://images.unsplash.com/photo-1534423861386-85a16f5d13fd?auto=format&fit=crop&q=80&w=600",
  },
  {
    id: "g6",
    title: "Iron Grid",
    genre: "Strategy",
    plays: "7k",
    author: "GridMaker",
    img: "https://images.unsplash.com/photo-1558591710-4b4a1ae0f04d?auto=format&fit=crop&q=80&w=600",
  },
];

const PLATFORMS = [
  { label: "WebGL", icon: Globe, desc: "Instant play", color: "#2563eb" },
  { label: "Android", icon: Smartphone, desc: "APK export", color: "#10b981" },
  { label: "iOS", icon: Smartphone, desc: "App Store ready", color: "#f59e0b" },
  { label: "Windows", icon: Monitor, desc: "Desktop build", color: "#0ea5e9" },
  { label: "macOS", icon: Monitor, desc: "Native feel", color: "#8b5cf6" },
];

const WORKFLOW = [
  {
    n: "01",
    title: "Describe",
    icon: Code2,
    desc: "Write your idea in plain English. Our engine understands mechanics, genre, and style in a single sentence.",
    color: "#2563eb",
  },
  {
    n: "02",
    title: "Configure",
    icon: Paintbrush,
    desc: "Fine-tune colors, physics, difficulty, and assets. Every parameter is visual and immediate.",
    color: "#0ea5e9",
  },
  {
    n: "03",
    title: "Ship",
    icon: Rocket,
    desc: "Build and publish in seconds. Your game runs instantly on every platform with zero runtime errors.",
    color: "#f59e0b",
  },
];

const STATS = [
  { label: "Games Published", value: "48,000+", note: "and counting" },
  { label: "Active Creators", value: "14,200", note: "this month" },
  { label: "Avg Build Time", value: "< 3 min", note: "from prompt to play" },
  { label: "Platforms", value: "5", note: "export targets" },
];

const TESTIMONIALS = [
  {
    name: "Marcus O.",
    role: "Indie developer",
    quote:
      "I shipped my first game in 2 days. The prompt-to-code pipeline is unlike anything I've used.",
    stars: 5,
  },
  {
    name: "Layla R.",
    role: "Studio founder",
    quote:
      "We prototype 10× faster now. The WebGL export is rock-solid for browser-first games.",
    stars: 5,
  },
  {
    name: "Tom V.",
    role: "Game jam winner",
    quote:
      "Won a 48h jam with a game I built here. The team couldn't believe it was real.",
    stars: 5,
  },
];

// ─────────────────────────────────────────────────────────────
//  COMPONENTS
// ─────────────────────────────────────────────────────────────

function Navbar({ onWatchDemo }: { onWatchDemo: () => void }) {
  const [scrolled, setScrolled] = useState(false);
  useEffect(() => {
    const fn = () => setScrolled(window.scrollY > 32);
    window.addEventListener("scroll", fn, { passive: true });
    return () => window.removeEventListener("scroll", fn);
  }, []);

  return (
    <header className={`fixed top-0 left-0 right-0 z-50 transition-all duration-500 ${scrolled ? "bg-[#07080f]/80 backdrop-blur-xl shadow-[0_20px_60px_rgba(0,0,0,0.5)]" : ""}`}>
      <div className="max-w-7xl mx-auto px-6 h-16 flex items-center justify-between">
        <a href="/"><ForgeLogo size={44} /></a>
        <nav className="hidden md:flex items-center gap-1">
          {["Features", "Arcade", "Pricing", "Docs"].map((item) => (
            <a key={item} href={`#${item.toLowerCase()}`}
              className="px-4 py-2 rounded-xl text-sm font-medium text-zinc-400 hover:text-white hover:bg-white/[0.05] transition-all">
              {item}
            </a>
          ))}
        </nav>
        <div className="flex items-center gap-3">
          <a href="/signin" className="text-sm font-semibold text-zinc-400 hover:text-white transition-colors px-3 py-2">Sign in</a>
          <a href="/signup"
            className="relative overflow-hidden flex items-center gap-2 px-5 py-2.5 rounded-[14px] bg-blue-600 text-white text-sm font-bold hover:bg-blue-500 transition-all">
            Get started free
          </a>
        </div>
      </div>
    </header>
  );
}

// Marquee row
function MarqueeRow({
  games,
  direction = 1,
  speed = 35,
}: {
  games: Game[];
  direction?: 1 | -1;
  speed?: number;
}) {
  const doubled = [...games, ...games];
  return (
    <div className="relative overflow-hidden py-4">
      <motion.div
        animate={{
          x:
            direction === 1
              ? [0, -50 * games.length * 8]
              : [-50 * games.length * 8, 0],
        }}
        transition={{
          duration: speed * games.length,
          repeat: Infinity,
          ease: "linear",
        }}
        className="flex gap-6"
        style={{ width: "max-content" }}
      >
        {doubled.map((g, i) => (
          <motion.div
            key={`${g.id}-${i}`}
            whileHover={{
              y: -12,
              scale: 1.05,
              rotateX: 5,
              rotateY: -5,
              transition: { type: "spring", stiffness: 400, damping: 10 },
            }}
            className="group relative w-80 h-48 rounded-[32px] overflow-hidden border border-white/[0.08] dark:border-white/[0.1] shrink-0 cursor-pointer transition-all duration-500 shadow-[0_30px_80px_rgba(0,0,0,0.4)] hover:shadow-blue-500/40 hover:border-blue-400/60"
            style={{ transformStyle: "preserve-3d", perspective: "1000px" }}
          >
            <img
              src={g.img}
              alt={g.title}
              className="absolute inset-0 w-full h-full object-cover group-hover:scale-110 transition-transform duration-1000 ease-out"
            />

            {/* Glossy Overlay */}
            <div className="absolute inset-0 bg-gradient-to-t from-black/95 via-black/30 to-transparent opacity-80 group-hover:opacity-100 transition-opacity" />

            {/* Animated Neon border */}
            <div className="absolute inset-0 opacity-0 group-hover:opacity-100 transition-opacity duration-500">
              <div className="absolute inset-0 border-2 border-blue-400/30 rounded-[32px] animate-pulse" />
            </div>

            {/* Glass Badge */}
            <div
              className="absolute top-4 left-5"
              style={{ transform: "translateZ(20px)" }}
            >
              <div className="px-3 py-1.5 rounded-xl bg-black/50 backdrop-blur-md border border-white/10 text-[10px] font-black text-blue-400 uppercase tracking-widest shadow-2xl">
                {g.genre}
              </div>
            </div>

            <div
              className="absolute bottom-6 left-6 right-6"
              style={{ transform: "translateZ(40px)" }}
            >
              <div className="flex items-center gap-2 mb-2">
                <div className="flex items-center gap-1.5 px-2 py-1 rounded-lg bg-blue-500 text-white shadow-[0_0_15px_rgba(59,130,246,0.6)]">
                  <Play size={10} className="fill-white" />
                  <span className="text-[10px] font-black uppercase tracking-tighter">
                    {g.plays} PLAYS
                  </span>
                </div>
              </div>
              <div className="text-lg font-black text-white tracking-tight drop-shadow-[0_2px_10px_rgba(0,0,0,0.8)]">
                {g.title}
              </div>
              <div className="text-[11px] font-bold text-zinc-400 uppercase tracking-widest mt-1 opacity-0 group-hover:opacity-100 transition-all duration-500 transform translate-y-2 group-hover:translate-y-0">
                Built by {g.author}
              </div>
            </div>

            {/* Moving Shine Effect */}
            <motion.div
              initial={{ x: "-100%", y: "-100%" }}
              whileHover={{ x: "100%", y: "100%" }}
              transition={{ duration: 1, ease: "easeInOut" }}
              className="absolute inset-0 bg-gradient-to-br from-white/20 via-transparent to-transparent pointer-events-none"
            />
          </motion.div>
        ))}
      </motion.div>
    </div>
  );
}

// Platform pill
function PlatformPill({ label, icon: Icon, desc, color, delay }: any) {
  return (
    <motion.div
      initial={{ opacity: 0, y: 16 }}
      whileInView={{ opacity: 1, y: 0 }}
      viewport={{ once: true }}
      transition={{ delay, duration: 0.4 }}
      whileHover={{ y: -4, scale: 1.03 }}
      className="flex flex-col items-center gap-3 p-5 rounded-[20px] bg-white/[0.04] border border-white/[0.09] hover:bg-white/[0.05] hover:border-white/[0.12] transition-all cursor-default group"
    >
      <div
        className="h-12 w-12 rounded-2xl flex items-center justify-center group-hover:scale-110 transition-transform"
        style={{
          backgroundColor: `${color}20`,
          border: `1px solid ${color}30`,
        }}
      >
        <Icon size={22} style={{ color }} />
      </div>
      <div className="text-sm font-bold text-white">{label}</div>
      <div className="text-[11px] text-zinc-600">{desc}</div>
    </motion.div>
  );
}

// Feature card
function FeatureCard({ icon: Icon, title, desc, color, delay }: any) {
  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      whileInView={{ opacity: 1, y: 0 }}
      viewport={{ once: true }}
      transition={{ delay, duration: 0.4 }}
      className="group p-6 rounded-[24px] bg-white/[0.04] border border-white/[0.09] hover:bg-white/[0.07] hover:border-white/[0.16] transition-all"
    >
      <div
        className="h-10 w-10 rounded-[14px] flex items-center justify-center mb-4 transition-transform group-hover:scale-110"
        style={{
          backgroundColor: `${color}20`,
          border: `1px solid ${color}25`,
        }}
      >
        <Icon size={18} style={{ color }} />
      </div>
      <h3 className="text-[15px] font-bold text-white mb-2">{title}</h3>
      <p className="text-[13px] text-zinc-500 leading-relaxed">{desc}</p>
    </motion.div>
  );
}

// ─────────────────────────────────────────────────────────────
//  MAIN PAGE
// ─────────────────────────────────────────────────────────────
export default function LandingPage() {
  const [trailerOpen, setTrailerOpen] = useState(false);
  const [prompt, setPrompt] = useState("");
  const [mousePos, setMousePos] = useState({ x: 0, y: 0 });
  const heroRef = useRef<HTMLDivElement>(null);
  const { scrollY } = useScroll();
  const heroOpacity = useTransform(scrollY, [0, 400], [1, 0]);
  const heroY = useTransform(scrollY, [0, 400], [0, -80]);

  useEffect(() => {
    const handleMouseMove = (e: MouseEvent) => {
      setMousePos({ x: e.clientX, y: e.clientY });
    };
    window.addEventListener("mousemove", handleMouseMove);
    return () => window.removeEventListener("mousemove", handleMouseMove);
  }, []);

  const { data: realTemplates = [] } = useQuery({
    queryKey: ["landing-templates"],
    queryFn: async () => {
      try {
        const res = await apiFetch<any>("/templates", { method: "GET" });
        const items = Array.isArray(res?.data)
          ? res.data
          : Array.isArray(res)
            ? res
            : [];
        return items.map((t: any) => ({
          id: t.id || t._id,
          title: t.name || "Untitled Game",
          genre: t.category || "Unity",
          plays: String(t.downloads || "0"),
          author: "GameForge",
          img:
            resolveMediaUrl(t.previewImageUrl || t.previewImage || "") ||
            "https://images.unsplash.com/photo-1614850523296-d8c1af93d400?auto=format&fit=crop&q=80&w=600",
        }));
      } catch (e) {
        console.error("Failed to load landing templates", e);
        return [];
      }
    },
  });

  const displayGames =
    realTemplates.length > 0 ? realTemplates : FEATURED_GAMES;

  const handleGenerate = useCallback(() => {
    const dest = prompt.trim()
      ? `/signup?prompt=${encodeURIComponent(prompt.trim())}`
      : "/signup";
    window.location.href = dest;
  }, [prompt]);

  return (
    <div className="min-h-screen bg-[var(--gf-bg)] text-[var(--foreground)] font-sans selection:bg-blue-600/30 overflow-x-hidden transition-colors duration-500">
      {/* ── Global ambient glow ── */}
      <div className="fixed inset-0 pointer-events-none z-0 overflow-hidden">
        <motion.div
          animate={{
            scale: [1, 1.2, 1.1, 1],
            rotate: [0, 90, 180, 270],
            x: [0, 100, -50, 0],
            y: [0, -50, 100, 0],
          }}
          transition={{ duration: 30, repeat: Infinity, ease: "linear" }}
          className="absolute -top-[20%] -right-[10%] w-[80%] h-[80%] rounded-full bg-blue-600/10 dark:bg-blue-600/20 blur-[160px] opacity-60"
        />
        <motion.div
          animate={{
            scale: [1.1, 1, 1.2, 1.1],
            rotate: [270, 180, 90, 0],
            x: [0, -80, 60, 0],
            y: [0, 100, -40, 0],
          }}
          transition={{
            duration: 35,
            repeat: Infinity,
            ease: "linear",
            delay: 2,
          }}
          className="absolute -bottom-[20%] -left-[10%] w-[70%] h-[70%] rounded-full bg-indigo-600/10 dark:bg-indigo-600/15 blur-[150px] opacity-50"
        />
        <div
          className="absolute inset-0 opacity-[0.15] dark:opacity-[0.2]"
          style={{
            background: `radial-gradient(circle at ${mousePos.x}px ${mousePos.y}px, rgba(37,99,235,0.25) 0%, transparent 40%)`,
          }}
        />
      </div>

      <Navbar onWatchDemo={() => setTrailerOpen(true)} />

      {/* ═══════════════════ HERO ═══════════════════ */}
      <section
        ref={heroRef}
        className="relative min-h-screen flex items-center pt-24 pb-32 overflow-hidden"
      >
        {/* Background layers */}
        <div className="pointer-events-none absolute inset-0">
          {/* Top-center glow */}
          <div className="absolute top-0 left-1/2 -translate-x-1/2 w-[900px] h-[500px] rounded-full bg-blue-600/12 blur-[120px]" />
          {/* Side glows */}
          <div className="absolute bottom-0 right-0 w-[500px] h-[400px] rounded-full bg-sky-500/6 blur-[100px]" />
          <div className="absolute top-1/3 left-0 w-[300px] h-[300px] rounded-full bg-blue-800/8 blur-[80px]" />
          {/* Grid */}
          <div
            className="absolute inset-0 opacity-[0.065]"
            style={{
              backgroundImage:
                "linear-gradient(rgba(255,255,255,0.5) 1px,transparent 1px),linear-gradient(90deg,rgba(255,255,255,0.5) 1px,transparent 1px)",
              backgroundSize: "60px 60px",
            }}
          />
          {/* Floating particles */}
          {[
            { x: "8%", y: "20%", c: "#2563eb", s: 2, d: 5, dl: 0 },
            { x: "15%", y: "65%", c: "#0ea5e9", s: 1, d: 7, dl: 1 },
            { x: "25%", y: "40%", c: "#f59e0b", s: 2, d: 6, dl: 2 },
            { x: "38%", y: "80%", c: "#2563eb", s: 1, d: 8, dl: 0.5 },
            { x: "52%", y: "15%", c: "#60a5fa", s: 2, d: 5, dl: 1.5 },
            { x: "65%", y: "55%", c: "#0ea5e9", s: 1, d: 9, dl: 0.8 },
            { x: "72%", y: "25%", c: "#f59e0b", s: 2, d: 6, dl: 2.5 },
            { x: "85%", y: "70%", c: "#2563eb", s: 1, d: 7, dl: 0.3 },
            { x: "92%", y: "35%", c: "#60a5fa", s: 2, d: 5, dl: 1.2 },
            { x: "43%", y: "50%", c: "#0ea5e9", s: 1, d: 8, dl: 3 },
            { x: "78%", y: "45%", c: "#f59e0b", s: 2, d: 6, dl: 1.7 },
            { x: "30%", y: "10%", c: "#2563eb", s: 1, d: 7, dl: 2.2 },
          ].map((p, i) => (
            <motion.div
              key={i}
              style={{
                left: p.x,
                top: p.y,
                width: p.s,
                height: p.s,
                backgroundColor: p.c,
                position: "absolute",
              }}
              animate={{ y: [0, -16, 0], opacity: [0.15, 0.5, 0.15] }}
              transition={{
                duration: p.d,
                repeat: Infinity,
                ease: "easeInOut",
                delay: p.dl,
              }}
              className="rounded-full"
            />
          ))}
          {/* Fade edges */}
          <div className="absolute inset-0 bg-gradient-to-b from-[#07080f]/0 via-transparent to-[#07080f]" />
          <div className="absolute inset-0 bg-gradient-to-r from-[#07080f] via-transparent to-[#07080f]/50" />
        </div>

        <div className="relative z-10 max-w-7xl mx-auto px-6 w-full">
          <div className="grid lg:grid-cols-2 gap-16 items-center">
            {/* LEFT */}
            <motion.div
              initial={{ opacity: 0, y: 40 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.8, ease: [0.16, 1, 0.3, 1] }}
              className="space-y-8"
            >
              {/* Badge */}
              <div className="inline-flex items-center gap-2.5 px-4 py-2 rounded-full border border-blue-500/25 bg-blue-600/8 text-[11px] font-bold text-blue-300 uppercase tracking-[0.18em]">
                <span className="h-1.5 w-1.5 rounded-full bg-blue-400 animate-pulse shadow-[0_0_6px_rgba(59,130,246,0.9)]" />
                Game Studio · Now in Beta
              </div>

              {/* H1 */}
              <div className="space-y-2">
                <h1 className="text-6xl xl:text-8xl font-black tracking-[-0.04em] leading-[0.85] text-[var(--foreground)]">
                  Build games.
                  <br />
                  <span className="text-transparent bg-clip-text bg-gradient-to-r from-blue-600 via-sky-500 to-indigo-400 dark:from-white dark:via-zinc-200 dark:to-zinc-500 animate-pulse">
                    Ship fast.
                  </span>
                </h1>
                <h2 className="text-3xl xl:text-4xl font-black tracking-[-0.02em] text-transparent bg-clip-text bg-gradient-to-r from-blue-400 to-sky-300 leading-tight pt-1">
                  No code required.
                </h2>
              </div>

              <p className="text-zinc-400 text-lg leading-relaxed max-w-lg font-medium">
                Describe your game in plain English. GameForge builds it,
                packages it, and ships it to every platform — in minutes, not
                months.
              </p>

              <div className="relative group max-w-xl">
                <div className="absolute -inset-1 rounded-[24px] bg-gradient-to-r from-blue-600 to-sky-500 opacity-20 blur-lg group-focus-within:opacity-40 transition-opacity duration-500" />
                <div className="relative flex items-center gap-3 p-2.5 rounded-[24px] border border-zinc-200 dark:border-white/[0.1] bg-[var(--gf-shell-bg)]/80 backdrop-blur-xl focus-within:ring-2 focus-within:ring-blue-500/20 transition-all">
                  <div className="pl-4 text-blue-500">
                    <Zap size={18} />
                  </div>
                  <input
                    value={prompt}
                    onChange={(e) => setPrompt(e.target.value)}
                    onKeyDown={(e) => e.key === "Enter" && handleGenerate()}
                    placeholder="Describe your dream game (e.g. 'A futuristic synthwave racer')..."
                    className="flex-1 bg-transparent py-4 text-base text-[var(--foreground)] placeholder:text-zinc-500 outline-none font-medium"
                  />
                  <motion.button
                    whileHover={{ scale: 1.02, x: 2 }}
                    whileTap={{ scale: 0.98 }}
                    onClick={handleGenerate}
                    className="shrink-0 flex items-center gap-2 px-7 py-4 rounded-[18px] bg-blue-600 text-white text-sm font-black uppercase tracking-widest hover:bg-blue-500 shadow-xl shadow-blue-500/25 transition-all"
                  >
                    Generate <Rocket size={16} />
                  </motion.button>
                </div>
              </div>

              {/* Social proof row */}
              <div className="flex flex-wrap items-center gap-6">
                <div className="flex -space-x-2">
                  {["2563eb", "0ea5e9", "10b981", "f59e0b", "8b5cf6"].map(
                    (c, i) => (
                      <div
                        key={i}
                        className="h-8 w-8 rounded-full border-2 border-[#07080f] flex items-center justify-center text-[10px] font-black text-white"
                        style={{ backgroundColor: `#${c}40`, zIndex: 5 - i }}
                      >
                        {String.fromCharCode(65 + i * 3)}
                      </div>
                    ),
                  )}
                </div>
                <div>
                  <div className="text-sm font-bold text-white">
                    14,200+ creators
                  </div>
                  <div className="flex items-center gap-1 mt-0.5">
                    {[1, 2, 3, 4, 5].map((s) => (
                      <Star
                        key={s}
                        size={10}
                        className="fill-amber-400 text-amber-400"
                      />
                    ))}
                    <span className="text-[11px] text-zinc-600 ml-1">
                      4.9/5 — 2,800 reviews
                    </span>
                  </div>
                </div>

                <button
                  onClick={() => setTrailerOpen(true)}
                  className="flex items-center gap-2.5 text-sm font-semibold text-zinc-400 hover:text-white transition-colors group/play"
                >
                  <div className="h-9 w-9 rounded-full bg-white/[0.06] border border-white/[0.1] flex items-center justify-center group-hover/play:bg-blue-600/20 group-hover/play:border-blue-500/30 transition-all">
                    <Play size={14} className="ml-0.5" />
                  </div>
                  Watch 2-min demo
                </button>
              </div>
            </motion.div>

            {/* RIGHT — app preview */}
            <motion.div
              initial={{ opacity: 0, scale: 0.92, y: 20 }}
              animate={{ opacity: 1, scale: 1, y: 0 }}
              transition={{
                duration: 0.9,
                delay: 0.15,
                ease: [0.16, 1, 0.3, 1],
              }}
              className="relative hidden lg:block"
              style={{ y: heroY, opacity: heroOpacity }}
            >
              {/* Main card */}
              <div className="relative rounded-[32px] overflow-hidden border border-white/[0.08] bg-[#0c0e1a] shadow-[0_40px_120px_rgba(0,0,0,0.7)]">
                {/* Title bar */}
                <div className="flex items-center gap-2 px-5 py-4 border-b border-white/[0.05]">
                  <div className="h-3 w-3 rounded-full bg-red-500/70" />
                  <div className="h-3 w-3 rounded-full bg-amber-500/70" />
                  <div className="h-3 w-3 rounded-full bg-emerald-500/70" />
                  <span className="text-[11px] text-zinc-600 font-mono ml-2">
                    gameforge.studio / project / neon-rush
                  </span>
                </div>

                {/* Game preview */}
                <div className="relative aspect-[4/3] overflow-hidden">
                  <img
                    src="https://images.unsplash.com/photo-1542751371-adc38448a05e?auto=format&fit=crop&q=80&w=900"
                    alt="Game preview"
                    className="w-full h-full object-cover opacity-75"
                  />
                  <div className="absolute inset-0 bg-gradient-to-t from-[#0c0e1a] via-transparent to-transparent" />

                  {/* Live build overlay */}
                  <div className="absolute top-4 left-4 right-4 flex items-center justify-between">
                    <div className="flex items-center gap-2 px-3 py-1.5 rounded-full bg-black/60 backdrop-blur-md border border-white/10">
                      <span className="h-1.5 w-1.5 rounded-full bg-emerald-400 animate-pulse" />
                      <span className="text-[10px] font-bold text-white uppercase tracking-widest">
                        Live Preview
                      </span>
                    </div>
                    <div className="flex items-center gap-2 px-3 py-1.5 rounded-full bg-black/60 backdrop-blur-md border border-white/10">
                      <span className="text-[10px] font-bold text-amber-300">
                        WebGL · 60fps
                      </span>
                    </div>
                  </div>

                  {/* Bottom HUD */}
                  <div className="absolute bottom-4 left-4 right-4">
                    <div className="flex items-center justify-between mb-2">
                      <span className="text-[10px] font-bold text-zinc-400 uppercase tracking-widest">
                        Build progress
                      </span>
                      <span className="text-[10px] font-black text-blue-400">
                        87%
                      </span>
                    </div>
                    <div className="h-1.5 w-full rounded-full bg-white/10 overflow-hidden">
                      <motion.div
                        animate={{ width: ["0%", "87%"] }}
                        transition={{
                          duration: 2.5,
                          ease: [0.16, 1, 0.3, 1],
                          delay: 0.8,
                        }}
                        className="h-full rounded-full bg-gradient-to-r from-blue-600 to-sky-400"
                      />
                    </div>
                  </div>
                </div>

                {/* Stats bar */}
                <div className="grid grid-cols-3 divide-x divide-white/[0.05] border-t border-white/[0.05]">
                  {[
                    { label: "Platforms", val: "5" },
                    { label: "Build time", val: "2m 14s" },
                    { label: "File size", val: "4.2 MB" },
                  ].map((s) => (
                    <div
                      key={s.label}
                      className="flex flex-col items-center py-3"
                    >
                      <span className="text-sm font-black text-white">
                        {s.val}
                      </span>
                      <span className="text-[10px] text-zinc-600">
                        {s.label}
                      </span>
                    </div>
                  ))}
                </div>
              </div>

              {/* Floating badges */}
              <motion.div
                animate={{ y: [0, -8, 0] }}
                transition={{
                  duration: 4,
                  repeat: Infinity,
                  ease: "easeInOut",
                }}
                className="absolute -top-6 -right-6 flex items-center gap-2.5 px-4 py-3 rounded-[16px] bg-[#0f1420] border border-white/[0.08] shadow-xl"
              >
                <div className="h-8 w-8 rounded-[10px] bg-amber-500/15 flex items-center justify-center">
                  <Zap size={16} className="text-amber-400" />
                </div>
                <div>
                  <div className="text-[11px] font-black text-white">
                    Built in 2m 14s
                  </div>
                  <div className="text-[9px] text-zinc-600">
                    WebGL · Android · iOS
                  </div>
                </div>
              </motion.div>

              <motion.div
                animate={{ y: [0, 6, 0] }}
                transition={{
                  duration: 5,
                  repeat: Infinity,
                  ease: "easeInOut",
                  delay: 1,
                }}
                className="absolute -bottom-6 -left-6 flex items-center gap-2.5 px-4 py-3 rounded-[16px] bg-[#0f1420] border border-white/[0.08] shadow-xl"
              >
                <div className="h-8 w-8 rounded-[10px] bg-blue-600/15 flex items-center justify-center">
                  <Users size={16} className="text-blue-400" />
                </div>
                <div>
                  <div className="text-[11px] font-black text-white">
                    4,800 plays today
                  </div>
                  <div className="text-[9px] text-zinc-600">
                    Community arcade
                  </div>
                </div>
              </motion.div>
            </motion.div>
          </div>
        </div>
      </section>

      {/* ═══════════════════ STATS BAND ═══════════════════ */}
      <section className="border-y border-white/[0.05] bg-white/[0.01] py-12">
        <div className="max-w-7xl mx-auto px-6">
          <div className="grid grid-cols-2 md:grid-cols-4 gap-8">
            {STATS.map((s, i) => (
              <motion.div
                key={s.label}
                initial={{ opacity: 0, y: 12 }}
                whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true }}
                transition={{ delay: i * 0.07 }}
                className="text-center md:text-left"
              >
                <div className="text-3xl font-black text-white tracking-tight">
                  {s.value}
                </div>
                <div className="text-[11px] font-bold text-zinc-500 uppercase tracking-widest mt-1">
                  {s.label}
                </div>
                <div className="text-[10px] text-zinc-700 mt-0.5">{s.note}</div>
              </motion.div>
            ))}
          </div>
        </div>
      </section>

      {/* ═══════════════════ GAME SHOWCASE ═══════════════════ */}
      <section id="arcade" className="py-24 overflow-hidden">
        <div className="max-w-7xl mx-auto px-6 mb-12">
          <div className="flex items-end justify-between flex-wrap gap-4">
            <div>
              <div className="text-[10px] font-black text-blue-400 uppercase tracking-[0.3em] mb-3">
                Community Arcade
              </div>
              <h2 className="text-4xl font-black tracking-tight">
                Real games. Real creators.
              </h2>
              <p className="text-zinc-500 mt-2 font-medium">
                Everything in the Arcade was built with GameForge — no
                exceptions.
              </p>
            </div>
            <a
              href="/studio/arcade"
              className="flex items-center gap-2 text-sm font-bold text-blue-400 hover:text-blue-300 transition-colors group"
            >
              Browse Arcade{" "}
              <ArrowUpRight
                size={15}
                className="group-hover:translate-x-0.5 group-hover:-translate-y-0.5 transition-transform"
              />
            </a>
          </div>
        </div>
        <div className="space-y-4">
          <MarqueeRow
            games={displayGames.slice(0, FEATURED_GAMES.length)}
            direction={1}
            speed={28}
          />
          <MarqueeRow
            games={[...displayGames].reverse().slice(0, FEATURED_GAMES.length)}
            direction={-1}
            speed={32}
          />
        </div>
      </section>

      {/* ═══════════════════ HOW IT WORKS ═══════════════════ */}
      <section className="py-28 relative">
        <div className="absolute inset-0 pointer-events-none">
          <div className="absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2 w-[700px] h-[500px] rounded-full bg-blue-600/[0.05] blur-[100px]" />
        </div>
        <div className="max-w-7xl mx-auto px-6 relative z-10">
          <div className="text-center mb-20">
            <div className="text-[10px] font-black text-blue-400 uppercase tracking-[0.3em] mb-3">
              The Workflow
            </div>
            <h2 className="text-4xl md:text-5xl font-black tracking-tight">
              From idea to shipped.
              <br />
              <span className="text-zinc-500 font-medium text-2xl md:text-3xl">
                In three steps.
              </span>
            </h2>
          </div>

          <div className="grid md:grid-cols-3 gap-8">
            {WORKFLOW.map((step, i) => (
              <motion.div
                key={step.n}
                initial={{ opacity: 0, y: 24 }}
                whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true }}
                transition={{ delay: i * 0.12, duration: 0.5 }}
                className="relative group"
              >
                {/* Connector line */}
                {i < 2 && (
                  <div
                    className="hidden md:block absolute top-10 left-full w-full h-px z-0"
                    style={{
                      background: `linear-gradient(to right, ${step.color}40, transparent)`,
                    }}
                  />
                )}
                <div className="relative z-10 p-8 rounded-[28px] bg-white/[0.04] border border-white/[0.09] hover:bg-white/[0.04] hover:border-white/10 transition-all h-full">
                  <div className="flex items-start justify-between mb-6">
                    <div
                      className="h-12 w-12 rounded-[16px] flex items-center justify-center"
                      style={{
                        backgroundColor: `${step.color}18`,
                        border: `1px solid ${step.color}30`,
                      }}
                    >
                      <step.icon size={22} style={{ color: step.color }} />
                    </div>
                    <span
                      className="text-[64px] font-black leading-none select-none"
                      style={{ color: `${step.color}08` }}
                    >
                      {step.n}
                    </span>
                  </div>
                  <h3 className="text-xl font-black text-white mb-3">
                    {step.title}
                  </h3>
                  <p className="text-[13px] text-zinc-500 leading-relaxed">
                    {step.desc}
                  </p>
                </div>
              </motion.div>
            ))}
          </div>
        </div>
      </section>

      {/* ═══════════════════ FEATURES GRID ═══════════════════ */}
      <section id="features" className="py-28 border-t border-white/[0.05]">
        <div className="max-w-7xl mx-auto px-6">
          <div className="text-center mb-16">
            <div className="text-[10px] font-black text-blue-400 uppercase tracking-[0.3em] mb-3">
              Built for creators
            </div>
            <h2 className="text-4xl md:text-5xl font-black tracking-tight">
              Everything you need.
              <br />
              Nothing you don't.
            </h2>
          </div>
          <div className="grid sm:grid-cols-2 lg:grid-cols-3 gap-4">
            <FeatureCard
              icon={Zap}
              title="AI Game Generator"
              desc="Go from prompt to playable WebGL build. The engine handles logic, physics, and assets automatically."
              color="#2563eb"
              delay={0}
            />
            <FeatureCard
              icon={Layers}
              title="Smart Templates"
              desc="300+ genre-specific blueprints. Pick a starting point, then customize every detail with natural language."
              color="#0ea5e9"
              delay={0.06}
            />
            <FeatureCard
              icon={Globe}
              title="Multi-Platform Export"
              desc="One project, five platforms. WebGL, Android APK, iOS IPA, Windows exe, macOS app — all from one click."
              color="#10b981"
              delay={0.12}
            />
            <FeatureCard
              icon={Paintbrush}
              title="Visual Configurator"
              desc="Drag sliders for physics, gravity, and difficulty. See changes instantly in the live WebGL preview."
              color="#f59e0b"
              delay={0.18}
            />
            <FeatureCard
              icon={Users}
              title="Community Arcade"
              desc="Publish directly to the GameForge Arcade. Get plays, likes, and feedback from 14,000+ active users."
              color="#8b5cf6"
              delay={0.24}
            />
            <FeatureCard
              icon={Shield}
              title="Always Stable"
              desc="Every build is validated before export. Zero runtime errors, optimized bundles, and automatic fallbacks."
              color="#ec4899"
              delay={0.3}
            />
          </div>
        </div>
      </section>

      {/* ═══════════════════ PLATFORMS ═══════════════════ */}
      <section className="py-24 border-t border-white/[0.05]">
        <div className="max-w-7xl mx-auto px-6">
          <div className="text-center mb-14">
            <div className="text-[10px] font-black text-blue-400 uppercase tracking-[0.3em] mb-3">
              Build Once
            </div>
            <h2 className="text-3xl md:text-4xl font-black tracking-tight">
              Ship to every platform.
            </h2>
          </div>
          <div className="grid grid-cols-2 md:grid-cols-5 gap-4">
            {PLATFORMS.map((p, i) => (
              <PlatformPill key={p.label} {...p} delay={i * 0.07} />
            ))}
          </div>
        </div>
      </section>

      {/* ═══════════════════ TESTIMONIALS ═══════════════════ */}
      <section className="py-24 border-t border-white/[0.05]">
        <div className="max-w-7xl mx-auto px-6">
          <div className="text-center mb-14">
            <div className="text-[10px] font-black text-blue-400 uppercase tracking-[0.3em] mb-3">
              Creators love it
            </div>
            <h2 className="text-3xl md:text-4xl font-black tracking-tight">
              Don't take our word for it.
            </h2>
          </div>
          <div className="grid md:grid-cols-3 gap-6">
            {TESTIMONIALS.map((t, i) => (
              <motion.div
                key={t.name}
                initial={{ opacity: 0, y: 20 }}
                whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true }}
                transition={{ delay: i * 0.1 }}
                className="p-7 rounded-[24px] bg-white/[0.04] border border-white/[0.09]"
              >
                <div className="flex gap-1 mb-5">
                  {Array.from({ length: t.stars }).map((_, s) => (
                    <Star
                      key={s}
                      size={12}
                      className="fill-amber-400 text-amber-400"
                    />
                  ))}
                </div>
                <p className="text-[14px] text-zinc-300 leading-relaxed mb-5">
                  "{t.quote}"
                </p>
                <div>
                  <div className="text-sm font-bold text-white">{t.name}</div>
                  <div className="text-[11px] text-zinc-600 mt-0.5">
                    {t.role}
                  </div>
                </div>
              </motion.div>
            ))}
          </div>
        </div>
      </section>

      {/* ═══════════════════ PRICING ═══════════════════ */}
      <section id="pricing" className="py-28 border-t border-white/[0.05]">
        <div className="max-w-7xl mx-auto px-6">
          <div className="text-center mb-16">
            <div className="text-[10px] font-black text-blue-400 uppercase tracking-[0.3em] mb-3">
              Pricing
            </div>
            <h2 className="text-4xl md:text-5xl font-black tracking-tight">
              Start free.
              <br />
              Scale when you ship.
            </h2>
          </div>

          <div className="grid lg:grid-cols-3 gap-6 max-w-5xl mx-auto">
            {[
              {
                name: "Starter",
                price: "$0",
                note: "Forever free",
                features: [
                  "3 projects",
                  "10 AI builds/month",
                  "WebGL export",
                  "Community Arcade",
                ],
                cta: "Start building",
                featured: false,
              },
              {
                name: "Creator",
                price: "$19",
                note: "per month",
                features: [
                  "Unlimited projects",
                  "100 AI builds/month",
                  "All 5 platforms",
                  "Priority builds",
                  "Analytics dashboard",
                ],
                cta: "Get Creator",
                featured: true,
              },
              {
                name: "Studio",
                price: "$49",
                note: "per month",
                features: [
                  "Everything in Creator",
                  "Team workspace",
                  "Custom branding",
                  "API access",
                  "Dedicated support",
                ],
                cta: "Contact sales",
                featured: false,
              },
            ].map((plan, i) => (
              <motion.div
                key={plan.name}
                initial={{ opacity: 0, y: 20 }}
                whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true }}
                transition={{ delay: i * 0.1 }}
                className={`relative rounded-[28px] p-8 border ${
                  plan.featured
                    ? "bg-blue-600/[0.08] border-blue-500/30 shadow-[0_0_60px_rgba(37,99,235,0.12)]"
                    : "bg-white/[0.02] border-white/[0.07]"
                }`}
              >
                {plan.featured && (
                  <div className="absolute -top-3 left-1/2 -translate-x-1/2 px-4 py-1 rounded-full bg-blue-600 text-white text-[10px] font-black uppercase tracking-widest shadow-lg">
                    Most popular
                  </div>
                )}
                <div className="mb-6">
                  <div className="text-[11px] font-black text-zinc-500 uppercase tracking-widest mb-2">
                    {plan.name}
                  </div>
                  <div className="text-4xl font-black text-white tracking-tight">
                    {plan.price}
                    <span className="text-sm text-zinc-600 font-medium ml-1">
                      {plan.note}
                    </span>
                  </div>
                </div>
                <ul className="space-y-3 mb-8">
                  {plan.features.map((f) => (
                    <li
                      key={f}
                      className="flex items-center gap-3 text-[13px] text-zinc-400"
                    >
                      <Check
                        size={14}
                        className={
                          plan.featured ? "text-blue-400" : "text-zinc-600"
                        }
                      />
                      {f}
                    </li>
                  ))}
                </ul>
                <a
                  href="/signup"
                  className={`block text-center py-3.5 rounded-[16px] text-sm font-bold transition-all ${
                    plan.featured
                      ? "bg-blue-600 text-white hover:bg-blue-500"
                      : "bg-white/[0.05] text-white border border-white/[0.08] hover:bg-white/[0.09]"
                  }`}
                >
                  {plan.cta}
                </a>
              </motion.div>
            ))}
          </div>
        </div>
      </section>

      {/* ═══════════════════ CTA BANNER ═══════════════════ */}
      <section className="py-24 border-t border-white/[0.05]">
        <div className="max-w-4xl mx-auto px-6 text-center">
          <motion.div
            initial={{ opacity: 0, y: 24 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            className="relative p-16 rounded-[40px] bg-white/[0.04] border border-white/[0.09] overflow-hidden"
          >
            <div className="absolute inset-0 pointer-events-none">
              <div className="absolute top-0 left-1/2 -translate-x-1/2 w-[500px] h-[200px] rounded-full bg-blue-600/10 blur-[80px]" />
            </div>
            <div className="relative z-10 space-y-6">
              <h2 className="text-4xl md:text-5xl font-black tracking-tight">
                Your first game is
                <br />
                30 minutes away.
              </h2>
              <p className="text-zinc-500 text-lg font-medium max-w-xl mx-auto">
                Join 14,000+ creators who ship games without touching a single
                line of code.
              </p>
              <div className="flex flex-wrap items-center justify-center gap-4">
                <a
                  href="/signup"
                  className="flex items-center gap-2.5 px-8 py-4 rounded-[16px] bg-blue-600 text-white font-bold hover:bg-blue-500 transition-all hover:scale-105 active:scale-95 shadow-[0_16px_40px_rgba(37,99,235,0.35)]"
                >
                  Start building free <Rocket size={17} />
                </a>
                <a
                  href="/studio/arcade"
                  className="flex items-center gap-2.5 px-8 py-4 rounded-[16px] border border-white/[0.08] bg-white/[0.03] text-white font-bold hover:bg-white/[0.06] transition-all"
                >
                  Browse the Arcade <ArrowRight size={17} />
                </a>
              </div>
            </div>
          </motion.div>
        </div>
      </section>

      {/* ═══════════════════ FOOTER ═══════════════════ */}
      <footer className="border-t border-white/[0.05] py-12">
        <div className="max-w-7xl mx-auto px-6">
          <div className="flex flex-col md:flex-row items-center justify-between gap-6">
            <ForgeLogo size={40} />
            <div className="flex items-center gap-6 text-[12px] text-zinc-600">
              <a href="#" className="hover:text-white transition-colors">
                Privacy
              </a>
              <a href="#" className="hover:text-white transition-colors">
                Terms
              </a>
              <a href="#" className="hover:text-white transition-colors">
                Docs
              </a>
              <a href="/signin" className="hover:text-white transition-colors">
                Sign in
              </a>
            </div>
            <div className="text-[11px] text-zinc-700">
              © 2026 GameForge. All rights reserved.
            </div>
          </div>
        </div>
      </footer>

      {/* ═══════════════════ DEMO MODAL ═══════════════════ */}
      <AnimatePresence>
        {trailerOpen && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 z-[100] flex items-center justify-center bg-black/80 backdrop-blur-xl px-6"
            onClick={() => setTrailerOpen(false)}
          >
            <motion.div
              initial={{ y: 20, scale: 0.97, opacity: 0 }}
              animate={{ y: 0, scale: 1, opacity: 1 }}
              exit={{ y: 20, scale: 0.97, opacity: 0 }}
              onClick={(e) => e.stopPropagation()}
              className="w-full max-w-3xl rounded-[28px] overflow-hidden border border-white/[0.08] bg-[#0c0e18] shadow-[0_40px_120px_rgba(0,0,0,0.8)]"
            >
              <div className="flex items-center justify-between px-6 py-4 border-b border-white/[0.06]">
                <span className="text-[11px] font-black text-zinc-500 uppercase tracking-widest">
                  GameForge • Product Demo
                </span>
                <button
                  onClick={() => setTrailerOpen(false)}
                  className="text-zinc-550 hover:text-white transition-colors text-sm px-3 py-1.5 rounded-lg hover:bg-white/[0.06]"
                >
                  Close
                </button>
              </div>
              <div className="aspect-video bg-black flex items-center justify-center">
                <div className="text-center space-y-4">
                  <div className="h-16 w-16 rounded-[20px] bg-blue-600/20 border border-blue-500/30 flex items-center justify-center mx-auto">
                    <Play size={28} className="text-blue-400 ml-1" />
                  </div>
                  <p className="text-zinc-500 text-sm">
                    Demo video — coming soon
                  </p>
                </div>
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
