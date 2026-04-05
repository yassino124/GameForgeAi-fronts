"use client";

import { useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import UserShell from "@/app/_components/UserShell";
import { apiFetch, ApiError } from "@/lib/api";
import { getUserToken } from "@/lib/userAuth";
import { normalizeImageUrl } from "@/lib/media";
import { motion, AnimatePresence } from "framer-motion";
import { 
  Search, Filter, Zap, Rocket, ArrowRight, Star, 
  Gamepad2, Sword, Target, Cpu, Map, Boxes, ChevronRight,
  TrendingUp, Sparkles, Award, Mic, MicOff,
  Trophy, Medal, Code, User, Crown
} from "lucide-react";

type Template = {
  id?: string;
  _id?: string;
  name?: string;
  title?: string;
  description?: string;
  category?: string;
  tags?: string[];
  price?: number;
  priceUsd?: number;
  rating?: number;
  downloads?: number;
  downloadCount?: number;
  previewImageUrl?: string;
  thumbnailUrl?: string;
  imageUrl?: string;
  ownerUsername?: string;
  ownerAvatar?: string;
  ownerRole?: string;
  isDev?: boolean;
};

function toNum(v: any) {
  if (typeof v === "number") return v;
  if (typeof v === "string") return Number(v) || 0;
  return 0;
}

const CATEGORY_COLORS: Record<string, string> = {
  "RPG": "from-rose-500/20 to-rose-500/5 text-rose-400 border-rose-500/20",
  "Action": "from-orange-500/20 to-orange-500/5 text-orange-400 border-orange-500/20",
  "Shooter": "from-red-500/20 to-red-500/5 text-red-400 border-red-500/20",
  "Puzzle": "from-emerald-500/20 to-emerald-500/5 text-emerald-400 border-emerald-500/20",
  "Simulation": "from-cyan-500/20 to-cyan-500/5 text-cyan-400 border-cyan-500/20",
  "Adventure": "from-indigo-500/20 to-indigo-500/5 text-indigo-400 border-indigo-500/20",
  "Platformer": "from-fuchsia-500/20 to-fuchsia-500/5 text-fuchsia-400 border-fuchsia-500/20",
};

const CATEGORY_ICONS: Record<string, any> = {
  "All": Sparkles,
  "RPG": Sword,
  "Action": Zap,
  "Shooter": Target,
  "Puzzle": Boxes,
  "Simulation": Cpu,
  "Adventure": Map,
  "Platformer": Gamepad2,
};

export default function StudioMarketplacePage() {
  const router = useRouter();
  const token = useMemo(() => getUserToken(), []);
  const [q, setQ] = useState("");
  const [category, setCategory] = useState("All");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [items, setItems] = useState<Template[]>([]);
  const [isListening, setIsListening] = useState(false);

  // ─── Voice Search Integration ─────────────────────────────────────────────
  const startVoiceSearch = () => {
    const SpeechRecognition = (window as any).SpeechRecognition || (window as any).webkitSpeechRecognition;
    if (!SpeechRecognition) {
      alert("Voice search is not supported in this browser.");
      return;
    }

    const recognition = new SpeechRecognition();
    recognition.lang = "en-US";
    recognition.continuous = false;
    recognition.interimResults = false;

    recognition.onstart = () => setIsListening(true);
    recognition.onend = () => setIsListening(false);
    recognition.onresult = (event: any) => {
      const transcript = event.results[0][0].transcript;
      setQ(transcript);
      setIsListening(false);
    };
    recognition.onerror = () => setIsListening(false);

    recognition.start();
  };

  useEffect(() => {
    let cancelled = false;
    const ac = new AbortController();

    async function load() {
      setLoading(true);
      setError(null);
      try {
        const qp = new URLSearchParams();
        if (q.trim()) qp.set("q", q.trim());
        if (category.trim() && category !== "All") qp.set("category", category.trim());
        const path = `/templates${qp.toString() ? `?${qp.toString()}` : ""}`;

        const res = await apiFetch<any>(path, { method: "GET", token: token || undefined, signal: ac.signal });
        const data = (res && typeof res === "object" && "data" in res) ? (res as any).data : res;
        const list = Array.isArray((data as any)?.data) ? (data as any).data : (Array.isArray(data) ? data : []);
        const normalized = list
          .filter(Boolean)
          .map((t: any) => (t && typeof t === "object" ? (t as Template) : ({} as Template)));
        if (!cancelled) setItems(normalized);
      } catch (e: any) {
        if (!cancelled) setError(e instanceof ApiError ? e.message : (e?.message || "Failed to load templates"));
      } finally {
        if (!cancelled) setLoading(false);
      }
    }

    const t = setTimeout(load, 220);
    return () => {
      cancelled = true;
      clearTimeout(t);
      ac.abort();
    };
  }, [q, category, token]);

  const categories = useMemo(() => {
    const set = new Set<string>();
    for (const it of items) {
      const c = (it.category || "").trim();
      if (c) set.add(c);
    }
    return ["All", ...Array.from(set).sort((a, b) => a.localeCompare(b))];
  }, [items]);

  return (
    <UserShell title="Marketplace" subtitle="Templates, assets, and inspiration">
      {/* Immersive background decoration */}
      <div className="pointer-events-none absolute inset-0 overflow-hidden">
        <div className="gf-blob gf-blob-slow absolute -right-24 top-20 h-96 w-96 bg-indigo-500/10 opacity-20" />
        <div className="gf-blob gf-blob-fast absolute -left-20 top-1/2 h-80 w-80 bg-fuchsia-500/10 opacity-20" />
      </div>

      {error ? (
        <div className="relative z-10 mb-6 rounded-2xl border border-red-500/20 bg-red-500/10 px-4 py-3 text-sm text-red-200">
          {error}
        </div>
      ) : null}

      {/* Featured Hero Area */}
      {!loading && items.length > 0 && !q && category === "All" && (
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          className="relative z-10 mb-8 overflow-hidden rounded-[40px] border border-white/10 bg-black/40 shadow-2xl"
        >
          <div className="grid grid-cols-1 gap-0 lg:grid-cols-2">
            <div className="relative h-[300px] lg:h-[420px]">
              <img
                src={normalizeImageUrl(items[0].previewImageUrl || items[0].thumbnailUrl || items[0].imageUrl)}
                alt=""
                className="h-full w-full object-cover"
              />
              <div className="absolute inset-0 bg-gradient-to-t from-black via-black/20 to-transparent lg:bg-gradient-to-r" />
              
              <div className="absolute left-6 top-6 flex flex-wrap gap-2">
                <span className="flex items-center gap-1.5 rounded-full bg-indigo-500 px-3 py-1 text-[10px] font-black uppercase tracking-widest text-white shadow-[0_0_20px_rgba(99,102,241,0.5)]">
                  <TrendingUp size={12} />
                  Trending
                </span>
                <span className="rounded-full bg-white/10 backdrop-blur-md px-3 py-1 text-[10px] font-black uppercase tracking-widest text-white border border-white/10">
                  Top Choice
                </span>
              </div>
            </div>

            <div className="flex flex-col justify-center p-8 lg:p-12">
              <div className="text-[10px] font-black uppercase tracking-[0.4em] text-indigo-400">Featured Template</div>
              <h1 className="gf-chromatic mt-4 text-4xl font-black italic tracking-tighter text-white lg:text-5xl uppercase leading-[0.9]">
                {items[0].name || items[0].title}
              </h1>
              <p className="mt-6 text-sm font-medium leading-relaxed text-zinc-400 lg:text-base max-w-md">
                {items[0].description || "Step into the future of game design with this mastercrafted template. Ready to forge."}
              </p>
              
              <div className="mt-8 flex flex-wrap items-center gap-6">
                <div className="flex items-center gap-3">
                  <div className="h-10 w-10 rounded-full border border-white/10 bg-white/5 flex items-center justify-center text-zinc-300">
                    <Rocket size={18} />
                  </div>
                  <div>
                    <div className="text-[8px] font-black uppercase tracking-widest text-zinc-500 leading-none">Downloads</div>
                    <div className="mt-1 text-sm font-black text-white">{(items[0].downloads ?? 0).toLocaleString()}</div>
                  </div>
                </div>
                <div className="flex items-center gap-3">
                  <div className="h-10 w-10 rounded-full border border-indigo-500/20 bg-indigo-500/10 flex items-center justify-center text-indigo-400 shadow-[0_0_15px_rgba(99,102,241,0.2)]">
                    <Zap size={18} />
                  </div>
                  <div>
                    <div className="text-[8px] font-black uppercase tracking-widest text-zinc-500 leading-none">Status</div>
                    <div className="mt-1 text-sm font-black text-indigo-400">Pro Ready</div>
                  </div>
                </div>
              </div>

              <div className="mt-10">
                <button
                  onClick={() => router.push(`/studio/marketplace/${encodeURIComponent(items[0]._id || items[0].id || "")}`)}
                  className="flex items-center gap-3 rounded-2xl bg-white px-8 py-4 text-sm font-black uppercase tracking-widest text-black transition-all hover:scale-105 hover:bg-zinc-200 active:scale-95"
                >
                  Forging Now
                  <ArrowRight size={18} />
                </button>
              </div>
            </div>
          </div>
        </motion.div>
      )}

      {/* Top 3 Podium Showcase */}
      {!loading && items.length > 2 && !q && category === "All" && (
        <div className="relative z-10 mb-10 overflow-hidden">
          <div className="flex items-center gap-3 mb-6 px-4">
            <Trophy className="text-yellow-400" size={20} />
            <h3 className="text-sm font-black uppercase tracking-[0.3em] text-zinc-400">Nebula Hall of Fame</h3>
          </div>
          
          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            {[0, 1, 2].map((idx) => {
              const t = items[idx];
              const rankColors = [
                "from-yellow-400/20 via-orange-500/10 to-fuchsia-600/5 border-yellow-400/40 text-yellow-400 shadow-yellow-500/20",
                "from-zinc-300/20 via-zinc-400/10 to-indigo-600/5 border-zinc-300/40 text-zinc-300 shadow-zinc-500/20",
                "from-orange-400/20 via-orange-500/10 to-cyan-500/5 border-orange-400/40 text-orange-400 shadow-orange-500/20"
              ];
              const rankIcons = [Trophy, Crown, Medal];
              const Icon = rankIcons[idx];
              
              return (
                <motion.button
                  key={t._id || t.id || idx}
                  whileHover={{ y: -8, scale: 1.02 }}
                  onClick={() => router.push(`/studio/marketplace/${encodeURIComponent(t._id || t.id || "")}`)}
                  className={`group relative overflow-hidden rounded-[32px] border bg-black/40 p-1 transition-all duration-500 ${rankColors[idx]}`}
                >
                  <div className="relative h-40 w-full overflow-hidden rounded-[28px]">
                    <img src={normalizeImageUrl(t.previewImageUrl || t.thumbnailUrl || t.imageUrl)} className="h-full w-full object-cover transition-transform duration-700 group-hover:scale-110" alt="" />
                    <div className="absolute inset-0 bg-gradient-to-t from-black via-transparent to-transparent opacity-80" />
                    <div className="absolute top-4 left-4 flex h-10 w-10 items-center justify-center rounded-2xl bg-black/60 backdrop-blur-md border border-white/10 text-inherit">
                      <Icon size={20} />
                    </div>
                    <div className="absolute top-4 right-4 text-[10px] font-black uppercase tracking-widest opacity-60">Top {idx + 1}</div>
                  </div>
                  
                  <div className="p-5 text-left">
                    <div className="truncate text-lg font-black tracking-tight text-white uppercase italic leading-none">{t.name || t.title}</div>
                    <div className="mt-2 text-[10px] font-black uppercase tracking-[0.2em] text-zinc-500">{t.category} Module</div>
                  </div>
                </motion.button>
              );
            })}
          </div>
        </div>
      )}

      {/* Advanced Filter Ribbon */}
      <div className="relative z-10 flex flex-col gap-6 mb-8">
        <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
          <div className="relative flex-1 sm:max-w-md group">
            <div className={`absolute inset-0 -m-[2px] rounded-[18px] bg-gradient-to-r from-indigo-500 via-fuchsia-500 to-cyan-500 opacity-0 blur-sm transition-opacity duration-500 group-focus-within:opacity-40`} />
            <input
              className="gf-input relative w-full rounded-2xl pl-12 pr-12 py-3.5 text-sm border-white/10 focus:ring-0 transition-all font-medium placeholder:text-zinc-600"
              placeholder="Searching the Nebula hub…"
              value={q}
              onChange={(e) => setQ(e.target.value)}
            />
            <Search size={18} className="absolute left-4 top-1/2 -translate-y-1/2 text-zinc-500 group-focus-within:text-indigo-400 transition-colors" />
            
            <button
              onClick={startVoiceSearch}
              className={`absolute right-3 top-1/2 -translate-y-1/2 h-9 w-9 flex items-center justify-center rounded-xl transition-all
                ${isListening 
                  ? "bg-rose-500 text-white shadow-[0_0_20px_rgba(244,63,94,0.4)] animate-pulse" 
                  : "bg-white/5 text-zinc-500 hover:bg-white/10 hover:text-white border border-white/5"
                }`}
            >
              {isListening ? (
                <motion.div animate={{ scale: [1, 1.2, 1] }} transition={{ repeat: Infinity, duration: 1.5 }}>
                  <MicOff size={16} />
                </motion.div>
              ) : (
                <Mic size={16} />
              )}
              
              {isListening && (
                <div className="absolute inset-x-0 -bottom-12 flex justify-center">
                  <motion.div 
                    initial={{ opacity: 0, y: -10 }}
                    animate={{ opacity: 1, y: 0 }}
                    className="bg-rose-500/90 backdrop-blur-md px-3 py-1 rounded-full text-[10px] font-black uppercase tracking-widest text-white whitespace-nowrap shadow-xl"
                  >
                    Listening...
                  </motion.div>
                </div>
              )}
            </button>
          </div>
          
          <div className="flex items-center gap-2">
            <div className="h-1 w-1 rounded-full bg-indigo-500 animate-pulse" />
            <div className="text-[10px] font-black uppercase tracking-[0.3em] text-zinc-600">
              {loading ? "Syncing..." : `${items.length} Modules Synced`}
            </div>
          </div>
        </div>

        <div className="no-scrollbar flex items-center gap-3 overflow-x-auto pb-4">
          {categories.map((c) => {
            const Icon = CATEGORY_ICONS[c] || Sparkles;
            const isActive = category === c;
            return (
              <button
                key={c}
                onClick={() => setCategory(c)}
                className={`flex shrink-0 items-center gap-2.5 rounded-2xl border px-5 py-2.5 text-[10px] font-black uppercase tracking-[0.2em] transition-all
                  ${isActive 
                    ? "border-indigo-500 bg-indigo-500/10 text-indigo-400 shadow-[0_0_20px_rgba(99,102,241,0.2)]" 
                    : "border-white/5 bg-white/[0.04] text-zinc-500 hover:border-white/10 hover:bg-white/[0.06] hover:text-zinc-300"
                  }`}
              >
                <Icon size={14} className={isActive ? "text-indigo-400" : "text-zinc-600"} />
                {c}
              </button>
            );
          })}
        </div>
      </div>

      <MarketplaceGrid 
        items={items} 
        loading={loading} 
        router={router} 
        category={category} 
        q={q}
      />
    </UserShell>
  );
}

function MarketplaceGrid({ items, loading, router, category, q }: { items: Template[], loading: boolean, router: any, category: string, q: string }) {
  const container = {
    hidden: { opacity: 0 },
    show: {
      opacity: 1,
      transition: {
        staggerChildren: 0.08
      }
    }
  };

  const itemAnim = {
    hidden: { opacity: 0, y: 20 },
    show: { opacity: 1, y: 0 }
  };

  return (
    <motion.div
      variants={container}
      initial="hidden"
      animate="show"
      className="relative z-10 mt-6 grid grid-cols-1 gap-6 md:grid-cols-2 xl:grid-cols-3"
    >
      {loading ? (
        Array.from({ length: 6 }).map((_, i) => (
          <div key={i} className="gf-card overflow-hidden rounded-[32px] border border-white/10">
            <div className="h-56 w-full bg-white/5" />
            <div className="p-6">
              <div className="h-6 w-36 rounded bg-white/10" />
              <div className="mt-4 h-4 w-52 rounded bg-white/10" />
            </div>
          </div>
        ))
      ) : items.length === 0 ? (
        <div className="gf-panel rounded-[32px] p-12 text-center md:col-span-2 xl:col-span-3">
          <div className="mx-auto flex h-16 w-16 items-center justify-center rounded-2xl bg-white/5 text-zinc-600">
            <Search size={32} />
          </div>
          <div className="mt-6 text-xl font-black text-white uppercase italic tracking-tighter">Nebula Hub Empty</div>
          <div className="mt-2 text-xs text-zinc-500 font-medium tracking-widest uppercase">Try adjusting your spectral filters.</div>
        </div>
      ) : (
        items.map((t, idx) => {
          const id = (t._id || t.id || "").toString();
          const title = (t.name || t.title || "Template").toString();
          const desc = (t.description || "—").toString();
          const img = normalizeImageUrl(t.previewImageUrl || t.thumbnailUrl || t.imageUrl);
          const price = t.price ?? t.priceUsd;
          const downloads = toNum(t.downloads ?? t.downloadCount);
          const isHot = downloads > 1000;
          
          // Check for dev status based on backend owner role or specific owner
          const isDev = t.isDev || t.ownerRole === "admin" || t.ownerRole === "developer";
          
          // Only show ranks in grid IF not displayed in Podium mode or if searching
          const isRankedInGrid = (q.trim() || category !== "All") && idx < 3;
          const rankColors = [
            "from-yellow-400 via-orange-500 to-fuchsia-600 text-white shadow-yellow-500/50 border-yellow-400/50",
            "from-zinc-300 via-zinc-400 to-indigo-600 text-white shadow-indigo-500/50 border-zinc-300/50",
            "from-orange-400 via-orange-500 to-cyan-500 text-white shadow-cyan-500/50 border-orange-400/50"
          ];
          const rankNames = ["#1 Top Pick", "#2 Silver", "#3 Bronze"];
          const RankIcon = [Trophy, Crown, Medal][idx] || Award;

          return (
            <motion.button
              variants={itemAnim}
              layout
              key={id || title}
              onClick={() => (id ? router.push(`/studio/marketplace/${encodeURIComponent(id)}`) : null)}
              className="gf-glass-card group relative flex flex-col overflow-hidden rounded-[32px] border border-white/[0.08] text-left transition-all duration-500 hover:border-indigo-500/40 shadow-2xl"
            >
              <div className="relative h-60 w-full overflow-hidden">
                {img ? (
                  <motion.img 
                    src={img} 
                    alt="" 
                    className="h-full w-full object-cover transition-transform duration-1000 group-hover:scale-110" 
                  />
                ) : (
                  <div className="h-full w-full bg-gradient-to-br from-indigo-500/30 via-fuchsia-500/15 to-cyan-500/10" />
                )}
                
                {/* Visual fine-tuning */}
                <div className="pointer-events-none absolute inset-0 bg-gradient-to-t from-[#0c0d14] via-transparent to-transparent opacity-90" />
                
                {/* Status Badges */}
                <div className="absolute left-4 top-4 flex items-center gap-2">
                  {t.category ? (
                    <span className={`rounded-xl border backdrop-blur-md px-3 py-1.5 text-[8px] font-black uppercase tracking-[0.2em] ${CATEGORY_COLORS[t.category] || "bg-black/40 border-white/10 text-white"}`}>
                      {t.category}
                    </span>
                  ) : null}
                  {isHot && (
                    <motion.span 
                      animate={{ opacity: [0.6, 1, 0.6] }}
                      transition={{ duration: 2, repeat: Infinity }}
                      className="rounded-xl border border-rose-500/40 bg-rose-500/20 px-3 py-1.5 text-[8px] font-black uppercase tracking-[0.2em] text-rose-400 shadow-[0_0_15px_rgba(244,63,94,0.3)]"
                    >
                      Hot
                    </motion.span>
                  )}
                  {isDev && (
                    <span className={`flex items-center gap-1.5 rounded-xl border backdrop-blur-md px-3 py-1.5 text-[8px] font-black uppercase tracking-[0.2em] shadow-lg transition-all ${
                      t.ownerRole === "admin" 
                        ? "border-amber-500/30 bg-amber-500/20 text-amber-400 shadow-amber-500/20" 
                        : "border-cyan-400/30 bg-cyan-400/20 text-cyan-300 shadow-cyan-400/20"
                    }`}>
                      <Code size={12} className={t.ownerRole === "admin" ? "animate-pulse" : "animate-bounce"} />
                      {t.ownerRole === "admin" ? "CORE DEV" : "D E V"}
                    </span>
                  )}
                </div>

                {isRankedInGrid && (
                  <div className="absolute right-4 top-4">
                    <motion.div 
                      initial={{ scale: 0, rotate: -20 }}
                      animate={{ scale: 1, rotate: 0 }}
                      className={`flex items-center gap-2 rounded-2xl bg-gradient-to-br ${rankColors[idx]} px-4 py-2 border-2 shadow-2xl backdrop-blur-md transition-all group-hover:scale-110 group-hover:-rotate-3`}
                    >
                      <RankIcon size={16} className="fill-current" />
                      <span className="text-[10px] font-black uppercase tracking-tighter italic">{rankNames[idx]}</span>
                    </motion.div>
                  </div>
                )}

                <div className={`absolute right-4 top-4 ${isRankedInGrid ? "hidden" : "block"}`}>
                  <motion.div 
                    whileHover={{ scale: 1.1, rotate: 5 }}
                    className="h-10 w-10 rounded-2xl bg-black/40 backdrop-blur-xl border border-white/10 flex items-center justify-center text-white relative overflow-hidden group/pop"
                  >
                    <Award size={18} className="text-zinc-400 group-hover/pop:text-indigo-400 transition-colors" />
                    <div className="absolute inset-0 bg-indigo-500/10 opacity-0 group-hover/pop:opacity-100 transition-opacity" />
                  </motion.div>
                </div>

                {/* Processing Units (Popularity Pulse) */}
                <div className="absolute bottom-4 right-4 flex items-center gap-2 rounded-xl bg-black/60 border border-white/10 backdrop-blur-md px-3 py-1.5">
                  <motion.div 
                    animate={{ scale: [1, 1.2, 1], opacity: [0.5, 1, 0.5] }}
                    transition={{ duration: 1.5, repeat: Infinity }}
                    className="h-1.5 w-1.5 rounded-full bg-emerald-400 shadow-[0_0_10px_#10b981]"
                  />
                  <span className="text-[7px] font-black uppercase tracking-[0.2em] text-zinc-400">
                    <span className="text-white font-mono">{toNum(t.downloads || t.downloadCount || 0) * 12 + 45}</span> P-Units
                  </span>
                </div>

                {/* Neural Glow Overlay */}
                <div className="pointer-events-none absolute inset-0 bg-gradient-radial from-indigo-500/5 via-transparent to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-500" />

                <div className="absolute bottom-6 left-6 right-6">
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-2">
                      <div className="flex h-10 w-10 items-center justify-center rounded-2xl bg-white text-black shadow-2xl">
                        <ArrowRight size={18} />
                      </div>
                      <div className="text-[10px] font-black text-white uppercase tracking-widest opacity-0 group-hover:opacity-100 transition-all translate-x-2 group-hover:translate-x-0">
                        Details
                      </div>
                    </div>
                    
                    {typeof price === "number" && price > 0 ? (
                      <div className="rounded-2xl border border-white/10 bg-black/60 backdrop-blur-md px-4 py-2 text-sm font-black text-white">
                        ${price.toFixed(2)}
                      </div>
                    ) : (
                      <div className="rounded-2xl border border-emerald-500/20 bg-emerald-500/10 backdrop-blur-md px-4 py-2 text-sm font-black text-emerald-400">
                        FREE
                      </div>
                    )}
                  </div>
                </div>
              </div>

              <div className="relative flex-1 p-8">
                <div className="flex items-start justify-between gap-4">
                  <div className="min-w-0">
                    <div className="truncate text-2xl font-black text-white tracking-tighter uppercase italic leading-none">{title}</div>
                    <p className="mt-4 line-clamp-2 text-xs font-medium leading-relaxed text-zinc-500 group-hover:text-zinc-400 transition-colors">
                      {desc}
                    </p>
                  </div>
                </div>
                
                <div className="mt-8 flex items-center justify-between border-t border-white/5 pt-6">
                  <div className="flex flex-col gap-1">
                    <div className="text-[8px] font-black uppercase tracking-widest text-zinc-600 leading-none">Deployment Sync</div>
                    <div className="mt-1 flex items-center gap-2 text-[10px] font-black text-zinc-300 uppercase tracking-widest">
                      <Rocket size={12} className="text-indigo-500/60" />
                      {downloads.toLocaleString()}
                    </div>
                  </div>

                  <div className="flex -space-x-2">
                    {[1, 2, 3].map(i => (
                      <div key={i} className="h-6 w-6 rounded-full border-2 border-zinc-950 bg-zinc-800" />
                    ))}
                    <div className="flex items-center justify-center h-6 w-8 rounded-full border-2 border-zinc-950 bg-white/5 text-[8px] font-black text-zinc-500">
                      +42
                    </div>
                  </div>
                </div>

                {/* Holographic scanning overlay on hover */}
                <div className="absolute inset-x-0 bottom-0 h-1 bg-gradient-to-r from-transparent via-indigo-500 to-transparent opacity-0 group-hover:opacity-100 transition-opacity" />
              </div>

              {/* Hover highlight effect */}
              <div className="absolute inset-0 bg-gradient-to-tr from-indigo-500/0 via-transparent to-white/5 opacity-0 group-hover:opacity-100 transition-opacity duration-700 pointer-events-none" />
            </motion.button>
          );
        })
      )}
    </motion.div>
  );
}
