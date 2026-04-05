"use client";

import { useEffect, useMemo, useState, useRef } from "react";
import { useRouter } from "next/navigation";
import { motion, AnimatePresence, useMotionValue, useTransform, useSpring } from "framer-motion";
import { 
  Wallet as WalletIcon, TrendingUp, DollarSign, 
  ArrowUpRight, Clock, CheckCircle2, Heart, 
  Sparkles, Rocket, RefreshCw, ChevronRight,
  Activity, Zap, Shield, CreditCard,
  Cpu, Target, Search, Coins, ArrowDownRight, Layers
} from "lucide-react";
import UserShell from "@/app/_components/UserShell";
import { apiFetch, ApiError } from "@/lib/api";
import { getUserToken } from "@/lib/userAuth";

type Transaction = {
  id: string;
  amount: number;
  currency: string;
  type: string;
  status: 'completed' | 'pending' | 'failed';
  description: string;
  createdAt: string;
};

type WalletData = {
  activeBalance: number;
  pendingRevenue: number;
  totalEarned: number;
  currency: string;
  transactions: Transaction[];
  isRealData?: boolean;
};

export default function WalletPage() {
  const router = useRouter();
  const token = useMemo(() => getUserToken(), []);
  const [loading, setLoading] = useState(true);
  const [wallet, setWallet] = useState<WalletData | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [syncStatus, setSyncStatus] = useState<"synced" | "probing" | "failed">("probing");

  // 3D Tilt Values
  const x = useMotionValue(0);
  const y = useMotionValue(0);
  const mouseX = useMotionValue(0);
  const mouseY = useMotionValue(0);

  const rotateX = useSpring(useTransform(y, [-150, 150], [10, -10]), { stiffness: 150, damping: 20 });
  const rotateY = useSpring(useTransform(x, [-150, 150], [-10, 10]), { stiffness: 150, damping: 20 });

  function handleMouseMove(event: React.MouseEvent<HTMLDivElement>) {
    const rect = event.currentTarget.getBoundingClientRect();
    const centerX = rect.left + rect.width / 2;
    const centerY = rect.top + rect.height / 2;
    x.set(event.clientX - centerX);
    y.set(event.clientY - centerY);
    mouseX.set(event.clientX - rect.left);
    mouseY.set(event.clientY - rect.top);
  }

  function handleMouseLeave() {
    x.set(0);
    y.set(0);
  }

  useEffect(() => {
    let cancelled = false;
    async function syncRealData() {
      if (!token) return;
      setLoading(true);
      setSyncStatus("probing");
      
      try {
        // Direct synchronization with Creator Monetization Engine
        const [walletRes, txRes] = await Promise.all([
          apiFetch<any>("/creator-monetization/me/wallet", { method: "GET", token }),
          apiFetch<any>("/creator-monetization/me/transactions", { method: "GET", token }),
        ]);

        const w = (walletRes && typeof walletRes === "object" && "data" in walletRes) ? walletRes.data : walletRes;
        const txData = (txRes && typeof txRes === "object" && "data" in txRes) ? txRes.data : txRes;

        // Cents to USD Conversion Mapping
        const activeBalance = Number(w?.availableBalanceCents || 0) / 100;
        const pendingRevenue = Number(w?.pendingBalanceCents || 0) / 100;
        const totalEarned = Number(w?.lifetimeEarningsCents || 0) / 100;
        const currency = String(w?.currency || "USD").toUpperCase();

        const transactions: Transaction[] = (txData || []).map((t: any) => ({
          id: String(t.id || t._id),
          amount: Number(t.amountGrossCents || t.creatorNetCents || 0) / 100,
          currency: String(t.currency || "USD").toUpperCase(),
          type: String(t.type || "earning"),
          status: (t.status === 'succeeded' ? 'completed' : 'pending') as any,
          description: t.description || t.title || (t.type === 'tip' ? 'Donation Received' : t.type === 'template_sale' ? 'Asset Sale' : 'Monetization Capture'),
          createdAt: t.createdAt
        }));

        if (!cancelled) {
          setWallet({
            activeBalance,
            pendingRevenue,
            totalEarned,
            currency,
            transactions,
            isRealData: true
          });
          setSyncStatus("synced");
        }
      } catch (e: any) {
        if (!cancelled) {
          setError("Neural link status unstable (Real Data Unavailable)");
          setSyncStatus("failed");
        }
      } finally {
        if (!cancelled) setLoading(false);
      }
    }

    syncRealData();
    const interval = setInterval(syncRealData, 15000); // 15s High-Frequency Sync
    return () => {
      cancelled = true;
      clearInterval(interval);
    };
  }, [token]);

  const getTxIcon = (type: string) => {
    const t = type.toLowerCase();
    if (t.includes('donation') || t.includes('tip')) return <Heart size={18} className="text-rose-400" />;
    if (t.includes('sale') || t.includes('template')) return <Layers size={18} className="text-cyan-400" />;
    if (t.includes('ad')) return <Activity size={18} className="text-emerald-400" />;
    return <Coins size={18} className="text-amber-400" />;
  };

  return (
    <UserShell title="Creator Wallet" subtitle="Neural Financial Center">
      <div className="max-w-2xl mx-auto space-y-12 pb-20">
        
        {/* Holographic Balance Card (Master Architect 3D) */}
        <div 
          className="perspective-[1200px] h-80"
          onMouseMove={handleMouseMove}
          onMouseLeave={handleMouseLeave}
        >
          <motion.div
            style={{ rotateX, rotateY, transformStyle: "preserve-3d" }}
            className="relative h-full w-full rounded-[48px] overflow-hidden border border-white/10 shadow-[0_50px_100px_rgba(0,0,0,0.6)] group bg-[#05060a]"
          >
            {/* Neural Surface Layer */}
            <div className="absolute inset-0 bg-gradient-to-br from-indigo-600/30 via-transparent to-fuchsia-600/30" />
            
            {/* Interactive Spotlight */}
            <motion.div 
              style={{ 
                left: mouseX, 
                top: mouseY,
                background: "radial-gradient(circle at center, rgba(255,255,255,0.15) 0%, transparent 60%)"
              }}
              className="absolute pointer-events-none w-[800px] h-[800px] -translate-x-1/2 -translate-y-1/2 rounded-full"
            />

            {/* Neural Grid Overlay */}
            <div className="absolute inset-0 opacity-[0.03]" style={{ backgroundImage: "linear-gradient(rgba(255,255,255,0.1) 1px, transparent 1px), linear-gradient(90deg, rgba(255,255,255,0.1) 1px, transparent 1px)", backgroundSize: "30px 30px" }} />

            <div className="relative h-full p-12 flex flex-col justify-between text-white z-10">
              <div className="flex items-center justify-between">
                 <div className="flex items-center gap-4">
                   <motion.div 
                     animate={{ opacity: [0.4, 1, 0.4] }}
                     transition={{ duration: 1.5, repeat: Infinity }}
                     className={`h-3 w-3 rounded-full ${syncStatus === 'synced' ? 'bg-emerald-400 shadow-[0_0_15px_#34d399]' : 'bg-amber-400 animate-pulse'} `} 
                   />
                   <div className="space-y-0.5">
                     <span className="text-[10px] font-black uppercase tracking-[0.4em] opacity-60">Neural Financial Sync</span>
                     <div className="text-[9px] font-mono text-indigo-400 opacity-80 uppercase tracking-widest">{syncStatus === 'synced' ? 'Link Secure' : 'Probing Data...'}</div>
                   </div>
                 </div>
                 <div className="flex items-center gap-2">
                   <div className="h-10 w-10 rounded-xl bg-white/5 backdrop-blur-3xl border border-white/10 flex items-center justify-center text-indigo-300">
                     <Cpu size={18} />
                   </div>
                 </div>
              </div>

              <div>
                <div className="flex items-center gap-3 mb-3">
                  <Target size={12} className="text-indigo-400/50" />
                  <span className="text-[11px] font-black uppercase tracking-[0.6em] opacity-50">Active Balance</span>
                </div>
                <div className="flex items-baseline gap-5">
                  <AnimatePresence mode="wait">
                    <motion.h2 
                      key={wallet?.activeBalance}
                      initial={{ opacity: 0, y: 10 }}
                      animate={{ opacity: 1, y: 0 }}
                      className="text-8xl font-black italic tracking-tighter gf-chromatic drop-shadow-2xl"
                    >
                      {loading && !wallet ? "..." : (wallet?.activeBalance || 0).toLocaleString(undefined, { minimumFractionDigits: 2 })}
                    </motion.h2>
                  </AnimatePresence>
                  <span className="text-3xl font-black text-indigo-500/80 italic">{wallet?.currency || "USD"}</span>
                </div>
              </div>

              <div className="grid grid-cols-2 gap-16 border-t border-white/5 pt-8 mt-4">
                <div className="space-y-2">
                  <p className="text-[10px] font-black uppercase tracking-widest opacity-40 flex items-center gap-2">
                    <Clock size={10} /> Pending Hub
                  </p>
                  <p className="text-3xl font-black italic text-zinc-200">
                    ${(wallet?.pendingRevenue || 0).toLocaleString(undefined, { minimumFractionDigits: 2 })}
                  </p>
                </div>
                <div className="space-y-2">
                  <p className="text-[10px] font-black uppercase tracking-widest opacity-40 flex items-center gap-2">
                    <Activity size={10} /> Architect Earnings
                  </p>
                  <p className="text-3xl font-black italic text-indigo-400">
                    ${(wallet?.totalEarned || 0).toLocaleString(undefined, { minimumFractionDigits: 2 })}
                  </p>
                </div>
              </div>
            </div>
          </motion.div>
        </div>

        {/* Global Action Trigger Hub */}
        <div className="flex gap-6">
          <motion.button
            whileHover={{ scale: 1.02, y: -5 }}
            whileTap={{ scale: 0.98 }}
            className="flex-1 h-20 rounded-[32px] bg-gradient-to-r from-indigo-500 to-indigo-600 text-white flex items-center justify-center gap-4 font-black text-xs uppercase tracking-[0.4em] shadow-[0_20px_50px_rgba(99,102,241,0.4)] border border-white/20"
          >
            <Rocket size={20} /> Payout Status
          </motion.button>
          <motion.button
            whileHover={{ scale: 1.05, rotate: -2 }}
            whileTap={{ scale: 0.95 }}
            onClick={() => window.location.reload()}
            className="h-20 w-20 rounded-[32px] bg-white text-black flex items-center justify-center shadow-2xl border border-white/20"
          >
            <RefreshCw size={20} />
          </motion.button>
        </div>

        {/* Ledger Transaction Feed */}
        <div className="space-y-8">
          <div className="flex items-center justify-between px-6">
             <div className="flex items-center gap-4">
               <div className="h-10 w-10 rounded-xl bg-white/5 flex items-center justify-center border border-white/10">
                 <Shield size={18} className="text-indigo-400" />
               </div>
               <h3 className="text-3xl font-black text-white italic uppercase tracking-tighter">Secure Ledger</h3>
             </div>
             <div className="flex items-center gap-3">
               <div className="h-2 w-2 rounded-full bg-emerald-500 animate-pulse" />
               <span className="text-[10px] font-black text-zinc-500 uppercase tracking-widest">{wallet?.transactions.length || 0} Items</span>
             </div>
          </div>

          <div className="space-y-4 px-2">
            {loading && !wallet ? (
              Array.from({ length: 6 }).map((_, i) => (
                <div key={i} className="h-28 w-full rounded-[48px] bg-white/5 animate-pulse" />
              ))
            ) : !wallet?.transactions.length ? (
              <div className="gf-panel rounded-[48px] p-24 text-center border-dashed border-white/5 bg-black/20">
                <div className="h-20 w-20 rounded-full bg-white/5 flex items-center justify-center mx-auto mb-8 border border-white/5">
                   <Search size={32} className="text-zinc-700" />
                </div>
                <div className="text-zinc-500 font-black uppercase tracking-[0.6em] text-sm">Ledger Empty</div>
                <div className="mt-2 text-zinc-600 text-[10px] uppercase tracking-[0.3em] italic">New architecture transactions will manifest here shortly</div>
              </div>
            ) : (
              wallet.transactions.map((t, idx) => (
                <motion.div
                  key={t.id}
                  initial={{ opacity: 0, scale: 0.95, y: 10 }}
                  animate={{ opacity: 1, scale: 1, y: 0 }}
                  transition={{ delay: idx * 0.05 }}
                  className="group flex items-center gap-8 p-8 rounded-[48px] bg-white/[0.02] border border-white/5 hover:border-indigo-500/30 hover:bg-indigo-500/[0.03] transition-all relative overflow-hidden"
                >
                  <div className="h-16 w-16 rounded-[24px] bg-[#0d0e12] border border-white/5 flex items-center justify-center shadow-2xl group-hover:scale-110 transition-transform">
                    {getTxIcon(t.type)}
                  </div>
                  
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-4">
                      <div className="text-2xl font-black text-white italic uppercase tracking-tight truncate">{t.description}</div>
                      <div className="px-2 py-0.5 rounded bg-indigo-500/10 border border-indigo-500/20 text-[8px] font-black uppercase text-indigo-400 tracking-widest">{t.type}</div>
                    </div>
                    <div className="flex items-center gap-5 mt-2">
                       <div className="flex items-center gap-2">
                         <div className={`h-1.5 w-1.5 rounded-full ${t.status === 'completed' ? 'bg-emerald-500 shadow-[0_0_8px_#10b981]' : 'bg-amber-500'}`} />
                         <span className="text-[10px] font-black text-zinc-500 uppercase tracking-widest">{t.status}</span>
                       </div>
                       <div className="text-[10px] font-black text-zinc-600 uppercase tracking-tighter">{new Date(t.createdAt).toLocaleDateString()}</div>
                    </div>
                  </div>

                  <div className="text-right pr-4">
                    <div className={cx(
                      "text-3xl font-black italic leading-none",
                      t.amount > 0 ? "text-emerald-400" : "text-zinc-200"
                    )}>
                      {t.amount > 0 ? '+' : ''}{t.amount.toFixed(2)}
                    </div>
                    <div className="text-[11px] font-black text-zinc-600 uppercase tracking-widest mt-2">{t.currency}</div>
                  </div>
                  
                  <div className="absolute inset-y-0 right-0 w-32 bg-gradient-to-l from-indigo-500/[0.03] to-transparent pointer-events-none" />
                </motion.div>
              ))
            )}
          </div>
        </div>

      </div>
    </UserShell>
  );
}

function cx(...parts: any[]) {
  return parts.filter(Boolean).join(" ");
}

