"use client";

import { useEffect, useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { Terminal, Zap, ShieldCheck, Activity } from "lucide-react";

export default function ForgeConsole() {
  const [logs, setLogs] = useState<{ id: string; msg: string; type: string; time: string }[]>([]);
  const [isOpen, setIsOpen] = useState(false);

  useEffect(() => {
    const messages = [
      { msg: "Neural weights loaded successfully", type: "info" },
      { msg: "Asset pipeline: Optimizing PBR textures", type: "process" },
      { msg: "Compiler: WEBGL target ready", type: "success" },
      { msg: "Physics Core: Stability 99.8%", type: "status" },
      { msg: "Syncing with Forge-V4 global nodes", type: "network" },
    ];

    const interval = setInterval(() => {
      const randomMsg = messages[Math.floor(Math.random() * messages.length)];
      const newLog = {
        id: Math.random().toString(36).substr(2, 9),
        msg: randomMsg.msg,
        type: randomMsg.type,
        time: new Date().toLocaleTimeString([], { hour12: false, hour: '2-digit', minute: '2-digit', second: '2-digit' }),
      };
      setLogs((prev) => [newLog, ...prev].slice(0, 50));
    }, 5000);

    return () => clearInterval(interval);
  }, []);

  return (
    <div className="fixed bottom-0 left-[260px] right-0 z-[40] pointer-events-none p-4">
      <div className="max-w-7xl mx-auto flex flex-col items-start gap-2">
        <button 
          onClick={() => setIsOpen(!isOpen)}
          className="pointer-events-auto gf-holographic px-4 py-1.5 rounded-t-xl border-b-0 text-[9px] font-black uppercase tracking-[0.2em] text-blue-400 flex items-center gap-2 hover:bg-white/5 transition-all"
        >
          <Terminal size={12} />
          System Console
          <div className="h-1 w-1 rounded-full bg-blue-400 animate-pulse shadow-[0_0_8px_rgba(59,130,246,0.8)]" />
        </button>

        <AnimatePresence>
          {isOpen && (
            <motion.div
              initial={{ height: 0, opacity: 0 }}
              animate={{ height: 160, opacity: 1 }}
              exit={{ height: 0, opacity: 0 }}
              className="pointer-events-auto w-full gf-holographic rounded-tr-[32px] rounded-br-none rounded-bl-none p-4 font-mono text-[10px] overflow-hidden flex flex-col shadow-2xl"
            >
              <div className="flex-1 overflow-y-auto gf-scrollbar space-y-1.5 opacity-60">
                {logs.length === 0 ? (
                  <div className="text-zinc-600 italic">Initializing Forge-V4 system logs...</div>
                ) : (
                  logs.map((log) => (
                    <div key={log.id} className="flex gap-4">
                      <span className="text-zinc-700 shrink-0">[{log.time}]</span>
                      <span className="text-blue-500 shrink-0 uppercase font-black">[{log.type}]</span>
                      <span className="text-zinc-400">{log.msg}</span>
                    </div>
                  ))
                )}
              </div>
              <div className="mt-4 pt-3 border-t border-white/5 flex items-center justify-between text-[9px] font-black uppercase tracking-widest text-zinc-600">
                <div className="flex gap-6">
                  <span className="flex items-center gap-1.5"><Zap size={10} /> Latency: 12ms</span>
                  <span className="flex items-center gap-1.5"><ShieldCheck size={10} /> Secure Node</span>
                  <span className="flex items-center gap-1.5"><Activity size={10} /> CPU: 14%</span>
                </div>
                <div>v4.0.2-stable</div>
              </div>
            </motion.div>
          )}
        </AnimatePresence>
      </div>
    </div>
  );
}
