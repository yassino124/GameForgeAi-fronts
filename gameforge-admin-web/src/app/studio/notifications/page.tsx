"use client";

import { useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import UserShell from "@/app/_components/UserShell";
import { apiFetch, ApiError } from "@/lib/api";
import { useAuthToken } from "@/lib/stores/authStore";
import { 
  Bell, Check, Trash, Package, Star, 
  WarningCircle, Info, CreditCard, Users,
  CheckCircle, Clock, ArrowsOut, Funnel,
  Sparkle, Lightning
} from "@phosphor-icons/react";
import { motion, AnimatePresence } from "framer-motion";
import Tilt from "react-parallax-tilt";
import { NeonChip, PulseDot } from "@/app/_components/Hud";

type Notification = {
  id: string;
  _id?: string;
  title: string;
  message: string;
  type: string;
  read: boolean;
  createdAt: string;
  data?: any;
};

// Helper: Relative Time
function formatRelativeTime(dateStr: string) {
  const d = new Date(dateStr);
  const now = new Date();
  const diff = now.getTime() - d.getTime();
  const sec = Math.floor(diff / 1000);
  const min = Math.floor(sec / 60);
  const hour = Math.floor(min / 60);
  const day = Math.floor(hour / 24);

  if (sec < 60) return "Just now";
  if (min < 60) return `${min}m ago`;
  if (hour < 24) return `${hour}h ago`;
  if (day < 7) return `${day}d ago`;
  return d.toLocaleDateString([], { month: "short", day: "numeric" });
}

// Neural Particles Component
const NeuralParticles = () => (
  <div className="absolute inset-0 pointer-events-none opacity-20">
    {Array.from({ length: 6 }).map((_, i) => (
      <motion.div
        key={i}
        className="absolute w-1 h-1 bg-blue-400 rounded-full blur-[1px]"
        animate={{
          x: [Math.random() * 400, Math.random() * 400],
          y: [Math.random() * 200, Math.random() * 200],
          opacity: [0.2, 0.8, 0.2],
          scale: [1, 1.5, 1],
        }}
        transition={{
          duration: 10 + Math.random() * 10,
          repeat: Infinity,
          ease: "linear",
        }}
      />
    ))}
    <svg className="absolute inset-0 w-full h-full opacity-5">
      <defs>
        <pattern id="neural-grid" width="40" height="40" patternUnits="userSpaceOnUse">
          <circle cx="2" cy="2" r="1" fill="currentColor" />
        </pattern>
      </defs>
      <rect width="100%" height="100%" fill="url(#neural-grid)" />
    </svg>
  </div>
);

const getIconForNotification = (n: Notification) => {
  const t = (n.title + n.message).toLowerCase();
  
  if (t.includes("template") || t.includes("forge")) 
    return { icon: Package, color: "text-cyan-400", bg: "bg-cyan-500/10", tone: "cyan" as const };
  if (t.includes("review") || t.includes("star") || t.includes("approval")) 
    return { icon: Star, color: "text-amber-400", bg: "bg-amber-500/10", tone: "amber" as const };
  if (t.includes("payment") || t.includes("wallet") || t.includes("subscription")) 
    return { icon: CreditCard, color: "text-emerald-400", bg: "bg-emerald-500/10", tone: "emerald" as const };
  if (t.includes("multiplayer") || t.includes("user") || t.includes("friend")) 
    return { icon: Users, color: "text-sky-400", bg: "bg-sky-500/10", tone: "zinc" as const };
  if (t.includes("error") || t.includes("fail") || t.includes("warning")) 
    return { icon: WarningCircle, color: "text-rose-400", bg: "bg-rose-500/10", tone: "cyan" as const };
    
  return { icon: Bell, color: "text-blue-400", bg: "bg-blue-500/10", tone: "cyan" as const };
};

export default function NotificationsPage() {
  const { token, hydrated } = useAuthToken();
  const queryClient = useQueryClient();
  const [actionLoading, setActionLoading] = useState<string | null>(null);
  const [filterTab, setFilterTab] = useState<"all" | "unread">("all");

  const notificationsQuery = useQuery<Notification[]>({
    queryKey: ["notifications", token],
    enabled: hydrated && !!token,
    queryFn: async () => {
      const res = await apiFetch<any>("/notifications", { method: "GET", token: token! });
      const data = (res && typeof res === "object" && "data" in res) ? res.data : res;
      return Array.isArray(data) ? data : (Array.isArray(data?.data) ? data.data : []);
    },
  });

  const markAsReadMutation = useMutation({
    mutationFn: async (id: string) => {
      await apiFetch(`/notifications/${id}`, {
        method: "PATCH",
        token: token!,
        body: { isRead: true },
      });
      return id;
    },
    onSuccess: (id) => {
      queryClient.setQueryData<Notification[]>(["notifications", token], (prev = []) =>
        prev.map((n) => (n._id === id || n.id === id) ? { ...n, read: true } : n),
      );
    },
  });

  const markAllReadMutation = useMutation({
    mutationFn: async () => {
      await apiFetch("/notifications/read-all", { method: "POST", token: token! });
    },
    onSuccess: () => {
      queryClient.setQueryData<Notification[]>(["notifications", token], (prev = []) =>
        prev.map((n) => ({ ...n, read: true })),
      );
    },
  });

  const clearAllMutation = useMutation({
    mutationFn: async () => {
      await apiFetch("/notifications/clear-all", { method: "POST", token: token! });
    },
    onSuccess: () => {
      queryClient.setQueryData<Notification[]>(["notifications", token], []);
    },
  });

  const notifications = notificationsQuery.data ?? [];
  const loading = !hydrated || notificationsQuery.isLoading;
  const error = notificationsQuery.error instanceof ApiError
    ? notificationsQuery.error.message
    : notificationsQuery.error instanceof Error
      ? notificationsQuery.error.message
      : null;

  async function markAsRead(id: string) {
    if (!token || markAsReadMutation.isPending) return;
    try {
      await markAsReadMutation.mutateAsync(id);
    } catch (e) {
      // ignore
    }
  }

  async function markAllRead() {
    if (!token || actionLoading) return;
    setActionLoading("mark-all");
    try {
      await markAllReadMutation.mutateAsync();
    } catch (e) {
      // ignore
    } finally {
      setActionLoading(null);
    }
  }

  async function clearAll() {
    if (!token || actionLoading) return;
    if (!confirm("Are you sure you want to clear all notifications?")) return;
    setActionLoading("clear-all");
    try {
      await clearAllMutation.mutateAsync();
    } catch (e) {
      // ignore
    } finally {
      setActionLoading(null);
    }
  }

  const unreadCount = notifications.filter(n => !n.read).length;
  const filteredList = filterTab === "unread" ? notifications.filter(n => !n.read) : notifications;

  return (
    <UserShell 
      title="Notifications" 
      subtitle="Stay updated with your projects"
      right={
        <div className="flex items-center gap-2">
          {notifications.length > 0 && (
            <>
              <button 
                onClick={markAllRead}
                disabled={unreadCount === 0 || !!actionLoading}
                className="gf-btn flex items-center gap-2 px-4 py-2 rounded-xl text-xs bg-white/5 border border-white/10 hover:bg-white/10 disabled:opacity-30 disabled:cursor-not-allowed transition-all"
              >
                <CheckCircle size={16} weight="duotone" className="text-emerald-400" />
                <span>Mark all read</span>
              </button>
              <button 
                onClick={clearAll}
                disabled={!!actionLoading}
                className="gf-btn flex items-center gap-2 px-4 py-2 rounded-xl text-xs bg-rose-500/5 border border-rose-500/10 text-rose-400 hover:bg-rose-500/10 transition-all shrink-0"
              >
                <Trash size={16} weight="duotone" />
                <span className="hidden sm:inline">Clear All</span>
              </button>
            </>
          )}
        </div>
      }
    >
      <div className="max-w-4xl space-y-8 mx-auto">
        {/* Navigation Tabs */}
        <div className="flex items-center justify-between border-b border-white/[0.05] pb-2">
            <div className="flex items-center gap-6">
                {[
                    { id: "all", label: "All Activity", count: notifications.length },
                    { id: "unread", label: "Unread", count: unreadCount, highlight: unreadCount > 0 },
                ].map((tab) => (
                    <button
                        key={tab.id}
                        onClick={() => setFilterTab(tab.id as any)}
                        className={`relative flex items-center gap-2 pb-3 text-sm font-bold tracking-tight transition-all ${
                            filterTab === tab.id ? "text-white" : "text-zinc-500 hover:text-zinc-300"
                        }`}
                    >
                        {filterTab === tab.id && (
                            <motion.div 
                                layoutId="tabIndicator"
                                className="absolute bottom-0 left-0 right-0 h-[2px] bg-blue-500 shadow-[0_0_12px_rgba(99,102,241,0.8)]"
                            />
                        )}
                        <span>{tab.label}</span>
                        {tab.count > 0 && (
                            <span className={`px-1.5 py-0.5 rounded-md text-[10px] ${
                                tab.highlight ? "bg-blue-500/20 text-blue-400" : "bg-white/5 text-zinc-500"
                            }`}>
                                {tab.count}
                            </span>
                        )}
                    </button>
                ))}
            </div>
            
            <div className="flex items-center gap-2 text-zinc-500 italic text-[11px] font-medium opacity-60">
                <Funnel size={14} weight="bold" />
                <span>Smart Categorization Active</span>
            </div>
        </div>

        {error && (
          <motion.div 
            initial={{ opacity: 0, scale: 0.95 }}
            animate={{ opacity: 1, scale: 1 }}
            className="rounded-2xl border border-red-500/20 bg-red-500/10 px-4 py-3 text-sm text-red-200 flex items-center gap-3 shadow-[0_0_20px_rgba(239,68,68,0.1)]"
          >
            <WarningCircle size={20} className="text-red-400" />
            {error}
          </motion.div>
        )}
        
        <div className="space-y-5">
          {loading ? (
            Array.from({ length: 4 }).map((_, i) => (
              <div key={i} className="gf-card rounded-3xl p-8 relative overflow-hidden bg-white/[0.02] border border-white/5 animate-pulse">
                <div className="flex gap-4">
                  <div className="w-14 h-14 rounded-2xl bg-white/5 shrink-0" />
                  <div className="flex-1 space-y-4">
                    <div className="h-5 w-1/4 bg-white/10 rounded" />
                    <div className="h-3 w-5/6 bg-white/5 rounded" />
                    <div className="h-2 w-24 bg-white/5 rounded" />
                  </div>
                </div>
              </div>
            ))
          ) : filteredList.length === 0 ? (
            <motion.div 
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              className="gf-card rounded-[3rem] p-20 text-center bg-white/[0.01] border border-dashed border-white/10 flex flex-col items-center justify-center relative overflow-hidden"
            >
              <div className="absolute inset-0 bg-gradient-to-br from-blue-500/[0.02] via-transparent to-transparent pointer-events-none" />
              
              <div className="relative mb-10">
                <motion.div 
                    initial={{ scale: 0.8 }}
                    animate={{ scale: [0.8, 1.1, 0.9, 1] }}
                    transition={{ duration: 4, repeat: Infinity }}
                    className="absolute inset-0 bg-blue-500/20 blur-[80px] rounded-full" 
                />
                <div className="relative w-32 h-32 rounded-3xl bg-black/40 border border-white/10 flex items-center justify-center shadow-2xl backdrop-blur-xl">
                    <Sparkle size={64} weight="duotone" className="text-blue-400 animate-pulse" />
                </div>
                <div className="absolute -bottom-2 -right-2 w-10 h-10 rounded-full bg-emerald-500/20 border border-emerald-400/30 flex items-center justify-center shadow-lg">
                    <Check size={20} weight="bold" className="text-emerald-400" />
                </div>
              </div>

              <h3 className="text-3xl font-black text-white tracking-tighter sm:text-4xl">System Zen Reached</h3>
              <p className="text-zinc-500 mt-4 max-w-md text-base leading-relaxed font-medium">
                Your neural link is clear. No new notifications or project updates require your immediate attention.
              </p>
              
              <div className="mt-10 flex flex-wrap items-center justify-center gap-4">
                  <button 
                    onClick={() => window.location.reload()}
                    className="gf-btn bg-white/5 border border-white/10 px-8 py-3 rounded-2xl text-sm font-bold hover:bg-white/10 transition-all flex items-center gap-3 active:scale-95"
                  >
                    <Clock size={18} weight="bold" className="text-zinc-400" />
                    <span>Synchronize Feed</span>
                  </button>
                  <button 
                    onClick={() => setFilterTab("all")}
                    className="gf-btn text-zinc-400 text-sm font-bold hover:text-white transition-colors"
                  >
                    View History
                  </button>
              </div>
            </motion.div>
          ) : (
            <AnimatePresence mode="popLayout">
              {filteredList.map((n, idx) => {
                const id = n._id || n.id;
                const { icon: Icon, color, bg, tone } = getIconForNotification(n);
                
                return (
                  <Tilt 
                    key={id}
                    perspective={1200}
                    scale={1.01}
                    glareEnable={false}
                    tiltMaxAngleX={4}
                    tiltMaxAngleY={4}
                    transitionSpeed={1500}
                    className="relative group"
                  >
                    <motion.div 
                        layout
                        initial={{ opacity: 0, y: 20, rotateX: 10 }}
                        animate={{ opacity: 1, y: 0, rotateX: 0 }}
                        exit={{ opacity: 0, scale: 0.9, filter: "blur(10px)" }}
                        transition={{ 
                            duration: 0.6, 
                            delay: idx * 0.04, 
                            ease: [0.22, 1, 0.36, 1] 
                        }}
                        className={`relative overflow-hidden rounded-[2rem] p-7 border transition-all duration-700 shadow-xl ${
                            n.read 
                                ? 'bg-white/[0.015] border-white/[0.03] grayscale-[0.3] opacity-70' 
                                : 'bg-[#11111a]/80 border-white/[0.08] backdrop-blur-3xl ring-1 ring-white/5 shadow-[0_20px_50px_rgba(0,0,0,0.6)]'
                        }`}
                        onMouseEnter={() => !n.read && markAsRead(id)}
                    >
                        {!n.read && (
                            <>
                                <div className="absolute inset-0 bg-gradient-to-r from-blue-500/[0.03] via-transparent to-transparent pointer-events-none" />
                                <div className="absolute top-0 right-0 p-4 pointer-events-none">
                                    <Lightning size={16} weight="fill" className="text-blue-400/20 blur-[1px]" />
                                </div>
                                <NeuralParticles />
                                <div className="absolute -inset-[2px] bg-gradient-to-r from-blue-500/20 via-sky-500/10 to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-500 p-[2px] -z-10 blur-sm" />
                            </>
                        )}

                        <div className="relative z-10 flex gap-6">
                            <div className="relative shrink-0">
                                <motion.div 
                                    className={`w-16 h-16 rounded-2xl ${bg} border border-white/5 flex items-center justify-center transition-transform group-hover:scale-105 duration-700 shadow-inner`}
                                    whileHover={{ rotate: 10 }}
                                >
                                    <Icon size={32} weight="duotone" className={color} />
                                </motion.div>
                                {!n.read && (
                                    <div className="absolute -top-1 -right-1">
                                        <PulseDot tone="cyan" className="scale-90 shadow-blue-500" />
                                    </div>
                                )}
                            </div>
                            
                            <div className="flex-1 min-w-0">
                                <div className="flex items-center gap-3 mb-1.5 flex-wrap">
                                    <h4 className={`text-[17px] font-black leading-tight tracking-tight transition-colors ${n.read ? 'text-zinc-400' : 'text-white'}`}>
                                        {n.title}
                                    </h4>
                                    <NeonChip tone={tone} className="py-0 px-2 h-5 opacity-60 text-[9px] uppercase font-black tracking-widest">
                    {tone === 'cyan' ? 'SYSTEM' : tone === 'amber' ? 'REVIEW' : tone === 'emerald' ? 'FINANCE' : 'SOCIAL'}
                                    </NeonChip>
                                </div>
                                
                                <p className={`text-[15px] leading-relaxed mb-4 max-w-2xl font-medium tracking-tight ${n.read ? 'text-zinc-500' : 'text-zinc-400'}`}>
                                    {n.message}
                                </p>
                                
                                <div className="flex items-center justify-between">
                                    <div className="flex items-center gap-4">
                                        <div className="flex items-center gap-2 text-[11px] font-bold uppercase tracking-[0.15em] text-zinc-500">
                                            <Clock weight="fill" className="text-zinc-600 size-3" />
                                            <span>{formatRelativeTime(n.createdAt)}</span>
                                        </div>
                                        <div className="h-1 w-1 rounded-full bg-zinc-800" />
                                        <div className={`text-[10px] font-black uppercase tracking-[0.2em] ${n.read ? 'text-zinc-700' : 'text-blue-400/40'}`}>
                                            {n.read ? 'Archived' : 'Active Link'}
                                        </div>
                                    </div>
                                    
                                    <div className="flex items-center gap-2 opacity-0 group-hover:opacity-100 transition-all duration-500 translate-x-2 group-hover:translate-x-0">
                                        <button className="p-2 rounded-xl bg-white/[0.03] border border-white/5 hover:bg-white/10 text-zinc-400 hover:text-white transition-all">
                                            <ArrowsOut size={16} weight="bold" />
                                        </button>
                                        <button className="p-2 rounded-xl bg-white/[0.03] border border-white/5 hover:bg-rose-500/10 text-zinc-400 hover:text-rose-400 transition-all">
                                            <Trash size={16} weight="bold" />
                                        </button>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </motion.div>
                   </Tilt>
                );
              })}
            </AnimatePresence>
          )}
        </div>
      </div>
    </UserShell>
  );
}


