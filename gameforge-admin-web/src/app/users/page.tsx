"use client";

import { Suspense, useEffect, useMemo, useState } from "react";
import { useSearchParams } from "next/navigation";
import { apiFetch, ApiError } from "@/lib/api";
import { clearToken, getToken } from "@/lib/auth";
import AdminShell from "@/app/_components/AdminShell";
import { useToast } from "@/app/_components/ToastProvider";
import ConfirmDialog from "@/app/_components/ConfirmDialog";
import { 
  Users, User, Shield, Code, ChevronDown, 
  Search, ShieldCheck, Mail, Calendar, 
  Trash2, Ban, ShieldAlert, Zap, Award
} from "lucide-react";
import { motion, AnimatePresence } from "framer-motion";
import { NeonChip } from "@/app/_components/Hud";

type UserRow = {
  id: string;
  email?: string;
  username?: string;
  fullName?: string;
  role?: string;
  subscription?: string;
  isActive?: boolean;
  createdAt?: string;
  lastLogin?: string;
};

type Paged<T> = { page: number; limit: number; total: number; items: T[] };

type ProjectRow = {
  id: string;
  name?: string;
  status?: string;
  buildTarget?: string;
  error?: string;
  buildLogLastLine?: string;
  updatedAt?: string;
};

type BuildRow = {
  id: string;
  name?: string;
  status?: string;
  buildTarget?: string;
  error?: string;
  buildLogLastLine?: string;
  updatedAt?: string;
};

function cx(...parts: Array<string | false | null | undefined>) {
  return parts.filter(Boolean).join(" ");
}

function ActivePill({ isActive }: { isActive?: boolean }) {
  const v = Boolean(isActive);
  return (
    <span
      className={cx(
        "rounded-full border px-2 py-0.5 text-xs",
        v ? "border-emerald-400/20 bg-emerald-500/10 text-emerald-200" : "border-red-400/20 bg-red-500/10 text-red-200",
      )}
    >
      {v ? "active" : "banned"}
    </span>
  );
}

function RolePill({ role }: { role?: string }) {
  const r = (role || "").toLowerCase();
  const isDev = r === "dev" || r === "devl" || r === "developer";
  const isAdmin = r === "admin" || r === "owner";
  
  const cls =
    isAdmin
      ? "border-emerald-400/30 bg-emerald-500/20 text-emerald-300 shadow-[0_0_15px_rgba(16,185,129,0.2)] font-black"
      : isDev
        ? "border-cyan-400/20 bg-cyan-500/10 text-cyan-200"
        : "border-white/10 bg-white/5 text-zinc-400";
        
  return (
    <div className="flex items-center gap-2">
      <span className={cx("rounded-full border px-2.5 py-0.5 text-[10px] uppercase tracking-wider", cls)}>
        {role || "—"}
      </span>
      {isAdmin && <span className="text-[9px] font-black text-emerald-500/80 uppercase tracking-widest whitespace-nowrap">Master Architect</span>}
    </div>
  );
}

function RoleSelector({ value, onChange, disabled }: { value: string; onChange: (val: string) => void; disabled?: boolean }) {
  const [isOpen, setIsOpen] = useState(false);
  const roles = [
    { id: "user", label: "User", icon: User, tone: "zinc" },
    { id: "dev", label: "Developer", icon: Code, tone: "cyan" },
    { id: "devl", label: "Dev L", icon: Zap, tone: "cyan" },
    { id: "admin", label: "Admin", icon: Shield, tone: "emerald" },
  ];

  const current = roles.find(r => r.id === (value || "user").toLowerCase()) || roles[0];

  return (
    <div className="relative">
      <button
        onClick={() => !disabled && setIsOpen(!isOpen)}
        disabled={disabled}
        className={cx(
          "gf-btn flex items-center gap-3 h-10 px-4 rounded-xl border border-white/10 bg-white/5 hover:bg-white/10 transition-all",
          disabled && "opacity-50 cursor-not-allowed",
          isOpen && "ring-2 ring-indigo-500/50 border-indigo-500/50"
        )}
      >
        <current.icon size={14} className={cx(
          current.tone === "emerald" ? "text-emerald-400" : current.tone === "cyan" ? "text-cyan-400" : "text-zinc-400"
        )} />
        <span className="text-xs font-bold text-white tracking-wide">{current.label}</span>
        <ChevronDown size={14} className={cx("text-zinc-500 transition-transform duration-300", isOpen && "rotate-180")} />
      </button>

      <AnimatePresence>
        {isOpen && (
          <>
            <div className="fixed inset-0 z-40" onClick={() => setIsOpen(false)} />
            <motion.div
              initial={{ opacity: 0, y: 10, scale: 0.95 }}
              animate={{ opacity: 1, y: 0, scale: 1 }}
              exit={{ opacity: 0, y: 10, scale: 0.95 }}
              className="absolute right-0 top-full mt-2 w-48 z-50 rounded-2xl border border-white/10 bg-[#16161c]/95 backdrop-blur-2xl p-2 shadow-2xl overflow-hidden"
            >
              <div className="absolute inset-0 bg-gradient-to-br from-indigo-500/5 via-transparent to-transparent pointer-events-none" />
              {roles.map((r) => (
                <button
                  key={r.id}
                  onClick={() => {
                    onChange(r.id);
                    setIsOpen(false);
                  }}
                  className={cx(
                    "w-full flex items-center gap-3 px-3 py-2.5 rounded-xl transition-all group",
                    value === r.id ? "bg-white/10 text-white" : "text-zinc-400 hover:bg-white/5 hover:text-white"
                  )}
                >
                  <div className={cx(
                    "flex h-8 w-8 items-center justify-center rounded-lg border border-white/5",
                    r.tone === "emerald" ? "bg-emerald-500/10 text-emerald-400" : r.tone === "cyan" ? "bg-cyan-500/10 text-cyan-400" : "bg-white/5 text-zinc-500"
                  )}>
                    <r.icon size={16} />
                  </div>
                  <div className="text-left">
                    <div className="text-xs font-bold tracking-tight">{r.label}</div>
                    <div className="text-[9px] uppercase tracking-widest opacity-40 font-black">
                      {r.id === "admin" ? "High Power" : "Limited Access"}
                    </div>
                  </div>
                  {value === r.id && (
                    <div className="ml-auto h-1.5 w-1.5 rounded-full bg-indigo-500 shadow-[0_0_8px_rgba(99,102,241,0.8)]" />
                  )}
                </button>
              ))}
            </motion.div>
          </>
        )}
      </AnimatePresence>
    </div>
  );
}

export default function UsersPage() {
  return (
    <Suspense fallback={null}>
      <UsersPageInner />
    </Suspense>
  );
}

function UsersPageInner() {
  const toast = useToast();
  const searchParams = useSearchParams();
  const token = useMemo(() => getToken(), []);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const [drawerOpen, setDrawerOpen] = useState(false);
  const [drawerMounted, setDrawerMounted] = useState(false);
  const [drawerUser, setDrawerUser] = useState<UserRow | null>(null);
  const [drawerLoading, setDrawerLoading] = useState(false);
  const [drawerError, setDrawerError] = useState<string | null>(null);
  const [drawerProjects, setDrawerProjects] = useState<Paged<ProjectRow> | null>(null);
  const [drawerBuilds, setDrawerBuilds] = useState<Paged<BuildRow> | null>(null);

  const [q, setQ] = useState(() => searchParams.get("q") || "");
  const [role, setRole] = useState(() => searchParams.get("role") || "");
  const [page, setPage] = useState(1);
  const [data, setData] = useState<Paged<UserRow> | null>(null);
  const [busyId, setBusyId] = useState<string | null>(null);
  const [confirm, setConfirm] = useState<null | { id: string; action: "ban" | "unban" | "delete"; label?: string }>(null);

  async function load() {
    if (!token) return;
    setLoading(true);
    setError(null);
    try {
      const qs = new URLSearchParams();
      qs.set("page", String(page));
      qs.set("limit", "20");
      if (q.trim()) qs.set("q", q.trim());
      if (role.trim()) qs.set("role", role.trim());
      const res = await apiFetch<Paged<UserRow>>(`/admin/users?${qs.toString()}`, { method: "GET", token });
      setData(res);
    } catch (e: any) {
      const msg = e?.message || "Failed to load users";
      setError(msg);
      if (e instanceof ApiError && (e.status === 401 || e.status === 403)) {
        clearToken();
      }
    } finally {
      setLoading(false);
    }
  }

  async function openDrawer(u: UserRow) {
    setDrawerMounted(true);
    setDrawerOpen(true);
    setDrawerUser(u);
    setDrawerError(null);
    setDrawerLoading(true);
    try {
      if (!token) return;
      const qs = new URLSearchParams();
      qs.set("page", "1");
      qs.set("limit", "8");
      qs.set("ownerId", u.id);
      const [projects, builds] = await Promise.all([
        apiFetch<Paged<ProjectRow>>(`/admin/projects?${qs.toString()}`, { method: "GET", token }),
        apiFetch<Paged<BuildRow>>(`/admin/builds?${qs.toString()}`, { method: "GET", token }),
      ]);
      setDrawerProjects(projects);
      setDrawerBuilds(builds);
    } catch (e: any) {
      const msg = e?.message || "Failed to load user details";
      setDrawerError(msg);
    } finally {
      setDrawerLoading(false);
    }
  }

  function closeDrawer() {
    setDrawerOpen(false);
    // Keep mounted briefly to allow exit animation.
    setTimeout(() => {
      setDrawerMounted(false);
      setDrawerUser(null);
      setDrawerProjects(null);
      setDrawerBuilds(null);
      setDrawerError(null);
      setDrawerLoading(false);
    }, 180);
  }

  useEffect(() => {
    if (!drawerMounted) return;
    const prev = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => {
      document.body.style.overflow = prev;
    };
  }, [drawerMounted]);

  useEffect(() => {
    if (!drawerMounted) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") {
        e.preventDefault();
        closeDrawer();
      }
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [drawerMounted]);

  async function doUserAction(userId: string, action: "ban" | "unban" | "delete") {
    if (!token) return;
    setBusyId(userId);
    setError(null);
    try {
      if (action === "delete") {
        await apiFetch(`/admin/users/${encodeURIComponent(userId)}`, { method: "DELETE", token });
        toast.success("User deleted");
      } else {
        await apiFetch(`/admin/users/${encodeURIComponent(userId)}/active`, {
          method: "PATCH",
          token,
          body: { isActive: action === "unban" },
        });
        toast.success(action === "ban" ? "User banned" : "User unbanned");
      }
      await load();
    } catch (e: any) {
      const msg = e?.message || "Action failed";
      setError(msg);
      toast.error("Action failed", msg);
    } finally {
      setBusyId(null);
    }
  }

  useEffect(() => {
    load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [page, q, role]);

  useEffect(() => {
    const nextQ = searchParams.get("q") || "";
    const nextRole = searchParams.get("role") || "";
    setQ(nextQ);
    setRole(nextRole);
    setPage(1);
    setTimeout(() => {
      load();
    }, 0);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [searchParams]);

  async function setUserRole(userId: string, nextRole: string) {
    if (!token) return;
    setBusyId(userId);
    setError(null);
    try {
      await apiFetch(`/admin/users/${encodeURIComponent(userId)}/role`, {
        method: "PATCH",
        token,
        body: { role: nextRole },
      });
      toast.success("Role updated", `New role: ${nextRole}`);
      await load();
    } catch (e: any) {
      const msg = e?.message || "Failed to update role";
      setError(msg);
      toast.error("Failed", msg);
    } finally {
      setBusyId(null);
    }
  }

  const total = data?.total ?? 0;
  const totalPages = Math.max(1, Math.ceil(total / (data?.limit || 20)));

  return (
    <AdminShell
      title="Users"
      right={
        <div className="flex items-center gap-2">
          <NeonChip tone="emerald">
            <span className="font-mono">ACCESS</span>
            <span className="text-white">USERS</span>
          </NeonChip>
          <input
            value={q}
            onChange={(e) => setQ(e.target.value)}
            placeholder="Search email / username"
            className="gf-input h-9 w-56 rounded-xl px-3 text-sm placeholder:text-zinc-500"
          />
          <select
            value={role}
            onChange={(e) => setRole(e.target.value)}
            className="gf-input h-9 rounded-xl px-3 text-sm"
          >
            <option value="">All roles</option>
            <option value="user">user</option>
            <option value="dev">dev</option>
            <option value="admin">admin</option>
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
              "radial-gradient(circle at 20% 0%, rgba(34,211,238,0.18), transparent 55%), radial-gradient(circle at 80% 100%, rgba(16,185,129,0.16), transparent 55%)",
          }}
        />
        <div className="pointer-events-none absolute inset-0 opacity-20" style={{ backgroundImage: "repeating-linear-gradient(to bottom, rgba(255,255,255,0.10), rgba(255,255,255,0.10) 1px, transparent 1px, transparent 7px)" }} />
        <div className="relative flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <NeonChip tone="emerald">ACCESS CONTROL</NeonChip>
            <div className="mt-2 text-sm text-zinc-400">Roles, bans, and user drilldown</div>
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
        <div className="gf-table-head grid grid-cols-[1.2fr_0.9fr_0.7fr_0.7fr_0.8fr_1fr] gap-0 border-b border-white/10 px-4 py-3 text-xs font-medium text-zinc-400">
          <div>Email</div>
          <div>Username</div>
          <div>Plan</div>
          <div>Role</div>
          <div>Status</div>
          <div className="text-right">Actions</div>
        </div>

        {(loading ? Array.from({ length: 8 }) : data?.items || []).map((u: any, idx: number) => (
          <div
            key={u?.id || idx}
            className="gf-row gf-tr grid grid-cols-[1.2fr_0.9fr_0.7fr_0.7fr_0.8fr_1fr] items-center gap-0 px-4 py-3 text-sm text-zinc-200"
          >
            <div className="truncate">
              {loading ? <div className="h-4 w-40 animate-pulse rounded bg-white/10" /> : u.email || "—"}
            </div>
            <div className="truncate">
              {loading ? <div className="h-4 w-28 animate-pulse rounded bg-white/10" /> : u.username || "—"}
            </div>
            <div>{loading ? <div className="h-4 w-16 animate-pulse rounded bg-white/10" /> : u.subscription || "—"}</div>
            <div>{loading ? <div className="h-4 w-14 animate-pulse rounded bg-white/10" /> : <RolePill role={u.role} />}</div>
            <div>{loading ? <div className="h-4 w-16 animate-pulse rounded bg-white/10" /> : <ActivePill isActive={u.isActive} />}</div>
            <div className="flex justify-end">
              {loading ? (
                <div className="h-9 w-28 animate-pulse rounded-xl bg-white/10" />
              ) : (
                <div className="flex items-center gap-2">
                  <button
                    disabled={busyId === u.id}
                    onClick={() => openDrawer(u)}
                    className="gf-btn h-9 rounded-xl px-3 text-xs disabled:opacity-50"
                  >
                    Details
                  </button>
                  <RoleSelector
                    disabled={busyId === u.id}
                    value={(u.role || "").toLowerCase()}
                    onChange={(val) => setUserRole(u.id, val)}
                  />
                  <button
                    disabled={busyId === u.id}
                    onClick={() =>
                      setConfirm({
                        id: u.id,
                        action: u.isActive ? "ban" : "unban",
                        label: u.email || u.username || u.id,
                      })
                    }
                    className="gf-btn h-9 rounded-xl px-3 text-xs disabled:opacity-50"
                  >
                    {u.isActive ? "Ban" : "Unban"}
                  </button>
                  <button
                    disabled={busyId === u.id}
                    onClick={() => setConfirm({ id: u.id, action: "delete", label: u.email || u.username || u.id })}
                    className="gf-btn gf-btn-danger h-9 rounded-xl px-3 text-xs disabled:opacity-50"
                  >
                    Delete
                  </button>
                </div>
              )}
            </div>
          </div>
        ))}
      </div>

      {drawerMounted ? (
        <div className="fixed inset-0 z-[150]">
          <div
            className={
              "absolute inset-0 bg-black/70 backdrop-blur-sm transition-opacity duration-200 " +
              (drawerOpen ? "opacity-100" : "opacity-0")
            }
            onClick={closeDrawer}
          />
          <div
            className={
              "gf-panel-strong absolute right-0 top-0 h-full w-full max-w-[720px] overflow-hidden border-l border-white/10 " +
              "rounded-none sm:rounded-l-2xl transition-transform duration-200 will-change-transform " +
              (drawerOpen ? "translate-x-0" : "translate-x-full")
            }
          >
            <div className="flex items-center justify-between border-b border-white/10 px-5 py-4">
              <div className="min-w-0">
                <h3 className="truncate text-sm font-semibold text-white">
                  {drawerUser?.username || drawerUser?.email || drawerUser?.id || "User"}
                </h3>
                <p className="mt-1 truncate text-xs text-zinc-500">{drawerUser?.email || "—"}</p>
              </div>
              <div className="flex items-center gap-2">
                <button
                  className="gf-btn h-9 rounded-xl px-3 text-xs"
                  disabled={drawerLoading}
                  onClick={() => (drawerUser ? openDrawer(drawerUser) : null)}
                >
                  Refresh
                </button>
                <button className="gf-btn h-9 rounded-xl px-3 text-xs" onClick={closeDrawer}>
                  Close
                </button>
              </div>
            </div>

            {drawerError ? (
              <div className="mx-5 mt-4 rounded-xl border border-red-400/20 bg-red-500/10 px-4 py-3 text-sm text-red-200">
                {drawerError}
              </div>
            ) : null}

            <div className="gf-scrollbar h-[calc(100vh-70px)] overflow-auto">
              <div className="grid grid-cols-1 gap-4 px-5 py-5 lg:grid-cols-3">
              <div className="gf-card rounded-2xl p-4 lg:col-span-1">
                <div className="text-xs font-medium text-zinc-400">Profile</div>
                <div className="mt-3 space-y-2 text-sm text-zinc-200">
                  <div className="flex items-center justify-between">
                    <div className="text-zinc-500">Role</div>
                    <RolePill role={drawerUser?.role} />
                  </div>
                  <div className="flex items-center justify-between">
                    <div className="text-zinc-500">Status</div>
                    <ActivePill isActive={drawerUser?.isActive} />
                  </div>
                  <div className="flex items-center justify-between">
                    <div className="text-zinc-500">Plan</div>
                    <div className="text-zinc-200">{drawerUser?.subscription || "—"}</div>
                  </div>
                </div>

                <div className="mt-4 grid grid-cols-2 gap-2">
                  <button
                    disabled={!drawerUser || busyId === drawerUser.id}
                    onClick={() =>
                      drawerUser
                        ? setConfirm({
                            id: drawerUser.id,
                            action: drawerUser.isActive ? "ban" : "unban",
                            label: drawerUser.email || drawerUser.username || drawerUser.id,
                          })
                        : null
                    }
                    className="gf-btn h-9 rounded-xl px-3 text-xs disabled:opacity-50"
                  >
                    {drawerUser?.isActive ? "Ban" : "Unban"}
                  </button>
                  <button
                    disabled={!drawerUser || busyId === drawerUser.id}
                    onClick={() =>
                      drawerUser
                        ? setConfirm({
                            id: drawerUser.id,
                            action: "delete",
                            label: drawerUser.email || drawerUser.username || drawerUser.id,
                          })
                        : null
                    }
                    className="gf-btn gf-btn-danger h-9 rounded-xl px-3 text-xs disabled:opacity-50"
                  >
                    Delete
                  </button>
                </div>
              </div>

              <div className="gf-card rounded-2xl p-4 lg:col-span-2">
                <div className="flex items-center justify-between">
                  <div className="text-xs font-medium text-zinc-400">Projects</div>
                  <div className="text-xs text-zinc-500">{drawerProjects?.total != null ? `Total: ${drawerProjects.total}` : ""}</div>
                </div>

                <div className="mt-3 space-y-2">
                  {(drawerLoading ? Array.from({ length: 4 }) : drawerProjects?.items || []).map((p: any, idx: number) => (
                    <div
                      key={p?.id || idx}
                      className="flex items-center justify-between rounded-xl border border-white/10 bg-black/20 px-3 py-2"
                    >
                      <div className="min-w-0">
                        <div className="truncate text-sm text-white">{drawerLoading ? "…" : p.name || "—"}</div>
                        <div className="truncate text-xs text-zinc-500">
                          {drawerLoading ? "" : `${p.status || "—"} • ${p.buildTarget || "—"}`}
                        </div>
                      </div>
                      <button
                        className="gf-btn h-9 rounded-xl px-3 text-xs"
                        onClick={() => toast.info("Tip", "Open Projects page for rebuild/cancel/clear")}
                      >
                        Open
                      </button>
                    </div>
                  ))}
                </div>

                <div className="mt-4 border-t border-white/10 pt-4">
                  <div className="flex items-center justify-between">
                    <div className="text-xs font-medium text-zinc-400">Builds</div>
                    <div className="text-xs text-zinc-500">{drawerBuilds?.total != null ? `Total: ${drawerBuilds.total}` : ""}</div>
                  </div>
                  <div className="mt-3 space-y-2">
                    {(drawerLoading ? Array.from({ length: 4 }) : drawerBuilds?.items || []).map((b: any, idx: number) => (
                      <div
                        key={b?.id || idx}
                        className="flex items-center justify-between rounded-xl border border-white/10 bg-black/20 px-3 py-2"
                      >
                        <div className="min-w-0">
                          <div className="truncate text-sm text-white">{drawerLoading ? "…" : b.name || "—"}</div>
                          <div className="truncate text-xs text-zinc-500">
                            {drawerLoading ? "" : `${b.status || "—"} • ${b.buildTarget || "—"}`}
                          </div>
                        </div>
                        <button
                          className="gf-btn h-9 rounded-xl px-3 text-xs"
                          onClick={() => toast.info("Tip", "Open Builds page for rebuild/cancel")}
                        >
                          Open
                        </button>
                      </div>
                    ))}
                  </div>
                </div>
              </div>
              </div>
            </div>
          </div>
        </div>
      ) : null}

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
          <div className="gf-input rounded-xl px-3 py-2 text-xs">
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
          confirm?.action === "delete" ? "Delete user?" : confirm?.action === "ban" ? "Ban user?" : "Unban user?"
        }
        description={confirm?.label ? `User: ${confirm.label}` : undefined}
        confirmText={confirm?.action === "delete" ? "Delete" : confirm?.action === "ban" ? "Ban" : "Unban"}
        confirmTone={confirm?.action === "delete" ? "danger" : confirm?.action === "ban" ? "danger" : "default"}
        busy={Boolean(confirm?.id && busyId === confirm.id)}
        onCancel={() => setConfirm(null)}
        onConfirm={async () => {
          if (!confirm) return;
          const { id, action } = confirm;
          setConfirm(null);
          await doUserAction(id, action);

          // Keep drawer state in sync after actions.
          if (drawerUser && drawerUser.id === id) {
            const next: UserRow = { ...drawerUser };
            if (action === "ban") next.isActive = false;
            if (action === "unban") next.isActive = true;
            if (action === "delete") {
              closeDrawer();
              return;
            }
            setDrawerUser(next);
          }
        }}
      />
    </AdminShell>
  );
}
