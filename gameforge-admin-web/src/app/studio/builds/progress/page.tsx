"use client";

import { Suspense, useEffect, useMemo, useState, useRef } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { motion, AnimatePresence } from "framer-motion";
import { 
  Rocket, 
  Cpu, 
  CheckCircle2, 
  AlertCircle, 
  ArrowLeft,
  Timer,
  Terminal,
  Activity,
  Zap,
  Layers,
  Box,
  Binary,
  Code2,
  X
} from "lucide-react";
import UserShell from "@/app/_components/UserShell";
import { apiFetch, ApiError } from "@/lib/api";
import { useAuthToken } from "@/lib/stores/authStore";

type BuildStatus = "queued" | "running" | "ready" | "failed";

type Project = {
  id?: string;
  _id?: string;
  name?: string;
  status?: BuildStatus;
  error?: string;
  updatedAt?: string;
  generationMode?: "blueprint" | "scratch" | "modules";
};

const MatrixRain = () => {
  return (
    <div className="absolute inset-0 overflow-hidden pointer-events-none opacity-[0.15]">
      <div className="flex justify-around w-full h-full">
        {Array.from({ length: 20 }).map((_, i) => (
          <motion.div
            key={i}
            initial={{ y: -100 }}
            animate={{ y: ["0%", "1000%"] }}
            transition={{
              duration: 5 + Math.random() * 10,
              repeat: Infinity,
              ease: "linear",
              delay: Math.random() * 5
            }}
            className="text-[10px] font-mono text-blue-400 leading-none writing-vertical-rl flex flex-col gap-1"
          >
            {Array.from({ length: 20 }).map((_, j) => (
              <span key={j} style={{ opacity: 1 - j * 0.05 }}>
                {Math.random() > 0.5 ? "1" : "0"}
              </span>
            ))}
          </motion.div>
        ))}
      </div>
    </div>
  );
};

const NeuralProcessor = ({ status }: { status: BuildStatus }) => (
  <div className="relative h-96 w-96 flex items-center justify-center">
    <MatrixRain />
    
    {/* Holographic 3D-like Projection Base */}
    <div className="absolute -bottom-20 w-64 h-24 bg-blue-600/10 blur-[40px] rounded-full scale-y-50" />
    <motion.div 
      animate={{ opacity: [0.3, 0.6, 0.3], scale: [1, 1.1, 1] }}
      transition={{ duration: 4, repeat: Infinity }}
      className="absolute -bottom-10 w-48 h-10 border-t-2 border-blue-500/20 rounded-full blur-[2px]"
    />

    {/* High-End Cybernetic HUD */}
    <div className="absolute inset-0 pointer-events-none">
      <svg viewBox="0 0 200 200" className="w-full h-full opacity-30">
        <motion.circle 
          animate={{ strokeDashoffset: [0, 400] }}
          transition={{ duration: 20, repeat: Infinity, ease: "linear" }}
          cx="100" cy="100" r="98" fill="none" stroke="currentColor" strokeWidth="0.5" strokeDasharray="10 10" className="text-blue-500" 
        />
        <motion.circle 
          animate={{ rotate: -360 }}
          transition={{ duration: 30, repeat: Infinity, ease: "linear" }}
          cx="100" cy="100" r="85" fill="none" stroke="currentColor" strokeWidth="1" strokeDasharray="40 20" className="text-blue-500" 
        />
      </svg>
    </div>

    {/* Dynamic Orbital Rings with Glitch Effect */}
    {[1, 2, 3, 4, 5].map((i) => (
      <motion.div
        key={i}
        animate={{ 
          rotateX: 60,
          rotateY: i * 20,
          rotateZ: i % 2 === 0 ? 360 : -360,
          scale: status === "running" ? [1, 1.05, 1] : 1,
          opacity: status === "running" ? [0.1, 0.4, 0.1] : 0.1
        }}
        transition={{ 
          rotateZ: { duration: 10 + i * 5, repeat: Infinity, ease: "linear" },
          scale: { duration: 2, repeat: Infinity, ease: "easeInOut" },
          opacity: { duration: 1.5, repeat: Infinity }
        }}
        className="absolute border-2 border-blue-500/40 rounded-full shadow-[0_0_20px_rgba(37,99,235,0.2)]"
        style={{ 
          width: `${80 + i * 40}%`, 
          height: `${80 + i * 40}%`,
          perspective: "1000px"
        }}
      />
    ))}

    {/* Kinetic Data Stream Particles */}
    <AnimatePresence>
      {status === "running" && Array.from({ length: 16 }).map((_, i) => (
        <motion.div
          key={i}
          initial={{ opacity: 0, scale: 0 }}
          animate={{ 
            opacity: [0, 1, 0],
            scale: [0, 2, 0],
            x: Math.cos(i * 22.5) * 180,
            y: Math.sin(i * 22.5) * 180,
            rotate: 720
          }}
          transition={{ 
            duration: 3, 
            repeat: Infinity, 
            delay: i * 0.1,
            ease: "circOut"
          }}
          className="absolute h-1.5 w-1.5 bg-gradient-to-r from-cyan-400 via-blue-500 to-sky-400 rounded-full shadow-[0_0_20px_rgba(34,211,238,1)] z-20"
        />
      ))}
    </AnimatePresence>

    {/* Central Pulsing Reactor Core with Chromatic Glitch */}
    <motion.div
      animate={{ 
        boxShadow: status === "running" 
          ? ["0 0 40px rgba(37,99,235,0.4)", "0 0 120px rgba(168,85,247,0.8)", "0 0 40px rgba(37,99,235,0.4)"]
          : "0 0 30px rgba(37,99,235,0.2)",
        scale: status === "running" ? [1, 1.1, 0.95, 1.05, 1] : 1,
        skewX: status === "running" ? [0, 5, -5, 2, 0] : 0
      }}
      transition={{ duration: 2, repeat: Infinity }}
      className="relative z-30 h-44 w-44 rounded-[56px] bg-gradient-to-br from-blue-700 via-blue-600 to-sky-500 flex items-center justify-center border-2 border-white/30 shadow-2xl backdrop-blur-xl"
    >
      {/* Internal Core Glow */}
      <div className="absolute inset-3 rounded-[48px] bg-black/40 backdrop-blur-2xl border border-white/10 overflow-hidden">
        <motion.div 
          animate={{ y: ["-100%", "100%"] }}
          transition={{ duration: 1.5, repeat: Infinity, ease: "linear" }}
          className="absolute inset-0 bg-gradient-to-b from-transparent via-white/20 to-transparent"
        />
      </div>
      
      <AnimatePresence mode="wait">
        {status === "ready" ? (
          <motion.div key="ready" initial={{ scale: 0, rotate: -90, filter: "blur(10px)" }} animate={{ scale: 1, rotate: 0, filter: "blur(0px)" }} exit={{ scale: 0 }}>
            <CheckCircle2 size={80} className="text-white drop-shadow-[0_0_30px_rgba(255,255,255,0.6)]" strokeWidth={3} />
          </motion.div>
        ) : status === "failed" ? (
          <motion.div key="failed" initial={{ scale: 0 }} animate={{ scale: 1 }} exit={{ scale: 0 }}>
            <AlertCircle size={80} className="text-white drop-shadow-[0_0_30px_rgba(244,63,94,0.6)]" strokeWidth={3} />
          </motion.div>
        ) : (
          <motion.div 
            key="active" 
            animate={{ 
              rotate: 360,
              scale: [1, 1.2, 1],
              filter: ["hue-rotate(0deg) contrast(1)", "hue-rotate(180deg) contrast(1.5)", "hue-rotate(360deg) contrast(1)"]
            }} 
            transition={{ 
              rotate: { duration: 2, repeat: Infinity, ease: "linear" },
              scale: { duration: 1, repeat: Infinity },
              filter: { duration: 4, repeat: Infinity }
            }}
            className="relative z-10"
          >
            <Cpu size={72} className="text-white drop-shadow-[0_0_20px_rgba(255,255,255,0.4)]" strokeWidth={1.5} />
          </motion.div>
        )}
      </AnimatePresence>

      {/* Rotating Ring on Core */}
      <motion.div 
        animate={{ rotate: -360 }}
        transition={{ duration: 2, repeat: Infinity, ease: "linear" }}
        className="absolute inset-0 rounded-[56px] border-4 border-t-white/60 border-r-transparent border-b-white/20 border-l-transparent pointer-events-none" 
      />
    </motion.div>

    {/* Scanning HUD Accents with Timers */}
    <motion.div 
      animate={{ opacity: [0.4, 0.8, 0.4], x: ["-50%", "-50%"], scale: [1, 1.05, 1] }}
      transition={{ duration: 2, repeat: Infinity }}
      className="absolute -bottom-16 left-1/2 -translate-x-1/2 px-6 py-2 rounded-2xl border border-blue-500/40 bg-blue-600/20 backdrop-blur-2xl flex items-center gap-3 shadow-[0_0_30px_rgba(37,99,235,0.3)]"
    >
      <div className="h-2 w-2 rounded-full bg-emerald-400 animate-ping" />
      <span className="text-[11px] font-black text-white uppercase tracking-[0.5em] whitespace-nowrap italic">Neural Sync Active</span>
    </motion.div>
  </div>
);

function BuildProgressPageInner() {
  const router = useRouter();
  const sp = useSearchParams();
  const { token } = useAuthToken();
  const projectId = sp?.get("projectId") || "";

  const [project, setProject] = useState<Project | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [elapsed, setElapsed] = useState(0);
  const [logs, setLogs] = useState<{msg: string, type: 'info' | 'warn' | 'success'}[]>([]);
  
  const timerRef = useRef<NodeJS.Timeout | null>(null);
  const pollRef = useRef<NodeJS.Timeout | null>(null);

  const addLog = (msg: string, type: 'info' | 'warn' | 'success' = 'info') => {
    setLogs(prev => [...prev.slice(-12), { msg, type }]);
  };

  useEffect(() => {
    if (!projectId || !token) return;

    // Initial logs
    addLog("Initializing build pipeline...", "info");
    addLog("Fetching project artifacts...", "info");

    timerRef.current = setInterval(() => {
      setElapsed(prev => prev + 1);
    }, 1000);

    const poll = async () => {
      try {
        const res = await apiFetch<any>(`/projects/${projectId}`, { method: "GET", token });
        const data = (res?.data ?? res) as Project;
        
        if (project?.status !== data.status) {
          if (data.status === "running") {
            if (data.generationMode === "scratch") {
              addLog("Synthesizing unique C# Logic Matrices...", "info");
              addLog("Assembling Procedural Objects...", "info");
            } else {
              addLog("Neural processor active. Baking game logic...", "success");
            }
          }
          if (data.status === "ready") addLog("Build verified. Artifacts deployed to edge.", "success");
          if (data.status === "failed") addLog("Critical build failure detected.", "warn");
        }
        
        setProject(data);

        if (data.status === "ready") {
          if (timerRef.current) clearInterval(timerRef.current);
          // Wait a bit so user can see "Ready" status
          setTimeout(() => router.replace(`/studio/projects/${projectId}`), 2000);
        } else if (data.status === "failed") {
          if (timerRef.current) clearInterval(timerRef.current);
          setError(data.error || "Build failed");
        } else {
          pollRef.current = setTimeout(poll, 2000);
        }
      } catch (e: any) {
        setError(e.message || "Failed to fetch build status");
      }
    };

    poll();

    return () => {
      if (timerRef.current) clearInterval(timerRef.current);
      if (pollRef.current) clearTimeout(pollRef.current);
    };
  }, [projectId, token]);

  const formatTime = (s: number) => {
    const mins = Math.floor(s / 60);
    const secs = s % 60;
    return `${mins}:${secs.toString().padStart(2, '0')}`;
  };

  const status = project?.status || "queued";

  return (
    <UserShell title="Build Reactor" subtitle="Real-time build progress and neural processing">
      <div className="max-w-6xl mx-auto py-6">
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-10 items-start">
          
          {/* Main Visual Section */}
          <div className="lg:col-span-7 space-y-10">
            <div className="gf-panel-strong rounded-[60px] p-12 flex flex-col items-center justify-center relative overflow-hidden min-h-[650px] border border-white/10 shadow-[0_0_150px_rgba(37,99,235,0.2)]">
              {/* High-End Background Effects */}
              <div className="absolute inset-0 bg-gradient-to-b from-blue-600/15 via-transparent to-black pointer-events-none" />
              <div className="absolute inset-0 gf-grid opacity-30 pointer-events-none" />
              
              {/* Floating HUD Elements */}
              <motion.div 
                animate={{ 
                  y: [0, -15, 0],
                  opacity: [0.3, 0.6, 0.3]
                }}
                transition={{ duration: 6, repeat: Infinity, ease: "easeInOut" }}
                className="absolute top-10 left-10 p-4 rounded-2xl border border-white/5 bg-white/[0.02] backdrop-blur-md hidden xl:block"
              >
                <div className="text-[8px] font-black text-blue-400 uppercase tracking-[0.3em] mb-2">Protocol Buffer</div>
                <div className="h-1 w-24 bg-white/5 rounded-full overflow-hidden">
                  <motion.div 
                    animate={{ width: ["0%", "100%", "0%"] }}
                    transition={{ duration: 4, repeat: Infinity }}
                    className="h-full bg-blue-500"
                  />
                </div>
              </motion.div>

              <motion.div 
                animate={{ 
                  y: [0, 15, 0],
                  opacity: [0.3, 0.6, 0.3]
                }}
                transition={{ duration: 5, repeat: Infinity, ease: "easeInOut", delay: 1 }}
                className="absolute bottom-20 right-10 p-4 rounded-2xl border border-white/5 bg-white/[0.02] backdrop-blur-md hidden xl:block"
              >
                <div className="text-[8px] font-black text-blue-400 uppercase tracking-[0.3em] mb-2">Neural Entropy</div>
                <div className="flex gap-1">
                  {[1,2,3,4].map(i => (
                    <motion.div 
                      key={i}
                      animate={{ height: [4, 12, 4] }}
                      transition={{ duration: 1, repeat: Infinity, delay: i * 0.2 }}
                      className="w-1 bg-blue-500/30 rounded-full"
                    />
                  ))}
                </div>
              </motion.div>
              
              <NeuralProcessor status={status} />

              <div className="mt-24 text-center relative z-10">
                <AnimatePresence mode="wait">
                  <motion.div
                    key={status}
                    initial={{ opacity: 0, y: 20, filter: "blur(10px)" }}
                    animate={{ opacity: 1, y: 0, filter: "blur(0px)" }}
                    exit={{ opacity: 0, y: -20, filter: "blur(10px)" }}
                    transition={{ duration: 0.5 }}
                  >
                    <h2 className="text-5xl font-black tracking-tighter text-white italic uppercase gf-chromatic">
                      {status === "queued" ? "Initializing Link" : 
                       status === "running" ? "Baking DNA" : 
                       status === "ready" ? "Link Synchronized" : "Build Fractured"}
                    </h2>
                    <p className="mt-6 text-zinc-400 max-w-sm mx-auto font-medium text-lg leading-relaxed">
                      {status === "failed" ? error : 
                       status === "ready" ? "Your digital universe is now stable and ready for deployment." :
                       "Processing procedural matrices and neural pathways for high-end runtime execution."}
                    </p>
                  </motion.div>
                </AnimatePresence>
              </div>

              {/* High-End Progress HUD */}
              <div className="mt-16 w-full max-w-md space-y-4">
                <div className="flex justify-between items-center px-2">
                  <span className="text-[10px] font-black text-zinc-500 uppercase tracking-[0.4em]">Core Integrity</span>
                  <span className="text-[10px] font-black text-blue-400 uppercase tracking-[0.4em]">
                    {status === "ready" ? "100%" : status === "running" ? "64%" : "12%"}
                  </span>
                </div>
                <div className="flex gap-2.5 w-full">
                  {[1, 2, 3, 4, 5, 6, 7, 8].map((i) => {
                    const active = (status === "ready") || (status === "running" && i <= 5) || (status === "queued" && i <= 1);
                    return (
                      <div key={i} className="flex-1 h-2 rounded-sm bg-white/5 overflow-hidden border border-white/5">
                        {active && (
                          <motion.div 
                            layoutId={`step-${i}`}
                            className="h-full bg-gradient-to-r from-blue-600 to-sky-400 shadow-[0_0_15px_rgba(37,99,235,0.8)]" 
                            initial={{ x: "-100%" }}
                            animate={{ x: "0%" }}
                            transition={{ type: "spring", stiffness: 100, damping: 15, delay: i * 0.05 }}
                          />
                        )}
                      </div>
                    );
                  })}
                </div>
              </div>
            </div>

            {/* Premium Actions */}
            <div className="flex gap-6">
              <button 
                onClick={() => router.replace(`/studio/projects/${projectId}`)}
                className="gf-btn flex-1 rounded-[32px] py-5 font-black uppercase tracking-[0.2em] text-xs flex items-center justify-center gap-3 text-zinc-500 hover:text-rose-400 hover:border-rose-500/30 transition-all group"
              >
                <motion.div whileHover={{ rotate: -90 }} transition={{ type: "spring" }}>
                  <X size={18} />
                </motion.div>
                Terminate Build
              </button>
              
              {status === "ready" ? (
                <motion.button 
                  initial={{ scale: 0.9, opacity: 0 }}
                  animate={{ scale: 1, opacity: 1 }}
                  whileHover={{ scale: 1.02 }}
                  whileTap={{ scale: 0.98 }}
                  onClick={() => router.push(`/studio/projects/${projectId}`)}
                  className="flex-[1.5] rounded-[32px] bg-white text-black py-5 font-black uppercase tracking-[0.2em] text-xs flex items-center justify-center gap-3 shadow-[0_20px_60px_rgba(255,255,255,0.2)] transition-all group overflow-hidden relative"
                >
                  <span className="relative z-10 flex items-center gap-3">
                    Enter Simulation <Rocket size={20} className="group-hover:translate-x-1 group-hover:-translate-y-1 transition-transform" />
                  </span>
                  <motion.div 
                    animate={{ x: ["-100%", "200%"] }}
                    transition={{ duration: 2, repeat: Infinity, ease: "linear" }}
                    className="absolute inset-0 bg-gradient-to-r from-transparent via-black/5 to-transparent skew-x-12"
                  />
                </motion.button>
              ) : (
                <div className="flex-[1.5] rounded-[32px] bg-white/5 border border-white/10 py-5 flex items-center justify-center gap-3 grayscale opacity-50">
                  <span className="text-[10px] font-black uppercase tracking-[0.2em] text-zinc-500">Awaiting Deployment</span>
                </div>
              )}
            </div>
          </div>

          {/* High-End Sidebar */}
          <div className="lg:col-span-5 space-y-8">
            
            {/* Real-time Telemetry */}
            <div className="grid grid-cols-2 gap-6">
              <motion.div whileHover={{ y: -5 }} className="gf-panel rounded-[40px] p-8 border border-white/5 relative overflow-hidden group">
                <div className="absolute top-0 right-0 p-4 opacity-5 group-hover:opacity-10 transition-opacity">
                  <Timer size={60} />
                </div>
                <div className="flex items-center gap-3 text-zinc-500 mb-4">
                  <Timer size={16} className="text-blue-400" />
                  <span className="text-[10px] font-black uppercase tracking-[0.3em] leading-none">Telemetry</span>
                </div>
                <div className="text-4xl font-black text-white italic tracking-tighter gf-chromatic">{formatTime(elapsed)}</div>
                <div className="mt-2 text-[9px] font-bold text-zinc-600 uppercase tracking-widest">Active Runtime</div>
              </motion.div>

              <motion.div whileHover={{ y: -5 }} className="gf-panel rounded-[40px] p-8 border border-white/5 relative overflow-hidden group">
                <div className="absolute top-0 right-0 p-4 opacity-5 group-hover:opacity-10 transition-opacity">
                  <Activity size={60} />
                </div>
                <div className="flex items-center gap-3 text-zinc-500 mb-4">
                  <Activity size={16} className="text-blue-400" />
                  <span className="text-[10px] font-black uppercase tracking-[0.3em] leading-none">Load State</span>
                </div>
                <div className="text-2xl font-black text-white uppercase italic tracking-tighter truncate">
                  {status === "running" ? "Critical" : status}
                </div>
                <div className="mt-2 text-[9px] font-bold text-zinc-600 uppercase tracking-widest">Neural Stress</div>
              </motion.div>
            </div>

            {/* Advanced Terminal */}
            <div className="gf-panel-strong rounded-[48px] p-10 border border-white/10 relative overflow-hidden h-[480px] flex flex-col shadow-2xl group/terminal">
              {/* Matrix Background for Terminal */}
              <div className="absolute inset-0 opacity-5 pointer-events-none group-hover/terminal:opacity-10 transition-opacity">
                <MatrixRain />
              </div>
              
              <div className="flex items-center justify-between mb-8 relative z-10">
                <div className="flex items-center gap-4">
                  <div className="h-10 w-10 rounded-xl bg-blue-600/10 flex items-center justify-center">
                    <Terminal size={20} className="text-blue-400" />
                  </div>
                  <div>
                    <span className="text-[10px] font-black uppercase tracking-[0.3em] text-white">Neural Stream</span>
                    <div className="text-[8px] font-bold text-zinc-600 uppercase tracking-widest mt-0.5">Encrypted Protocol 0.42</div>
                  </div>
                </div>
                <div className="flex gap-2">
                  <div className="h-2 w-2 rounded-full bg-rose-500 animate-pulse" />
                  <div className="h-2 w-2 rounded-full bg-blue-600/20" />
                </div>
              </div>

              <div className="flex-1 font-mono text-[10px] space-y-4 overflow-y-auto gf-scrollbar pr-4">
                <AnimatePresence>
                  {logs.map((log, i) => (
                    <motion.div 
                      initial={{ opacity: 0, x: -10, filter: "blur(5px)" }}
                      animate={{ opacity: 1, x: 0, filter: "blur(0px)" }}
                      key={`${i}-${log.msg}`} 
                      className="flex gap-4 leading-relaxed group"
                    >
                      <span className="text-zinc-700 shrink-0 font-bold">[{formatTime(elapsed)}]</span>
                      <div className={
                        log.type === 'success' ? 'text-emerald-400' : 
                        log.type === 'warn' ? 'text-rose-400' : 'text-zinc-400'
                      }>
                        <span className="mr-2 opacity-50">{log.type === 'success' ? '●' : log.type === 'warn' ? '▲' : '○'}</span>
                        {log.msg}
                      </div>
                    </motion.div>
                  ))}
                </AnimatePresence>
                <div className="flex gap-2 text-blue-500">
                  <span className="animate-pulse font-black text-lg">_</span>
                </div>
              </div>

              {/* Functional HUD Accents */}
              <div className="mt-8 pt-8 border-t border-white/5 grid grid-cols-3 gap-4">
                {[
                  { icon: Box, label: "Assets", value: "Verified" },
                  { icon: Binary, label: "DNA", value: "Baking" },
                  { icon: Code2, label: "Logic", value: "Baking" }
                ].map(item => (
                  <div key={item.label} className="flex flex-col items-center gap-2 group cursor-default">
                    <motion.div 
                      whileHover={{ scale: 1.1, rotate: 5 }}
                      className="h-12 w-full rounded-2xl bg-white/[0.03] border border-white/5 flex items-center justify-center transition-all group-hover:bg-white/10 group-hover:border-white/20"
                    >
                      <item.icon size={18} className="text-zinc-500 group-hover:text-blue-400 transition-colors" />
                    </motion.div>
                    <span className="text-[8px] font-black uppercase tracking-widest text-zinc-600 group-hover:text-zinc-400 transition-colors">{item.label}</span>
                  </div>
                ))}
              </div>
            </div>
          </div>

        </div>
      </div>
    </UserShell>
  );
}

export default function BuildProgressPage() {
  return (
    <Suspense fallback={null}>
      <BuildProgressPageInner />
    </Suspense>
  );
}

