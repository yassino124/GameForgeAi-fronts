"use client";

import { useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import AdminShell from "@/app/_components/AdminShell";
import { NeonChip, PulseDot } from "@/app/_components/Hud";
import { apiFetch, ApiError } from "@/lib/api";
import { getToken } from "@/lib/auth";
import { useToast } from "@/app/_components/ToastProvider";

type UserRow = {
  id: string;
  email?: string;
  username?: string;
  fullName?: string;
  role?: string;
  isActive?: boolean;
};

type Paged<T> = { page: number; limit: number; total: number; items: T[] };

type TargetMode = "all" | "role" | "users";

type SendPayload = {
  title: string;
  message: string;
  type: "info" | "success" | "warning" | "error";
  data?: any;
  target: { type: TargetMode; roles?: string[]; userIds?: string[] };
};

type PersonalNotification = {
  id?: string;
  _id?: string;
  title?: string;
  message?: string;
  type?: string;
  isRead?: boolean;
  read?: boolean;
  createdAt?: string;
  data?: any;
};

function cx(...parts: Array<string | false | null | undefined>) {
  return parts.filter(Boolean).join(" ");
}

function userLabel(u: UserRow) {
  const a = (u.fullName || u.username || u.email || "").trim();
  return a || u.id;
}

export default function NotificationsAdminPage() {
  const router = useRouter();
  const toast = useToast();
  const token = useMemo(() => getToken(), []);

  const [mode, setMode] = useState<TargetMode>("all");
  const [roles, setRoles] = useState<string[]>(["user"]);
  const [q, setQ] = useState("");
  const [usersLoading, setUsersLoading] = useState(false);
  const [usersError, setUsersError] = useState<string | null>(null);
  const [users, setUsers] = useState<UserRow[]>([]);
  const [selected, setSelected] = useState<UserRow[]>([]);

  const [title, setTitle] = useState("");
  const [message, setMessage] = useState("");
  const [type, setType] = useState<SendPayload["type"]>("info");
  const [sending, setSending] = useState(false);
  const [sendError, setSendError] = useState<string | null>(null);
  const [personalLoading, setPersonalLoading] = useState(false);
  const [personalNotifs, setPersonalNotifs] = useState<PersonalNotification[]>([]);

  async function searchUsers() {
    if (!token) return;
    setUsersLoading(true);
    setUsersError(null);
    try {
      const qs = new URLSearchParams();
      qs.set("page", "1");
      qs.set("limit", "30");
      if (q.trim()) qs.set("q", q.trim());
      const res = await apiFetch<Paged<UserRow>>(`/admin/users?${qs.toString()}`, { method: "GET", token });
      setUsers(res.items || []);
    } catch (e: any) {
      const msg = e?.message || "Failed to search users";
      setUsersError(msg);
    } finally {
      setUsersLoading(false);
    }
  }

  useEffect(() => {
    if (mode !== "users") return;
    const t = setTimeout(() => {
      searchUsers();
    }, 250);
    return () => clearTimeout(t);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [mode, q]);

  async function loadPersonalNotifications() {
    if (!token) return;
    setPersonalLoading(true);
    try {
      const res = await apiFetch<PersonalNotification[]>("/notifications", {
        method: "GET",
        token,
      });
      setPersonalNotifs(Array.isArray(res) ? res : []);
    } catch {
      // non-blocking for composer
    } finally {
      setPersonalLoading(false);
    }
  }

  useEffect(() => {
    loadPersonalNotifications();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [token]);

  async function openNotification(n: PersonalNotification) {
    const id = String(n._id || n.id || "").trim();
    if (id) {
      try {
        await apiFetch(`/notifications/${encodeURIComponent(id)}`, {
          method: "PATCH",
          token,
          body: { isRead: true },
        });
      } catch {
        // ignore read-state error
      }
      setPersonalNotifs((prev) =>
        prev.map((x) => {
          const xid = String(x._id || x.id || "").trim();
          return xid === id ? { ...x, isRead: true, read: true } : x;
        }),
      );
    }

    const route = String(n?.data?.route || "").trim();
    const ticketId = String(n?.data?.ticketId || "").trim();

    if (ticketId) {
      router.push(`/messages?ticketId=${encodeURIComponent(ticketId)}`);
      return;
    }
    if (route.startsWith("/")) {
      if (route === "/messages") {
        router.push("/messages");
      } else {
        router.push(route);
      }
      return;
    }
    router.push("/messages");
  }

  function toggleSelect(u: UserRow) {
    setSelected((prev) => {
      const exists = prev.some((x) => x.id === u.id);
      if (exists) return prev.filter((x) => x.id !== u.id);
      return [...prev, u].slice(0, 50);
    });
  }

  async function send() {
    if (!token) return;
    setSendError(null);

    const t = title.trim();
    const m = message.trim();
    if (!t) {
      setSendError("Missing title");
      return;
    }
    if (!m) {
      setSendError("Missing message");
      return;
    }

    const payload: SendPayload = {
      title: t,
      message: m,
      type,
      target:
        mode === "all"
          ? { type: "all" }
          : mode === "role"
            ? { type: "role", roles }
            : { type: "users", userIds: selected.map((u) => u.id) },
    };

    if (payload.target.type === "role" && (!payload.target.roles || !payload.target.roles.length)) {
      setSendError("Pick at least 1 role");
      return;
    }
    if (payload.target.type === "users" && (!payload.target.userIds || !payload.target.userIds.length)) {
      setSendError("Select at least 1 user");
      return;
    }

    setSending(true);
    try {
      const res = await apiFetch<{ created?: number; sent?: number; failed?: number }>("/admin/notifications/send", {
        method: "POST",
        token,
        body: payload,
      });

      toast.success("Notification queued", `created ${res?.created ?? 0}`);
      setTitle("");
      setMessage("");
      setSelected([]);
    } catch (e: any) {
      const msg = e?.message || "Send failed";
      setSendError(msg);
      if (e instanceof ApiError && (e.status === 401 || e.status === 403)) {
        toast.error("Auth", "Not authorized");
      } else {
        toast.error("Send failed", msg);
      }
    } finally {
      setSending(false);
    }
  }

  function setRoleChecked(r: string, on: boolean) {
    setRoles((prev) => {
      const s = new Set(prev);
      if (on) s.add(r);
      else s.delete(r);
      return Array.from(s);
    });
  }

  const tone = sending ? "cyan" : sendError ? "amber" : "emerald";

  return (
    <AdminShell
      title="Notifications"
      subtitle="Broadcast / role / selected users"
      right={
        <div className="flex items-center gap-2">
          <NeonChip tone={tone as any}>
            <PulseDot tone={tone as any} />
            <span className="font-mono">PUSH</span>
            <span className="text-white">{sending ? "sending…" : sendError ? "degraded" : "ready"}</span>
          </NeonChip>
        </div>
      }
    >
      <div className="gf-card relative overflow-hidden rounded-2xl border border-white/10 p-5">
        <div
          className="pointer-events-none absolute inset-0 opacity-50"
          style={{
            backgroundImage:
              "radial-gradient(circle at 20% 0%, rgba(34,211,238,0.18), transparent 55%), radial-gradient(circle at 80% 100%, rgba(236,72,153,0.16), transparent 55%)",
          }}
        />

        <div className="relative grid grid-cols-1 gap-4 lg:grid-cols-[1.1fr_0.9fr]">
          <div className="rounded-2xl border border-white/10 bg-black/20 p-4">
            <div className="flex items-center justify-between">
              <div className="text-xs font-semibold text-zinc-200">Composer</div>
              <NeonChip tone="zinc">
                <span className="font-mono">MODE</span>
                <span className="text-white">{mode}</span>
              </NeonChip>
            </div>

            {sendError ? (
              <div className="mt-3 rounded-xl border border-amber-400/20 bg-amber-500/10 px-3 py-2 text-xs text-amber-100">
                {sendError}
              </div>
            ) : null}

            <div className="mt-4 grid grid-cols-1 gap-3">
              <div className="grid grid-cols-1 gap-2 sm:grid-cols-3">
                <button
                  className={cx(
                    "gf-btn h-10 rounded-xl px-3 text-sm",
                    mode === "all" ? "border-white/20 bg-white/10" : "",
                  )}
                  onClick={() => setMode("all")}
                  type="button"
                >
                  All users
                </button>
                <button
                  className={cx(
                    "gf-btn h-10 rounded-xl px-3 text-sm",
                    mode === "role" ? "border-white/20 bg-white/10" : "",
                  )}
                  onClick={() => setMode("role")}
                  type="button"
                >
                  By role
                </button>
                <button
                  className={cx(
                    "gf-btn h-10 rounded-xl px-3 text-sm",
                    mode === "users" ? "border-white/20 bg-white/10" : "",
                  )}
                  onClick={() => setMode("users")}
                  type="button"
                >
                  Selected
                </button>
              </div>

              {mode === "role" ? (
                <div className="rounded-2xl border border-white/10 bg-black/20 p-3">
                  <div className="text-xs font-medium text-zinc-400">Roles</div>
                  <div className="mt-2 flex flex-wrap gap-2">
                    {["user", "dev", "admin"].map((r) => {
                      const on = roles.includes(r);
                      return (
                        <button
                          key={r}
                          className={cx(
                            "gf-btn rounded-xl px-3 py-2 text-xs",
                            on ? "border-white/20 bg-white/10" : "",
                          )}
                          onClick={() => setRoleChecked(r, !on)}
                          type="button"
                        >
                          {r}
                        </button>
                      );
                    })}
                  </div>
                </div>
              ) : null}

              <div className="grid grid-cols-1 gap-2 sm:grid-cols-3">
                <input
                  value={title}
                  onChange={(e) => setTitle(e.target.value)}
                  placeholder="Title"
                  className="gf-input h-10 rounded-xl px-3 text-sm placeholder:text-zinc-500 sm:col-span-2"
                />
                <select value={type} onChange={(e) => setType(e.target.value as any)} className="gf-input h-10 rounded-xl px-3 text-sm">
                  <option value="info">info</option>
                  <option value="success">success</option>
                  <option value="warning">warning</option>
                  <option value="error">error</option>
                </select>
              </div>

              <textarea
                value={message}
                onChange={(e) => setMessage(e.target.value)}
                placeholder="Message"
                className="gf-input min-h-[120px] rounded-xl px-3 py-2 text-sm placeholder:text-zinc-500"
              />

              <div className="flex items-center justify-between gap-2">
                <div className="text-xs text-zinc-500">Tip: keep it short. Mobile push truncates long text.</div>
                <button className="gf-btn h-10 rounded-xl px-4 text-sm" onClick={send} disabled={sending}>
                  Send
                </button>
              </div>
            </div>
          </div>

          <div className="rounded-2xl border border-white/10 bg-black/20 p-4">
            <div className="flex items-center justify-between">
              <div className="text-xs font-semibold text-zinc-200">Target</div>
              <NeonChip tone="zinc">
                <span className="font-mono">COUNT</span>
                <span className="text-white">{mode === "users" ? selected.length : mode === "role" ? roles.length : "—"}</span>
              </NeonChip>
            </div>

            {mode === "users" ? (
              <div className="mt-3">
                <input
                  value={q}
                  onChange={(e) => setQ(e.target.value)}
                  placeholder="Search users…"
                  className="gf-input h-10 w-full rounded-xl px-3 text-sm placeholder:text-zinc-500"
                />

                {usersError ? (
                  <div className="mt-3 rounded-xl border border-amber-400/20 bg-amber-500/10 px-3 py-2 text-xs text-amber-100">
                    {usersError}
                  </div>
                ) : null}

                <div className="mt-3 max-h-[360px] overflow-auto rounded-2xl border border-white/10 bg-black/30 p-2">
                  {(usersLoading ? Array.from({ length: 6 }) : users).map((u: any, idx: number) => {
                    const id = u?.id || String(idx);
                    const on = selected.some((x) => x.id === id);
                    return (
                      <button
                        key={id}
                        className={cx(
                          "w-full rounded-xl px-3 py-2 text-left transition",
                          on ? "border border-white/15 bg-white/10" : "border border-transparent hover:border-white/10 hover:bg-white/5",
                        )}
                        onClick={() => (usersLoading ? null : toggleSelect(u))}
                        type="button"
                      >
                        <div className="flex items-center justify-between gap-3">
                          <div className="min-w-0">
                            <div className="truncate text-sm text-white">{usersLoading ? "…" : userLabel(u)}</div>
                            <div className="truncate text-[11px] text-zinc-500">{usersLoading ? "" : `${u.email || ""} • ${u.role || "user"}`}</div>
                          </div>
                          <div className="shrink-0 text-[11px] text-zinc-500">{on ? "selected" : "pick"}</div>
                        </div>
                      </button>
                    );
                  })}
                </div>

                {selected.length ? (
                  <div className="mt-3 rounded-2xl border border-white/10 bg-black/20 p-3">
                    <div className="text-xs font-medium text-zinc-400">Selected users</div>
                    <div className="mt-2 flex flex-wrap gap-2">
                      {selected.slice(0, 16).map((u) => (
                        <button
                          key={u.id}
                          className="gf-btn rounded-xl px-3 py-1.5 text-xs"
                          onClick={() => toggleSelect(u)}
                          type="button"
                        >
                          {userLabel(u)}
                        </button>
                      ))}
                      {selected.length > 16 ? <span className="text-xs text-zinc-500">+{selected.length - 16}</span> : null}
                    </div>
                  </div>
                ) : null}
              </div>
            ) : (
              <div className="mt-3 rounded-2xl border border-white/10 bg-black/20 p-4">
                <div className="text-xs text-zinc-400">
                  {mode === "all"
                    ? "This will notify all active users with at least one registered FCM token."
                    : "This will notify all active users matching the selected roles."}
                </div>
              </div>
            )}
          </div>

          <div className="rounded-2xl border border-white/10 bg-black/20 p-4">
            <div className="flex items-center justify-between">
              <div className="text-xs font-semibold text-zinc-200">Recent personal notifications</div>
              <NeonChip tone="cyan">
                <span className="font-mono">INBOX</span>
                <span className="text-white">{personalLoading ? "…" : personalNotifs.length}</span>
              </NeonChip>
            </div>

            <div className="mt-3 max-h-[260px] space-y-2 overflow-auto pr-1">
              {personalLoading ? (
                <div className="rounded-xl border border-white/10 bg-black/20 px-3 py-2 text-xs text-zinc-400">
                  Loading notifications…
                </div>
              ) : personalNotifs.length === 0 ? (
                <div className="rounded-xl border border-white/10 bg-black/20 px-3 py-2 text-xs text-zinc-400">
                  No notifications yet.
                </div>
              ) : (
                personalNotifs.slice(0, 12).map((n, i) => {
                  const id = String(n._id || n.id || i).trim();
                  const isRead = n.isRead === true || n.read === true;
                  return (
                    <button
                      key={id}
                      type="button"
                      onClick={() => openNotification(n)}
                      className={cx(
                        "w-full rounded-xl border px-3 py-2 text-left transition",
                        isRead
                          ? "border-white/10 bg-black/20"
                          : "border-indigo-400/20 bg-indigo-500/10 hover:border-indigo-300/40",
                      )}
                    >
                      <div className="truncate text-xs font-semibold text-white">{n.title || "Notification"}</div>
                      <div className="mt-1 line-clamp-2 text-[11px] text-zinc-400">{n.message || "Open"}</div>
                      <div className="mt-1 text-[10px] uppercase tracking-wide text-zinc-500">
                        {String(n?.data?.kind || n?.type || "info")}
                      </div>
                    </button>
                  );
                })
              )}
            </div>

            <div className="mt-3 flex justify-end">
              <button
                type="button"
                className="gf-btn h-9 rounded-xl px-3 text-xs"
                onClick={() => router.push("/messages")}
              >
                Open Support Inbox
              </button>
            </div>
          </div>
        </div>
      </div>
    </AdminShell>
  );
}
