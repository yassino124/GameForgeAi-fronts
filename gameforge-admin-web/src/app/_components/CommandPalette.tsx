"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { apiFetch } from "@/lib/api";
import { getToken } from "@/lib/auth";
import { useToast } from "@/app/_components/ToastProvider";

type Hit = {
  kind: "user" | "project" | "build" | "template" | "page" | "action";
  id?: string;
  title: string;
  subtitle?: string;
  href?: string;
  actionId?: string;
  tone?: "default" | "danger";
  perform?: () => Promise<void>;
};

type Paged<T> = { items: T[] };

type UserRow = { id: string; email?: string; username?: string; role?: string; isActive?: boolean };

type ProjectRow = { id: string; name?: string; status?: string; buildTarget?: string };

type BuildRow = { id: string; name?: string; status?: string; buildTarget?: string };

type TemplateRow = { id: string; name?: string; category?: string; isPublic?: boolean };

function cx(...parts: Array<string | false | null | undefined>) {
  return parts.filter(Boolean).join(" ");
}

function useDebounced<T>(value: T, ms: number) {
  const [v, setV] = useState(value);
  useEffect(() => {
    const t = setTimeout(() => setV(value), ms);
    return () => clearTimeout(t);
  }, [value, ms]);
  return v;
}

export default function CommandPalette(props: {
  open: boolean;
  onOpenChange: (v: boolean) => void;
}) {
  const router = useRouter();
  const toast = useToast();
  const token = useMemo(() => getToken(), []);

  const [query, setQuery] = useState("");
  const q = useDebounced(query.trim(), 220);

  const [loading, setLoading] = useState(false);
  const [items, setItems] = useState<Hit[]>([]);
  const [active, setActive] = useState(0);
  const [actionBusyId, setActionBusyId] = useState<string | null>(null);

  const inputRef = useRef<HTMLInputElement | null>(null);

  const staticPages: Hit[] = useMemo(
    () => [
      { kind: "page", title: "Dashboard", subtitle: "Overview", href: "/dashboard" },
      { kind: "page", title: "Builds / Queue", subtitle: "Monitor running / failed", href: "/builds" },
      { kind: "page", title: "Projects", subtitle: "Manage projects", href: "/projects" },
      { kind: "page", title: "Support Inbox", subtitle: "Tickets / replies / SLA", href: "/messages" },
      { kind: "page", title: "Users", subtitle: "Roles & access", href: "/users" },
      { kind: "page", title: "Templates", subtitle: "Store templates", href: "/templates" },
      { kind: "page", title: "Upload Template", subtitle: "Templates • Create / upload", href: "/templates?upload=1" },
      { kind: "page", title: "Billing", subtitle: "Revenue & plans", href: "/billing" },
      { kind: "page", title: "System", subtitle: "Health metrics", href: "/system" },
    ],
    [],
  );

  useEffect(() => {
    if (!props.open) return;
    setQuery("");
    setItems(staticPages);
    setActive(0);
    setActionBusyId(null);
    const t = setTimeout(() => inputRef.current?.focus(), 0);
    return () => clearTimeout(t);
  }, [props.open, staticPages]);

  async function runAction(hit: Hit) {
    if (!hit.perform) return;
    if (!token) return;
    const id = hit.actionId || hit.id || hit.title;
    setActionBusyId(id);
    try {
      await hit.perform();
      toast.success("Done", hit.title);
      close();
    } catch (e: any) {
      const msg = e?.message || "Action failed";
      toast.error("Action failed", msg);
    } finally {
      setActionBusyId(null);
    }
  }

  useEffect(() => {
    if (!props.open) return;
    if (!token) return;

    if (!q) {
      setItems(staticPages);
      setActive(0);
      return;
    }

    let alive = true;
    setLoading(true);
    (async () => {
      try {
        const qs = new URLSearchParams();
        qs.set("page", "1");
        qs.set("limit", "6");
        qs.set("q", q);

        const [users, projects, builds, templates] = await Promise.all([
          apiFetch<Paged<UserRow>>(`/admin/users?${qs.toString()}`, { method: "GET", token }),
          apiFetch<Paged<ProjectRow>>(`/admin/projects?${qs.toString()}`, { method: "GET", token }),
          apiFetch<Paged<BuildRow>>(`/admin/builds?${qs.toString()}`, { method: "GET", token }),
          apiFetch<Paged<TemplateRow>>(`/admin/templates?${qs.toString()}`, { method: "GET", token }),
        ]);

        if (!alive) return;

        const hits: Hit[] = [];

        hits.push(...staticPages.map((p) => p));

        for (const u of (users?.items || []).slice(0, 4)) {
          hits.push({
            kind: "user",
            id: u.id,
            title: u.username || u.email || u.id,
            subtitle: `User • ${u.email || ""} • ${u.role || ""} • ${u.isActive === false ? "banned" : "active"}`.trim(),
            href: `/users?q=${encodeURIComponent(q)}`,
          });

          const currentRole = (u.role || "").toLowerCase();
          const roleTargets = ["admin", "dev", "devl", "user"];
          for (const nextRole of roleTargets) {
            if (nextRole === currentRole) continue;
            hits.push({
              kind: "action",
              id: u.id,
              actionId: `user_role_${u.id}_${nextRole}`,
              title: `Set role → ${nextRole}`,
              subtitle: `User • ${(u.email || u.username || u.id).toString()}`,
              href: `/users?q=${encodeURIComponent(q)}`,
              perform: async () => {
                await apiFetch(`/admin/users/${encodeURIComponent(u.id)}/role`, {
                  method: "PATCH",
                  token,
                  body: { role: nextRole },
                });
              },
            });
          }

          hits.push({
            kind: "action",
            id: u.id,
            actionId: `user_${u.id}_active_${u.isActive === false ? "unban" : "ban"}`,
            tone: u.isActive === false ? "default" : "danger",
            title: u.isActive === false ? "Unban user" : "Ban user",
            subtitle: `User • ${(u.email || u.username || u.id).toString()}`,
            href: `/users?q=${encodeURIComponent(q)}`,
            perform: async () => {
              await apiFetch(`/admin/users/${encodeURIComponent(u.id)}/active`, {
                method: "PATCH",
                token,
                body: { isActive: Boolean(u.isActive === false) },
              });
            },
          });

          hits.push({
            kind: "action",
            id: u.id,
            actionId: `user_${u.id}_delete`,
            tone: "danger",
            title: "Delete user",
            subtitle: `User • ${(u.email || u.username || u.id).toString()}`,
            href: `/users?q=${encodeURIComponent(q)}`,
            perform: async () => {
              await apiFetch(`/admin/users/${encodeURIComponent(u.id)}`, { method: "DELETE", token });
            },
          });
        }

        for (const p of (projects?.items || []).slice(0, 4)) {
          hits.push({
            kind: "project",
            id: p.id,
            title: p.name || p.id,
            subtitle: `Project • ${p.status || ""} • ${p.buildTarget || ""}`.trim(),
            href: `/projects?q=${encodeURIComponent(q)}`,
          });

          hits.push({
            kind: "action",
            id: p.id,
            actionId: `project_${p.id}_clear_error`,
            title: "Clear error",
            subtitle: `Project • ${(p.name || p.id).toString()}`,
            href: `/projects?q=${encodeURIComponent(q)}`,
            perform: async () => {
              await apiFetch(`/admin/projects/${encodeURIComponent(p.id)}/clear-error`, { method: "POST", token });
            },
          });

          hits.push({
            kind: "action",
            id: p.id,
            actionId: `project_${p.id}_force_failed`,
            tone: "danger",
            title: "Force status → failed",
            subtitle: `Project • ${(p.name || p.id).toString()}`,
            href: `/projects?q=${encodeURIComponent(q)}`,
            perform: async () => {
              await apiFetch(`/admin/projects/${encodeURIComponent(p.id)}/status`, {
                method: "PATCH",
                token,
                body: { status: "failed" },
              });
            },
          });
        }

        for (const b of (builds?.items || []).slice(0, 4)) {
          hits.push({
            kind: "build",
            id: b.id,
            title: b.name || b.id,
            subtitle: `Build • ${b.status || ""} • ${b.buildTarget || ""}`.trim(),
            href: `/builds?q=${encodeURIComponent(q)}`,
          });

          hits.push({
            kind: "action",
            id: b.id,
            actionId: `build_rebuild_${b.id}`,
            title: `Rebuild build`,
            subtitle: `Build • ${(b.name || b.id).toString()}`,
            href: `/builds?q=${encodeURIComponent(q)}`,
            perform: async () => {
              await apiFetch(`/admin/builds/${encodeURIComponent(b.id)}/rebuild`, { method: "POST", token });
            },
          });

          hits.push({
            kind: "action",
            id: b.id,
            actionId: `build_cancel_${b.id}`,
            tone: "danger",
            title: `Cancel build`,
            subtitle: `Build • ${(b.name || b.id).toString()}`,
            href: `/builds?q=${encodeURIComponent(q)}`,
            perform: async () => {
              await apiFetch(`/admin/builds/${encodeURIComponent(b.id)}/cancel`, { method: "POST", token });
            },
          });
        }

        for (const t of (templates?.items || []).slice(0, 4)) {
          hits.push({
            kind: "template",
            id: t.id,
            title: t.name || t.id,
            subtitle: `Template • ${t.category || ""} • ${t.isPublic ? "public" : "private"}`.trim(),
            href: `/templates?q=${encodeURIComponent(q)}`,
          });

          hits.push({
            kind: "action",
            id: t.id,
            actionId: `template_${t.id}_visibility_${t.isPublic ? "private" : "public"}`,
            title: t.isPublic ? "Make template private" : "Make template public",
            subtitle: `Template • ${(t.name || t.id).toString()}`,
            href: `/templates?q=${encodeURIComponent(q)}`,
            perform: async () => {
              await apiFetch(`/admin/templates/${encodeURIComponent(t.id)}/public`, {
                method: "PATCH",
                token,
                body: { isPublic: Boolean(!t.isPublic) },
              });
            },
          });

          hits.push({
            kind: "action",
            id: t.id,
            actionId: `template_${t.id}_delete`,
            tone: "danger",
            title: "Delete template",
            subtitle: `Template • ${(t.name || t.id).toString()}`,
            href: `/templates?q=${encodeURIComponent(q)}`,
            perform: async () => {
              await apiFetch(`/admin/templates/${encodeURIComponent(t.id)}`, { method: "DELETE", token });
            },
          });
        }

        // Dedupe by href+title
        const seen = new Set<string>();
        const deduped = hits.filter((h) => {
          const k = `${h.kind}::${h.actionId || ""}::${h.href || ""}::${h.title}`;
          if (seen.has(k)) return false;
          seen.add(k);
          return true;
        });

        setItems(deduped);
        setActive(0);
      } catch {
        if (!alive) return;
        setItems(staticPages);
      } finally {
        if (alive) setLoading(false);
      }
    })();

    return () => {
      alive = false;
    };
  }, [props.open, q, staticPages, token]);

  function close() {
    props.onOpenChange(false);
  }

  function go(hit: Hit) {
    if (hit.kind === "action") {
      runAction(hit);
      return;
    }
    if (hit.href) router.push(hit.href);
    close();
  }

  function hitKey(h: Hit) {
    if (h.kind !== "action") return `${h.kind}::${h.href || ""}::${h.title}`;
    return `action::${h.actionId || h.id || h.title}`;
  }

  useEffect(() => {
    if (!props.open) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") {
        e.preventDefault();
        close();
        return;
      }
      if (e.key === "ArrowDown") {
        e.preventDefault();
        setActive((a) => Math.min(items.length - 1, a + 1));
        return;
      }
      if (e.key === "ArrowUp") {
        e.preventDefault();
        setActive((a) => Math.max(0, a - 1));
        return;
      }
      if (e.key === "Enter") {
        e.preventDefault();
        const h = items[active];
        if (h) go(h);
        return;
      }
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [active, items, props.open]);

  if (!props.open) return null;

  return (
    <div className="fixed inset-0 z-[140] flex items-start justify-center pt-24">
      <div className="absolute inset-0 bg-black/70 backdrop-blur-sm" onClick={close} />
      <div className="gf-panel-strong relative mx-4 w-full max-w-2xl overflow-hidden rounded-2xl">
        <div className="flex items-center gap-3 border-b border-white/10 px-4 py-3">
          <div className="h-9 w-9 rounded-2xl bg-gradient-to-br from-indigo-500/25 via-fuchsia-500/20 to-cyan-500/20" />
          <input
            ref={inputRef}
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Search users, projects, builds, templates..."
            className="gf-input h-10 flex-1 rounded-xl px-3 text-sm placeholder:text-zinc-500"
          />
          <div className="rounded-lg border border-white/10 bg-black/20 px-2 py-1 text-xs text-zinc-300">
            ⌘K
          </div>
        </div>

        <div className="max-h-[420px] overflow-auto p-2">
          {loading ? (
            <div className="p-4 text-sm text-zinc-400">Searching…</div>
          ) : null}

          {items.map((h, idx) => {
            const isBusy = Boolean(actionBusyId && (h.actionId || h.id || h.title) === actionBusyId);
            const badgeTone =
              h.kind === "action" && h.tone === "danger"
                ? "border-red-400/20 bg-red-500/10 text-red-200"
                : "border-white/10 bg-black/20 text-zinc-300";
            return (
              <button
                key={hitKey(h)}
                onMouseEnter={() => setActive(idx)}
                onClick={() => {
                  if (actionBusyId) return;
                  go(h);
                }}
                disabled={Boolean(actionBusyId)}
                className={cx(
                  "flex w-full items-start justify-between gap-3 rounded-xl border px-3 py-2 text-left transition disabled:opacity-60",
                  idx === active
                    ? "border-white/15 bg-white/10"
                    : "border-transparent hover:border-white/10 hover:bg-white/5",
                )}
              >
                <div className="min-w-0">
                  <div className="truncate text-sm font-medium text-white">
                    {isBusy ? "Working… " : null}
                    {h.title}
                  </div>
                  {h.subtitle ? <div className="mt-0.5 truncate text-xs text-zinc-400">{h.subtitle}</div> : null}
                </div>
                <div className={cx("shrink-0 rounded-lg border px-2 py-1 text-[11px]", badgeTone)}>
                  {h.kind === "action" ? (h.tone === "danger" ? "action !" : "action") : h.kind}
                </div>
              </button>
            );
          })}

          {!items.length ? <div className="p-4 text-sm text-zinc-400">No results</div> : null}
        </div>

        <div className="flex items-center justify-between border-t border-white/10 px-4 py-3 text-xs text-zinc-400">
          <div>Enter to open, ↑↓ to navigate, Esc to close</div>
          <div className="rounded-lg border border-white/10 bg-black/20 px-2 py-1">Ctrl+K / ⌘K</div>
        </div>
      </div>
    </div>
  );
}
