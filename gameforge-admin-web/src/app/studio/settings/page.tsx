"use client";

import { useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import UserShell from "@/app/_components/UserShell";
import { apiFetch, ApiError } from "@/lib/api";
import { getUserToken } from "@/lib/userAuth";
import { normalizeImageUrl } from "@/lib/media";
import { motion, AnimatePresence } from "framer-motion";
import SettingsTabs, { TabId } from "./_components/SettingsTabs";
import { 
  CheckCircle2, AlertCircle, Loader2, Camera, 
  Mail, ShieldCheck, Zap, Globe, Trash2
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

export default function SettingsPage() {
  const router = useRouter();
  const token = useMemo(() => getUserToken(), []);

  const [activeTab, setActiveTab] = useState<TabId>("profile");
  const [loading, setLoading] = useState(true);
  const [updating, setUpdating] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  const [profile, setProfile] = useState<UserProfile | null>(null);
  const [username, setUsername] = useState("");
  const [fullName, setFullName] = useState("");
  const [bio, setBio] = useState("");

  useEffect(() => {
    let cancelled = false;
    async function load() {
      if (!token) return;
      setLoading(true);
      try {
        const res = await apiFetch<any>("/auth/profile", { method: "GET", token });
        const data = (res && typeof res === "object" && "data" in res) ? res.data : res;
        if (!cancelled) {
          const p = (data?.user ?? data) as UserProfile;
          setProfile(p);
          setUsername(p.username || "");
          setFullName(p.fullName || "");
          setBio(p.bio || "");
        }
      } catch (e: any) {
        if (!cancelled) setError(e instanceof ApiError ? e.message : "Failed to load profile");
      } finally {
        if (!cancelled) setLoading(false);
      }
    }
    load();
    return () => { cancelled = true; };
  }, [token]);

  async function handleUpdate(e?: React.FormEvent) {
    if (e) e.preventDefault();
    if (!token) return;
    setUpdating(true);
    setError(null);
    setSuccess(null);
    try {
      await apiFetch("/auth/profile", {
        method: "PUT",
        token,
        body: { username, fullName, bio },
      });
      setSuccess("Profile updated successfully");
      setTimeout(() => setSuccess(null), 3000);
    } catch (e: any) {
      setError(e instanceof ApiError ? e.message : "Update failed");
    } finally {
      setUpdating(false);
    }
  }

  const tabVariants = {
    initial: { opacity: 0, x: 20 },
    animate: { opacity: 1, x: 0 },
    exit: { opacity: 0, x: -20 },
  };

  return (
    <UserShell title="Settings" subtitle="Control Center">
      <div className="flex flex-col lg:flex-row gap-8 lg:gap-12 min-h-[600px]">
        {/* Navigation Sidebar */}
        <SettingsTabs activeTab={activeTab} onTabChange={setActiveTab} />

        {/* Content Area */}
        <div className="flex-1">
          <AnimatePresence mode="wait">
            <motion.div
              key={activeTab}
              variants={tabVariants}
              initial="initial"
              animate="animate"
              exit="exit"
              transition={{ duration: 0.3, ease: "easeOut" }}
            >
              {/* Profile Tab */}
              {activeTab === "profile" && (
                <div className="space-y-6">
                  <header>
                    <h3 className="text-2xl font-bold text-white">Public Profile</h3>
                    <p className="text-zinc-400 mt-1">Information visible to other users on the platform.</p>
                  </header>

                  <div className="gf-panel-strong rounded-3xl p-8 border border-white/5 space-y-8">
                    {/* Avatar Upload */}
                    <div className="flex flex-col sm:flex-row items-center gap-6">
                      <div className="relative group">
                        <div className="h-24 w-24 overflow-hidden rounded-[2rem] border-2 border-indigo-500/20 bg-zinc-900 shadow-2xl">
                          {profile?.avatar ? (
                            <img src={normalizeImageUrl(profile.avatar)} alt="" className="h-full w-full object-cover transition-transform duration-500 group-hover:scale-110" />
                          ) : (
                            <div className="flex h-full w-full items-center justify-center text-3xl font-bold text-indigo-500/40 select-none">
                              {username.charAt(0).toUpperCase() || "U"}
                            </div>
                          )}
                        </div>
                        <button className="absolute -bottom-2 -right-2 p-2.5 rounded-xl bg-indigo-600 border border-indigo-500 text-white shadow-xl hover:bg-indigo-500 transition-all group-hover:scale-110">
                          <Camera size={16} />
                        </button>
                      </div>
                      <div className="text-center sm:text-left">
                        <h4 className="text-lg font-semibold text-white">Profile Photo</h4>
                        <p className="text-sm text-zinc-500 mt-1 mb-3">Upload a PNG or JPEG at least 512x512px.</p>
                        <button className="gf-btn rounded-xl px-4 py-2 text-xs" disabled>Change Avatar (soon)</button>
                      </div>
                    </div>

                    <form onSubmit={handleUpdate} className="space-y-6">
                      <div className="grid grid-cols-1 sm:grid-cols-2 gap-6">
                        <div className="space-y-2">
                          <label className="text-xs font-bold text-zinc-400 uppercase tracking-widest ml-1">Username</label>
                          <input 
                            className="gf-input w-full rounded-2xl px-4 py-3 text-sm focus:ring-2 focus:ring-indigo-500/50 transition-all" 
                            placeholder="e.g. game_master"
                            value={username} 
                            onChange={(e) => setUsername(e.target.value)} 
                          />
                        </div>
                        <div className="space-y-2">
                          <label className="text-xs font-bold text-zinc-400 uppercase tracking-widest ml-1">Full Name</label>
                          <input 
                            className="gf-input w-full rounded-2xl px-4 py-3 text-sm focus:ring-2 focus:ring-indigo-500/50 transition-all" 
                            placeholder="Your full name"
                            value={fullName} 
                            onChange={(e) => setFullName(e.target.value)} 
                          />
                        </div>
                      </div>

                      <div className="space-y-2">
                        <label className="text-xs font-bold text-zinc-400 uppercase tracking-widest ml-1">Biography</label>
                        <textarea 
                          className="gf-input w-full rounded-2xl px-4 py-3 text-sm focus:ring-2 focus:ring-indigo-500/50 transition-all" 
                          rows={4} 
                          placeholder="Tell us about yourself..."
                          value={bio} 
                          onChange={(e) => setBio(e.target.value)} 
                        />
                        <p className="text-[11px] text-zinc-500 mt-1 ml-1 text-right">Markdown supported.</p>
                      </div>

                      <div className="flex items-center justify-between pt-4 border-t border-white/5">
                        <div className="flex items-center gap-2">
                          {success && <span className="flex items-center gap-1.5 text-xs text-emerald-400 animate-in fade-in slide-in-from-left-4"><CheckCircle2 size={14}/> {success}</span>}
                          {error && <span className="flex items-center gap-1.5 text-xs text-red-400 animate-in fade-in slide-in-from-left-4"><AlertCircle size={14}/> {error}</span>}
                        </div>
                        <button
                          type="submit"
                          disabled={updating || loading}
                          className="relative overflow-hidden flex items-center gap-2 rounded-2xl bg-gradient-to-r from-indigo-600 to-purple-600 px-6 py-3 text-sm font-bold text-white shadow-[0_4px_20px_rgba(99,102,241,0.3)] hover:shadow-[0_4px_30px_rgba(99,102,241,0.5)] transition-all disabled:opacity-50 active:scale-95 group"
                        >
                          <div className="absolute inset-0 bg-white/10 opacity-0 group-hover:opacity-100 transition-opacity" />
                          {updating ? <Loader2 size={18} className="animate-spin" /> : "Update Profile"}
                        </button>
                      </div>
                    </form>
                  </div>
                </div>
              )}

              {/* Account Tab */}
              {activeTab === "account" && (
                <div className="space-y-8">
                  <header>
                    <h3 className="text-2xl font-bold text-white">Account Settings</h3>
                    <p className="text-zinc-400 mt-1">Manage your identity and subscription status.</p>
                  </header>

                  <div className="grid gap-6">
                    {/* Identity Panel */}
                    <div className="gf-panel-strong rounded-3xl p-8 border border-white/5">
                      <h4 className="text-sm font-bold text-zinc-500 uppercase tracking-widest mb-6">Identity</h4>
                      <div className="space-y-4">
                        <div className="flex items-center justify-between p-4 rounded-2xl bg-white/[0.03] border border-white/5">
                          <div className="flex items-center gap-4">
                            <div className="p-3 rounded-xl bg-indigo-500/10 text-indigo-400">
                              <Mail size={20} />
                            </div>
                            <div>
                              <p className="text-sm font-bold text-white">Email Address</p>
                              <p className="text-xs text-zinc-400 mt-0.5">{profile?.email}</p>
                            </div>
                          </div>
                          <button className="text-xs font-bold text-indigo-400 hover:text-indigo-300 transition-colors" disabled>Change (Soon)</button>
                        </div>
                      </div>
                    </div>

                    {/* Subscription Panel */}
                    <div className="gf-panel-strong rounded-3xl p-8 border border-white/5">
                      <h4 className="text-sm font-bold text-zinc-500 uppercase tracking-widest mb-6">Subscription</h4>
                      <div className="flex flex-col sm:flex-row items-center justify-between p-6 rounded-2xl bg-gradient-to-br from-zinc-800/50 to-indigo-900/20 border border-white/5">
                        <div className="flex items-center gap-5">
                          <div className="h-16 w-16 rounded-2xl bg-emerald-500/10 flex items-center justify-center text-emerald-400 shadow-inner">
                            <Zap size={32} />
                          </div>
                          <div>
                            <div className="flex items-center gap-2">
                              <h5 className="text-lg font-bold text-white capitalize">{profile?.subscription || "Standard Free"}</h5>
                              <span className="px-2 py-0.5 rounded-full bg-emerald-500/20 text-[10px] font-black tracking-widest text-emerald-400 uppercase">Active</span>
                            </div>
                            <p className="text-sm text-zinc-400 mt-1">Access to all standard generation tools.</p>
                          </div>
                        </div>
                        <button className="mt-4 sm:mt-0 gf-btn rounded-xl px-6 py-3 font-bold text-sm shadow-xl" onClick={() => router.push("/studio/subscription")}>
                          Manage Subscription
                        </button>
                      </div>
                    </div>

                    {/* Danger Zone */}
                    <div className="rounded-3xl p-8 border border-red-500/10 bg-red-500/[0.02]">
                      <h4 className="text-sm font-bold text-red-500 uppercase tracking-widest mb-4">Danger Zone</h4>
                      <div className="flex items-center justify-between">
                        <div>
                          <p className="text-sm font-bold text-white leading-none">Delete Account</p>
                          <p className="text-xs text-zinc-500 mt-2">Permanently delete your profile and all associated game assets.</p>
                        </div>
                        <button className="flex items-center gap-2 rounded-xl bg-red-500/10 border border-red-500/20 px-4 py-2 text-xs font-bold text-red-500 hover:bg-red-500 hover:text-white transition-all">
                          <Trash2 size={14} /> Delete
                        </button>
                      </div>
                    </div>
                  </div>
                </div>
              )}

              {/* Security Tab (UI Only) */}
              {activeTab === "security" && (
                <div className="space-y-8">
                  <header>
                    <h3 className="text-2xl font-bold text-white">Security</h3>
                    <p className="text-zinc-400 mt-1">Protect your account and game data.</p>
                  </header>

                  <div className="gf-panel-strong rounded-3xl p-8 border border-white/5 space-y-8">
                    <div className="flex items-center justify-between">
                      <div className="flex items-center gap-5">
                        <div className="p-4 rounded-2xl bg-indigo-500/10 text-indigo-400">
                          <ShieldCheck size={32} />
                        </div>
                        <div>
                          <p className="text-lg font-bold text-white">Two-Factor Authentication</p>
                          <p className="text-sm text-zinc-400 mt-1 italic opacity-60">Authentication via app or SMS code.</p>
                        </div>
                      </div>
                      <div className="relative inline-flex h-6 w-11 shrink-0 cursor-not-allowed rounded-full border-2 border-transparent bg-zinc-800 transition-colors duration-200 ease-in-out focus:outline-none">
                        <span className="pointer-events-none inline-block h-5 w-5 translate-x-0 rounded-full bg-white shadow ring-0 transition duration-200 ease-in-out" />
                      </div>
                    </div>

                    <hr className="border-white/5" />

                    <div>
                      <h4 className="text-sm font-bold text-zinc-500 uppercase tracking-widest mb-4">Active Sessions</h4>
                      <div className="p-4 rounded-2xl bg-white/[0.03] border border-white/5 flex items-center justify-between">
                        <div className="flex items-center gap-3">
                          <Globe size={18} className="text-zinc-500" />
                          <div className="text-sm">
                            <span className="text-white font-medium">Lagos, Nigeria</span>
                            <span className="text-zinc-500 ml-2">• Chrome on MacOS</span>
                          </div>
                        </div>
                        <span className="text-[10px] font-bold text-indigo-400/80 uppercase bg-indigo-500/10 px-2 py-0.5 rounded-full">Current</span>
                      </div>
                    </div>
                  </div>
                </div>
              )}

              {/* Billing Tab */}
              {activeTab === "billing" && (
                <div className="space-y-8">
                  <header>
                    <h3 className="text-2xl font-bold text-white">Billing & Wallet</h3>
                    <p className="text-zinc-400 mt-1">Manage your generation credits and payment history.</p>
                  </header>

                  <div className="grid grid-cols-1 sm:grid-cols-2 gap-6">
                    <div className="gf-panel-strong rounded-3xl p-8 border border-white/5 flex flex-col justify-between aspect-video">
                      <h4 className="text-xs font-black text-zinc-500 uppercase tracking-widest">Available Credits</h4>
                      <div className="mt-4">
                        <div className="flex items-baseline gap-2">
                          <span className="text-5xl font-black text-white">{profile?.credits || 0}</span>
                          <span className="text-sm font-bold text-indigo-400 uppercase tracking-widest">GF-COINS</span>
                        </div>
                        <p className="text-xs text-zinc-500 mt-2 italic">Standard usage credits reset monthly.</p>
                      </div>
                      <button className="mt-6 w-full rounded-2xl bg-white/[0.05] border border-white/10 px-4 py-3 text-sm font-bold text-white hover:bg-white/10 transition-all shadow-lg active:scale-95">
                        Purchase More Credits
                      </button>
                    </div>

                    <div className="gf-panel-strong rounded-3xl p-8 border border-white/5 flex flex-col justify-between aspect-video relative overflow-hidden group">
                      <div className="absolute top-0 right-0 p-6 opacity-10 group-hover:opacity-20 transition-opacity">
                        <Zap size={120} />
                      </div>
                      <h4 className="text-xs font-black text-zinc-500 uppercase tracking-widest">Current Plan</h4>
                      <div className="mt-4 relative z-10">
                        <h5 className="text-3xl font-black text-white">{profile?.subscription?.toUpperCase() || "FREE PLAN"}</h5>
                        <p className="text-xs text-zinc-400 mt-2">Next refresh date: April 30, 2026</p>
                      </div>
                      <button className="mt-6 w-full rounded-2xl bg-indigo-600 px-4 py-3 text-sm font-bold text-white shadow-xl hover:shadow-[0_4px_30px_rgba(99,102,241,0.4)] transition-all active:scale-95">
                        Upgrade To Pro
                      </button>
                    </div>
                  </div>
                </div>
              )}
            </motion.div>
          </AnimatePresence>
        </div>
      </div>
    </UserShell>
  );
}
