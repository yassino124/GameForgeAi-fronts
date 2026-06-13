"use client";

import { useState, useEffect } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { apiFetch } from "@/lib/api";
import { setUserToken as setToken } from "@/lib/userAuth";
import { motion, AnimatePresence } from "framer-motion";
import {
  Mail, Lock, ArrowRight, Loader2, AlertCircle,
  CheckCircle2, Sparkles, ShieldCheck, Eye, EyeOff
} from "lucide-react";
import ForgeLogo from "@/app/_components/ForgeLogo";

// Animated background orbs
function Orbs() {
  return (
    <div className="pointer-events-none fixed inset-0 z-0 overflow-hidden">
      <motion.div
        animate={{ x: [0, 60, 0], y: [0, -40, 0], scale: [1, 1.15, 1] }}
        transition={{ duration: 20, repeat: Infinity, ease: "easeInOut" }}
        className="absolute -top-[30%] left-[10%] h-[700px] w-[700px] rounded-full bg-blue-700/18 blur-[140px]"
      />
      <motion.div
        animate={{ x: [0, -50, 0], y: [0, 60, 0], scale: [1.1, 1, 1.1] }}
        transition={{ duration: 24, repeat: Infinity, ease: "easeInOut", delay: 4 }}
        className="absolute -bottom-[20%] right-[5%] h-[600px] w-[600px] rounded-full bg-cyan-600/12 blur-[120px]"
      />
      <motion.div
        animate={{ x: [0, 40, 0], scale: [1, 1.08, 1] }}
        transition={{ duration: 18, repeat: Infinity, ease: "easeInOut", delay: 8 }}
        className="absolute top-[40%] -left-[10%] h-[400px] w-[400px] rounded-full bg-cyan-600/8 blur-[100px]"
      />
      {/* Fine grid */}
      <div
        className="absolute inset-0 opacity-[0.06]"
        style={{
          backgroundImage: "linear-gradient(to right,rgba(255,255,255,0.5) 1px,transparent 1px),linear-gradient(to bottom,rgba(255,255,255,0.5) 1px,transparent 1px)",
          backgroundSize: "52px 52px",
        }}
      />
    </div>
  );
}

// Floating particle dots
const PARTICLES = Array.from({ length: 18 }, (_, i) => ({
  left: `${(i * 67 + 13) % 100}%`,
  top: `${(i * 53 + 7) % 100}%`,
  dur: 4 + (i % 5),
  delay: i * 0.4,
  size: (i % 3) + 1,
}));

export default function SigninPage() {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [showPass, setShowPass] = useState(false);
  const [rememberMe, setRememberMe] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState(false);

  const canSubmit = email.length > 0 && password.length > 0 && !loading;

  useEffect(() => {
    const params = new URLSearchParams(window.location.search);
    const token = params.get("token");
    if (token) {
      setToken(token);
      setSuccess(true);
      window.history.replaceState({}, document.title, window.location.pathname);
      setTimeout(() => router.push("/studio"), 1500);
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
        body: { email: email.trim(), username: email.trim(), password, rememberMe },
      })) as any;
      const token = res?.access_token || res?.data?.access_token;
      if (!token) throw new Error(res?.message || "Invalid credentials");
      setToken(token);
      setSuccess(true);
      setTimeout(() => router.push("/studio"), 1500);
    } catch (err: any) {
      setError(err?.message || "Invalid email or password");
    } finally {
      setLoading(false);
    }
  }

  async function handleSocial(provider: "google" | "github") {
    setLoading(true);
    window.location.href = `${process.env.NEXT_PUBLIC_API_URL || "http://localhost:3000/api"}/auth/${provider}`;
  }

  return (
    <div className="min-h-screen bg-[#06060a] font-sans selection:bg-blue-600/30 flex items-center justify-center relative overflow-hidden">
      <Orbs />

      {/* Floating particles */}
      <div className="pointer-events-none fixed inset-0 z-0">
        {PARTICLES.map((p, i) => (
          <motion.div
            key={i}
            style={{ left: p.left, top: p.top, width: p.size + 1, height: p.size + 1 }}
            animate={{ y: [0, -20, 0], opacity: [0.15, 0.5, 0.15] }}
            transition={{ duration: p.dur, repeat: Infinity, ease: "easeInOut", delay: p.delay }}
            className="absolute rounded-full bg-blue-400"
          />
        ))}
      </div>

      {/* Split layout */}
      <div className="relative z-10 w-full min-h-screen flex">
        {/* ── Left panel: branding ── */}
        <div className="hidden lg:flex flex-col lg:w-[55%] xl:w-[58%] relative overflow-hidden">
          {/* Radial glow behind illustration */}
          <div className="absolute inset-0 bg-gradient-to-br from-blue-600/10 via-sky-500/5 to-transparent" />

          <div className="relative z-10 flex-1 flex flex-col justify-between p-12 xl:p-16">
            {/* Logo */}
            <ForgeLogo size={52} />

            {/* Central visual */}
            <div className="flex flex-col items-center gap-12">
              {/* Orbiting rings visual */}
              <div className="relative h-72 w-72 flex items-center justify-center">
                {/* Outer ring */}
                <motion.div
                  animate={{ rotate: 360 }}
                  transition={{ duration: 30, repeat: Infinity, ease: "linear" }}
                  className="absolute inset-0 rounded-full"
                  style={{
                    background: "conic-gradient(from 0deg, rgba(37,99,235,0.35), rgba(14,165,233,0.25), rgba(34,211,238,0.2), rgba(37,99,235,0.35))",
                    mask: "radial-gradient(transparent 44%, black 45%, black 46%, transparent 47%)",
                  }}
                />
                {/* Inner ring */}
                <motion.div
                  animate={{ rotate: -360 }}
                  transition={{ duration: 20, repeat: Infinity, ease: "linear" }}
                  className="absolute inset-8 rounded-full"
                  style={{
                    background: "conic-gradient(from 90deg, rgba(14,165,233,0.25), rgba(37,99,235,0.35), rgba(34,211,238,0.2), rgba(14,165,233,0.25))",
                    mask: "radial-gradient(transparent 60%, black 61%, black 62%, transparent 63%)",
                  }}
                />
                {/* Inner glow ring */}
                <motion.div
                  animate={{ rotate: 360 }}
                  transition={{ duration: 14, repeat: Infinity, ease: "linear" }}
                  className="absolute inset-16 rounded-full"
                  style={{
                    background: "conic-gradient(from 200deg, rgba(34,211,238,0.3), rgba(37,99,235,0.2), rgba(34,211,238,0.3))",
                    mask: "radial-gradient(transparent 70%, black 71%, black 72%, transparent 73%)",
                  }}
                />
                {/* Center logo */}
                <motion.div
                  animate={{ y: [0, -6, 0], scale: [1, 1.04, 1] }}
                  transition={{ duration: 4, repeat: Infinity, ease: "easeInOut" }}
                  className="relative z-10 h-28 w-28 rounded-[32px] bg-gradient-to-br from-[#181828] to-[#0a0a14] border border-white/10 flex items-center justify-center shadow-[0_0_60px_rgba(37,99,235,0.25),inset_0_1px_0_rgba(255,255,255,0.06)]"
                >
                  <ForgeLogo iconOnly size={60} className="drop-shadow-[0_0_20px_rgba(37,99,235,0.6)]" />
                </motion.div>

                {/* Orbit dots */}
                {[0, 72, 144, 216, 288].map((deg, i) => (
                  <motion.div
                    key={deg}
                    animate={{ opacity: [0.3, 1, 0.3], scale: [0.8, 1.3, 0.8] }}
                    transition={{ duration: 2.5 + i * 0.3, repeat: Infinity, ease: "easeInOut", delay: i * 0.6 }}
                    className="absolute h-2 w-2 rounded-full bg-blue-400 shadow-[0_0_8px_rgba(37,99,235,0.9)]"
                    style={{
                      top: `calc(50% + ${(Math.sin((deg * Math.PI) / 180) * 130).toFixed(2)}px)`,
                      left: `calc(50% + ${(Math.cos((deg * Math.PI) / 180) * 130).toFixed(2)}px)`,
                      transform: "translate(-50%,-50%)",
                    }}
                  />
                ))}
              </div>

              {/* Text under visual */}
              <div className="text-center space-y-4">
                <h2 className="text-4xl xl:text-5xl font-black tracking-tight text-white leading-tight">
                  Create Games<br />
                  <span className="text-transparent bg-clip-text bg-gradient-to-r from-blue-400 via-sky-300 to-cyan-400">
                    with AI.
                  </span>
                </h2>
                <p className="text-zinc-500 font-medium max-w-xs mx-auto leading-relaxed">
                  Build and ship high-performance games in minutes, powered by neural generation.
                </p>
              </div>
            </div>

            {/* Stat pills */}
            <div className="flex items-center gap-4 justify-center">
              {[
                { label: "Avg build time", value: "< 3 min" },
                { label: "Platforms", value: "5+" },
                { label: "AI-powered", value: "100%" },
              ].map((s) => (
                <div key={s.label} className="flex flex-col items-center gap-0.5 px-4 py-2.5 rounded-[14px] border border-white/[0.05] bg-white/[0.02]">
                  <span className="text-[13px] font-black text-sky-300">{s.value}</span>
                  <span className="text-[9px] font-bold text-zinc-600 uppercase tracking-widest">{s.label}</span>
                </div>
              ))}
            </div>
          </div>
        </div>

        {/* ── Right panel: form ── */}
        <div className="w-full lg:w-[45%] xl:w-[42%] flex items-center justify-center px-6 py-14 relative bg-[#06060a]/80">
          {/* Subtle divider line on desktop */}
          <div className="hidden lg:block absolute left-0 top-[10%] bottom-[10%] w-px bg-white/[0.06]" />

          <div className="w-full max-w-[420px]">
            {/* Mobile logo */}
            <div className="flex justify-center mb-8 lg:hidden">
              <ForgeLogo size={48} />
            </div>

            <motion.div
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.6, ease: [0.16, 1, 0.3, 1] }}
            >
              {/* Header */}
              <div className="mb-8">
                <motion.div
                  initial={{ opacity: 0, scale: 0.9 }}
                  animate={{ opacity: 1, scale: 1 }}
                  transition={{ delay: 0.1 }}
                  className="inline-flex items-center gap-2 rounded-full border border-blue-500/20 bg-blue-600/8 px-3 py-1 text-[9px] font-black uppercase tracking-[0.22em] text-sky-300 mb-5"
                >
                  <span className="h-1.5 w-1.5 rounded-full bg-blue-400 shadow-[0_0_6px_rgba(37,99,235,0.9)] animate-pulse" />
                  Studio Portal
                </motion.div>
                <h1 className="text-[2rem] font-black tracking-tight text-white leading-tight">
                  Welcome back
                </h1>
                <p className="mt-1.5 text-sm text-zinc-500 font-medium">
                  Sign in to continue building your next game.
                </p>
              </div>

              <AnimatePresence mode="wait">
                {success ? (
                  <motion.div
                    key="success"
                    initial={{ opacity: 0, scale: 0.92 }}
                    animate={{ opacity: 1, scale: 1 }}
                    className="py-14 text-center"
                  >
                    <div className="relative inline-flex mb-6">
                      <motion.div
                        initial={{ scale: 0 }}
                        animate={{ scale: 1 }}
                        transition={{ type: "spring", stiffness: 200, damping: 18 }}
                        className="h-20 w-20 rounded-full bg-emerald-500/10 border border-emerald-500/25 flex items-center justify-center shadow-[0_0_40px_rgba(16,185,129,0.18)]"
                      >
                        <CheckCircle2 size={36} className="text-emerald-400" />
                      </motion.div>
                    </div>
                    <h2 className="text-xl font-black text-white mb-2">Authenticated!</h2>
                    <p className="text-sm text-zinc-500">Launching your studio…</p>
                    <motion.div
                      initial={{ width: "0%" }}
                      animate={{ width: "100%" }}
                      transition={{ duration: 1.4, ease: "linear" }}
                      className="h-0.5 bg-gradient-to-r from-emerald-500 to-blue-500 rounded-full mt-8"
                    />
                  </motion.div>
                ) : (
                  <motion.form
                    key="form"
                    onSubmit={onSubmit}
                    initial={{ opacity: 0 }}
                    animate={{ opacity: 1 }}
                    className="space-y-5"
                  >
                    {/* Social login */}
                    <div className="grid grid-cols-2 gap-3">
                      {[
                        { provider: "google" as const, label: "Google", icon: (
                          <svg className="h-4 w-4" viewBox="0 0 24 24"><path d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z" fill="#4285F4"/><path d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" fill="#34A853"/><path d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z" fill="#FBBC05"/><path d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z" fill="#EA4335"/></svg>
                        )},
                        { provider: "github" as const, label: "GitHub", icon: (
                          <svg className="h-4 w-4 fill-current text-white" viewBox="0 0 24 24"><path d="M12 0C5.37 0 0 5.37 0 12c0 5.31 3.435 9.795 8.205 11.385.6.105.825-.255.825-.57 0-.285-.015-1.23-.015-2.235-3.015.555-3.795-.735-4.035-1.41-.135-.345-.72-1.41-1.23-1.695-.42-.225-1.02-.78-.015-.795.945-.015 1.62.87 1.845 1.23 1.08 1.815 2.805 1.305 3.495.99.105-.78.42-1.305.765-1.605-2.67-.3-5.46-1.335-5.46-5.925 0-1.305.465-2.385 1.23-3.225-.12-.3-.54-1.53.12-3.18 0 0 1.005-.315 3.3 1.23.96-.27 1.98-.405 3-.405s2.04.135 3 .405c2.295-1.56 3.3-1.23 3.3-1.23.66 1.65.24 2.88.12 3.18.765.84 1.23 1.905 1.23 3.225 0 4.605-2.805 5.625-5.475 5.925.435.375.81 1.095.81 2.22 0 1.605-.015 2.895-.015 3.3 0 .315.225.69.825.57A12.02 12.02 0 0 0 24 12c0-6.63-5.37-12-12-12z" /></svg>
                        )},
                      ].map(({ provider, label, icon }) => (
                        <button
                          key={provider}
                          type="button"
                          onClick={() => handleSocial(provider)}
                          disabled={loading}
                          className="flex items-center justify-center gap-2.5 h-11 rounded-[14px] bg-white/[0.03] border border-white/[0.07] hover:bg-white/[0.07] hover:border-white/[0.12] transition-all duration-250 disabled:opacity-50"
                        >
                          {icon}
                          <span className="text-[11px] font-bold text-zinc-400 tracking-wide">{label}</span>
                        </button>
                      ))}
                    </div>

                    {/* Divider */}
                    <div className="flex items-center gap-3">
                      <div className="flex-1 h-px bg-white/[0.05]" />
                      <span className="text-[9px] font-black text-zinc-700 uppercase tracking-[0.2em]">or</span>
                      <div className="flex-1 h-px bg-white/[0.05]" />
                    </div>

                    {/* Email */}
                    <div className="group space-y-1.5">
                      <label className="block text-[10px] font-black text-zinc-600 uppercase tracking-[0.22em] group-focus-within:text-blue-400 transition-colors ml-0.5">
                        Email or Username
                      </label>
                      <div className="relative">
                        <Mail size={15} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-zinc-600 group-focus-within:text-blue-400 transition-colors pointer-events-none" />
                        <input
                          type="text"
                          value={email}
                          onChange={(e) => setEmail(e.target.value)}
                          className="gf-input h-12 w-full rounded-[14px] pl-10 pr-4 text-sm"
                          placeholder="you@domain.com"
                          required
                          autoComplete="email"
                        />
                      </div>
                    </div>

                    {/* Password */}
                    <div className="group space-y-1.5">
                      <label className="block text-[10px] font-black text-zinc-600 uppercase tracking-[0.22em] group-focus-within:text-cyan-400 transition-colors ml-0.5">
                        Password
                      </label>
                      <div className="relative">
                        <Lock size={15} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-zinc-600 group-focus-within:text-cyan-400 transition-colors pointer-events-none" />
                        <input
                          type={showPass ? "text" : "password"}
                          value={password}
                          onChange={(e) => setPassword(e.target.value)}
                          className="gf-input h-12 w-full rounded-[14px] pl-10 pr-11 text-sm"
                          placeholder="••••••••"
                          required
                          autoComplete="current-password"
                        />
                        <button
                          type="button"
                          onClick={() => setShowPass(!showPass)}
                          className="absolute right-3.5 top-1/2 -translate-y-1/2 text-zinc-600 hover:text-zinc-400 transition-colors"
                        >
                          {showPass ? <EyeOff size={15} /> : <Eye size={15} />}
                        </button>
                      </div>
                    </div>

                    {/* Remember + Forgot */}
                    <div className="flex items-center justify-between px-0.5">
                      <label className="flex items-center gap-2.5 cursor-pointer group">
                        <div
                          onClick={() => setRememberMe(!rememberMe)}
                          className={`h-4 w-4 rounded-[5px] border flex items-center justify-center transition-all duration-200 cursor-pointer ${
                            rememberMe ? "bg-blue-600 border-blue-500 shadow-[0_0_10px_rgba(37,99,235,0.4)]" : "border-white/15 bg-white/[0.02] hover:border-blue-500/40"
                          }`}
                        >
                          {rememberMe && (
                            <motion.div initial={{ scale: 0 }} animate={{ scale: 1 }}>
                              <CheckCircle2 size={10} className="text-white" />
                            </motion.div>
                          )}
                        </div>
                        <span className="text-[11px] font-semibold text-zinc-600 group-hover:text-zinc-400 transition-colors">
                          Stay signed in
                        </span>
                      </label>
                      <Link
                        href="/forgot-password"
                        className="text-[11px] font-bold text-blue-400/70 hover:text-sky-300 transition-colors"
                      >
                        Forgot password?
                      </Link>
                    </div>

                    {/* Error */}
                    <AnimatePresence>
                      {error && (
                        <motion.div
                          initial={{ opacity: 0, height: 0, y: -5 }}
                          animate={{ opacity: 1, height: "auto", y: 0 }}
                          exit={{ opacity: 0, height: 0 }}
                          className="flex items-center gap-2.5 px-4 py-3 rounded-[14px] bg-red-500/8 border border-red-500/18 text-red-400 text-xs font-medium"
                        >
                          <AlertCircle size={13} className="shrink-0" />
                          {error}
                        </motion.div>
                      )}
                    </AnimatePresence>

                    {/* Submit */}
                    <motion.button
                      type="submit"
                      disabled={!canSubmit}
                      whileHover={canSubmit ? { scale: 1.02 } : {}}
                      whileTap={canSubmit ? { scale: 0.98 } : {}}
                      className="relative h-12 w-full overflow-hidden rounded-[14px] disabled:opacity-50 disabled:cursor-not-allowed"
                    >
                      <div className="absolute inset-0 bg-gradient-to-r from-blue-700 via-blue-600 to-sky-500" />
                      {/* Shimmer */}
                      <motion.div
                        animate={{ x: ["-100%", "200%"] }}
                        transition={{ duration: 3, repeat: Infinity, ease: "linear", repeatDelay: 1 }}
                        className="absolute inset-0 bg-gradient-to-r from-transparent via-white/20 to-transparent skew-x-12"
                      />
                      <div className="relative flex items-center justify-center gap-2.5 text-[11px] font-black text-white uppercase tracking-widest">
                        {loading ? (
                          <Loader2 size={16} className="animate-spin" />
                        ) : (
                          <>
                            Enter Studio
                            <ArrowRight size={15} className="group-hover:translate-x-1 transition-transform" />
                          </>
                        )}
                      </div>
                    </motion.button>

                    {/* Footer links */}
                    <div className="flex items-center justify-center gap-5 pt-2">
                      <Link href="/signup" className="text-[10px] font-bold text-zinc-600 hover:text-white uppercase tracking-widest transition-colors">
                        Create Account
                      </Link>
                      <div className="h-3 w-px bg-white/[0.08]" />
                      <Link href="/" className="text-[10px] font-bold text-zinc-600 hover:text-white uppercase tracking-widest transition-colors">
                        Home
                      </Link>
                      <div className="h-3 w-px bg-white/[0.08]" />
                      <Link href="/login" className="text-[10px] font-bold text-zinc-600 hover:text-white uppercase tracking-widest transition-colors">
                        Admin
                      </Link>
                    </div>
                  </motion.form>
                )}
              </AnimatePresence>

              {/* Security badge */}
              <div className="flex justify-center mt-6">
                <div className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full border border-white/[0.05] bg-white/[0.02] text-[9px] font-bold text-zinc-700 uppercase tracking-widest">
                  <ShieldCheck size={10} className="text-emerald-500/50" />
                  End-to-end encrypted
                </div>
              </div>
            </motion.div>
          </div>
        </div>
      </div>
    </div>
  );
}
