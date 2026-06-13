"use client";

import { useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { motion } from "framer-motion";
import { Radio, Users, Sparkles } from "lucide-react";
import UserShell from "@/app/_components/UserShell";

type LiveSession = {
  roomName: string;
  creatorIdentity: string;
  creatorName: string;
  creatorAvatarUrl?: string;
  gameTitle?: string;
  thumbUrl?: string;
  startedAt: number;
  tags?: string[];
};

function cx(...parts: Array<string | false | null | undefined>) {
  return parts.filter(Boolean).join(" ");
}

export default function LiveFeedPage() {
  const [items, setItems] = useState<LiveSession[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let cancelled = false;
    async function load() {
      setLoading(true);
      try {
        const r = await fetch("/api/live-sessions", { method: "GET" });
        const j = (await r.json().catch(() => null)) as any;
        const list = Array.isArray(j?.data) ? (j.data as LiveSession[]) : [];
        if (!cancelled) setItems(list);
      } catch {
        if (!cancelled) setItems([]);
      } finally {
        if (!cancelled) setLoading(false);
      }
    }

    load();
    const t = setInterval(load, 4000);
    return () => {
      cancelled = true;
      clearInterval(t);
    };
  }, []);

  const total = items.length;

  return (
    <UserShell title="Live Now" subtitle="Join creators who are currently streaming">
      <div className="space-y-5">
        <div className="relative rounded-[32px] p-8 overflow-hidden bg-[var(--gf-panel-bg-strong)] border border-white/5 shadow-2xl">
          {/* Animated Blob Background */}
          <div className="absolute top-0 right-0 w-[400px] h-[400px] bg-emerald-500/20 blur-[100px] rounded-full mix-blend-screen translate-x-1/2 -translate-y-1/2 animate-pulse" />
          <div className="absolute bottom-0 left-0 w-[400px] h-[400px] bg-blue-500/10 blur-[100px] rounded-full mix-blend-screen -translate-x-1/3 translate-y-1/3" />

          <div className="relative z-10 flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
            <div>
              <div className="inline-flex items-center gap-2 rounded-full border border-emerald-500/30 bg-emerald-500/10 backdrop-blur-md px-4 py-1.5 text-xs font-bold uppercase tracking-widest text-emerald-300 shadow-[0_0_20px_rgba(52,211,153,0.15)]">
                <Radio size={14} className="animate-pulse" />
                Live Directory
              </div>
              <h1 className="mt-4 text-4xl sm:text-5xl font-black tracking-tight text-[var(--foreground)] drop-shadow-sm">
                {loading ? "Scanning…" : `${total} Creators Live`}
              </h1>
              <p className="mt-2 text-sm sm:text-base font-medium text-zinc-400 max-w-xl leading-relaxed">
                Join our community of creators. Tap on any card below to watch their stream in real-time with picture-in-picture mode.
              </p>
            </div>

            <div className="flex items-center gap-2 rounded-2xl border border-white/5 bg-white/[0.03] backdrop-blur-md px-4 py-3 text-sm font-semibold text-zinc-300 shadow-xl">
              <Sparkles size={16} className="text-cyan-400 drop-shadow-[0_0_8px_rgba(232,121,249,0.5)] animate-pulse" />
              Updates automatically
            </div>
          </div>
        </div>

        {loading ? (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5">
            {Array.from({ length: 3 }).map((_, i) => (
              <div key={i} className="gf-panel-strong rounded-[24px] h-[240px] animate-pulse" />
            ))}
          </div>
        ) : items.length === 0 ? (
          <div className="gf-panel-strong rounded-[28px] p-12 text-center border border-dashed border-white/10">
            <div className="text-2xl font-black italic uppercase text-[var(--foreground)]">Nobody is live yet</div>
            <div className="mt-2 text-sm text-zinc-500">Start a stream from Studio → Live</div>
          </div>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5">
            {items.map((s, i) => (
              <motion.div
                key={s.roomName}
                initial={{ opacity: 0, scale: 0.95, y: 20 }}
                animate={{ opacity: 1, scale: 1, y: 0 }}
                transition={{ duration: 0.5, delay: 0.05 * i, ease: [0.23, 1, 0.32, 1] }}
                className="group relative h-[300px] rounded-[32px] p-[2px] overflow-hidden hover:-translate-y-2 transition-transform duration-500 shadow-2xl hover:shadow-[0_0_80px_rgba(16,185,129,0.2)]"
              >
                {/* Spinning Gradient Border */}
                <div className="absolute inset-x-[-50%] inset-y-[-50%] w-[200%] h-[200%] bg-[conic-gradient(from_0deg,transparent_0_310deg,#34d399_330deg,#8b5cf6_360deg)] animate-[spin_4s_linear_infinite] opacity-30 group-hover:opacity-100 transition-opacity duration-500" />

                <Link href={`/live/${encodeURIComponent(s.roomName)}`} className="relative block w-full h-full rounded-[30px] overflow-hidden bg-[var(--gf-shell-bg)]">
                  {/* Thumbnail Image */}
                  <div
                    className="absolute inset-0 transition-all duration-700 ease-out group-hover:scale-110 opacity-70 group-hover:opacity-90"
                    style={{
                      backgroundImage: s.thumbUrl
                        ? `url(${s.thumbUrl})`
                        : "radial-gradient(circle at center, rgba(99,102,241,0.25), transparent 70%), radial-gradient(circle at bottom left, rgba(236,72,153,0.15), transparent 70%)",
                      backgroundSize: "cover",
                      backgroundPosition: "center",
                    }}
                  />
                  {/* Glassmorphism gradient overlays */}
                  <div className="absolute inset-0 bg-gradient-to-b from-black/50 via-transparent to-black/95 pointer-events-none" />
                  <div className="absolute inset-0 bg-[radial-gradient(circle_at_top_right,rgba(52,211,153,0.15),transparent_50%)] opacity-0 group-hover:opacity-100 transition-opacity duration-700 pointer-events-none" />

                  {/* Top Badges */}
                  <div className="absolute left-5 top-5 flex flex-wrap items-center gap-2 pr-16 z-10 transition-transform duration-500 group-hover:-translate-y-1">
                    <div className="flex items-center gap-1.5 rounded-full bg-red-600/90 backdrop-blur-xl px-3 py-1 text-[11px] font-black uppercase tracking-widest text-white shadow-[0_0_20px_rgba(220,38,38,0.5)] border border-white/20">
                      <span className="h-1.5 w-1.5 animate-pulse rounded-full bg-white shadow-[0_0_10px_white]" />
                      LIVE
                    </div>
                    {s.gameTitle && (
                      <div className="rounded-full bg-white/10 backdrop-blur-xl px-3 py-1 text-[11px] font-bold tracking-wide text-zinc-100 border border-white/20 truncate max-w-[140px] shadow-lg">
                        {s.gameTitle}
                      </div>
                    )}
                  </div>

                  <div className="absolute right-5 top-5 flex items-center gap-1.5 rounded-full bg-black/40 backdrop-blur-xl px-3 py-1 text-[11px] font-bold text-white border border-white/10 shadow-lg z-10 transition-transform duration-500 group-hover:-translate-y-1">
                    <Users size={14} className="text-emerald-400 drop-shadow-[0_0_8px_rgba(52,211,153,0.8)]" />
                    <span className="drop-shadow-md">Watching</span>
                  </div>

                  {/* Play Button Overlay (Revealed on hover) */}
                  <div className="absolute inset-0 flex items-center justify-center opacity-0 group-hover:opacity-100 transition-all duration-500 scale-75 group-hover:scale-100 z-10">
                    <div className="h-16 w-16 rounded-full bg-emerald-500/20 backdrop-blur-md border border-emerald-400/40 flex items-center justify-center shadow-[0_0_40px_rgba(52,211,153,0.4)] text-emerald-300">
                      <svg className="w-6 h-6 ml-1 drop-shadow-md" fill="currentColor" viewBox="0 0 24 24"><path d="M8 5v14l11-7z" /></svg>
                    </div>
                  </div>

                  {/* Bottom Info: Avatar and Titles */}
                  <div className="absolute left-5 right-5 bottom-5 z-20 flex items-end gap-3 transition-transform duration-500 group-hover:translate-y-[-4px]">
                    {/* Glowing Avatar Frame */}
                    <div className="relative">
                      <div className="absolute -inset-1 rounded-full bg-gradient-to-r from-emerald-500 to-blue-500 opacity-0 group-hover:opacity-75 blur-md transition-opacity duration-500" />
                      <div className="relative h-[56px] w-[56px] shrink-0 rounded-full border-[3px] border-[#0A0A0A] bg-zinc-900 overflow-hidden shadow-2xl">
                        {s.creatorAvatarUrl ? (
                          // eslint-disable-next-line @next/next/no-img-element
                          <img src={s.creatorAvatarUrl} alt={s.creatorName} className="h-full w-full object-cover" />
                        ) : (
                          <div className="flex h-full w-full items-center justify-center text-zinc-300 bg-gradient-to-br from-zinc-800 to-zinc-900 font-black text-xl">
                            {s.creatorName.charAt(0).toUpperCase()}
                          </div>
                        )}
                      </div>
                    </div>

                    <div className="flex-1 min-w-0 pb-1">
                      <div className="text-lg font-black leading-tight text-white truncate drop-shadow-[0_2px_10px_rgba(0,0,0,0.8)] transform transition-transform duration-500 origin-left group-hover:scale-[1.03]">
                        {s.gameTitle ? `Streaming ${s.gameTitle}!` : "Welcome to my stream!"}
                      </div>
                      <div className="mt-1 text-[13px] font-bold tracking-wide text-emerald-400 truncate drop-shadow-sm flex items-center gap-1.5 opacity-80 group-hover:opacity-100 transition-opacity duration-500">
                        {s.creatorName}
                        <Sparkles size={12} className="text-cyan-400" />
                      </div>
                    </div>
                  </div>
                </Link>
              </motion.div>
            ))}
          </div>
        )}
      </div>
    </UserShell>
  );
}
