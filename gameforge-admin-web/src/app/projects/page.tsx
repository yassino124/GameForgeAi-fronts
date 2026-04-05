"use client";

import { Suspense, useEffect, useMemo, useState } from "react";
import { useSearchParams } from "next/navigation";
import { apiFetch, ApiError } from "@/lib/api";
import { clearToken, getToken } from "@/lib/auth";
import AdminShell from "@/app/_components/AdminShell";
import ConfirmDialog from "@/app/_components/ConfirmDialog";
import { useToast } from "@/app/_components/ToastProvider";
import { NeonChip, PulseDot } from "@/app/_components/Hud";

type ProjectRow = {
  id: string;
  ownerId?: string;
  templateId?: string;
  name?: string;
  status?: string;
  buildTarget?: string;
  error?: string;
  buildLogLastLine?: string;
  updatedAt?: string;
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

export default function ProjectsPage() {
  return (
    <Suspense fallback={null}>
      <ProjectsPageInner />
    </Suspense>
  );
}

function ProjectsPageInner() {
  const toast = useToast();
  const searchParams = useSearchParams();
  const token = useMemo(() => getToken(), []);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const [q, setQ] = useState(() => searchParams.get("q") || "");
  const [status, setStatus] = useState(() => searchParams.get("status") || "");
  const [page, setPage] = useState(1);
  const [data, setData] = useState<Paged<ProjectRow> | null>(null);
  const [busyId, setBusyId] = useState<string | null>(null);
  const [confirm, setConfirm] = useState<
    null | {
      id: string;
      action: "rebuild" | "cancel" | "delete" | "clearError" | "setStatus";
      name?: string;
      nextStatus?: string;
    }
  >(null);

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
      const res = await apiFetch<Paged<ProjectRow>>(`/admin/projects?${qs.toString()}`, { method: "GET", token });
      setData(res);
    } catch (e: any) {
      const msg = e?.message || "Failed to load projects";
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
  }, [page, q, status]);

  useEffect(() => {
    const nextQ = searchParams.get("q") || "";
    const nextStatus = searchParams.get("status") || "";
    setQ(nextQ);
    setStatus(nextStatus);
    setPage(1);
    setTimeout(() => {
      load();
    }, 0);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [searchParams]);

  async function doAction(
    projectId: string,
    action: "rebuild" | "cancel" | "delete" | "clearError" | "setStatus",
    nextStatus?: string,
  ) {
    if (!token) return;
    setBusyId(projectId);
    setError(null);
    try {
      if (action === "rebuild") {
        await apiFetch(`/admin/builds/${encodeURIComponent(projectId)}/rebuild`, { method: "POST", token });
      } else if (action === "cancel") {
        await apiFetch(`/admin/builds/${encodeURIComponent(projectId)}/cancel`, { method: "POST", token });
      } else if (action === "clearError") {
        await apiFetch(`/admin/projects/${encodeURIComponent(projectId)}/clear-error`, { method: "POST", token });
      } else if (action === "setStatus") {
        await apiFetch(`/admin/projects/${encodeURIComponent(projectId)}/status`, {
          method: "PATCH",
          token,
          body: { status: String(nextStatus || "").trim() },
        });
      } else {
        await apiFetch(`/admin/projects/${encodeURIComponent(projectId)}`, { method: "DELETE", token });
      }
      toast.success(
        action === "delete"
          ? "Project deleted"
          : action === "cancel"
            ? "Build cancelled"
            : action === "clearError"
              ? "Cleared"
              : action === "setStatus"
                ? "Status updated"
                : "Rebuild queued",
      );
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
    <AdminShell
      title="Projects"
      right={
        <div className="flex items-center gap-2">
          <NeonChip tone="fuchsia">
            <PulseDot tone="cyan" />
            <span className="font-mono">FORGE</span>
            <span className="text-white">PROJECTS</span>
          </NeonChip>
          <input
            value={q}
            onChange={(e) => setQ(e.target.value)}
            placeholder="Search project"
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
          <button
            onClick={() => {
              setPage(1);
              load();
            }}
            className="gf-btn h-9 rounded-xl px-3 text-sm"
          >
            Apply
          </button>
        </div>
      }
    >
      <div className="gf-card relative mb-4 overflow-hidden rounded-2xl border border-white/10 p-5">
        <div
          className="pointer-events-none absolute inset-0 opacity-50"
          style={{
            backgroundImage:
              "radial-gradient(circle at 20% 0%, rgba(34,211,238,0.20), transparent 55%), radial-gradient(circle at 80% 100%, rgba(236,72,153,0.16), transparent 55%)",
          }}
        />
        <div className="pointer-events-none absolute inset-0 opacity-20" style={{ backgroundImage: "repeating-linear-gradient(to bottom, rgba(255,255,255,0.10), rgba(255,255,255,0.10) 1px, transparent 1px, transparent 7px)" }} />
        <div className="relative flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <NeonChip tone="fuchsia">
              <PulseDot tone="cyan" />
              PROJECT FORGE
            </NeonChip>
            <div className="mt-2 text-sm text-zinc-400">Manage status, rebuilds, and error recovery</div>
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
        <div className="gf-table-head grid grid-cols-[1.2fr_0.8fr_0.7fr_1.6fr_1.3fr] gap-0 border-b border-white/10 px-4 py-3 text-xs font-medium text-zinc-400">
          <div>Name</div>
          <div>Target</div>
          <div>Status</div>
          <div>Last log / error</div>
          <div className="text-right">Actions</div>
        </div>

        {(loading ? Array.from({ length: 8 }) : data?.items || []).map((p: any, idx: number) => (
          <div
            key={p?.id || idx}
            className="gf-row gf-tr grid grid-cols-[1.2fr_0.8fr_0.7fr_1.6fr_1.3fr] items-center gap-0 px-4 py-3 text-sm text-zinc-200"
          >
            <div className="truncate">
              {loading ? <div className="h-4 w-52 animate-pulse rounded bg-white/10" /> : p.name || "—"}
              {!loading ? <div className="mt-0.5 text-xs text-zinc-500">{p.id}</div> : null}
            </div>
            <div>{loading ? <div className="h-4 w-20 animate-pulse rounded bg-white/10" /> : p.buildTarget || "—"}</div>
            <div>{loading ? <div className="h-4 w-14 animate-pulse rounded bg-white/10" /> : <StatusPill status={p.status} />}</div>
            <div className="truncate text-xs text-zinc-300">
              {loading ? (
                <div className="h-4 w-80 animate-pulse rounded bg-white/10" />
              ) : (
                (p.buildLogLastLine || p.error || "—").toString()
              )}
            </div>
            <div className="flex justify-end gap-2">
              {loading ? (
                <div className="h-9 w-40 animate-pulse rounded-xl bg-white/10" />
              ) : (
                <>
                  <button
                    disabled={busyId === p.id}
                    onClick={() => setConfirm({ id: p.id, action: "rebuild", name: p.name })}
                    className="gf-btn h-9 rounded-xl px-3 text-xs disabled:opacity-50"
                  >
                    Rebuild
                  </button>
                  <button
                    disabled={busyId === p.id}
                    onClick={() => setConfirm({ id: p.id, action: "cancel", name: p.name })}
                    className="gf-btn h-9 rounded-xl px-3 text-xs disabled:opacity-50"
                  >
                    Cancel
                  </button>
                  <button
                    disabled={busyId === p.id}
                    onClick={() => setConfirm({ id: p.id, action: "clearError", name: p.name })}
                    className="gf-btn h-9 rounded-xl px-3 text-xs disabled:opacity-50"
                  >
                    Clear
                  </button>
                  <button
                    disabled={busyId === p.id}
                    onClick={() => setConfirm({ id: p.id, action: "setStatus", name: p.name, nextStatus: "failed" })}
                    className="gf-btn h-9 rounded-xl px-3 text-xs disabled:opacity-50"
                  >
                    Fail
                  </button>
                  <button
                    disabled={busyId === p.id}
                    onClick={() => setConfirm({ id: p.id, action: "delete", name: p.name })}
                    className="gf-btn gf-btn-danger h-9 rounded-xl px-3 text-xs disabled:opacity-50"
                  >
                    Delete
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
        title={
          confirm?.action === "delete"
            ? "Delete project?"
            : confirm?.action === "cancel"
              ? "Cancel build?"
              : confirm?.action === "clearError"
                ? "Clear error?"
                : confirm?.action === "setStatus"
                  ? "Force status?"
                  : "Queue rebuild?"
        }
        description={
          confirm?.name
            ? confirm?.action === "setStatus"
              ? `Project: ${confirm.name} • Set: ${confirm?.nextStatus || ""}`
              : `Project: ${confirm.name}`
            : undefined
        }
        confirmText={
          confirm?.action === "delete"
            ? "Delete"
            : confirm?.action === "cancel"
              ? "Cancel build"
              : confirm?.action === "clearError"
                ? "Clear"
                : confirm?.action === "setStatus"
                  ? "Force"
                  : "Rebuild"
        }
        confirmTone={confirm?.action === "delete" ? "danger" : confirm?.action === "setStatus" ? "danger" : "default"}
        busy={Boolean(confirm?.id && busyId === confirm.id)}
        onCancel={() => setConfirm(null)}
        onConfirm={async () => {
          if (!confirm) return;
          const { id, action, nextStatus } = confirm;
          setConfirm(null);
          await doAction(id, action, nextStatus);
        }}
      />
    </AdminShell>
  );
}
