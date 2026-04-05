"use client";

import { Suspense, useEffect, useMemo, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { motion, AnimatePresence } from "framer-motion";
import Tilt from "react-parallax-tilt";
import { 
  Rocket, 
  Layout, 
  Settings, 
  Zap, 
  ArrowRight, 
  ArrowLeft, 
  Search, 
  Check,
  Sparkles,
  Palette,
  Cpu,
  Globe,
  Dices,
  MonitorSmartphone,
  Info,
  AlertCircle,
  X
} from "lucide-react";
import UserShell from "@/app/_components/UserShell";
import { apiFetch, ApiError } from "@/lib/api";
import { getUserToken } from "@/lib/userAuth";
import { normalizeImageUrl } from "@/lib/media";

// Types
type Template = {
  id: string;
  _id?: string;
  name: string;
  description: string;
  category: string;
  imageUrl?: string;
  previewImageUrl?: string;
  thumbnailUrl?: string;
};

type ProjectConfig = {
  name: string;
  description: string;
  templateId: string;
  buildTarget: string;
  difficulty: number;
  timeScale: number;
  speed: number;
  gravityY: number;
  jumpForce: number;
  primaryColor: string;
  secondaryColor: string;
  enableMultiplayer: boolean;
  useAdvancedPhysics: boolean;
};

const fadeInUp = {
  initial: { opacity: 0, y: 20 },
  animate: { opacity: 1, y: 0 },
  transition: { duration: 0.5, ease: [0.16, 1, 0.3, 1] }
};

const COLOR_PRESETS = [
  { name: "Neon Cyber", primary: "#6366f1", secondary: "#ec4899", label: "Cyberpunk" },
  { name: "Classic Plumber", primary: "#e11d48", secondary: "#fbbf24", label: "Super Mario" },
  { name: "Forest Quest", primary: "#10b981", secondary: "#78350f", label: "Adventure" },
  { name: "Deep Space", primary: "#1e1b4b", secondary: "#06b6d4", label: "Sci-Fi" },
  { name: "Retro Console", primary: "#4b5563", secondary: "#9ca3af", label: "Classic" },
  { name: "Vaporwave", primary: "#a855f7", secondary: "#22d3ee", label: "Synth" },
];

export default function CreateProjectWizard() {
  return (
    <Suspense fallback={null}>
      <CreateProjectWizardInner />
    </Suspense>
  );
}

function CreateProjectWizardInner() {
  const router = useRouter();
  const sp = useSearchParams();
  const token = useMemo(() => getUserToken(), []);
  
  const [step, setStep] = useState(1);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [buildProgress, setBuildProgress] = useState(0);
  const [countdown, setCountdown] = useState(10);

  const [plan, setPlan] = useState<string>("Free");
  const [projectCount, setProjectCount] = useState<number>(0);
  const [showUpgrade, setShowUpgrade] = useState(false);
  const [upgradeReason, setUpgradeReason] = useState<string>("Upgrade required");

  const normPlan = (p: any) => String(p || "Free").trim().toLowerCase();
  const isFree = normPlan(plan) === "free";
  const isPro = useMemo(() => {
    const p = String(plan || "").trim().toLowerCase();
    const paidKeywords = ["pro", "enterprise", "studio", "premium", "gold"];
    const isPaid = paidKeywords.some(k => p.includes(k)) || (p !== "free" && p !== "" && p !== "standard free");
    console.log("CRITICAL Plan Check - raw:", plan, "norm:", p, "isPro:", isPaid);
    return isPaid;
  }, [plan]);
  const freeMaxProjects = 3;

  // Step 1: Template Selection State
  const [templates, setTemplates] = useState<Template[]>([]);
  const [search, setSearch] = useState("");
  const [selectedTemplate, setSelectedTemplate] = useState<Template | null>(null);

  // Step 2: Configuration State
  const [config, setConfig] = useState<ProjectConfig>({
    name: "",
    description: "",
    templateId: "",
    buildTarget: "webgl",
    difficulty: 0.5,
    timeScale: 1.0,
    speed: 7.0,
    gravityY: -9.8,
    jumpForce: 6.5,
    primaryColor: "#6366f1",
    secondaryColor: "#ec4899",
    enableMultiplayer: false,
    useAdvancedPhysics: true,
  });

  // Load Templates
  useEffect(() => {
    async function loadTemplates() {
      if (!token) return;
      try {
        try {
          const meRes = await apiFetch<any>("/auth/profile", { method: "GET", token });
          const meData = (meRes && typeof meRes === "object" && "data" in meRes) ? (meRes as any).data : meRes;
          const userObj = meData?.user || meData;
          setPlan((userObj?.subscription ?? userObj?.plan ?? "Free") as string);
        } catch {}

        try {
          const projRes = await apiFetch<any>("/projects", { method: "GET", token });
          const projData = (projRes && typeof projRes === "object" && "data" in projRes) ? (projRes as any).data : projRes;
          const items = Array.isArray((projData as any)?.data) ? (projData as any).data : (Array.isArray(projData) ? projData : []);
          setProjectCount(Array.isArray(items) ? items.length : 0);
        } catch {}

        const res = await apiFetch<any>("/templates", { method: "GET", token });
        const data = res?.data ?? res;
        const list = Array.isArray(data) ? data : data?.items ?? [];
        setTemplates(list);
      } catch (e) {
        console.error("Failed to load templates", e);
      }
    }
    loadTemplates();
  }, [token]);

  const filteredTemplates = useMemo(() => {
    return templates.filter(t => 
      t.name.toLowerCase().includes(search.toLowerCase()) || 
      t.category.toLowerCase().includes(search.toLowerCase())
    );
  }, [templates, search]);

  const handleCreate = async () => {
    if (!token || !selectedTemplate) return;

    if (isFree && !isPro && projectCount >= freeMaxProjects) {
      setUpgradeReason(`Free plan supports up to ${freeMaxProjects} projects. Upgrade to Pro to create more.`);
      setShowUpgrade(true);
      return;
    }

    if (config.buildTarget === "android" && !isPro) {
      setUpgradeReason("Android (APK) exports require Pro plan. Upgrade to enable APK builds.");
      setShowUpgrade(true);
      return;
    }

    try {
      setLoading(true);
      setError(null);
      
      // Phase 1: Neural Handshake
      setBuildProgress(10);
      await new Promise(r => setTimeout(r, 800));
      
      const createRes = await apiFetch<any>("/projects/from-template", {
        method: "POST",
        token,
        body: {
          templateId: selectedTemplate.id || (selectedTemplate as any)._id,
          name: config.name || `My ${selectedTemplate.name}`,
          description: config.description,
        },
      });

      const project = createRes?.data ?? createRes;
      const projectId = project.id || project._id;

      if (!projectId) throw new Error("Failed to get project ID");

      // Phase 2: DNA Injection
      setBuildProgress(45);
      await new Promise(r => setTimeout(r, 1200));

      await apiFetch(`/projects/${projectId}`, {
        method: "PUT",
        token,
        body: {
          buildTarget: config.buildTarget,
          difficulty: config.difficulty,
          timeScale: config.timeScale,
          speed: config.speed,
          gravityY: config.gravityY,
          jumpForce: config.jumpForce,
          primaryColor: config.primaryColor,
          secondaryColor: config.secondaryColor,
          enableMultiplayer: config.enableMultiplayer,
          useAdvancedPhysics: config.useAdvancedPhysics,
        }
      });

      // Phase 3: Engine Ignition
      setBuildProgress(85);
      await new Promise(r => setTimeout(r, 1000));

      await apiFetch(`/projects/${projectId}/rebuild`, { method: "POST", token });
      
      // Final Synchronization
      setBuildProgress(100);
      await new Promise(r => setTimeout(r, 800));
      
      router.push(`/studio/builds/progress?projectId=${projectId}`);
    } catch (e: any) {
      setError(e instanceof ApiError ? e.message : "Creation failed");
      setLoading(false);
    }
  };

  return (
    <UserShell title="Project Architect" subtitle="Forge your next digital universe">
      <div className="max-w-7xl mx-auto pb-20">

        <AnimatePresence>
          {loading && (
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              className="fixed inset-0 z-[200] flex flex-col items-center justify-center bg-[#05060a]/90 backdrop-blur-xl"
            >
              <div className="relative h-96 w-96 flex items-center justify-center">
                {/* Orbital Rings */}
                {[1, 2, 3].map((i) => (
                  <motion.div
                    key={i}
                    animate={{ rotate: 360 }}
                    transition={{ duration: 10 + i * 5, repeat: Infinity, ease: "linear" }}
                    className="absolute border border-indigo-500/20 rounded-full"
                    style={{ width: `${100 + i * 40}%`, height: `${100 + i * 40}%` }}
                  />
                ))}
                
                {/* Central Core */}
                <motion.div
                  animate={{ 
                    scale: [1, 1.1, 1],
                    boxShadow: ["0 0 20px rgba(99,102,241,0.2)", "0 0 60px rgba(99,102,241,0.5)", "0 0 20px rgba(99,102,241,0.2)"]
                  }}
                  transition={{ duration: 2, repeat: Infinity }}
                  className="h-40 w-40 rounded-[48px] bg-gradient-to-br from-indigo-500 to-fuchsia-600 flex flex-col items-center justify-center border border-white/20 shadow-2xl relative z-10"
                >
                  <Rocket size={48} className="text-white mb-2 animate-bounce" />
                  <div className="text-2xl font-black text-white italic">{buildProgress}%</div>
                </motion.div>

                {/* Progress Text */}
                <div className="absolute -bottom-24 text-center space-y-4">
                  <motion.div
                    key={buildProgress}
                    initial={{ opacity: 0, y: 10 }}
                    animate={{ opacity: 1, y: 0 }}
                    className="text-xl font-black text-white uppercase tracking-[0.3em] italic gf-chromatic"
                  >
                    {buildProgress < 30 ? "Initializing Neural Link..." :
                     buildProgress < 70 ? "Injecting DNA Matrices..." :
                     buildProgress < 100 ? "Igniting Game Engine..." : "Synchronization Complete"}
                  </motion.div>
                  <div className="flex gap-2 justify-center">
                    {Array.from({ length: 10 }).map((_, i) => (
                      <motion.div
                        key={i}
                        animate={{ 
                          opacity: buildProgress > (i * 10) ? 1 : 0.1,
                          scale: buildProgress > (i * 10) ? [1, 1.2, 1] : 1
                        }}
                        className="h-1.5 w-6 rounded-full bg-indigo-500 shadow-[0_0_10px_rgba(99,102,241,0.5)]"
                      />
                    ))}
                  </div>
                </div>
              </div>
            </motion.div>
          )}
        </AnimatePresence>

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
        
        {/* Progress Navigation */}
        <div className="mb-12 flex items-center justify-center">
          <div className="flex items-center gap-4 bg-white/[0.03] border border-white/5 p-2 rounded-[24px] backdrop-blur-xl shadow-2xl">
            {[
              { id: 1, label: "Blueprint", icon: Layout },
              { id: 2, label: "DNA Config", icon: Sparkles },
              { id: 3, label: "Engine Launch", icon: Rocket },
            ].map((s, i) => (
              <div key={s.id} className="flex items-center">
                <button 
                  onClick={() => step > s.id && setStep(s.id)}
                  className={`flex items-center gap-3 px-6 py-3 rounded-2xl transition-all ${
                    step === s.id 
                      ? "bg-indigo-500 text-white shadow-lg shadow-indigo-500/20" 
                      : step > s.id 
                        ? "text-emerald-400 hover:bg-white/5" 
                        : "text-zinc-500 cursor-not-allowed"
                  }`}
                >
                  <s.icon size={18} className={step === s.id ? "animate-pulse" : ""} />
                  <span className="text-xs font-bold uppercase tracking-widest">{s.label}</span>
                  {step > s.id && <Check size={14} className="ml-1" />}
                </button>
                {i < 2 && <div className="mx-2 h-1 w-4 rounded-full bg-white/5" />}
              </div>
            ))}
          </div>
        </div>

        <AnimatePresence mode="wait">
          {step === 1 && (
            <motion.div
              key="step1"
              variants={fadeInUp}
              initial="initial"
              animate="animate"
              exit={{ opacity: 0, scale: 0.95, filter: "blur(10px)" }}
              className="space-y-10"
            >
              <div className="flex flex-col md:flex-row gap-6 items-center bg-white/[0.02] p-6 rounded-[32px] border border-white/5 backdrop-blur-md">
                <div className="relative flex-1 w-full group">
                  <div className="absolute inset-0 bg-indigo-500/10 blur-xl opacity-0 group-focus-within:opacity-100 transition-opacity" />
                  <Search className="absolute left-5 top-1/2 -translate-y-1/2 text-zinc-500" size={20} />
                  <input 
                    className="gf-input w-full rounded-[24px] pl-14 pr-6 py-4 text-base border-white/10 focus:border-indigo-500/50 bg-black/40 transition-all shadow-inner font-bold"
                    placeholder="Search blueprints by name or category..."
                    value={search}
                    onChange={(e) => setSearch(e.target.value)}
                  />
                </div>
                <button 
                  disabled={!selectedTemplate}
                  onClick={() => setStep(2)}
                  className="group relative w-full md:w-auto overflow-hidden rounded-[24px] bg-white text-black px-12 py-4 font-black uppercase tracking-[0.2em] shadow-[0_20px_40px_rgba(255,255,255,0.1)] hover:scale-105 active:scale-95 disabled:opacity-20 transition-all flex items-center justify-center gap-3"
                >
                  <span className="relative z-10 flex items-center gap-3">
                    Next: DNA Config <ArrowRight size={20} className="group-hover:translate-x-1 transition-transform" />
                  </span>
                  <motion.div 
                    animate={{ x: ["-100%", "200%"] }}
                    transition={{ duration: 2, repeat: Infinity, ease: "linear" }}
                    className="absolute inset-0 bg-gradient-to-r from-transparent via-black/5 to-transparent skew-x-12"
                  />
                </button>
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-8">
                {filteredTemplates.map((t, idx) => {
                  const tId = t.id || (t as any)._id || `temp-${idx}`;
                  const active = selectedTemplate?.id === tId || (selectedTemplate as any)?._id === tId;
                  return (
                    <motion.div
                      key={tId}
                      initial={{ opacity: 0, y: 30 }}
                      animate={{ opacity: 1, y: 0 }}
                      transition={{ delay: idx * 0.05 }}
                    >
                      <Tilt
                        perspective={1400}
                        scale={1.05}
                        transitionSpeed={2500}
                        tiltMaxAngleX={12}
                        tiltMaxAngleY={12}
                        className="h-full"
                      >
                        <button
                          onClick={() => setSelectedTemplate(t)}
                          className={`gf-panel-strong group relative overflow-hidden rounded-[40px] border-2 transition-all text-left w-full h-full flex flex-col ${
                            active 
                              ? "border-indigo-500 bg-indigo-500/[0.1] shadow-[0_0_60px_rgba(99,102,241,0.3)]" 
                              : "border-white/5 hover:border-white/20 bg-white/[0.03]"
                          }`}
                        >
                          <div className="aspect-[16/11] relative overflow-hidden m-3 rounded-[32px] bg-black/40">
                            <motion.img 
                              src={normalizeImageUrl(t.previewImageUrl || t.thumbnailUrl)} 
                              alt={t.name}
                              className="w-full h-full object-cover transition-transform duration-1000 group-hover:scale-110"
                              animate={active ? { scale: 1.1 } : { scale: 1 }}
                            />
                            
                            {/* Cinematic Overlays */}
                            <div className="absolute inset-0 bg-gradient-to-t from-[#05060a] via-transparent to-transparent opacity-80" />
                            <div className="absolute inset-0 bg-indigo-500/10 opacity-0 group-hover:opacity-100 transition-opacity" />
                            
                            <div className="absolute top-4 left-4">
                              <span className="rounded-xl border border-white/10 bg-black/60 backdrop-blur-xl px-4 py-1.5 text-[10px] font-black uppercase tracking-[0.2em] text-indigo-300 shadow-2xl">
                                {t.category}
                              </span>
                            </div>

                            {active && (
                              <motion.div 
                                layoutId="check-glow"
                                initial={{ opacity: 0, scale: 0 }}
                                animate={{ opacity: 1, scale: 1 }}
                                className="absolute inset-0 border-4 border-indigo-500/50 rounded-[32px] pointer-events-none"
                              >
                                <div className="absolute top-4 right-4 h-10 w-10 rounded-2xl bg-indigo-500 flex items-center justify-center shadow-[0_0_20px_#6366f1] border border-white/20">
                                  <Check size={20} className="text-white" strokeWidth={4} />
                                </div>
                              </motion.div>
                            )}
                          </div>
                          
                          <div className="p-8 pt-4 flex-1">
                            <h4 className="text-xl font-black text-white tracking-tighter uppercase italic group-hover:gf-chromatic transition-all">{t.name}</h4>
                            <p className="mt-3 text-sm text-zinc-500 font-medium line-clamp-2 leading-relaxed group-hover:text-zinc-400 transition-colors">
                              {t.description}
                            </p>
                            
                            <div className="mt-6 pt-6 border-t border-white/5 flex items-center justify-between opacity-0 group-hover:opacity-100 transition-all translate-y-2 group-hover:translate-y-0">
                               <div className="flex gap-2">
                                 <Zap size={14} className="text-indigo-400" />
                                 <span className="text-[10px] font-black text-zinc-500 uppercase tracking-widest">Premium Logic</span>
                               </div>
                               <ArrowRight size={16} className="text-white" />
                            </div>
                          </div>

                          {/* Animated Border Glow */}
                          {active && (
                            <motion.div 
                              animate={{ opacity: [0.1, 0.3, 0.1] }}
                              transition={{ duration: 2, repeat: Infinity }}
                              className="absolute inset-0 bg-indigo-500 blur-3xl -z-10"
                            />
                          )}
                        </button>
                      </Tilt>
                    </motion.div>
                  );
                })}
              </div>
            </motion.div>
          )}

          {step === 2 && (
            <motion.div
              key="step2"
              initial={{ opacity: 0, scale: 0.98, filter: "blur(20px)" }}
              animate={{ opacity: 1, scale: 1, filter: "blur(0px)" }}
              exit={{ opacity: 0, scale: 0.98, filter: "blur(20px)" }}
              className="grid grid-cols-1 lg:grid-cols-12 gap-10"
            >
              <div className="lg:col-span-8 space-y-8">
                {/* Visual DNA Config */}
                <motion.div 
                  initial={{ x: -20, opacity: 0 }}
                  animate={{ x: 0, opacity: 1 }}
                  transition={{ delay: 0.1 }}
                  className="gf-panel-strong gf-stroke-gradient rounded-[48px] p-10 space-y-12 relative overflow-hidden group"
                >
                  <div className="absolute inset-0 bg-gradient-to-br from-indigo-500/5 via-transparent to-transparent pointer-events-none" />
                  
                  <div className="flex items-center gap-6 relative z-10">
                    <motion.div 
                      whileHover={{ rotate: 180 }}
                      className="h-16 w-16 rounded-[24px] bg-indigo-500/20 flex items-center justify-center text-indigo-400 border border-indigo-500/30 shadow-[0_0_30px_rgba(99,102,241,0.2)]"
                    >
                      <Palette size={32} />
                    </motion.div>
                    <div>
                      <h3 className="text-3xl font-black text-white italic uppercase tracking-tighter">Visual DNA</h3>
                      <p className="text-sm text-zinc-500 font-bold uppercase tracking-widest mt-1">Branding & Neural Color Grading</p>
                    </div>
                  </div>

                  <div className="grid grid-cols-1 gap-12 relative z-10">
                    <div className="space-y-6">
                      <div className="flex justify-between items-center">
                        <label className="text-[10px] font-black text-zinc-500 uppercase tracking-[0.4em]">Neural Presets</label>
                        <span className="text-[10px] font-black text-indigo-400 uppercase tracking-widest">Selected: {COLOR_PRESETS.find(p => p.primary === config.primaryColor)?.label || "Custom"}</span>
                      </div>
                      <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-6 gap-4">
                        {COLOR_PRESETS.map((p, idx) => (
                          <motion.button
                            key={p.name}
                            initial={{ opacity: 0, y: 10 }}
                            animate={{ opacity: 1, y: 0 }}
                            transition={{ delay: idx * 0.05 + 0.2 }}
                            whileHover={{ y: -5, scale: 1.05 }}
                            whileTap={{ scale: 0.95 }}
                            onClick={() => setConfig({...config, primaryColor: p.primary, secondaryColor: p.secondary})}
                            className={`flex flex-col gap-3 p-2 rounded-[24px] border-2 transition-all ${
                              config.primaryColor === p.primary && config.secondaryColor === p.secondary
                                ? "border-indigo-500 bg-indigo-500/10 shadow-[0_0_40px_rgba(99,102,241,0.2)]"
                                : "border-white/5 bg-white/[0.03] hover:border-white/20"
                            }`}
                          >
                            <div className="flex flex-col gap-1 h-12 w-full rounded-xl overflow-hidden">
                              <div className="flex-1" style={{ backgroundColor: p.primary }} />
                              <div className="flex-1" style={{ backgroundColor: p.secondary }} />
                            </div>
                            <span className="text-[8px] font-black uppercase tracking-widest text-zinc-500 pb-1">{p.label}</span>
                          </motion.button>
                        ))}
                      </div>
                    </div>

                    <div className="grid grid-cols-1 md:grid-cols-2 gap-10">
                      <div className="space-y-4 group/input">
                        <label className="text-[10px] font-black text-zinc-500 uppercase tracking-[0.4em] group-focus-within/input:text-indigo-400 transition-colors">Project Identity</label>
                        <div className="relative">
                          <input 
                            className="gf-input w-full rounded-[24px] px-8 py-5 bg-black/40 border-2 border-white/5 text-xl font-black italic tracking-tight text-white placeholder:text-zinc-800 focus:border-indigo-500/50 transition-all shadow-inner"
                            value={config.name}
                            onChange={(e) => setConfig({...config, name: e.target.value})}
                            placeholder="PROJECT ALPHA..."
                          />
                          <div className="absolute right-6 top-1/2 -translate-y-1/2 text-zinc-700">
                            <Info size={20} />
                          </div>
                        </div>
                      </div>
                      <div className="space-y-4">
                        <label className="text-[10px] font-black text-zinc-500 uppercase tracking-[0.4em]">Neural Target</label>
                        <div className="flex gap-4">
                          {[
                            { id: "webgl", icon: Globe, label: "WEB RUNTIME", color: "text-emerald-400" },
                            { id: "android", icon: MonitorSmartphone, label: "APK EXPORT", color: "text-indigo-400" }
                          ].map((target) => (
                            <motion.button
                              key={target.id}
                              whileHover={{ scale: 1.02 }}
                              whileTap={{ scale: 0.98 }}
                                onClick={() => {
                                  const currentPlan = String(plan || "").trim().toLowerCase();
                                  const isActuallyPro = currentPlan !== "free" && currentPlan !== "";
                                  if (target.id === "android" && !isActuallyPro) {
                                    setUpgradeReason("Android (APK) exports require Pro plan. Upgrade to enable APK builds.");
                                    setShowUpgrade(true);
                                    return;
                                  }
                                  setConfig({ ...config, buildTarget: target.id });
                                }}
                              className={`flex-1 flex flex-col items-center justify-center gap-3 py-5 rounded-[24px] border-2 transition-all ${
                                config.buildTarget === target.id 
                                  ? "bg-white text-black border-white shadow-[0_20px_40px_rgba(255,255,255,0.1)]" 
                                  : "bg-white/5 border-white/5 text-zinc-600 hover:border-white/10"
                              }`}
                            >
                              <target.icon size={24} className={config.buildTarget === target.id ? "text-black" : target.color} />
                              <span className="text-[10px] font-black uppercase tracking-[0.2em]">{target.label}</span>
                            </motion.button>
                          ))}
                        </div>
                      </div>
                    </div>
                  </div>
                </motion.div>

                {/* Engine Dynamics */}
                <motion.div 
                  initial={{ x: -20, opacity: 0 }}
                  animate={{ x: 0, opacity: 1 }}
                  transition={{ delay: 0.2 }}
                  className="gf-panel rounded-[48px] p-10 space-y-12 border-2 border-white/5"
                >
                  <div className="flex items-center gap-6">
                    <motion.div 
                      animate={{ rotate: [0, 10, -10, 0] }}
                      transition={{ duration: 4, repeat: Infinity }}
                      className="h-16 w-16 rounded-[24px] bg-amber-500/20 flex items-center justify-center text-amber-400 border border-amber-500/30 shadow-[0_0_30px_rgba(245,158,11,0.2)]"
                    >
                      <Cpu size={32} />
                    </motion.div>
                    <div>
                      <h3 className="text-3xl font-black text-white italic uppercase tracking-tighter">Engine Dynamics</h3>
                      <p className="text-sm text-zinc-500 font-bold uppercase tracking-widest mt-1">Real-time Procedural Calibration</p>
                    </div>
                  </div>

                  <div className="grid grid-cols-1 md:grid-cols-2 gap-16">
                    <div className="space-y-12">
                      <div className="space-y-6">
                        <div className="flex justify-between items-end">
                          <label className="text-[10px] font-black text-zinc-500 uppercase tracking-[0.4em]">Movement Velocity</label>
                          <span className="text-indigo-400 font-black text-2xl italic tracking-tighter">{config.speed.toFixed(1)}<span className="text-xs ml-1">m/s</span></span>
                        </div>
                        <div className="relative py-4">
                          <input 
                            type="range" min="1" max="20" step="0.5"
                            className="w-full h-2 appearance-none bg-white/5 rounded-full accent-indigo-500 cursor-pointer"
                            value={config.speed}
                            onChange={(e) => setConfig({...config, speed: parseFloat(e.target.value)})}
                          />
                          <div className="absolute inset-x-0 bottom-0 flex justify-between px-1">
                            {[0, 25, 50, 75, 100].map(p => <div key={p} className="h-1 w-1 rounded-full bg-zinc-800" />)}
                          </div>
                        </div>
                      </div>

                      <div className="space-y-6">
                        <div className="flex justify-between items-end">
                          <label className="text-[10px] font-black text-zinc-500 uppercase tracking-[0.4em]">Gravitational Force</label>
                          <span className="text-cyan-400 font-black text-2xl italic tracking-tighter">{config.gravityY.toFixed(1)}<span className="text-xs ml-1">G</span></span>
                        </div>
                        <div className="relative py-4">
                          <input 
                            type="range" min="-20" max="5" step="0.5"
                            className="w-full h-2 appearance-none bg-white/5 rounded-full accent-cyan-500 cursor-pointer"
                            value={config.gravityY}
                            onChange={(e) => setConfig({...config, gravityY: parseFloat(e.target.value)})}
                          />
                        </div>
                      </div>
                    </div>

                    <div className="space-y-12">
                      <div className="space-y-6">
                        <div className="flex justify-between items-end">
                          <label className="text-[10px] font-black text-zinc-500 uppercase tracking-[0.4em]">Vertical Impulse</label>
                          <span className="text-fuchsia-400 font-black text-2xl italic tracking-tighter">{config.jumpForce.toFixed(1)}<span className="text-xs ml-1">N</span></span>
                        </div>
                        <div className="relative py-4">
                          <input 
                            type="range" min="1" max="15" step="0.5"
                            className="w-full h-2 appearance-none bg-white/5 rounded-full accent-fuchsia-500 cursor-pointer"
                            value={config.jumpForce}
                            onChange={(e) => setConfig({...config, jumpForce: parseFloat(e.target.value)})}
                          />
                        </div>
                      </div>

                      <div className="space-y-6">
                        <div className="flex justify-between items-end">
                          <label className="text-[10px] font-black text-zinc-500 uppercase tracking-[0.4em]">Temporal Scale</label>
                          <span className="text-emerald-400 font-black text-2xl italic tracking-tighter">{config.timeScale.toFixed(1)}<span className="text-xs ml-1">x</span></span>
                        </div>
                        <div className="relative py-4">
                          <input 
                            type="range" min="0.1" max="3" step="0.1"
                            className="w-full h-2 appearance-none bg-white/5 rounded-full accent-emerald-500 cursor-pointer"
                            value={config.timeScale}
                            onChange={(e) => setConfig({...config, timeScale: parseFloat(e.target.value)})}
                          />
                        </div>
                      </div>
                    </div>
                  </div>

                  <div className="grid grid-cols-1 sm:grid-cols-2 gap-8 border-t-2 border-white/5 pt-12">
                    <motion.button 
                      whileHover={{ scale: 1.02, y: -5 }}
                      whileTap={{ scale: 0.98 }}
                      onClick={() => setConfig({...config, useAdvancedPhysics: !config.useAdvancedPhysics})}
                      className={`group p-8 rounded-[32px] border-2 flex items-center justify-between transition-all duration-500 ${
                        config.useAdvancedPhysics ? "border-indigo-500/50 bg-indigo-500/[0.05] shadow-2xl" : "border-white/5 bg-white/[0.02]"
                      }`}
                    >
                      <div className="flex items-center gap-5">
                        <div className={`h-14 w-14 rounded-2xl flex items-center justify-center transition-all ${config.useAdvancedPhysics ? "bg-indigo-500 text-white shadow-[0_0_20px_#6366f1]" : "bg-white/5 text-zinc-700"}`}>
                          <Zap size={28} fill={config.useAdvancedPhysics ? "currentColor" : "none"} />
                        </div>
                        <div className="text-left">
                          <div className="text-base font-black text-white italic uppercase tracking-tight">Advanced Physics</div>
                          <div className="text-[10px] text-indigo-400/60 font-black uppercase tracking-widest mt-1">High Fidelity Collisions</div>
                        </div>
                      </div>
                      <div className={`h-8 w-8 rounded-full border-2 flex items-center justify-center transition-all ${
                        config.useAdvancedPhysics ? "border-indigo-500 bg-indigo-500" : "border-zinc-800"
                      }`}>
                        {config.useAdvancedPhysics && <Check size={18} className="text-white" strokeWidth={4} />}
                      </div>
                    </motion.button>

                    <motion.button 
                      whileHover={{ scale: 1.02, y: -5 }}
                      whileTap={{ scale: 0.98 }}
                      onClick={() => setConfig({...config, enableMultiplayer: !config.enableMultiplayer})}
                      className={`group p-8 rounded-[32px] border-2 flex items-center justify-between transition-all duration-500 ${
                        config.enableMultiplayer ? "border-cyan-500/50 bg-cyan-500/[0.05] shadow-2xl" : "border-white/5 bg-white/[0.02]"
                      }`}
                    >
                      <div className="flex items-center gap-5">
                        <div className={`h-14 w-14 rounded-2xl flex items-center justify-center transition-all ${config.enableMultiplayer ? "bg-cyan-500 text-white shadow-[0_0_20px_#22d3ee]" : "bg-white/5 text-zinc-700"}`}>
                          <Globe size={28} />
                        </div>
                        <div className="text-left">
                          <div className="text-base font-black text-white italic uppercase tracking-tight">Neural Multi-Hub</div>
                          <div className="text-[10px] text-cyan-400/60 font-black uppercase tracking-widest mt-1">Real-time Instances</div>
                        </div>
                      </div>
                      <div className={`h-8 w-8 rounded-full border-2 flex items-center justify-center transition-all ${
                        config.enableMultiplayer ? "border-cyan-500 bg-cyan-500" : "border-zinc-800"
                      }`}>
                        {config.enableMultiplayer && <Check size={18} className="text-white" strokeWidth={4} />}
                      </div>
                    </motion.button>
                  </div>
                </motion.div>
              </div>

              {/* Architect Summary Sidebar */}
              <div className="lg:col-span-4 space-y-8">
                <motion.div 
                  initial={{ x: 20, opacity: 0 }}
                  animate={{ x: 0, opacity: 1 }}
                  transition={{ delay: 0.3 }}
                  className="gf-panel-strong gf-stroke-gradient rounded-[48px] p-10 sticky top-24 shadow-[0_0_100px_rgba(0,0,0,0.5)] border-2 border-white/5"
                >
                  <div className="absolute inset-0 bg-gradient-to-b from-indigo-500/5 via-transparent to-transparent pointer-events-none" />
                  
                  <div className="flex items-center justify-between mb-10 relative z-10">
                    <h3 className="text-xs font-black text-white uppercase tracking-[0.4em] italic">System Summary</h3>
                    <motion.div 
                      animate={{ scale: [1, 1.2, 1], opacity: [0.5, 1, 0.5] }}
                      transition={{ duration: 2, repeat: Infinity }}
                      className="h-2.5 w-2.5 rounded-full bg-emerald-500 shadow-[0_0_15px_rgba(16,185,129,1)]" 
                    />
                  </div>
                  
                  <div className="space-y-8 relative z-10">
                    <div className="aspect-[16/11] rounded-[36px] overflow-hidden border-2 border-white/10 relative group bg-black shadow-2xl">
                      <motion.img 
                        initial={{ scale: 1.2, filter: "grayscale(1) blur(5px)" }}
                        animate={{ scale: 1, filter: "grayscale(0) blur(0px)" }}
                        transition={{ duration: 1.5 }}
                        src={normalizeImageUrl(selectedTemplate?.previewImageUrl || selectedTemplate?.thumbnailUrl)} 
                        alt="" 
                        className="w-full h-full object-cover group-hover:scale-110 transition-transform duration-1000"
                      />
                      <div className="absolute inset-0 bg-gradient-to-t from-black via-black/20 to-transparent" />
                      <div className="absolute bottom-6 left-6 right-6">
                        <div className="text-[10px] font-black text-indigo-400 uppercase tracking-[0.3em] mb-2 drop-shadow-lg">Active Core</div>
                        <div className="text-xl font-black text-white italic tracking-tighter uppercase leading-none">{selectedTemplate?.name}</div>
                      </div>
                    </div>

                    <div className="grid grid-cols-2 gap-6">
                      <div className="space-y-2">
                        <div className="text-[9px] font-black text-zinc-600 uppercase tracking-[0.4em] leading-none">Color Map</div>
                        <div className="flex gap-1.5 h-3 w-full rounded-full overflow-hidden p-0.5 bg-white/5 border border-white/5">
                          <motion.div animate={{ width: ["0%", "100%"] }} className="flex-1 rounded-full" style={{ backgroundColor: config.primaryColor }} />
                          <motion.div animate={{ width: ["0%", "100%"] }} transition={{ delay: 0.1 }} className="flex-1 rounded-full" style={{ backgroundColor: config.secondaryColor }} />
                        </div>
                      </div>
                      <div className="space-y-2">
                        <div className="text-[9px] font-black text-zinc-600 uppercase tracking-[0.4em] leading-none">Complexity</div>
                        <div className="h-3 w-full rounded-full bg-white/5 overflow-hidden p-0.5 border border-white/5">
                          <motion.div 
                            initial={{ width: 0 }}
                            animate={{ width: `${config.difficulty * 100}%` }}
                            className="h-full bg-gradient-to-r from-indigo-500 to-fuchsia-500 rounded-full" 
                          />
                        </div>
                      </div>
                    </div>

                    <div className="space-y-4 pt-8 border-t-2 border-white/5">
                      {[
                        { label: "Neural Link", value: config.buildTarget.toUpperCase() },
                        { label: "Engine Core", value: "GPT-4 TURBO" },
                        { label: "Physics API", value: config.useAdvancedPhysics ? "FIDELITY-X" : "STANDARD" },
                        { label: "Instances", value: config.enableMultiplayer ? "MULTI-SYNC" : "SINGLE-VOID" },
                      ].map((row, idx) => (
                        <motion.div 
                          initial={{ opacity: 0, x: 10 }}
                          animate={{ opacity: 1, x: 0 }}
                          transition={{ delay: idx * 0.1 + 0.5 }}
                          key={row.label} 
                          className="flex justify-between items-center text-[10px] font-black tracking-[0.2em] leading-none"
                        >
                          <span className="text-zinc-600 uppercase">{row.label}</span>
                          <span className="text-white uppercase italic">{row.value}</span>
                        </motion.div>
                      ))}
                    </div>

                    <div className="space-y-4 pt-8">
                      <motion.button 
                        whileHover={{ scale: 1.03, y: -5 }}
                        whileTap={{ scale: 0.97 }}
                        onClick={handleCreate}
                        disabled={loading}
                        className="group relative w-full overflow-hidden rounded-[32px] bg-white text-black py-6 font-black uppercase tracking-[0.3em] italic text-xs shadow-[0_20px_60px_rgba(255,255,255,0.2)] transition-all flex items-center justify-center gap-3 disabled:opacity-30"
                      >
                        <span className="relative z-10 flex items-center gap-3">
                          Launch Neural Build <Rocket size={20} className="group-hover:translate-x-1 group-hover:-translate-y-1 transition-transform" />
                        </span>
                        <motion.div 
                          animate={{ x: ["-100%", "200%"] }}
                          transition={{ duration: 3, repeat: Infinity, ease: "linear" }}
                          className="absolute inset-0 bg-gradient-to-r from-transparent via-black/5 to-transparent skew-x-12"
                        />
                      </motion.button>
                      
                      <button 
                        onClick={() => setStep(1)}
                        className="w-full py-4 text-[10px] font-black uppercase tracking-[0.4em] text-zinc-600 hover:text-white transition-colors flex items-center justify-center gap-2 group"
                      >
                        <ArrowLeft size={14} className="group-hover:-translate-x-1 transition-transform" /> Reboot Blueprint Selection
                      </button>
                    </div>
                  </div>

                  {error && (
                    <motion.div 
                      initial={{ opacity: 0, scale: 0.9 }}
                      animate={{ opacity: 1, scale: 1 }}
                      className="mt-8 p-6 rounded-[24px] bg-rose-500/10 border-2 border-rose-500/20 text-rose-400 text-[10px] font-black uppercase tracking-[0.2em] text-center italic"
                    >
                      <AlertCircle size={16} className="inline mr-2 mb-1" /> {error}
                    </motion.div>
                  )}
                </motion.div>
              </div>
            </motion.div>
          )}
        </AnimatePresence>
      </div>
    </UserShell>
  );
}

const staggerContainer = {
  animate: {
    transition: {
      staggerChildren: 0.05
    }
  }
};
