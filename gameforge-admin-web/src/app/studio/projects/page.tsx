"use client";

import { useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import UserShell from "@/app/_components/UserShell";
import { apiFetch, ApiError } from "@/lib/api";
import { useAuthToken } from "@/lib/stores/authStore";
import { normalizeImageUrl } from "@/lib/media";
import { AnimatePresence, motion } from "framer-motion";
import {
  Rocket, Zap, ArrowRight, Plus, Search,
  LayoutGrid, List, Clock, Download, Layers,
  CheckCircle2, AlertCircle, Timer, FileCode2, ChevronRight,
  Gamepad2, Sparkles, Cpu, Globe, Swords, Star
} from "lucide-react";

/* ─────────────────────────────────────────── types */
type Project = {
  id?: string; _id?: string; name?: string; description?: string;
  status?: string; updatedAt?: string; createdAt?: string;
  downloadCount?: number; downloadsCount?: number; downloads?: number;
  previewImageUrl?: string; thumbnailUrl?: string; iconUrl?: string; imageUrl?: string;
};

function toInt(v: any) {
  if (typeof v === "number") return Math.trunc(v);
  if (typeof v === "string") return Number.parseInt(v, 10) || 0;
  return 0;
}

function timeAgo(raw?: string | null) {
  const s = (raw ?? "").trim();
  if (!s) return "Recently";
  const d = new Date(s);
  if (Number.isNaN(d.getTime())) return "Recently";
  const diffMs = Date.now() - d.getTime();
  const min = Math.floor(diffMs / 60000);
  if (min < 2) return "Just now";
  if (min < 60) return `${min}m ago`;
  const h = Math.floor(min / 60);
  if (h < 24) return `${h}h ago`;
  return `${Math.floor(h / 24)}d ago`;
}

/* ─────────────────────────────────────────── status config */
type StatusKey = "ready" | "building" | "queued" | "failed" | "draft";
const STATUS_CONFIG: Record<StatusKey, { label: string; badge: string; bar: string; icon: any; dot: string }> = {
  ready:    { label: "Ready",    badge: "border-emerald-500/25 bg-emerald-500/10 text-emerald-300", bar: "bg-emerald-500",  icon: CheckCircle2, dot: "bg-emerald-400" },
  building: { label: "Building", badge: "border-blue-500/25 bg-blue-600/10 text-blue-300",          bar: "bg-blue-500",    icon: Timer,        dot: "bg-blue-400 animate-pulse" },
  queued:   { label: "Queued",   badge: "border-sky-500/25 bg-sky-600/10 text-sky-300",             bar: "bg-sky-500",     icon: Timer,        dot: "bg-sky-400 animate-pulse" },
  failed:   { label: "Failed",   badge: "border-red-500/25 bg-red-500/10 text-red-300",             bar: "bg-red-500",     icon: AlertCircle,  dot: "bg-red-400" },
  draft:    { label: "Draft",    badge: "border-white/10 bg-white/5 text-zinc-400",                 bar: "bg-zinc-700",    icon: FileCode2,    dot: "bg-zinc-500" },
};

function getStatusConfig(status: string) {
  const key = status.toLowerCase() as StatusKey;
  return STATUS_CONFIG[key] ?? STATUS_CONFIG["draft"];
}

/* ─────────────────────────────────────────── skeleton */
function ProjectCardSkeleton() {
  return (
    <div className="rounded-[28px] border border-white/[0.05] bg-[var(--gf-panel-bg-strong)]/70 overflow-hidden">
      <div className="gf-skeleton h-44 w-full" />
      <div className="p-6 space-y-3">
        <div className="flex items-center justify-between">
          <div className="gf-skeleton h-4 w-36 rounded-full" />
          <div className="gf-skeleton h-5 w-16 rounded-full" />
        </div>
        <div className="gf-skeleton h-3 w-4/5 rounded-full" />
        <div className="gf-skeleton h-3 w-3/5 rounded-full" />
        <div className="flex items-center justify-between pt-2">
          <div className="gf-skeleton h-6 w-20 rounded-xl" />
          <div className="gf-skeleton h-6 w-14 rounded-xl" />
        </div>
      </div>
    </div>
  );
}

/* ─────────────────────────────────────────── project card */
function ProjectCard({ p, idx, router }: { p: Project; idx: number; router: any }) {
  const id     = (p._id || p.id || "").toString();
  const name   = (p.name || "Project").toString();
  const desc   = (p.description || "").toString();
  const status = (p.status || "draft").toString().toLowerCase();
  const cfg    = getStatusConfig(status);
  const updated   = p.updatedAt || p.createdAt;
  const downloads = toInt(p.downloadCount ?? p.downloadsCount ?? (p as any).downloads);
  const img       = normalizeImageUrl(p.previewImageUrl || p.thumbnailUrl || p.iconUrl || p.imageUrl);

  return (
    <motion.button
      layout
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ delay: idx * 0.05, duration: 0.45, ease: [0.16, 1, 0.3, 1] }}
      whileHover={{ y: -8, transition: { type: "spring", stiffness: 420, damping: 24 } }}
      onClick={() => id && router.push(`/studio/projects/${encodeURIComponent(id)}`)}
      className="group relative overflow-hidden rounded-[28px] border border-white/[0.07] bg-[var(--gf-panel-bg-strong)] text-left flex flex-col shadow-[0_8px_32px_rgba(0,0,0,0.4)] hover:shadow-[0_24px_64px_rgba(0,0,0,0.6)] hover:border-white/[0.12] transition-all duration-400"
    >
      {/* Status color strip — top */}
      <div className={`absolute top-0 left-0 right-0 h-px ${cfg.bar} opacity-60 group-hover:opacity-100 transition-opacity`} />

      {/* Thumbnail */}
      <div className="relative h-44 w-full overflow-hidden shrink-0 bg-[var(--gf-panel-bg-strong)]">
        {img ? (
          <img
            src={img}
            alt={name}
            className="w-full h-full object-cover opacity-75 group-hover:opacity-100 group-hover:scale-105 transition-all duration-700"
          />
      ) : (() => {
          // Each card gets a unique identity based on idx
          const THEMES = [
            { from: "from-blue-600/30",    via: "via-blue-900/20",    to: "to-[#08090e]", glow1: "bg-blue-600/20",   glow2: "bg-sky-500/10",    icon: Rocket,   iconColor: "#60a5fa",  grid: "rgba(37,99,235,0.2)" },
            { from: "from-emerald-600/30", via: "via-emerald-900/20", to: "to-[#08090e]", glow1: "bg-emerald-600/20",glow2: "bg-teal-500/10",   icon: Gamepad2, iconColor: "#34d399",  grid: "rgba(16,185,129,0.18)" },
            { from: "from-sky-600/30",  via: "via-sky-900/20",  to: "to-[#08090e]", glow1: "bg-sky-600/20", glow2: "bg-sky-500/10", icon: Sparkles, iconColor: "#c084fc",  grid: "rgba(147,51,234,0.18)" },
            { from: "from-amber-600/30",   via: "via-amber-900/20",   to: "to-[#08090e]", glow1: "bg-amber-600/20",  glow2: "bg-orange-500/10", icon: Zap,      iconColor: "#fbbf24",  grid: "rgba(245,158,11,0.18)" },
            { from: "from-rose-600/30",    via: "via-rose-900/20",    to: "to-[#08090e]", glow1: "bg-rose-600/20",   glow2: "bg-pink-500/10",   icon: Swords,   iconColor: "#fb7185",  grid: "rgba(244,63,94,0.18)" },
            { from: "from-sky-600/30",     via: "via-sky-900/20",     to: "to-[#08090e]", glow1: "bg-sky-600/20",    glow2: "bg-cyan-500/10",   icon: Cpu,      iconColor: "#38bdf8",  grid: "rgba(14,165,233,0.18)" },
          ];
          const t = THEMES[idx % THEMES.length];
          const IconComp = t.icon;
          return (
            <>
              {/* Gradient bg */}
              <div className={`absolute inset-0 bg-gradient-to-br ${t.from} ${t.via} ${t.to}`} />
              {/* Grid overlay */}
              <div
                className="absolute inset-0 opacity-[0.22]"
                style={{
                  backgroundImage: `linear-gradient(${t.grid} 1px, transparent 1px), linear-gradient(90deg, ${t.grid} 1px, transparent 1px)`,
                  backgroundSize: "26px 26px",
                }}
              />
              {/* Corner glows */}
              <div className={`absolute -top-6 -left-6 w-28 h-28 rounded-full ${t.glow1} blur-[35px]`} />
              <div className={`absolute -bottom-6 -right-6 w-28 h-28 rounded-full ${t.glow2} blur-[35px]`} />
              {/* Floating icon */}
              <div className="absolute inset-0 flex items-center justify-center">
                <motion.div
                  animate={{ y: [0, -8, 0], rotate: [0, 4, 0] }}
                  transition={{ duration: 3.5 + (idx % 3) * 0.5, repeat: Infinity, ease: "easeInOut" }}
                  className="p-5 rounded-3xl bg-black/30 border border-white/10 backdrop-blur-sm"
                  style={{ boxShadow: `0 0 32px ${t.iconColor}30` }}
                >
                  <IconComp size={34} style={{ color: t.iconColor }} />
                </motion.div>
              </div>
            </>
          );
        })()}
        <div className="absolute inset-0 bg-gradient-to-t from-[var(--gf-bg)] via-[var(--gf-bg)]/20 to-transparent" />

        {/* Status badge */}
        <div className="absolute top-4 right-4">
          <span className={`inline-flex items-center gap-1.5 rounded-full border px-2.5 py-1 text-[9px] font-black uppercase tracking-widest backdrop-blur-md ${cfg.badge}`}>
            <span className={`h-1.5 w-1.5 rounded-full shrink-0 ${cfg.dot}`} />
            {cfg.label}
          </span>
        </div>

        {/* Hover shimmer */}
        <motion.div
          animate={{ x: ["-100%", "200%"] }}
          transition={{ duration: 2.5, repeat: Infinity, ease: "linear", repeatDelay: 3 }}
          className="absolute inset-0 w-1/2 bg-gradient-to-r from-transparent via-white/[0.04] to-transparent opacity-0 group-hover:opacity-100 pointer-events-none"
        />
      </div>

      {/* Content */}
      <div className="flex-1 flex flex-col p-6">
        {/* Hover glow */}
        <div className="absolute inset-0 bg-gradient-to-b from-transparent via-blue-600/[0.03] to-blue-600/[0.06] opacity-0 group-hover:opacity-100 transition-opacity duration-500 pointer-events-none" />

        <div className="relative z-10 flex-1">
          <h3 className="text-[15px] font-bold text-[var(--foreground)] leading-snug tracking-tight truncate mb-1.5 group-hover:text-blue-500 transition-colors duration-300">
            {name}
          </h3>
          {desc && (
            <p className="text-[12px] text-zinc-600 leading-relaxed line-clamp-2 group-hover:text-zinc-500 transition-colors">
              {desc}
            </p>
          )}
        </div>

        {/* Footer */}
        <div className="relative z-10 flex items-center justify-between mt-5 pt-4 border-t border-white/[0.05]">
          <div className="flex items-center gap-3">
            {downloads > 0 && (
              <span className="flex items-center gap-1.5 text-[10px] font-semibold text-zinc-600">
                <Download size={10} strokeWidth={2.5} />
                {downloads.toLocaleString()}
              </span>
            )}
            {updated && (
              <span className="flex items-center gap-1.5 text-[10px] font-semibold text-zinc-700">
                <Clock size={10} strokeWidth={2.5} />
                {timeAgo(updated)}
              </span>
            )}
          </div>
          <div className="flex items-center gap-1 text-[10px] font-black uppercase tracking-widest text-zinc-700 group-hover:text-blue-400 transition-colors duration-300">
            Open <ChevronRight size={12} className="group-hover:translate-x-0.5 transition-transform duration-200" />
          </div>
        </div>
      </div>
    </motion.button>
  );
}

/* ─────────────────────────────────────────── main page */
export default function StudioProjectsPage() {
  const router = useRouter();
  const { token } = useAuthToken();
  const [loading, setLoading]         = useState(true);
  const [error, setError]             = useState<string | null>(null);
  const [projects, setProjects]       = useState<Project[]>([]);
  const [plan, setPlan]               = useState<string>("Free");
  const [showUpgrade, setShowUpgrade] = useState(false);
  const [upgradeReason, setUpgradeReason] = useState<string>("Upgrade required");
  const [search, setSearch]           = useState("");
  const [view, setView]               = useState<"grid" | "list">("grid");
  const [statusFilter, setStatusFilter] = useState<string>("all");

  const normPlan     = (p: any) => String(p || "Free").trim().toLowerCase();
  const isFree       = normPlan(plan) === "free";
  const isPro        = useMemo(() => {
    const p = String(plan || "").trim().toLowerCase();
    return ["pro", "enterprise", "studio", "premium", "gold"].some((k) => p.includes(k)) || (p !== "free" && p !== "" && p !== "standard free");
  }, [plan]);
  const freeMaxProjects = 3;

  useEffect(() => {
    let cancelled = false;
    async function load() {
      if (!token) return;
      setLoading(true); setError(null);
      try {
        try {
          const meRes = await apiFetch<any>("/auth/profile", { method: "GET", token });
          const meData = meRes && typeof meRes === "object" && "data" in meRes ? (meRes as any).data : meRes;
          const userObj = meData?.user || meData;
          if (!cancelled) setPlan((userObj?.subscription ?? userObj?.plan ?? "Free") as string);
        } catch {}
        const res   = await apiFetch<any>("/projects", { method: "GET", token });
        const data  = res && typeof res === "object" && "data" in res ? (res as any).data : res;
        const items = Array.isArray((data as any)?.data) ? (data as any).data : Array.isArray(data) ? data : [];
        const normalized = items.filter(Boolean).map((p: any) => (p && typeof p === "object" ? (p as Project) : ({} as Project)));
        normalized.sort((a: Project, b: Project) => (b.updatedAt || b.createdAt || "").localeCompare(a.updatedAt || a.createdAt || ""));
        if (!cancelled) setProjects(normalized);
      } catch (e: any) {
        if (!cancelled) setError(e instanceof ApiError ? e.message : e?.message || "Failed to load projects");
      } finally {
        if (!cancelled) setLoading(false);
      }
    }
    load();
    return () => { cancelled = true; };
  }, [token]);

  const filtered = projects.filter((p) => {
    const matchSearch = !search || (p.name || "").toLowerCase().includes(search.toLowerCase());
    const matchStatus = statusFilter === "all" || (p.status || "draft").toLowerCase() === statusFilter;
    return matchSearch && matchStatus;
  });

  /* ── status counts for filter pills */
  const counts = useMemo(() => {
    const c: Record<string, number> = { all: projects.length };
    projects.forEach((p) => {
      const s = (p.status || "draft").toLowerCase();
      c[s] = (c[s] || 0) + 1;
    });
    return c;
  }, [projects]);

  const statusPills = [
    { key: "all",      label: "All" },
    { key: "ready",    label: "Ready" },
    { key: "building", label: "Building" },
    { key: "draft",    label: "Draft" },
    { key: "failed",   label: "Failed" },
  ];

  return (
    <UserShell
      title="Projects"
      subtitle="MY WORK"
      right={
        <button
          className="group relative overflow-hidden flex items-center gap-2 rounded-2xl bg-blue-600 px-5 py-2.5 text-[11px] font-black uppercase tracking-widest text-white shadow-[0_12px_28px_rgba(37,99,235,0.3)] transition-all hover:bg-blue-500 hover:shadow-[0_18px_40px_rgba(37,99,235,0.4)] active:scale-95"
          onClick={() => {
            if (!isPro && isFree && projects.length >= freeMaxProjects) {
              setUpgradeReason(`Free plan supports up to ${freeMaxProjects} projects. Upgrade to unlock unlimited.`);
              setShowUpgrade(true);
              return;
            }
            router.push("/studio/projects/new");
          }}
        >
          <div className="absolute inset-0 bg-gradient-to-r from-transparent via-white/20 to-transparent -translate-x-full group-hover:translate-x-full transition-transform duration-700" />
          <Plus size={14} className="relative" />
          <span className="relative">New Project</span>
        </button>
      }
    >
      {/* ── Global bg glow ── */}
      <div className="pointer-events-none fixed inset-0 z-0">
        <motion.div
          animate={{ scale: [1, 1.12, 1], opacity: [0.04, 0.08, 0.04] }}
          transition={{ duration: 20, repeat: Infinity, ease: "easeInOut" }}
          className="absolute -top-[10%] -right-[5%] w-[50%] h-[50%] rounded-full bg-blue-600/10 blur-[120px]"
        />
      </div>

      {error && (
        <div className="relative z-10 mb-6 rounded-2xl border border-red-500/20 bg-red-500/8 px-4 py-3 text-sm text-red-300">
          {error}
        </div>
      )}

      {/* ── Hero header bar ── */}
      <motion.div
        initial={{ opacity: 0, y: -12 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.5, ease: [0.16, 1, 0.3, 1] }}
        className="relative z-10 mb-8 overflow-hidden rounded-[28px] border border-white/[0.07] bg-[var(--gf-panel-bg-strong)] px-8 py-6 shadow-xl"
      >
        {/* Grid bg */}
        <div
          className="pointer-events-none absolute inset-0 opacity-[0.04]"
          style={{
            backgroundImage: "linear-gradient(rgba(255,255,255,0.3) 1px, transparent 1px), linear-gradient(90deg, rgba(255,255,255,0.3) 1px, transparent 1px)",
            backgroundSize: "36px 36px",
          }}
        />
        <div className="absolute top-0 left-1/3 h-[180px] w-[400px] -translate-x-1/2 rounded-full bg-blue-600/10 blur-[80px] pointer-events-none" />

        <div className="relative z-10 flex flex-col sm:flex-row sm:items-center gap-6 justify-between">
          <div>
            <div className="text-[10px] font-black text-zinc-600 uppercase tracking-[0.5em] mb-1">Studio / Projects</div>
            <h1 className="text-3xl font-black text-[var(--foreground)] tracking-tight">
              Your Games<span className="text-blue-400">.</span>
            </h1>
            <p className="text-zinc-500 text-sm mt-1 font-medium">
              {loading ? "Loading…" : `${projects.length} project${projects.length !== 1 ? "s" : ""} in your studio`}
            </p>
          </div>

          {/* Mini stat pills */}
          {!loading && projects.length > 0 && (
            <div className="flex flex-wrap gap-2">
              {[
                { icon: CheckCircle2, label: "Ready",    count: counts["ready"]    || 0, color: "text-emerald-400 border-emerald-500/20 bg-emerald-500/8" },
                { icon: Timer,        label: "Building", count: counts["building"] || 0, color: "text-blue-400 border-blue-500/20 bg-blue-600/8" },
                { icon: Layers,       label: "Draft",    count: counts["draft"]    || 0, color: "text-zinc-400 border-white/10 bg-white/4" },
              ].map((s) => (
                <div key={s.label} className={`flex items-center gap-2 px-3 py-1.5 rounded-full border text-[10px] font-black uppercase tracking-widest ${s.color}`}>
                  <s.icon size={11} strokeWidth={2.5} />
                  {s.count} {s.label}
                </div>
              ))}
            </div>
          )}
        </div>
      </motion.div>

      {/* ── Toolbar ── */}
      <motion.div
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ delay: 0.15 }}
        className="relative z-10 flex flex-col gap-4 mb-7"
      >
        {/* Top row: search + view toggle */}
        <div className="flex flex-col sm:flex-row gap-3 items-start sm:items-center">
          <div className="relative flex-1 max-w-sm">
            <Search size={14} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-zinc-600 pointer-events-none" />
            <input
              className="w-full rounded-[14px] border border-white/[0.07] bg-white/[0.03] pl-9 pr-4 py-2.5 text-sm text-white placeholder-zinc-600 focus:outline-none focus:border-blue-500/40 focus:bg-white/[0.05] transition-all"
              placeholder="Search projects…"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
            />
          </div>

          <div className="flex items-center gap-2 ml-auto">
            <span className="text-[11px] font-semibold text-zinc-600 px-1">
              {!loading && `${filtered.length} shown`}
            </span>
            <div className="flex items-center rounded-[12px] border border-white/[0.06] bg-white/[0.02] p-1 gap-0.5">
              {(["grid", "list"] as const).map((v) => (
                <button
                  key={v}
                  onClick={() => setView(v)}
                  className={`h-7 w-7 flex items-center justify-center rounded-[9px] transition-all duration-200 ${view === v ? "bg-blue-600/20 text-blue-300" : "text-zinc-600 hover:text-zinc-400"}`}
                >
                  {v === "grid" ? <LayoutGrid size={13} /> : <List size={13} />}
                </button>
              ))}
            </div>
          </div>
        </div>

        {/* Status filter pills */}
        {!loading && projects.length > 0 && (
          <div className="flex flex-wrap gap-2">
            {statusPills.map((pill) => {
              const isActive = statusFilter === pill.key;
              const count    = counts[pill.key] ?? 0;
              if (pill.key !== "all" && !count) return null;
              return (
                <button
                  key={pill.key}
                  onClick={() => setStatusFilter(pill.key)}
                  className={`px-3.5 py-1.5 rounded-full text-[10px] font-black uppercase tracking-widest transition-all ${
                    isActive
                      ? "bg-blue-600/20 border border-blue-500/35 text-blue-300"
                      : "bg-white/[0.03] border border-white/[0.06] text-zinc-500 hover:text-zinc-300 hover:border-white/[0.12]"
                  }`}
                >
                  {pill.label}
                  {count > 0 && (
                    <span className={`ml-1.5 ${isActive ? "text-blue-400" : "text-zinc-600"}`}>
                      {count}
                    </span>
                  )}
                </button>
              );
            })}
          </div>
        )}
      </motion.div>

      {/* ── Grid / List ── */}
      <div className="relative z-10">
        <AnimatePresence mode="wait">
          {loading ? (
            <motion.div
              key="skeletons"
              initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}
              className={`grid gap-5 ${view === "grid" ? "grid-cols-1 md:grid-cols-2 xl:grid-cols-3" : "grid-cols-1"}`}
            >
              {Array.from({ length: 6 }).map((_, i) => <ProjectCardSkeleton key={i} />)}
            </motion.div>
          ) : filtered.length === 0 ? (
            <motion.div
              key="empty"
              initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0 }}
              className="relative flex flex-col items-center justify-center py-28 rounded-[32px] border border-white/[0.06] bg-[#08090e] overflow-hidden"
            >
              <div
                className="pointer-events-none absolute inset-0 opacity-[0.04]"
                style={{
                  backgroundImage: "linear-gradient(rgba(255,255,255,0.3) 1px, transparent 1px), linear-gradient(90deg, rgba(255,255,255,0.3) 1px, transparent 1px)",
                  backgroundSize: "36px 36px",
                }}
              />
              <div className="absolute inset-0 bg-[radial-gradient(ellipse_at_center,rgba(37,99,235,0.07),transparent_65%)] pointer-events-none" />

              <motion.div
                animate={{ y: [0, -10, 0] }}
                transition={{ duration: 3.5, repeat: Infinity, ease: "easeInOut" }}
                className="relative mb-6"
              >
                <div className="h-20 w-20 rounded-[28px] bg-blue-600/12 border border-blue-500/20 flex items-center justify-center">
                  <Rocket size={34} className="text-blue-400" />
                </div>
                <div className="absolute -inset-3 rounded-[36px] bg-blue-600/8 blur-xl -z-10" />
              </motion.div>

              <h3 className="text-2xl font-black text-white mb-2 tracking-tight">
                {search || statusFilter !== "all" ? "Nothing found" : "Your studio awaits"}
              </h3>
              <p className="text-sm text-zinc-500 mb-8 max-w-[280px] text-center leading-relaxed">
                {search || statusFilter !== "all"
                  ? "Try adjusting your filters or clear the search."
                  : "Build your first game — describe it and we ship it to every platform."}
              </p>

              {!search && statusFilter === "all" && (
                <button
                  onClick={() => router.push("/studio/projects/new")}
                  className="group relative overflow-hidden flex items-center gap-2.5 px-7 py-3.5 rounded-2xl bg-blue-600 text-white text-[11px] font-black uppercase tracking-widest hover:bg-blue-500 transition-all shadow-[0_14px_32px_rgba(37,99,235,0.28)]"
                >
                  <div className="absolute inset-0 bg-gradient-to-r from-transparent via-white/15 to-transparent -translate-x-full group-hover:translate-x-full transition-transform duration-700" />
                  <Plus size={15} className="relative" />
                  <span className="relative">Create Your First Game</span>
                </button>
              )}
            </motion.div>
          ) : (
            <motion.div
              key="projects"
              initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}
              className={`grid gap-5 ${view === "grid" ? "grid-cols-1 md:grid-cols-2 xl:grid-cols-3" : "grid-cols-1"}`}
            >
              {filtered.map((p, idx) => (
                <ProjectCard key={p._id || p.id || idx} p={p} idx={idx} router={router} />
              ))}
            </motion.div>
          )}
        </AnimatePresence>
      </div>

      {/* ── Upgrade modal ── */}
      <AnimatePresence>
        {showUpgrade && (
          <div className="fixed inset-0 z-[120] flex items-center justify-center p-4">
            <motion.div
              initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}
              className="absolute inset-0 bg-black/80 backdrop-blur-md"
              onClick={() => setShowUpgrade(false)}
            />
            <motion.div
              initial={{ opacity: 0, scale: 0.92, y: 16 }}
              animate={{ opacity: 1, scale: 1, y: 0 }}
              exit={{ opacity: 0, scale: 0.92, y: 16 }}
              transition={{ type: "spring", stiffness: 340, damping: 28 }}
              className="relative w-full max-w-sm rounded-[28px] border border-white/[0.09] bg-[#0a0b14] p-8 shadow-[0_40px_100px_rgba(0,0,0,0.7)]"
            >
              <div className="absolute top-0 left-1/2 -translate-x-1/2 -translate-y-1/2 h-20 w-48 bg-blue-600/15 blur-[40px] rounded-full pointer-events-none" />
              <div className="relative z-10">
                <div className="mb-5 h-12 w-12 rounded-2xl bg-blue-600/15 border border-blue-500/20 flex items-center justify-center">
                  <Zap size={22} className="text-blue-400" />
                </div>
                <h3 className="text-xl font-black text-white mb-2 tracking-tight">Unlock More Projects</h3>
                <p className="text-sm text-zinc-500 leading-relaxed mb-7">{upgradeReason}</p>
                <div className="flex gap-3">
                  <button
                    className="flex-1 rounded-2xl border border-white/[0.08] bg-white/[0.04] px-4 py-2.5 text-sm font-semibold text-zinc-400 hover:text-white hover:bg-white/[0.08] transition-all"
                    onClick={() => setShowUpgrade(false)}
                  >
                    Not now
                  </button>
                  <button
                    className="flex-1 rounded-2xl bg-blue-600 px-4 py-2.5 text-sm font-black text-white hover:bg-blue-500 transition-all shadow-[0_12px_28px_rgba(37,99,235,0.3)]"
                    onClick={() => router.push("/studio/subscription")}
                  >
                    Upgrade
                  </button>
                </div>
              </div>
            </motion.div>
          </div>
        )}
      </AnimatePresence>
    </UserShell>
  );
}
