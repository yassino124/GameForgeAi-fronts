"use client";

import { useState, useMemo } from "react";
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
  Rocket,
  ArrowRight,
  CheckCircle2,
  AlertCircle,
  Loader2,
  Eye,
  EyeOff,
  Gamepad2,
  Code2,
} from "lucide-react";
import ForgeLogo from "@/app/_components/ForgeLogo";

// === Background ===
function Orbs() {
  return (
    <div className="pointer-events-none fixed inset-0 z-0 overflow-hidden">
      <motion.div
        animate={{ x: [0, -60, 0], y: [0, 50, 0], scale: [1, 1.2, 1] }}
        transition={{ duration: 22, repeat: Infinity, ease: "easeInOut" }}
        className="absolute -top-[25%] right-[5%] h-[650px] w-[650px] rounded-full bg-blue-700/14 blur-[130px]"
      />
      <motion.div
        animate={{ x: [0, 50, 0], y: [0, -30, 0], scale: [1.1, 1, 1.1] }}
        transition={{
          duration: 18,
          repeat: Infinity,
          ease: "easeInOut",
          delay: 3,
        }}
        className="absolute -bottom-[20%] left-[0%] h-[600px] w-[600px] rounded-full bg-blue-700/15 blur-[120px]"
      />
      <motion.div
        animate={{ x: [0, -30, 0], scale: [1, 1.1, 1] }}
        transition={{
          duration: 25,
          repeat: Infinity,
          ease: "easeInOut",
          delay: 6,
        }}
        className="absolute top-[50%] right-[15%] h-[350px] w-[350px] rounded-full bg-cyan-600/7 blur-[90px]"
      />
      <div
        className="absolute inset-0 opacity-[0.05]"
        style={{
          backgroundImage:
            "linear-gradient(to right,rgba(255,255,255,0.5) 1px,transparent 1px),linear-gradient(to bottom,rgba(255,255,255,0.5) 1px,transparent 1px)",
          backgroundSize: "52px 52px",
        }}
      />
    </div>
  );
}

// === Password Strength ===
function PasswordStrength({ password }: { password: string }) {
  const checks = [
    { label: "8+ chars", ok: password.length >= 8 },
    { label: "Uppercase", ok: /[A-Z]/.test(password) },
    { label: "Number", ok: /\d/.test(password) },
    { label: "Special", ok: /[@$!%*?&]/.test(password) },
  ];
  const score = checks.filter((c) => c.ok).length;
  const colors = [
    "",
    "bg-red-500",
    "bg-orange-500",
    "bg-amber-500",
    "bg-emerald-500",
  ];
  const labels = ["", "Weak", "Fair", "Good", "Strong"];
  if (!password) return null;
  return (
    <div className="mt-2 space-y-2">
      <div className="flex gap-1.5">
        {[1, 2, 3, 4].map((s) => (
          <div
            key={s}
            className={`h-1 flex-1 rounded-full transition-all duration-300 ${score >= s ? colors[score] : "bg-white/[0.07]"}`}
          />
        ))}
      </div>
      <div className="flex items-center justify-between">
        <div className="flex gap-2 flex-wrap">
          {checks.map((c) => (
            <span
              key={c.label}
              className={`text-[9px] font-bold transition-colors ${c.ok ? "text-emerald-400" : "text-zinc-700"}`}
            >
              {c.ok ? "✓" : "○"} {c.label}
            </span>
          ))}
        </div>
        <span
          className={`text-[9px] font-black uppercase tracking-widest ${colors[score]?.replace("bg-", "text-") || "text-zinc-700"}`}
        >
          {labels[score]}
        </span>
      </div>
    </div>
  );
}

export default function SignUpPage() {
  const router = useRouter();
  const [username, setUsername] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [showPass, setShowPass] = useState(false);
  const [showConfirm, setShowConfirm] = useState(false);
  const [role, setRole] = useState<"devl" | "user">("devl");
  const [agreedToTerms, setAgreedToTerms] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState(false);

  const isEmailValid = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
  const isPasswordStrong =
    /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])/.test(password);

  const canSubmit = useMemo(
    () =>
      username.trim().length >= 2 &&
      isEmailValid &&
      password.length >= 8 &&
      isPasswordStrong &&
      password === confirmPassword &&
      agreedToTerms &&
      !loading,
    [
      username,
      email,
      isEmailValid,
      password,
      isPasswordStrong,
      confirmPassword,
      agreedToTerms,
      loading,
    ],
  );

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
      setTimeout(
        () =>
          router.push(
            `/verify-email?email=${encodeURIComponent(email.trim())}`,
          ),
        1500,
      );
    } catch (err: any) {
      setError(err?.message || "Sign up failed. Please try again.");
    } finally {
      setLoading(false);
    }
  }

  const ROLES = [
    {
      id: "devl" as const,
      label: "Developer",
      desc: "Build & ship games",
      icon: Code2,
      color: "blue",
      grad: "from-blue-600/15 to-blue-600/5",
      border: "border-blue-500/40",
      iconColor: "text-blue-400",
      dot: "bg-blue-500",
    },
    {
      id: "user" as const,
      label: "Player",
      desc: "Play & discover",
      icon: Gamepad2,
      color: "sky",
      grad: "from-sky-500/15 to-sky-500/5",
      border: "border-sky-500/40",
      iconColor: "text-sky-400",
      dot: "bg-sky-500",
    },
  ];

  return (
    <div className="min-h-screen bg-[#06060a] font-sans selection:bg-blue-600/30 overflow-hidden">
      <Orbs />

      <div className="relative z-10 w-full min-h-screen flex">
        {/* ── Form panel (left) ── */}
        <div className="w-full lg:w-[55%] xl:w-[52%] flex items-center justify-center px-6 py-12">
          <div className="w-full max-w-[440px]">
            {/* Logo */}
            <div className="mb-8">
              <ForgeLogo size={44} />
            </div>

            {/* Header */}
            <div className="mb-8">
              <motion.div
                initial={{ opacity: 0, y: 8 }}
                animate={{ opacity: 1, y: 0 }}
                className="inline-flex items-center gap-2 rounded-full border border-blue-500/20 bg-blue-600/8 px-3 py-1 text-[9px] font-black uppercase tracking-[0.22em] text-sky-300 mb-4"
              >
                <span className="h-1.5 w-1.5 rounded-full bg-blue-400 shadow-[0_0_6px_rgba(37,99,235,0.9)] animate-pulse" />
                Join Genesis
              </motion.div>
              <motion.h1
                initial={{ opacity: 0, y: 10 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: 0.05 }}
                className="text-[2.1rem] font-black tracking-tight text-white leading-tight"
              >
                Forge Your
                <span className="text-transparent bg-clip-text bg-gradient-to-r from-blue-400 to-sky-300">
                  {" "}
                  Identity
                </span>
              </motion.h1>
              <p className="mt-1.5 text-sm text-zinc-500 font-medium">
                Join thousands of creators building the next generation of
                games.
              </p>
            </div>

            <AnimatePresence mode="wait">
              {success ? (
                <motion.div
                  key="success"
                  initial={{ opacity: 0, scale: 0.93 }}
                  animate={{ opacity: 1, scale: 1 }}
                  className="py-14 text-center"
                >
                  <motion.div
                    initial={{ scale: 0 }}
                    animate={{ scale: 1 }}
                    transition={{ type: "spring", stiffness: 200, damping: 18 }}
                    className="relative inline-flex mb-6"
                  >
                    <div className="h-20 w-20 rounded-full bg-blue-600/10 border border-blue-500/25 flex items-center justify-center shadow-[0_0_40px_rgba(37,99,235,0.18)]">
                      <Rocket size={36} className="text-blue-400" />
                    </div>
                    <motion.div
                      animate={{ scale: [1, 1.4, 1], opacity: [0.4, 0.1, 0.4] }}
                      transition={{ duration: 2, repeat: Infinity }}
                      className="absolute inset-0 rounded-full bg-blue-600/20 blur-xl -z-10"
                    />
                  </motion.div>
                  <h2 className="text-xl font-black text-white mb-2">
                    Account Created!
                  </h2>
                  <p className="text-sm text-zinc-500">
                    Redirecting to verification…
                  </p>
                  <motion.div
                    initial={{ width: "0%" }}
                    animate={{ width: "100%" }}
                    transition={{ duration: 1.4, ease: "linear" }}
                    className="h-0.5 bg-gradient-to-r from-blue-600 to-sky-400 rounded-full mt-8"
                  />
                </motion.div>
              ) : (
                <motion.form
                  key="form"
                  initial={{ opacity: 0 }}
                  animate={{ opacity: 1 }}
                  onSubmit={onSubmit}
                  className="space-y-5"
                >
                  {/* Role selector */}
                  <div className="grid grid-cols-2 gap-3">
                    {ROLES.map((r) => {
                      const Icon = r.icon;
                      const active = role === r.id;
                      return (
                        <button
                          key={r.id}
                          type="button"
                          onClick={() => setRole(r.id)}
                          className={`relative flex items-center gap-3 p-4 rounded-[16px] border transition-all duration-250 text-left overflow-hidden ${
                            active
                              ? `bg-gradient-to-br ${r.grad} ${r.border} shadow-[0_0_20px_rgba(37,99,235,0.1)]`
                              : "bg-white/[0.02] border-white/[0.06] hover:border-white/[0.1] hover:bg-white/[0.04]"
                          }`}
                        >
                          {active && (
                            <div
                              className={`absolute inset-0 bg-gradient-to-br ${r.grad} pointer-events-none`}
                            />
                          )}
                          <div
                            className={`relative z-10 h-9 w-9 rounded-[12px] flex items-center justify-center border transition-all ${active ? `border-${r.color}-500/30 bg-${r.color}-500/15` : "border-white/[0.06] bg-white/[0.03]"}`}
                          >
                            <Icon
                              size={16}
                              className={active ? r.iconColor : "text-zinc-600"}
                            />
                          </div>
                          <div className="relative z-10 min-w-0">
                            <p
                              className={`text-[12px] font-bold ${active ? "text-white" : "text-zinc-500"}`}
                            >
                              {r.label}
                            </p>
                            <p className="text-[10px] text-zinc-700">
                              {r.desc}
                            </p>
                          </div>
                          {active && (
                            <div
                              className={`absolute bottom-0 left-0 right-0 h-[2px] bg-gradient-to-r from-transparent via-${r.dot.replace("bg-", "")} to-transparent`}
                            />
                          )}
                        </button>
                      );
                    })}
                  </div>

                  {/* Fields grid */}
                  <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                    {/* Username */}
                    <div className="group space-y-1.5">
                      <label className="block text-[10px] font-black text-zinc-600 uppercase tracking-[0.22em] ml-0.5 group-focus-within:text-blue-400 transition-colors">
                        Username
                      </label>
                      <div className="relative">
                        <User
                          size={14}
                          className="absolute left-3.5 top-1/2 -translate-y-1/2 text-zinc-600 group-focus-within:text-blue-400 transition-colors pointer-events-none"
                        />
                        <input
                          value={username}
                          onChange={(e) => setUsername(e.target.value)}
                          placeholder="nexus_dev"
                          className={`gf-input h-11 w-full rounded-[14px] pl-10 pr-4 text-sm ${username.length > 0 && username.length < 2 ? "border-red-500/40 focus:border-red-500/60" : ""}`}
                          required
                        />
                      </div>
                      {username.length > 0 && username.length < 2 && (
                        <p className="text-[9px] text-red-400 ml-0.5">
                          Min. 2 characters
                        </p>
                      )}
                    </div>

                    {/* Email */}
                    <div className="group space-y-1.5">
                      <label className="block text-[10px] font-black text-zinc-600 uppercase tracking-[0.22em] ml-0.5 group-focus-within:text-blue-400 transition-colors">
                        Email
                      </label>
                      <div className="relative">
                        <Mail
                          size={14}
                          className="absolute left-3.5 top-1/2 -translate-y-1/2 text-zinc-600 group-focus-within:text-blue-400 transition-colors pointer-events-none"
                        />
                        <input
                          type="email"
                          value={email}
                          onChange={(e) => setEmail(e.target.value)}
                          placeholder="you@domain.com"
                          className={`gf-input h-11 w-full rounded-[14px] pl-10 pr-4 text-sm ${email.length > 0 && !isEmailValid ? "border-red-500/40" : ""}`}
                          required
                        />
                      </div>
                    </div>
                  </div>

                  {/* Password */}
                  <div className="group space-y-1.5">
                    <label className="block text-[10px] font-black text-zinc-600 uppercase tracking-[0.22em] ml-0.5 group-focus-within:text-blue-400 transition-colors">
                      Password
                    </label>
                    <div className="relative">
                      <Lock
                        size={14}
                        className="absolute left-3.5 top-1/2 -translate-y-1/2 text-zinc-600 group-focus-within:text-blue-400 transition-colors pointer-events-none"
                      />
                      <input
                        type={showPass ? "text" : "password"}
                        value={password}
                        onChange={(e) => setPassword(e.target.value)}
                        placeholder="••••••••"
                        className="gf-input h-11 w-full rounded-[14px] pl-10 pr-11 text-sm"
                        required
                      />
                      <button
                        type="button"
                        onClick={() => setShowPass(!showPass)}
                        className="absolute right-3.5 top-1/2 -translate-y-1/2 text-zinc-600 hover:text-zinc-400 transition-colors"
                      >
                        {showPass ? <EyeOff size={14} /> : <Eye size={14} />}
                      </button>
                    </div>
                    <PasswordStrength password={password} />
                  </div>

                  {/* Confirm password */}
                  <div className="group space-y-1.5">
                    <label className="block text-[10px] font-black text-zinc-600 uppercase tracking-[0.22em] ml-0.5 group-focus-within:text-blue-400 transition-colors">
                      Confirm Password
                    </label>
                    <div className="relative">
                      <ShieldCheck
                        size={14}
                        className="absolute left-3.5 top-1/2 -translate-y-1/2 text-zinc-600 group-focus-within:text-blue-400 transition-colors pointer-events-none"
                      />
                      <input
                        type={showConfirm ? "text" : "password"}
                        value={confirmPassword}
                        onChange={(e) => setConfirmPassword(e.target.value)}
                        placeholder="••••••••"
                        className={`gf-input h-11 w-full rounded-[14px] pl-10 pr-11 text-sm ${confirmPassword.length > 0 && password !== confirmPassword ? "border-red-500/40" : confirmPassword.length > 0 && password === confirmPassword ? "border-emerald-500/40" : ""}`}
                        required
                      />
                      <button
                        type="button"
                        onClick={() => setShowConfirm(!showConfirm)}
                        className="absolute right-3.5 top-1/2 -translate-y-1/2 text-zinc-600 hover:text-zinc-400 transition-colors"
                      >
                        {showConfirm ? <EyeOff size={14} /> : <Eye size={14} />}
                      </button>
                    </div>
                    {confirmPassword.length > 0 &&
                      password !== confirmPassword && (
                        <p className="text-[9px] text-red-400 ml-0.5">
                          Passwords don't match
                        </p>
                      )}
                    {confirmPassword.length > 0 &&
                      password === confirmPassword && (
                        <p className="text-[9px] text-emerald-400 ml-0.5 flex items-center gap-1">
                          <CheckCircle2 size={9} /> Match confirmed
                        </p>
                      )}
                  </div>

                  {/* Terms checkbox */}
                  <label className="flex items-start gap-3 cursor-pointer group">
                    <div
                      onClick={() => setAgreedToTerms(!agreedToTerms)}
                      className={`mt-0.5 h-4 w-4 shrink-0 rounded-[5px] border flex items-center justify-center transition-all duration-200 ${
                        agreedToTerms
                          ? "bg-blue-600 border-blue-500 shadow-[0_0_10px_rgba(37,99,235,0.4)]"
                          : "border-white/15 bg-white/[0.02] hover:border-blue-500/40"
                      }`}
                    >
                      {agreedToTerms && (
                        <motion.div
                          initial={{ scale: 0 }}
                          animate={{ scale: 1 }}
                        >
                          <CheckCircle2 size={10} className="text-white" />
                        </motion.div>
                      )}
                    </div>
                    <span className="text-[11px] leading-relaxed text-zinc-600 group-hover:text-zinc-400 transition-colors">
                      I agree to the{" "}
                      <span className="text-blue-400 font-bold cursor-pointer hover:text-sky-300">
                        Terms of Service
                      </span>{" "}
                      and{" "}
                      <span className="text-blue-400 font-bold cursor-pointer hover:text-sky-300">
                        Privacy Policy
                      </span>
                    </span>
                  </label>

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
                    className="relative h-12 w-full overflow-hidden rounded-[14px] disabled:opacity-40 disabled:cursor-not-allowed"
                  >
                    <div className="absolute inset-0 bg-gradient-to-r from-blue-700 via-blue-600 to-sky-500 bg-[length:200%_100%] animate-[gradient_3s_linear_infinite]" />
                    <motion.div
                      animate={{ x: ["-100%", "200%"] }}
                      transition={{
                        duration: 2.5,
                        repeat: Infinity,
                        ease: "linear",
                        repeatDelay: 1.5,
                      }}
                      className="absolute inset-0 bg-gradient-to-r from-transparent via-white/25 to-transparent skew-x-12"
                    />
                    <div className="relative flex items-center justify-center gap-2.5 text-[11px] font-black text-white uppercase tracking-widest">
                      {loading ? (
                        <Loader2 size={16} className="animate-spin" />
                      ) : (
                        <>
                          Create Studio Account <ArrowRight size={15} />
                        </>
                      )}
                    </div>
                  </motion.button>

                  {/* Footer */}
                  <div className="flex items-center justify-center gap-5">
                    <Link
                      href="/signin"
                      className="text-[10px] font-bold text-zinc-600 hover:text-white uppercase tracking-widest transition-colors"
                    >
                      Sign In
                    </Link>
                    <div className="h-3 w-px bg-white/[0.08]" />
                    <Link
                      href="/"
                      className="text-[10px] font-bold text-zinc-600 hover:text-white uppercase tracking-widest transition-colors"
                    >
                      Home
                    </Link>
                    <div className="h-3 w-px bg-white/[0.08]" />
                    <Link
                      href="/login"
                      className="text-[10px] font-bold text-zinc-600 hover:text-white uppercase tracking-widest transition-colors"
                    >
                      Admin
                    </Link>
                  </div>
                </motion.form>
              )}
            </AnimatePresence>
          </div>
        </div>

        {/* ── Right branding panel ── */}
        <div className="hidden lg:flex flex-col lg:w-[45%] xl:w-[48%] relative overflow-hidden">
          <div className="hidden lg:block absolute left-0 top-[10%] bottom-[10%] w-px bg-white/[0.05]" />
          <div className="absolute inset-0 bg-gradient-to-bl from-blue-600/10 via-transparent to-sky-500/6" />

          <div className="relative z-10 flex-1 flex flex-col justify-between p-12 xl:p-16">
            {/* Feature list */}
            <div className="mt-auto" />

            <div className="space-y-8">
              <div>
                <h2 className="text-4xl xl:text-5xl font-black tracking-tight text-white leading-tight">
                  Start building<br />
                  <span className="text-transparent bg-clip-text bg-gradient-to-r from-blue-400 to-sky-300">
                    in seconds.
                  </span>
                </h2>
                <p className="text-zinc-500 font-medium mt-3 max-w-sm leading-relaxed">
                  No experience required. Describe your game and our neural
                  engine builds it for you.
                </p>
              </div>

              {/* Feature cards */}
              <div className="space-y-3">
                {[
                  { emoji: "⚡", title: "AI-powered generation", desc: "Full game from a single prompt" },
                  { emoji: "🎮", title: "5+ export platforms", desc: "WebGL, iOS, Android, PC, Mac" },
                  { emoji: "🧠", title: "Neural coaching", desc: "Get smart suggestions as you build" },
                  { emoji: "🌐", title: "Community arcade", desc: "Publish and share instantly" },
                ].map((f, i) => (
                  <motion.div
                    key={f.title}
                    initial={{ opacity: 0, x: 20 }}
                    animate={{ opacity: 1, x: 0 }}
                    transition={{ delay: 0.1 + i * 0.08 }}
                    className="flex items-center gap-4 p-4 rounded-[16px] border border-white/[0.04] bg-white/[0.02] hover:bg-white/[0.04] transition-colors group"
                  >
                    <div className="h-10 w-10 rounded-[12px] bg-white/[0.04] border border-white/[0.06] flex items-center justify-center text-lg shrink-0 group-hover:scale-110 transition-transform">
                      {f.emoji}
                    </div>
                    <div>
                      <p className="text-[13px] font-bold text-white leading-tight">{f.title}</p>
                      <p className="text-[11px] text-zinc-600 font-medium mt-0.5">{f.desc}</p>
                    </div>
                  </motion.div>
                ))}
              </div>
            </div>

            {/* Social proof */}
            <div className="flex items-center gap-4">
              <div className="flex -space-x-2">
                {["#2563eb", "#0ea5e9", "#10b981", "#f59e0b", "#8b5cf6"].map(
                  (c, i) => (
                    <div
                      key={i}
                      className="h-8 w-8 rounded-full border-2 border-[#06060a] flex items-center justify-center text-[10px] font-black text-white"
                      style={{ backgroundColor: `${c}40`, zIndex: 5 - i }}
                    >
                      {String.fromCharCode(65 + i * 3)}
                    </div>
                  ),
                )}
              </div>
              <div>
                <p className="text-[12px] font-bold text-white">12,400+ creators</p>
                <p className="text-[10px] text-zinc-600">already building with GameForge</p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
