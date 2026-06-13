"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { apiFetch } from "@/lib/api";

export default function ForgotPasswordPage() {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState(false);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (email.trim().length < 4) return;
    
    setLoading(true);
    setError(null);
    try {
      await apiFetch("/auth/forgot-password", {
        method: "POST",
        body: { email: email.trim() },
      });
      setSuccess(true);
    } catch (err: any) {
      setError(err?.message || "Failed to send reset link");
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="gf-app min-h-screen text-white bg-[#050505] flex items-center justify-center relative overflow-hidden">
      {/* Background Effects */}
      <div className="pointer-events-none absolute inset-0">
        <div className="gf-grid absolute inset-0 opacity-20" />
        <div className="gf-noise absolute inset-0 opacity-[0.03]" />
        <div className="absolute top-[-20%] left-[-10%] w-[60%] h-[60%] bg-blue-500/10 rounded-full blur-[120px] animate-pulse" />
        <div className="absolute bottom-[-20%] right-[-10%] w-[60%] h-[60%] bg-cyan-500/10 rounded-full blur-[120px] animate-pulse" />
      </div>

      <div className="relative mx-auto w-full max-w-lg px-6 py-12">
        <div className="gf-panel-strong w-full rounded-3xl p-6 sm:p-8 relative z-10 border border-white/5 backdrop-blur-3xl bg-zinc-900/20 shadow-2xl">
          <div className="flex items-center justify-between mb-8">
            <div>
              <p className="text-xs text-zinc-500 font-medium tracking-wider uppercase">GameForge</p>
              <h1 className="mt-1 text-2xl font-bold tracking-tight text-white">Reset Password</h1>
            </div>
            <div className="h-12 w-12 rounded-2xl bg-gradient-to-br from-blue-500/20 to-cyan-500/20 flex items-center justify-center text-2xl shadow-lg border border-white/10">
              🔑
            </div>
          </div>

          {!success ? (
            <form onSubmit={onSubmit} className="space-y-6">
              <p className="text-sm text-zinc-400 leading-relaxed">
                Enter your email address and we'll send you a link to reset your password.
              </p>

              <div className="space-y-2">
                <label className="block text-xs font-semibold text-zinc-400 ml-1">Email Address</label>
                <input
                  className="gf-input w-full rounded-2xl px-4 py-3.5 text-sm bg-black/40 border-white/10 focus:border-blue-500/50 focus:ring-1 focus:ring-blue-500/50 transition-all duration-300 outline-none"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  placeholder="you@domain.com"
                  type="email"
                  required
                  autoFocus
                />
              </div>

              {error ? (
                <div className="rounded-2xl border border-red-500/20 bg-red-500/10 px-4 py-3 text-sm text-red-300 animate-in fade-in slide-in-from-top-1">
                  {error}
                </div>
              ) : null}

              <button
                disabled={email.trim().length < 4 || loading}
                className="w-full rounded-2xl bg-gradient-to-r from-blue-500 to-cyan-500 py-4 text-sm font-bold text-white transition-all duration-300 shadow-lg shadow-blue-500/20 hover:shadow-blue-500/40 hover:scale-[1.02] active:scale-[0.98] disabled:opacity-50 disabled:hover:scale-100"
                type="submit"
              >
                {loading ? (
                  <div className="flex items-center justify-center gap-2">
                    <div className="h-4 w-4 border-2 border-white/30 border-t-white rounded-full animate-spin" />
                    Sending Link...
                  </div>
                ) : (
                  "Send Reset Link"
                )}
              </button>
            </form>
          ) : (
            <div className="text-center py-4 animate-in zoom-in duration-300">
              <div className="h-16 w-16 rounded-full bg-green-500/20 flex items-center justify-center text-3xl mx-auto mb-6 border border-green-500/30">
                ✅
              </div>
              <h2 className="text-xl font-bold text-white mb-2">Email Sent!</h2>
              <p className="text-sm text-zinc-400 leading-relaxed mb-8">
                Check your inbox at <span className="text-blue-400 font-medium">{email}</span> for instructions to reset your password.
              </p>
              <button
                onClick={() => router.push("/signin")}
                className="text-sm font-semibold text-blue-400 hover:text-blue-300 transition-colors"
              >
                Return to sign in
              </button>
            </div>
          )}

          <div className="mt-8 pt-6 border-t border-white/5 flex items-center justify-between">
            <button
              onClick={() => router.back()}
              className="text-xs text-zinc-500 hover:text-zinc-300 transition-colors flex items-center gap-1.5"
            >
              <span>←</span> Go back
            </button>
            <a href="/signin" className="text-xs text-zinc-500 hover:text-blue-400 transition-colors">
              Sign in instead
            </a>
          </div>
        </div>
      </div>
    </div>
  );
}
