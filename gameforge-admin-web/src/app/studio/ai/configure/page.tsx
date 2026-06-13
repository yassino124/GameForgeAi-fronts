"use client";

import { useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { motion } from "framer-motion";
import { 
  Sparkles, 
  Cpu, 
  Zap, 
  ArrowRight, 
  ArrowLeft,
  Wand2,
  Rocket,
  Palette,
  Globe,
  Gauge,
  Monitor
} from "lucide-react";
import UserShell from "@/app/_components/UserShell";
import { apiFetch, ApiError } from "@/lib/api";
import { useAuthToken } from "@/lib/stores/authStore";

export default function AIConfigurationPage() {
  const router = useRouter();
  const { token } = useAuthToken();

  const [prompt, setPrompt] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // AI Settings
  const [model, setModel] = useState("GPT-4");
  const [creativity, setCreativity] = useState(0.7);
  const [buildTarget, setBuildTarget] = useState("webgl");
  const [difficulty, setDifficulty] = useState(0.5);
  const [useAdvancedPhysics, setUseAdvancedPhysics] = useState(true);
  const [enableMultiplayer, setEnableMultiplayer] = useState(false);
  const [primaryColor, setPrimaryColor] = useState("#6366f1");
  const [secondaryColor, setSecondaryColor] = useState("#ec4899");

  async function handleGenerate() {
    if (!token) return;
    if (!prompt.trim()) {
      setError("Please describe the game you want to generate.");
      return;
    }

    setLoading(true);
    setError(null);

    try {
      const res = await apiFetch<any>("/projects/ai/create", {
        method: "POST",
        token,
        body: {
          prompt: prompt.trim(),
          buildTarget,
          difficulty,
          primaryColor,
          secondaryColor,
          useAdvancedPhysics,
          enableMultiplayer,
          creativity,
          model,
        },
      });

      const data = res?.data ?? res;
      const projectId = data?.projectId ?? data?.id ?? data?._id;

      if (!projectId) throw new Error("Failed to get project ID");

      router.push(`/studio/builds/progress?projectId=${projectId}`);
    } catch (e: any) {
      setError(e instanceof ApiError ? e.message : "AI Generation failed");
      setLoading(false);
    }
  }

  return (
    <UserShell title="AI Architect" subtitle="Configure your AI-powered game generation">
      <div className="max-w-5xl mx-auto space-y-8">
        
        <motion.div 
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          className="gf-panel-strong gf-stroke-gradient rounded-[48px] p-8 md:p-12 relative overflow-hidden group"
        >
          <div className="absolute inset-0 bg-gradient-to-br from-blue-500/5 via-transparent to-transparent pointer-events-none" />
          
          <div className="relative z-10 flex items-center gap-4 mb-8">
            <div className="h-14 w-14 rounded-[20px] bg-blue-500/20 flex items-center justify-center text-blue-400 gf-glow border border-blue-500/30 shadow-[0_0_30px_rgba(99,102,241,0.2)]">
              <Wand2 size={28} className="animate-pulse" />
            </div>
            <div>
              <div className="text-[10px] font-black uppercase tracking-[0.3em] text-blue-400">Neural Synthesis</div>
              <h3 className="text-3xl font-black text-white italic uppercase tracking-tight gf-chromatic">Core Concept</h3>
            </div>
          </div>

          <div className="relative z-10 group/input">
            <div className="absolute inset-0 bg-blue-500/10 blur-xl opacity-0 group-focus-within/input:opacity-100 transition-opacity" />
            <textarea
              className="gf-input relative w-full rounded-[32px] border border-white/10 bg-black/40 p-8 text-xl font-medium text-white min-h-[200px] resize-none focus:border-blue-500/50 shadow-inner transition-all leading-relaxed placeholder:text-zinc-600"
              placeholder="Describe your game vision in detail... e.g. 'A futuristic racing game where players must hack gates to pass through them, with a synthwave aesthetic and gravity-defying tracks.'"
              value={prompt}
              onChange={(e) => setPrompt(e.target.value)}
            />
          </div>
        </motion.div>

        <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
          
          {/* Engine Settings */}
          <motion.div 
            initial={{ opacity: 0, x: -20 }}
            animate={{ opacity: 1, x: 0 }}
            transition={{ delay: 0.1 }}
            className="space-y-6"
          >
            <div className="gf-panel-strong rounded-[40px] p-8 md:p-10 space-y-8 relative overflow-hidden h-full">
              <div className="absolute top-0 right-0 p-8 opacity-[0.02] pointer-events-none">
                <Cpu size={160} />
              </div>
              <div className="relative z-10 flex items-center gap-3 border-b border-white/10 pb-6">
                <Cpu className="text-cyan-400" size={24} />
                <h3 className="text-sm font-black text-white uppercase tracking-[0.2em]">Engine Config</h3>
              </div>

              <div className="relative z-10 space-y-8">
                <div className="space-y-4">
                  <div className="flex justify-between items-center bg-white/[0.02] rounded-2xl p-3 border border-white/5">
                    <label className="text-[10px] font-black text-cyan-500 uppercase tracking-widest pl-2">Model Class</label>
                    <span className="text-white font-black uppercase text-xs tracking-wider pr-2">{model}</span>
                  </div>
                  <div className="grid grid-cols-2 gap-3">
                    {["GPT-4", "GPT-3.5", "Claude-3", "Gemini"].map((m) => (
                      <button
                        key={m}
                        onClick={() => setModel(m)}
                        className={`py-3 rounded-[20px] border text-[11px] font-black uppercase tracking-widest transition-all ${
                          model === m ? "bg-cyan-500/20 border-cyan-500/50 text-cyan-300 shadow-[0_0_20px_rgba(6,182,212,0.15)]" : "border-white/5 bg-black/40 text-zinc-500 hover:text-white hover:border-white/20"
                        }`}
                      >
                        {m}
                      </button>
                    ))}
                  </div>
                </div>

                <div className="space-y-5 bg-white/[0.02] rounded-[28px] p-6 border border-white/5">
                  <div className="flex justify-between items-center">
                    <label className="text-[10px] font-black text-blue-400 uppercase tracking-widest">Creativity Variance</label>
                    <span className="text-white font-black text-xs tracking-wider">{(creativity * 100).toFixed(0)}%</span>
                  </div>
                  <div className="relative h-2 w-full bg-black/40 rounded-full border border-white/10 overflow-hidden">
                    <div className="absolute top-0 left-0 h-full bg-gradient-to-r from-blue-500 to-cyan-500" style={{ width: `${creativity * 100}%` }} />
                    <input 
                      type="range" min="0" max="1" step="0.1"
                      className="absolute inset-0 w-full h-full opacity-0 cursor-pointer"
                      value={creativity}
                      onChange={(e) => setCreativity(parseFloat(e.target.value))}
                    />
                  </div>
                </div>

                <div className="grid grid-cols-2 gap-4">
                  <button 
                    onClick={() => setUseAdvancedPhysics(!useAdvancedPhysics)}
                    className={`p-5 rounded-[24px] border flex flex-col gap-4 transition-all group ${
                      useAdvancedPhysics ? "border-amber-500/50 bg-amber-500/10 shadow-[0_0_20px_rgba(245,158,11,0.1)]" : "border-white/5 bg-white/[0.02] hover:border-white/20"
                    }`}
                  >
                    <div className="flex items-center justify-between w-full">
                      <Zap className={useAdvancedPhysics ? "text-amber-400 drop-shadow-[0_0_8px_rgba(245,158,11,0.8)]" : "text-zinc-600"} size={20} />
                      <div className={`h-5 w-5 rounded-full border-2 flex items-center justify-center transition-all ${
                        useAdvancedPhysics ? "border-amber-500 bg-amber-500 text-black" : "border-zinc-700 text-transparent"
                      }`}>
                        <Check size={12} />
                      </div>
                    </div>
                    <div className="text-left">
                      <div className={`text-[10px] font-black uppercase tracking-widest transition-colors ${useAdvancedPhysics ? "text-amber-100" : "text-zinc-500 group-hover:text-zinc-300"}`}>Adv. Physics</div>
                    </div>
                  </button>

                  <button 
                    onClick={() => setEnableMultiplayer(!enableMultiplayer)}
                    className={`p-5 rounded-[24px] border flex flex-col gap-4 transition-all group ${
                      enableMultiplayer ? "border-emerald-500/50 bg-emerald-500/10 shadow-[0_0_20px_rgba(16,185,129,0.1)]" : "border-white/5 bg-white/[0.02] hover:border-white/20"
                    }`}
                  >
                    <div className="flex items-center justify-between w-full">
                      <Globe className={enableMultiplayer ? "text-emerald-400 drop-shadow-[0_0_8px_rgba(16,185,129,0.8)]" : "text-zinc-600"} size={20} />
                      <div className={`h-5 w-5 rounded-full border-2 flex items-center justify-center transition-all ${
                        enableMultiplayer ? "border-emerald-500 bg-emerald-500 text-black" : "border-zinc-700 text-transparent"
                      }`}>
                        <Check size={12} />
                      </div>
                    </div>
                    <div className="text-left">
                      <div className={`text-[10px] font-black uppercase tracking-widest transition-colors ${enableMultiplayer ? "text-emerald-100" : "text-zinc-500 group-hover:text-zinc-300"}`}>Multiplayer</div>
                    </div>
                  </button>
                </div>
              </div>
            </div>
          </motion.div>

          {/* Visual Settings */}
          <motion.div 
            initial={{ opacity: 0, x: 20 }}
            animate={{ opacity: 1, x: 0 }}
            transition={{ delay: 0.2 }}
            className="space-y-6"
          >
            <div className="gf-panel-strong rounded-[40px] p-8 md:p-10 space-y-8 relative overflow-hidden h-full">
              <div className="absolute bottom-0 right-0 p-8 opacity-[0.02] pointer-events-none">
                <Palette size={160} />
              </div>
              <div className="relative z-10 flex items-center gap-3 border-b border-white/10 pb-6">
                <Palette className="text-cyan-400" size={24} />
                <h3 className="text-sm font-black text-white uppercase tracking-[0.2em]">Visual Identity</h3>
              </div>

              <div className="relative z-10 space-y-8">
                <div className="grid grid-cols-2 gap-4">
                  <div className="bg-white/[0.02] rounded-[24px] p-4 border border-white/5 space-y-3">
                    <label className="text-[9px] font-black text-rose-400 uppercase tracking-widest pl-1">Primary Color</label>
                    <div className="flex items-center gap-3 bg-black/40 rounded-[16px] p-2 border border-white/10">
                      <div className="relative h-10 w-10 rounded-[12px] overflow-hidden border border-white/20 shrink-0">
                        <input 
                          type="color" 
                          className="absolute -inset-4 w-[200%] h-[200%] cursor-pointer p-0 m-0 border-none"
                          value={primaryColor}
                          onChange={(e) => setPrimaryColor(e.target.value)}
                        />
                      </div>
                      <input 
                        className="w-full bg-transparent text-[11px] font-black uppercase text-white outline-none tracking-widest min-w-0"
                        value={primaryColor}
                        onChange={(e) => setPrimaryColor(e.target.value)}
                      />
                    </div>
                  </div>
                  <div className="bg-white/[0.02] rounded-[24px] p-4 border border-white/5 space-y-3">
                    <label className="text-[9px] font-black text-blue-400 uppercase tracking-widest pl-1">Secondary Color</label>
                    <div className="flex items-center gap-3 bg-black/40 rounded-[16px] p-2 border border-white/10">
                      <div className="relative h-10 w-10 rounded-[12px] overflow-hidden border border-white/20 shrink-0">
                        <input 
                          type="color" 
                          className="absolute -inset-4 w-[200%] h-[200%] cursor-pointer p-0 m-0 border-none"
                          value={secondaryColor}
                          onChange={(e) => setSecondaryColor(e.target.value)}
                        />
                      </div>
                      <input 
                        className="w-full bg-transparent text-[11px] font-black uppercase text-white outline-none tracking-widest min-w-0"
                        value={secondaryColor}
                        onChange={(e) => setSecondaryColor(e.target.value)}
                      />
                    </div>
                  </div>
                </div>

                <div className="space-y-5 bg-white/[0.02] rounded-[28px] p-6 border border-white/5">
                  <div className="flex justify-between items-center">
                    <label className="text-[10px] font-black text-cyan-400 uppercase tracking-widest">Difficulty Matrix</label>
                    <span className="inline-flex items-center justify-center bg-cyan-500/20 text-cyan-200 border border-cyan-500/30 rounded-full px-2 py-0.5 text-[10px] font-black">Level {(difficulty * 10).toFixed(1)}</span>
                  </div>
                  <div className="relative h-2 w-full bg-black/40 rounded-full border border-white/10 overflow-hidden">
                    <div className="absolute top-0 left-0 h-full bg-gradient-to-r from-emerald-500 via-amber-500 to-rose-500" style={{ width: `${difficulty * 100}%` }} />
                    <input 
                      type="range" min="0" max="1" step="0.1"
                      className="absolute inset-0 w-full h-full opacity-0 cursor-pointer"
                      value={difficulty}
                      onChange={(e) => setDifficulty(parseFloat(e.target.value))}
                    />
                  </div>
                </div>

                <div className="space-y-4">
                  <label className="text-[10px] font-black text-zinc-500 uppercase tracking-widest pl-2">Target Architecture</label>
                  <div className="flex flex-wrap gap-3">
                    {[
                      { id: "webgl", label: "Web", icon: Globe },
                      { id: "android", label: "Android", icon: Monitor },
                      { id: "ios", label: "iOS", icon: Rocket },
                    ].map((p) => (
                      <button
                        key={p.id}
                        onClick={() => setBuildTarget(p.id)}
                        className={`flex-1 min-w-[30%] flex flex-col items-center gap-3 py-4 rounded-[24px] border transition-all ${
                          buildTarget === p.id 
                            ? "bg-blue-500/20 border-blue-500/60 text-white shadow-[0_0_20px_rgba(99,102,241,0.2)] scale-[1.02]" 
                            : "border-white/5 bg-black/40 text-zinc-500 hover:border-white/20 hover:text-white"
                        }`}
                      >
                        <p.icon size={20} className={buildTarget === p.id ? "text-blue-400 drop-shadow-[0_0_8px_rgba(99,102,241,0.8)]" : ""} />
                        <span className="text-[10px] font-black uppercase tracking-widest">{p.label}</span>
                      </button>
                    ))}
                  </div>
                </div>
              </div>
            </div>
          </motion.div>
        </div>

        <motion.div 
          initial={{ opacity: 0, y: 30 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.3 }}
          className="flex flex-col sm:flex-row gap-6 items-center justify-between gf-panel-strong border-t-[3px] border-t-blue-500 rounded-[32px] p-6 shadow-2xl"
        >
          <div className="flex items-center gap-4 text-zinc-400 text-[10px] font-black uppercase tracking-[0.2em]">
            <div className="flex items-center gap-2 bg-blue-500/10 border border-blue-500/30 px-4 py-2 rounded-full text-blue-300">
              <span className="h-2 w-2 rounded-full bg-blue-400 animate-pulse" />
              Engine Online
            </div>
          </div>

          <div className="flex gap-3 w-full sm:w-auto">
            <button 
              onClick={() => router.back()}
              className="rounded-[20px] bg-white/[0.04] border border-white/5 px-8 py-4 text-[11px] font-black uppercase tracking-[0.2em] text-zinc-400 hover:text-white hover:bg-white/10 transition-all flex items-center justify-center"
            >
              Cancel
            </button>
            <button 
              onClick={handleGenerate}
              disabled={loading || !prompt.trim()}
              className="flex-1 sm:flex-none group relative overflow-hidden rounded-[20px] bg-white px-10 py-4 font-black uppercase tracking-[0.2em] text-black shadow-[0_20px_40px_rgba(255,255,255,0.15)] flex items-center justify-center gap-3 transition-all hover:scale-105 active:scale-95 disabled:opacity-20 disabled:scale-100"
            >
              <span className="relative z-10 flex items-center gap-3">
                {loading ? "Neural Link Active..." : "Ignite Engine"}
                {loading ? <div className="h-4 w-4 border-2 border-black/30 border-t-black animate-spin rounded-full" /> : <Sparkles size={16} />}
              </span>
              <motion.div 
                animate={{ x: ["-100%", "200%"] }}
                transition={{ duration: 2, repeat: Infinity, ease: "linear" }}
                className="absolute inset-0 bg-gradient-to-r from-transparent via-black/10 to-transparent skew-x-12"
              />
            </button>
          </div>
        </motion.div>

        {error && (
          <motion.div 
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            className="p-4 rounded-2xl bg-rose-500/10 border border-rose-500/20 text-rose-400 text-sm text-center"
          >
            {error}
          </motion.div>
        )}
      </div>
    </UserShell>
  );
}

function Check({ size, className }: { size?: number, className?: string }) {
  return (
    <svg 
      width={size || 24} 
      height={size || 24} 
      viewBox="0 0 24 24" 
      fill="none" 
      stroke="currentColor" 
      strokeWidth="3" 
      strokeLinecap="round" 
      strokeLinejoin="round" 
      className={className}
    >
      <polyline points="20 6 9 17 4 12" />
    </svg>
  );
}
