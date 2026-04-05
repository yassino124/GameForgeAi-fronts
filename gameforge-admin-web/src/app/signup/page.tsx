"use client";

import { useState, useEffect, useMemo } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { apiFetch } from "@/lib/api";
import { setUserToken } from "@/lib/userAuth";
import { motion, AnimatePresence } from "framer-motion";
import {
  User,
  Mail,
  Lock,
  ShieldCheck,
  Sparkles,
  Rocket,
  ArrowRight,
  CheckCircle2,
  ChevronRight,
  Info,
  Laptop,
  Gamepad2,
  AlertCircle,
  Loader2
} from "lucide-react";

type RegisterResponse = {
  access_token?: string;
  refresh_token?: string;
  user?: {
    id?: string;
    email?: string;
    username?: string;
    role?: string;
  };
};

export default function SignUpPage() {
  const router = useRouter();
  const [username, setUsername] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [role, setRole] = useState("devl");
  const [agreedToTerms, setAgreedToTerms] = useState(false);
  const [showTerms, setShowTerms] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState(false);

  const isEmailValid = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
  const isPasswordStrong = /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]/.test(password);

  const canSubmit = useMemo(() => {
    return (
      username.trim().length >= 2 &&
      isEmailValid &&
      password.length >= 8 &&
      isPasswordStrong &&
      password === confirmPassword &&
      agreedToTerms &&
      !loading
    );
  }, [username, email, isEmailValid, password, isPasswordStrong, confirmPassword, agreedToTerms, loading]);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!canSubmit) return;

    setError(null);
    setLoading(true);

    try {
      await apiFetch("/auth/register", {
        method: "POST",
        body: {
          username: username.trim(),
          email: email.trim(),
          password,
          role,
        },
      });

      setSuccess(true);
      setTimeout(() => {
        router.push(`/verify-email?email=${encodeURIComponent(email.trim())}`);
      }, 1500);
    } catch (err: any) {
      setError(err?.message || "Sign up failed");
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="min-h-screen bg-zinc-950 font-sans selection:bg-indigo-500/30 overflow-hidden relative">
      {/* Background - Stabilized matching Admin Login style */}
      <div className="absolute inset-0 overflow-hidden pointer-events-none">
        <div className="absolute -top-24 left-1/2 h-[600px] w-[1000px] -translate-x-1/2 rounded-full bg-gradient-to-r from-indigo-600/30 via-fuchsia-600/20 to-cyan-500/20 blur-[120px] opacity-50" />
      </div>

      <div className="relative mx-auto flex min-h-screen max-w-7xl items-center justify-center px-6 py-16 z-10">
        <div className="w-full max-w-2xl">
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.5 }}
            className="rounded-[2rem] border border-white/10 bg-white/[0.03] p-8 sm:p-10 shadow-[0_0_0_1px_rgba(255,255,255,0.06),0_24px_60px_rgba(0,0,0,0.6)] backdrop-blur-3xl relative overflow-hidden"
          >
            {/* Subtle Gradient Glow inside card */}
            <div className="absolute top-0 right-0 w-32 h-32 bg-indigo-500/5 blur-3xl -mr-16 -mt-16" />

            <div className="mb-10 relative z-10 text-center">
              <div className="inline-flex items-center gap-2 rounded-full border border-white/10 bg-white/5 px-3 py-1 text-[10px] font-bold uppercase tracking-widest text-zinc-200">
                <Sparkles size={10} className="text-emerald-400 animate-pulse" />
                Join the Genesis
              </div>
              <h1 className="mt-6 text-4xl sm:text-5xl font-black tracking-tight text-white italic">
                Forge Your <span className="text-transparent bg-clip-text bg-gradient-to-r from-indigo-400 to-fuchsia-400">Identity</span>
              </h1>
              <p className="mt-2 text-sm text-zinc-400 font-medium">
                Join the next generation of creative game architects.
              </p>
            </div>
            <AnimatePresence mode="wait">
              {success ? (
                <motion.div
                  key="success"
                  initial={{ opacity: 0, scale: 0.9 }}
                  animate={{ opacity: 1, scale: 1 }}
                  className="py-16 text-center"
                >
                  <div className="relative inline-flex mb-8">
                    <motion.div
                      initial={{ scale: 0 }}
                      animate={{ scale: 1 }}
                      className="h-24 w-24 rounded-full bg-indigo-500/10 flex items-center justify-center border border-indigo-500/20 shadow-[0_0_40px_rgba(99,102,241,0.15)]"
                    >
                      <Rocket size={48} className="text-indigo-400" />
                    </motion.div>
                    <motion.div
                      animate={{ scale: [1, 1.2, 1], opacity: [0.5, 0.2, 0.5] }}
                      transition={{ duration: 2, repeat: Infinity }}
                      className="absolute inset-0 rounded-full bg-indigo-500/20 blur-xl -z-10"
                    />
                  </div>
                  <h2 className="text-2xl font-bold text-white mb-2">Account Created</h2>
                  <p className="text-zinc-400 text-sm">Redirecting to verification terminal...</p>
                </motion.div>
              ) : (
                <form onSubmit={onSubmit} className="space-y-7 relative z-10">
                  {/* Form Grid */}
                  <div className="grid grid-cols-1 sm:grid-cols-2 gap-5">
                    <div className="group space-y-2">
                      <label className="text-[10px] font-bold text-zinc-500 uppercase tracking-widest ml-1 group-focus-within:text-indigo-400 transition-colors flex items-center gap-2">
                        <User size={10} /> Username
                      </label>
                      <input
                        value={username}
                        onChange={(e) => setUsername(e.target.value)}
                        placeholder="nexus_architect"
                        className={`w-full bg-black/40 border ${username.length > 0 && username.length < 2 ? 'border-red-500/50' : 'border-white/5'} rounded-2xl px-5 py-3.5 text-sm text-white placeholder:text-zinc-700 focus:outline-none focus:border-indigo-500/50 focus:bg-black/60 transition-all duration-300`}
                        required
                      />
                      {username.length > 0 && username.length < 2 && (
                        <p className="text-[9px] text-red-400 ml-1">Minimum 2 characters</p>
                      )}
                    </div>
                    <div className="group space-y-2">
                      <label className="text-[10px] font-bold text-zinc-500 uppercase tracking-widest ml-1 group-focus-within:text-indigo-400 transition-colors flex items-center gap-2">
                        <Mail size={10} /> Email Address
                      </label>
                      <input
                        type="email"
                        value={email}
                        onChange={(e) => setEmail(e.target.value)}
                        placeholder="you@nebula.com"
                        className={`w-full bg-black/40 border ${email.length > 0 && !isEmailValid ? 'border-red-500/50' : 'border-white/5'} rounded-2xl px-5 py-3.5 text-sm text-white placeholder:text-zinc-700 focus:outline-none focus:border-indigo-500/50 focus:bg-black/60 transition-all duration-300`}
                        required
                      />
                      {email.length > 0 && !isEmailValid && (
                        <p className="text-[9px] text-red-400 ml-1">Invalid email format</p>
                      )}
                    </div>
                    <div className="group space-y-2">
                      <label className="text-[10px] font-bold text-zinc-500 uppercase tracking-widest ml-1 group-focus-within:text-fuchsia-400 transition-colors flex items-center gap-2">
                        <Lock size={10} /> Password
                      </label>
                      <input
                        type="password"
                        value={password}
                        onChange={(e) => setPassword(e.target.value)}
                        placeholder="••••••••"
                        className={`w-full bg-black/40 border ${password.length > 0 && (!isPasswordStrong || password.length < 8) ? 'border-red-500/50' : 'border-white/5'} rounded-2xl px-5 py-3.5 text-sm text-white placeholder:text-zinc-700 focus:outline-none focus:border-fuchsia-500/50 focus:bg-black/60 transition-all duration-300`}
                        required
                      />
                      {password.length > 0 && password.length < 8 && (
                        <p className="text-[9px] text-red-400 ml-1">Minimum 8 characters</p>
                      )}
                      {password.length >= 8 && !isPasswordStrong && (
                        <p className="text-[9px] text-amber-400 ml-1 leading-tight">Must include Upper, Lower, Number & Special</p>
                      )}
                    </div>
                    <div className="group space-y-2">
                      <label className="text-[10px] font-bold text-zinc-500 uppercase tracking-widest ml-1 group-focus-within:text-fuchsia-400 transition-colors flex items-center gap-2">
                        <ShieldCheck size={10} /> Confirm
                      </label>
                      <input
                        type="password"
                        value={confirmPassword}
                        onChange={(e) => setConfirmPassword(e.target.value)}
                        placeholder="••••••••"
                        className={`w-full bg-black/40 border ${confirmPassword.length > 0 && password !== confirmPassword ? 'border-red-500/50' : 'border-white/5'} rounded-2xl px-5 py-3.5 text-sm text-white placeholder:text-zinc-700 focus:outline-none focus:border-fuchsia-500/50 focus:bg-black/60 transition-all duration-300`}
                        required
                      />
                      {confirmPassword.length > 0 && password !== confirmPassword && (
                        <p className="text-[9px] text-red-400 ml-1">Passwords do not match</p>
                      )}
                    </div>
                  </div>

                  {/* Role Selection */}
                  <div className="space-y-4">
                    <div className="flex items-center justify-between px-1">
                      <span className="text-[10px] font-black text-zinc-500 uppercase tracking-[0.2em]">Select Professional Role</span>
                      <div className="h-px bg-white/5 flex-1 ml-4" />
                    </div>
                    <div className="grid grid-cols-2 gap-4">
                      <button
                        type="button"
                        onClick={() => setRole("user")}
                        className={`group relative flex flex-col items-center justify-center p-5 rounded-2xl border transition-all duration-500 overflow-hidden ${role === "user"
                            ? "bg-indigo-500/10 border-indigo-500/50 shadow-[0_0_40px_rgba(99,102,241,0.15)] ring-1 ring-indigo-500/20"
                            : "bg-black/20 border-white/5 hover:border-white/10 hover:bg-white/5"
                          }`}
                      >
                        <div className={`h-10 w-10 rounded-xl border-2 flex items-center justify-center mb-3 transition-all duration-500 ${role === "user" ? "border-indigo-500 bg-indigo-500/20 rotate-12" : "border-zinc-800 rotate-0"
                          }`}>
                          <span className="text-xl">👤</span>
                        </div>
                        <p className={`text-xs font-black tracking-wider uppercase ${role === "user" ? "text-indigo-400" : "text-zinc-500"}`}>Player</p>
                        {role === "user" && (
                          <div className="absolute bottom-0 left-0 right-0 h-1 bg-gradient-to-r from-transparent via-indigo-500 to-transparent" />
                        )}
                      </button>

                      <button
                        type="button"
                        onClick={() => setRole("devl")}
                        className={`group relative flex flex-col items-center justify-center p-5 rounded-2xl border transition-all duration-500 overflow-hidden ${role === "devl"
                            ? "bg-fuchsia-500/10 border-fuchsia-500/50 shadow-[0_0_40px_rgba(217,70,239,0.15)] ring-1 ring-fuchsia-500/20"
                            : "bg-black/20 border-white/5 hover:border-white/10 hover:bg-white/5"
                          }`}
                      >
                        <div className={`h-10 w-10 rounded-xl border-2 flex items-center justify-center mb-3 transition-all duration-500 ${role === "devl" ? "border-fuchsia-500 bg-fuchsia-500/20 -rotate-12" : "border-zinc-800 rotate-0"
                          }`}>
                          <span className="text-xl">💻</span>
                        </div>
                        <p className={`text-xs font-black tracking-wider uppercase ${role === "devl" ? "text-fuchsia-400" : "text-zinc-500"}`}>Developer</p>
                        {role === "devl" && (
                          <div className="absolute bottom-0 left-0 right-0 h-1 bg-gradient-to-r from-transparent via-fuchsia-500 to-transparent" />
                        )}
                      </button>
                    </div>
                  </div>

                  {/* Terms & Conditions */}
                  <div className="pt-2">
                    <label className="flex items-start gap-3 cursor-pointer group">
                      <div
                        onClick={() => setAgreedToTerms(!agreedToTerms)}
                        className={`mt-0.5 w-5 h-5 rounded-lg border flex items-center justify-center transition-all duration-300 ${agreedToTerms ? 'bg-emerald-500/20 border-emerald-500/50 shadow-[0_0_15px_rgba(16,185,129,0.2)]' : 'bg-white/5 border-white/10 group-hover:border-white/20'
                          }`}
                      >
                        {agreedToTerms && <CheckCircle2 size={12} className="text-emerald-400" />}
                      </div>
                      <span className="text-[11px] leading-relaxed text-zinc-500 group-hover:text-zinc-400 transition-colors">
                        I certify that I have read and accepted the{" "}
                        <button
                          type="button"
                          onClick={(e) => { e.stopPropagation(); setShowTerms(true); }}
                          className="text-indigo-400 hover:text-indigo-300 font-bold underline underline-offset-4"
                        >
                          Terms of Service
                        </button>
                        {" "}governing the Forge AI protocols.
                      </span>
                    </label>
                  </div>

                  {/* Error State */}
                  <AnimatePresence>
                    {error && (
                      <motion.div
                        initial={{ opacity: 0, y: -10 }}
                        animate={{ opacity: 1, y: 0 }}
                        className="flex items-center gap-3 p-4 rounded-xl bg-red-500/10 border border-red-500/20 text-red-400 text-xs font-medium"
                      >
                        <AlertCircle size={14} className="shrink-0" />
                        {error}
                      </motion.div>
                    )}
                  </AnimatePresence>

                  {/* Submit Button */}
                  <AnimatePresence>
                    {canSubmit && (
                      <motion.button
                        key="submit-btn"
                        initial={{ opacity: 0, y: 20, scale: 0.95 }}
                        animate={{ opacity: 1, y: 0, scale: 1 }}
                        exit={{ opacity: 0, y: 10, scale: 0.95 }}
                        type="submit"
                        disabled={loading}
                        className="group relative w-full rounded-2xl py-4.5 transition-all duration-500 disabled:opacity-30 disabled:grayscale disabled:cursor-not-allowed"
                      >
                        <div className="absolute inset-0 bg-gradient-to-r from-indigo-600 to-fuchsia-600 group-hover:scale-105 transition-transform duration-500" />
                        <div className="relative flex items-center justify-center gap-3 text-sm font-black text-white uppercase tracking-[0.2em]">
                          {loading ? (
                            <>
                              <Loader2 size={18} className="animate-spin" />
                              Forging Identity...
                            </>
                          ) : (
                            <>
                              Create Studio Account
                              <ArrowRight size={18} className="group-hover:translate-x-1 transition-transform" />
                            </>
                          )}
                        </div>
                      </motion.button>
                    )}
                  </AnimatePresence>

                  <div className="flex items-center justify-center gap-6 pt-8 border-t border-white/5">
                    <Link href="/signin" className="text-[10px] font-black text-zinc-500 hover:text-white uppercase tracking-widest transition-all group relative">
                      Already Registered
                      <span className="absolute -bottom-1 left-0 w-0 h-[1px] bg-indigo-500 group-hover:w-full transition-all duration-300" />
                    </Link>
                    <div className="w-1 h-1 rounded-full bg-zinc-800" />
                    <Link href="/login" className="text-[10px] font-black text-zinc-500 hover:text-white uppercase tracking-widest transition-all group relative">
                      Admin Portal
                      <span className="absolute -bottom-1 left-0 w-0 h-[1px] bg-fuchsia-500 group-hover:w-full transition-all duration-300" />
                    </Link>
                    <div className="w-1 h-1 rounded-full bg-zinc-800" />
                    <Link href="/" className="text-[10px] font-black text-zinc-500 hover:text-white uppercase tracking-widest transition-all group relative">
                      Main Terminal
                      <span className="absolute -bottom-1 left-0 w-0 h-[1px] bg-cyan-500 group-hover:w-full transition-all duration-300" />
                    </Link>
                  </div>
                </form>
              )}
            </AnimatePresence>
          </motion.div>
        </div>
      </div>

      {/* Modern Terms Modal */}
      <AnimatePresence>
        {showTerms && (
          <div className="fixed inset-0 z-[100] flex items-center justify-center p-6">
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              onClick={() => setShowTerms(false)}
              className="absolute inset-0 bg-black/90 backdrop-blur-md"
            />
            <motion.div
              initial={{ opacity: 0, scale: 0.9, y: 20 }}
              animate={{ opacity: 1, scale: 1, y: 0 }}
              exit={{ opacity: 0, scale: 0.9, y: 20 }}
              className="gf-panel-strong relative w-full max-w-2xl max-h-[80vh] rounded-[2.5rem] bg-[#0a0a0d]/90 border border-white/10 shadow-[0_0_100px_rgba(99,102,241,0.1)] flex flex-col overflow-hidden"
            >
              <div className="p-8 border-b border-white/5 flex items-center justify-between">
                <div className="flex items-center gap-4">
                  <div className="h-12 w-12 rounded-2xl bg-indigo-500/10 flex items-center justify-center border border-indigo-500/20 text-indigo-400">
                    <Info size={24} />
                  </div>
                  <div>
                    <h3 className="text-2xl font-black italic tracking-tight">Terms of Service</h3>
                    <p className="text-[10px] font-bold text-zinc-500 uppercase tracking-widest">Protocol v2.4.0 • Updated April 2026</p>
                  </div>
                </div>
                <button
                  onClick={() => setShowTerms(false)}
                  className="h-10 w-10 rounded-full bg-white/5 flex items-center justify-center hover:bg-white/10 transition-colors"
                >
                  <X size={20} className="text-zinc-500" />
                </button>
              </div>

              <div className="flex-1 overflow-y-auto p-8 custom-scrollbar space-y-8">
                <section className="space-y-3">
                  <h4 className="text-xs font-black uppercase tracking-widest text-indigo-400 flex items-center gap-2">
                    <div className="h-1 w-4 bg-indigo-500 rounded-full" /> 01. Platform Access
                  </h4>
                  <p className="text-sm text-zinc-400 leading-relaxed">
                    By accessing GameForge AI Studio, you enter an ecosystem of high-end game development tools. You agree to use these tools for legitimate creative purposes and respect our ethical AI guidelines.
                  </p>
                </section>
                <section className="space-y-3">
                  <h4 className="text-xs font-black uppercase tracking-widest text-fuchsia-400 flex items-center gap-2">
                    <div className="h-1 w-4 bg-fuchsia-500 rounded-full" /> 02. Intellectual Property
                  </h4>
                  <p className="text-sm text-zinc-400 leading-relaxed">
                    Games generated through our AI remain your creative property. However, the proprietary algorithms, models, and platform architecture are the exclusive property of GameForge AI.
                  </p>
                </section>
                <section className="space-y-3">
                  <h4 className="text-xs font-black uppercase tracking-widest text-emerald-400 flex items-center gap-2">
                    <div className="h-1 w-4 bg-emerald-500 rounded-full" /> 03. Usage Limits
                  </h4>
                  <p className="text-sm text-zinc-400 leading-relaxed">
                    Accounts are intended for individual or professional team use. Automated scraping or reverse engineering of our AI generation pipeline is strictly prohibited and will result in immediate termination.
                  </p>
                </section>
                <section className="space-y-3">
                  <h4 className="text-xs font-black uppercase tracking-widest text-amber-400 flex items-center gap-2">
                    <div className="h-1 w-4 bg-amber-500 rounded-full" /> 04. Privacy & Data
                  </h4>
                  <p className="text-sm text-zinc-400 leading-relaxed">
                    We process your prompts and data to improve your game generation experience. We never sell your personal data to third parties. Your projects are encrypted and stored with industry-leading standards.
                  </p>
                </section>
              </div>

              <div className="p-8 border-t border-white/5 bg-black/40 flex gap-4">
                <button
                  onClick={() => setShowTerms(false)}
                  className="flex-1 rounded-2xl bg-white/5 py-4 font-bold text-zinc-400 hover:text-white transition-colors"
                >
                  Review Again
                </button>
                <button
                  onClick={() => { setAgreedToTerms(true); setShowTerms(false); }}
                  className="flex-[2] rounded-2xl bg-gradient-to-r from-indigo-600 to-fuchsia-600 py-4 font-black text-white shadow-xl shadow-indigo-500/20"
                >
                  Accept & Complete
                </button>
              </div>
            </motion.div>
          </div>
        )}
      </AnimatePresence>
    </div>
  );
}

function X({ size, className }: { size?: number, className?: string }) {
  return (
    <svg
      width={size || 24}
      height={size || 24}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2.5"
      strokeLinecap="round"
      strokeLinejoin="round"
      className={className}
    >
      <path d="M18 6L6 18M6 6l12 12" />
    </svg>
  );
}

