"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import AdminShell from "@/app/_components/AdminShell";
import { apiFetch, ApiError } from "@/lib/api";
import { clearToken, getToken } from "@/lib/auth";
import { useToast } from "@/app/_components/ToastProvider";
import { NeonChip, PulseDot } from "@/app/_components/Hud";

type SystemHealth = {
  status?: string;
  runtime?: {
    node?: string;
    platform?: string;
    arch?: string;
    pid?: number;
    uptimeSeconds?: number;
  };
  memory?: {
    rss?: number;
    heapTotal?: number;
    heapUsed?: number;
    systemTotal?: number;
    systemFree?: number;
  };
  builds?: {
    queued?: number;
    running?: number;
    ready?: number;
    failed?: number;
  };
  env?: {
    publicBaseUrl?: string | null;
    unityEditorConfigured?: boolean;
  };
};

function bytes(n?: number) {
  const v = Number(n || 0);
  if (!v) return "0";
  const gb = 1024 * 1024 * 1024;
  const mb = 1024 * 1024;
  if (v >= gb) return (v / gb).toFixed(2) + " GB";
  if (v >= mb) return (v / mb).toFixed(1) + " MB";
  return v + " B";
}

function StatCard(props: { label: string; value: string; hint?: string; accent: string }) {
  return (
    <div className="gf-card group relative overflow-hidden rounded-2xl border border-white/10 p-5 transition-transform duration-200 hover:-translate-y-0.5">
      <div className="pointer-events-none absolute inset-0 opacity-0 transition-opacity duration-200 group-hover:opacity-100">
        <div className="absolute inset-0 bg-gradient-to-b from-white/5 via-transparent to-transparent" />
        <div className="absolute inset-0" style={{ backgroundImage: "repeating-linear-gradient(to bottom, rgba(255,255,255,0.06), rgba(255,255,255,0.06) 1px, transparent 1px, transparent 6px)" }} />
      </div>
      <div className="flex items-center justify-between">
        <div>
          <p className="text-xs font-medium text-zinc-400">{props.label}</p>
          <p className="mt-2 text-3xl font-semibold tracking-tight text-white">{props.value}</p>
          {props.hint ? <p className="mt-1 text-xs text-zinc-500">{props.hint}</p> : null}
        </div>
        <div className={`h-10 w-10 rounded-2xl ${props.accent}`} />
      </div>
    </div>
  );
}

export default function SystemPage() {
  const toast = useToast();
  const token = useMemo(() => getToken(), []);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [data, setData] = useState<SystemHealth | null>(null);
  const [live, setLive] = useState(true);
  const timerRef = useRef<any>(null);

  async function load() {
    if (!token) return;
    setLoading(true);
    setError(null);
    try {
      const res = await apiFetch<SystemHealth>("/admin/system-health", { method: "GET", token });
      setData(res);
    } catch (e: any) {
      const msg = e?.message || "Failed to load system health";
      setError(msg);
      toast.error("System health", msg);
      if (e instanceof ApiError && (e.status === 401 || e.status === 403)) {
        clearToken();
      }
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    if (!live) return;
    if (!token) return;
    if (timerRef.current) clearInterval(timerRef.current);
    timerRef.current = setInterval(() => {
      load();
    }, 5000);
    return () => {
      if (timerRef.current) clearInterval(timerRef.current);
      timerRef.current = null;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [live, token]);

  const st = (data?.status || "unknown").toLowerCase();
  const stPill =
    st === "healthy" ? "border-emerald-400/20 bg-emerald-500/10 text-emerald-200" : "border-amber-400/20 bg-amber-500/10 text-amber-200";

  const builds = data?.builds;
  const buildsSummary = loading
    ? "—"
    : `Q:${builds?.queued ?? 0}  R:${builds?.running ?? 0}  OK:${builds?.ready ?? 0}  F:${builds?.failed ?? 0}`;

  const uptime = Number(data?.runtime?.uptimeSeconds || 0);
  const uptimeStr = uptime ? `${Math.floor(uptime / 3600)}h ${Math.floor((uptime % 3600) / 60)}m` : "—";

  return (
    <AdminShell
      title="System"
      right={
        <div className="flex items-center gap-2">
          <NeonChip tone={st === "healthy" ? "emerald" : "amber"}>
            <PulseDot tone={st === "healthy" ? "emerald" : "amber"} />
            <span className="font-mono">SYS</span>
            <span className="text-white">{data?.status || "—"}</span>
          </NeonChip>
          <button
            onClick={() => setLive((v) => !v)}
            className="gf-btn h-9 rounded-xl px-3 text-sm"
          >
            {live ? "Live" : "Paused"}
          </button>
        </div>
      }
    >
      <div className="gf-card relative mb-4 overflow-hidden rounded-2xl border border-white/10 p-5">
        <div
          className="pointer-events-none absolute inset-0 opacity-50"
          style={{
            backgroundImage:
              "radial-gradient(circle at 20% 0%, rgba(34,211,238,0.22), transparent 55%), radial-gradient(circle at 80% 100%, rgba(236,72,153,0.16), transparent 55%)",
          }}
        />
        <div className="pointer-events-none absolute inset-0 opacity-20" style={{ backgroundImage: "repeating-linear-gradient(to bottom, rgba(255,255,255,0.10), rgba(255,255,255,0.10) 1px, transparent 1px, transparent 7px)" }} />
        <div className="relative flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <NeonChip tone="cyan">
              <PulseDot tone="cyan" />
              FORGE PULSE
            </NeonChip>
            <div className="mt-2 text-sm text-zinc-400">Runtime, memory, builds, and Unity configuration</div>
          </div>
          <NeonChip tone="zinc">
            <span className="font-mono">BUILDS</span>
            <span className="text-white">{buildsSummary}</span>
          </NeonChip>
        </div>
      </div>

      {error ? (
        <div className="mb-4 rounded-xl border border-red-400/20 bg-red-500/10 px-4 py-3 text-sm text-red-200">
          {error}
        </div>
      ) : null}

      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <StatCard
          label="Uptime"
          value={loading ? "—" : uptimeStr}
          hint={loading ? undefined : `pid ${data?.runtime?.pid ?? "—"} • ${data?.runtime?.platform ?? "—"}/${data?.runtime?.arch ?? "—"}`}
          accent="bg-gradient-to-br from-emerald-500/35 to-emerald-300/10"
        />
        <StatCard
          label="Node"
          value={loading ? "—" : String(data?.runtime?.node || "—")}
          hint="runtime"
          accent="bg-gradient-to-br from-blue-500/35 to-blue-300/10"
        />
        <StatCard
          label="Builds"
          value={buildsSummary}
          hint="Q/R/OK/F"
          accent="bg-gradient-to-br from-cyan-500/35 to-cyan-300/10"
        />
        <StatCard
          label="Unity"
          value={loading ? "—" : data?.env?.unityEditorConfigured ? "configured" : "missing"}
          hint="UNITY_EDITOR_PATH"
          accent="bg-gradient-to-br from-cyan-500/35 to-cyan-300/10"
        />
      </div>

      <div className="mt-5 grid grid-cols-1 gap-4 lg:grid-cols-2">
        <div className="gf-card rounded-2xl p-5">
          <h2 className="text-sm font-semibold text-zinc-100">Memory</h2>
          <div className="mt-3 space-y-2 text-sm text-zinc-200">
            <div className="flex items-center justify-between rounded-xl border border-white/10 bg-white/5 px-3 py-2">
              <span className="text-zinc-300">RSS</span>
              <span>{loading ? "—" : bytes(data?.memory?.rss)}</span>
            </div>
            <div className="flex items-center justify-between rounded-xl border border-white/10 bg-white/5 px-3 py-2">
              <span className="text-zinc-300">Heap used</span>
              <span>{loading ? "—" : bytes(data?.memory?.heapUsed)}</span>
            </div>
            <div className="flex items-center justify-between rounded-xl border border-white/10 bg-white/5 px-3 py-2">
              <span className="text-zinc-300">System free</span>
              <span>{loading ? "—" : bytes(data?.memory?.systemFree)}</span>
            </div>
            <div className="flex items-center justify-between rounded-xl border border-white/10 bg-white/5 px-3 py-2">
              <span className="text-zinc-300">System total</span>
              <span>{loading ? "—" : bytes(data?.memory?.systemTotal)}</span>
            </div>
          </div>
        </div>

        <div className="gf-card rounded-2xl p-5">
          <h2 className="text-sm font-semibold text-zinc-100">Environment</h2>
          <div className="mt-3 space-y-2 text-sm text-zinc-200">
            <div className="rounded-xl border border-white/10 bg-white/5 px-3 py-2">
              <div className="text-xs text-zinc-400">PUBLIC_BASE_URL</div>
              <div className="mt-1 break-all text-zinc-200">{loading ? "—" : String(data?.env?.publicBaseUrl || "(not set)")}</div>
            </div>
            <button
              onClick={load}
              className="gf-btn w-full rounded-xl px-3 py-2 text-sm"
            >
              Refresh health
            </button>
          </div>
        </div>
      </div>
    </AdminShell>
  );
}
