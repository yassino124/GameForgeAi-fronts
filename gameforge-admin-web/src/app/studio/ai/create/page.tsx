"use client";

import { useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import UserShell from "@/app/_components/UserShell";
import { apiFetch, ApiError } from "@/lib/api";
import { getUserToken } from "@/lib/userAuth";
import { normalizeImageUrl } from "@/lib/media";
import { Activity, Sparkles, Wand2, Hammer, Layout, Check, ArrowRight, Zap, Target, Palette, Cpu, Volume2 } from "lucide-react";

// Types
type GDD = {
  genre: string;
  title: string;
  description: string;
  difficulty: number;
  theme: string;
  mechanics: string[];
  playerSpeed: number;
  primaryColor: string;
  backgroundColor: string;
};

type Template = {
  id?: string;
  _id?: string;
  name?: string;
  title?: string;
  description?: string;
  category?: string;
  previewImageUrl?: string;
  thumbnailUrl?: string;
  imageUrl?: string;
};

export default function AiCreatePage() {
  const router = useRouter();

  const [prompt, setPrompt] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // New States
  const [mode, setMode] = useState<"blueprint" | "scratch">("blueprint");
  const [gdd, setGdd] = useState<GDD | null>(null);
  const [showGdd, setShowGdd] = useState(false);

  const [suggestLoading, setSuggestLoading] = useState(false);
  const [suggestions, setSuggestions] = useState<Template[]>([]);
  const [selectedTemplateId, setSelectedTemplateId] = useState<string>("");

  // Clear error when prompt changes
  useEffect(() => {
    if (prompt.trim() && error) setError(null);
  }, [prompt, error]);

  useEffect(() => {
    if (mode !== "blueprint") return;
    const token = getUserToken();
    let cancelled = false;
    const ac = new AbortController();

    async function loadSuggestions() {
      const q = prompt.trim();
      if (q.length < 3) {
        setSuggestions([]);
        setSelectedTemplateId("");
        setSuggestLoading(false);
        return;
      }

      setSuggestLoading(true);
      try {
        const qp = new URLSearchParams();
        qp.set("q", q);
        const res = await apiFetch<any>(`/templates?${qp.toString()}`, { method: "GET", token: token || undefined, signal: ac.signal });
        const data = (res && typeof res === "object" && "data" in res) ? (res as any).data : res;
        const list = Array.isArray((data as any)?.data) ? (data as any).data : (Array.isArray(data) ? data : []);
        const items = list
          .filter(Boolean)
          .slice(0, 6)
          .map((t: any) => (t && typeof t === "object" ? (t as Template) : ({} as Template)));
        if (!cancelled) {
          setSuggestions(items);
        }
      } catch {
        // ignore
      } finally {
        if (!cancelled) setSuggestLoading(false);
      }
    }

    const t = setTimeout(loadSuggestions, 420);
    return () => {
      cancelled = true;
      clearTimeout(t);
      ac.abort();
    };
  }, [prompt, mode]);

  async function handleAction() {
    console.log("handleAction triggered", { mode, prompt, gdd });
    const token = getUserToken();
    if (!token) {
      console.warn("No token found, redirecting to signin");
      router.push("/signin");
      return;
    }
    const p = prompt.trim();
    if (!p) {
      setError("Please enter a prompt");
      return;
    }

    setError(null);
    setLoading(true);

    try {
      if (mode === "scratch" && !gdd) {
        console.log(`[FE] POST -> /ai/generate-gdd-preview | Body:`, { prompt: p });
        const res = await apiFetch<any>("/ai/generate-gdd-preview", {
          method: "POST",
          token,
          body: { prompt: p }
        });
        console.log(`[FE] Result:`, res);
        const data = res?.data?.gdd || res?.gdd || res;
        if (!data) throw new Error("Failed to generate GDD - No data returned from engine");
        setGdd(data);
        setShowGdd(true);
      } else {
        console.log("Finalizing project creation...");
        await finalizeCreate();
      }
    } catch (e: any) {
      console.error("handleAction failed", e);
      setError(e instanceof ApiError ? e.message : (e?.message || "Synthesis failed - Check your connection"));
    } finally {
      setLoading(false);
    }
  }

  async function finalizeCreate() {
    console.log("[FE] finalizeCreate started", { mode, prompt, selectedTemplateId });
    setLoading(true);
    setError(null);
    try {
      let endpoint = "/projects/ai/create";
      let body: any = { prompt: prompt.trim(), buildTarget: "webgl" };

      if (mode === "scratch") {
        console.log("[FE] Scratch Mode -> /ai/generate-from-scratch");
        endpoint = "/ai/generate-from-scratch";
      } else if (selectedTemplateId) {
        console.log("[FE] Blueprint Mode -> templateId:", selectedTemplateId);
        body.templateId = selectedTemplateId;
      }

      const res = await apiFetch<any>(endpoint, { method: "POST", token: getUserToken(), body });
      console.log("[FE] finalizeCreate Result:", res);
      
      const data = (res && typeof res === "object" && "data" in res) ? (res as any).data : res;
      const payload = (data?.data ?? data) as any;
      const projectId = (payload?.projectId ?? payload?._id ?? payload?.id)?.toString?.() ?? "";
      
      if (!projectId) {
        console.error("[FE] No projectId in response", payload);
        throw new Error("Creation failed: Missing project ID from engine");
      }

      console.log("[FE] Redirecting to build progress:", projectId);
      router.replace(`/studio/builds/progress?projectId=${encodeURIComponent(projectId)}`);
    } catch (e: any) {
      console.error("[FE] finalizeCreate failed", e);
      const msg = e instanceof ApiError ? e.message : (e?.message || "Creation failed - Connection lost");
      setError(msg);
      // Also show alert to ensure user sees it since the modal might be on top
      if (typeof window !== "undefined") {
        window.alert("Forge Initialization Error: " + msg);
      }
      setLoading(false);
    }
  }

  return (
    <UserShell
      title="Create with AI"
      subtitle="Generate a project from a prompt"
      right={
        <button className="gf-btn rounded-xl px-3 py-2 text-sm" onClick={() => router.push("/studio")}>
          Back
        </button>
      }
    >
      {error ? <div className="mb-6 rounded-2xl border border-red-500/20 bg-red-500/10 px-4 py-3 text-sm text-red-200">{error}</div> : null}

      <div className="grid grid-cols-1 lg:grid-cols-12 gap-8">
        <div className="lg:col-span-8 space-y-6">
          {/* Mode Toggle */}
          <div className="flex gap-2 p-1.5 bg-black/40 rounded-2xl border border-white/5 w-fit mb-4">
            <button
              onClick={() => { setMode("blueprint"); setGdd(null); setShowGdd(false); }}
              className={`flex items-center gap-2 px-4 py-2 rounded-xl text-xs font-black uppercase tracking-widest transition-all ${
                mode === "blueprint" ? "bg-indigo-500 text-white shadow-lg" : "text-zinc-500 hover:text-white"
              }`}
            >
              <Layout size={14} /> Blueprint Mode
            </button>
            <button
              onClick={() => setMode("scratch")}
              className={`flex items-center gap-2 px-4 py-2 rounded-xl text-xs font-black uppercase tracking-widest transition-all ${
                mode === "scratch" ? "bg-gradient-to-r from-fuchsia-600 to-indigo-600 text-white shadow-lg" : "text-zinc-500 hover:text-white"
              }`}
            >
              <Wand2 size={14} /> Magic Forge
            </button>
          </div>

          <div className="gf-panel-strong rounded-[32px] p-8 border border-white/5 relative overflow-hidden group/vision shadow-2xl">
            <div className="absolute inset-0 bg-gradient-to-br from-indigo-500/10 via-transparent to-fuchsia-500/5 pointer-events-none opacity-50" />
            
            <div className="flex items-center gap-4 mb-8">
              <div className="h-12 w-12 rounded-2xl bg-gradient-to-br from-indigo-500 to-fuchsia-600 flex items-center justify-center text-white shadow-lg shadow-indigo-500/20">
                <Sparkles size={24} className="animate-pulse" />
              </div>
              <div>
                <h3 className="text-2xl font-black text-white italic uppercase tracking-tighter">The Vision</h3>
                <p className="text-[10px] font-bold text-zinc-500 uppercase tracking-widest mt-0.5">Neural Synthesis Input</p>
              </div>
            </div>

            <div className="relative group/input">
              <div className="absolute -inset-0.5 bg-gradient-to-r from-indigo-500 to-fuchsia-500 rounded-[22px] opacity-0 group-focus-within/input:opacity-30 blur-md transition-all duration-500" />
              <textarea
                className="gf-input relative w-full rounded-2xl px-6 py-5 text-base bg-black/80 border-2 border-white/5 placeholder:text-zinc-800 focus:border-indigo-500/50 transition-all shadow-2xl min-h-[220px] leading-relaxed font-medium"
                value={prompt}
                onChange={(e) => setPrompt(e.target.value)}
                placeholder={mode === "blueprint" 
                  ? "Example: A neon runner where the player dodges obstacles..." 
                  : "Deep prompt: A zero-gravity physics racer with black-hole mechanics and synthwave aesthetic..."}
              />
            </div>

            <div className="mt-8 flex items-center justify-between">
              <div className="flex items-center gap-4">
                 {mode === "blueprint" && (
                   <div className="flex items-center gap-2 px-3 py-1.5 rounded-full bg-white/5 border border-white/5">
                     <div className={`h-2 w-2 rounded-full ${suggestLoading ? "bg-indigo-500 animate-pulse shadow-[0_0_8px_rgba(99,102,241,1)]" : "bg-emerald-500"}`} />
                     <span className="text-[9px] font-black text-zinc-400 uppercase tracking-widest">
                       {suggestLoading ? "Searching Neural Patterns..." : suggestions.length ? `${suggestions.length} Blueprints available` : "Awaiting Pattern"}
                     </span>
                   </div>
                 )}
              </div>

              <button
                className="group relative overflow-hidden rounded-2xl bg-white text-black px-10 py-4 font-black uppercase tracking-[0.2em] text-xs shadow-[0_0_40px_rgba(255,255,255,0.1)] transition-all hover:scale-105 active:scale-95 disabled:opacity-50 hover:shadow-[0_0_60px_rgba(255,255,255,0.2)]"
                disabled={loading}
                onClick={handleAction}
              >
                <span className="relative z-10 flex items-center gap-3">
                  {loading ? "Aligning Matrices..." : mode === "scratch" ? (gdd ? "Forge Reality" : "Analyze Vision") : "Spawn Blueprint"} 
                  <ArrowRight size={18} className="group-hover:translate-x-1 transition-transform" />
                </span>
                <div className="absolute inset-0 bg-gradient-to-r from-transparent via-indigo-500/10 to-transparent -translate-x-full group-hover:translate-x-full transition-transform duration-1000" />
              </button>
            </div>
          </div>

          {mode === "blueprint" && suggestions.length > 0 && (
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 animate-in fade-in slide-in-from-bottom-4 duration-500">
              {suggestions.map((t) => {
                const id = (t._id || t.id || "").toString();
                const active = id && id === selectedTemplateId;
                return (
                  <button
                    key={id}
                    onClick={() => setSelectedTemplateId(active ? "" : id)}
                    className={`gf-panel group relative flex items-center gap-4 rounded-[28px] border-2 p-4 text-left transition-all ${
                      active ? "border-indigo-500 bg-indigo-500/10 shadow-lg" : "border-white/5 hover:border-white/10 bg-white/[0.02]"
                    }`}
                  >
                    <div className="h-16 w-16 overflow-hidden rounded-2xl border border-white/10">
                      <img src={normalizeImageUrl(t.previewImageUrl || t.thumbnailUrl) ?? undefined} alt="" className="h-full w-full object-cover transition-transform group-hover:scale-110" />
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="truncate text-sm font-black text-white italic uppercase tracking-tight">{t.name}</div>
                      <div className="mt-1 truncate text-[10px] font-bold text-zinc-500 uppercase tracking-widest">{t.category}</div>
                    </div>
                    {active && <Check size={20} className="text-indigo-400" />}
                  </button>
                );
              })}
            </div>
          )}
        </div>

        <div className="lg:col-span-4">
          <div className="sticky top-24 space-y-6">
            <div className={`gf-panel-strong rounded-[32px] p-8 border border-white/10 transition-all duration-700 ${mode === "scratch" ? "bg-indigo-500/5 shadow-[0_0_50px_rgba(99,102,241,0.1)]" : "opacity-60"}`}>
               <h4 className="text-xs font-black text-white uppercase tracking-[0.3em] mb-6 flex items-center gap-2">
                 <Cpu size={14} className="text-indigo-400" /> System Engine
               </h4>
               
               <div className="space-y-6">
                 <div className="flex items-center justify-between">
                   <span className="text-[10px] font-black text-zinc-500 uppercase tracking-widest">Logic Engine</span>
                   <span className="px-3 py-1 rounded-full bg-white/5 text-[9px] font-black text-white border border-white/5">
                     {mode === "scratch" ? "Gemini Neural-Scratch" : "Blueprint Instance"}
                   </span>
                 </div>
                 <div className="flex items-center justify-between">
                   <span className="text-[10px] font-black text-zinc-500 uppercase tracking-widest">Physics Mode</span>
                   <span className="text-[9px] font-black text-emerald-400">High Precision</span>
                 </div>
                 <div className="flex items-center justify-between">
                   <span className="text-[10px] font-black text-zinc-500 uppercase tracking-widest">Build Target</span>
                   <span className="text-[9px] font-black text-white uppercase">WebGL 2.0</span>
                 </div>

                 <div className="pt-6 border-t border-white/5">
                   <div className="flex items-center gap-4 text-zinc-500">
                     <Activity size={16} className="animate-pulse text-indigo-500" />
                     <div className="flex-1 h-1.5 bg-white/5 rounded-full overflow-hidden">
                       <div className="h-full bg-indigo-500 w-[45%]" />
                     </div>
                   </div>
                   <p className="mt-3 text-[9px] font-black text-zinc-600 uppercase tracking-widest text-center">Neural Link Stable</p>
                 </div>
               </div>
            </div>

            {mode === "scratch" && (
              <div className="gf-panel rounded-[24px] p-6 border border-amber-500/20 bg-amber-500/5">
                <div className="flex gap-4">
                  <Zap size={24} className="text-amber-400 shrink-0" />
                  <div>
                    <p className="text-[10px] font-black text-white uppercase tracking-widest mb-1 italic">Pro Tip</p>
                    <p className="text-[10px] text-amber-200/60 leading-relaxed font-bold">
                      Scratch mode generates a full Unity project. This process takes 2-3 minutes as the AI writes unique code for your vision.
                    </p>
                  </div>
                </div>
              </div>
            )}
          </div>
        </div>
      </div>

      {/* GDD Preview Modal */}
      {showGdd && gdd && (
        <div className="fixed inset-0 z-[200] flex items-center justify-center p-6 backdrop-blur-xl bg-black/60">
          <div className="relative w-full max-w-4xl max-h-[90vh] overflow-hidden rounded-[40px] border border-white/10 bg-[#05060a] shadow-2xl flex flex-col">
            <div className="p-8 border-b border-white/5 bg-gradient-to-r from-indigo-500/10 to-transparent flex items-center justify-between">
              <div>
                <h2 className="text-3xl font-black text-white italic uppercase tracking-tighter italic">Game Blueprint</h2>
                <p className="text-xs font-black text-indigo-400 uppercase tracking-widest mt-1">Generated Design Specification</p>
              </div>
              <button 
                onClick={() => setShowGdd(false)}
                className="h-12 w-12 rounded-2xl hover:bg-white/5 flex items-center justify-center text-zinc-500 transition-colors"
                disabled={loading}
              >
                <Activity size={24} />
              </button>
            </div>

            <div className="flex-1 overflow-y-auto p-10 space-y-12">
               <div className="grid grid-cols-1 md:grid-cols-2 gap-10">
                 <div className="space-y-6">
                   <div className="space-y-2">
                     <label className="text-[10px] font-black text-zinc-600 uppercase tracking-widest">Project Title</label>
                     <div className="text-2xl font-black text-white italic uppercase tracking-tight">{gdd.title}</div>
                   </div>
                   <div className="space-y-2">
                     <label className="text-[10px] font-black text-zinc-600 uppercase tracking-widest">Abstract</label>
                     <p className="text-sm text-zinc-400 font-bold leading-relaxed">{gdd.description}</p>
                   </div>
                 </div>
                 
                 <div className="grid grid-cols-2 gap-6">
                   <div className="gf-panel rounded-2xl p-4 border border-white/5">
                     <Target className="text-fuchsia-500 mb-3" size={20} />
                     <div className="text-[9px] font-black text-zinc-600 uppercase mb-1">Genre</div>
                     <div className="text-xs font-black text-white uppercase">{gdd.genre}</div>
                   </div>
                   <div className="gf-panel rounded-2xl p-4 border border-white/5">
                     <Zap className="text-amber-500 mb-3" size={20} />
                     <div className="text-[9px] font-black text-zinc-600 uppercase mb-1">Difficulty</div>
                     <div className="text-xs font-black text-white uppercase">{Math.round(gdd.difficulty * 100)}%</div>
                   </div>
                   <div className="gf-panel rounded-2xl p-4 border border-white/5">
                     <Palette className="text-indigo-500 mb-3" size={20} />
                     <div className="text-[9px] font-black text-zinc-600 uppercase mb-1">Theme</div>
                     <div className="text-xs font-black text-white uppercase">{gdd.theme}</div>
                   </div>
                   <div className="gf-panel rounded-2xl p-4 border border-white/5">
                     <Cpu className="text-emerald-500 mb-3" size={20} />
                     <div className="text-[9px] font-black text-zinc-600 uppercase mb-1">Speed</div>
                     <div className="text-xs font-black text-white uppercase">{gdd.playerSpeed} m/s</div>
                   </div>
                 </div>
               </div>

               <div className="space-y-6">
                  <label className="text-[10px] font-black text-zinc-600 uppercase tracking-widest flex items-center gap-2">
                    <Activity size={14} /> Core Mechanics
                  </label>
                  <div className="flex flex-wrap gap-3">
                    {gdd.mechanics.map(m => (
                      <span key={m} className="px-4 py-2 rounded-xl bg-white/5 border border-white/5 text-[10px] font-black text-white uppercase tracking-widest">
                        {m}
                      </span>
                    ))}
                  </div>
               </div>

               <div className="grid grid-cols-1 md:grid-cols-2 gap-10 pt-10 border-t border-white/5">
                 <div className="space-y-4">
                   <label className="text-[10px] font-black text-zinc-600 uppercase tracking-widest">Color DNA</label>
                   <div className="flex gap-4">
                     <div className="h-10 flex-1 rounded-xl flex items-center justify-center text-[10px] font-black text-white border border-white/10" style={{ backgroundColor: gdd.primaryColor }}>Primary</div>
                     <div className="h-10 flex-1 rounded-xl flex items-center justify-center text-[10px] font-black text-white border border-white/10" style={{ backgroundColor: gdd.backgroundColor }}>Backdrop</div>
                   </div>
                 </div>
                 <div className="space-y-4">
                   <label className="text-[10px] font-black text-zinc-600 uppercase tracking-widest">Audio Profile</label>
                   <div className="flex items-center gap-3 p-4 bg-white/5 rounded-xl border border-white/5">
                     <Volume2 size={20} className="text-indigo-400" />
                     <span className="text-xs font-black text-white uppercase">Atmospheric Synth</span>
                   </div>
                 </div>
               </div>
            </div>

            <div className="p-8 border-t border-white/5 bg-black/40 flex items-center justify-between">
              <button 
                onClick={() => setShowGdd(false)}
                className="text-xs font-black text-zinc-500 uppercase tracking-widest hover:text-white transition-colors"
                disabled={loading}
              >
                Re-Generate Vision
              </button>
              <button 
                onClick={finalizeCreate}
                disabled={loading}
                className="px-10 py-4 rounded-2xl bg-white text-black font-black uppercase tracking-[0.2em] text-xs shadow-2xl hover:scale-105 active:scale-95 transition-all flex items-center gap-3"
              >
                {loading ? "Igniting Forge..." : "Initialize Build Engine"} <Zap size={16} />
              </button>
            </div>
          </div>
        </div>
      )}
    </UserShell>
  );
}
