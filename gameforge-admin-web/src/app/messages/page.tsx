"use client";

import { Suspense, useEffect, useMemo, useState } from "react";
import { useSearchParams } from "next/navigation";
import AdminShell from "@/app/_components/AdminShell";
import { apiFetch, ApiError } from "@/lib/api";
import { getToken } from "@/lib/auth";
import { useToast } from "@/app/_components/ToastProvider";

type TicketStatus = "open" | "pending" | "closed";
type TicketPriority = "low" | "normal" | "high" | "urgent";

type SupportTicket = {
  _id: string;
  userId: string;
  subject: string;
  status: TicketStatus;
  priority: TicketPriority;
  category?: string;
  assignedToUserId?: string | null;
  sla?: {
    remainingMinutes?: number;
    breached?: boolean;
  };
  updatedAt?: string;
  lastReplyAt?: string;
};

type TicketMessage = {
  _id?: string;
  ticketId: string;
  authorUserId: string;
  authorType: "user" | "support" | "system";
  body: string;
  createdAt?: string;
};

function cx(...parts: Array<string | false | null | undefined>) {
  return parts.filter(Boolean).join(" ");
}

function relTime(input?: string) {
  if (!input) return "";
  const t = new Date(input).getTime();
  if (!Number.isFinite(t)) return "";
  const diffSec = Math.max(0, Math.floor((Date.now() - t) / 1000));
  if (diffSec < 60) return "just now";
  const m = Math.floor(diffSec / 60);
  if (m < 60) return `${m}m ago`;
  const h = Math.floor(m / 60);
  if (h < 24) return `${h}h ago`;
  const d = Math.floor(h / 24);
  return `${d}d ago`;
}

function minsToHuman(v?: number) {
  const m = Number(v || 0);
  if (!Number.isFinite(m) || m <= 0) return "0m";
  if (m < 60) return `${m}m`;
  const h = Math.floor(m / 60);
  const rem = m % 60;
  if (h < 24) return rem ? `${h}h ${rem}m` : `${h}h`;
  const d = Math.floor(h / 24);
  const hr = h % 24;
  return hr ? `${d}d ${hr}h` : `${d}d`;
}

export default function SupportInboxPage() {
  return (
    <Suspense fallback={null}>
      <SupportInboxPageInner />
    </Suspense>
  );
}

function SupportInboxPageInner() {
  const toast = useToast();
  const token = useMemo(() => getToken(), []);
  const searchParams = useSearchParams();
  const preselectedTicketId = (searchParams.get("ticketId") || "").trim();

  const [loadingTickets, setLoadingTickets] = useState(false);
  const [loadingMessages, setLoadingMessages] = useState(false);
  const [sending, setSending] = useState(false);
  const [actionBusy, setActionBusy] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  const [q, setQ] = useState("");
  const [status, setStatus] = useState<"all" | TicketStatus>("all");
  const [priority, setPriority] = useState<"all" | TicketPriority>("all");

  const [tickets, setTickets] = useState<SupportTicket[]>([]);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [messages, setMessages] = useState<TicketMessage[]>([]);
  const [reply, setReply] = useState("");

  const selected = useMemo(
    () => tickets.find((t) => t._id === selectedId) ?? null,
    [tickets, selectedId],
  );

  async function loadTickets() {
    if (!token) return;
    setLoadingTickets(true);
    setError(null);
    try {
      const qs = new URLSearchParams();
      if (status !== "all") qs.set("status", status);
      if (priority !== "all") qs.set("priority", priority);
      if (q.trim()) qs.set("q", q.trim());

      const list = await apiFetch<SupportTicket[]>(`/support/tickets?${qs.toString()}`, {
        method: "GET",
        token,
      });

      const normalized = Array.isArray(list) ? list : [];
      setTickets(normalized);

      const fromNotifExists = preselectedTicketId
        ? normalized.some((x) => x._id === preselectedTicketId)
        : false;
      if (fromNotifExists) {
        setSelectedId(preselectedTicketId);
        return;
      }

      const currentExists = normalized.some((x) => x._id === selectedId);
      if (!currentExists) {
        setSelectedId(normalized.length > 0 ? normalized[0]._id : null);
      }
    } catch (e: any) {
      const msg = e instanceof ApiError ? e.message : (e?.message || "Failed to load tickets");
      setError(msg);
      toast.error("Support inbox", msg);
    } finally {
      setLoadingTickets(false);
    }
  }

  async function loadMessages(ticketId: string) {
    if (!token || !ticketId) return;
    setLoadingMessages(true);
    try {
      const list = await apiFetch<TicketMessage[]>(`/support/tickets/${encodeURIComponent(ticketId)}/messages`, {
        method: "GET",
        token,
      });
      setMessages(Array.isArray(list) ? list : []);
    } catch (e: any) {
      const msg = e instanceof ApiError ? e.message : (e?.message || "Failed to load messages");
      toast.error("Messages", msg);
      setMessages([]);
    } finally {
      setLoadingMessages(false);
    }
  }

  useEffect(() => {
    loadTickets();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [token, status, priority, preselectedTicketId]);

  useEffect(() => {
    if (!selectedId) {
      setMessages([]);
      return;
    }
    loadMessages(selectedId);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [selectedId]);

  async function sendReply() {
    if (!token || !selectedId) return;
    const body = reply.trim();
    if (!body) return;

    setSending(true);
    try {
      await apiFetch(`/support/tickets/${encodeURIComponent(selectedId)}/messages`, {
        method: "POST",
        token,
        body: { body },
      });
      setReply("");
      await Promise.all([loadMessages(selectedId), loadTickets()]);
      toast.success("Reply sent", "User received your support response");
    } catch (e: any) {
      const msg = e instanceof ApiError ? e.message : (e?.message || "Failed to send reply");
      toast.error("Reply failed", msg);
    } finally {
      setSending(false);
    }
  }

  async function updateTicket(next: { status?: TicketStatus; priority?: TicketPriority }) {
    if (!token || !selectedId) return;
    const key = `update-${selectedId}`;
    setActionBusy(key);
    try {
      await apiFetch(`/support/tickets/${encodeURIComponent(selectedId)}/status`, {
        method: "PATCH",
        token,
        body: {
          status: next.status || selected?.status || "open",
          priority: next.priority || selected?.priority || "normal",
        },
      });
      await Promise.all([loadTickets(), loadMessages(selectedId)]);
      toast.success("Ticket updated");
    } catch (e: any) {
      const msg = e instanceof ApiError ? e.message : (e?.message || "Failed to update ticket");
      toast.error("Update failed", msg);
    } finally {
      setActionBusy(null);
    }
  }

  async function assignMe() {
    if (!token || !selectedId) return;
    const key = `assign-${selectedId}`;
    setActionBusy(key);
    try {
      await apiFetch(`/support/tickets/${encodeURIComponent(selectedId)}/assign-me`, {
        method: "PATCH",
        token,
      });
      await loadTickets();
      toast.success("Assigned", "Ticket assigned to you");
    } catch (e: any) {
      const msg = e instanceof ApiError ? e.message : (e?.message || "Failed to assign ticket");
      toast.error("Assign failed", msg);
    } finally {
      setActionBusy(null);
    }
  }

  const ticketCount = tickets.length;
  const openCount = tickets.filter((t) => t.status === "open").length;

  return (
    <AdminShell
      title="Support Inbox"
      subtitle="Admin ticket center"
      right={
        <div className="flex items-center gap-2">
          <span className="rounded-full border border-cyan-400/20 bg-cyan-500/10 px-2 py-1 text-[11px] font-semibold text-cyan-200">
            {openCount} open
          </span>
          <button className="gf-btn h-9 rounded-xl px-3 text-xs" onClick={loadTickets} type="button">
            Refresh
          </button>
        </div>
      }
    >
      <div className="grid min-h-[70vh] grid-cols-1 gap-4 lg:grid-cols-[330px_1fr]">
        <div className="gf-card rounded-2xl border border-white/10 p-4">
          <div className="space-y-3">
            <input
              value={q}
              onChange={(e) => setQ(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === "Enter") loadTickets();
              }}
              placeholder="Search subject/category"
              className="w-full rounded-xl border border-white/10 bg-black/30 px-3 py-2 text-sm outline-none focus:border-blue-400/40"
            />

            <div className="grid grid-cols-2 gap-2">
              <select
                value={status}
                onChange={(e) => setStatus(e.target.value as any)}
                className="rounded-xl border border-white/10 bg-black/30 px-2 py-2 text-xs"
              >
                <option value="all">ALL STATUS</option>
                <option value="open">OPEN</option>
                <option value="pending">PENDING</option>
                <option value="closed">CLOSED</option>
              </select>
              <select
                value={priority}
                onChange={(e) => setPriority(e.target.value as any)}
                className="rounded-xl border border-white/10 bg-black/30 px-2 py-2 text-xs"
              >
                <option value="all">ALL PRIORITY</option>
                <option value="low">LOW</option>
                <option value="normal">NORMAL</option>
                <option value="high">HIGH</option>
                <option value="urgent">URGENT</option>
              </select>
            </div>

            <div className="flex items-center justify-between">
              <div className="text-xs text-zinc-400">{ticketCount} tickets</div>
              <button className="text-xs text-blue-300 hover:text-white" onClick={loadTickets} type="button">
                Apply
              </button>
            </div>

            {error ? (
              <div className="rounded-xl border border-amber-400/30 bg-amber-500/10 px-3 py-2 text-xs text-amber-100">
                {error}
              </div>
            ) : null}

            <div className="max-h-[58vh] space-y-2 overflow-auto pr-1">
              {loadingTickets && tickets.length === 0 ? (
                <div className="text-sm text-zinc-400">Loading tickets…</div>
              ) : tickets.length === 0 ? (
                <div className="rounded-xl border border-white/10 bg-white/5 px-3 py-3 text-xs text-zinc-400">
                  No tickets found.
                </div>
              ) : (
                tickets.map((t) => {
                  const isActive = t._id === selectedId;
                  return (
                    <button
                      key={t._id}
                      type="button"
                      onClick={() => setSelectedId(t._id)}
                      className={cx(
                        "w-full rounded-xl border p-3 text-left transition",
                        isActive
                          ? "border-blue-400/40 bg-blue-500/10"
                          : "border-white/10 bg-black/20 hover:border-white/20",
                      )}
                    >
                      <div className="truncate text-sm font-semibold text-white">{t.subject || "Untitled"}</div>
                      <div className="mt-2 flex flex-wrap gap-1">
                        <span className="rounded-full border border-white/15 bg-white/5 px-2 py-0.5 text-[10px] uppercase text-zinc-300">
                          {t.status}
                        </span>
                        <span className="rounded-full border border-white/15 bg-white/5 px-2 py-0.5 text-[10px] uppercase text-zinc-300">
                          {t.priority}
                        </span>
                        <span
                          className={cx(
                            "rounded-full border px-2 py-0.5 text-[10px]",
                            t.sla?.breached
                              ? "border-rose-400/30 bg-rose-500/10 text-rose-200"
                              : "border-emerald-400/20 bg-emerald-500/10 text-emerald-200",
                          )}
                        >
                          {t.sla?.breached ? "SLA breached" : `SLA ${minsToHuman(t.sla?.remainingMinutes)}`}
                        </span>
                      </div>
                      <div className="mt-2 text-[11px] text-zinc-500">{relTime(t.updatedAt || t.lastReplyAt)}</div>
                    </button>
                  );
                })
              )}
            </div>
          </div>
        </div>

        <div className="gf-card flex min-h-[70vh] flex-col rounded-2xl border border-white/10">
          {!selected ? (
            <div className="grid flex-1 place-items-center p-8 text-zinc-400">Select a ticket to open conversation.</div>
          ) : (
            <>
              <div className="border-b border-white/10 p-4">
                <div className="flex flex-wrap items-center justify-between gap-3">
                  <div>
                    <h3 className="text-lg font-bold text-white">{selected.subject}</h3>
                    <div className="mt-1 text-xs text-zinc-400">User: {selected.userId}</div>
                  </div>
                  <div className="flex flex-wrap items-center gap-2">
                    <button
                      type="button"
                      className="gf-btn h-8 rounded-lg px-2 text-xs"
                      onClick={assignMe}
                      disabled={!!actionBusy}
                    >
                      Assign me
                    </button>
                    <select
                      value={selected.status}
                      onChange={(e) => updateTicket({ status: e.target.value as TicketStatus })}
                      className="rounded-lg border border-white/15 bg-black/30 px-2 py-1 text-xs"
                      disabled={!!actionBusy}
                    >
                      <option value="open">open</option>
                      <option value="pending">pending</option>
                      <option value="closed">closed</option>
                    </select>
                    <select
                      value={selected.priority}
                      onChange={(e) => updateTicket({ priority: e.target.value as TicketPriority })}
                      className="rounded-lg border border-white/15 bg-black/30 px-2 py-1 text-xs"
                      disabled={!!actionBusy}
                    >
                      <option value="low">low</option>
                      <option value="normal">normal</option>
                      <option value="high">high</option>
                      <option value="urgent">urgent</option>
                    </select>
                  </div>
                </div>
              </div>

              <div className="flex-1 space-y-3 overflow-auto p-4">
                {loadingMessages ? (
                  <div className="text-sm text-zinc-400">Loading conversation…</div>
                ) : messages.length === 0 ? (
                  <div className="rounded-xl border border-white/10 bg-white/5 px-3 py-3 text-sm text-zinc-400">No messages yet.</div>
                ) : (
                  messages.map((m, i) => {
                    const support = m.authorType === "support";
                    return (
                      <div
                        key={`${m._id || "m"}-${i}`}
                        className={cx("max-w-[86%] rounded-2xl border px-4 py-3", support
                          ? "ml-auto border-blue-400/30 bg-blue-500/15"
                          : "border-white/10 bg-white/5")}
                      >
                        <div className="mb-1 flex items-center justify-between gap-2 text-[11px]">
                          <span className={support ? "text-blue-200" : "text-zinc-300"}>{support ? "Support" : "User"}</span>
                          <span className="text-zinc-500">{relTime(m.createdAt)}</span>
                        </div>
                        <div className="whitespace-pre-wrap text-sm text-zinc-100">{m.body}</div>
                      </div>
                    );
                  })
                )}
              </div>

              <div className="border-t border-white/10 p-4">
                <div className="flex items-end gap-2">
                  <textarea
                    value={reply}
                    onChange={(e) => setReply(e.target.value)}
                    rows={3}
                    placeholder="Type your reply to user..."
                    className="min-h-[86px] flex-1 resize-y rounded-xl border border-white/15 bg-black/30 px-3 py-2 text-sm outline-none focus:border-blue-400/40"
                  />
                  <button
                    type="button"
                    onClick={sendReply}
                    disabled={sending || !reply.trim()}
                    className="gf-btn h-10 rounded-xl px-4 text-sm disabled:opacity-50"
                  >
                    {sending ? "Sending…" : "Send"}
                  </button>
                </div>
                <div className="mt-2 text-[11px] text-zinc-500">
                  On send, backend notifies the ticket owner automatically.
                </div>
              </div>
            </>
          )}
        </div>
      </div>
    </AdminShell>
  );
}
