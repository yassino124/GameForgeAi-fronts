"use client";

import { useEffect, useMemo, useState } from "react";
import AdminShell from "@/app/_components/AdminShell";
import { apiFetch, ApiError } from "@/lib/api";
import { clearToken, getToken } from "@/lib/auth";
import { NeonChip } from "@/app/_components/Hud";

type BillingOverview = {
  totals?: {
    subscriptions?: number;
    active?: number;
    inactive?: number;
    mrrApproxUsd?: number;
  };
  byStatus?: Record<string, number>;
  byPlan?: Record<string, number>;
  plans?: Array<{
    name: string;
    description?: string;
    priceMonthly?: number;
    stripePriceId?: string;
    isPopular?: boolean;
    entitlements?: any;
  }>;
};

function cx(...parts: Array<string | false | null | undefined>) {
  return parts.filter(Boolean).join(" ");
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
        <div className={cx("h-10 w-10 rounded-2xl", props.accent)} />
      </div>
    </div>
  );
}

export default function BillingPage() {
  const token = useMemo(() => getToken(), []);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [data, setData] = useState<BillingOverview | null>(null);

  async function load() {
    if (!token) return;
    setLoading(true);
    setError(null);
    try {
      const res = await apiFetch<BillingOverview>("/admin/billing/overview", { method: "GET", token });
      setData(res);
    } catch (e: any) {
      setError(e?.message || "Failed to load billing");
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

  const totals = data?.totals;
  const byPlan = data?.byPlan || {};
  const byStatus = data?.byStatus || {};

  const planRows = Object.entries(byPlan)
    .sort((a, b) => Number(b[1]) - Number(a[1]))
    .slice(0, 8);

  const statusRows = Object.entries(byStatus)
    .sort((a, b) => Number(b[1]) - Number(a[1]))
    .slice(0, 8);

  return (
    <AdminShell
      title="Billing"
      right={
        <div className="flex items-center gap-2">
          <NeonChip tone="cyan">
            <span className="font-mono">LEDGER</span>
            <span className="text-white">BILLING</span>
          </NeonChip>
          <button onClick={load} className="gf-btn h-9 rounded-xl px-3 text-sm">
            Refresh
          </button>
        </div>
      }
    >
      {error ? (
        <div className="mb-4 rounded-xl border border-red-400/20 bg-red-500/10 px-4 py-3 text-sm text-red-200">
          {error}
        </div>
      ) : null}

      <div className="gf-card relative mb-4 overflow-hidden rounded-2xl border border-white/10 p-5">
        <div
          className="pointer-events-none absolute inset-0 opacity-50"
          style={{
            backgroundImage:
              "radial-gradient(circle at 20% 0%, rgba(34,211,238,0.20), transparent 55%), radial-gradient(circle at 80% 100%, rgba(236,72,153,0.14), transparent 55%)",
          }}
        />
        <div className="pointer-events-none absolute inset-0 opacity-20" style={{ backgroundImage: "repeating-linear-gradient(to bottom, rgba(255,255,255,0.10), rgba(255,255,255,0.10) 1px, transparent 1px, transparent 7px)" }} />
        <div className="relative flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <NeonChip tone="fuchsia">REVENUE HUD</NeonChip>
            <div className="mt-2 text-sm text-zinc-400">Subscriptions, MRR, and plan distribution</div>
          </div>
          <NeonChip tone="zinc">
            <span className="font-mono">MRR</span>
            <span className="text-white">{loading ? "—" : `$${Number(totals?.mrrApproxUsd ?? 0).toFixed(0)}`}</span>
          </NeonChip>
        </div>
      </div>

      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <StatCard
          label="Subscriptions"
          value={loading ? "—" : String(totals?.subscriptions ?? 0)}
          hint="All subscription rows"
          accent="bg-gradient-to-br from-indigo-500/35 to-indigo-300/10"
        />
        <StatCard
          label="Active"
          value={loading ? "—" : String(totals?.active ?? 0)}
          hint="active + trialing"
          accent="bg-gradient-to-br from-emerald-500/35 to-emerald-300/10"
        />
        <StatCard
          label="Inactive"
          value={loading ? "—" : String(totals?.inactive ?? 0)}
          hint="canceled/past_due/etc"
          accent="bg-gradient-to-br from-amber-500/35 to-amber-300/10"
        />
        <StatCard
          label="MRR (approx)"
          value={loading ? "—" : `$${Number(totals?.mrrApproxUsd ?? 0).toFixed(0)}`}
          hint="sum of active plan priceMonthly"
          accent="bg-gradient-to-br from-cyan-500/35 to-cyan-300/10"
        />
      </div>

      <div className="mt-5 grid grid-cols-1 gap-4 lg:grid-cols-2">
        <div className="gf-card rounded-2xl border border-white/10 p-5">
          <h2 className="text-sm font-semibold text-zinc-100">By plan</h2>
          <div className="mt-3 space-y-2">
            {loading ? (
              Array.from({ length: 6 }).map((_, i) => <div key={i} className="h-4 w-full animate-pulse rounded bg-white/10" />)
            ) : planRows.length ? (
              planRows.map(([k, v]) => (
                <div key={k} className="flex items-center justify-between rounded-xl border border-white/10 bg-black/20 px-3 py-2 text-sm">
                  <span className="truncate text-zinc-200">{k}</span>
                  <span className="text-zinc-300">{v}</span>
                </div>
              ))
            ) : (
              <div className="text-sm text-zinc-400">No data</div>
            )}
          </div>
        </div>

        <div className="gf-card rounded-2xl border border-white/10 p-5">
          <h2 className="text-sm font-semibold text-zinc-100">By status</h2>
          <div className="mt-3 space-y-2">
            {loading ? (
              Array.from({ length: 6 }).map((_, i) => <div key={i} className="h-4 w-full animate-pulse rounded bg-white/10" />)
            ) : statusRows.length ? (
              statusRows.map(([k, v]) => (
                <div key={k} className="flex items-center justify-between rounded-xl border border-white/10 bg-black/20 px-3 py-2 text-sm">
                  <span className="truncate text-zinc-200">{k}</span>
                  <span className="text-zinc-300">{v}</span>
                </div>
              ))
            ) : (
              <div className="text-sm text-zinc-400">No data</div>
            )}
          </div>
        </div>
      </div>

      <div className="gf-card mt-5 rounded-2xl border border-white/10 p-5">
        <h2 className="text-sm font-semibold text-zinc-100">Plans</h2>
        <div className="mt-3 overflow-hidden rounded-xl border border-white/10">
          <div className="grid grid-cols-[0.8fr_1.6fr_0.6fr_0.6fr] gap-0 border-b border-white/10 bg-black/10 px-4 py-3 text-xs font-medium text-zinc-400">
            <div>Name</div>
            <div>Description</div>
            <div>Price</div>
            <div>Popular</div>
          </div>
          {(loading ? Array.from({ length: 3 }) : data?.plans || []).map((p: any, idx: number) => (
            <div key={p?.name || idx} className="grid grid-cols-[0.8fr_1.6fr_0.6fr_0.6fr] gap-0 px-4 py-3 text-sm text-zinc-200">
              <div className="font-medium">{loading ? <div className="h-4 w-20 animate-pulse rounded bg-white/10" /> : p.name}</div>
              <div className="truncate text-zinc-300">
                {loading ? <div className="h-4 w-72 animate-pulse rounded bg-white/10" /> : p.description || "—"}
              </div>
              <div>{loading ? <div className="h-4 w-12 animate-pulse rounded bg-white/10" /> : `$${Number(p.priceMonthly || 0).toFixed(0)}`}</div>
              <div>{loading ? <div className="h-4 w-10 animate-pulse rounded bg-white/10" /> : p.isPopular ? "yes" : "—"}</div>
            </div>
          ))}
        </div>
      </div>
    </AdminShell>
  );
}
