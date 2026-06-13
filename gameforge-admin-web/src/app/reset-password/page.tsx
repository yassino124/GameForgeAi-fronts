"use client";

import { useState, Suspense } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { apiFetch } from "@/lib/api";

function ResetPasswordContent() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const token = searchParams.get("token") || "";
  
  const [password, setPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState(false);

  const strongPasswordOk = /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]/.test(
    password,
  );

  const errorLines = (error || "")
    .split(/,\s*/g)
    .map((s) => s.trim())
    .filter(Boolean);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    const cleanPassword = password.trim();
    const cleanConfirm = confirmPassword.trim();
    
    if (cleanPassword.length < 8) {
      setError("Password must be at least 8 characters long");
      return;
    }
    if (!/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]/.test(cleanPassword)) {
      setError(
        "Password must contain at least one uppercase letter, one lowercase letter, one number and one special character",
      );
      return;
    }
    if (cleanPassword !== cleanConfirm) {
      setError("Passwords do not match");
      return;
    }
    if (!token) {
      setError("Invalid or missing reset token");
      return;
    }
    
    setLoading(true);
    setError(null);
    try {
      await apiFetch("/auth/reset-password", {
        method: "POST",
        body: { 
          token,
          newPassword: cleanPassword 
        },
      });
      setSuccess(true);
    } catch (err: any) {
      setError(err?.message || "Failed to reset password");
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="gf-panel-strong w-full rounded-3xl p-6 sm:p-8 relative z-10 border border-white/5 backdrop-blur-3xl bg-zinc-900/20 shadow-2xl">
      <div className="flex items-center justify-between mb-10">
        <div>
          <p className="text-[10px] text-blue-400 font-bold tracking-[0.2em] uppercase mb-1">Security</p>
          <h1 className="text-3xl font-bold tracking-tight text-white">Reset Password</h1>
        </div>
        <div className="h-14 w-14 rounded-2xl bg-gradient-to-br from-blue-500/20 via-cyan-500/10 to-transparent flex items-center justify-center text-3xl shadow-inner border border-white/10">
          🛡️
        </div>
      </div>

      {!success ? (
        <form onSubmit={onSubmit} className="space-y-8">
          <p className="text-sm text-zinc-400 leading-relaxed">
            Choose a secure password. We recommend a mix of letters, numbers and symbols.
          </p>

          <div className="space-y-5">
            <div className="space-y-2">
              <label className="block text-xs font-bold text-zinc-500 uppercase tracking-wider ml-1">New Password</label>
              <input
                className="gf-input w-full rounded-2xl px-5 py-4 text-sm bg-black/40 border-white/5 focus:border-blue-500/50 focus:bg-black/60 transition-all duration-300 outline-none placeholder:text-zinc-700"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="••••••••"
                type="password"
                required
                autoFocus
              />
            </div>

            <div className="space-y-2">
              <label className="block text-xs font-bold text-zinc-500 uppercase tracking-wider ml-1">Confirm Password</label>
              <input
                className="gf-input w-full rounded-2xl px-5 py-4 text-sm bg-black/40 border-white/5 focus:border-blue-500/50 focus:bg-black/60 transition-all duration-300 outline-none placeholder:text-zinc-700"
                value={confirmPassword}
                onChange={(e) => setConfirmPassword(e.target.value)}
                placeholder="••••••••"
                type="password"
                required
              />
            </div>
          </div>

          {!token && (
            <div className="rounded-2xl border border-amber-500/20 bg-amber-500/5 px-5 py-4 text-xs text-amber-200/80 leading-relaxed border-dashed">
              ⚠️ No reset token found. Please make sure you clicked the link from your email correctly.
            </div>
          )}

          {error ? (
            <div className="rounded-2xl border border-red-500/20 bg-red-500/10 px-5 py-4 text-sm text-red-300 animate-in fade-in slide-in-from-top-2 duration-300">
              {errorLines.length > 1 ? (
                <div className="space-y-1">
                  {errorLines.map((line, idx) => (
                    <div key={idx}>{line}</div>
                  ))}
                </div>
              ) : (
                error
              )}
            </div>
          ) : null}

          <button
            disabled={!strongPasswordOk || password.length < 8 || password !== confirmPassword || loading || !token}
            className="w-full rounded-2xl bg-gradient-to-r from-blue-600 to-cyan-600 py-4.5 text-sm font-bold text-white transition-all duration-300 shadow-xl shadow-blue-500/20 hover:shadow-blue-500/40 hover:scale-[1.01] active:scale-[0.99] disabled:opacity-30 disabled:hover:scale-100 disabled:shadow-none"
            type="submit"
          >
            {loading ? (
              <div className="flex items-center justify-center gap-3">
                <div className="h-5 w-5 border-2 border-white/20 border-t-white rounded-full animate-spin" />
                Updating Security...
              </div>
            ) : (
              "Update Password"
            )}
          </button>
        </form>
      ) : (
        <div className="text-center py-6 animate-in zoom-in duration-500">
          <div className="h-20 w-20 rounded-full bg-green-500/10 flex items-center justify-center text-4xl mx-auto mb-8 border border-green-500/20 shadow-2xl shadow-green-500/10">
            ✨
          </div>
          <h2 className="text-2xl font-bold text-white mb-3">Security Updated</h2>
          <p className="text-sm text-zinc-400 leading-relaxed mb-10 px-4">
            Your password has been changed successfully. You can now access your account with your new credentials.
          </p>
          <button
            onClick={() => router.push("/signin")}
            className="w-full rounded-2xl bg-white text-black py-4.5 text-sm font-bold hover:bg-zinc-200 transition-all duration-300 shadow-xl shadow-white/5 active:scale-[0.98]"
          >
            Sign in to Studio
          </button>
        </div>
      )}
    </div>
  );
}

export default function ResetPasswordPage() {
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
        <Suspense fallback={
          <div className="gf-panel-strong w-full rounded-3xl p-12 text-center">
            <div className="h-8 w-8 border-2 border-blue-500/30 border-t-blue-500 rounded-full animate-spin mx-auto" />
          </div>
        }>
          <ResetPasswordContent />
        </Suspense>
      </div>
    </div>
  );
}
