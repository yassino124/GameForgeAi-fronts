"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import { useParams, useRouter } from "next/navigation";
import { motion } from "framer-motion";
import UserShell from "@/app/_components/UserShell";
import { apiFetch, ApiError } from "@/lib/api";
import { getUserToken } from "@/lib/userAuth";
import { normalizeImageUrl } from "@/lib/media";
import { Zap as ZapIcon, Play, Box, Settings2, RefreshCcw, Activity, Globe, Layers, Download, Smartphone, Monitor } from "lucide-react";

type Project = {
  id?: string;
  _id?: string;
  name?: string;
  description?: string;
  status?: string;
  buildTarget?: string;
  androidApkStorageKey?: string;
  macosZipStorageKey?: string;
  windowsZipStorageKey?: string;
  updatedAt?: string;
  createdAt?: string;
  downloadCount?: number;
  downloadsCount?: number;
  previewImageUrl?: string;
  thumbnailUrl?: string;
  iconUrl?: string;
  imageUrl?: string;
};

function clampNum(v: any, min: number, max: number, fallback: number) {
  const n = typeof v === "number" ? v : Number(v);
  if (!Number.isFinite(n)) return fallback;
  return Math.max(min, Math.min(max, n));
}

function normHex(v: any, fallback: string) {
  const s = (typeof v === "string" ? v : "").trim();
  if (!s) return fallback;
  const n = s.startsWith("#") ? s : `#${s}`;
  if (!/^#[0-9a-fA-F]{6}$/.test(n)) return fallback;
  return n.toUpperCase();
}

const EmbeddedWebgl = ({ url }: { url: string }) => (
  <div className="relative h-[440px] w-full overflow-hidden rounded-3xl bg-black/40 border border-white/5">
    <div className="absolute inset-0 bg-gradient-to-br from-indigo-500/10 via-transparent to-fuchsia-500/10 pointer-events-none" />
    <iframe
      src={url}
      className="relative z-10 h-full w-full"
      allow="autoplay; fullscreen; gamepad"
      sandbox="allow-scripts allow-same-origin allow-pointer-lock allow-forms"
    />
  </div>
);

const Scene3D = ({ config }: { config: any }) => (
  <div className="relative h-64 w-full flex items-center justify-center perspective-1000 overflow-hidden rounded-3xl bg-black/40 border border-white/5">
    <div className="absolute inset-0 bg-gradient-to-br from-indigo-500/10 via-transparent to-fuchsia-500/10 pointer-events-none" />
    
    <motion.div 
      animate={{ 
        rotateY: 360,
        rotateX: [0, 10, 0, -10, 0],
      }}
      transition={{ 
        rotateY: { duration: 20, repeat: Infinity, ease: "linear" },
        rotateX: { duration: 10, repeat: Infinity, ease: "easeInOut" }
      }}
      className="relative w-32 h-32 preserve-3d"
    >
      {/* 3D Cube representing the project core */}
      {[
        { transform: "rotateY(0deg) translateZ(64px)", color: "primary" },
        { transform: "rotateY(90deg) translateZ(64px)", color: "secondary" },
        { transform: "rotateY(180deg) translateZ(64px)", color: "primary" },
        { transform: "rotateY(270deg) translateZ(64px)", color: "secondary" },
        { transform: "rotateX(90deg) translateZ(64px)", color: "accent" },
        { transform: "rotateX(-90deg) translateZ(64px)", color: "accent" },
      ].map((face, i) => (
        <div 
          key={i}
          className="absolute inset-0 border border-white/20 backdrop-blur-md flex items-center justify-center overflow-hidden"
          style={{ 
            transform: face.transform,
            backgroundColor: i === 0 ? (config.primaryColor || "#6366f1") + "44" : "rgba(255,255,255,0.03)"
          }}
        >
          <div className="gf-grid absolute inset-0 opacity-30" />
          {i === 0 && <Box className="text-white" size={40} strokeWidth={1} />}
        </div>
      ))}
    </motion.div>

    {/* HUD Overlays */}
    <div className="absolute top-6 left-6 flex flex-col gap-2">
      <div className="flex items-center gap-2">
        <div className="h-1.5 w-1.5 rounded-full bg-indigo-500 animate-pulse" />
        <span className="text-[10px] font-black uppercase tracking-widest text-indigo-400">Engine Core v4</span>
      </div>
      <div className="text-[9px] font-bold text-zinc-500 uppercase tracking-widest leading-none">
        {config.buildTarget || "WEBGL"} // RENDER_ACTIVE
      </div>
    </div>

    <div className="absolute bottom-6 right-6 flex flex-col items-end gap-1">
      <div className="text-[10px] font-mono text-zinc-500">POS: 0.0, 0.0, 0.0</div>
      <div className="text-[10px] font-mono text-zinc-500">ROT: AUTO_SPIN</div>
    </div>
  </div>
);

const SandboxPreview = ({ config, previewUrl }: { config: any; previewUrl?: string | null }) => {
  return (
    <div className="space-y-6">
      {previewUrl ? <EmbeddedWebgl url={previewUrl} /> : <Scene3D config={config} />}
      
      {/* Simulation HUD */}
      <div className="flex justify-between items-start">
        <div className="flex flex-col gap-1">
          <span className="text-[10px] font-black text-indigo-400 uppercase tracking-widest bg-indigo-500/10 px-2 py-1 rounded-lg border border-indigo-500/20">
            Sandbox Active
          </span>
          <div className="flex items-center gap-2 mt-2">
            <div className="h-1.5 w-1.5 rounded-full bg-emerald-500 animate-pulse" />
            <span className="text-[9px] font-bold text-zinc-500 uppercase tracking-tighter">Physics: {config.useAdvancedPhysics ? "Adv" : "Standard"}</span>
          </div>
        </div>
        <div className="flex flex-col items-end gap-1">
          <span className="text-[10px] font-mono text-zinc-500">{config.speed} m/s</span>
          <span className="text-[10px] font-mono text-zinc-500">{config.gravityY} G</span>
        </div>
      </div>
    </div>
  );
};

const LogicNode = ({ title, desc, icon: Icon, delay = 0 }: { title: string, desc: string, icon: any, delay?: number }) => (
  <motion.div
    initial={{ opacity: 0, scale: 0.9, y: 20 }}
    whileInView={{ opacity: 1, scale: 1, y: 0 }}
    viewport={{ once: true }}
    transition={{ delay, duration: 0.5 }}
    className="gf-panel p-4 rounded-2xl border border-white/5 bg-white/[0.02] relative group"
  >
    <div className="flex items-start gap-4">
      <div className="h-10 w-10 rounded-xl bg-indigo-500/10 flex items-center justify-center text-indigo-400 shrink-0 group-hover:bg-indigo-500/20 transition-colors">
        <Icon size={20} />
      </div>
      <div className="min-w-0">
        <div className="text-[10px] font-black text-white uppercase tracking-widest leading-none mb-1">{title}</div>
        <p className="text-[10px] text-zinc-500 font-medium leading-relaxed line-clamp-2">{desc}</p>
      </div>
    </div>
  </motion.div>
);

const LogicVisualizer = ({ project }: { project: any }) => {
  const nodes = [
    { title: "Input Mapping", desc: "Adaptive control binding for WebGL/Touch", icon: ZapIcon },
    { title: "Physics Matrix", desc: `Gravity: ${project?.gravityY} | Speed: ${project?.speed}`, icon: Activity },
    { title: "Collision Core", desc: project?.useAdvancedPhysics ? "High-fidelity kinematic solver" : "Standard axis-aligned logic", icon: Box },
    { title: "Asset Pipeline", desc: "Streaming neural texture compression", icon: Layers },
  ];

  return (
    <div className="relative">
      {/* Background connecting lines (SVG) */}
      <svg className="absolute inset-0 w-full h-full pointer-events-none opacity-10">
        <line x1="50%" y1="0" x2="50%" y2="100%" stroke="white" strokeWidth="1" strokeDasharray="4 4" />
      </svg>
      
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 relative z-10">
        {nodes.map((n, i) => (
          <LogicNode key={i} {...n} delay={i * 0.1} />
        ))}
      </div>
    </div>
  );
};

export default function StudioProjectDetailsPage() {
  const router = useRouter();
  const params = useParams<{ id: string }>();
  const token = useMemo(() => getUserToken(), []);
  const id = (params?.id || "").toString();

  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [project, setProject] = useState<any | null>(null);
  const [busy, setBusy] = useState<string | null>(null);

  const [previewUrl, setPreviewUrl] = useState<string | null>(null);
  const [draft, setDraft] = useState<any>({});
  const [dirty, setDirty] = useState(false);
  const [autoApply, setAutoApply] = useState(true);
  const [toast, setToast] = useState<{ id: number; kind: "ok" | "err" | "info"; msg: string } | null>(null);
  const [iframeNonce, setIframeNonce] = useState(0);
  const autoSaveTimerRef = useRef<any>(null);

  const showToast = (kind: "ok" | "err" | "info", msg: string) => {
    const id = Date.now() + Math.floor(Math.random() * 1000);
    setToast({ id, kind, msg });
    window.setTimeout(() => {
      setToast((t) => (t?.id === id ? null : t));
    }, 2400);
  };

  useEffect(() => {
    let cancelled = false;
    async function load() {
      if (!token || !id) return;
      setLoading(true);
      setError(null);
      try {
        const p = await apiFetch<any>(`/projects/${encodeURIComponent(id)}`, { method: "GET", token });
        const data = (p && typeof p === "object" && "data" in p) ? (p as any).data : p;
        if (!cancelled) {
          setProject(data);
          const cfg = (data?.aiUnityConfig && typeof data.aiUnityConfig === "object") ? data.aiUnityConfig : {};
          setDraft({
            name: (data?.name ?? "").toString(),
            speed: typeof cfg.speed === "number" ? cfg.speed : 7,
            timeScale: typeof cfg.timeScale === "number" ? cfg.timeScale : 1.0,
            difficulty: typeof cfg.difficulty === "number" ? cfg.difficulty : 0.5,
            gravityY: typeof cfg.gravityY === "number" ? cfg.gravityY : -9.8,
            jumpForce: typeof cfg.jumpForce === "number" ? cfg.jumpForce : 12,
            primaryColor: normHex(cfg.primaryColor, "#6366F1"),
            secondaryColor: normHex(cfg.secondaryColor, "#A855F7"),
            accentColor: normHex(cfg.accentColor, "#22D3EE"),
            playerColor: normHex(cfg.playerColor, "#F59E0B"),
          });
          setDirty(false);
        }
      } catch (e: any) {
        if (!cancelled) setError(e instanceof ApiError ? e.message : (e?.message || "Failed to load project"));
      } finally {
        if (!cancelled) setLoading(false);
      }
    }
    load();
    return () => {
      cancelled = true;
    };
  }, [token, id]);

   useEffect(() => {
     let cancelled = false;
     async function loadPreview() {
       if (!token || !id) return;
       try {
         const pr = await apiFetch<any>(`/projects/${encodeURIComponent(id)}/preview-url`, { method: "GET", token });
         const url = (pr as any)?.url || (pr as any)?.data?.url;
         if (!cancelled) setPreviewUrl(typeof url === "string" ? url : null);
       } catch {
         if (!cancelled) setPreviewUrl(null);
       }
     }
     loadPreview();
     return () => {
       cancelled = true;
     };
   }, [token, id, project?.status]);

   useEffect(() => {
     return () => {
       if (autoSaveTimerRef.current) {
         try {
           clearTimeout(autoSaveTimerRef.current);
         } catch {}
         autoSaveTimerRef.current = null;
       }
     };
   }, []);

   const saveDraft = async (opts?: { rebuild?: boolean; silent?: boolean }) => {
     if (!token || !id) return;
     setBusy(opts?.rebuild ? "save_rebuild" : "save");
     setError(null);
     try {
       const payload: any = {
         name: (draft?.name ?? "").toString().trim(),
         speed: clampNum(draft?.speed, 0, 20, 7),
         timeScale: clampNum(draft?.timeScale, 0.5, 2.0, 1.0),
         difficulty: clampNum(draft?.difficulty, 0, 1, 0.5),
         gravityY: clampNum(draft?.gravityY, -50, 0, -9.8),
         jumpForce: clampNum(draft?.jumpForce, 0, 50, 12),
         primaryColor: normHex(draft?.primaryColor, "#6366F1"),
         secondaryColor: normHex(draft?.secondaryColor, "#A855F7"),
         accentColor: normHex(draft?.accentColor, "#22D3EE"),
         playerColor: normHex(draft?.playerColor, "#F59E0B"),
       };

       const updated = await apiFetch<any>(`/projects/${encodeURIComponent(id)}`, { method: "PUT", token, body: payload });
       setProject(updated);
       setDraft((d: any) => ({ ...d, ...payload }));
       setDirty(false);

       if (!opts?.silent) showToast("ok", opts?.rebuild ? "Saved. Rebuilding…" : "Saved");

       if (opts?.rebuild) {
         await apiFetch(`/projects/${encodeURIComponent(id)}/rebuild`, { method: "POST", token });
         router.push(`/studio/builds/progress?projectId=${encodeURIComponent(id)}`);
       }
     } catch (e: any) {
       setError(e instanceof ApiError ? e.message : (e?.message || "Save failed"));
       showToast("err", e instanceof ApiError ? e.message : (e?.message || "Save failed"));
     } finally {
       setBusy(null);
     }
   };

  useEffect(() => {
    if (!autoApply) return;
    if (!dirty) return;
    if (!token || !id) return;
    if (busy !== null) return;
    if (autoSaveTimerRef.current) {
      try {
        clearTimeout(autoSaveTimerRef.current);
      } catch {}
    }
    autoSaveTimerRef.current = window.setTimeout(() => {
      autoSaveTimerRef.current = null;
      saveDraft({ silent: true }).catch(() => null);
      showToast("info", "Auto-applied");
    }, 700);
  }, [autoApply, dirty, draft, token, id, busy]);

  const title = project?.name?.trim() ? project.name : "Project";
  const status = (project?.status ?? "").toString().toLowerCase();

  return (
    <UserShell
      title={title}
      subtitle={project?.status ? `Build Status: ${project.status.toUpperCase()}` : "System Analysis"}
      right={
        <div className="flex gap-2">
          <button className="gf-btn rounded-xl px-4 py-2 text-xs font-bold text-zinc-400" onClick={() => router.push("/studio/projects")}>
            Exit
          </button>
          <button className="gf-glow rounded-xl bg-indigo-500 px-4 py-2 text-xs font-black uppercase tracking-widest text-white transition-all hover:scale-105 active:scale-95 shadow-[0_10px_25px_rgba(99,102,241,0.3)]">
            Publish
          </button>
        </div>
      }
    >
      {toast ? (
        <motion.div
          key={toast.id}
          initial={{ opacity: 0, y: -10, scale: 0.98 }}
          animate={{ opacity: 1, y: 0, scale: 1 }}
          exit={{ opacity: 0, y: -10, scale: 0.98 }}
          transition={{ duration: 0.25 }}
          className={
            "mb-4 rounded-2xl border px-4 py-3 text-sm " +
            (toast.kind === "ok"
              ? "border-emerald-500/20 bg-emerald-500/10 text-emerald-100"
              : toast.kind === "err"
                ? "border-red-500/20 bg-red-500/10 text-red-200"
                : "border-indigo-500/20 bg-indigo-500/10 text-indigo-100")
          }
        >
          {toast.msg}
        </motion.div>
      ) : null}

      {error ? <div className="mb-4 rounded-2xl border border-red-500/20 bg-red-500/10 px-4 py-3 text-sm text-red-200">{error}</div> : null}

      <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 pb-20">
        
        {/* Left Column: Sandbox & Actions */}
        <div className="lg:col-span-8 space-y-8">
          <div className="gf-panel-strong gf-stroke-gradient rounded-[40px] p-10">
            <div className="flex items-center justify-between mb-8">
              <div className="flex items-center gap-4">
                <div className="h-12 w-12 rounded-2xl bg-indigo-500/20 flex items-center justify-center text-indigo-400">
                  <Play size={24} fill="currentColor" />
                </div>
                <div>
                  <h3 className="text-2xl font-bold text-white tracking-tight">Interactive Sandbox</h3>
                  <p className="text-sm text-zinc-500 font-medium">Real-time parameter simulation</p>
                </div>
              </div>
              <div className="flex items-center gap-2">
                <button
                  className="gf-btn rounded-2xl p-3 text-zinc-400 hover:text-white transition-all"
                  onClick={async () => {
                    if (!token || !id) return;
                    try {
                      const pr = await apiFetch<any>(`/projects/${encodeURIComponent(id)}/preview-url`, { method: "GET", token });
                      const url = (pr as any)?.url || (pr as any)?.data?.url;
                      setPreviewUrl(typeof url === "string" ? url : null);
                      setIframeNonce((n) => n + 1);
                      showToast("info", "Preview refreshed");
                    } catch (e: any) {
                      showToast("err", e instanceof ApiError ? e.message : (e?.message || "Refresh failed"));
                    }
                  }}
                >
                  <RefreshCcw size={20} />
                </button>
                <button
                  className="gf-btn rounded-2xl px-4 py-3 text-[10px] font-black uppercase tracking-widest text-zinc-400 hover:text-white transition-all disabled:opacity-30"
                  disabled={!previewUrl}
                  onClick={() => {
                    if (previewUrl) window.open(previewUrl, "_blank");
                  }}
                >
                  Fullscreen
                </button>
              </div>
            </div>

            <SandboxPreview
              key={previewUrl ? `${previewUrl}::${iframeNonce}` : `fallback::${iframeNonce}`}
              config={{ ...(project || {}), ...(draft || {}) }}
              previewUrl={previewUrl}
            />

            <div className="mt-8 space-y-4">
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <button
                  className="group relative flex flex-col justify-between overflow-hidden rounded-[28px] border border-indigo-500/20 bg-indigo-500/5 p-6 text-left transition-all hover:bg-indigo-500/10 hover:scale-[1.02] active:scale-[0.98]"
                  onClick={() => router.push(`/studio/builds/progress?projectId=${encodeURIComponent(id)}`)}
                >
                  <div className="h-10 w-10 rounded-2xl bg-indigo-500/20 flex items-center justify-center text-indigo-400 mb-8">
                    <Activity size={20} />
                  </div>
                  <div>
                    <div className="text-sm font-bold text-white uppercase tracking-wider">Live Pipeline</div>
                    <div className="mt-1 text-xs text-zinc-500 font-medium">Monitor build process</div>
                  </div>
                </button>

                <button
                  className="group relative flex flex-col justify-between overflow-hidden rounded-[28px] border border-white/5 bg-white/[0.03] p-6 text-left transition-all hover:bg-white/[0.06] hover:scale-[1.02] active:scale-[0.98] disabled:opacity-30"
                  disabled={status !== "ready"}
                  onClick={async () => {
                    if (!token || !id) return;
                    const pr = await apiFetch<any>(`/projects/${encodeURIComponent(id)}/preview-url`, { method: "GET", token });
                    const url = (pr?.data || pr)?.url;
                    if (url) window.open(url, "_blank");
                  }}
                >
                  <div className="h-10 w-10 rounded-2xl bg-emerald-500/20 flex items-center justify-center text-emerald-400 mb-8">
                    <Globe size={20} />
                  </div>
                  <div>
                    <div className="text-sm font-bold text-white uppercase tracking-wider">WebGL Preview</div>
                    <div className="mt-1 text-xs text-zinc-500 font-medium">Run in full screen</div>
                  </div>
                </button>
              </div>

              {/* Native Downloads Row */}
              {status === "ready" && (project?.androidApkStorageKey || project?.macosZipStorageKey || project?.windowsZipStorageKey) && (
                <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
                  {project?.androidApkStorageKey && (
                    <button
                      onClick={async () => {
                        const res = await apiFetch<any>(`/projects/${id}/download-url?target=android`, { method: 'GET', token });
                        const url = res?.data?.url || res?.url;
                        if (url) window.open(url, '_blank');
                      }}
                      className="group flex items-center gap-4 rounded-2xl border border-white/5 bg-white/[0.02] p-4 text-left transition-all hover:bg-white/[0.05]"
                    >
                      <div className="h-10 w-10 shrink-0 rounded-xl bg-emerald-500/10 flex items-center justify-center text-emerald-400">
                        <Smartphone size={20} />
                      </div>
                      <div className="min-w-0">
                        <div className="text-[10px] font-black text-white uppercase tracking-widest leading-none mb-1">Android Build</div>
                        <div className="text-[9px] text-zinc-500 font-bold uppercase tracking-tighter flex items-center gap-1">
                          Download APK <Download size={10} />
                        </div>
                      </div>
                    </button>
                  )}

                  {project?.macosZipStorageKey && (
                    <button
                      onClick={async () => {
                        const res = await apiFetch<any>(`/projects/${id}/download-url?target=macos`, { method: 'GET', token });
                        const url = res?.data?.url || res?.url;
                        if (url) window.open(url, '_blank');
                      }}
                      className="group flex items-center gap-4 rounded-2xl border border-white/5 bg-white/[0.02] p-4 text-left transition-all hover:bg-white/[0.05]"
                    >
                      <div className="h-10 w-10 shrink-0 rounded-xl bg-indigo-500/10 flex items-center justify-center text-indigo-400">
                        <Monitor size={20} />
                      </div>
                      <div className="min-w-0">
                        <div className="text-[10px] font-black text-white uppercase tracking-widest leading-none mb-1">macOS Build</div>
                        <div className="text-[9px] text-zinc-500 font-bold uppercase tracking-tighter flex items-center gap-1">
                          Download ZIP <Download size={10} />
                        </div>
                      </div>
                    </button>
                  )}

                  {project?.windowsZipStorageKey && (
                    <button
                      onClick={async () => {
                        const res = await apiFetch<any>(`/projects/${id}/download-url?target=windows`, { method: 'GET', token });
                        const url = res?.data?.url || res?.url;
                        if (url) window.open(url, '_blank');
                      }}
                      className="group flex items-center gap-4 rounded-2xl border border-white/5 bg-white/[0.02] p-4 text-left transition-all hover:bg-white/[0.05]"
                    >
                      <div className="h-10 w-10 shrink-0 rounded-xl bg-blue-500/10 flex items-center justify-center text-blue-400">
                        <Monitor size={20} />
                      </div>
                      <div className="min-w-0">
                        <div className="text-[10px] font-black text-white uppercase tracking-widest leading-none mb-1">Windows Build</div>
                        <div className="text-[9px] text-zinc-500 font-bold uppercase tracking-tighter flex items-center gap-1">
                          Download EXE <Download size={10} />
                        </div>
                      </div>
                    </button>
                  )}
                </div>
              )}
            </div>
          </div>

          {/* Advanced Logic Visualizer */}
          <div className="gf-panel rounded-[40px] p-10">
            <div className="flex items-center gap-4 mb-10">
              <div className="h-10 w-10 rounded-xl bg-white/5 flex items-center justify-center text-indigo-400 shadow-[0_0_15px_rgba(99,102,241,0.2)]">
                <Settings2 size={20} />
              </div>
              <div>
                <h3 className="text-xl font-bold text-white tracking-tight">Engine Intelligence</h3>
                <p className="text-xs text-zinc-500 font-medium uppercase tracking-widest mt-1">Neural Mapping Matrix</p>
              </div>
            </div>

            <LogicVisualizer project={project} />
          </div>

          {/* Live Multiplayer Previewer */}
          <div className="gf-panel rounded-[40px] p-10 relative overflow-hidden group">
            <div className="absolute inset-0 bg-gradient-to-br from-cyan-500/5 via-transparent to-transparent opacity-50" />
            <div className="relative z-10">
              <div className="flex items-center justify-between mb-10">
                <div className="flex items-center gap-4">
                  <div className="h-10 w-10 rounded-xl bg-cyan-500/10 flex items-center justify-center text-cyan-400">
                    <Globe size={20} />
                  </div>
                  <div>
                    <h3 className="text-xl font-bold text-white tracking-tight italic uppercase">Network Lobby</h3>
                    <p className="text-[10px] text-zinc-500 font-bold uppercase tracking-widest mt-1">Real-time Synchronization</p>
                  </div>
                </div>
                <div className="px-3 py-1.5 rounded-full bg-emerald-500/10 border border-emerald-500/20 flex items-center gap-2">
                  <div className="h-1.5 w-1.5 rounded-full bg-emerald-500 animate-pulse" />
                  <span className="text-[9px] font-black text-emerald-400 uppercase tracking-widest">Server Live</span>
                </div>
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-3 gap-6">
                {[
                  { name: "Player_Alpha", ping: "24ms", status: "Connected" },
                  { name: "Game_Master", ping: "12ms", status: "Syncing" },
                  { name: "Nova_01", ping: "45ms", status: "Idle" },
                ].map((p, i) => (
                  <div key={i} className="p-4 rounded-2xl bg-white/[0.02] border border-white/5 flex items-center justify-between group-hover:bg-white/[0.04] transition-all">
                    <div className="flex items-center gap-3">
                      <div className="h-8 w-8 rounded-lg bg-zinc-800 flex items-center justify-center text-[10px] font-black text-zinc-500">
                        {p.name[0]}
                      </div>
                      <div className="text-[10px] font-bold text-white uppercase tracking-tight">{p.name}</div>
                    </div>
                    <div className="text-right">
                      <div className="text-[9px] font-mono text-cyan-400">{p.ping}</div>
                    </div>
                  </div>
                ))}
              </div>

              <div className="mt-8 pt-8 border-t border-white/5 flex items-center justify-between">
                <div className="flex gap-4">
                  <div className="text-[9px] font-black text-zinc-600 uppercase tracking-widest">Protocol: <span className="text-white">UDP_FORGE</span></div>
                  <div className="text-[9px] font-black text-zinc-600 uppercase tracking-widest">Encryption: <span className="text-white">AES-256</span></div>
                </div>
                <button className="text-[9px] font-black text-indigo-400 uppercase tracking-[0.2em] hover:text-white transition-colors">
                  Open Debug Console
                </button>
              </div>
            </div>
          </div>
        </div>

        {/* Right Column: Identity & Build */}
        <div className="lg:col-span-4 space-y-8">
          <div className="gf-panel-strong gf-stroke-gradient rounded-[40px] p-8 space-y-8 sticky top-24 shadow-2xl">
            <div className="aspect-[16/10] rounded-[24px] overflow-hidden border border-white/5 relative group bg-black/40">
              <img 
                src={normalizeImageUrl(project?.previewImageUrl || project?.thumbnailUrl)} 
                alt="" 
                className="w-full h-full object-cover grayscale opacity-30 group-hover:grayscale-0 group-hover:opacity-100 transition-all duration-700"
              />
              <div className="absolute inset-0 bg-gradient-to-t from-black/80 via-transparent to-transparent opacity-60" />
              <div className="absolute bottom-4 left-4">
                <div className="text-[9px] font-black text-indigo-400 uppercase tracking-[0.2em] bg-indigo-500/10 px-3 py-1 rounded-full border border-indigo-500/20 mb-2 inline-block">
                  Visual Identity
                </div>
                <div className="text-white font-bold tracking-tight">{title}</div>
              </div>
            </div>

            <div className="space-y-4 pt-4 border-t border-white/5">
              <div className="flex justify-between items-center text-[10px] font-black tracking-widest leading-none">
                <span className="text-zinc-600 uppercase">Platform</span>
                <span className="text-white uppercase">{(project?.buildTarget || "webgl")}</span>
              </div>
              <div className="flex justify-between items-center text-[10px] font-black tracking-widest leading-none">
                <span className="text-zinc-600 uppercase">Engine</span>
                <span className="text-white uppercase">Neural Weaver v4</span>
              </div>
              <div className="flex justify-between items-center text-[10px] font-black tracking-widest leading-none">
                <span className="text-zinc-600 uppercase">Status</span>
                <span className={`font-bold ${status === "ready" ? "text-emerald-400" : "text-amber-400"}`}>
                  {status.toUpperCase()}
                </span>
              </div>
            </div>

            <div className="space-y-3 pt-4">
              <motion.div
                initial={{ opacity: 0, y: 12 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ duration: 0.5 }}
                className="rounded-[24px] border border-white/5 bg-white/[0.02] p-5 space-y-4"
              >
                <div className="flex items-center justify-between">
                  <div>
                    <div className="text-[10px] font-black uppercase tracking-widest text-zinc-400">Live Config</div>
                    <div className="mt-1 text-sm font-semibold text-white">Sandbox Controls</div>
                  </div>
                  <div className={`text-[10px] font-black uppercase tracking-widest ${dirty ? "text-amber-300" : "text-emerald-400"}`}>
                    {dirty ? "UNSAVED" : "SYNCED"}
                  </div>
                </div>

                <button
                  onClick={() => {
                    setAutoApply((v) => !v);
                    showToast("info", !autoApply ? "Auto-Apply ON" : "Auto-Apply OFF");
                  }}
                  className={
                    "w-full rounded-xl border px-3 py-2 text-[10px] font-black uppercase tracking-widest transition-all " +
                    (autoApply
                      ? "border-emerald-500/20 bg-emerald-500/10 text-emerald-200 hover:bg-emerald-500/15"
                      : "border-white/10 bg-black/30 text-zinc-300 hover:bg-white/[0.06]")
                  }
                >
                  Auto-Apply: {autoApply ? "ON" : "OFF"}
                </button>

                <div className="space-y-2">
                  <div className="text-[10px] font-black uppercase tracking-widest text-zinc-500">Name</div>
                  <input
                    value={(draft?.name ?? "").toString()}
                    onChange={(e) => {
                      const v = e.target.value;
                      setDraft((d: any) => ({ ...d, name: v }));
                      setDirty(true);
                    }}
                    className="w-full rounded-xl border border-white/10 bg-black/30 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500/40"
                    placeholder="Project name"
                  />
                </div>

                <div className="grid grid-cols-1 gap-4">
                  <div className="space-y-2">
                    <div className="flex items-center justify-between">
                      <div className="text-[10px] font-black uppercase tracking-widest text-zinc-500">Speed</div>
                      <div className="text-[10px] font-mono text-zinc-400">{clampNum(draft?.speed, 0, 20, 7).toFixed(1)}</div>
                    </div>
                    <input
                      type="range"
                      min={0}
                      max={20}
                      step={0.1}
                      value={clampNum(draft?.speed, 0, 20, 7)}
                      onChange={(e) => {
                        const v = Number(e.target.value);
                        setDraft((d: any) => ({ ...d, speed: v }));
                        setDirty(true);
                      }}
                      className="w-full"
                    />
                  </div>

                  <div className="space-y-2">
                    <div className="flex items-center justify-between">
                      <div className="text-[10px] font-black uppercase tracking-widest text-zinc-500">Time Scale</div>
                      <div className="text-[10px] font-mono text-zinc-400">{clampNum(draft?.timeScale, 0.5, 2.0, 1.0).toFixed(2)}</div>
                    </div>
                    <input
                      type="range"
                      min={0.5}
                      max={2}
                      step={0.01}
                      value={clampNum(draft?.timeScale, 0.5, 2.0, 1.0)}
                      onChange={(e) => {
                        const v = Number(e.target.value);
                        setDraft((d: any) => ({ ...d, timeScale: v }));
                        setDirty(true);
                      }}
                      className="w-full"
                    />
                  </div>

                  <div className="space-y-2">
                    <div className="flex items-center justify-between">
                      <div className="text-[10px] font-black uppercase tracking-widest text-zinc-500">Difficulty</div>
                      <div className="text-[10px] font-mono text-zinc-400">{clampNum(draft?.difficulty, 0, 1, 0.5).toFixed(2)}</div>
                    </div>
                    <input
                      type="range"
                      min={0}
                      max={1}
                      step={0.01}
                      value={clampNum(draft?.difficulty, 0, 1, 0.5)}
                      onChange={(e) => {
                        const v = Number(e.target.value);
                        setDraft((d: any) => ({ ...d, difficulty: v }));
                        setDirty(true);
                      }}
                      className="w-full"
                    />
                  </div>

                  <div className="grid grid-cols-2 gap-4">
                    <div className="space-y-2">
                      <div className="flex items-center justify-between">
                        <div className="text-[10px] font-black uppercase tracking-widest text-zinc-500">Gravity Y</div>
                        <div className="text-[10px] font-mono text-zinc-400">{clampNum(draft?.gravityY, -50, 0, -9.8).toFixed(1)}</div>
                      </div>
                      <input
                        type="number"
                        value={clampNum(draft?.gravityY, -50, 0, -9.8)}
                        onChange={(e) => {
                          const v = Number(e.target.value);
                          setDraft((d: any) => ({ ...d, gravityY: v }));
                          setDirty(true);
                        }}
                        className="w-full rounded-xl border border-white/10 bg-black/30 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500/40"
                      />
                    </div>
                    <div className="space-y-2">
                      <div className="flex items-center justify-between">
                        <div className="text-[10px] font-black uppercase tracking-widest text-zinc-500">Jump Force</div>
                        <div className="text-[10px] font-mono text-zinc-400">{clampNum(draft?.jumpForce, 0, 50, 12).toFixed(1)}</div>
                      </div>
                      <input
                        type="number"
                        value={clampNum(draft?.jumpForce, 0, 50, 12)}
                        onChange={(e) => {
                          const v = Number(e.target.value);
                          setDraft((d: any) => ({ ...d, jumpForce: v }));
                          setDirty(true);
                        }}
                        className="w-full rounded-xl border border-white/10 bg-black/30 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500/40"
                      />
                    </div>
                  </div>

                  <div className="grid grid-cols-2 gap-4">
                    {[
                      { k: "primaryColor", label: "Primary" },
                      { k: "secondaryColor", label: "Secondary" },
                      { k: "accentColor", label: "Accent" },
                      { k: "playerColor", label: "Player" },
                    ].map((c) => (
                      <div key={c.k} className="space-y-2">
                        <div className="text-[10px] font-black uppercase tracking-widest text-zinc-500">{c.label}</div>
                        <div className="flex items-center gap-2">
                          <input
                            type="color"
                            value={normHex((draft as any)?.[c.k], "#6366F1")}
                            onChange={(e) => {
                              const v = e.target.value;
                              setDraft((d: any) => ({ ...d, [c.k]: v }));
                              setDirty(true);
                            }}
                            className="h-9 w-10 rounded-lg border border-white/10 bg-black/30"
                          />
                          <input
                            value={normHex((draft as any)?.[c.k], "#6366F1")}
                            onChange={(e) => {
                              const v = e.target.value;
                              setDraft((d: any) => ({ ...d, [c.k]: v }));
                              setDirty(true);
                            }}
                            className="w-full rounded-xl border border-white/10 bg-black/30 px-3 py-2 text-xs font-mono text-white outline-none focus:border-indigo-500/40"
                          />
                        </div>
                      </div>
                    ))}
                  </div>
                </div>

                <div className="grid grid-cols-1 gap-3">
                  <button
                    onClick={() => saveDraft()}
                    disabled={busy !== null || !dirty}
                    className="w-full rounded-[18px] bg-white text-black py-4 font-black uppercase tracking-widest shadow-xl hover:scale-[1.02] active:scale-95 transition-all disabled:opacity-30"
                  >
                    {busy === "save" ? "Saving…" : dirty ? "Save" : "Saved"}
                  </button>
                  <button
                    onClick={() => saveDraft({ rebuild: true })}
                    disabled={busy !== null}
                    className="w-full gf-glow rounded-[18px] bg-indigo-500 py-4 text-[10px] font-black uppercase tracking-widest text-white transition-all hover:scale-[1.03] active:scale-95 shadow-[0_10px_25px_rgba(99,102,241,0.3)] disabled:opacity-30"
                  >
                    {busy === "save_rebuild" ? "Saving & Rebuilding…" : "Save & Rebuild"}
                  </button>
                </div>
              </motion.div>

              <button 
                onClick={async () => {
                  setBusy("rebuild");
                  await apiFetch(`/projects/${id}/rebuild`, { method: "POST", token });
                  router.push(`/studio/builds/progress?projectId=${id}`);
                }}
                disabled={busy !== null}
                className="w-full rounded-[24px] bg-white text-black py-5 font-black uppercase tracking-widest shadow-xl hover:scale-[1.03] active:scale-95 transition-all flex items-center justify-center gap-3 disabled:opacity-30"
              >
                {busy === "rebuild" ? (
                  <div className="h-4 w-4 border-2 border-black/30 border-t-black animate-spin rounded-full" />
                ) : (
                  <>Re-Bake Engine <ZapIcon size={20} fill="currentColor" /></>
                )}
              </button>
              <button 
                className="w-full gf-btn rounded-[24px] py-4 text-[10px] font-black uppercase tracking-widest text-zinc-500 hover:text-white transition-colors"
                onClick={async () => {
                  const dl = await apiFetch<any>(`/projects/${encodeURIComponent(id)}/download-url`, { method: "GET", token });
                  const url = (dl?.data || dl)?.url;
                  if (url) window.open(url, "_blank");
                }}
                disabled={status !== "ready"}
              >
                Download Package
              </button>
            </div>
          </div>
        </div>

      </div>
    </UserShell>
  );
}
