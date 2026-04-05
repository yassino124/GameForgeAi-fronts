"use client";

import { useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { apiFetch } from "@/lib/api";
import { setToken } from "@/lib/auth";

type LoginResponse = {
  access_token: string;
  refresh_token?: string;
  user?: {
    id?: string;
    email?: string;
    username?: string;
    role?: string;
    subscription?: string;
  };
};

export default function LoginPage() {
  const router = useRouter();
  const [emailOrUsername, setEmailOrUsername] = useState("");
  const [password, setPassword] = useState("");
  const [rememberMe, setRememberMe] = useState(true);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const canSubmit = useMemo(() => {
    return emailOrUsername.trim().length >= 2 && password.length >= 4 && !loading;
  }, [emailOrUsername, password, loading]);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setLoading(true);
    try {
      // Backend expects LoginDto; to keep compatible we send both email and username fields.
      const data = await apiFetch<LoginResponse>("/auth/login", {
        method: "POST",
        body: {
          email: emailOrUsername.trim(),
          username: emailOrUsername.trim(),
          password,
          rememberMe,
        },
      });

      const token = (data as any)?.access_token as string | undefined;
      if (!token) throw new Error("Missing access token");

      const role = (data as any)?.user?.role?.toString?.()?.toLowerCase?.() ?? "";
      if (role !== "admin") {
        throw new Error("Forbidden: admin access required");
      }

      setToken(token);
      router.replace("/dashboard");
    } catch (err: any) {
      setError(err?.message || "Login failed");
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="absolute inset-0 overflow-hidden">
        <div className="pointer-events-none absolute -top-24 left-1/2 h-[500px] w-[900px] -translate-x-1/2 rounded-full bg-gradient-to-r from-indigo-600/35 via-fuchsia-600/25 to-cyan-500/25 blur-3xl" />
      </div>

      <div className="relative mx-auto flex min-h-screen max-w-7xl items-center justify-center px-6 py-16">
        <div className="w-full max-w-md">
          <div className="rounded-2xl border border-white/10 bg-white/5 p-6 shadow-[0_0_0_1px_rgba(255,255,255,0.06),0_24px_60px_rgba(0,0,0,0.6)] backdrop-blur">
            <div className="mb-6">
              <div className="inline-flex items-center gap-2 rounded-full border border-white/10 bg-white/5 px-3 py-1 text-xs font-medium text-zinc-200">
                <span className="h-2 w-2 rounded-full bg-emerald-400" />
                GameForge Admin
              </div>
              <h1 className="mt-4 text-3xl font-semibold tracking-tight text-white">
                Sign in
              </h1>
              <p className="mt-2 text-sm text-zinc-300">
                Use your GameForge account. Only <span className="font-semibold">admin</span> can access this panel.
              </p>
            </div>

            {error ? (
              <div className="mb-4 rounded-xl border border-red-400/20 bg-red-500/10 px-4 py-3 text-sm text-red-200">
                {error}
              </div>
            ) : null}

            <form onSubmit={onSubmit} className="space-y-4">
              <div>
                <label className="mb-1 block text-sm font-medium text-zinc-200">
                  Email OR Username
                </label>
                <input
                  value={emailOrUsername}
                  onChange={(e) => setEmailOrUsername(e.target.value)}
                  className="h-11 w-full rounded-xl border border-white/10 bg-zinc-950/40 px-3 text-sm text-white outline-none ring-0 placeholder:text-zinc-500 focus:border-indigo-400/40 focus:bg-zinc-950/55"
                  placeholder="admin@example.com"
                  autoComplete="username"
                />
              </div>

              <div>
                <label className="mb-1 block text-sm font-medium text-zinc-200">
                  Password
                </label>
                <input
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  type="password"
                  className="h-11 w-full rounded-xl border border-white/10 bg-zinc-950/40 px-3 text-sm text-white outline-none ring-0 placeholder:text-zinc-500 focus:border-indigo-400/40 focus:bg-zinc-950/55"
                  placeholder="••••••••"
                  autoComplete="current-password"
                />
              </div>

              <label className="flex items-center gap-2 text-sm text-zinc-300">
                <input
                  type="checkbox"
                  checked={rememberMe}
                  onChange={(e) => setRememberMe(e.target.checked)}
                  className="h-4 w-4 rounded border-white/20 bg-transparent"
                />
                Remember me
              </label>

              <button
                type="submit"
                disabled={!canSubmit}
                className="h-11 w-full rounded-xl bg-gradient-to-r from-indigo-500 via-fuchsia-500 to-cyan-400 px-4 text-sm font-semibold text-white shadow-lg shadow-indigo-500/10 transition-opacity disabled:opacity-50"
              >
                {loading ? "Signing in..." : "Sign in"}
              </button>
            </form>

            <p className="mt-6 text-xs text-zinc-400">
              Backend API: <span className="font-mono">http://localhost:3000/api</span>
            </p>
          </div>

          <p className="mt-6 text-center text-xs text-zinc-500">
            If you don't have an admin user yet, change your user role to <span className="font-mono">admin</span> in database.
          </p>
        </div>
      </div>
    </div>
  );
}
