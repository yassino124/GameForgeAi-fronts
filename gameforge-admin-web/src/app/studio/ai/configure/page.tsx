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
import { getUserToken } from "@/lib/userAuth";

export default function AIConfigurationPage() {
  const router = useRouter();
  const token = useMemo(() => getUserToken(), []);

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
        
        {/* Main Prompt Area */}
        <motion.div 
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          className="gf-panel-strong rounded-[32px] p-8"
        >
          <div className="flex items-center gap-3 mb-6">
            <div className="h-10 w-10 rounded-2xl bg-indigo-500/20 flex items-center justify-center text-indigo-400 gf-glow">
              <Wand2 size={24} />
            </div>
            <h3 className="text-xl font-bold text-white">The Concept</h3>
          </div>

          <textarea
            className="gf-input w-full rounded-2xl p-5 text-lg min-h-[160px] resize-none"
            placeholder="Describe your game vision in detail... e.g. 'A futuristic racing game where players must hack gates to pass through them, with a synthwave aesthetic and gravity-defying tracks.'"
            value={prompt}
            onChange={(e) => setPrompt(e.target.value)}
          />
        </motion.div>

        <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
          
          {/* Engine Settings */}
          <motion.div 
            initial={{ opacity: 0, x: -20 }}
            animate={{ opacity: 1, x: 0 }}
            transition={{ delay: 0.1 }}
            className="space-y-6"
          >
            <div className="gf-panel rounded-[32px] p-8 space-y-8">
              <div className="flex items-center gap-3 border-b border-white/5 pb-4">
                <Cpu className="text-cyan-400" size={20} />
                <h3 className="font-bold text-white uppercase tracking-widest text-xs">Engine Core</h3>
              </div>

              <div className="space-y-6">
                <div className="space-y-4">
                  <div className="flex justify-between items-center">
                    <label className="text-xs font-bold text-zinc-500 uppercase tracking-widest">Model Intelligence</label>
                    <span className="text-indigo-400 font-mono text-sm">{model}</span>
                  </div>
                  <div className="grid grid-cols-2 gap-2">
                    {["GPT-4", "GPT-3.5", "Claude-3", "Gemini"].map((m) => (
                      <button
                        key={m}
                        onClick={() => setModel(m)}
                        className={`py-2 rounded-xl border text-xs font-bold transition-all ${
                          model === m ? "bg-indigo-500 border-indigo-500 text-white" : "border-white/5 bg-white/2 text-zinc-500"
                        }`}
                      >
                        {m}
                      </button>
                    ))}
                  </div>
                </div>

                <div className="space-y-4">
                  <div className="flex justify-between items-center">
                    <label className="text-xs font-bold text-zinc-500 uppercase tracking-widest">Creativity Bias</label>
                    <span className="text-indigo-400 font-mono text-sm">{(creativity * 100).toFixed(0)}%</span>
                  </div>
                  <input 
                    type="range" min="0" max="1" step="0.1"
                    className="w-full h-1 bg-white/5 rounded-full appearance-none accent-indigo-500"
                    value={creativity}
                    onChange={(e) => setCreativity(parseFloat(e.target.value))}
                  />
                </div>

                <div className="grid grid-cols-2 gap-4">
                  <button 
                    onClick={() => setUseAdvancedPhysics(!useAdvancedPhysics)}
                    className={`p-4 rounded-2xl border flex items-center justify-between transition-all ${
                      useAdvancedPhysics ? "border-indigo-500/50 bg-indigo-500/5" : "border-white/5 bg-white/2"
                    }`}
                  >
                    <div className="flex items-center gap-3">
                      <Zap className={useAdvancedPhysics ? "text-indigo-400" : "text-zinc-600"} size={18} />
                      <div className="text-left">
                        <div className="text-xs font-bold text-white">Physics</div>
                      </div>
                    </div>
                    <div className={`h-4 w-4 rounded-full border-2 flex items-center justify-center ${
                      useAdvancedPhysics ? "border-indigo-500 bg-indigo-500" : "border-zinc-700"
                    }`}>
                      {useAdvancedPhysics && <Check size={10} className="text-white" />}
                    </div>
                  </button>

                  <button 
                    onClick={() => setEnableMultiplayer(!enableMultiplayer)}
                    className={`p-4 rounded-2xl border flex items-center justify-between transition-all ${
                      enableMultiplayer ? "border-indigo-500/50 bg-indigo-500/5" : "border-white/5 bg-white/2"
                    }`}
                  >
                    <div className="flex items-center gap-3">
                      <Globe className={enableMultiplayer ? "text-indigo-400" : "text-zinc-600"} size={18} />
                      <div className="text-left">
                        <div className="text-xs font-bold text-white">Multiplayer</div>
                      </div>
                    </div>
                    <div className={`h-4 w-4 rounded-full border-2 flex items-center justify-center ${
                      enableMultiplayer ? "border-indigo-500 bg-indigo-500" : "border-zinc-700"
                    }`}>
                      {enableMultiplayer && <Check size={10} className="text-white" />}
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
            <div className="gf-panel rounded-[32px] p-8 space-y-8">
              <div className="flex items-center gap-3 border-b border-white/5 pb-4">
                <Palette className="text-fuchsia-400" size={20} />
                <h3 className="font-bold text-white uppercase tracking-widest text-xs">Visual Identity</h3>
              </div>

              <div className="space-y-6">
                <div className="grid grid-cols-2 gap-6">
                  <div className="space-y-3">
                    <label className="text-[10px] font-bold text-zinc-500 uppercase tracking-widest">Primary Color</label>
                    <div className="flex gap-3">
                      <input 
                        type="color" 
                        className="h-10 w-10 rounded-xl bg-transparent border-none cursor-pointer p-0"
                        value={primaryColor}
                        onChange={(e) => setPrimaryColor(e.target.value)}
                      />
                      <input 
                        className="gf-input flex-1 rounded-xl px-3 text-[10px] font-mono uppercase"
                        value={primaryColor}
                        onChange={(e) => setPrimaryColor(e.target.value)}
                      />
                    </div>
                  </div>
                  <div className="space-y-3">
                    <label className="text-[10px] font-bold text-zinc-500 uppercase tracking-widest">Secondary Color</label>
                    <div className="flex gap-3">
                      <input 
                        type="color" 
                        className="h-10 w-10 rounded-xl bg-transparent border-none cursor-pointer p-0"
                        value={secondaryColor}
                        onChange={(e) => setSecondaryColor(e.target.value)}
                      />
                      <input 
                        className="gf-input flex-1 rounded-xl px-3 text-[10px] font-mono uppercase"
                        value={secondaryColor}
                        onChange={(e) => setSecondaryColor(e.target.value)}
                      />
                    </div>
                  </div>
                </div>

                <div className="space-y-4">
                  <div className="flex justify-between items-center">
                    <label className="text-xs font-bold text-zinc-500 uppercase tracking-widest">Difficulty Scale</label>
                    <span className="text-fuchsia-400 font-mono text-sm">{(difficulty * 10).toFixed(1)}</span>
                  </div>
                  <input 
                    type="range" min="0" max="1" step="0.1"
                    className="w-full h-1 bg-white/5 rounded-full appearance-none accent-fuchsia-500"
                    value={difficulty}
                    onChange={(e) => setDifficulty(parseFloat(e.target.value))}
                  />
                </div>

                <div className="space-y-4">
                  <label className="text-[10px] font-bold text-zinc-500 uppercase tracking-widest">Deployment Platform</label>
                  <div className="grid grid-cols-3 gap-2">
                    {[
                      { id: "webgl", label: "Web", icon: Globe },
                      { id: "android", label: "Android", icon: Monitor },
                      { id: "ios", label: "iOS", icon: Rocket },
                    ].map((p) => (
                      <button
                        key={p.id}
                        onClick={() => setBuildTarget(p.id)}
                        className={`flex flex-col items-center gap-2 py-3 rounded-2xl border transition-all ${
                          buildTarget === p.id ? "bg-indigo-500/10 border-indigo-500 text-indigo-400 shadow-[0_0_15px_rgba(99,102,241,0.1)]" : "border-white/5 bg-white/2 text-zinc-500 hover:border-white/10"
                        }`}
                      >
                        <p.icon size={16} />
                        <span className="text-[10px] font-bold uppercase">{p.label}</span>
                      </button>
                    ))}
                  </div>
                </div>
              </div>
            </div>
          </motion.div>
        </div>

        {/* Action Bar */}
        <motion.div 
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.3 }}
          className="flex flex-col sm:flex-row gap-4 items-center justify-between gf-panel rounded-[24px] p-6 border-indigo-500/20"
        >
          <div className="flex items-center gap-4 text-zinc-400 text-sm">
            <span className="flex items-center gap-2">
              <Check className="text-emerald-500" size={16} /> Concept ready
            </span>
            <span className="h-4 w-px bg-white/5 hidden sm:block" />
            <span className="flex items-center gap-2">
              <Check className="text-emerald-500" size={16} /> Configured
            </span>
          </div>

          <div className="flex gap-3 w-full sm:w-auto">
            <button 
              onClick={() => router.back()}
              className="gf-btn px-6 py-3 rounded-2xl text-sm font-bold flex items-center gap-2"
            >
              <ArrowLeft size={18} /> Back
            </button>
            <button 
              onClick={handleGenerate}
              disabled={loading || !prompt.trim()}
              className="flex-1 sm:flex-none rounded-2xl bg-indigo-500 px-10 py-3 font-bold text-white shadow-lg shadow-indigo-500/20 flex items-center justify-center gap-3 transition-all hover:scale-105 active:scale-95 disabled:opacity-50"
            >
              {loading ? (
                <>
                  <div className="h-4 w-4 border-2 border-white/30 border-t-white animate-spin rounded-full" />
                  Processing...
                </>
              ) : (
                <>Generate Game <Sparkles size={18} /></>
              )}
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
