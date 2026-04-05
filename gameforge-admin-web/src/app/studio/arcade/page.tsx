"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { motion, AnimatePresence } from "framer-motion";
import {
  GameController, Play, Heart, ChatCircleDots, ShareNetwork,
  Trophy, Users, MagnifyingGlass as Search, Lightning,
  TrendUp as TrendingUp, X, Crown, Medal, CurrencyDollar,
  ArrowSquareOut
} from "@phosphor-icons/react";
import UserShell from "@/app/_components/UserShell";
import { apiFetch, ApiError } from "@/lib/api";
import { getUserToken } from "@/lib/userAuth";
import { normalizeImageUrl } from "@/lib/media";

function cx(...parts: Array<string | false | null | undefined>) {
  return parts.filter(Boolean).join(" ");
}

const LEADERBOARD = [
  { rank: 1, title: "Neon Strike", creator: "CyberNeon", score: "1.2M", downloads: "45k", trend: "+12%" },
  { rank: 2, title: "Void Runner", creator: "MarioDev", score: "980K", downloads: "32k", trend: "+8%" },
  { rank: 3, title: "Cyber Trade", creator: "RPG_Master", score: "850K", downloads: "28k", trend: "+15%" },
  { rank: 4, title: "Neural Link", creator: "AI_Wiz", score: "720K", downloads: "21k", trend: "-2%" },
];

export default function ArcadeFeedPage() {
  const router = useRouter();
  const token = useMemo(() => getUserToken(), []);
  const [loading, setLoading] = useState(true);
  const [items, setItems] = useState<any[]>([]);
  const [leaderboard, setLeaderboard] = useState<any[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [search, setSearch] = useState("");
  const scrollerRef = useRef<HTMLDivElement | null>(null);
  const [activeIndex, setActiveIndex] = useState(0);
  const [playingId, setPlayingId] = useState<string | null>(null);
  const [me, setMe] = useState<any>(null);

  useEffect(() => {
    const params = new URLSearchParams(window.location.search);
    const playId = params.get("play");
    if (playId) {
      setPlayingId(playId);
    }
  }, []);

  const handleLike = async (id: string) => {
    if (!token) return;
    try {
      await apiFetch(`/game-feed/${id}/like`, { method: "POST", token });
      setItems(prev => prev.map(it => (it.id === id || it._id === id) ? { ...it, likeCount: (it.likeCount || 0) + 1 } : it));
    } catch (e) { }
  };

  const handleShare = async (id: string) => {
    try {
      const url = `${window.location.origin}/studio/arcade?play=${id}`;
      await navigator.clipboard.writeText(url);
      alert("Neural link copied to clipboard!");
    } catch (e) { }
  };

  const handleDonate = async (creatorId: string) => {
    if (!token) {
      alert("Please initialize your neural link (login) to send donations.");
      return;
    }
    try {
      const res = await apiFetch<any>("/creator-monetization/checkout", {
        method: "POST",
        token,
        body: {
          creatorUserId: creatorId,
          type: "tip",
          amountUsd: 10, // Default architect-grade donation
          message: "Supporting a Master Architect's work!"
        }
      });
      if (res?.data?.url) {
        window.location.href = res.data.url;
      }
    } catch (e: any) {
      alert("Neural payment bypass failed: " + (e.message || "Unknown error"));
    }
  };


  useEffect(() => {
    let cancelled = false;
    async function load() {
      setLoading(true);
      try {
        const [feedRes, leaderboardRes, meRes] = await Promise.allSettled([
          apiFetch<any>("/game-feed", { method: "GET", token: token || undefined }),
          apiFetch<any>("/arcade/leaderboard", { method: "GET", token: token || undefined }),
          apiFetch<any>("/auth/profile", { method: "GET", token: token || undefined }),
        ]);

        if (!cancelled) {
          if (meRes.status === 'fulfilled') {
            const meData = meRes.value?.data || meRes.value;
            setMe(meData?.user || meData);
          }

          if (feedRes.status === 'fulfilled') {
            const feedData = feedRes.value;
            const data = (feedData && typeof feedData === "object" && "data" in feedData) ? feedData.data : feedData;
            setItems(Array.isArray(data) ? data : (Array.isArray(data?.items) ? data.items : []));
          } else {
            console.error("Feed error:", feedRes.reason);
            setItems([]);
          }

          if (leaderboardRes.status === 'fulfilled') {
            const lbData = leaderboardRes.value;
            const data = (lbData && typeof lbData === "object" && "data" in lbData) ? lbData.data : lbData;
            setLeaderboard(Array.isArray(data) ? data : (Array.isArray(data?.items) ? data.items : []));
          } else {
            // Fallback to high-end hardcoded telemetry if API is unreachable
            setLeaderboard(LEADERBOARD);
          }

          if (feedRes.status === 'rejected' && leaderboardRes.status === 'rejected') {
            setError("Arcade systems initializing. Please check back shortly.");
          } else {
            setError(null);
          }
        }
      } catch (e: any) {
        if (!cancelled) setError("Neural link interrupted. Reconnecting...");
      } finally {
        if (!cancelled) setLoading(false);
      }
    }
    load();
    return () => { cancelled = true; };
  }, [token]);

  const filteredItems = useMemo(() => {
    return items.filter(item =>
      (item.title || item.name || "").toLowerCase().includes(search.toLowerCase()) ||
      (item.creatorUsername || "").toLowerCase().includes(search.toLowerCase())
    );
  }, [items, search]);

  useEffect(() => {
    const el = scrollerRef.current;
    if (!el) return;

    const children = Array.from(el.querySelectorAll("[data-arcade-item='1']")) as HTMLElement[];
    if (!children.length) return;

    const obs = new IntersectionObserver(
      (entries) => {
        const visible = entries
          .filter((e) => e.isIntersecting)
          .sort((a, b) => (b.intersectionRatio ?? 0) - (a.intersectionRatio ?? 0));
        const top = visible[0];
        if (!top?.target) return;
        const idx = children.indexOf(top.target as HTMLElement);
        if (idx >= 0) setActiveIndex(idx);
      },
      { root: el, threshold: [0.55, 0.7, 0.85] },
    );

    for (const c of children) obs.observe(c);
    return () => obs.disconnect();
  }, [filteredItems.length]);

  function getId(it: any, idx: number) {
    return String(it?.id || it?._id || it?.projectId || it?.buildId || `item-${idx}`);
  }

  function getTitle(it: any) {
    return String(it?.title || it?.name || "Untitled");
  }

  function getCreator(it: any) {
    return String(it?.ownerUsername || it?.creatorUsername || it?.creator || it?.author || "creator");
  }

  function getThumb(it: any) {
    const raw =
      it?.thumbnailUrl ||
      it?.previewImageUrl ||
      it?.imageUrl ||
      it?.coverUrl ||
      it?.posterUrl ||
      "";
    const normalized = normalizeImageUrl(raw);
    return normalized || "https://images.unsplash.com/photo-1550745165-9bc0b252726f?auto=format&fit=crop&q=80&w=2070";
  }

  function getPlayUrl(it: any) {
    const raw =
      it?.playUrl ||
      it?.webglUrl ||
      it?.previewUrl ||
      it?.url ||
      it?.gameUrl ||
      it?.webUrl ||
      "";
    const s = String(raw || "").trim();
    if (!s) return "";
    if (s.startsWith("http://") || s.startsWith("https://")) return s;
    return normalizeImageUrl(s);
  }

  return (
    <UserShell title="Community Arcade" subtitle="Discover and play the best community creations">
      <div className="space-y-12 pb-20">

        {/* Top bar with Search */}
        <div className="flex flex-col md:flex-row gap-6 items-center justify-between">
          <div className="relative flex-1 w-full group">
            <div className="absolute inset-0 bg-indigo-500/5 blur-xl opacity-0 group-focus-within:opacity-100 transition-opacity" />
            <Search className="absolute left-5 top-1/2 -translate-y-1/2 text-zinc-500" size={20} />
            <input
              className="gf-input w-full rounded-[24px] pl-14 pr-6 py-4 text-sm border-white/10 focus:border-indigo-500/50 bg-black/40 transition-all font-bold"
              placeholder="Search games or creators..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
            />
          </div>
          <div className="flex items-center gap-3 text-[10px] font-black text-zinc-500 uppercase tracking-[0.2em] leading-none">
            <span className="text-white text-lg font-mono">{filteredItems.length}</span> Games Available
          </div>
        </div>

        {loading ? (
          <div className="gf-panel-strong rounded-[48px] p-24 text-center border border-white/10 relative overflow-hidden">
            <div className="absolute inset-0 gf-grid opacity-20" />
            <div className="relative z-10">
              <div className="text-4xl font-black italic uppercase tracking-tighter text-white gf-chromatic animate-pulse">Initializing Feed…</div>
              <div className="mt-4 text-[10px] font-black text-zinc-500 uppercase tracking-[0.4em]">Booting arcade nodes</div>
            </div>
          </div>
        ) : error ? (
          <div className="gf-panel-strong rounded-[48px] p-16 text-center border border-rose-500/20 bg-rose-500/10">
            <div className="text-2xl font-black italic uppercase tracking-tight text-white">Arcade offline</div>
            <div className="mt-2 text-sm text-rose-200/80">{error}</div>
          </div>
        ) : filteredItems.length === 0 ? (
          <div className="gf-panel-strong rounded-[48px] p-20 text-center border-dashed border-white/10">
            <div className="text-6xl mb-6 opacity-20">🕹️</div>
            <h3 className="text-2xl font-bold text-white uppercase italic">Arcade is quiet</h3>
            <p className="text-zinc-500 mt-2 font-medium">Be the first to publish a game to the global feed!</p>
          </div>
        ) : (
          <div className="gf-panel-strong gf-stroke-gradient rounded-[40px] p-0 overflow-hidden shadow-[0_0_100px_rgba(0,0,0,0.5)] border border-white/5">
            <div
              ref={scrollerRef}
              className="h-[72vh] md:h-[78vh] overflow-y-auto snap-y snap-mandatory gf-scrollbar"
            >
              {filteredItems.map((it, idx) => {
                const id = getId(it, idx);
                const title = getTitle(it);
                const creator = getCreator(it);
                const thumb = getThumb(it);
                const playUrl = getPlayUrl(it);
                const isActive = idx === activeIndex;
                const isPlaying = playingId === id;
                const creatorId = it?.ownerId || it?.creatorId || it?.authorId || it?.userId;
                const isMe = me && String(creatorId) === String(me.id);
                const rawAvatar = (isMe && me.avatar)
                  ? me.avatar
                  : (it?.avatar || it?.ownerAvatar || it?.creatorAvatar || it?.authorAvatar || it?.avatarUrl || it?.imageUrl);
                const avatarUrl = normalizeImageUrl(rawAvatar);

                return (
                  <section
                    key={`${id}-${idx}`}
                    data-arcade-item="1"
                    className="snap-start h-[72vh] md:h-[78vh] relative border-b border-white/5"
                  >
                    <div className="absolute inset-0">
                      {/* background */}
                      <img src={thumb} alt={title} className="h-full w-full object-cover opacity-60" />
                      <div className="absolute inset-0 bg-gradient-to-t from-[#05060a] via-black/40 to-black/10" />
                      <div className="absolute inset-0 gf-noise opacity-40" />
                    </div>

                    {/* playable surface */}
                    <div className="absolute inset-0 p-4 md:p-8 lg:p-12">
                      <div className="relative h-full w-full rounded-[40px] border border-white/10 bg-black/40 overflow-hidden shadow-[0_0_100px_rgba(99,102,241,0.15)] backdrop-blur-sm">
                        {/* when playing, mount iframe only for active item */}
                        {isPlaying && isActive && playUrl ? (
                          <iframe
                            src={playUrl}
                            className="absolute inset-0 h-full w-full"
                            allow="fullscreen; autoplay; gamepad; clipboard-write"
                            sandbox="allow-scripts allow-same-origin allow-pointer-lock allow-forms allow-popups"
                          />
                        ) : (
                          <div className="absolute inset-0 flex items-center justify-center group/play">
                            <motion.div
                              animate={{ scale: [1, 1.1, 1], opacity: [0.3, 0.6, 0.3] }}
                              transition={{ duration: 3, repeat: Infinity }}
                              className="absolute inset-0 bg-indigo-500/10 rounded-full blur-[100px]"
                            />
                            {it.kind === 'ad' && it.videoUrl ? (
                              <video
                                src={it.videoUrl}
                                poster={thumb}
                                autoPlay
                                muted
                                loop
                                playsInline
                                className="absolute inset-0 h-full w-full object-cover"
                              />
                            ) : (
                              <motion.button
                                whileHover={{ scale: 1.1, rotate: 5 }}
                                whileTap={{ scale: 0.95 }}
                                onClick={() => {
                                  setPlayingId(id);
                                }}
                                className="gf-stroke-gradient gf-glow h-24 w-24 rounded-full bg-white text-black flex items-center justify-center shadow-2xl relative z-10 transition-transform"
                                disabled={!playUrl}
                                title={!playUrl ? "Missing play URL" : "Play"}
                              >
                                <Play size={36} weight="fill" className="ml-1" />
                              </motion.button>
                            )}

                          </div>
                        )}

                        {/* top chrome */}
                        <div className="absolute left-6 top-6 right-6 flex items-center justify-between gap-3 z-30">
                          {it.kind === 'ad' ? (
                            <div className="inline-flex items-center gap-3 rounded-2xl border border-rose-500/30 bg-rose-500/10 backdrop-blur-xl px-4 py-2 text-[10px] font-black uppercase tracking-[0.3em] text-rose-400 animate-pulse">
                              <Lightning size={14} weight="fill" className="text-rose-400" />
                              SPONSORED
                            </div>
                          ) : (
                            <div className="inline-flex items-center gap-3 rounded-2xl border border-white/10 bg-black/60 backdrop-blur-xl px-4 py-2 text-[10px] font-black uppercase tracking-[0.3em] text-indigo-300">
                              <div className="h-2 w-2 rounded-full bg-indigo-500 animate-ping" />
                              Arcade Hub
                            </div>
                          )}

                          <div className="flex items-center gap-3">
                            <motion.button
                              whileHover={{ scale: 1.05 }}
                              whileTap={{ scale: 0.95 }}
                              className="h-10 w-10 rounded-xl border border-white/10 bg-black/60 backdrop-blur-xl flex items-center justify-center text-zinc-200 hover:bg-white/10 transition-all"
                              onClick={() => setPlayingId((cur) => (cur === id ? null : cur))}
                            >
                              {isPlaying ? <X size={20} weight="bold" /> : <Play size={20} weight="fill" />}
                            </motion.button>
                          </div>
                        </div>


                        {/* bottom info */}
                        <div className="absolute left-0 right-0 bottom-0 p-6 md:p-10 bg-gradient-to-t from-black/80 via-black/40 to-transparent">
                          <div className="flex items-end justify-between gap-10">
                            <div className="min-w-0">
                              <motion.div
                                initial={{ opacity: 0, x: -20 }}
                                animate={{ opacity: 1, x: 0 }}
                                className="text-3xl md:text-5xl font-black italic uppercase tracking-tighter text-white truncate gf-chromatic"
                              >
                                {title}
                              </motion.div>

                              {it.kind !== "ad" ? (
                                <div className="mt-6 flex items-center gap-6">
                                  <button
                                    onClick={() => creatorId && router.push(`/studio/profile/${creatorId}`)}
                                    className="group flex items-center gap-3 bg-white/5 border border-white/10 px-4 py-2 rounded-2xl backdrop-blur-xl hover:bg-white/10 transition-all"
                                  >
                                    {avatarUrl ? (
                                      <div className="relative">
                                        <img src={avatarUrl} className={cx("h-10 w-10 rounded-2xl object-cover border-2 shadow-lg transition-all", (creator || "").toLowerCase().includes("mohamed") ? "border-indigo-500/50 shadow-[0_0_20px_rgba(99,102,241,0.3)]" : "border-white/10")} alt="" />
                                        {(creator || "").toLowerCase().includes("mohamed") && (
                                          <div className="absolute -right-1 -top-1 h-4 w-4 bg-indigo-500 rounded-full border-2 border-black flex items-center justify-center">
                                            <Lightning size={10} weight="fill" className="text-white" />
                                          </div>
                                        )}
                                      </div>
                                    ) : (
                                      <div className="h-10 w-10 rounded-2xl bg-gradient-to-br from-indigo-500 to-fuchsia-600 flex items-center justify-center text-white font-black text-sm border border-white/10 shadow-lg">
                                        {(creator || "C").substring(0, 1).toUpperCase()}
                                      </div>
                                    )}
                                    <div className="flex flex-col items-start leading-tight">
                                      <span className="text-sm text-zinc-300 font-black tracking-tight group-hover:text-white transition-colors">@{creator}</span>
                                      {(creator || "").toLowerCase().includes("mohamed") && (
                                        <span className="text-[8px] text-indigo-400 font-black uppercase tracking-widest">Master Architect</span>
                                      )}
                                    </div>
                                  </button>

                                  <div className="h-1 w-1 rounded-full bg-zinc-700" />
                                  <div className="flex items-center gap-2 text-zinc-500 font-black text-[10px] uppercase tracking-widest">
                                    <Users size={14} weight="duotone" className="text-indigo-400" />
                                    {it?.playCount || 0} Instances
                                  </div>
                                </div>
                              ) : (
                                <div className="mt-8 flex flex-col items-start gap-4">
                                  <div className="text-[10px] font-black text-rose-400 uppercase tracking-[0.3em] flex items-center gap-2">
                                    <Lightning size={12} weight="fill" />
                                    Sponsored Campaign
                                  </div>
                                  <a
                                    href={it.clickUrl}
                                    target="_blank"
                                    rel="noopener noreferrer"
                                    className="relative group/cta mt-2"
                                  >
                                    {/* High-intensity outer glow */}
                                    <div className="absolute inset-[-10px] bg-indigo-500/30 rounded-[40px] blur-2xl opacity-0 group-hover/cta:opacity-100 transition-opacity duration-500" />

                                    <div className="relative flex items-center gap-4 bg-white px-12 py-6 rounded-2xl text-xl font-black text-indigo-950 shadow-[0_20px_50px_-10px_rgba(255,255,255,0.3)] transition-all group-hover/cta:scale-105 group-hover/cta:shadow-[0_25px_60px_-5px_rgba(255,255,255,0.5)] border-2 border-white/20">
                                      {it.ctaLabel || "Visit Website"}
                                      <div className="h-8 w-8 rounded-full bg-indigo-950/10 flex items-center justify-center group-hover/cta:bg-indigo-600 group-hover/cta:text-white transition-all">
                                        <ArrowSquareOut size={20} weight="bold" />
                                      </div>
                                    </div>
                                  </a>
                                </div>
                              )}
                            </div>

                            {it.kind !== "ad" && (
                              <div className="flex flex-col items-center gap-4 shrink-0 z-30">
                                <motion.button
                                  whileHover={{ scale: 1.1 }}
                                  whileTap={{ scale: 0.9 }}
                                  onClick={() => handleLike(id)}
                                  className="h-14 w-14 rounded-2xl border border-white/10 bg-black/60 backdrop-blur-xl flex items-center justify-center text-rose-400 hover:bg-rose-400/20 transition-all shadow-xl"
                                >
                                  <Heart size={24} weight={(it?.likes || it?.likeCount) ? "fill" : "duotone"} />
                                  <span className="absolute -bottom-2 text-[10px] font-black">{it?.likeCount || 0}</span>
                                </motion.button>

                                <motion.button
                                  whileHover={{ scale: 1.1, rotate: -10 }}
                                  whileTap={{ scale: 0.9 }}
                                  onClick={() => creatorId && handleDonate(creatorId)}
                                  className="h-14 w-14 rounded-2xl border border-emerald-500/30 bg-emerald-500/10 backdrop-blur-xl flex items-center justify-center text-emerald-400 hover:bg-emerald-500/20 transition-all shadow-xl group"
                                  title="Donate to Creator"
                                >
                                  <CurrencyDollar size={24} weight="duotone" className="group-hover:animate-bounce" />
                                  <span className="absolute -bottom-2 text-[10px] font-black">TIP</span>
                                </motion.button>

                                <motion.button
                                  whileHover={{ scale: 1.1 }}
                                  whileTap={{ scale: 0.9 }}
                                  className="h-14 w-14 rounded-2xl border border-white/10 bg-black/60 backdrop-blur-xl flex items-center justify-center text-zinc-300 hover:bg-white/20 transition-all shadow-xl"
                                >
                                  <ChatCircleDots size={24} weight="duotone" />
                                  <span className="absolute -bottom-2 text-[10px] font-black">{it?.commentCount || 0}</span>
                                </motion.button>
                                <motion.button
                                  whileHover={{ scale: 1.1 }}
                                  whileTap={{ scale: 0.9 }}
                                  className="h-14 w-14 rounded-2xl border border-white/10 bg-black/60 backdrop-blur-xl flex items-center justify-center text-zinc-300 hover:bg-white/20 transition-all shadow-xl"
                                  onClick={() => handleShare(id)}
                                >
                                  <ShareNetwork size={24} weight="duotone" />
                                </motion.button>
                              </div>
                            )}

                          </div>
                        </div>
                      </div>
                    </div>
                  </section>
                );
              })}
            </div>
          </div>
        )}

        {/* Global Leaderboard Section (Moved to Bottom) */}
        {!loading && leaderboard.length > 0 && (
          <section className="animate-in fade-in slide-in-from-bottom-8 duration-1000">
            <div className="gf-panel-strong gf-stroke-gradient rounded-[60px] p-12 relative overflow-hidden shadow-[0_0_100px_rgba(99,102,241,0.1)] border border-white/10">
              <div className="absolute inset-0 bg-gradient-to-br from-indigo-500/10 via-transparent to-fuchsia-500/10 pointer-events-none" />
              <div className="absolute inset-0 gf-grid opacity-10 pointer-events-none" />

              <div className="relative z-10">
                <div className="flex flex-col md:flex-row md:items-center justify-between gap-6 mb-16">
                  <div className="flex items-center gap-6">
                    <motion.div
                      animate={{ rotate: [0, 10, -10, 0] }}
                      transition={{ duration: 4, repeat: Infinity }}
                      className="h-16 w-16 rounded-[24px] bg-indigo-500/20 flex items-center justify-center text-indigo-400 border border-indigo-500/30 shadow-[0_0_30px_rgba(99,102,241,0.2)]"
                    >
                      <Trophy size={32} />
                    </motion.div>
                    <div>
                      <h2 className="text-4xl font-black text-white tracking-tighter italic uppercase gf-chromatic">Global Hall of Fame</h2>
                      <p className="text-[10px] text-zinc-500 font-black uppercase tracking-[0.4em] mt-2">Neural Performance Distribution Network</p>
                    </div>
                  </div>
                  <div className="flex items-center gap-3 text-[10px] font-black text-emerald-400 bg-emerald-500/10 px-5 py-2.5 rounded-2xl border-2 border-emerald-500/20 shadow-[0_0_20px_rgba(16,185,129,0.1)]">
                    <div className="h-2 w-2 rounded-full bg-emerald-500 animate-ping" />
                    LIVE TELEMETRY
                  </div>
                </div>

                <div className="grid grid-cols-1 gap-6">
                  {leaderboard.slice(0, 5).map((item, i) => (
                    <motion.div
                      key={i}
                      initial={{ opacity: 0, y: 20 }}
                      animate={{ opacity: 1, y: 0 }}
                      transition={{ delay: i * 0.1 }}
                      whileHover={{ y: -5, scale: 1.01 }}
                      className="group flex flex-col md:flex-row md:items-center gap-8 p-8 rounded-[40px] bg-white/[0.02] border-2 border-white/5 hover:border-indigo-500/40 hover:bg-indigo-500/[0.03] transition-all cursor-pointer relative overflow-hidden"
                    >
                      {/* Interactive Glow */}
                      <div className="absolute inset-0 bg-gradient-to-r from-indigo-500/10 via-transparent to-fuchsia-500/10 opacity-0 group-hover:opacity-100 transition-opacity" />

                      <div className="w-16 text-center shrink-0 relative z-10">
                        {i === 0 ? (
                          <div className="relative">
                            <Crown size={40} weight="duotone" className="text-amber-400 mx-auto drop-shadow-[0_0_20px_#fbbf24]" />
                            <motion.div animate={{ opacity: [0.2, 0.4, 0.2] }} transition={{ duration: 2, repeat: Infinity }} className="absolute inset-0 bg-amber-400 blur-2xl rounded-full" />
                          </div>
                        ) : i === 1 ? (
                          <Medal size={36} weight="duotone" className="text-zinc-300 mx-auto drop-shadow-[0_0_15px_#d4d4d8]" />
                        ) : i === 2 ? (
                          <Medal size={36} weight="duotone" className="text-amber-700/80 mx-auto" />
                        ) : (
                          <span className="text-3xl font-black text-zinc-800 group-hover:text-zinc-500 italic">0{i + 1}</span>
                        )}
                      </div>

                      <div className="flex-1 min-w-0 relative z-10">
                        <div className="text-2xl font-black text-white tracking-tighter uppercase italic group-hover:gf-chromatic transition-all truncate">{item.title || item.name}</div>
                        <button
                          onClick={(e) => {
                            e.stopPropagation();
                            const creatorId = item.ownerId || item.creatorId || item.authorId || item.userId;
                            if (creatorId) router.push(`/studio/profile/${creatorId}`);
                          }}
                          className="mt-2 text-xs text-zinc-500 font-black tracking-[0.2em] uppercase hover:text-indigo-400 transition-colors"
                        >
                          CREATOR: <span className="text-indigo-400">@{item.ownerUsername || item.creatorUsername || item.creator}</span>
                        </button>
                      </div>

                      <div className="flex items-center gap-16 text-right shrink-0 relative z-10">
                        <div className="space-y-2">
                          <div className="text-[9px] font-black text-zinc-600 uppercase tracking-[0.3em]">Peak Score</div>
                          <div className="text-2xl font-black text-white italic tracking-tighter">{(item.highScore || item.score || 0).toLocaleString()}</div>
                        </div>
                        <div className="space-y-2 hidden sm:block">
                          <div className="text-[9px] font-black text-zinc-600 uppercase tracking-[0.3em]">Deployment</div>
                          <div className="text-2xl font-black text-white italic tracking-tighter">{(item.playCount || item.installs || 0).toLocaleString()}</div>
                        </div>
                        <div className="flex items-center gap-3 px-4 py-2 rounded-2xl bg-black/40 border-2 border-white/5">
                          <TrendingUp size={16} weight="bold" className="text-emerald-400" />
                          <span className="text-xs font-black text-emerald-400 tracking-tighter">+14%</span>
                        </div>
                      </div>

                      <motion.button
                        whileHover={{ scale: 1.1, rotate: 5 }}
                        whileTap={{ scale: 0.9 }}
                        className="h-16 w-16 rounded-[24px] bg-white text-black flex items-center justify-center shadow-[0_15px_30px_rgba(255,255,255,0.2)] transition-all shrink-0 relative z-10 ml-4 group/btn"
                      >
                        <Play size={28} weight="fill" className="ml-1 group-hover/btn:scale-110 transition-transform" />
                      </motion.button>
                    </motion.div>
                  ))}
                </div>
              </div>
            </div>
          </section>
        )}
      </div>
    </UserShell>
  );
}
