"use client";

import { Suspense, useEffect, useMemo, useRef, useState } from "react";
import { useSearchParams } from "next/navigation";
import { apiFetch, ApiError } from "@/lib/api";
import { clearToken, getToken } from "@/lib/auth";
import AdminShell from "@/app/_components/AdminShell";
import ConfirmDialog from "@/app/_components/ConfirmDialog";
import { useToast } from "@/app/_components/ToastProvider";
import { NeonChip, PulseDot } from "@/app/_components/Hud";

type BuildRow = {
  id: string;
  ownerId?: string;
  name?: string;
  status?: string;
  buildTarget?: string;
  error?: string;
  buildLogLastLine?: string;
  updatedAt?: string;
  artifacts?: {
    resultStorageKey?: string;
    webglZipStorageKey?: string;
    webglIndexStorageKey?: string;
    androidApkStorageKey?: string;
    windowsZipStorageKey?: string;
    macosZipStorageKey?: string;
    sourceZipStorageKey?: string;
  };
};

type Paged<T> = { page: number; limit: number; total: number; items: T[] };

function cx(...parts: Array<string | false | null | undefined>) {
  return parts.filter(Boolean).join(" ");
}

function StatusPill({ status }: { status?: string }) {
  const s = (status || "").toLowerCase();
  const cls =
    s === "ready"
      ? "border-emerald-400/20 bg-emerald-500/10 text-emerald-200"
      : s === "running"
        ? "border-cyan-400/20 bg-cyan-500/10 text-cyan-200"
        : s === "queued"
          ? "border-amber-400/20 bg-amber-500/10 text-amber-200"
          : "border-red-400/20 bg-red-500/10 text-red-200";
  return <span className={cx("rounded-full border px-2 py-0.5 text-xs", cls)}>{status || "—"}</span>;
}

function ArtifactBadge({ label, present }: { label: string; present: boolean }) {
  return (
    <span
      className={cx(
        "rounded-full border px-2 py-0.5 text-[11px]",
        present ? "border-white/10 bg-white/5 text-zinc-200" : "border-white/5 bg-transparent text-zinc-500",
      )}
    >
      {label}
    </span>
  );
}

function BuildsPageInner() {
  const toast = useToast();
  const searchParams = useSearchParams();
  const token = useMemo(() => getToken(), []);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const [q, setQ] = useState(() => searchParams.get("q") || "");
  const [status, setStatus] = useState(() => searchParams.get("status") || "");
  const [target, setTarget] = useState(() => searchParams.get("target") || "");
  const [page, setPage] = useState(1);
  const [data, setData] = useState<Paged<BuildRow> | null>(null);
  const [busyId, setBusyId] = useState<string | null>(null);
  const [confirm, setConfirm] = useState<null | { id: string; action: "rebuild" | "cancel"; name?: string }>(null);
  const [live, setLive] = useState(true);
  const timerRef = useRef<any>(null);

  async function load() {
    if (!token) return;
    setLoading(true);
    setError(null);
    try {
      const qs = new URLSearchParams();
      qs.set("page", String(page));
      qs.set("limit", "20");
      if (q.trim()) qs.set("q", q.trim());
      if (status.trim()) qs.set("status", status.trim());
      if (target.trim()) qs.set("target", target.trim());
      const res = await apiFetch<Paged<BuildRow>>(`/admin/builds?${qs.toString()}`, { method: "GET", token });
      setData(res);
    } catch (e: any) {
      const msg = e?.message || "Failed to load builds";
      setError(msg);
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
  }, [page, q, status, target]);

  useEffect(() => {
    const nextQ = searchParams.get("q") || "";
    const nextStatus = searchParams.get("status") || "";
    const nextTarget = searchParams.get("target") || "";
    setQ(nextQ);
    setStatus(nextStatus);
    setTarget(nextTarget);
    setPage(1);
    setTimeout(() => {
      load();
    }, 0);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [searchParams]);

  useEffect(() => {
    if (!live) return;
    if (!token) return;
    if (timerRef.current) clearInterval(timerRef.current);
    timerRef.current = setInterval(() => {
      load();
    }, 4000);
    return () => {
      if (timerRef.current) clearInterval(timerRef.current);
      timerRef.current = null;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [live, token]);

  async function doAction(buildId: string, action: "rebuild" | "cancel") {
    if (!token) return;
    setBusyId(buildId);
    setError(null);
    try {
      if (action === "rebuild") {
        await apiFetch(`/admin/builds/${encodeURIComponent(buildId)}/rebuild`, { method: "POST", token });
      } else {
        await apiFetch(`/admin/builds/${encodeURIComponent(buildId)}/cancel`, { method: "POST", token });
      }
      toast.success(action === "cancel" ? "Build cancelled" : "Rebuild queued");
      await load();
    } catch (e: any) {
      const msg = e?.message || "Action failed";
      setError(msg);
      toast.error("Action failed", msg);
    } finally {
      setBusyId(null);
    }
  }

  const total = data?.total ?? 0;
  const totalPages = Math.max(1, Math.ceil(total / (data?.limit || 20)));

  return (
    <AdminShell title="Builds / Queue" right={
      <div className="flex items-center gap-2">
        <NeonChip tone={live ? "cyan" : "amber"}>
          <PulseDot tone={live ? "cyan" : "amber"} />
          <span className="font-mono">REACTOR</span>
          <span className="text-white">{live ? "LIVE" : "PAUSED"}</span>
        </NeonChip>
        <input
          value={q}
          onChange={(e) => setQ(e.target.value)}
          placeholder="Search build"
          className="gf-input h-9 w-56 rounded-xl px-3 text-sm placeholder:text-zinc-500"
        />
        <select
          value={status}
          onChange={(e) => setStatus(e.target.value)}
          className="gf-input h-9 rounded-xl px-3 text-sm"
        >
          <option value="">All status</option>
          <option value="queued">queued</option>
          <option value="running">running</option>
          <option value="ready">ready</option>
          <option value="failed">failed</option>
        </select>
        <select
          value={target}
          onChange={(e) => setTarget(e.target.value)}
          className="gf-input h-9 rounded-xl px-3 text-sm"
        >
          <option value="">All targets</option>
          <option value="webgl">webgl</option>
          <option value="android_apk">android_apk</option>
          <option value="windows">windows</option>
          <option value="macos">macos</option>
        </select>
        <button
          onClick={() => {
            setPage(1);
            load();
          }}
          className="gf-btn h-9 rounded-xl px-3 text-sm"
        >
          Apply
        </button>
        <button
          onClick={() => setLive((v) => !v)}
          className="gf-btn h-9 rounded-xl px-3 text-sm"
        >
          {live ? "Live" : "Paused"}
        </button>
      </div>
    }>
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
              BUILD REACTOR
            </NeonChip>
            <div className="mt-2 text-sm text-zinc-400">Live queue monitor and admin actions</div>
          </div>
          <NeonChip tone="zinc">
            <span className="font-mono">TOTAL</span>
            <span className="text-white">{loading ? "—" : String(total)}</span>
          </NeonChip>
        </div>
      </div>

      {error ? (
        <div className="mb-4 rounded-xl border border-red-400/20 bg-red-500/10 px-4 py-3 text-sm text-red-200">
          {error}
        </div>
      ) : null}

      <div className="gf-table gf-scrollbar overflow-hidden rounded-2xl">
        <div className="gf-table-head grid grid-cols-[1.1fr_0.7fr_0.6fr_1.6fr_0.9fr] gap-0 border-b border-white/10 px-4 py-3 text-xs font-medium text-zinc-400">
          <div>Build</div>
          <div>Target</div>
          <div>Status</div>
          <div>Log / error</div>
          <div className="text-right">Actions</div>
        </div>

        {(loading ? Array.from({ length: 8 }) : data?.items || []).map((b: any, idx: number) => (
          <div
            key={b?.id || idx}
            className="gf-row gf-tr grid grid-cols-[1.1fr_0.7fr_0.6fr_1.6fr_0.9fr] items-center gap-0 px-4 py-3 text-sm text-zinc-200"
          >
            <div className="truncate">
              {loading ? <div className="h-4 w-52 animate-pulse rounded bg-white/10" /> : b.name || "—"}
              {!loading ? (
                <div className="mt-1 flex flex-wrap gap-1">
                  <ArtifactBadge label="result" present={Boolean(b.artifacts?.resultStorageKey)} />
                  <ArtifactBadge label="webgl" present={Boolean(b.artifacts?.webglIndexStorageKey)} />
                  <ArtifactBadge label="apk" present={Boolean(b.artifacts?.androidApkStorageKey)} />
                  <ArtifactBadge label="win" present={Boolean(b.artifacts?.windowsZipStorageKey)} />
                  <ArtifactBadge label="mac" present={Boolean(b.artifacts?.macosZipStorageKey)} />
                  <ArtifactBadge label="source" present={Boolean(b.artifacts?.sourceZipStorageKey)} />
                </div>
              ) : null}
            </div>
            <div>{loading ? <div className="h-4 w-16 animate-pulse rounded bg-white/10" /> : b.buildTarget || "—"}</div>
            <div>{loading ? <div className="h-4 w-12 animate-pulse rounded bg-white/10" /> : <StatusPill status={b.status} />}</div>
            <div className="truncate text-xs text-zinc-300">
              {loading ? (
                <div className="h-4 w-80 animate-pulse rounded bg-white/10" />
              ) : (
                (b.buildLogLastLine || b.error || "—").toString()
              )}
            </div>
            <div className="flex justify-end gap-2">
              {loading ? (
                <div className="h-9 w-36 animate-pulse rounded-xl bg-white/10" />
              ) : (
                <>
                  <button
                    disabled={busyId === b.id}
                    onClick={() => setConfirm({ id: b.id, action: "rebuild", name: b.name })}
                    className="gf-btn h-9 rounded-xl px-3 text-xs disabled:opacity-50"
                  >
                    Rebuild
                  </button>
                  <button
                    disabled={busyId === b.id}
                    onClick={() => setConfirm({ id: b.id, action: "cancel", name: b.name })}
                    className="gf-btn h-9 rounded-xl px-3 text-xs disabled:opacity-50"
                  >
                    Cancel
                  </button>
                </>
              )}
            </div>
          </div>
        ))}
      </div>

      <div className="mt-4 flex items-center justify-between text-sm text-zinc-300">
        <div>
          Showing {(data?.items?.length ?? 0).toString()} of {total.toString()}
        </div>
        <div className="flex items-center gap-2">
          <button
            disabled={page <= 1}
            onClick={() => setPage((p) => Math.max(1, p - 1))}
            className="gf-btn h-9 rounded-xl px-3 text-sm disabled:opacity-50"
          >
            Prev
          </button>
          <div className="gf-input rounded-xl border border-white/10 bg-white/5 px-3 py-2 text-xs">
            Page {page} / {totalPages}
          </div>
          <button
            disabled={page >= totalPages}
            onClick={() => setPage((p) => Math.min(totalPages, p + 1))}
            className="gf-btn h-9 rounded-xl px-3 text-sm disabled:opacity-50"
          >
            Next
          </button>
        </div>
      </div>

      <ConfirmDialog
        open={Boolean(confirm)}
        title={confirm?.action === "cancel" ? "Cancel build?" : "Queue rebuild?"}
        description={confirm?.name ? `Build: ${confirm.name}` : undefined}
        confirmText={confirm?.action === "cancel" ? "Cancel build" : "Rebuild"}
        confirmTone={"default"}
        busy={Boolean(confirm?.id && busyId === confirm.id)}
        onCancel={() => setConfirm(null)}
        onConfirm={async () => {
          if (!confirm) return;
          const { id, action } = confirm;
          setConfirm(null);
          await doAction(id, action);
        }}
      />
    </AdminShell>
  );
}

export default function BuildsPage() {
  return (
    <Suspense fallback={null}>
      <BuildsPageInner />
    </Suspense>
  );
}
