"use client";

import { useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { motion, AnimatePresence } from "framer-motion";
import { 
  FileText, 
  Image as ImageIcon, 
  Package, 
  Search, 
  Plus, 
  MoreHorizontal,
  Download,
  Trash2,
  ExternalLink,
  Sparkles,
  X,
  Code2,
  Box,
  Activity
} from "lucide-react";
import UserShell from "@/app/_components/UserShell";
import { apiFetch, ApiError } from "@/lib/api";
import { getUserToken } from "@/lib/userAuth";
import { normalizeImageUrl } from "@/lib/media";

type Asset = {
  id: string;
  _id?: string;
  name: string;
  type: string;
  url: string;
  thumbnailUrl?: string;
  size?: number;
  createdAt: string;
};

const AssetEditor = ({ asset, onClose }: { asset: Asset; onClose: () => void }) => {
  const [brightness, setBrightness] = useState(100);
  const [saturation, setSaturation] = useState(100);
  const [hue, setHue] = useState(0);

  return (
    <motion.div 
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      exit={{ opacity: 0 }}
      className="fixed inset-0 z-[100] bg-[#05060a]/95 backdrop-blur-2xl flex items-center justify-center p-6"
    >
      <div className="gf-panel-strong gf-stroke-gradient rounded-[40px] max-w-5xl w-full grid grid-cols-1 lg:grid-cols-12 overflow-hidden shadow-[0_0_100px_rgba(99,102,241,0.2)]">
        <div className="lg:col-span-8 bg-black/40 flex items-center justify-center p-12 relative group">
          <motion.img 
            style={{ filter: `brightness(${brightness}%) saturate(${saturation}%) hue-rotate(${hue}deg)` }}
            src={normalizeImageUrl(asset.url)} 
            alt={asset.name}
            className="max-w-full max-h-[60vh] rounded-2xl shadow-2xl transition-all duration-300"
          />
          <div className="absolute top-6 left-6 flex items-center gap-3">
            <div className="h-10 w-10 rounded-xl bg-indigo-500/20 flex items-center justify-center text-indigo-400">
              <Sparkles size={20} />
            </div>
            <div>
              <div className="text-sm font-bold text-white uppercase tracking-tight">Neural Editor</div>
              <div className="text-[10px] text-zinc-500 font-medium uppercase tracking-widest">Post-Processing v1</div>
            </div>
          </div>
        </div>

        <div className="lg:col-span-4 p-10 space-y-10 border-l border-white/5">
          <div className="flex items-center justify-between">
            <h3 className="text-xl font-bold text-white tracking-tight">Adjustments</h3>
            <button onClick={onClose} className="gf-btn p-2 rounded-full text-zinc-500 hover:text-white transition-all">
              <X size={20} />
            </button>
          </div>

          <div className="space-y-8">
            <div className="space-y-4">
              <div className="flex justify-between text-[10px] font-black uppercase tracking-widest text-zinc-500">
                <span>Brightness</span>
                <span className="text-indigo-400">{brightness}%</span>
              </div>
              <input 
                type="range" min="0" max="200" value={brightness}
                onChange={(e) => setBrightness(parseInt(e.target.value))}
                className="w-full h-1 bg-white/5 rounded-full appearance-none accent-indigo-500"
              />
            </div>

            <div className="space-y-4">
              <div className="flex justify-between text-[10px] font-black uppercase tracking-widest text-zinc-500">
                <span>Saturation</span>
                <span className="text-fuchsia-400">{saturation}%</span>
              </div>
              <input 
                type="range" min="0" max="200" value={saturation}
                onChange={(e) => setSaturation(parseInt(e.target.value))}
                className="w-full h-1 bg-white/5 rounded-full appearance-none accent-fuchsia-500"
              />
            </div>

            <div className="space-y-4">
              <div className="flex justify-between text-[10px] font-black uppercase tracking-widest text-zinc-500">
                <span>Hue Rotate</span>
                <span className="text-cyan-400">{hue}°</span>
              </div>
              <input 
                type="range" min="0" max="360" value={hue}
                onChange={(e) => setHue(parseInt(e.target.value))}
                className="w-full h-1 bg-white/5 rounded-full appearance-none accent-cyan-500"
              />
            </div>
          </div>

          <div className="pt-10 border-t border-white/5 space-y-3">
            <button className="w-full rounded-2xl bg-white text-black py-4 font-black uppercase tracking-widest shadow-xl hover:scale-105 active:scale-95 transition-all">
              Bake Changes
            </button>
            <button 
              onClick={() => { setBrightness(100); setSaturation(100); setHue(0); }}
              className="w-full gf-btn rounded-2xl py-4 text-xs font-black uppercase tracking-widest text-zinc-500 hover:text-white transition-all"
            >
              Reset DNA
            </button>
          </div>
        </div>
      </div>
    </motion.div>
  );
};

export default function AssetsLibraryPage() {
  const router = useRouter();
  const token = useMemo(() => getUserToken(), []);
  const [loading, setLoading] = useState(true);
  const [assets, setAssets] = useState<Asset[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [search, setSearch] = useState("");
  const [filter, setFilter] = useState("All");
  const [editingAsset, setEditingAsset] = useState<Asset | null>(null);

  useEffect(() => {
    let cancelled = false;
    async function load() {
      if (!token) return;
      setLoading(true);
      try {
        const res = await apiFetch<any>("/assets", { method: "GET", token });
        const data = (res && typeof res === "object" && "data" in res) ? res.data : res;
        if (!cancelled) {
          const list = Array.isArray(data) ? data : (Array.isArray(data?.data) ? data.data : []);
          setAssets(list);
        }
      } catch (e: any) {
        if (!cancelled) setError("Failed to load assets");
      } finally {
        if (!cancelled) setLoading(false);
      }
    }
    load();
    return () => { cancelled = true; };
  }, [token]);

  const filteredAssets = useMemo(() => {
    return assets.filter(a => {
      const matchesSearch = a.name.toLowerCase().includes(search.toLowerCase());
      const matchesFilter = filter === "All" || 
        (filter === "Images" && a.type.startsWith("image/")) ||
        (filter === "Models" && (a.type.includes("json") || a.type.includes("binary")));
      return matchesSearch && matchesFilter;
    });
  }, [assets, search, filter]);

  return (
    <UserShell title="Asset Vault" subtitle="Neural-linked library for your game data">
      <div className="space-y-8 pb-20">
        
        {/* Control Bar */}
        <div className="flex flex-col md:flex-row gap-6 items-center justify-between">
          <div className="relative flex-1 w-full group">
            <div className="absolute inset-0 bg-indigo-500/5 blur-xl opacity-0 group-focus-within:opacity-100 transition-opacity" />
            <Search className="absolute left-5 top-1/2 -translate-y-1/2 text-zinc-500" size={20} />
            <input 
              className="gf-input w-full rounded-[24px] pl-14 pr-6 py-4 text-sm border-white/10 focus:border-indigo-500/50 bg-black/40 transition-all shadow-inner"
              placeholder="Search assets by name or type..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
            />
          </div>
          
          <div className="flex items-center gap-3 w-full md:w-auto">
            <div className="flex bg-white/[0.03] border border-white/5 p-1.5 rounded-2xl">
              {["All", "Images", "Models"].map(f => (
                <button
                  key={f}
                  onClick={() => setFilter(f)}
                  className={`px-4 py-2 rounded-xl text-[10px] font-black uppercase tracking-widest transition-all ${
                    filter === f ? "bg-white text-black shadow-lg" : "text-zinc-500 hover:text-white"
                  }`}
                >
                  {f}
                </button>
              ))}
            </div>
            <button className="rounded-2xl bg-indigo-500 p-3 text-white shadow-lg shadow-indigo-500/20 hover:scale-105 active:scale-95 transition-all">
              <Plus size={20} strokeWidth={3} />
            </button>
          </div>
        </div>

        {/* Neural Node Explorer Header */}
        <section className="animate-in fade-in slide-in-from-bottom-4 duration-700 delay-300">
          <div className="flex items-center justify-between mb-6">
            <h3 className="text-[11px] font-black text-white uppercase tracking-[0.3em] flex items-center gap-3">
              <div className="h-1 w-8 bg-fuchsia-500 rounded-full" />
              Neural Node Explorer
            </h3>
            <div className="flex items-center gap-2 text-[10px] font-black text-zinc-500 bg-white/5 border border-white/5 px-3 py-1.5 rounded-full uppercase tracking-widest">
              <div className="h-1.5 w-1.5 rounded-full bg-fuchsia-500 animate-pulse" />
              Interactive Map
            </div>
          </div>
          
          <div className="gf-holographic rounded-[40px] p-12 h-[400px] relative overflow-hidden group">
            <div className="absolute inset-0 bg-[#05060a]/40 backdrop-blur-3xl" />
            
            {/* Visualizer Background */}
            <div className="absolute inset-0 opacity-20">
              <svg className="w-full h-full">
                <defs>
                  <pattern id="hexagons" width="50" height="43.4" patternUnits="userSpaceOnUse" patternTransform="scale(2)">
                    <path d="M25 0 L50 14.4 L50 43.4 L25 57.8 L0 43.4 L0 14.4 Z" fill="none" stroke="white" strokeWidth="0.5" />
                  </pattern>
                </defs>
                <rect width="100%" height="100%" fill="url(#hexagons)" />
              </svg>
            </div>

            {/* Neural Nodes */}
            <div className="absolute inset-0 flex items-center justify-center">
              <div className="relative w-full max-w-2xl h-full flex items-center justify-center">
                {[...Array(8)].map((_, i) => (
                  <motion.div
                    key={i}
                    animate={{
                      scale: [1, 1.1, 1],
                      opacity: [0.3, 0.6, 0.3],
                      rotate: [0, 360],
                    }}
                    transition={{
                      duration: 10 + i * 2,
                      repeat: Infinity,
                      ease: "linear"
                    }}
                    className="absolute border border-indigo-500/20 rounded-full"
                    style={{
                      width: `${100 + i * 60}px`,
                      height: `${100 + i * 60}px`,
                    }}
                  />
                ))}
                
                {/* Center Core */}
                <motion.div 
                  whileHover={{ scale: 1.1 }}
                  className="h-24 w-24 rounded-full bg-white flex items-center justify-center text-black z-10 shadow-[0_0_50px_rgba(255,255,255,0.3)] cursor-pointer"
                >
                  <Package size={32} />
                </motion.div>

                {/* Satellite Nodes (Assets) */}
                {[
                  { label: "Textures", icon: ImageIcon, color: "text-indigo-400", pos: "top-10 left-20" },
                  { label: "Logic", icon: Code2, color: "text-fuchsia-400", pos: "bottom-20 right-10" },
                  { label: "Models", icon: Box, color: "text-cyan-400", pos: "top-1/2 -left-10" },
                  { label: "Audio", icon: Activity, color: "text-emerald-400", pos: "bottom-10 left-1/2" },
                ].map((node, i) => (
                  <motion.div
                    key={i}
                    initial={{ opacity: 0 }}
                    animate={{ opacity: 1 }}
                    whileHover={{ scale: 1.1, y: -5 }}
                    className={`absolute ${node.pos} z-20 flex flex-col items-center gap-3 cursor-pointer group/node`}
                  >
                    <div className={`h-12 w-12 rounded-2xl bg-black/60 border border-white/10 flex items-center justify-center ${node.color} backdrop-blur-xl group-hover/node:border-white/30 transition-all`}>
                      <node.icon size={20} />
                    </div>
                    <span className="text-[9px] font-black uppercase tracking-[0.2em] text-white/40 group-hover/node:text-white transition-colors">{node.label}</span>
                  </motion.div>
                ))}
              </div>
            </div>

            {/* Scanning HUD */}
            <div className="absolute top-10 left-10 flex flex-col gap-2">
              <div className="flex items-center gap-2">
                <div className="h-1.5 w-1.5 rounded-full bg-indigo-500 animate-pulse" />
                <span className="text-[10px] font-black uppercase tracking-widest text-indigo-400">Neural Sync: Active</span>
              </div>
              <div className="text-[9px] font-bold text-zinc-600 uppercase tracking-widest leading-none">Scanning 12,402 global nodes...</div>
            </div>
          </div>
        </section>

        {loading ? (
          <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 xl:grid-cols-6 gap-6">
            {Array.from({ length: 12 }).map((_, i) => (
              <div key={i} className="aspect-square gf-panel-strong rounded-[32px] animate-pulse bg-white/5" />
            ))}
          </div>
        ) : filteredAssets.length === 0 ? (
          <div className="gf-panel-strong rounded-[48px] p-20 text-center border-dashed border-white/10">
            <div className="h-20 w-20 rounded-3xl bg-indigo-500/10 flex items-center justify-center text-4xl mx-auto mb-6">
              📦
            </div>
            <h3 className="text-2xl font-bold text-white uppercase italic">Vault Empty</h3>
            <p className="text-zinc-500 mt-2 font-medium">Upload project assets or generate them using AI.</p>
          </div>
        ) : (
          <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 xl:grid-cols-6 gap-6">
            {filteredAssets.map((a, i) => {
              const id = a._id || a.id;
              const img = normalizeImageUrl(a.thumbnailUrl || a.url);
              const isImg = a.type.startsWith('image/');
              
              return (
                <motion.div 
                  initial={{ opacity: 0, scale: 0.9 }}
                  animate={{ opacity: 1, scale: 1 }}
                  transition={{ delay: i * 0.03 }}
                  key={id} 
                  className="group relative aspect-square gf-card rounded-[32px] overflow-hidden border border-white/5 bg-white/[0.02] transition-all hover:-translate-y-1 hover:border-indigo-500/30 shadow-xl"
                >
                  {isImg && img ? (
                    <img src={img} alt={a.name} className="h-full w-full object-cover opacity-80 group-hover:opacity-100 transition-opacity" />
                  ) : (
                    <div className="h-full w-full flex flex-col items-center justify-center bg-zinc-900/50">
                      {a.type.includes('json') ? <FileText className="text-indigo-400 mb-2" size={32} /> : <Package className="text-fuchsia-400 mb-2" size={32} />}
                      <span className="text-[8px] font-black text-zinc-600 uppercase tracking-widest">{a.type.split('/')[1] || 'DATA'}</span>
                    </div>
                  )}
                  
                  {/* Hover Overlay */}
                  <div className="absolute inset-0 bg-[#05060a]/80 backdrop-blur-sm opacity-0 group-hover:opacity-100 transition-all p-4 flex flex-col justify-between">
                    <div className="flex justify-end gap-2">
                      <button 
                        onClick={(e) => {
                          e.stopPropagation();
                          setEditingAsset(a);
                        }}
                        className="p-2 rounded-xl bg-white/5 hover:bg-white/10 text-white transition-colors"
                      >
                        <Sparkles size={14} />
                      </button>
                      <button className="p-2 rounded-xl bg-white/5 hover:bg-white/10 text-white transition-colors">
                        <ExternalLink size={14} />
                      </button>
                      <button className="p-2 rounded-xl bg-rose-500/10 hover:bg-rose-500/20 text-rose-400 transition-colors">
                        <Trash2 size={14} />
                      </button>
                    </div>
                    <div className="min-w-0">
                      <p className="text-[10px] font-black text-white truncate uppercase tracking-tight">{a.name}</p>
                      <p className="text-[8px] text-indigo-400 font-bold uppercase tracking-widest mt-1">
                        {a.size ? `${(a.size / 1024).toFixed(1)} KB` : 'Cloud Sync'}
                      </p>
                    </div>
                  </div>

                  {/* Icon Badge */}
                  <div className="absolute top-3 left-3 pointer-events-none group-hover:opacity-0 transition-opacity">
                    <div className="h-6 w-6 rounded-lg bg-black/60 backdrop-blur-md flex items-center justify-center border border-white/10">
                      {isImg ? <ImageIcon size={12} className="text-zinc-400" /> : <Package size={12} className="text-zinc-400" />}
                    </div>
                  </div>
                </motion.div>
              );
            })}
          </div>
        )}

        <AnimatePresence>
          {editingAsset && (
            <AssetEditor asset={editingAsset} onClose={() => setEditingAsset(null)} />
          )}
        </AnimatePresence>

        {/* AI Insight Card */}
        <div className="gf-panel-strong gf-stroke-gradient rounded-[40px] p-8 flex flex-col md:flex-row items-center justify-between gap-8 mt-12 overflow-hidden relative group">
          <div className="absolute top-0 right-0 p-8 opacity-[0.03] group-hover:opacity-[0.07] transition-opacity">
            <Sparkles size={160} />
          </div>
          <div className="relative z-10 text-center md:text-left">
            <div className="inline-flex items-center gap-2 rounded-full border border-indigo-500/20 bg-indigo-500/5 px-4 py-1 text-[10px] font-black uppercase tracking-widest text-indigo-400 mb-4">
              <Sparkles size={12} />
              AI Assistant
            </div>
            <h3 className="text-2xl font-bold text-white">Need more assets?</h3>
            <p className="text-zinc-400 text-sm mt-2 max-w-sm">Use our Neural Weaver to generate custom high-res textures and 3D models instantly.</p>
          </div>
          <button className="relative z-10 rounded-2xl bg-white text-black px-8 py-4 text-xs font-black uppercase tracking-[0.2em] shadow-xl hover:scale-105 active:scale-95 transition-all">
            Open Generator
          </button>
        </div>
      </div>
    </UserShell>
  );
}
