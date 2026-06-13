"use client";

import { useState, useEffect } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { Command, Search, Rocket, Sparkles, Layout, Database, Settings, X, Zap } from "lucide-react";
import { useRouter } from "next/navigation";

type CommandItem = {
  id: string;
  title: string;
  subtitle: string;
  icon: any;
  href: string;
  category: string;
};

const COMMANDS: CommandItem[] = [
  { id: "home", title: "Home", subtitle: "Go to dashboard", icon: Layout, href: "/studio", category: "Navigation" },
  { id: "new-project", title: "New Project", subtitle: "Create from blueprint", icon: Rocket, href: "/studio/projects/new", category: "Actions" },
  { id: "ai-coach", title: "AI Coach", subtitle: "Neural assistant chat", icon: Sparkles, href: "/studio/ai/coach", category: "AI Tools" },
  { id: "marketplace", title: "Marketplace", subtitle: "Browse templates", icon: Database, href: "/studio/marketplace", category: "Discovery" },
  { id: "settings", title: "Settings", subtitle: "Account preferences", icon: Settings, href: "/studio/settings", category: "System" },
];

export default function CommandCenter() {
  const [open, setOpen] = useState(false);
  const [search, setSearch] = useState("");
  const router = useRouter();

  useEffect(() => {
    const down = (e: KeyboardEvent) => {
      if (e.key === "k" && (e.metaKey || e.ctrlKey)) {
        e.preventDefault();
        setOpen((open) => !open);
      }
      if (e.key === "Escape") setOpen(false);
    };

    document.addEventListener("keydown", down);
    return () => document.removeEventListener("keydown", down);
  }, []);

  const filtered = COMMANDS.filter(c => 
    c.title.toLowerCase().includes(search.toLowerCase()) || 
    c.subtitle.toLowerCase().includes(search.toLowerCase())
  );

  if (!open) return null;

  return (
    <div className="fixed inset-0 z-[200] flex items-start justify-center pt-[15vh] px-4">
      <motion.div 
        initial={{ opacity: 0 }} 
        animate={{ opacity: 1 }} 
        exit={{ opacity: 0 }}
        onClick={() => setOpen(false)}
        className="absolute inset-0 bg-[#05060a]/80 backdrop-blur-md" 
      />
      
      <motion.div
        initial={{ opacity: 0, scale: 0.95, y: -20 }}
        animate={{ opacity: 1, scale: 1, y: 0 }}
        className="relative w-full max-w-2xl bg-[#0a0b14] border border-white/10 rounded-[32px] shadow-[0_0_100px_rgba(99,102,241,0.2)] overflow-hidden"
      >
        <div className="flex items-center px-6 py-5 border-b border-white/5">
          <Search className="text-blue-400 mr-4" size={20} />
          <input 
            autoFocus
            className="flex-1 bg-transparent border-none outline-none text-lg text-white placeholder:text-zinc-600 font-medium"
            placeholder="Search commands, projects, or tools... (⌘K)"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
          <div className="flex items-center gap-2">
            <span className="text-[10px] font-black text-zinc-600 border border-white/10 px-2 py-1 rounded-lg">ESC</span>
          </div>
        </div>

        <div className="max-h-[60vh] overflow-y-auto gf-scrollbar p-3">
          {filtered.length === 0 ? (
            <div className="py-12 text-center">
              <div className="text-zinc-600 text-sm">No commands found for "{search}"</div>
            </div>
          ) : (
            <div className="space-y-6 p-2">
              {Array.from(new Set(filtered.map(c => c.category))).map(cat => (
                <div key={cat} className="space-y-2">
                  <div className="px-3 text-[10px] font-black uppercase tracking-[0.2em] text-zinc-500">{cat}</div>
                  <div className="space-y-1">
                    {filtered.filter(c => c.category === cat).map(item => (
                      <button
                        key={item.id}
                        onClick={() => {
                          router.push(item.href);
                          setOpen(false);
                        }}
                        className="w-full flex items-center gap-4 px-4 py-3 rounded-2xl hover:bg-white/[0.03] transition-all group text-left"
                      >
                        <div className="h-10 w-10 rounded-xl bg-white/5 flex items-center justify-center text-zinc-400 group-hover:text-blue-400 transition-colors">
                          <item.icon size={20} />
                        </div>
                        <div className="flex-1">
                          <div className="text-sm font-bold text-white uppercase tracking-tight">{item.title}</div>
                          <div className="text-xs text-zinc-500 font-medium">{item.subtitle}</div>
                        </div>
                        <ChevronRight size={16} className="text-zinc-700 opacity-0 group-hover:opacity-100 transition-all" />
                      </button>
                    ))}
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>

        <div className="px-6 py-4 bg-black/40 border-t border-white/5 flex items-center justify-between">
          <div className="flex items-center gap-4">
            <div className="flex items-center gap-1.5">
              <div className="h-4 w-4 rounded bg-white/5 flex items-center justify-center text-[10px] text-zinc-500 border border-white/10">↑</div>
              <div className="h-4 w-4 rounded bg-white/5 flex items-center justify-center text-[10px] text-zinc-500 border border-white/10">↓</div>
              <span className="text-[10px] text-zinc-600 font-bold uppercase tracking-widest">Navigate</span>
            </div>
            <div className="flex items-center gap-1.5">
              <div className="h-4 w-8 rounded bg-white/5 flex items-center justify-center text-[10px] text-zinc-500 border border-white/10">ENTER</div>
              <span className="text-[10px] text-zinc-600 font-bold uppercase tracking-widest">Select</span>
            </div>
          </div>
          <div className="flex items-center gap-2">
            <Zap size={12} className="text-blue-500" />
            <span className="text-[9px] font-black text-blue-500/60 uppercase tracking-[0.2em]">Neural Command v1.0</span>
          </div>
        </div>
      </motion.div>
    </div>
  );
}

function ChevronRight({ size, className }: { size?: number, className?: string }) {
  return (
    <svg width={size || 24} height={size || 24} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className={className}>
      <path d="m9 18 6-6-6-6" />
    </svg>
  );
}
