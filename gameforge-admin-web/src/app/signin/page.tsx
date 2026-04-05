"use client";

import { useState, useEffect, useMemo } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { apiFetch } from "@/lib/api";
import { setUserToken as setToken } from "@/lib/userAuth";
import { motion, AnimatePresence } from "framer-motion";
import {
  Mail,
  Lock,
  ArrowRight,
  Loader2,
  Github,
  Chrome,
  AlertCircle,
  CheckCircle2,
  Sparkles,
  ShieldCheck
} from "lucide-react";

export default function SigninPage() {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [rememberMe, setRememberMe] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState(false);

  const canSubmit = email.length > 0 && password.length > 0 && !loading;

  useEffect(() => {
    // Check for token in URL (from social login redirect)
    const params = new URLSearchParams(window.location.search);
    const token = params.get("token");
    if (token) {
      setToken(token);
      setSuccess(true);
      // Clean up URL
      window.history.replaceState({}, document.title, window.location.pathname);
      setTimeout(() => {
        router.push("/studio");
      }, 1500);
    }
  }, [router]);

  async function onSubmit(e?: React.FormEvent) {
    if (e) e.preventDefault();
    if (!canSubmit) return;

    setLoading(true);
    setError(null);
    try {
      const res = (await apiFetch("/auth/login", {
        method: "POST",
        body: {
          email: email.trim(),
          username: email.trim(),
          password,
          rememberMe
        },
      })) as any;

      const token = res?.access_token || res?.data?.access_token;
      if (!token) {
        throw new Error(res?.message || "Invalid email or password");
      }

      setToken(token);
      setSuccess(true);
      setTimeout(() => {
        router.push("/studio");
      }, 1500);
    } catch (err: any) {
      setError(err?.message || "Invalid email or password");
    } finally {
      setLoading(false);
    }
  }

  async function handleSocialLogin(provider: "google" | "github") {
    setLoading(true);
    setError(null);
    try {
      // Redirect to backend OAuth endpoint
      // The backend should be configured to handle these routes
      window.location.href = `${process.env.NEXT_PUBLIC_API_URL || "http://localhost:3000/api"}/auth/${provider}`;
    } catch (err: any) {
      setError(`Failed to initialize ${provider} login`);
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
        <div className="w-full max-w-md">
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.5 }}
            className="rounded-[2rem] border border-white/10 bg-white/[0.03] p-8 shadow-[0_0_0_1px_rgba(255,255,255,0.06),0_24px_60px_rgba(0,0,0,0.6)] backdrop-blur-3xl relative overflow-hidden"
          >
            {/* Subtle Gradient Glow inside card */}
            <div className="absolute top-0 right-0 w-32 h-32 bg-indigo-500/5 blur-3xl -mr-16 -mt-16" />

            <div className="mb-8 relative z-10 text-center">
              <div className="inline-flex items-center gap-2 rounded-full border border-white/10 bg-white/5 px-3 py-1 text-[10px] font-bold uppercase tracking-widest text-zinc-200">
                <Sparkles size={10} className="text-emerald-400 animate-pulse" />
                GameForge Studio
              </div>
              <h1 className="mt-6 text-4xl font-black tracking-tight text-white italic">
                Studio <span className="text-transparent bg-clip-text bg-gradient-to-r from-indigo-400 to-fuchsia-400">Sign In</span>
              </h1>
              <p className="mt-2 text-sm text-zinc-400 font-medium">
                Continue your creative journey in the metaverse.
              </p>
            </div>

            <AnimatePresence mode="wait">
              {success ? (
                <motion.div
                  key="success"
                  initial={{ opacity: 0, scale: 0.9 }}
                  animate={{ opacity: 1, scale: 1 }}
                  className="py-12 text-center"
                >
                  <div className="relative inline-flex mb-8">
                    <div className="h-20 w-20 rounded-full bg-green-500/10 flex items-center justify-center border border-green-500/20 shadow-[0_0_40px_rgba(34,197,94,0.15)]">
                      <CheckCircle2 size={40} className="text-green-400" />
                    </div>
                  </div>
                  <h2 className="text-2xl font-bold text-white mb-2 italic">Authenticated</h2>
                  <p className="text-zinc-400 text-sm">Synchronizing your workspace...</p>
                </motion.div>
              ) : (
                <form
                  onSubmit={onSubmit}
                  onKeyDown={(e) => {
                    if (e.key === 'Enter' && canSubmit) {
                      onSubmit();
                    }
                  }}
                  className="space-y-5 relative z-10"
                >
                  {/* Social Login - Unified Style */}
                  <div className="grid grid-cols-2 gap-4 mb-8">
                    <button
                      type="button"
                      onClick={() => handleSocialLogin("google")}
                      disabled={loading}
                      className="flex items-center justify-center gap-2 h-11 rounded-xl bg-white/[0.03] border border-white/5 hover:bg-white/[0.06] hover:border-white/10 transition-all duration-300 group disabled:opacity-50"
                    >
                      <Chrome size={16} className="text-zinc-400 group-hover:text-white" />
                      <span className="text-[11px] font-bold uppercase tracking-wider text-zinc-400 group-hover:text-white">Google</span>
                    </button>
                    <button
                      type="button"
                      onClick={() => handleSocialLogin("github")}
                      disabled={loading}
                      className="flex items-center justify-center gap-2 h-11 rounded-xl bg-white/[0.03] border border-white/5 hover:bg-white/[0.06] hover:border-white/10 transition-all duration-300 group disabled:opacity-50"
                    >
                      <Github size={16} className="text-zinc-400 group-hover:text-white" />
                      <span className="text-[11px] font-bold uppercase tracking-wider text-zinc-400 group-hover:text-white">GitHub</span>
                    </button>
                  </div>

                  <div className="relative flex items-center gap-4 mb-6">
                    <div className="h-px bg-white/5 flex-1" />
                    <span className="text-[9px] font-black text-zinc-600 uppercase tracking-[0.2em]">Credentials</span>
                    <div className="h-px bg-white/5 flex-1" />
                  </div>

                  <div className="space-y-4">
                    <div className="group space-y-1.5">
                      <label className="text-[10px] font-bold text-zinc-500 uppercase tracking-widest ml-1 group-focus-within:text-indigo-400 transition-colors">Email or Username</label>
                      <div className="relative">
                        <div className="absolute left-4 top-1/2 -translate-y-1/2 text-zinc-500 group-focus-within:text-indigo-400 transition-colors">
                          <Mail size={16} />
                        </div>
                        <input
                          type="text"
                          value={email}
                          onChange={(e) => setEmail(e.target.value)}
                          className="h-12 w-full rounded-[1rem] border border-white/10 bg-zinc-950/40 pl-11 pr-4 text-sm text-white outline-none ring-0 placeholder:text-zinc-600 focus:border-indigo-400/40 focus:bg-zinc-950/60 transition-all duration-300"
                          placeholder="you@domain.com"
                          required
                        />
                      </div>
                    </div>

                    <div className="group space-y-1.5">
                      <label className="text-[10px] font-bold text-zinc-500 uppercase tracking-widest ml-1 group-focus-within:text-fuchsia-400 transition-colors">Security Password</label>
                      <div className="relative">
                        <div className="absolute left-4 top-1/2 -translate-y-1/2 text-zinc-500 group-focus-within:text-fuchsia-400 transition-colors">
                          <Lock size={16} />
                        </div>
                        <input
                          type="password"
                          value={password}
                          onChange={(e) => setPassword(e.target.value)}
                          className="h-12 w-full rounded-[1rem] border border-white/10 bg-zinc-950/40 pl-11 pr-4 text-sm text-white outline-none ring-0 placeholder:text-zinc-600 focus:border-fuchsia-400/40 focus:bg-zinc-950/60 transition-all duration-300"
                          placeholder="••••••••"
                          required
                        />
                      </div>
                    </div>
                  </div>

                  <div className="flex items-center justify-between px-1 py-2">
                    <label className="flex items-center gap-2 cursor-pointer group">
                      <div className={`w-4 h-4 rounded border flex items-center justify-center transition-all duration-300 ${rememberMe ? 'bg-indigo-500 border-indigo-500' : 'bg-transparent border-white/20'}`}>
                        {rememberMe && <CheckCircle2 size={10} className="text-white" />}
                      </div>
                      <input type="checkbox" className="hidden" checked={rememberMe} onChange={(e) => setRememberMe(e.target.checked)} />
                      <span className="text-[11px] font-bold text-zinc-500 group-hover:text-zinc-300 uppercase tracking-wider">Stay logged in</span>
                    </label>
                    <Link href="/forgot-password" title="Recover Password" className="text-[11px] font-black text-indigo-400/80 hover:text-indigo-300 uppercase tracking-widest">
                      Recovery?
                    </Link>
                  </div>

                  {error && (
                    <motion.div initial={{ opacity: 0, height: 0 }} animate={{ opacity: 1, height: "auto" }} className="flex items-center gap-2 px-4 py-3 rounded-xl bg-red-500/10 border border-red-500/20 text-red-400 text-xs font-medium">
                      <AlertCircle size={14} />
                      {error}
                    </motion.div>
                  )}

                  <button
                    type="submit"
                    disabled={!canSubmit}
                    className="relative h-12 w-full group overflow-hidden rounded-xl transition-all duration-500 disabled:opacity-50"
                  >
                    <div className="absolute inset-0 bg-gradient-to-r from-indigo-600 via-fuchsia-600 to-cyan-500 group-hover:scale-105 transition-transform duration-500" />
                    <div className="relative flex items-center justify-center gap-2 text-xs font-black text-white uppercase tracking-[0.2em]">
                      {loading ? <Loader2 size={16} className="animate-spin" /> : <>Enter Studio <ArrowRight size={16} className="group-hover:translate-x-1 transition-transform" /></>}
                    </div>
                  </button>
                </form>
              )}
            </AnimatePresence>
          </motion.div>

          {/* Footer Links - Refined */}
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ delay: 0.6 }}
            className="mt-8 text-center space-y-6"
          >
            <div className="flex items-center justify-center gap-6">
              <Link href="/signup" className="text-[10px] font-black text-zinc-500 hover:text-white uppercase tracking-widest transition-all group relative">
                Create Account
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

            <div className="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-white/[0.02] border border-white/5 text-[9px] text-zinc-600 font-bold uppercase tracking-[0.2em]">
              <ShieldCheck size={10} className="text-emerald-500/50" />
              Encrypted Connection Verified
            </div>
          </motion.div>
        </div>
      </div>
    </div>
  );
}
