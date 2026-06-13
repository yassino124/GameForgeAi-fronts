"use client";
import { useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import UserShell from "@/app/_components/UserShell";

const OLLAMA_BASE = "http://localhost:11434";

const THEMES = [
  { id: "forest",  label: "Forest",  icon: "🌲", color: "#10b981", img: "https://images.unsplash.com/photo-1448375240586-882707db888b?w=600" },
  { id: "space",   label: "Space",   icon: "🚀", color: "#6366f1", img: "https://images.unsplash.com/photo-1462331940025-496dfbfc7564?w=600" },
  { id: "ocean",   label: "Ocean",   icon: "🌊", color: "#0ea5e9", img: "https://images.unsplash.com/photo-1518020382113-a7e8fc38eac9?w=600" },
  { id: "city",    label: "City",    icon: "🏙️", color: "#f59e0b", img: "https://images.unsplash.com/photo-1514565131-fce0801e6c40?w=600" },
  { id: "dungeon", label: "Dungeon", icon: "⚔️", color: "#ef4444", img: "https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=600" },
  { id: "neon",    label: "Neon",    icon: "💜", color: "#8b5cf6", img: "https://images.unsplash.com/photo-1542751371-adc38448a05e?w=600" },
  { id: "desert",  label: "Desert",  icon: "🏜️", color: "#f97316", img: "https://images.unsplash.com/photo-1509316785289-025f5b846b35?w=600" },
];

const MOCK_WORLDS = [
  { id: "1", name: "Neon City Hub",       theme: "neon",   players: 142, portals: 6, rating: 4.8, event: "⚡ Boss Raid Active" },
  { id: "2", name: "Space Station Omega", theme: "space",  players: 89,  portals: 4, rating: 4.6, event: null },
  { id: "3", name: "Enchanted Forest",    theme: "forest", players: 67,  portals: 8, rating: 4.9, event: "🎉 Festival" },
  { id: "4", name: "Deep Ocean Realm",    theme: "ocean",  players: 34,  portals: 3, rating: 4.4, event: null },
];
type World = typeof MOCK_WORLDS[number] & { isOwned?: boolean };

async function askOllama(model: string, prompt: string): Promise<string> {
  const res = await fetch(`${OLLAMA_BASE}/api/generate`, {
    method: "POST", headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ model, prompt, stream: false }),
    signal: AbortSignal.timeout(60000),
  });
  if (!res.ok) throw new Error(`Ollama ${res.status}`);
  const d = await res.json();
  return d.response || "";
}

export default function WorldsPage() {
  const [tab, setTab]               = useState<"discover" | "create">("discover");
  const [theme, setTheme]           = useState("neon");
  const [worldName, setWorldName]   = useState("");
  const [creating, setCreating]     = useState(false);
  const [worlds, setWorlds]         = useState<World[]>(MOCK_WORLDS);
  const [ollamaOk, setOllamaOk]     = useState<boolean | null>(null);
  const [model, setModel]           = useState("llama3.2");
  const [aiDesc, setAiDesc]         = useState("");
  const [aiEvents, setAiEvents]     = useState<string[]>([]);
  const [aiLoading, setAiLoading]   = useState(false);

  const themeColor = (id: string) => THEMES.find(t => t.id === id)?.color ?? "#8b5cf6";
  const themeImg   = (id: string) => THEMES.find(t => t.id === id)?.img ?? "";
  const themeIcon  = (id: string) => THEMES.find(t => t.id === id)?.icon ?? "🌐";

  const checkOllama = async () => {
    try {
      const r = await fetch(`${OLLAMA_BASE}/api/tags`, { signal: AbortSignal.timeout(3000) });
      setOllamaOk(r.ok);
    } catch { setOllamaOk(false); }
  };

  const generateWithAI = async () => {
    if (!worldName.trim()) return;
    setAiLoading(true);
    try {
      const [desc, eventsRaw] = await Promise.all([
        askOllama(model, `Write an immersive world description (max 50 words) for a multiplayer game world called "${worldName}" with ${theme} theme. Return ONLY the description.`),
        askOllama(model, `Generate 4 creative event ideas for a ${theme}-themed game world called "${worldName}". Return ONLY a JSON array: ["Event1","Event2","Event3","Event4"]`),
      ]);
      setAiDesc(desc.trim());
      try { setAiEvents(JSON.parse(eventsRaw.replace(/```[\w]*\n?/g,"").replace(/```/g,"").trim())); }
      catch { setAiEvents(["Boss Raid", "Festival", "Treasure Hunt", "Invasion"]); }
    } catch { setAiDesc(""); setAiEvents([]); }
    finally { setAiLoading(false); }
  };

  const createWorld = async () => {
    if (!worldName.trim()) return;
    setCreating(true);
    await new Promise(r => setTimeout(r, 800));
    setWorlds(prev => [{ id: Date.now().toString(), name: worldName, theme, players: 0, portals: 0, rating: 0, event: null, isOwned: true }, ...prev]);
    setWorldName(""); setAiDesc(""); setAiEvents([]); setCreating(false); setTab("discover");
  };

  const totalPlayers = worlds.reduce((s, w) => s + w.players, 0);

  return (
    <UserShell title="GF Worlds" subtitle="Mondes Persistants · Ollama"
      right={
        <div className="flex items-center gap-2 px-3 py-1.5 rounded-xl bg-emerald-500/10 border border-emerald-500/20">
          <span className="h-2 w-2 rounded-full bg-emerald-400 animate-pulse" />
          <span className="text-[12px] font-bold text-emerald-400">{totalPlayers} online</span>
        </div>
      }>

      {/* Tabs */}
      <div className="flex gap-3 mb-5">
        {(["discover","create"] as const).map(t => (
          <button key={t} onClick={() => setTab(t)}
            className={`px-5 py-2.5 rounded-xl text-sm font-bold border transition-all ${tab === t ? "bg-violet-500/20 border-violet-500/40 text-violet-300" : "bg-white/[0.03] border-white/[0.07] text-zinc-500 hover:text-white"}`}>
            {t === "discover" ? "🌐 Discover" : "➕ Create World"}
          </button>
        ))}
      </div>

      {tab === "discover" ? (
        <div>
          <div className="grid grid-cols-4 gap-4 mb-6">
            {[
              { label: "Active Worlds", val: worlds.length },
              { label: "Total Players", val: totalPlayers },
              { label: "Live Events",   val: worlds.filter(w => w.event).length },
              { label: "Total Portals", val: worlds.reduce((s, w) => s + w.portals, 0) },
            ].map(s => (
              <div key={s.label} className="p-4 rounded-2xl bg-white/[0.03] border border-white/[0.07]">
                <p className="text-2xl font-black text-white">{s.val}</p>
                <p className="text-[11px] text-zinc-500 mt-1">{s.label}</p>
              </div>
            ))}
          </div>
          <div className="grid md:grid-cols-2 xl:grid-cols-3 gap-4">
            {worlds.map((w, i) => {
              const c = themeColor(w.theme);
              return (
                <motion.div key={w.id} initial={{ opacity: 0, y: 12 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: i * 0.05 }}
                  className="rounded-2xl border overflow-hidden" style={{ borderColor: `${c}30`, backgroundColor: "rgba(255,255,255,0.02)" }}>
                  <div className="relative h-36">
                    <img src={themeImg(w.theme)} alt="" className="w-full h-full object-cover opacity-60" />
                    <div className="absolute inset-0" style={{ background: "linear-gradient(to bottom, transparent, rgba(0,0,0,0.85))" }} />
                    {w.event && <span className="absolute top-2 left-2 px-2 py-1 rounded-full bg-red-500/90 text-white text-[10px] font-bold">{w.event}</span>}
                    {(w as any).isOwned && <span className="absolute top-2 right-2 px-2 py-1 rounded-full bg-violet-600 text-white text-[10px] font-bold">MINE</span>}
                    <div className="absolute bottom-2 left-3 right-3 flex justify-between items-end">
                      <p className="text-white font-black text-sm">{w.name}</p>
                      <div className="flex items-center gap-1 text-white/70 text-[10px]"><span>👤</span><span>{w.players}</span></div>
                    </div>
                  </div>
                  <div className="p-3 flex items-center justify-between">
                    <div className="flex items-center gap-3 text-[11px] text-zinc-500">
                      <span>{themeIcon(w.theme)} {w.theme}</span>
                      <span>🎮 {w.portals} portals</span>
                      {w.rating > 0 && <span>⭐ {w.rating}</span>}
                    </div>
                    <button className="px-3 py-1.5 rounded-lg text-[11px] font-bold text-white transition-all hover:opacity-80"
                      style={{ background: `linear-gradient(135deg, ${c}, ${c}99)` }}>Enter</button>
                  </div>
                </motion.div>
              );
            })}
          </div>
        </div>
      ) : (
        <div className="max-w-2xl mx-auto space-y-5">
          {/* Ollama status + model */}
          <div className="flex items-center gap-3 flex-wrap">
            <div className="flex items-center gap-2 px-3 py-2 rounded-xl bg-white/[0.04] border border-white/[0.08]">
              <div className={`h-2 w-2 rounded-full ${ollamaOk === true ? "bg-emerald-400 animate-pulse" : ollamaOk === false ? "bg-red-400" : "bg-zinc-600"}`} />
              <span className="text-[11px] font-bold text-zinc-400">
                Ollama {ollamaOk === true ? "Connected" : ollamaOk === false ? "Offline" : "Not checked"}
              </span>
              <button onClick={checkOllama} className="text-[10px] px-2 py-0.5 rounded-md bg-white/[0.06] hover:bg-white/[0.1] text-zinc-500 hover:text-white transition-all">ping</button>
            </div>
            {["llama3.2","mistral","phi3"].map(m => (
              <button key={m} onClick={() => setModel(m)}
                className={`px-3 py-2 rounded-xl text-[11px] font-bold border transition-all ${model === m ? "bg-indigo-500/20 border-indigo-500/40 text-indigo-300" : "bg-white/[0.03] border-white/[0.07] text-zinc-600 hover:text-white"}`}>
                {m}
              </button>
            ))}
          </div>

          {/* Theme picker */}
          <div>
            <p className="text-[11px] font-black uppercase tracking-widest text-zinc-500 mb-3">Thème</p>
            <div className="grid grid-cols-7 gap-2">
              {THEMES.map(t => (
                <button key={t.id} onClick={() => setTheme(t.id)}
                  className="flex flex-col items-center gap-1.5 p-2 rounded-xl border transition-all"
                  style={theme === t.id ? { backgroundColor: `${t.color}20`, borderColor: `${t.color}60` } : { backgroundColor: "rgba(255,255,255,0.02)", borderColor: "rgba(255,255,255,0.07)" }}>
                  <span className="text-xl">{t.icon}</span>
                  <span className="text-[9px] font-bold" style={{ color: theme === t.id ? t.color : "#71717a" }}>{t.label}</span>
                </button>
              ))}
            </div>
          </div>

          {/* Theme preview */}
          <div className="relative h-28 rounded-2xl overflow-hidden border border-white/[0.08]">
            <img src={themeImg(theme)} alt="" className="w-full h-full object-cover" />
            <div className="absolute inset-0 bg-black/40 flex items-center justify-center">
              <span className="text-4xl">{themeIcon(theme)}</span>
            </div>
          </div>

          {/* Name + AI generate */}
          <div>
            <p className="text-[11px] font-black uppercase tracking-widest text-zinc-500 mb-2">Nom du monde</p>
            <div className="flex gap-3">
              <input value={worldName} onChange={e => setWorldName(e.target.value)}
                placeholder='"The Neon Nexus"'
                className="flex-1 rounded-xl bg-white/[0.04] border border-white/[0.08] text-white placeholder:text-zinc-600 text-sm p-3 outline-none focus:border-indigo-500/40" />
              <button onClick={generateWithAI} disabled={aiLoading || !worldName.trim()}
                className="px-4 py-3 rounded-xl text-[12px] font-bold border border-indigo-500/30 bg-indigo-500/10 text-indigo-300 hover:bg-indigo-500/20 transition-all disabled:opacity-40">
                {aiLoading ? <span className="flex items-center gap-2"><span className="h-3 w-3 rounded-full border-2 border-indigo-300/30 border-t-indigo-300 animate-spin" />AI…</span> : "🦙 Générer avec Ollama"}
              </button>
            </div>
          </div>

          {/* AI results */}
          <AnimatePresence>
            {(aiDesc || aiEvents.length > 0) && (
              <motion.div initial={{ opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0 }}
                className="p-4 rounded-xl bg-indigo-500/[0.07] border border-indigo-500/20 space-y-3">
                {aiDesc && (
                  <div>
                    <p className="text-[10px] font-bold text-indigo-400 mb-1">🦙 Description générée</p>
                    <p className="text-[12px] text-white/70 italic leading-relaxed">{aiDesc}</p>
                  </div>
                )}
                {aiEvents.length > 0 && (
                  <div>
                    <p className="text-[10px] font-bold text-indigo-400 mb-2">⚡ Événements suggérés</p>
                    <div className="flex flex-wrap gap-2">
                      {aiEvents.map((e, i) => (
                        <span key={i} className="px-2 py-1 rounded-lg bg-indigo-500/20 border border-indigo-500/30 text-[11px] text-indigo-300 font-bold">{e}</span>
                      ))}
                    </div>
                  </div>
                )}
              </motion.div>
            )}
          </AnimatePresence>

          {/* NFT toggle */}
          <div className="flex items-center justify-between p-4 rounded-xl bg-white/[0.03] border border-white/[0.07]">
            <div><p className="text-sm font-bold text-white">💎 Cosmétiques NFT (ERC1155)</p><p className="text-[11px] text-zinc-600">Items NFT équipables dans ce monde</p></div>
            <div className="h-6 w-11 rounded-full bg-violet-600 relative cursor-pointer"><div className="absolute right-1 top-1 h-4 w-4 rounded-full bg-white" /></div>
          </div>

          <button onClick={createWorld} disabled={creating || !worldName.trim()}
            className="w-full py-3.5 rounded-xl font-black text-white transition-all disabled:opacity-40"
            style={{ background: "linear-gradient(135deg, #6366f1, #0ea5e9)", boxShadow: "0 8px 24px rgba(99,102,241,0.3)" }}>
            {creating ? <span className="flex items-center justify-center gap-2"><span className="h-4 w-4 rounded-full border-2 border-white/30 border-t-white animate-spin" />Création…</span> : "🌐 Créer le Monde"}
          </button>
        </div>
      )}
    </UserShell>
  );
}
