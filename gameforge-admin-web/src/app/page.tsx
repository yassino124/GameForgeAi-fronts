"use client";

import { motion, useScroll, useTransform, AnimatePresence, useReducedMotion } from "framer-motion";
import Tilt from "react-parallax-tilt";
import {
  Rocket,
  Cpu,
  ArrowRight,
  ChevronRight,
  Code2,
  ShieldCheck,
  PlayCircle,
  Wand2,
  BrainCircuit,
  Boxes,
  Microchip,
  Gamepad2,
  Globe,
  Smartphone,
  Monitor,
  Laptop,
  Apple,
  Sparkles,
  TrendingUp,
  Eye,
  Heart
} from "lucide-react";
import { useRef, useState, useEffect } from "react";
import MatrixRain from "@/app/_components/MatrixRain";
import ForgeLogo from "@/app/_components/ForgeLogo";
import { API_BASE_URL, apiFetch } from "@/lib/api";
import { getUserToken } from "@/lib/userAuth";

const fadeInUp = {
  initial: { opacity: 0, y: 30 },
  animate: { opacity: 1, y: 0 },
  transition: { duration: 0.8, ease: [0.16, 1, 0.3, 1] }
};

const staggerContainer = {
  animate: {
    transition: {
      staggerChildren: 0.15
    }
  }
};

const HeroVideoShowcase = ({ src, loopSeconds = 30 }: { src: string; loopSeconds?: number }) => {
  const shouldReduceMotion = useReducedMotion();
  const videoRef = useRef<HTMLVideoElement | null>(null);
  const [ready, setReady] = useState(false);
  const [playing, setPlaying] = useState(true);
  const [t, setT] = useState(0);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const v = videoRef.current;
    if (!v) return;
    if (shouldReduceMotion) {
      v.pause();
      setPlaying(false);
    }
  }, [shouldReduceMotion]);

  const clampLoopWindow = () => {
    const v = videoRef.current;
    if (!v) return;
    const ct = Math.max(0, v.currentTime || 0);
    if (ct >= loopSeconds) {
      try {
        v.currentTime = 0.001;
      } catch { }
    }
    setT(Math.min(loopSeconds, ct));
  };

  const toggle = async () => {
    const v = videoRef.current;
    if (!v) return;
    if (v.paused) {
      try {
        clampLoopWindow();
        await v.play();
        setPlaying(true);
      } catch {
        setPlaying(false);
      }
    } else {
      v.pause();
      setPlaying(false);
    }
  };

  const progress = loopSeconds > 0 ? Math.max(0, Math.min(1, t / loopSeconds)) : 0;

  return (
    <div className="absolute inset-0">
      <div className="absolute inset-0 bg-gradient-to-br from-indigo-500/10 via-transparent to-black/55" />
      <div className="absolute inset-0">
        <video
          ref={videoRef}
          src={src}
          muted
          autoPlay={!shouldReduceMotion}
          playsInline
          preload="metadata"
          onCanPlay={() => {
            setReady(true);
            setError(null);
            clampLoopWindow();
          }}
          onPlay={() => setPlaying(true)}
          onPause={() => setPlaying(false)}
          onTimeUpdate={clampLoopWindow}
          onEnded={clampLoopWindow}
          onError={() => {
            setError('Failed to load video');
            setPlaying(false);
          }}
          className="h-full w-full object-cover opacity-90"
          onClick={toggle}
        />
      </div>

      <div className="absolute inset-0 pointer-events-none">
        <div className="absolute -left-24 -top-24 h-72 w-72 rounded-full bg-indigo-500/12 blur-[90px]" />
        <div className="absolute -right-24 -bottom-24 h-72 w-72 rounded-full bg-fuchsia-500/10 blur-[90px]" />
      </div>

      <div className="absolute bottom-5 left-5 right-5 flex items-center gap-3">
        <button
          type="button"
          onClick={toggle}
          className="pointer-events-auto group relative h-12 w-12 rounded-2xl bg-black/35 backdrop-blur-xl border border-white/10 shadow-[0_20px_60px_rgba(0,0,0,0.45)] flex items-center justify-center transition-transform active:scale-95"
          aria-label={playing ? "Pause" : "Play"}
        >
          <div className="absolute -inset-px rounded-2xl bg-gradient-to-br from-indigo-500/35 via-white/10 to-fuchsia-500/25 opacity-70" />
          <div className="relative text-white">
            {playing ? <div className="flex gap-1"><span className="h-5 w-1.5 rounded bg-white" /><span className="h-5 w-1.5 rounded bg-white" /></div> : <PlayCircle size={22} fill="currentColor" />}
          </div>
        </button>

        <div className="flex-1 gf-panel-strong rounded-2xl border border-white/10 bg-black/25 backdrop-blur-2xl px-4 py-3 shadow-[0_20px_60px_rgba(0,0,0,0.45)]">
          <div className="flex items-center justify-between">
            <div className="text-[10px] font-black uppercase tracking-[0.35em] text-white/55">Demo Clip</div>
            <div className="text-[10px] font-black uppercase tracking-[0.35em] text-indigo-400">0–{loopSeconds}s</div>
          </div>
          <div className="mt-2 h-1.5 w-full rounded-full bg-white/10 overflow-hidden">
            <div
              className="h-full rounded-full bg-gradient-to-r from-indigo-500 via-fuchsia-500 to-cyan-400"
              style={{ width: `${Math.floor(progress * 100)}%` }}
            />
          </div>
        </div>

        <div className="pointer-events-none h-12 w-12 rounded-2xl border border-white/10 bg-black/25 backdrop-blur-2xl shadow-[0_20px_60px_rgba(0,0,0,0.45)] flex items-center justify-center">
          <div className="relative h-7 w-7">
            <svg viewBox="0 0 36 36" className="h-7 w-7 -rotate-90">
              <path
                d="M18 2 a 16 16 0 0 1 0 32 a 16 16 0 0 1 0 -32"
                fill="none"
                stroke="rgba(255,255,255,0.12)"
                strokeWidth="4"
                strokeLinecap="round"
              />
              <path
                d="M18 2 a 16 16 0 0 1 0 32 a 16 16 0 0 1 0 -32"
                fill="none"
                stroke="rgba(99,102,241,0.85)"
                strokeWidth="4"
                strokeLinecap="round"
                strokeDasharray={`${Math.floor(progress * 100)}, 100`}
              />
            </svg>
          </div>
        </div>
      </div>

      {error && (
        <div className="absolute inset-0 flex items-center justify-center">
          <div className="gf-panel-strong rounded-3xl border border-white/10 bg-black/35 backdrop-blur-2xl px-5 py-4 shadow-[0_20px_80px_rgba(0,0,0,0.55)]">
            <div className="text-[10px] font-black uppercase tracking-[0.35em] text-white/70">{error}</div>
          </div>
        </div>
      )}

      {!ready && !error && (
        <div className="absolute inset-0 flex items-center justify-center">
          <div className="gf-panel-strong rounded-3xl border border-white/10 bg-black/30 backdrop-blur-2xl px-5 py-4 shadow-[0_20px_80px_rgba(0,0,0,0.55)]">
            <div className="text-[10px] font-black uppercase tracking-[0.35em] text-white/60">Loading clip…</div>
          </div>
        </div>
      )}
    </div>
  );
};

const AIPreviewTerminal = ({ prompt, active }: { prompt: string, active: boolean }) => {
  const [step, setStep] = useState(0);
  const steps = [
    { label: "NEURAL MAPPING", icon: BrainCircuit, color: "text-indigo-400" },
    { label: "LOGIC SYNTHESIS", icon: Code2, color: "text-fuchsia-400" },
    { label: "ASSET WEAVING", icon: Boxes, color: "text-cyan-400" },
    { label: "ENGINE BOOT", icon: Microchip, color: "text-emerald-400" }
  ];

  useEffect(() => {
    if (active) {
      const interval = setInterval(() => {
        setStep((s) => (s + 1) % steps.length);
      }, 2000);
      return () => clearInterval(interval);
    }
  }, [active]);

  return (
    <div className="absolute -bottom-24 left-0 right-0 px-4 pointer-events-none">
      <AnimatePresence>
        {active && (
          <motion.div
            initial={{ opacity: 0, y: 20, scale: 0.95 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            exit={{ opacity: 0, scale: 0.95 }}
            className="gf-panel-strong gf-stroke-gradient mx-auto max-w-md rounded-2xl p-4 shadow-2xl backdrop-blur-2xl bg-black/60 border border-white/10"
          >
            <div className="flex items-center gap-4">
              <div className={`p-2 rounded-xl bg-white/5 ${steps[step].color}`}>
                <motion.div
                  key={step}
                  initial={{ rotate: -90, opacity: 0 }}
                  animate={{ rotate: 0, opacity: 1 }}
                >
                  {(() => {
                    const Icon = steps[step].icon;
                    return <Icon size={18} />;
                  })()}
                </motion.div>
              </div>
              <div className="flex-1">
                <div className="flex justify-between items-center mb-1.5">
                  <span className="text-[9px] font-black uppercase tracking-[0.2em] text-white/40">AI Architect Status</span>
                  <span className={`text-[9px] font-black uppercase tracking-[0.2em] ${steps[step].color}`}>{steps[step].label}</span>
                </div>
                <div className="h-1 w-full bg-white/5 rounded-full overflow-hidden">
                  <motion.div
                    key={step}
                    initial={{ width: "0%" }}
                    animate={{ width: "100%" }}
                    transition={{ duration: 2, ease: "linear" }}
                    className={`h-full ${steps[step].color.replace('text', 'bg')}`}
                  />
                </div>
              </div>
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
};

function LandingAICoachTip() {
  const AI_TIPS = [
    "Did you know? You can export to 5+ platforms in one click.",
    "Pro Tip: Use the 'Neural Storyboard' to generate levels instantly.",
    "AI Coach: Try adding a 'Cyberpunk' theme to your first project.",
    "Optimization: Compress textures to make your WebGL games fly.",
    "Community: 1.2k+ creators joined the GameForge ecosystem this week."
  ];

  const [tipIdx, setTipIdx] = useState(0);

  useEffect(() => {
    const interval = setInterval(() => {
      setTipIdx((prev) => (prev + 1) % AI_TIPS.length);
    }, 6000);
    return () => clearInterval(interval);
  }, []);

  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      whileInView={{ opacity: 1, y: 0 }}
      viewport={{ once: true }}
      className="relative mx-auto max-w-4xl overflow-hidden rounded-[40px] border border-indigo-500/20 bg-white/[0.02] backdrop-blur-3xl p-10 shadow-[0_20px_80px_rgba(0,0,0,0.4)] group"
    >
      <div className="absolute -right-20 -top-20 h-64 w-64 rounded-full bg-indigo-500/10 blur-[100px] group-hover:bg-indigo-500/20 transition-all duration-700" />
      <div className="absolute -left-20 -bottom-20 h-64 w-64 rounded-full bg-fuchsia-500/10 blur-[100px] group-hover:bg-fuchsia-500/20 transition-all duration-700" />

      <div className="relative z-10 flex flex-col md:flex-row items-center gap-8">
        <div className="shrink-0 relative">
          <div className="h-20 w-20 rounded-3xl bg-gradient-to-br from-indigo-500 to-fuchsia-600 flex items-center justify-center shadow-2xl shadow-indigo-500/20 group-hover:rotate-6 transition-transform duration-500">
            <Sparkles size={40} className="text-white animate-pulse" />
          </div>
          <div className="absolute -bottom-2 -right-2 h-8 w-8 rounded-full bg-emerald-500 border-4 border-[#05060a] flex items-center justify-center">
            <div className="h-2 w-2 rounded-full bg-white animate-ping" />
          </div>
        </div>

        <div className="flex-1 text-center md:text-left">
          <div className="flex items-center justify-center md:justify-start gap-2 mb-2">
            <span className="text-[10px] font-black uppercase tracking-[0.4em] text-indigo-400">AI Coach Assistant</span>
            <div className="h-1 w-1 rounded-full bg-zinc-600" />
            <span className="text-[10px] font-black uppercase tracking-[0.4em] text-emerald-400">Live Tip</span>
          </div>
          <AnimatePresence mode="wait">
            <motion.h3
              key={tipIdx}
              initial={{ opacity: 0, x: 20 }}
              animate={{ opacity: 1, x: 0 }}
              exit={{ opacity: 0, x: -20 }}
              className="text-2xl md:text-3xl font-bold text-white tracking-tight leading-tight"
            >
              "{AI_TIPS[tipIdx]}"
            </motion.h3>
          </AnimatePresence>
        </div>

        <div className="flex flex-col sm:flex-row gap-4">
          <button className="px-8 py-4 rounded-2xl bg-indigo-500 text-white text-[10px] font-black uppercase tracking-widest hover:scale-105 active:scale-95 transition-all shadow-xl shadow-indigo-500/20">
            Tell me more
          </button>
          <button className="px-8 py-4 rounded-2xl bg-white/5 text-zinc-400 text-[10px] font-black uppercase tracking-widest hover:bg-white/10 transition-all border border-white/5">
            Dismiss
          </button>
        </div>
      </div>
    </motion.div>
  );
}

function LandingArcadeSection() {
  const resolveMediaUrl = (raw?: string | null) => {
    const s = String(raw ?? "").trim();
    if (!s) return "";
    if (s.startsWith("http://") || s.startsWith("https://")) return s;
    const base = String(API_BASE_URL || "").replace(/\/?api\/?$/, "");
    if (!base) return s;
    if (s.startsWith("/")) return `${base}${s}`;
    return `${base}/${s}`;
  };

  const asInt = (v: any) => {
    if (typeof v === "number" && Number.isFinite(v)) return Math.floor(v);
    return parseInt(String(v ?? "0"), 10) || 0;
  };

  const FALLBACK_GAMES = [
    { id: "f1", title: "Cute Cartoon Platf...", views: "359", likes: "3", author: "PixelWizard", img: "https://images.unsplash.com/photo-1614850523296-d8c1af93d400?auto=format&fit=crop&q=80&w=600" },
    { id: "f2", title: "AI Game Royale", views: "149", likes: "12", author: "NeuroDev", img: "https://images.unsplash.com/photo-1542751371-adc38448a05e?auto=format&fit=crop&q=80&w=600" },
    { id: "f3", title: "Neon Drifter 2077", views: "1.2k", likes: "84", author: "CyberGhost", img: "https://images.unsplash.com/photo-1550745165-9bc0b252726f?auto=format&fit=crop&q=80&w=600" },
    { id: "f4", title: "TheLostForest", views: "2.1k", likes: "156", author: "NatureCoder", img: "https://images.unsplash.com/photo-1534423861386-85a16f5d13fd?auto=format&fit=crop&q=80&w=600" },
    { id: "f5", title: "Void Runner", views: "982", likes: "45", author: "VoidX", img: "https://images.unsplash.com/photo-1614850523459-c2f4c699c52e?auto=format&fit=crop&q=80&w=600" },
  ];

  const [trendingGames, setTrendingGames] = useState<Array<{ id: string; title: string; views: string; likes: string; author: string; img: string }>>(FALLBACK_GAMES);

  useEffect(() => {
    let cancelled = false;
    async function load() {
      try {
        const token = getUserToken();
        if (!token) return;
        const gf = await apiFetch<any>("/game-feed?limit=30", { method: "GET", token });
        const gfData = (gf && typeof gf === "object" && "data" in gf) ? (gf as any).data : gf;
        const gfItems = Array.isArray((gfData as any)?.data) ? (gfData as any).data : (Array.isArray(gfData) ? gfData : []);
        const posts = (Array.isArray(gfItems) ? gfItems : []).filter(Boolean).map((x: any) => (x && typeof x === "object" ? x : {}));

        const top = posts.slice(0, 5).map((p: any, idx: number) => {
          const id = String(p.id || p._id || `post_${idx}`);
          const title = String(p.title || p.name || "Game");
          const author = String(p.authorName || p.creatorName || p.creatorUsername || p.creator || "Creator");
          const likes = asInt(p.likeCount);
          const plays = asInt(p.playCount);
          const views = asInt(p.viewCount);
          const v = views > 0 ? views : plays;
          const rawImg = p.previewImageUrl || p.previewImage || p.thumbnailUrl || "";
          const img = resolveMediaUrl(rawImg);

          const fmt = (n: number) => (n >= 1000 ? `${(n / 1000).toFixed(1)}k`.replace(/\.0k$/, "k") : `${n}`);
          return { id, title, views: fmt(v), likes: fmt(likes), author, img };
        });

        if (!cancelled && top.length) setTrendingGames(top);
      } catch {
        // keep fallback
      }
    }
    load();
    return () => {
      cancelled = true;
    };
  }, []);

  return (
    <div className="space-y-12">
      <div className="text-center space-y-4">
        <motion.div
          initial={{ opacity: 0, y: 10 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          className="inline-flex items-center gap-2 rounded-full border border-fuchsia-500/20 bg-fuchsia-500/5 px-4 py-1.5 text-[10px] font-black uppercase tracking-widest text-fuchsia-400"
        >
          <TrendingUp size={12} />
          Trending Now
        </motion.div>
        <h2 className="text-4xl md:text-5xl font-black text-white tracking-tighter uppercase italic">
          Community Arcade
        </h2>
        <p className="mx-auto max-w-2xl text-zinc-400 font-medium">
          Discover the top 5 games built with GameForge this week. High performance, AI-driven, and ready for all platforms.
        </p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-5 gap-6">
        {trendingGames.map((game, i) => (
          <motion.div
            key={i}
            initial={{ opacity: 0, scale: 0.9 }}
            whileInView={{ opacity: 1, scale: 1 }}
            viewport={{ once: true }}
            transition={{ delay: i * 0.1 }}
            whileHover={{ y: -10 }}
            className="group relative aspect-[3/4] rounded-[32px] overflow-hidden border border-white/5 bg-[#0a0b14] shadow-2xl"
          >
            <img
              src={game.img}
              alt={game.title}
              className="absolute inset-0 w-full h-full object-cover opacity-60 group-hover:scale-110 group-hover:opacity-100 transition-all duration-700"
            />
            <div className="absolute inset-0 bg-gradient-to-t from-[#05060a] via-[#05060a]/20 to-transparent" />

            <div className="absolute top-6 left-6 right-6 flex items-center justify-between">
              <div className="h-8 w-8 rounded-full bg-white/10 backdrop-blur-md border border-white/10 flex items-center justify-center text-[10px] font-black text-white italic">
                #{i + 1}
              </div>
              <div className="px-3 py-1 rounded-full bg-indigo-500 text-white text-[8px] font-black uppercase tracking-widest shadow-lg shadow-indigo-500/20">
                Top {i === 0 ? "Pick" : "Trending"}
              </div>
            </div>

            <div className="absolute bottom-0 left-0 right-0 p-8 space-y-4">
              <div>
                <div className="text-[10px] font-black text-indigo-400 uppercase tracking-widest mb-1">by {game.author}</div>
                <h4 className="text-lg font-bold text-white leading-tight group-hover:text-indigo-300 transition-colors">{game.title}</h4>
              </div>
              <div className="flex items-center justify-between border-t border-white/5 pt-4">
                <div className="flex items-center gap-4">
                  <span className="flex items-center gap-1.5 text-[10px] font-black text-zinc-400 uppercase">
                    <Eye size={14} className="text-zinc-500" /> {game.views}
                  </span>
                  <span className="flex items-center gap-1.5 text-[10px] font-black text-zinc-400 uppercase">
                    <Heart size={14} className="text-red-500 fill-red-500" /> {game.likes}
                  </span>
                </div>
                <button className="h-10 w-10 rounded-2xl bg-white/10 backdrop-blur-md border border-white/10 flex items-center justify-center text-white hover:bg-white/20 transition-all">
                  <Gamepad2 size={18} />
                </button>
              </div>
            </div>
          </motion.div>
        ))}
      </div>
    </div>
  );
}

export default function Home() {
  const containerRef = useRef(null);
  const shouldReduceMotion = useReducedMotion();
  const [previewPrompt, setPreviewPrompt] = useState("");
  const [isPreviewActive, setPreviewActive] = useState(false);
  const [trailerOpen, setTrailerOpen] = useState(false);
  const [mousePos, setMousePos] = useState({ x: 0, y: 0 });

  useEffect(() => {
    const handleMouseMove = (e: MouseEvent) => {
      setMousePos({ x: e.clientX, y: e.clientY });
    };
    window.addEventListener("mousemove", handleMouseMove);
    return () => window.removeEventListener("mousemove", handleMouseMove);
  }, []);

  useEffect(() => {
    function onKey(e: KeyboardEvent) {
      if (e.key === "Escape") setTrailerOpen(false);
    }
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, []);

  const { scrollYProgress } = useScroll({
    target: containerRef,
    offset: ["start start", "end end"]
  });

  const heroScale = useTransform(scrollYProgress, [0, 0.2], [1, 0.9]);
  const heroOpacity = useTransform(scrollYProgress, [0, 0.2], [1, 0]);

  return (
    <div ref={containerRef} className="relative min-h-screen bg-[#05060a] selection:bg-indigo-500/30">
      {/* TOP WOW: Cinematic Mesh Gradient Background */}
      <div className="fixed inset-0 pointer-events-none z-0 overflow-hidden">
        <motion.div
          animate={{
            scale: [1, 1.2, 1],
            x: [0, 100, 0],
            y: [0, 50, 0],
          }}
          transition={{ duration: 20, repeat: Infinity, ease: "easeInOut" }}
          className="absolute -top-[20%] -left-[10%] w-[70%] h-[70%] rounded-full bg-indigo-500/10 blur-[120px]"
        />
        <motion.div
          animate={{
            scale: [1.2, 1, 1.2],
            x: [0, -80, 0],
            y: [0, -40, 0],
          }}
          transition={{ duration: 25, repeat: Infinity, ease: "easeInOut", delay: 2 }}
          className="absolute -bottom-[10%] -right-[5%] w-[60%] h-[60%] rounded-full bg-fuchsia-500/10 blur-[140px]"
        />
        <div
          className="absolute inset-0 opacity-[0.15]"
          style={{
            background: `radial-gradient(circle at ${mousePos.x}px ${mousePos.y}px, rgba(99, 102, 241, 0.15) 0%, transparent 40%)`
          }}
        />
      </div>

      {/* MATRIX BACKGROUND LAYER */}
      <MatrixRain />
      {/* Dynamic Background Layer */}
      <div className="pointer-events-none absolute inset-0 overflow-hidden">
        <div className="gf-grid absolute inset-0 opacity-20" />
        <div className="gf-noise absolute inset-0 opacity-10" />

        <motion.div
          animate={{
            scale: [1, 1.2, 1],
            opacity: [0.3, 0.5, 0.3],
            rotate: [0, 90, 0]
          }}
          transition={{ duration: 20, repeat: Infinity, ease: "linear" }}
          className="absolute -top-[20%] -left-[10%] h-[1000px] w-[1000px] rounded-full bg-indigo-600/10 blur-[160px]"
        />
        <motion.div
          animate={{
            scale: [1, 1.1, 1],
            opacity: [0.2, 0.4, 0.2],
            rotate: [0, -90, 0]
          }}
          transition={{ duration: 25, repeat: Infinity, ease: "linear", delay: 2 }}
          className="absolute top-[10%] -right-[15%] h-[900px] w-[900px] rounded-full bg-fuchsia-600/10 blur-[180px]"
        />
      </div>

      <div className="relative mx-auto max-w-7xl px-6 lg:px-8">
        {/* Premium Navigation */}
        <div className="sticky top-0 z-50 -mx-6 px-6 lg:-mx-8 lg:px-8">
          <div className="pt-6 pb-4">
            <nav className="gf-panel-strong rounded-[28px] border border-white/10 bg-black/30 backdrop-blur-2xl px-5 py-4 shadow-[0_20px_80px_rgba(0,0,0,0.45)]">
              <div className="flex items-center justify-between gap-6">
                <motion.div
                  initial={{ opacity: 0, x: -16 }}
                  animate={{ opacity: 1, x: 0 }}
                  className="min-w-0"
                >
                  <a href="/" className="inline-flex items-center">
                    <ForgeLogo size={70} />
                  </a>
                </motion.div>

                <motion.div
                  initial={{ opacity: 0, x: 16 }}
                  animate={{ opacity: 1, x: 0 }}
                  className="flex items-center gap-3 sm:gap-4"
                >
                  <a
                    href="/studio/marketplace"
                    className="hidden rounded-xl px-3 py-2 text-sm font-semibold tracking-wide text-zinc-400 transition hover:bg-white/5 hover:text-white lg:block"
                  >
                    Marketplace
                  </a>
                  <a
                    href="/signin"
                    className="hidden rounded-xl px-3 py-2 text-sm font-semibold tracking-wide text-zinc-400 transition hover:bg-white/5 hover:text-white sm:block"
                  >
                    Log in
                  </a>
                  <a
                    href="/signup"
                    className="gf-stroke-gradient gf-glow relative group rounded-2xl bg-white/[0.04] px-5 py-3 text-sm font-black uppercase tracking-widest text-white overflow-hidden transition-all active:scale-95"
                  >
                    <div className="absolute inset-0 bg-gradient-to-r from-indigo-500 to-fuchsia-500 opacity-0 group-hover:opacity-10 transition-opacity" />
                    Get Started
                  </a>
                </motion.div>
              </div>
            </nav>
          </div>
        </div>

        {/* Cinematic Hero */}
        <motion.main
          style={{ scale: heroScale, opacity: heroOpacity }}
          className="pt-16 pb-32 lg:pt-24 lg:pb-48"
        >
          <div className="grid grid-cols-1 gap-24 lg:grid-cols-2 lg:items-center">
            <motion.div
              variants={staggerContainer}
              initial="initial"
              animate="animate"
              className="relative z-10 text-center lg:text-left"
            >
              <motion.div
                variants={fadeInUp}
                className="inline-flex items-center gap-3 rounded-full border border-white/5 bg-white/[0.02] px-5 py-2 text-[11px] font-black uppercase tracking-[0.2em] text-indigo-400 shadow-xl backdrop-blur-md"
              >
                <div className="flex h-2 w-2 rounded-full bg-indigo-500 animate-pulse shadow-[0_0_8px_rgba(99,102,241,0.8)]" />
                The Ultimate Web Engine
              </motion.div>

              <motion.h1
                variants={fadeInUp}
                className="mt-10 text-7xl font-bold leading-[0.95] tracking-tight sm:text-8xl xl:text-9xl relative"
              >
                <span className="relative inline-block">
                  Build Your
                  <motion.span
                    animate={{
                      opacity: [1, 0.8, 1, 0.9, 1],
                      x: [0, -1, 1, -1, 0]
                    }}
                    transition={{ duration: 0.2, repeat: Infinity, repeatDelay: 5 }}
                    className="absolute inset-0 text-indigo-500/30 blur-sm pointer-events-none"
                  >
                    Build Your
                  </motion.span>
                </span>
                <br />
                <span className="relative inline-block bg-gradient-to-r from-indigo-400 via-fuchsia-400 to-cyan-400 bg-clip-text text-transparent italic pb-2">
                  Universe.
                  <motion.span
                    animate={{
                      backgroundPosition: ["0% 50%", "100% 50%", "0% 50%"]
                    }}
                    transition={{ duration: 5, repeat: Infinity, ease: "linear" }}
                    style={{ backgroundSize: "200% auto" }}
                    className="absolute inset-0 bg-gradient-to-r from-transparent via-white/20 to-transparent bg-clip-text text-transparent pointer-events-none"
                  >
                    Universe.
                  </motion.span>
                </span>
              </motion.h1>

              <motion.p
                variants={fadeInUp}
                className="mt-10 max-w-xl text-xl leading-relaxed text-zinc-400 mx-auto lg:mx-0 font-medium"
              >
                Create, build, and deploy high-performance games entirely in your browser.
                Powered by AI logic and cinematic rendering.
              </motion.p>

              <motion.div
                variants={fadeInUp}
                className="mt-12 max-w-2xl mx-auto lg:mx-0 relative"
              >
                <div className="gf-panel-strong gf-stroke-gradient p-2 rounded-[32px] shadow-2xl relative group focus-within:border-indigo-500/50 transition-all">
                  <div className="flex items-center gap-2">
                    <div className="flex-1 relative">
                      <Wand2 className={`absolute left-5 top-1/2 -translate-y-1/2 transition-colors ${isPreviewActive ? 'text-indigo-400 animate-pulse' : 'text-zinc-500'}`} size={20} />
                      <input
                        className="w-full bg-transparent border-none outline-none pl-14 pr-6 py-5 text-sm text-white placeholder:text-zinc-600 font-medium"
                        placeholder="Describe your game idea... e.g. 'A space combat RPG with trade mechanics'"
                        value={previewPrompt}
                        onChange={(e) => setPreviewPrompt(e.target.value)}
                        onFocus={() => setPreviewActive(true)}
                        onBlur={() => !previewPrompt && setPreviewActive(false)}
                      />
                    </div>
                    <button
                      onClick={() => previewPrompt && (window.location.href = `/signup?prompt=${encodeURIComponent(previewPrompt)}`)}
                      className="rounded-2xl bg-white text-black px-8 py-4 text-xs font-black uppercase tracking-widest transition-all hover:scale-[1.02] active:scale-95 shadow-xl"
                    >
                      Generate
                    </button>
                  </div>

                  <AIPreviewTerminal prompt={previewPrompt} active={isPreviewActive} />
                </div>
              </motion.div>

              <motion.div
                variants={fadeInUp}
                className="mt-20 flex flex-col gap-5 sm:flex-row sm:justify-center lg:justify-start"
              >
                <a
                  href="/signup"
                  className="gf-glow group relative flex items-center justify-center gap-3 rounded-2xl bg-indigo-500 px-10 py-5 text-sm font-black uppercase tracking-[0.15em] text-white transition-all hover:scale-105 hover:bg-indigo-600 active:scale-95 shadow-[0_20px_50px_rgba(99,102,241,0.3)]"
                >
                  Launch Studio <Rocket size={20} className="transition-transform group-hover:-translate-y-1 group-hover:translate-x-1" />
                </a>
                <button
                  className="gf-btn group flex items-center justify-center gap-3 rounded-2xl border border-white/10 bg-white/5 px-10 py-5 text-sm font-black uppercase tracking-[0.15em] text-white transition-all hover:bg-white/10"
                  onClick={() => setTrailerOpen(true)}
                >
                  Watch Trailer <PlayCircle size={20} />
                </button>
              </motion.div>
            </motion.div>

            {/* Premium Interactive Visual */}
            <motion.div
              initial={{ opacity: 0, scale: 0.8, rotate: shouldReduceMotion ? 0 : 5 }}
              animate={{ opacity: 1, scale: 1, rotate: 0 }}
              transition={{ duration: 1.5, ease: [0.16, 1, 0.3, 1] }}
              className="relative hidden lg:block perspective-1000"
            >
              <Tilt
                perspective={1200}
                glareEnable={!shouldReduceMotion}
                glareMaxOpacity={0.15}
                scale={shouldReduceMotion ? 1 : 1.02}
                className="relative z-10"
              >
                <div className="relative group overflow-hidden rounded-[48px] border border-white/10 bg-black/40 aspect-[4/3] gf-glow shadow-[0_0_100px_rgba(99,102,241,0.1)]">
                  <div className="absolute inset-0 bg-gradient-to-br from-indigo-500/20 via-transparent to-fuchsia-500/20" />
                  <img
                    src="https://images.unsplash.com/photo-1542751371-adc38448a05e?auto=format&fit=crop&q=80&w=2070"
                    alt="Engine Preview"
                    loading="lazy"
                    decoding="async"
                    className="absolute inset-0 w-full h-full object-cover opacity-60 mix-blend-overlay group-hover:scale-105 transition-transform duration-700"
                  />
                  <div className="absolute inset-0 bg-gradient-to-t from-black via-transparent to-transparent" />

                  <div className="absolute bottom-8 left-8 right-8">
                    <div className="flex items-center gap-3 mb-4">
                      <div className="h-2 w-2 rounded-full bg-indigo-500 animate-ping" />
                      <span className="text-[10px] font-black uppercase tracking-widest text-white/60">Live Preview Engine</span>
                    </div>
                    <div className="h-1.5 w-full bg-white/10 rounded-full overflow-hidden">
                      <motion.div
                        animate={{ width: ["0%", "100%", "0%"] }}
                        transition={{ duration: 10, repeat: Infinity, ease: "easeInOut" }}
                        className="h-full bg-indigo-500"
                      />
                    </div>
                  </div>
                </div>
              </Tilt>

              {/* Floating Orbitals */}
              <div className="absolute -inset-10 border border-indigo-500/10 rounded-full pointer-events-none animate-[spin_20s_linear_infinite]" />
              <div className="absolute -inset-20 border border-fuchsia-500/5 rounded-full pointer-events-none animate-[spin_35s_linear_infinite_reverse]" />
            </motion.div>
          </div>
        </motion.main>

        <AnimatePresence>
          {trailerOpen ? (
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              className="fixed inset-0 z-[100] flex items-center justify-center bg-black/70 backdrop-blur-xl px-6"
              onClick={() => setTrailerOpen(false)}
            >
              <motion.div
                initial={{ y: 18, scale: 0.98, opacity: 0 }}
                animate={{ y: 0, scale: 1, opacity: 1 }}
                exit={{ y: 18, scale: 0.98, opacity: 0 }}
                transition={{ duration: 0.25 }}
                className="w-full max-w-4xl overflow-hidden rounded-[32px] border border-white/10 bg-black/60 shadow-[0_30px_120px_rgba(0,0,0,0.7)]"
                onClick={(e) => e.stopPropagation()}
              >
                <div className="flex items-center justify-between px-6 py-4 border-b border-white/10">
                  <div className="text-[10px] font-black uppercase tracking-[0.3em] text-zinc-400">GameForge Trailer</div>
                  <button
                    onClick={() => setTrailerOpen(false)}
                    className="rounded-xl border border-white/10 bg-white/5 px-3 py-2 text-[10px] font-black uppercase tracking-widest text-zinc-300 hover:text-white hover:bg-white/10 transition"
                  >
                    Close
                  </button>
                </div>
                <div className="relative aspect-video bg-black">
                  <div className="absolute inset-0 bg-gradient-to-br from-indigo-500/15 via-transparent to-fuchsia-500/15" />
                  <div className="absolute inset-0 flex items-center justify-center">
                    <div className="text-center">
                      <div className="mx-auto mb-4 h-14 w-14 rounded-2xl bg-white text-black flex items-center justify-center shadow-[0_0_40px_rgba(255,255,255,0.25)]">
                        <PlayCircle size={30} />
                      </div>
                      <div className="text-sm font-bold text-white">Trailer video placeholder</div>
                      <div className="mt-1 text-xs text-zinc-400">Replace this with an mp4/embed when ready.</div>
                    </div>
                  </div>
                </div>
              </motion.div>
            </motion.div>
          ) : null}
        </AnimatePresence>

        {/* FEATURED GAMES MARQUEE */}
        <section className="py-24 overflow-hidden border-y border-white/5 relative bg-white/[0.01]">
          <div className="absolute top-0 left-0 w-32 h-full bg-gradient-to-r from-[#05060a] to-transparent z-10" />
          <div className="absolute top-0 right-0 w-32 h-full bg-gradient-to-l from-[#05060a] to-transparent z-10" />

          <div className="flex flex-col gap-12">
            <div className="px-6">
              <div className="text-[10px] font-black uppercase tracking-[0.4em] text-indigo-500 mb-2">Top Forges</div>
              <h2 className="text-3xl font-bold text-white tracking-tight italic uppercase">Community Showcase</h2>
            </div>

            <div className="flex gap-6 animate-marquee whitespace-nowrap">
              {[...Array(2)].map((_, i) => (
                <div key={i} className="flex gap-6">
                  {[
                    { title: "Neon Strike", genre: "Action", img: "https://images.unsplash.com/photo-1542751371-adc38448a05e?auto=format&fit=crop&q=80&w=400" },
                    { title: "Void Runner", genre: "Arcade", img: "https://images.unsplash.com/photo-1614850523296-d8c1af93d400?auto=format&fit=crop&q=80&w=400" },
                    { title: "Cyber Trade", genre: "RPG", img: "https://images.unsplash.com/photo-1550745165-9bc0b252726f?auto=format&fit=crop&q=80&w=400" },
                    { title: "Neural Link", genre: "Strategy", img: "https://images.unsplash.com/photo-1558591710-4b4a1ae0f04d?auto=format&fit=crop&q=80&w=400" },
                    { title: "Solaris 7", genre: "Simulation", img: "https://images.unsplash.com/photo-1451187580459-43490279c0fa?auto=format&fit=crop&q=80&w=400" }
                  ].map((game, j) => (
                    <div
                      key={j}
                      className="group relative w-[300px] aspect-[16/10] rounded-2xl overflow-hidden border border-white/10 bg-black/40 cursor-pointer"
                    >
                      <img
                        src={game.img}
                        alt={game.title}
                        loading="lazy"
                        decoding="async"
                        className="absolute inset-0 w-full h-full object-cover opacity-60 group-hover:opacity-100 group-hover:scale-110 transition-all duration-700 grayscale group-hover:grayscale-0"
                      />
                      <div className="absolute inset-0 bg-gradient-to-t from-black/90 via-transparent to-transparent opacity-60" />
                      <div className="absolute bottom-4 left-4">
                        <div className="text-[8px] font-black text-indigo-400 uppercase tracking-widest mb-1">{game.genre}</div>
                        <div className="text-sm font-bold text-white uppercase tracking-tight">{game.title}</div>
                      </div>
                    </div>
                  ))}
                </div>
              ))}
            </div>
          </div>
        </section>

        {/* PRO MAX: Community Arcade Section */}
        <section className="container relative z-10 py-32">
          <LandingArcadeSection />
        </section>

        {/* PRO MAX: Floating AI Tip Section */}
        <section className="container relative z-10 pb-32">
          <LandingAICoachTip />
        </section>

        {/* BUILD FOR ALL PLATFORMS */}
        <section className="py-28 border-b border-white/5 relative overflow-hidden">
          <div className="absolute inset-0 gf-grid opacity-[0.06]" />
          <div className="absolute -top-40 -left-40 h-[520px] w-[520px] rounded-full bg-indigo-500/10 blur-[140px]" />
          <div className="absolute -bottom-40 -right-40 h-[560px] w-[560px] rounded-full bg-fuchsia-500/10 blur-[160px]" />

          <div className="relative mx-auto max-w-6xl px-6">
            <div className="text-center">
              <div className="text-[10px] font-black uppercase tracking-[0.4em] text-indigo-500">Multi-Platform</div>
              <h2 className="mt-4 text-4xl font-black tracking-tight text-white sm:text-5xl uppercase italic">
                Build once. Ship everywhere.
              </h2>
              <p className="mx-auto mt-5 max-w-2xl text-sm text-zinc-400 font-medium">
                Generate a single project and export optimized builds for every major platform.
              </p>
            </div>

            <div className="mt-14 grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-5">
              {[
                {
                  key: "web",
                  title: "WebGL",
                  desc: "Instant browser play",
                  icon: Globe,
                  tone: "from-indigo-500/20 to-indigo-500/5",
                  ring: "border-indigo-500/20",
                  text: "text-indigo-300",
                },
                {
                  key: "android",
                  title: "Android",
                  desc: "APK export",
                  icon: Smartphone,
                  tone: "from-emerald-500/20 to-emerald-500/5",
                  ring: "border-emerald-500/20",
                  text: "text-emerald-300",
                },
                {
                  key: "ios",
                  title: "iOS",
                  desc: "iPhone-ready",
                  icon: Apple,
                  tone: "from-white/10 to-white/5",
                  ring: "border-white/10",
                  text: "text-white",
                },
                {
                  key: "windows",
                  title: "Windows",
                  desc: "Desktop build",
                  icon: Monitor,
                  tone: "from-cyan-500/20 to-cyan-500/5",
                  ring: "border-cyan-500/20",
                  text: "text-cyan-300",
                },
                {
                  key: "mac",
                  title: "macOS",
                  desc: "Native feel",
                  icon: Laptop,
                  tone: "from-fuchsia-500/20 to-fuchsia-500/5",
                  ring: "border-fuchsia-500/20",
                  text: "text-fuchsia-300",
                },
              ].map((p, idx) => {
                const Icon = p.icon as any;
                return (
                  <motion.div
                    key={p.key}
                    initial={{ opacity: 0, y: 18 }}
                    whileInView={{ opacity: 1, y: 0 }}
                    viewport={{ once: true }}
                    transition={{ duration: 0.45, delay: idx * 0.06 }}
                    whileHover={shouldReduceMotion ? {} : { y: -10, scale: 1.02 }}
                    className={
                      "relative overflow-hidden rounded-[28px] border bg-white/[0.02] p-6 shadow-[0_20px_80px_rgba(0,0,0,0.35)] transition-all " +
                      p.ring
                    }
                  >
                    <div className={"absolute inset-0 bg-gradient-to-br opacity-70 " + p.tone} />
                    <div className="absolute inset-0 opacity-0 hover:opacity-100 transition-opacity">
                      <div className="absolute -top-16 -right-16 h-56 w-56 rounded-full bg-white/5 blur-[70px]" />
                    </div>

                    <div className="relative z-10">
                      <div className={"h-12 w-12 rounded-2xl border border-white/10 bg-black/30 flex items-center justify-center " + p.text}>
                        <Icon size={22} />
                      </div>
                      <div className="mt-6">
                        <div className="text-[10px] font-black uppercase tracking-[0.3em] text-zinc-500">Target</div>
                        <div className="mt-1 text-lg font-bold text-white tracking-tight">{p.title}</div>
                        <div className="mt-2 text-xs text-zinc-400 font-medium">{p.desc}</div>
                      </div>
                    </div>

                    <motion.div
                      animate={{ y: ["-120%", "220%"] }}
                      transition={{ duration: 5.0, repeat: Infinity, ease: "linear", delay: idx * 0.2 }}
                      className="absolute inset-0 w-full h-1/2 bg-gradient-to-b from-transparent via-white/5 to-transparent pointer-events-none"
                    />
                  </motion.div>
                );
              })}
            </div>
          </div>
        </section>

        {/* SOCIAL PROOF */}
        <section className="py-20 border-b border-white/5">
          <div className="flex flex-col gap-10">
            <div className="px-6 text-center">
              <div className="text-[10px] font-black uppercase tracking-[0.4em] text-zinc-500">Trusted by creators</div>
              <div className="mt-3 text-2xl font-bold text-white tracking-tight">Studios, indie teams, and AI-first builders</div>
            </div>
            <div className="mx-auto w-full max-w-6xl px-6">
              <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-6">
                {[
                  "Neon Studio",
                  "Arcade Labs",
                  "VoidWorks",
                  "Fuchsia Forge",
                  "IndiePulse",
                  "CyberGuild",
                ].map((n) => (
                  <div
                    key={n}
                    className="rounded-2xl border border-white/10 bg-white/[0.03] px-4 py-4 text-center text-[10px] font-black uppercase tracking-[0.25em] text-zinc-400"
                  >
                    {n}
                  </div>
                ))}
              </div>
            </div>
          </div>
        </section>

        {/* NEURAL ENGINE VISUALIZER */}
        <section className="py-40 relative overflow-hidden border-t border-white/5 bg-black/20">
          <div className="absolute inset-0 gf-grid opacity-10" />
          <div className="relative z-10 text-center mb-24">
            <motion.div
              initial={{ opacity: 0 }}
              whileInView={{ opacity: 1 }}
              className="text-[10px] font-black uppercase tracking-[0.4em] text-indigo-500 mb-4"
            >
              System Architecture
            </motion.div>
            <h2 className="text-5xl font-black tracking-tight text-white sm:text-7xl uppercase italic">
              Neural Engine <br /> <span className="text-indigo-500">v4.0</span>
            </h2>
          </div>

          <div className="relative mx-auto max-w-5xl aspect-[21/9] gf-panel-strong rounded-[40px] border border-white/10 overflow-hidden shadow-2xl group">
            <div className="absolute inset-0 bg-[#05060a]/40 backdrop-blur-3xl" />

            {/* Interactive Grid Visualizer */}
            <div className="absolute inset-0 p-12 grid grid-cols-12 grid-rows-6 gap-4">
              {[...Array(72)].map((_, i) => (
                <motion.div
                  key={i}
                  initial={{ opacity: 0.1 }}
                  whileInView={{
                    opacity: [0.1, 0.4, 0.1],
                  }}
                  transition={{
                    duration: 2,
                    repeat: Infinity,
                    delay: Math.random() * 5,
                    ease: "easeInOut"
                  }}
                  className="rounded-lg bg-indigo-500/20 border border-white/5"
                />
              ))}
            </div>

            {/* Pulsing Data Streams */}
            <div className="absolute inset-0 pointer-events-none">
              <motion.div
                animate={{
                  x: ["-100%", "200%"],
                  opacity: [0, 1, 0]
                }}
                transition={{ duration: 3, repeat: Infinity, ease: "linear" }}
                className="absolute top-1/4 left-0 w-[40%] h-[1px] bg-gradient-to-r from-transparent via-fuchsia-500 to-transparent blur-md"
              />
              <motion.div
                animate={{
                  x: ["-100%", "200%"],
                  opacity: [0, 1, 0]
                }}
                transition={{ duration: 4, repeat: Infinity, ease: "linear", delay: 1 }}
                className="absolute top-2/3 left-0 w-[60%] h-[1px] bg-gradient-to-r from-transparent via-indigo-500 to-transparent blur-md"
              />
            </div>

            {/* Central Core HUD */}
            <div className="absolute inset-0 flex items-center justify-center">
              <div className="relative h-40 w-40 flex items-center justify-center">
                <motion.div
                  animate={{ rotate: 360 }}
                  transition={{ duration: 20, repeat: Infinity, ease: "linear" }}
                  className="absolute inset-0 border border-indigo-500/20 rounded-full border-dashed"
                />
                <motion.div
                  animate={{ rotate: -360 }}
                  transition={{ duration: 15, repeat: Infinity, ease: "linear" }}
                  className="absolute inset-4 border border-fuchsia-500/20 rounded-full border-dashed"
                />
                <div className="gf-glow h-16 w-16 rounded-full bg-white flex items-center justify-center text-black shadow-[0_0_40px_rgba(255,255,255,0.4)]">
                  <Cpu size={32} strokeWidth={2.5} />
                </div>
              </div>
            </div>

            {/* Stats Overlay */}
            <div className="absolute bottom-10 left-10 right-10 flex justify-between items-end">
              <div className="space-y-4">
                <div className="flex items-center gap-3">
                  <div className="h-1.5 w-1.5 rounded-full bg-emerald-500 animate-pulse" />
                  <span className="text-[10px] font-black text-white uppercase tracking-widest">Processing Node 01: Active</span>
                </div>
                <div className="h-1 w-48 bg-white/5 rounded-full overflow-hidden">
                  <motion.div
                    animate={{ width: ["10%", "90%", "40%", "80%"] }}
                    transition={{ duration: 5, repeat: Infinity }}
                    className="h-full bg-indigo-500"
                  />
                </div>
              </div>
              <div className="text-right">
                <div className="text-4xl font-black text-white italic tracking-tighter">98.4 TFLOPS</div>
                <div className="text-[10px] font-black text-zinc-600 uppercase tracking-[0.2em] mt-1">AI Throughput</div>
              </div>
            </div>
          </div>
        </section>

        {/* THE CORE ENGINE: How it Works */}
        <section className="py-32 relative">
          <div className="text-center mb-24">
            <motion.div
              initial={{ opacity: 0 }}
              whileInView={{ opacity: 1 }}
              className="text-[10px] font-black uppercase tracking-[0.4em] text-indigo-500 mb-4"
            >
              The Workflow
            </motion.div>
            <h2 className="text-5xl font-black tracking-tight text-white sm:text-6xl">
              From Concept <br /> to <span className="italic">Reality.</span>
            </h2>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-12">
            {[
              {
                step: "01",
                title: "Blueprint",
                desc: "Describe your game logic in plain language. Our AI Architect drafts the architecture instantly.",
                icon: Wand2,
                color: "indigo"
              },
              {
                step: "02",
                title: "Construct",
                desc: "Choose from millions of high-fidelity assets or generate custom ones with a single click.",
                icon: Cpu,
                color: "fuchsia"
              },
              {
                step: "03",
                title: "Bake & Ship",
                desc: "Compiled in the cloud. Optimized for all platforms. Ready to play in seconds.",
                icon: Rocket,
                color: "cyan"
              }
            ].map((item, i) => (
              <motion.div
                initial={{ opacity: 0, y: 40 }}
                whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true }}
                transition={{ delay: i * 0.2 }}
                key={i}
                className="relative group perspective-1000"
              >
                <div className="text-[80px] font-black text-white/[0.03] absolute -top-12 -left-4 pointer-events-none select-none">
                  {item.step}
                </div>
                <motion.div
                  whileHover={shouldReduceMotion ? {} : { y: -10, rotateX: 5, rotateY: -5 }}
                  className="gf-panel-strong gf-stroke-gradient p-8 rounded-[32px] min-h-[280px] flex flex-col justify-between transition-all duration-500 relative overflow-hidden"
                >
                  <div className="absolute inset-0 bg-gradient-to-br from-indigo-500/10 via-transparent to-transparent opacity-0 group-hover:opacity-100 transition-opacity" />
                  <div className={`h-14 w-14 rounded-2xl flex items-center justify-center mb-6 relative z-10 ${item.color === 'indigo' ? 'bg-indigo-500/20 text-indigo-400' :
                    item.color === 'fuchsia' ? 'bg-fuchsia-500/20 text-fuchsia-400' :
                      'bg-cyan-500/20 text-cyan-400'
                    }`}>
                    <item.icon size={28} />
                  </div>
                  <div className="relative z-10">
                    <h3 className="text-2xl font-bold text-white mb-2">{item.title}</h3>
                    <p className="text-zinc-400 text-sm leading-relaxed">{item.desc}</p>
                  </div>
                </motion.div>
              </motion.div>
            ))}
          </div>
        </section>

        {/* CINEMATIC FEATURES GRID */}
        <section className="py-32 border-t border-white/5">
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-24 items-center">
            <motion.div
              initial={{ opacity: 0, x: -40 }}
              whileInView={{ opacity: 1, x: 0 }}
              className="space-y-12"
            >
              <div>
                <h2 className="text-4xl font-bold text-white tracking-tight mb-6">AI-Driven <br />Procedural Systems.</h2>
                <p className="text-zinc-400 text-lg leading-relaxed font-medium">
                  Our core engine leverages massive neural networks to assist in every phase.
                  Auto-balancing mechanics, generative NPC behaviors, and smart collision mapping.
                </p>
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-8">
                <div className="flex gap-4">
                  <div className="h-10 w-10 shrink-0 rounded-xl bg-white/5 flex items-center justify-center text-indigo-400">
                    <ZapIcon size={20} />
                  </div>
                  <div>
                    <h4 className="text-white font-bold mb-1">Turbo Bake</h4>
                    <p className="text-xs text-zinc-500">Instant compilation across platforms.</p>
                  </div>
                </div>
                <div className="flex gap-4">
                  <div className="h-10 w-10 shrink-0 rounded-xl bg-white/5 flex items-center justify-center text-fuchsia-400">
                    <ShieldCheck size={20} />
                  </div>
                  <div>
                    <h4 className="text-white font-bold mb-1">Zero Latency</h4>
                    <p className="text-xs text-zinc-500">Optimized for competitive web-play.</p>
                  </div>
                </div>
              </div>
            </motion.div>

            <motion.div
              initial={{ opacity: 0, scale: 0.9 }}
              whileInView={{ opacity: 1, scale: 1 }}
              className="relative aspect-square gf-panel-strong gf-stroke-gradient rounded-[60px] overflow-hidden group shadow-2xl"
            >
              <HeroVideoShowcase src="/videos/hero.mp4" loopSeconds={30} />
            </motion.div>
          </div>
        </section>

        {/* Global Impact Stats */}
        <section className="pb-32">
          <div className="grid grid-cols-2 md:grid-cols-4 gap-12 lg:gap-24 border-y border-white/5 py-16">
            {[
              { val: "12M+", label: "Assets" },
              { val: "250K", label: "Creators" },
              { val: "45ms", label: "Avg Latency" },
              { val: "Zero", label: "Runtime Errors" }
            ].map((s, i) => (
              <motion.div
                initial={{ opacity: 0 }}
                whileInView={{ opacity: 1 }}
                viewport={{ once: true }}
                transition={{ delay: i * 0.1 }}
                key={i}
                className="text-center md:text-left"
              >
                <div className="text-4xl font-black tracking-tighter text-white sm:text-5xl italic">{s.val}</div>
                <div className="mt-2 text-[10px] font-black uppercase tracking-[0.3em] text-indigo-400/60">{s.label}</div>
              </motion.div>
            ))}
          </div>
        </section>

        {/* CTA Bridge */}
        <section className="py-20">
          <motion.div
            initial={{ opacity: 0, scale: 0.95 }}
            whileInView={{ opacity: 1, scale: 1 }}
            viewport={{ once: true }}
            className="gf-panel-strong gf-stroke-gradient gf-glow relative overflow-hidden rounded-[60px] p-16 lg:p-24 text-center shadow-[0_0_100px_rgba(99,102,241,0.1)]"
          >
            <div className="absolute inset-0 bg-gradient-to-br from-indigo-500/5 via-transparent to-fuchsia-500/5 pointer-events-none" />
            <h2 className="text-5xl font-black tracking-tighter text-white sm:text-6xl italic uppercase">Start Your Saga.</h2>
            <p className="mx-auto mt-6 max-w-lg text-lg text-zinc-400 font-medium">
              The tools of the future are here. Join the elite community of creators.
            </p>

            <div className="mt-12 flex flex-wrap justify-center gap-6">
              <a
                href="/signup"
                className="group flex items-center gap-4 rounded-2xl bg-white text-black px-10 py-5 text-sm font-black uppercase tracking-widest transition hover:scale-105 active:scale-95 shadow-xl shadow-white/10"
              >
                Join Now <ChevronRight size={20} className="transition group-hover:translate-x-1" />
              </a>
              <a
                href="/studio"
                className="gf-btn group flex items-center gap-4 rounded-2xl border border-white/10 bg-white/5 px-10 py-5 text-sm font-black uppercase tracking-widest text-zinc-400 transition hover:bg-white/10 hover:text-white"
              >
                Explore Studio <ArrowRight size={20} />
              </a>
            </div>
          </motion.div>
        </section>

        {/* PRICING */}
        <section className="pb-28">
          <div className="text-center mb-16">
            <div className="text-[10px] font-black uppercase tracking-[0.4em] text-indigo-500 mb-3">Pricing</div>
            <h2 className="text-5xl font-black tracking-tighter text-white sm:text-6xl italic uppercase">Choose your tier.</h2>
            <p className="mx-auto mt-6 max-w-2xl text-lg text-zinc-400 font-medium">
              Start free. Upgrade when you ship. Built for creators and teams.
            </p>
          </div>

          <div className="grid grid-cols-1 gap-8 lg:grid-cols-3">
            {[
              {
                name: "Starter",
                price: "$0",
                hint: "For exploring the Forge",
                accent: "border-white/10",
                cta: "Start Free",
              },
              {
                name: "Creator",
                price: "$19",
                hint: "For shipping real projects",
                accent: "border-indigo-500/30",
                cta: "Go Creator",
                featured: true,
              },
              {
                name: "Studio",
                price: "$49",
                hint: "For teams + pipelines",
                accent: "border-fuchsia-500/30",
                cta: "Contact Sales",
              },
            ].map((p, i) => (
              <motion.div
                key={p.name}
                initial={{ opacity: 0, y: 18 }}
                whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true }}
                transition={{ delay: i * 0.08 }}
                className={
                  (p.featured ? "gf-panel-strong gf-stroke-gradient gf-glow " : "gf-panel ") +
                  `rounded-[40px] p-10 border ${p.accent} relative overflow-hidden`
                }
              >
                <div className="absolute inset-0 bg-gradient-to-br from-indigo-500/5 via-transparent to-transparent pointer-events-none" />
                <div className="relative z-10">
                  <div className="flex items-end justify-between">
                    <div>
                      <div className="text-[10px] font-black uppercase tracking-[0.35em] text-zinc-500">{p.name}</div>
                      <div className="mt-3 text-5xl font-black tracking-tighter text-white">{p.price}<span className="text-sm text-zinc-500">/mo</span></div>
                      <div className="mt-2 text-sm text-zinc-400 font-medium">{p.hint}</div>
                    </div>
                    {p.featured ? (
                      <div className="text-[10px] font-black uppercase tracking-[0.3em] text-indigo-400 bg-indigo-500/10 border border-indigo-500/20 px-3 py-1.5 rounded-full">
                        Most Popular
                      </div>
                    ) : null}
                  </div>

                  <div className="mt-10 space-y-3 text-sm text-zinc-400">
                    {[
                      "AI Coach + Blueprints",
                      "Asset Vault + Generator",
                      "Arcade Publishing",
                      "Turbo Builds",
                    ].map((f) => (
                      <div key={f} className="flex items-center gap-3">
                        <div className="h-1.5 w-1.5 rounded-full bg-indigo-500" />
                        <span>{f}</span>
                      </div>
                    ))}
                  </div>

                  <a
                    href="/signup"
                    className={
                      (p.featured
                        ? "bg-white text-black"
                        : "bg-white/[0.03] text-white border border-white/10") +
                      " mt-10 inline-flex w-full items-center justify-center rounded-2xl px-6 py-4 text-xs font-black uppercase tracking-[0.25em] transition hover:scale-[1.01] active:scale-[0.98]"
                    }
                  >
                    {p.cta}
                  </a>
                </div>
              </motion.div>
            ))}
          </div>
        </section>

        {/* FAQ */}
        <section className="pb-24">
          <div className="gf-panel-strong rounded-[48px] border border-white/10 bg-white/[0.02] p-10 lg:p-14">
            <div className="flex flex-col gap-6 lg:flex-row lg:items-end lg:justify-between">
              <div>
                <div className="text-[10px] font-black uppercase tracking-[0.4em] text-indigo-500 mb-2">FAQ</div>
                <h2 className="text-4xl font-black tracking-tighter text-white italic uppercase">Everything you need.</h2>
                <p className="mt-4 max-w-xl text-sm text-zinc-400 font-medium">
                  Clear answers to the common questions creators ask before they commit.
                </p>
              </div>
              <a href="/signup" className="text-[10px] font-black uppercase tracking-[0.3em] text-indigo-400 hover:text-white transition">
                Start building now
              </a>
            </div>

            <div className="mt-10 grid grid-cols-1 gap-6 lg:grid-cols-2">
              {[
                {
                  q: "Is GameForge a game engine?",
                  a: "It's a creator platform that generates logic + assets and ships a playable web build — with a studio workflow on top.",
                },
                {
                  q: "Can I publish and share my game?",
                  a: "Yes — publish to the Arcade feed, share links, and track plays + likes.",
                },
                {
                  q: "Does it work on mobile?",
                  a: "Builds are web-first and optimized for modern browsers, with adaptive UI and performance tuning.",
                },
                {
                  q: "Can teams collaborate?",
                  a: "Studio tier is designed for teams: shared assets, pipelines, and workspace organization.",
                },
              ].map((f, i) => (
                <div key={i} className="gf-holographic rounded-[32px] p-7 border border-white/10">
                  <div className="text-sm font-bold text-white">{f.q}</div>
                  <div className="mt-3 text-sm text-zinc-400 leading-relaxed">{f.a}</div>
                </div>
              ))}
            </div>
          </div>
        </section>

        {/* Footer */}
        <footer className="py-20 border-t border-white/5">
          <div className="flex flex-col items-center justify-between gap-10 md:flex-row">
            <a href="/" className="inline-flex items-center">
              <ForgeLogo size={48} />
            </a>
            <div className="flex flex-wrap justify-center gap-x-12 gap-y-4 text-[10px] font-black uppercase tracking-[0.2em] text-zinc-500">
              <a href="#" className="transition hover:text-indigo-400">Twitter</a>
              <a href="#" className="transition hover:text-indigo-400">Discord</a>
              <a href="#" className="transition hover:text-indigo-400">Status</a>
              <a href="#" className="transition hover:text-indigo-400">Legal</a>
            </div>
            <div className="text-[10px] font-bold text-zinc-600 tracking-widest uppercase">
              Build with Passion.
            </div>
          </div>
        </footer>
      </div>
    </div>
  );
}

function ZapIcon({ size, className }: { size?: number, className?: string }) {
  return (
    <svg
      width={size || 24}
      height={size || 24}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
      className={className}
    >
      <polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2" />
    </svg>
  );
}
