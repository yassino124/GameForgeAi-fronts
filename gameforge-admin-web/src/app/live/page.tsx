"use client";

import { useEffect, useMemo, useState } from "react";
import AdminShell from "@/app/_components/AdminShell";
import { apiFetch, ApiError } from "@/lib/api";
import { getToken } from "@/lib/auth";
import { NeonChip } from "@/app/_components/Hud";
import { useToast } from "@/app/_components/ToastProvider";
import { Users, Activity, Shield, XCircle, Globe, Zap } from "lucide-react";
import { motion, AnimatePresence } from "framer-motion";

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

  async function endSession(sessionId: string) {
    if (!token) return;
    if (!confirm("Terminate this live session immediately?")) return;
    setBusyId(sessionId);
    try {
      await apiFetch(`/live/${sessionId}/end`, { method: "POST", token });
      toast.success("Session ended", "The live session has been terminated.");
      await load();
    } catch (e: any) {
      toast.error("Action failed", e?.message || "Could not end session");
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
          <div className="text-4xl font-black text-white italic gf-chromatic">{sessions.length}</div>
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
            sessions.map((session) => (
              <div key={session.id} className="grid grid-cols-[1.5fr_1fr_1fr_1fr_1fr] gap-4 px-6 py-4 items-center hover:bg-white/[0.02] transition-colors">
                <div className="flex items-center gap-3">
                  <div className="h-10 w-10 rounded-xl bg-indigo-500/10 border border-indigo-500/20 flex items-center justify-center text-indigo-400">
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
                  <button 
                    disabled={busyId === session.id}
                    onClick={() => endSession(session.id)}
                    className="h-9 px-4 rounded-xl bg-rose-500/10 border border-rose-500/20 text-rose-400 text-xs font-black uppercase tracking-widest hover:bg-rose-500/20 transition-all disabled:opacity-50"
                  >
                    Terminate
                  </button>
                </div>
              </div>
            ))
          )}
        </div>
      </div>
    </AdminShell>
  );
}
