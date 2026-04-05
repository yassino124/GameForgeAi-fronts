"use client";

import { useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import UserShell from "@/app/_components/UserShell";
import { apiFetch, ApiError } from "@/lib/api";
import { getUserToken } from "@/lib/userAuth";
import { normalizeImageUrl } from "@/lib/media";
import { AnimatePresence, motion } from "framer-motion";
import { Rocket, Zap, ArrowRight, Layers, LayoutGrid } from "lucide-react";

type Project = {
  id?: string;
  _id?: string;
  name?: string;
  description?: string;
  status?: string;
  updatedAt?: string;
  createdAt?: string;
  downloadCount?: number;
  downloadsCount?: number;
  downloads?: number;
  previewImageUrl?: string;
  thumbnailUrl?: string;
  iconUrl?: string;
  imageUrl?: string;
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
  if (min < 60) return `${min} min ago`;
  const h = Math.floor(min / 60);
  if (h < 24) return `${h}h ago`;
  const days = Math.floor(h / 24);
  return `${days}d ago`;
}

export default function StudioProjectsPage() {
  const router = useRouter();
  const token = useMemo(() => getUserToken(), []);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [projects, setProjects] = useState<Project[]>([]);
  const [plan, setPlan] = useState<string>("Free");
  const [showUpgrade, setShowUpgrade] = useState(false);
  const [upgradeReason, setUpgradeReason] = useState<string>("Upgrade required");

  const normPlan = (p: any) => String(p || "Free").trim().toLowerCase();
  const isFree = normPlan(plan) === "free";
  const isPro = useMemo(() => {
    const p = String(plan || "").trim().toLowerCase();
    const paidKeywords = ["pro", "enterprise", "studio", "premium", "gold"];
    const isPaid = paidKeywords.some(k => p.includes(k)) || (p !== "free" && p !== "" && p !== "standard free");
    console.log("Projects List Plan Check - raw:", plan, "norm:", p, "isPro:", isPaid);
    return isPaid;
  }, [plan]);
  const freeMaxProjects = 3;

  useEffect(() => {
    let cancelled = false;
    async function load() {
      if (!token) return;
      setLoading(true);
      setError(null);
      try {
        try {
          const meRes = await apiFetch<any>("/auth/profile", { method: "GET", token });
          const meData = (meRes && typeof meRes === "object" && "data" in meRes) ? (meRes as any).data : meRes;
          const userObj = meData?.user || meData;
          if (!cancelled) setPlan((userObj?.subscription ?? userObj?.plan ?? "Free") as string);
        } catch {}

        const res = await apiFetch<any>("/projects", { method: "GET", token });
        const data = (res && typeof res === "object" && "data" in res) ? (res as any).data : res;
        const items = Array.isArray((data as any)?.data) ? (data as any).data : (Array.isArray(data) ? data : []);
        const normalized = items
          .filter(Boolean)
          .map((p: any) => (p && typeof p === "object" ? (p as Project) : ({} as Project)));

        normalized.sort((a: Project, b: Project) => {
          const ad = (a.updatedAt || a.createdAt || "").toString();
          const bd = (b.updatedAt || b.createdAt || "").toString();
          return bd.localeCompare(ad);
        });

        if (!cancelled) setProjects(normalized);
      } catch (e: any) {
        if (!cancelled) setError(e instanceof ApiError ? e.message : (e?.message || "Failed to load projects"));
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
    <UserShell title="Projects" subtitle="Manage your game projects">
      {error ? (
        <div className="mb-4 rounded-2xl border border-red-500/20 bg-red-500/10 px-4 py-3 text-sm text-red-200">{error}</div>
      ) : null}

      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div className="text-xs text-zinc-400">
          {loading ? "Loading…" : `${projects.length} project${projects.length === 1 ? "" : "s"}`}
        </div>
        <button
          className="rounded-xl bg-gradient-to-r from-indigo-500 to-fuchsia-500 px-3 py-2 text-sm font-semibold text-white"
          onClick={() => {
            if (!isPro && isFree && projects.length >= freeMaxProjects) {
              setUpgradeReason(`Free plan supports up to ${freeMaxProjects} projects. Upgrade to Pro to create more.`);
              setShowUpgrade(true);
              return;
            }
            router.push("/studio/projects/new");
          }}
        >
          Create project
        </button>
      </div>

      <AnimatePresence>
        {showUpgrade ? (
          <div className="fixed inset-0 z-[120] flex items-center justify-center p-4">
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              className="absolute inset-0 bg-black/80 backdrop-blur-sm"
              onClick={() => setShowUpgrade(false)}
            />
            <motion.div
              initial={{ opacity: 0, scale: 0.96, y: 12 }}
              animate={{ opacity: 1, scale: 1, y: 0 }}
              exit={{ opacity: 0, scale: 0.96, y: 12 }}
              className="relative w-full max-w-md gf-panel-strong rounded-[28px] border border-white/10 p-6 shadow-2xl"
            >
              <div className="text-lg font-black text-white">Upgrade to Pro</div>
              <div className="mt-2 text-sm text-zinc-400">{upgradeReason}</div>
              <div className="mt-5 flex gap-2">
                <button className="gf-btn rounded-xl px-4 py-2 text-sm" onClick={() => setShowUpgrade(false)}>
                  Not now
                </button>
                <button
                  className="flex-1 rounded-xl bg-indigo-500 px-4 py-2 text-sm font-black text-white"
                  onClick={() => router.push("/studio/subscription")}
                >
                  View plans
                </button>
              </div>
            </motion.div>
          </div>
        ) : null}
      </AnimatePresence>

      <div className="mt-4 grid grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-3">
        {loading ? (
          Array.from({ length: 6 }).map((_, i) => (
            <div key={i} className="gf-card rounded-2xl border border-white/10 p-5">
              <div className="h-4 w-32 rounded bg-white/10" />
              <div className="mt-3 h-3 w-48 rounded bg-white/10" />
              <div className="mt-6 h-10 w-full rounded bg-white/5" />
            </div>
          ))
        ) : projects.length === 0 ? (
          <div className="gf-panel rounded-2xl p-6 md:col-span-2 xl:col-span-3">
            <div className="text-sm font-semibold text-white">No projects yet</div>
            <div className="mt-1 text-xs text-zinc-400">Create your first game project to get started.</div>
          </div>
        ) : (
          projects.map((p) => {
            const id = (p._id || p.id || "").toString();
            const name = (p.name || "Project").toString();
            const desc = (p.description || "—").toString();
            const status = (p.status || "").toString().toLowerCase();
            const completed = status === "ready" || status === "completed";
            const updated = p.updatedAt || p.createdAt;
            const downloads = toInt(p.downloadCount ?? p.downloadsCount ?? (p as any).downloads);
            const img = normalizeImageUrl(p.previewImageUrl || p.thumbnailUrl || p.iconUrl || p.imageUrl);

            return (
              <motion.button
                layout
                initial={{ opacity: 0, scale: 0.9 }}
                animate={{ opacity: 1, scale: 1 }}
                whileHover={{ 
                  y: -8, 
                  transition: { type: "spring", stiffness: 400, damping: 10 } 
                }}
                key={id || name}
                onClick={() => (id ? router.push(`/studio/projects/${encodeURIComponent(id)}`) : null)}
                className="gf-holographic group relative overflow-hidden rounded-[32px] border border-white/10 p-6 text-left transition-all duration-500 hover:border-indigo-500/40"
              >
                {/* Immersive Background Glow */}
                <div className="absolute inset-0 bg-gradient-to-br from-indigo-500/10 via-transparent to-fuchsia-500/5 opacity-0 group-hover:opacity-100 transition-opacity duration-700" />
                
                <div className="relative flex items-start gap-5">
                  <motion.div 
                    whileHover={{ rotate: -5, scale: 1.05 }}
                    className="h-20 w-20 shrink-0 overflow-hidden rounded-[24px] border border-white/10 bg-gradient-to-br from-indigo-500/30 via-fuchsia-500/15 to-cyan-500/15 shadow-2xl group-hover:shadow-indigo-500/20 transition-all duration-500"
                  >
                    {img ? (
                      // eslint-disable-next-line @next/next/no-img-element
                      <img src={img} alt="" className="h-full w-full object-cover group-hover:scale-110 transition-transform duration-700" />
                    ) : (
                      <div className="flex h-full w-full items-center justify-center">
                        <Rocket size={32} className="text-white/20 group-hover:text-white/40 transition-colors" />
                      </div>
                    )}
                  </motion.div>

                  <div className="min-w-0 flex-1 py-1">
                    <div className="flex items-center justify-between gap-3">
                      <div className="truncate text-lg font-black text-white tracking-tight group-hover:gf-chromatic transition-all">{name}</div>
                      <motion.span
                        animate={{ scale: [1, 1.05, 1] }}
                        transition={{ duration: 2, repeat: Infinity }}
                        className={
                          "shrink-0 rounded-full border px-3 py-1 text-[10px] font-black uppercase tracking-widest " +
                          (completed
                            ? "border-emerald-500/30 bg-emerald-500/10 text-emerald-400 shadow-[0_0_15px_rgba(16,185,129,0.2)]"
                            : "border-amber-500/30 bg-amber-500/10 text-amber-400 shadow-[0_0_15px_rgba(245,158,11,0.2)]")
                        }
                      >
                        {completed ? "READY" : "WORK"}
                      </motion.span>
                    </div>
                    <div className="mt-1 line-clamp-1 text-xs text-zinc-500 font-medium group-hover:text-zinc-400 transition-colors">{desc}</div>

                    <div className="mt-6 flex items-center justify-between">
                      <div className="flex items-center gap-3">
                        <div className="flex items-center gap-1.5 rounded-xl border border-white/5 bg-black/40 px-3 py-1.5 text-[10px] font-black text-zinc-400 group-hover:text-indigo-300 transition-colors">
                          <Zap size={12} className="text-yellow-500" />
                          {downloads}
                        </div>
                        <div className="h-1 w-1 rounded-full bg-zinc-800" />
                        <span className="text-[10px] font-bold text-zinc-600 uppercase tracking-wider">{timeAgo(updated)}</span>
                      </div>
                      
                      <motion.div 
                        whileHover={{ x: 5 }}
                        className="opacity-0 group-hover:opacity-100 transition-all text-indigo-400"
                      >
                        <ArrowRight size={18} />
                      </motion.div>
                    </div>
                  </div>
                </div>

                {/* Animated scanning border */}
                <div className="absolute bottom-0 left-0 h-[2px] w-0 bg-gradient-to-r from-transparent via-indigo-500 to-transparent group-hover:w-full transition-all duration-700" />
              </motion.button>
            );
          })
        )}
      </div>
    </UserShell>
  );
}
