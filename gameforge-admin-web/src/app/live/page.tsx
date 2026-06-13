"use client";

import { useEffect, useMemo, useState } from "react";
import AdminShell from "@/app/_components/AdminShell";
import { apiFetch } from "@/lib/api";
import { getToken } from "@/lib/auth";
import { NeonChip } from "@/app/_components/Hud";
import { useToast } from "@/app/_components/ToastProvider";
import { Users, Activity, Shield, Globe, RefreshCw, Eye, Save, X } from "lucide-react";
import { motion, AnimatePresence } from "framer-motion";
import ConfirmDialog from "@/app/_components/ConfirmDialog";

type LiveSession = {
  id: string;
  roomName: string;
  creatorId: string;
  creatorUsername: string;
  participantCount: number;
  status: "active" | "ended" | "starting";
  createdAt: string;
  uptime?: string;
};

export default function LiveSessionsAdminPage() {
  const toast = useToast();
  const token = useMemo(() => getToken(), []);
  const [loading, setLoading] = useState(true);
  const [sessions, setSessions] = useState<LiveSession[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [busyId, setBusyId] = useState<string | null>(null);
  const [confirm, setConfirm] = useState<null | { id: string; action: "end" | "forceEnd" }>(null);
  const [query, setQuery] = useState("");
  const [selected, setSelected] = useState<LiveSession | null>(null);
  const [editTitle, setEditTitle] = useState("");
  const [details, setDetails] = useState<any>(null);
  const [detailsLoading, setDetailsLoading] = useState(false);

  async function load() {
    if (!token) return;
    setLoading(true);
    setError(null);
    try {
      const res = await apiFetch<any>("/live/feed", { method: "GET", token });
      const rawItems = Array.isArray(res) ? res : (res?.items || res?.data || []);
      
      const mapped = rawItems.map((s: any) => ({
        id: s.id || s._id,
        roomName: s.title || s.roomName || "Untitled Session",
        creatorId: s.creatorId,
        creatorUsername: s.creatorUsername || "Unknown",
        participantCount: s.viewerCount || s.participantCount || 0,
        status: s.isActive ? "active" : "ended",
        createdAt: s.createdAt || new Date().toISOString()
      }));

      setSessions(mapped);
    } catch (e: any) {
      setError(e?.message || "Failed to load live sessions");
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    load();
  }, [token]);

  useEffect(() => {
    if (!token) return;
    const id = window.setInterval(() => {
      load();
    }, 10000);
    return () => window.clearInterval(id);
  }, [token]);

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    if (!q) return sessions;
    return sessions.filter((s) => {
      return (
        s.roomName.toLowerCase().includes(q) ||
        s.id.toLowerCase().includes(q) ||
        s.creatorUsername.toLowerCase().includes(q)
      );
    });
  }, [sessions, query]);

  async function openDetails(session: LiveSession) {
    if (!token) return;
    setSelected(session);
    setEditTitle(session.roomName);
    setDetails(null);
    setDetailsLoading(true);
    try {
      const res = await apiFetch<any>(`/live/${session.id}`, { method: "GET", token }).catch(() => null);
      setDetails(res);
    } finally {
      setDetailsLoading(false);
    }
  }

  async function saveTitle() {
    if (!token || !selected) return;
    const t = editTitle.trim();
    if (!t) {
      toast.error("Invalid", "Title is required");
      return;
    }
    setBusyId(selected.id);
    try {
      await apiFetch(`/live/${selected.id}`, { method: "PATCH", token, body: { title: t } });
      toast.success("Updated", "Live session updated.");
      await load();
    } catch (e: any) {
      toast.error("Update failed", e?.message || "Backend does not support updating live sessions yet");
    } finally {
      setBusyId(null);
    }
  }

  async function endSession(sessionId: string, opts?: { force?: boolean }) {
    if (!token) return;
    setBusyId(sessionId);
    try {
      const qs = opts?.force ? "?force=true" : "";
      await apiFetch(`/live/${sessionId}/end${qs}`, { method: "POST", token });
      toast.success("Session ended", opts?.force ? "The live session has been force-terminated." : "The live session has been terminated.");
      await load();
    } catch (e: any) {
      const msg = String(e?.message || "").toLowerCase();
      const maybePerm =
        msg.includes("not your") ||
        msg.includes("forbidden") ||
        msg.includes("unauthorized") ||
        msg.includes("permission") ||
        msg.includes("owner") ||
        msg.includes("403");

      if (maybePerm && !opts?.force) {
        setConfirm({ id: sessionId, action: "forceEnd" });
      } else {
        toast.error(opts?.force ? "Force failed" : "Action failed", e?.message || (opts?.force ? "Could not force end session" : "Could not end session"));
      }
    } finally {
      setBusyId(null);
    }
  }

  return (
    <AdminShell title="Live Sessions" subtitle="Real-time monitoring and control">
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
        <div className="gf-panel p-6 rounded-2xl border border-white/5 relative overflow-hidden group">
          <div className="absolute top-0 right-0 p-4 opacity-10 group-hover:opacity-20 transition-opacity">
            <Activity size={48} />
          </div>
          <div className="text-xs font-black text-zinc-500 uppercase tracking-widest mb-2">Active Streams</div>
          <div className="text-4xl font-black text-white italic gf-chromatic">{sessions.filter(s => s.status === "active").length}</div>
        </div>
        <div className="gf-panel p-6 rounded-2xl border border-white/5 relative overflow-hidden group">
          <div className="absolute top-0 right-0 p-4 opacity-10 group-hover:opacity-20 transition-opacity">
            <Users size={48} />
          </div>
          <div className="text-xs font-black text-zinc-500 uppercase tracking-widest mb-2">Total Viewers</div>
          <div className="text-4xl font-black text-white italic gf-chromatic">
            {sessions.reduce((acc, s) => acc + s.participantCount, 0)}
          </div>
        </div>
        <div className="gf-panel p-6 rounded-2xl border border-white/5 relative overflow-hidden group">
          <div className="absolute top-0 right-0 p-4 opacity-10 group-hover:opacity-20 transition-opacity">
            <Shield size={48} />
          </div>
          <div className="text-xs font-black text-zinc-500 uppercase tracking-widest mb-2">System Health</div>
          <div className="text-4xl font-black text-emerald-400 italic">OPTIMAL</div>
        </div>
      </div>

      <div className="flex flex-col md:flex-row md:justify-between md:items-center gap-3 mb-6">
        <div className="text-xs font-black text-zinc-500 uppercase tracking-[0.3em]">Live Streams Matrix</div>
        <div className="flex items-center gap-3">
          <div className="gf-panel h-9 px-3 rounded-xl border border-white/5 flex items-center gap-2">
            <input
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder="Search sessions, creators, IDs..."
              className="bg-transparent text-xs font-bold text-zinc-200 placeholder:text-zinc-600 outline-none w-56"
            />
          </div>
          <button
            onClick={load}
            className="gf-btn h-9 px-4 rounded-xl flex items-center gap-2 text-xs font-black uppercase tracking-widest"
          >
            <RefreshCw size={14} className={loading ? "animate-spin" : ""} />
            Refresh
          </button>
        </div>
      </div>

      {error ? (
        <div className="mb-6 gf-panel p-4 rounded-2xl border border-rose-500/20 bg-rose-500/5">
          <div className="text-xs font-black uppercase tracking-widest text-rose-300">Error</div>
          <div className="text-sm text-rose-200/90 font-semibold mt-1">{error}</div>
        </div>
      ) : null}

      <div className="gf-table rounded-2xl border border-white/5 overflow-hidden">
        <div className="gf-table-head grid grid-cols-[1.5fr_1fr_1fr_1fr_1fr] gap-4 px-6 py-4 border-b border-white/10 text-[10px] font-black uppercase tracking-widest text-zinc-500">
          <div>Session / Room</div>
          <div>Creator</div>
          <div>Participants</div>
          <div>Status</div>
          <div className="text-right">Actions</div>
        </div>

        <div className="divide-y divide-white/5">
          {loading ? (
             <div className="p-12 text-center text-zinc-500 animate-pulse font-black uppercase tracking-widest">
               Synchronizing with LiveKit nodes...
             </div>
          ) : sessions.length === 0 ? (
            <div className="p-12 text-center text-zinc-500 font-black uppercase tracking-widest">
              No active sessions found
            </div>
          ) : (
            filtered.map((session) => (
              <div key={session.id} className="grid grid-cols-[1.5fr_1fr_1fr_1fr_1fr] gap-4 px-6 py-4 items-center hover:bg-white/[0.02] transition-colors">
                <div className="flex items-center gap-3">
                  <div className="h-10 w-10 rounded-xl bg-blue-500/10 border border-blue-500/20 flex items-center justify-center text-blue-400">
                    <Globe size={20} />
                  </div>
                  <div>
                    <div className="text-sm font-black text-white">{session.roomName}</div>
                    <div className="text-[10px] text-zinc-500 font-mono">ID: {session.id}</div>
                  </div>
                </div>
                <div className="text-sm text-zinc-300 font-bold">@{session.creatorUsername}</div>
                <div className="flex items-center gap-2">
                  <div className="h-1.5 w-1.5 rounded-full bg-emerald-500 animate-pulse" />
                  <span className="text-sm font-black text-white">{session.participantCount} Viewers</span>
                </div>
                <div>
                   <span className="px-2 py-1 rounded-lg bg-emerald-500/10 border border-emerald-500/20 text-[10px] font-black text-emerald-400 uppercase tracking-widest">
                     {session.status}
                   </span>
                </div>
                <div className="text-right">
                  <div className="flex justify-end gap-2">
                    <button
                      onClick={() => openDetails(session)}
                      className="h-9 px-3 rounded-xl bg-white/5 border border-white/10 text-zinc-200 text-[10px] font-black uppercase tracking-widest hover:bg-white/10 transition-all"
                      title="View / Edit"
                    >
                      <Eye size={14} />
                    </button>
                    <button 
                      disabled={busyId === session.id}
                      onClick={() => endSession(session.id)}
                      className="h-9 px-4 rounded-xl bg-rose-500/10 border border-rose-500/20 text-rose-400 text-xs font-black uppercase tracking-widest hover:bg-rose-500/20 transition-all disabled:opacity-50"
                    >
                      Terminate
                    </button>
                  </div>
                </div>
              </div>
            ))
          )}
        </div>
      </div>

      {selected ? (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/70">
          <div className="gf-panel w-full max-w-3xl rounded-3xl border border-white/10 overflow-hidden">
            <div className="p-5 border-b border-white/10 flex items-center justify-between">
              <div>
                <div className="text-xs font-black uppercase tracking-widest text-zinc-500">Session Control</div>
                <div className="text-lg font-black text-white mt-1">{selected.roomName}</div>
                <div className="text-[10px] text-zinc-500 font-mono mt-1">ID: {selected.id}</div>
              </div>
              <button
                onClick={() => {
                  setSelected(null);
                  setDetails(null);
                }}
                className="h-9 w-9 rounded-xl bg-white/5 border border-white/10 text-zinc-200 flex items-center justify-center hover:bg-white/10"
              >
                <X size={16} />
              </button>
            </div>

            <div className="p-5 grid grid-cols-1 md:grid-cols-2 gap-5">
              <div className="space-y-4">
                <div className="text-[10px] font-black uppercase tracking-widest text-zinc-500">Edit Title</div>
                <input
                  value={editTitle}
                  onChange={(e) => setEditTitle(e.target.value)}
                  className="w-full h-10 px-3 rounded-xl bg-black/30 border border-white/10 text-sm font-bold text-white outline-none"
                />
                <div className="flex items-center gap-2">
                  <button
                    disabled={busyId === selected.id}
                    onClick={saveTitle}
                    className="h-10 px-4 rounded-xl bg-blue-500/10 border border-blue-500/20 text-blue-300 text-xs font-black uppercase tracking-widest hover:bg-blue-500/20 transition-all disabled:opacity-50 flex items-center gap-2"
                  >
                    <Save size={14} />
                    Save
                  </button>
                  <button
                    disabled={busyId === selected.id}
                    onClick={() => endSession(selected.id)}
                    className="h-10 px-4 rounded-xl bg-rose-500/10 border border-rose-500/20 text-rose-300 text-xs font-black uppercase tracking-widest hover:bg-rose-500/20 transition-all disabled:opacity-50"
                  >
                    Terminate
                  </button>
                </div>
              </div>

              <div className="space-y-4">
                <div className="text-[10px] font-black uppercase tracking-widest text-zinc-500">Telemetry</div>
                <div className="gf-panel p-4 rounded-2xl border border-white/5 bg-black/20">
                  {detailsLoading ? (
                    <div className="text-sm text-zinc-500 font-black uppercase tracking-widest animate-pulse">Loading...</div>
                  ) : (
                    <pre className="text-[11px] text-zinc-300/90 whitespace-pre-wrap break-words font-mono leading-relaxed max-h-80 overflow-auto">
                      {JSON.stringify(details ?? selected, null, 2)}
                    </pre>
                  )}
                </div>
              </div>
            </div>
          </div>
        </div>
      ) : null}

      <ConfirmDialog
        open={Boolean(confirm)}
        title={confirm?.action === "forceEnd" ? "Force terminate session?" : "Terminate session?"}
        description={
          confirm?.action === "forceEnd"
            ? "This session is not owned by you. As admin you can force-terminate it."
            : "Terminate this live session immediately?"
        }
        confirmText={confirm?.action === "forceEnd" ? "Force terminate" : "Terminate"}
        confirmTone={confirm?.action === "forceEnd" ? "danger" : "danger"}
        busy={Boolean(confirm?.id && busyId === confirm.id)}
        onCancel={() => setConfirm(null)}
        onConfirm={async () => {
          if (!confirm) return;
          const { id, action } = confirm;
          setConfirm(null);
          await endSession(id, { force: action === "forceEnd" });
        }}
      />
    </AdminShell>
  );
}
