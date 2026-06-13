"use client";

import { useQuery } from "@tanstack/react-query";
import { motion, AnimatePresence, useMotionValue, useTransform, useSpring } from "framer-motion";
import {
  TrendingUp, DollarSign,
  ArrowUpRight, Clock, CheckCircle2, Heart,
  Sparkles, RefreshCw,
  Activity, Shield, CreditCard,
  Cpu, Target, Search, Coins, Layers,
  Rocket, Banknote, ExternalLink, Trophy
} from "lucide-react";
import UserShell from "@/app/_components/UserShell";
import { apiFetch } from "@/lib/api";
import { useAuthToken } from "@/lib/stores/authStore";

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

type TransactionApiRecord = {
  id?: string;
  _id?: string;
  amountGrossCents?: number;
  creatorNetCents?: number;
  currency?: string;
  type?: string;
  status?: string;
  description?: string;
  title?: string;
  createdAt?: string;
};

type WalletApiRecord = {
  availableBalanceCents?: number;
  pendingBalanceCents?: number;
  lifetimeEarningsCents?: number;
  currency?: string;
};

function unwrapData<T>(value: unknown): T {
  if (!value || typeof value !== "object") return {} as T;
  const record = value as Record<string, unknown>;
  return (record.data ?? record) as T;
}

function cx(...parts: Array<string | false | null | undefined>) {
  return parts.filter(Boolean).join(" ");
}

export default function WalletPage() {
  const { token, hydrated } = useAuthToken();

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

  const walletQuery = useQuery<WalletData>({
    queryKey: ["wallet-data", token],
    enabled: hydrated && !!token,
    refetchInterval: 15000,
    queryFn: async () => {
      const [walletRes, txRes] = await Promise.all([
        apiFetch("/creator-monetization/me/wallet", { method: "GET", token: token! }),
        apiFetch("/creator-monetization/me/transactions", { method: "GET", token: token! }),
      ]);

      const w = unwrapData<WalletApiRecord>(walletRes);
      const txData = unwrapData<TransactionApiRecord[] | unknown[]>(txRes);

      const activeBalance = Number(w?.availableBalanceCents || 0) / 100;
      const pendingRevenue = Number(w?.pendingBalanceCents || 0) / 100;
      const totalEarned = Number(w?.lifetimeEarningsCents || 0) / 100;
      const currency = String(w?.currency || "USD").toUpperCase();

      const txList = Array.isArray(txData) ? txData as TransactionApiRecord[] : [];
      const transactions: Transaction[] = txList.map((t) => ({
        id: String(t.id || t._id || crypto.randomUUID()),
        amount: Number(t.amountGrossCents || t.creatorNetCents || 0) / 100,
        currency: String(t.currency || "USD").toUpperCase(),
        type: String(t.type || "earning"),
        status: t.status === "succeeded" ? "completed" : "pending",
        description: t.description || t.title || (t.type === "tip" ? "Donation Received" : t.type === "template_sale" ? "Asset Sale" : t.type === "tournament_prize" ? "Tournament Prize" : "Monetization Capture"),
        createdAt: String(t.createdAt || new Date().toISOString()),
      }));

      return { activeBalance, pendingRevenue, totalEarned, currency, transactions, isRealData: true };
    },
  });

  const wallet = walletQuery.data ?? null;
  const loading = !hydrated || (walletQuery.isLoading && !wallet);
  const syncStatus: "synced" | "probing" | "failed" = !hydrated || walletQuery.isFetching
    ? "probing"
    : walletQuery.isError
      ? "failed"
      : "synced";

  const getTxIcon = (type: string) => {
    const t = type.toLowerCase();
    if (t.includes('donation') || t.includes('tip')) return <Heart size={16} className="text-rose-400" />;
    if (t.includes('sale') || t.includes('template')) return <Layers size={16} className="text-cyan-400" />;
    if (t.includes('ad')) return <Activity size={16} className="text-emerald-400" />;
    if (t.includes('tournament')) return <Trophy size={16} className="text-amber-400" />;
    return <Coins size={16} className="text-amber-400" />;
  };

  const getTxBg = (type: string) => {
    const t = type.toLowerCase();
    if (t.includes('donation') || t.includes('tip')) return "bg-rose-500/10 border-rose-500/20";
    if (t.includes('sale') || t.includes('template')) return "bg-cyan-500/10 border-cyan-500/20";
    if (t.includes('ad')) return "bg-emerald-500/10 border-emerald-500/20";
    if (t.includes('tournament')) return "bg-amber-500/10 border-amber-500/20";
    return "bg-amber-500/10 border-amber-500/20";
  };

  return (
    <UserShell title="Creator Wallet" subtitle="Neural Financial Center">
      {/* Ambient glow */}
      <div className="pointer-events-none absolute inset-0 overflow-hidden">
        <div className="absolute top-[-10%] left-[5%] w-[600px] h-[500px] bg-amber-500/6 blur-[150px] rounded-full" />
        <div className="absolute bottom-[-5%] right-[10%] w-[500px] h-[400px] bg-blue-600/8 blur-[140px] rounded-full" />
      </div>

      <div className="relative z-10 max-w-2xl mx-auto space-y-8 pb-20">

        {/* ── Holographic Balance Card ── */}
        <div
          className="perspective-[1200px]"
          style={{ height: "320px" }}
          onMouseMove={handleMouseMove}
          onMouseLeave={handleMouseLeave}
        >
          <motion.div
            style={{ rotateX, rotateY, transformStyle: "preserve-3d" }}
            className="relative h-full w-full rounded-[40px] overflow-hidden border border-white/10 shadow-[0_50px_100px_rgba(0,0,0,0.6)] group bg-[#05060a]"
          >
            <div className="absolute inset-0 bg-gradient-to-br from-amber-600/25 via-transparent to-blue-600/25" />
            <motion.div
              style={{
                left: mouseX,
                top: mouseY,
                background: "radial-gradient(circle at center, rgba(255,255,255,0.12) 0%, transparent 60%)"
              }}
              className="absolute pointer-events-none w-[600px] h-[600px] -translate-x-1/2 -translate-y-1/2 rounded-full"
            />
            <div
              className="absolute inset-0 opacity-[0.025]"
              style={{
                backgroundImage: "linear-gradient(rgba(255,255,255,0.1) 1px, transparent 1px), linear-gradient(90deg, rgba(255,255,255,0.1) 1px, transparent 1px)",
                backgroundSize: "30px 30px"
              }}
            />

            <div className="relative h-full p-10 flex flex-col justify-between text-white z-10">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-3">
                  <motion.div
                    animate={{ opacity: [0.4, 1, 0.4] }}
                    transition={{ duration: 1.5, repeat: Infinity }}
                    className={`h-2.5 w-2.5 rounded-full ${syncStatus === 'synced' ? 'bg-emerald-400 shadow-[0_0_12px_#34d399]' : 'bg-amber-400 animate-pulse'}`}
                  />
                  <div>
                    <div className="text-[10px] font-black uppercase tracking-[0.4em] opacity-50">Neural Financial Sync</div>
                    <div className="text-[9px] font-mono text-amber-400/80 uppercase tracking-widest">
                      {syncStatus === 'synced' ? 'Link Secure' : 'Probing...'}
                    </div>
                  </div>
                </div>
                <div className="h-9 w-9 rounded-xl bg-white/5 backdrop-blur-xl border border-white/10 flex items-center justify-center text-amber-300/70">
                  <Cpu size={16} />
                </div>
              </div>

              <div>
                <div className="flex items-center gap-2 mb-3">
                  <Target size={11} className="text-amber-400/40" />
                  <span className="text-[11px] font-black uppercase tracking-[0.5em] opacity-40">Active Balance</span>
                </div>
                <div className="flex items-baseline gap-4">
                  <AnimatePresence mode="wait">
                    <motion.h2
                      key={wallet?.activeBalance}
                      initial={{ opacity: 0, y: 10 }}
                      animate={{ opacity: 1, y: 0 }}
                      className="text-6xl font-black italic tracking-tighter text-transparent bg-clip-text bg-gradient-to-r from-amber-300 via-white to-blue-300"
                    >
                      {loading && !wallet ? "···" : (wallet?.activeBalance || 0).toLocaleString(undefined, { minimumFractionDigits: 2 })}
                    </motion.h2>
                  </AnimatePresence>
                  <span className="text-xl font-black text-amber-500/60 italic">{wallet?.currency || "USD"}</span>
                </div>
              </div>

              <div className="grid grid-cols-2 gap-10 border-t border-white/[0.06] pt-6">
                <div>
                  <p className="text-[10px] font-black uppercase tracking-widest opacity-35 flex items-center gap-1.5 mb-1">
                    <Clock size={10} /> Pending
                  </p>
                  <p className="text-2xl font-black italic text-zinc-300">
                    ${(wallet?.pendingRevenue || 0).toLocaleString(undefined, { minimumFractionDigits: 2 })}
                  </p>
                </div>
                <div>
                  <p className="text-[10px] font-black uppercase tracking-widest opacity-35 flex items-center gap-1.5 mb-1">
                    <Activity size={10} /> Lifetime Earned
                  </p>
                  <p className="text-2xl font-black italic text-amber-400">
                    ${(wallet?.totalEarned || 0).toLocaleString(undefined, { minimumFractionDigits: 2 })}
                  </p>
                </div>
              </div>
            </div>
          </motion.div>
        </div>

        {/* ── Action Cards Row ── */}
        <div className="grid grid-cols-3 gap-4">
          <motion.button
            whileHover={{ y: -4, scale: 1.02 }}
            whileTap={{ scale: 0.97 }}
            className="group flex flex-col items-center gap-3 p-6 rounded-[28px] bg-gradient-to-br from-emerald-600/20 to-emerald-700/10 border border-emerald-500/25 hover:border-emerald-500/50 transition-all"
          >
            <div className="h-11 w-11 rounded-2xl bg-emerald-500/20 flex items-center justify-center border border-emerald-500/30 group-hover:scale-110 transition-transform">
              <Banknote size={20} className="text-emerald-400" />
            </div>
            <div className="text-center">
              <div className="text-xs font-black uppercase tracking-[0.15em] text-emerald-300">Withdraw</div>
              <div className="text-[10px] text-zinc-600 mt-0.5">Payout</div>
            </div>
          </motion.button>

          <motion.button
            whileHover={{ y: -4, scale: 1.02 }}
            whileTap={{ scale: 0.97 }}
            onClick={() => window.location.reload()}
            className="group flex flex-col items-center gap-3 p-6 rounded-[28px] bg-white/[0.04] border border-white/10 hover:border-white/20 transition-all"
          >
            <div className="h-11 w-11 rounded-2xl bg-white/5 flex items-center justify-center border border-white/10 group-hover:scale-110 transition-transform">
              <RefreshCw size={20} className="text-zinc-400 group-hover:rotate-180 transition-transform duration-700" />
            </div>
            <div className="text-center">
              <div className="text-xs font-black uppercase tracking-[0.15em] text-white">Refresh</div>
              <div className="text-[10px] text-zinc-600 mt-0.5">Sync data</div>
            </div>
          </motion.button>

          <motion.button
            whileHover={{ y: -4, scale: 1.02 }}
            whileTap={{ scale: 0.97 }}
            className="group flex flex-col items-center gap-3 p-6 rounded-[28px] bg-gradient-to-br from-blue-600/20 to-blue-700/10 border border-blue-500/25 hover:border-blue-500/50 transition-all"
          >
            <div className="h-11 w-11 rounded-2xl bg-blue-500/20 flex items-center justify-center border border-blue-500/30 group-hover:scale-110 transition-transform">
              <ExternalLink size={20} className="text-blue-400" />
            </div>
            <div className="text-center">
              <div className="text-xs font-black uppercase tracking-[0.15em] text-blue-300">History</div>
              <div className="text-[10px] text-zinc-600 mt-0.5">Full report</div>
            </div>
          </motion.button>
        </div>

        {/* ── Ledger ── */}
        <div className="space-y-5">
          <div className="flex items-center justify-between px-2">
            <div className="flex items-center gap-3">
              <div className="h-8 w-8 rounded-xl bg-amber-500/10 flex items-center justify-center border border-amber-500/20">
                <Shield size={16} className="text-amber-400" />
              </div>
              <span className="text-lg font-black text-white uppercase tracking-tighter">Secure Ledger</span>
            </div>
            <div className="flex items-center gap-2">
              <div className="h-1.5 w-1.5 rounded-full bg-emerald-500 animate-pulse" />
              <span className="text-[10px] font-black text-zinc-500 uppercase tracking-widest">
                {wallet?.transactions.length || 0} items
              </span>
            </div>
          </div>

          <div className="space-y-3">
            {loading && !wallet ? (
              Array.from({ length: 4 }).map((_, i) => (
                <div key={i} className="h-20 w-full rounded-[24px] bg-white/5 animate-pulse" />
              ))
            ) : !wallet?.transactions.length ? (
              <div className="rounded-[28px] p-16 text-center border border-dashed border-white/[0.06] bg-black/20">
                <div className="h-16 w-16 rounded-full bg-white/5 flex items-center justify-center mx-auto mb-5 border border-white/5">
                  <Search size={28} className="text-zinc-700" />
                </div>
                <div className="text-zinc-500 font-black uppercase tracking-[0.4em] text-sm">Ledger Empty</div>
                <div className="mt-2 text-zinc-600 text-[10px] uppercase tracking-[0.2em]">
                  New transactions will appear here
                </div>
              </div>
            ) : (
              wallet.transactions.map((t, idx) => (
                <motion.div
                  key={t.id}
                  initial={{ opacity: 0, y: 10 }}
                  animate={{ opacity: 1, y: 0 }}
                  transition={{ delay: idx * 0.04 }}
                  className="group flex items-center gap-5 p-5 rounded-[24px] bg-white/[0.025] border border-white/[0.06] hover:border-amber-500/20 hover:bg-white/[0.04] transition-all relative overflow-hidden"
                >
                  <div className={`h-12 w-12 rounded-[18px] flex items-center justify-center border shrink-0 ${getTxBg(t.type)}`}>
                    {getTxIcon(t.type)}
                  </div>

                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2 mb-1">
                      <div className="text-sm font-black text-white tracking-tight truncate">{t.description}</div>
                      <div className="shrink-0 px-2 py-0.5 rounded bg-white/5 border border-white/10 text-[8px] font-black uppercase text-zinc-500 tracking-widest">
                        {t.type}
                      </div>
                    </div>
                    <div className="flex items-center gap-3">
                      <div className={`h-1.5 w-1.5 rounded-full ${t.status === 'completed' ? 'bg-emerald-500 shadow-[0_0_6px_#10b981]' : 'bg-amber-500'}`} />
                      <span className="text-[10px] font-bold text-zinc-500 uppercase tracking-wider">{t.status}</span>
                      <span className="text-[10px] text-zinc-600 uppercase tracking-tight">
                        {new Date(t.createdAt).toLocaleDateString()}
                      </span>
                    </div>
                  </div>

                  <div className="text-right shrink-0">
                    <div className={cx(
                      "text-xl font-black italic leading-none",
                      t.amount > 0 ? "text-emerald-400" : "text-zinc-300"
                    )}>
                      {t.amount > 0 ? '+' : ''}{t.amount.toFixed(2)}
                    </div>
                    <div className="text-[10px] font-black text-zinc-600 uppercase tracking-widest mt-1">{t.currency}</div>
                  </div>

                  <div className="absolute inset-y-0 right-0 w-20 bg-gradient-to-l from-amber-500/[0.03] to-transparent pointer-events-none" />
                </motion.div>
              ))
            )}
          </div>
        </div>
      </div>
    </UserShell>
  );
}
