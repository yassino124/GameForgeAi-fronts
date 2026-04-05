"use client";

import { useEffect, useMemo, useState } from "react";
import { useParams, useRouter } from "next/navigation";
import UserShell from "@/app/_components/UserShell";
import { apiFetch, ApiError, API_BASE_URL } from "@/lib/api";
import { getUserToken } from "@/lib/userAuth";
import { normalizeImageUrl } from "@/lib/media";
import { motion, AnimatePresence } from "framer-motion";
import { 
  Zap, 
  Rocket, 
  ArrowLeft, 
  Download, 
  Star, 
  ShieldCheck, 
  Cpu, 
  Sparkles,
  Layout,
  Gamepad2,
  User,
  Heart
} from "lucide-react";

type Template = {
  id?: string;
  _id?: string;
  name?: string;
  title?: string;
  description?: string;
  category?: string;
  tags?: string[];
  price?: number;
  priceUsd?: number;
  rating?: number;
  downloads?: number;
  downloadCount?: number;
  previewImageUrl?: string;
  thumbnailUrl?: string;
  imageUrl?: string;
  previewVideoUrl?: string;
  screenshots?: string[];
  updatedAt?: string;
  createdAt?: string;
  ownerId?: string;
  ownerUsername?: string;
  ownerAvatar?: string;
  ownerRole?: string;
};

function toNum(v: any) {
  if (typeof v === "number") return v;
  if (typeof v === "string") return Number(v) || 0;
  return 0;
}

export default function TemplateDetailsPage() {
  const router = useRouter();
  const params = useParams<{ id: string }>();
  const token = useMemo(() => getUserToken(), []);
  const id = (params?.id || "").toString();

  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [tpl, setTpl] = useState<Template | null>(null);

  useEffect(() => {
    let cancelled = false;
    async function load() {
      if (!id) return;
      setLoading(true);
      setError(null);
      try {
        const res = await apiFetch<any>(`/templates/${encodeURIComponent(id)}`, { method: "GET", token: token || undefined });
        const data = (res && typeof res === "object" && "data" in res) ? (res as any).data : res;
        if (!cancelled) setTpl((data?.data ?? data) as Template);
      } catch (e: any) {
        if (!cancelled) setError(e instanceof ApiError ? e.message : (e?.message || "Failed to load template"));
      } finally {
        if (!cancelled) setLoading(false);
      }
    }
    load();
    return () => {
      cancelled = true;
    };
  }, [id, token]);

  const title = (tpl?.name || tpl?.title || "Template").toString();
  const img = normalizeImageUrl(tpl?.previewImageUrl || tpl?.thumbnailUrl || tpl?.imageUrl);
  const price = tpl?.price ?? tpl?.priceUsd;

  const handleDownload = async () => {
    if (!id || !token) return;
    try {
      const res = await apiFetch<any>(`/templates/${encodeURIComponent(id)}/download-url`, { method: "GET", token });
      const url = res?.data?.url || res?.url;
      if (typeof url === "string" && url.startsWith("http")) {
        window.open(url, "_blank");
      } else {
        window.open(`${API_BASE_URL}/templates/${encodeURIComponent(id)}/download?token=${token}`, "_blank");
      }
    } catch (e) {
      window.open(`${API_BASE_URL}/templates/${encodeURIComponent(id)}/download?token=${token}`, "_blank");
    }
  };

  return (
    <UserShell
      title={title}
      subtitle={tpl?.category ? tpl.category : "Template details"}
      right={
        <button 
          className="gf-btn rounded-xl px-4 py-2 text-sm flex items-center gap-2 font-bold hover:bg-white/10 transition-all" 
          onClick={() => router.push("/studio/marketplace")}
        >
          <ArrowLeft size={16} /> Back
        </button>
      }
    >
      {error ? <div className="mb-4 rounded-2xl border border-red-500/20 bg-red-500/10 px-4 py-3 text-sm text-red-200">{error}</div> : null}

      <div className="grid grid-cols-1 gap-8 lg:grid-cols-3 pb-20">
        {/* Main Preview Section */}
        <div className="lg:col-span-2 space-y-8">
          <motion.div 
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            className="gf-panel-strong overflow-hidden rounded-[40px] p-0 border border-white/10 shadow-2xl relative group"
          >
            <div className="relative aspect-[16/9] w-full overflow-hidden bg-black">
              {tpl?.previewVideoUrl ? (
                <video
                  src={tpl.previewVideoUrl}
                  autoPlay
                  loop
                  muted
                  playsInline
                  className="h-full w-full object-cover opacity-80"
                />
              ) : img ? (
                <motion.img 
                  initial={{ scale: 1.1 }}
                  animate={{ scale: 1 }}
                  transition={{ duration: 1.5 }}
                  src={img} 
                  alt="" 
                  className="h-full w-full object-cover" 
                />
              ) : (
                <div className="h-full w-full bg-gradient-to-br from-indigo-500/30 via-fuchsia-500/15 to-cyan-500/10" />
              )}
              
              {/* Immersive Overlays */}
              <div className="pointer-events-none absolute inset-0 bg-gradient-to-t from-[#05060a] via-black/20 to-transparent opacity-90" />
              <div className="pointer-events-none absolute inset-0 bg-gradient-to-tr from-indigo-500/10 via-transparent to-fuchsia-500/10 opacity-0 group-hover:opacity-100 transition-opacity duration-1000" />
              
              {/* Badge System */}
              <div className="absolute top-6 left-6 flex items-center gap-3">
                {tpl?.category && (
                  <div className="rounded-2xl bg-indigo-500/20 border border-indigo-500/30 backdrop-blur-xl px-4 py-2 text-[10px] font-black uppercase tracking-[0.2em] text-indigo-300">
                    {tpl.category}
                  </div>
                )}
                <div className="rounded-2xl bg-white/5 border border-white/10 backdrop-blur-xl px-4 py-2 text-[10px] font-black uppercase tracking-[0.2em] text-zinc-400 flex items-center gap-2">
                  <Sparkles size={12} /> Premium Asset
                </div>
              </div>

              {/* Video Play Indicator */}
              {tpl?.previewVideoUrl && (
                <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 pointer-events-none">
                  <motion.div 
                    animate={{ scale: [1, 1.2, 1], opacity: [0.5, 0.8, 0.5] }}
                    transition={{ duration: 3, repeat: Infinity }}
                    className="h-20 w-20 rounded-full border border-white/20 bg-white/5 backdrop-blur-sm flex items-center justify-center"
                  >
                    <div className="h-12 w-12 rounded-full bg-white/10 flex items-center justify-center">
                      <Zap size={24} className="text-white fill-white" />
                    </div>
                  </motion.div>
                </div>
              )}

              {/* Title & Stats Overlay */}
              <div className="absolute bottom-0 left-0 right-0 p-10 pt-20">
                <div className="flex flex-col gap-4">
                  <motion.h2 
                    initial={{ opacity: 0, x: -20 }}
                    animate={{ opacity: 1, x: 0 }}
                    transition={{ delay: 0.3 }}
                    className="text-5xl font-black tracking-tighter text-white uppercase italic gf-chromatic"
                  >
                    {title}
                  </motion.h2>
                  
                  <div className="flex items-center gap-6">
                    <div className="flex items-center gap-2 text-zinc-400 font-bold text-sm">
                      <Star className="text-yellow-400 fill-yellow-400" size={16} />
                      {tpl?.rating || "4.9"} <span className="text-zinc-600 font-medium">(128 reviews)</span>
                    </div>
                    <div className="h-1 w-1 rounded-full bg-zinc-700" />
                    <div className="flex items-center gap-2 text-zinc-400 font-bold text-sm">
                      <Download size={16} className="text-indigo-400" />
                      {toNum(tpl?.downloads ?? tpl?.downloadCount).toLocaleString()} downloads
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </motion.div>

          {/* Description & Features Grid */}
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <motion.div 
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.4 }}
              className="gf-panel rounded-[32px] p-8 space-y-4"
            >
              <h3 className="text-xs font-black text-zinc-500 uppercase tracking-[0.3em]">Core Architecture</h3>
              <p className="text-zinc-300 leading-relaxed font-medium">
                {tpl?.description?.trim() || "Advanced procedural generation logic with integrated neural feedback systems. This template provides a high-performance foundation for next-gen game loops."}
              </p>
            </motion.div>

            <motion.div 
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.5 }}
              className="gf-panel rounded-[32px] p-8"
            >
              <h3 className="text-xs font-black text-zinc-500 uppercase tracking-[0.3em] mb-6">Technical Specifications</h3>
              <div className="space-y-4">
                {[
                  { label: "Optimization", value: "Ultra High", icon: Cpu },
                  { label: "Mobile Ready", value: "Certified", icon: ShieldCheck },
                  { label: "Logic Nodes", value: "Procedural", icon: Layout }
                ].map((spec, i) => (
                  <div key={i} className="flex items-center justify-between group">
                    <div className="flex items-center gap-3">
                      <div className="p-2 rounded-lg bg-white/5 text-zinc-500 group-hover:text-indigo-400 transition-colors">
                        <spec.icon size={14} />
                      </div>
                      <span className="text-xs font-bold text-zinc-400">{spec.label}</span>
                    </div>
                    <span className="text-xs font-black text-white uppercase tracking-wider italic">{spec.value}</span>
                  </div>
                ))}
              </div>
            </motion.div>
          </div>
        </div>

        {/* Sidebar Actions */}
        <div className="space-y-6">
          <motion.div 
            initial={{ opacity: 0, x: 20 }}
            animate={{ opacity: 1, x: 0 }}
            transition={{ delay: 0.6 }}
            className="gf-panel-strong rounded-[40px] p-8 border border-white/10 relative overflow-hidden"
          >
            <div className="absolute inset-0 bg-gradient-to-br from-indigo-500/5 via-transparent to-transparent pointer-events-none" />
            
            <div className="relative z-10 space-y-8">
              <div className="flex justify-between items-center">
                <span className="text-xs font-black text-zinc-500 uppercase tracking-[0.3em]">Acquisition</span>
                <div className="text-3xl font-black text-white italic tracking-tighter">
                  {typeof price === "number" && price > 0 ? `$${price.toFixed(2)}` : "FREE"}
                </div>
              </div>

              <div className="space-y-3">
                <button
                  className="group relative w-full overflow-hidden rounded-[24px] bg-gradient-to-r from-indigo-500 to-fuchsia-500 py-5 font-black uppercase tracking-[0.2em] text-white transition-all hover:scale-[1.03] active:scale-[0.97] shadow-[0_20px_40px_rgba(99,102,241,0.3)]"
                  disabled={loading}
                  onClick={() => router.push(`/studio/projects/new?templateId=${encodeURIComponent(id)}`)}
                >
                  <span className="relative z-10 flex items-center justify-center gap-3">
                    Initialize Project <Rocket size={20} />
                  </span>
                  <motion.div 
                    animate={{ x: ["-100%", "200%"] }}
                    transition={{ duration: 3, repeat: Infinity, ease: "linear" }}
                    className="absolute inset-0 bg-gradient-to-r from-transparent via-white/10 to-transparent skew-x-12"
                  />
                </button>
                
                <button 
                  className="w-full rounded-[24px] bg-white/5 border border-white/5 py-5 font-black uppercase tracking-[0.2em] text-zinc-400 hover:bg-white/10 hover:text-indigo-400 hover:border-indigo-500/30 transition-all transition-transform active:scale-[0.98]"
                  onClick={handleDownload}
                >
                  <span className="flex items-center justify-center gap-3">
                    Download Asset <Download size={18} />
                  </span>
                </button>
              </div>

              {/* Master Architect Showcase */}
              <div className="pt-6 border-t border-white/5">
                <div className="text-[10px] font-black text-zinc-600 uppercase tracking-[0.3em] mb-4">Master Architect</div>
                <div 
                  onClick={() => tpl?.ownerId && router.push(`/studio/profile/${encodeURIComponent(tpl.ownerId)}`)}
                  className="flex items-center justify-between rounded-2xl bg-white/[0.03] border border-white/5 p-4 group transition-all hover:bg-white/[0.05] hover:border-indigo-500/20 cursor-pointer active:scale-[0.98]"
                >
                  <div className="flex items-center gap-4">
                    <div className="relative h-12 w-12 rounded-xl overflow-hidden bg-indigo-500/10 flex items-center justify-center text-indigo-400 group-hover:scale-105 transition-transform">
                      {tpl?.ownerAvatar ? (
                        <img src={normalizeImageUrl(tpl.ownerAvatar)} className="h-full w-full object-cover" alt="" />
                      ) : (
                        <User size={24} />
                      )}
                      
                      <div className="absolute -right-1 -bottom-1 h-5 w-5 rounded-full bg-[#05060a] flex items-center justify-center">
                        <ShieldCheck size={12} className="text-emerald-400 fill-emerald-400/20" />
                      </div>
                    </div>
                    
                    <div>
                      <div className="text-sm font-black text-white hover:text-indigo-400 transition-colors cursor-pointer uppercase italic tracking-tight">
                        {tpl?.ownerUsername || "Nexus-1 Prime"}
                      </div>
                      <div className="text-[9px] font-bold text-zinc-500 uppercase tracking-widest mt-1">
                        {tpl?.ownerRole === "admin" ? "System Architect" : tpl?.ownerRole || "Core Architect"}
                      </div>
                    </div>
                  </div>
                  
                  <button className="h-10 w-10 rounded-xl bg-white/5 border border-white/5 flex items-center justify-center text-zinc-500 hover:text-rose-400 hover:bg-rose-400/10 hover:border-rose-400/20 transition-all">
                    <Heart size={16} />
                  </button>
                </div>
              </div>

              <div className="pt-6 border-t border-white/5">
                <div className="text-[10px] font-black text-zinc-600 uppercase tracking-[0.3em] mb-4 text-center">Metadata Tags</div>
                <div className="flex flex-wrap gap-2 justify-center">
                  {tpl?.tags?.length ? tpl.tags.slice(0, 12).map((tag) => (
                    <span key={tag} className="rounded-xl border border-white/5 bg-black/40 px-3 py-1.5 text-[9px] font-black uppercase tracking-widest text-zinc-500 hover:text-indigo-400 hover:border-indigo-500/30 transition-all cursor-default">
                      #{tag}
                    </span>
                  )) : (
                    ["game", "procedural", "high-performance"].map(tag => (
                      <span key={tag} className="rounded-xl border border-white/5 bg-black/40 px-3 py-1.5 text-[9px] font-black uppercase tracking-widest text-zinc-500">
                        #{tag}
                      </span>
                    ))
                  )}
                </div>
              </div>
            </div>
          </motion.div>

          {/* Integration Badge */}
          <motion.div 
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.7 }}
            className="gf-panel rounded-[32px] p-6 flex items-center gap-4 border-emerald-500/10"
          >
            <div className="h-12 w-12 rounded-2xl bg-emerald-500/10 flex items-center justify-center text-emerald-400 shadow-[0_0_20px_rgba(16,185,129,0.1)]">
              <Gamepad2 size={24} />
            </div>
            <div>
              <div className="text-[10px] font-black text-emerald-500 uppercase tracking-widest">Integrated</div>
              <div className="text-xs font-bold text-zinc-400">Direct-to-Studio Pipeline</div>
            </div>
          </motion.div>
        </div>
      </div>
    </UserShell>
  );
}
