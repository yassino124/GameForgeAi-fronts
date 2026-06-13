"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { useMutation, useQuery } from "@tanstack/react-query";
import UserShell from "@/app/_components/UserShell";
import { apiFetch, ApiError } from "@/lib/api";
import { useAuthToken } from "@/lib/stores/authStore";
import { normalizeImageUrl } from "@/lib/media";
import { motion, AnimatePresence } from "framer-motion";
import SettingsTabs, { TabId } from "./_components/SettingsTabs";
import {
  CheckCircle2, AlertCircle, Loader2, Camera,
  Mail, ShieldCheck, Zap, Globe, Trash2,
  Lock, KeyRound, Eye, EyeOff, ExternalLink,
  User, Layout, Bell, CreditCard, Cpu
} from "lucide-react";

type UserProfile = {
  id: string;
  email: string;
  username: string;
  fullName?: string;
  bio?: string;
  avatar?: string;
  role?: string;
  subscription?: string;
  credits?: number;
};

function SectionHeader({ title, description, icon: Icon }: { title: string; description: string; icon?: any }) {
  return (
    <div className="relative mb-8 flex items-center justify-between">
      <div className="flex items-center gap-4 relative z-10">
        {Icon && (
          <div className="h-12 w-12 rounded-[20px] bg-gradient-to-br from-blue-500/20 to-sky-500/5 border border-blue-500/20 flex items-center justify-center shadow-[0_0_30px_rgba(99,102,241,0.15)]">
            <Icon size={22} className="text-blue-400" />
          </div>
        )}
        <div>
          <h3 className="text-2xl font-black text-[var(--foreground)] italic uppercase tracking-tighter gf-chromatic">{title}</h3>
          <p className="text-[10px] text-zinc-500 font-black uppercase tracking-[0.3em] mt-1">{description}</p>
        </div>
      </div>
      <div className="absolute top-0 right-0 h-24 w-48 bg-gradient-to-l from-blue-500/5 to-transparent pointer-events-none rounded-full blur-2xl" />
    </div>
  );
}

function FieldLabel({ children }: { children: React.ReactNode }) {
  return (
    <label className="block text-[9px] font-black text-zinc-500 uppercase tracking-[0.25em] mb-2 ml-1">
      {children}
    </label>
  );
}

function Card({ children, className = "", noPad = false }: { children: React.ReactNode; className?: string; noPad?: boolean }) {
  return (
    <div className={`relative group/card gf-panel rounded-[32px] border border-white/[0.08] bg-[var(--gf-panel-bg-strong)] backdrop-blur-2xl shadow-xl transition-all duration-300 hover:border-blue-500/30 overflow-hidden ${noPad ? "" : "p-8"} ${className}`}>
      <div className="absolute inset-0 bg-gradient-to-br from-white/[0.02] via-transparent to-black/40 pointer-events-none" />
      <div className="absolute inset-0 bg-gradient-to-tr from-blue-500/[0.02] to-transparent opacity-0 group-hover/card:opacity-100 transition-opacity duration-500 pointer-events-none" />
      <div className="relative z-10">{children}</div>
    </div>
  );
}

export default function SettingsPage() {
  const router = useRouter();
  const { token, hydrated } = useAuthToken();

  const [activeTab, setActiveTab] = useState<TabId>("profile");
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  const [profile, setProfile] = useState<UserProfile | null>(null);
  const [username, setUsername] = useState("");
  const [fullName, setFullName] = useState("");
  const [bio, setBio] = useState("");

  const profileQuery = useQuery<UserProfile>({
    queryKey: ["settings-profile", token],
    enabled: hydrated && !!token,
    queryFn: async () => {
      const res = await apiFetch("/auth/profile", { method: "GET", token: token! });
      const data = (res && typeof res === "object" && "data" in res)
        ? (res as { data?: UserProfile | { user?: UserProfile } }).data
        : res;
      const p = (data && typeof data === "object" && "user" in (data as object))
        ? (data as { user?: UserProfile }).user
        : (data as UserProfile | undefined);
      return p ?? ({ id: "", email: "", username: "" } as UserProfile);
    },
  });

  useEffect(() => {
    if (!profileQuery.data) return;
    const p = profileQuery.data;
    setProfile(p);
    setUsername(p.username || "");
    setFullName(p.fullName || "");
    setBio(p.bio || "");
  }, [profileQuery.data]);

  useEffect(() => {
    if (!profileQuery.error) return;
    setError(profileQuery.error instanceof ApiError ? profileQuery.error.message : "Failed to load profile");
  }, [profileQuery.error]);

  const updateMutation = useMutation({
    mutationFn: async () => {
      await apiFetch("/auth/profile", {
        method: "PUT",
        token: token!,
        body: { username, fullName, bio },
      });
    },
    onSuccess: async () => {
      setSuccess("Profile updated successfully");
      setTimeout(() => setSuccess(null), 3500);
      await profileQuery.refetch();
    },
    onError: (e) => {
      setError(e instanceof ApiError ? e.message : "Update failed");
    },
  });

  const loading = !hydrated || profileQuery.isLoading;
  const updating = updateMutation.isPending;

  async function handleUpdate(e?: React.FormEvent) {
    if (e) e.preventDefault();
    if (!token) return;
    setError(null);
    setSuccess(null);
    try {
      await updateMutation.mutateAsync();
    } catch {
      // handled in mutation callbacks
    }
  }

  const userInitial = (username || profile?.email || "U").charAt(0).toUpperCase();
  const isPro = !["free", "", "standard free"].includes(String(profile?.subscription || "").toLowerCase());

  const tabContent = {
    /* ─── Profile ─── */
    profile: (
      <div className="space-y-8 animate-in fade-in slide-in-from-bottom-4 duration-700">
        <SectionHeader title="Public Profile" description="Your creator identity broadcasted globally" icon={User} />

        {/* Avatar card */}
        <Card>
          <div className="flex flex-col sm:flex-row items-center gap-8">
            {/* Avatar */}
            <div className="relative group shrink-0">
              <div className="h-[120px] w-[120px] rounded-[36px] border border-blue-500/30 bg-gradient-to-br from-blue-600/20 to-sky-500/10 overflow-hidden shadow-[0_0_40px_rgba(99,102,241,0.15)] relative">
                {profile?.avatar ? (
                  <img
                    src={normalizeImageUrl(profile.avatar)}
                    alt=""
                    className="h-full w-full object-cover group-hover:scale-110 transition-transform duration-700"
                  />
                ) : (
                  <div className="flex h-full w-full items-center justify-center text-4xl font-black text-blue-300/50 select-none">
                    {userInitial}
                  </div>
                )}
                <div className="absolute inset-0 ring-1 ring-inset ring-white/10 rounded-[36px]" />
              </div>
              <button className="absolute -bottom-3 -right-3 h-12 w-12 rounded-[16px] bg-blue-500 hover:bg-blue-400 border border-blue-400/50 text-white flex items-center justify-center shadow-lg shadow-blue-500/30 hover:scale-110 hover:-rotate-3 active:scale-95 transition-all duration-300">
                <Camera size={20} />
              </button>
            </div>

            {/* Instructions */}
            <div className="flex-1">
              <h4 className="text-[10px] font-black text-[var(--foreground)] uppercase tracking-[0.25em] mb-2 flex items-center gap-2">
                <div className="h-1.5 w-1.5 rounded-full bg-blue-500" />
                Hologram Identity
              </h4>
              <p className="text-[11px] text-zinc-500 font-bold leading-relaxed mb-5 max-w-sm">
                Upload PNG or JPEG, min 512×512px. Max file size 5MB. This hologram represents you across the Forge network.
              </p>
              <button className="rounded-xl border border-white/10 bg-white/[0.03] px-4 py-2.5 text-[10px] font-black uppercase tracking-widest text-zinc-400 opacity-50 cursor-not-allowed" disabled>
                Upload Interface Offline
              </button>
            </div>
          </div>
        </Card>

        {/* Form card */}
        <Card>
          <form onSubmit={handleUpdate} className="space-y-5">
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-5">
              <div>
                <FieldLabel>Username</FieldLabel>
                <input
                  className="gf-input w-full rounded-[14px] px-4 py-3 text-sm"
                  placeholder="e.g. gamemaster42"
                  value={username}
                  onChange={(e) => setUsername(e.target.value)}
                />
              </div>
              <div>
                <FieldLabel>Full Name</FieldLabel>
                <input
                  className="gf-input w-full rounded-[14px] px-4 py-3 text-sm"
                  placeholder="Your display name"
                  value={fullName}
                  onChange={(e) => setFullName(e.target.value)}
                />
              </div>
            </div>

            <div>
              <div className="flex items-center justify-between mb-1.5">
                <FieldLabel>Biography</FieldLabel>
                <span className="text-[10px] text-zinc-700 mr-0.5">{bio.length}/200</span>
              </div>
              <textarea
                className="gf-input w-full rounded-[14px] px-4 py-3 text-sm resize-none"
                rows={4}
                maxLength={200}
                placeholder="Tell the community about yourself…"
                value={bio}
                onChange={(e) => setBio(e.target.value)}
              />
              <p className="text-[10px] text-zinc-700 mt-1.5 ml-0.5">Markdown supported.</p>
            </div>

            {/* Feedback + submit */}
            <div className="flex items-center justify-between pt-3 border-t border-white/[0.05]">
              <AnimatePresence mode="wait">
                {success && (
                  <motion.span
                    key="success"
                    initial={{ opacity: 0, x: -8 }}
                    animate={{ opacity: 1, x: 0 }}
                    exit={{ opacity: 0 }}
                    className="flex items-center gap-1.5 text-xs text-emerald-400 font-semibold"
                  >
                    <CheckCircle2 size={13} /> {success}
                  </motion.span>
                )}
                {error && !success && (
                  <motion.span
                    key="error"
                    initial={{ opacity: 0, x: -8 }}
                    animate={{ opacity: 1, x: 0 }}
                    exit={{ opacity: 0 }}
                    className="flex items-center gap-1.5 text-xs text-red-400 font-semibold"
                  >
                    <AlertCircle size={13} /> {error}
                  </motion.span>
                )}
                {!success && !error && <span />}
              </AnimatePresence>

              <button
                type="submit"
                disabled={updating || loading}
                className="gf-btn-primary rounded-[14px] px-6 py-2.5 text-sm font-bold disabled:opacity-50 flex items-center gap-2"
              >
                {updating ? <Loader2 size={15} className="animate-spin" /> : null}
                {updating ? "Saving…" : "Save Changes"}
              </button>
            </div>
          </form>
        </Card>
      </div>
    ),

    /* ─── Account ─── */
    account: (
      <div className="space-y-8 animate-in fade-in slide-in-from-bottom-4 duration-700">
        <SectionHeader title="Account Core" description="Manage your identity matrix and subscription layer." icon={Layout} />

        {/* Identity */}
        <Card noPad>
          <div className="p-8 pb-4">
            <h4 className="text-[10px] font-black uppercase tracking-[0.3em] text-zinc-500 mb-6 flex items-center gap-2">
              <div className="h-1.5 w-1.5 rounded-full bg-cyan-500" />
              Identity Matrix
            </h4>
            <div className="flex items-center justify-between p-5 rounded-[24px] bg-white/[0.02] border border-white/[0.05] hover:border-cyan-500/30 transition-colors group">
              <div className="flex items-center gap-5">
                <div className="h-12 w-12 rounded-[16px] bg-cyan-500/10 border border-cyan-500/20 flex items-center justify-center group-hover:bg-cyan-500/20 transition-colors">
                  <Mail size={20} className="text-cyan-400" />
                </div>
                <div>
                  <p className="text-sm font-black text-white italic tracking-tight">Primary Auth Vector</p>
                  <p className="text-xs text-zinc-400 font-mono mt-1">{profile?.email || "—"}</p>
                </div>
              </div>
              <button className="text-[10px] font-black uppercase tracking-widest text-zinc-600 cursor-not-allowed border border-white/5 px-3 py-1.5 rounded-xl bg-white/[0.02]" disabled>
                Locked
              </button>
            </div>
          </div>

          <div className="p-8 pt-4">
            <h4 className="text-[10px] font-black uppercase tracking-[0.3em] text-zinc-500 mb-6 flex items-center gap-2">
              <div className="h-1.5 w-1.5 rounded-full bg-amber-500" />
              Subscription Layer
            </h4>
            <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4 p-6 rounded-[24px] bg-gradient-to-br from-amber-500/10 via-transparent to-transparent border border-amber-500/20 shadow-[inset_0_0_20px_rgba(245,158,11,0.05)]">
              <div className="flex items-center gap-5">
                <div className="relative">
                  <div className="h-14 w-14 rounded-[18px] bg-gradient-to-br from-amber-500 to-orange-600 p-[1px]">
                    <div className="h-full w-full rounded-[17px] bg-[#0a0b14] flex items-center justify-center">
                       <Zap size={24} className="text-amber-400" />
                    </div>
                  </div>
                  <motion.div animate={{ opacity: [0.5, 1, 0.5] }} transition={{ duration: 2, repeat: Infinity }} className="absolute inset-0 bg-amber-500/20 blur-xl rounded-full" />
                </div>
                <div>
                  <div className="flex items-center gap-3 mb-1">
                    <h5 className="text-lg font-black text-white italic uppercase tracking-tighter">
                      {profile?.subscription || "Standard Free"}
                    </h5>
                    <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg bg-emerald-500/10 border border-emerald-500/20 text-[9px] font-black tracking-widest text-emerald-400 uppercase shadow-[0_0_10px_rgba(16,185,129,0.1)]">
                      <span className="h-1.5 w-1.5 rounded-full bg-emerald-400 animate-pulse" />
                      Active Node
                    </span>
                  </div>
                  <p className="text-xs text-zinc-500 font-bold uppercase tracking-widest">Standard Generation Protocol</p>
                </div>
              </div>
              <button
                onClick={() => router.push("/studio/subscription")}
                className="rounded-[16px] bg-white text-black px-6 py-3 text-[10px] font-black uppercase tracking-widest flex items-center gap-2 hover:bg-zinc-200 transition-colors"
              >
                Manage Link <ExternalLink size={14} />
              </button>
            </div>
          </div>
        </Card>

        {/* Danger Zone */}
        <div className="rounded-[32px] p-8 border border-red-500/30 bg-gradient-to-br from-red-500/10 to-transparent relative overflow-hidden backdrop-blur-md">
          <div className="absolute top-0 right-0 w-64 h-64 bg-red-500/10 blur-[80px] rounded-full pointer-events-none" />
          <div className="relative z-10">
            <h4 className="text-[10px] font-black uppercase tracking-[0.3em] text-red-400 mb-6 flex items-center gap-2">
              <ShieldCheck size={14} /> Critical Area
            </h4>
            <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-6 p-6 rounded-[24px] bg-red-950/40 border border-red-500/20">
              <div>
                <p className="text-base font-black text-white italic uppercase tracking-tight">Initiate Server Wipe</p>
                <p className="text-xs text-red-200/60 font-bold mt-1">
                  Permanently destroys your neural profile and all generated assets. Irreversible.
                </p>
              </div>
              <button className="rounded-[16px] bg-red-500/20 text-red-400 border border-red-500/30 px-6 py-3 text-[10px] font-black uppercase tracking-widest hover:bg-red-500 hover:text-white transition-all shadow-[0_0_20px_rgba(239,68,68,0.2)] whitespace-nowrap">
                Purge Account
              </button>
            </div>
          </div>
        </div>
      </div>
    ),

    /* ─── Security ─── */
    security: (
      <div className="space-y-8 animate-in fade-in slide-in-from-bottom-4 duration-700">
        <SectionHeader title="Security Protocol" description="Safeguard your neural assets and forge keys" icon={ShieldCheck} />

        <Card noPad>
          <div className="p-8">
            <div className="space-y-4">
              {/* 2FA */}
              <div className="flex items-center justify-between p-5 rounded-[24px] bg-white/[0.02] border border-white/[0.05] hover:border-emerald-500/30 transition-colors group">
                <div className="flex items-center gap-5">
                  <div className="h-12 w-12 rounded-[16px] bg-emerald-500/10 border border-emerald-500/20 flex items-center justify-center group-hover:bg-emerald-500/20 transition-colors">
                    <KeyRound size={20} className="text-emerald-400" />
                  </div>
                  <div>
                    <p className="text-sm font-black text-white italic tracking-tight">Two-Factor Auth</p>
                    <p className="text-xs text-zinc-400 font-bold mt-1">Require cryptographic proof on login</p>
                  </div>
                </div>
                <div className="relative inline-flex h-7 w-12 shrink-0 cursor-not-allowed rounded-full bg-[#05050d] border-2 border-white/10 shadow-inner">
                  <span className="pointer-events-none inline-block h-5 w-5 translate-x-0.5 self-center rounded-full bg-zinc-600 shadow-md" />
                </div>
              </div>

              {/* Password */}
              <div className="flex items-center justify-between p-5 rounded-[24px] bg-white/[0.02] border border-white/[0.05] hover:border-blue-500/30 transition-colors group">
                <div className="flex items-center gap-5">
                  <div className="h-12 w-12 rounded-[16px] bg-blue-500/10 border border-blue-500/20 flex items-center justify-center group-hover:bg-blue-500/20 transition-colors">
                    <Lock size={20} className="text-blue-400" />
                  </div>
                  <div>
                    <p className="text-sm font-black text-white italic tracking-tight">Forge Password</p>
                    <p className="text-xs text-zinc-400 font-bold mt-1 tracking-widest">••••••••••••</p>
                  </div>
                </div>
                <button className="text-[10px] font-black uppercase tracking-widest text-zinc-600 cursor-not-allowed border border-white/5 px-4 py-2.5 rounded-[14px] bg-white/[0.02]" disabled>
                  Rotate Key
                </button>
              </div>
            </div>
          </div>

          <div className="p-8 pt-4 border-t border-white/[0.05] bg-gradient-to-b from-transparent to-[#05050d]/50">
            <h4 className="text-[10px] font-black uppercase tracking-[0.3em] text-zinc-500 mb-6 flex items-center gap-2">
              <Globe size={14} /> Active Conduits
            </h4>
            <div className="p-6 rounded-[24px] bg-white/[0.02] border border-white/[0.05] flex flex-col sm:flex-row sm:items-center justify-between gap-4">
              <div className="flex items-start gap-4">
                <div className="h-10 w-10 mt-1 rounded-[14px] bg-blue-500/10 border border-blue-500/20 flex items-center justify-center shrink-0">
                  <Layout size={16} className="text-blue-400" />
                </div>
                <div>
                  <p className="text-sm font-black text-white italic tracking-tight">Current Workstation</p>
                  <p className="text-[10px] font-mono text-blue-300 mt-1.5 uppercase">macOS · Web Interface</p>
                  <p className="text-[10px] text-zinc-600 font-bold mt-1">192.168.1.1 — Active now</p>
                </div>
              </div>
              <span className="inline-flex items-center gap-2 px-3 py-1.5 rounded-xl bg-blue-500/10 border border-blue-500/20 text-[9px] font-black tracking-widest text-blue-400 uppercase shadow-[0_0_15px_rgba(99,102,241,0.15)]">
                <span className="h-1.5 w-1.5 rounded-full bg-blue-400 animate-pulse" />
                Live Link
              </span>
            </div>
          </div>
        </Card>
      </div>
    ),

    /* ─── Notifications ─── */
    notifications: (
      <div className="space-y-8 animate-in fade-in slide-in-from-bottom-4 duration-700">
        <SectionHeader title="Comm Network" description="Control your signal-to-noise ratio" icon={Bell} />
        <Card noPad>
          <div className="p-4">
            {[
              { label: "Build Telemetry", desc: "Alert when engine finishes rendering", enabled: true, icon: Zap },
              { label: "Engine Alerts", desc: "Critical errors and compiler warnings", enabled: true, icon: AlertCircle },
              { label: "Social Pings", desc: "Game reviews and community replies", enabled: false, icon: Eye },
              { label: "Studio Updates", desc: "New architecture releases and labs", enabled: false, icon: Bell },
            ].map((item, i) => {
              const Icon = item.icon;
              return (
                <div key={i} className="flex items-center justify-between p-5 mb-2 last:mb-0 rounded-[24px] hover:bg-white/[0.02] transition-colors group">
                  <div className="flex items-center gap-5">
                    <div className={`h-12 w-12 rounded-[16px] border flex items-center justify-center transition-colors ${
                      item.enabled ? "bg-amber-500/10 border-amber-500/20 text-amber-400" : "bg-white/[0.02] border-white/5 text-zinc-600 group-hover:text-zinc-400"
                    }`}>
                      <Icon size={20} />
                    </div>
                    <div>
                      <p className={`text-sm font-black italic tracking-tight ${item.enabled ? "text-white" : "text-zinc-500"}`}>{item.label}</p>
                      <p className="text-[11px] font-bold text-zinc-600 mt-1">{item.desc}</p>
                    </div>
                  </div>
                  <div className={`relative inline-flex h-7 w-12 shrink-0 rounded-full border-2 transition-colors duration-300 cursor-not-allowed ${
                    item.enabled ? "bg-[#05050d] border-amber-500/50 shadow-[0_0_15px_rgba(245,158,11,0.2)]" : "bg-[#05050d] border-white/10"
                  }`}>
                    <span className={`inline-block h-5 w-5 self-center rounded-full shadow-lg transition-transform duration-300 ${
                      item.enabled ? "translate-x-5 bg-amber-400" : "translate-x-0.5 bg-zinc-700"
                    }`} />
                  </div>
                </div>
              );
            })}
          </div>
        </Card>
      </div>
    ),

    /* ─── Billing ─── */
    billing: (
      <div className="space-y-8 animate-in fade-in slide-in-from-bottom-4 duration-700">
        <SectionHeader title="Vault & Billing" description="Fuel reserves and network provisioning" icon={CreditCard} />

        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          {/* Credits card */}
          <Card className="flex flex-col justify-between min-h-[220px] relative">
            <div className="absolute top-0 right-0 w-32 h-32 bg-sky-500/10 blur-[50px] rounded-full pointer-events-none" />
            <div className="relative z-10 flex flex-col h-full">
              <h4 className="text-[10px] font-black uppercase tracking-[0.3em] text-zinc-500 mb-2 flex items-center gap-2">
                <div className="h-1.5 w-1.5 rounded-full bg-sky-500" /> Total Balance
              </h4>
              <div className="flex items-baseline gap-3 my-auto">
                <span className="text-6xl font-black text-[var(--foreground)] italic tracking-tighter gf-chromatic">{profile?.credits ?? 0}</span>
                <span className="text-[10px] font-black text-[var(--foreground)] uppercase tracking-[0.3em]">PRO CREATOR</span>
              </div>
              <div className="mt-auto pt-6">
                <button className="w-full rounded-[16px] bg-sky-500/10 hover:bg-sky-500/20 text-sky-400 border border-sky-500/30 px-6 py-4 text-[10px] font-black uppercase tracking-widest transition-all shadow-[0_0_20px_rgba(14,165,233,0.1)]">
                  Replenish Fuel
                </button>
              </div>
            </div>
          </Card>

          {/* Plan card */}
          <Card className="flex flex-col justify-between min-h-[220px] relative">
            <div className="absolute -bottom-10 -right-10 pointer-events-none opacity-[0.03] rotate-12">
              <Cpu size={180} />
            </div>
            <div className="relative z-10 flex flex-col h-full">
              <h4 className="text-[10px] font-black uppercase tracking-[0.3em] text-zinc-500 mb-2 flex items-center gap-2">
                <div className="h-1.5 w-1.5 rounded-full bg-sky-500" /> Active Plan
              </h4>
              <div className="my-auto">
                <h5 className="text-3xl font-black text-white italic uppercase tracking-tight">{profile?.subscription || "Standard Free"}</h5>
                <p className="text-[11px] font-bold text-zinc-500 uppercase tracking-widest mt-2">{isPro ? "Full Studio Access" : "Basic Forge Access"}</p>
              </div>
              <div className="mt-auto pt-6">
                <button
                  onClick={() => router.push("/studio/subscription")}
                  className="w-full rounded-[16px] bg-white text-black px-6 py-4 text-[10px] font-black uppercase tracking-widest hover:bg-zinc-200 transition-colors shadow-xl shadow-white/5"
                >
                  Upgrade Matrix
                </button>
              </div>
            </div>
          </Card>

          {/* Transactions */}
          <div className="md:col-span-2">
            <Card noPad>
              <div className="p-6 border-b border-white/[0.05] flex items-center justify-between">
                <h4 className="text-[10px] font-black uppercase tracking-[0.3em] text-white">Ledger History</h4>
                <button className="text-[9px] font-black uppercase tracking-widest text-zinc-500 hover:text-white transition-colors" onClick={() => router.push("/studio/wallet")}>
                  Full Ledger &rarr;
                </button>
              </div>
              <div className="p-8 text-center bg-black/20">
                <div className="inline-flex h-12 w-12 rounded-[16px] bg-white/[0.02] border border-white/5 items-center justify-center mb-4">
                   <CreditCard size={20} className="text-zinc-600" />
                </div>
                <p className="text-xs font-bold text-zinc-500 uppercase tracking-widest">No recent transactions recorded</p>
              </div>
            </Card>
          </div>
        </div>
      </div>
    ),
  };

  return (
    <UserShell title="Settings" subtitle="Control Center">
      <div className="flex flex-col lg:flex-row gap-6 lg:gap-8 min-h-[600px]">
        {/* ── Sidebar tabs ── */}
        <div className="lg:sticky lg:top-0 lg:self-start">
          <SettingsTabs activeTab={activeTab} onTabChange={setActiveTab} />
        </div>

        {/* ── Content ── */}
        <div className="flex-1 min-w-0">
          <AnimatePresence mode="wait">
            <motion.div
              key={activeTab}
              initial={{ opacity: 0, x: 12 }}
              animate={{ opacity: 1, x: 0 }}
              exit={{ opacity: 0, x: -8 }}
              transition={{ duration: 0.22, ease: "easeOut" }}
            >
              {loading ? (
                <div className="space-y-4">
                  <div className="gf-skeleton h-8 w-48 rounded-xl" />
                  <div className="gf-skeleton h-4 w-80 rounded-lg" />
                  <div className="gf-skeleton h-48 w-full rounded-[22px] mt-4" />
                  <div className="gf-skeleton h-64 w-full rounded-[22px]" />
                </div>
              ) : (
                tabContent[activeTab]
              )}
            </motion.div>
          </AnimatePresence>
        </div>
      </div>
    </UserShell>
  );
}
