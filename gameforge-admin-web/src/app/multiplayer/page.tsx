"use client";

import { useEffect, useMemo, useState } from "react";
import AdminShell from "@/app/_components/AdminShell";
import ConfirmDialog from "@/app/_components/ConfirmDialog";
import { apiFetch, ApiError } from "@/lib/api";
import { getToken } from "@/lib/auth";
import { useToast } from "@/app/_components/ToastProvider";
import { Users, Server, Zap, Globe, RefreshCw, Eye, Pencil, Save, X } from "lucide-react";
import { motion } from "framer-motion";

type MultiplayerRoom = {
  id: string;
  name: string;
  creatorId?: string;
  creatorUsername: string;
  playerCount: number;
  maxPlayers: number;
  status: "active" | "empty" | "full";
  region: string;
  createdAt: string;
};

type RoomDetails = {
  room?: any;
  messages?: any[];
};

export default function MultiplayerAdminPage() {
  const token = useMemo(() => getToken(), []);
  const toast = useToast();
  const [loading, setLoading] = useState(true);
  const [rooms, setRooms] = useState<MultiplayerRoom[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [busyId, setBusyId] = useState<string | null>(null);
  const [query, setQuery] = useState("");
  const [selected, setSelected] = useState<MultiplayerRoom | null>(null);
  const [details, setDetails] = useState<RoomDetails | null>(null);
  const [detailsLoading, setDetailsLoading] = useState(false);
  const [confirm, setConfirm] = useState<null | { id: string; action: "close" | "forceClose" }>(null);
  const [edit, setEdit] = useState<{ name: string; maxPlayers: number; region: string } | null>(null);

  async function load() {
    if (!token) return;
    setLoading(true);
    setError(null);
    try {
      const res = await apiFetch<any>("/multiplayer/rooms", { method: "GET", token });
      const rawItems = Array.isArray(res) ? res : (res?.items || res?.data || []);
      
      const mapped = rawItems.map((r: any) => ({
        id: r.roomId || r.id || r._id,
        name: r.name || "Untitled Room",
        creatorId: r.hostUserId,
        creatorUsername: r.hostUsername || "Unknown",
        playerCount: (r.members || []).length,
        maxPlayers: r.maxPlayers || 4,
        status: (r.members || []).length === 0 ? "empty" : ((r.members || []).length >= (r.maxPlayers || 4) ? "full" : "active"),
        region: r.region || "Global",
        createdAt: r.createdAt || new Date().toISOString()
      }));

      setRooms(mapped);
    } catch (e: any) {
      setError(e?.message || "Failed to load multiplayer rooms");
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

  const filteredRooms = useMemo(() => {
    const q = query.trim().toLowerCase();
    if (!q) return rooms;
    return rooms.filter((r) => {
      return (
        r.name.toLowerCase().includes(q) ||
        r.id.toLowerCase().includes(q) ||
        r.creatorUsername.toLowerCase().includes(q) ||
        r.region.toLowerCase().includes(q)
      );
    });
  }, [rooms, query]);

  async function openDetails(room: MultiplayerRoom) {
    if (!token) return;
    setSelected(room);
    setDetails(null);
    setEdit({ name: room.name, maxPlayers: room.maxPlayers, region: room.region });
    setDetailsLoading(true);
    try {
      const [roomRes, msgRes] = await Promise.all([
        apiFetch<any>(`/multiplayer/rooms/${room.id}`, { method: "GET", token }),
        apiFetch<any>(`/multiplayer/rooms/${room.id}/messages?limit=30`, { method: "GET", token }).catch(() => null),
      ]);
      const msgs = Array.isArray((msgRes as any)?.items)
        ? (msgRes as any).items
        : Array.isArray(msgRes)
          ? (msgRes as any)
          : (msgRes as any)?.data || [];
      setDetails({ room: roomRes, messages: Array.isArray(msgs) ? msgs : [] });
    } catch (e: any) {
      toast.error("Failed", e?.message || "Could not load room details");
    } finally {
      setDetailsLoading(false);
    }
  }

  async function saveEdits() {
    if (!token || !selected || !edit) return;
    const nextName = String(edit.name || "").trim();
    const nextMax = Number(edit.maxPlayers || 0);
    const nextRegion = String(edit.region || "").trim();
    if (!nextName) {
      toast.error("Invalid", "Room name is required");
      return;
    }
    if (!Number.isFinite(nextMax) || nextMax < 2 || nextMax > 64) {
      toast.error("Invalid", "maxPlayers must be between 2 and 64");
      return;
    }

    setBusyId(selected.id);
    try {
      await apiFetch(`/multiplayer/rooms/${selected.id}`, {
        method: "PATCH",
        token,
        body: { name: nextName, maxPlayers: nextMax, region: nextRegion || undefined },
      });
      toast.success("Updated", "Room settings have been saved.");
      await load();
    } catch (e: any) {
      toast.error("Update failed", e?.message || "Backend does not support updating rooms yet");
    } finally {
      setBusyId(null);
    }
  }

  async function deleteRoom(roomId: string, opts?: { force?: boolean }) {
    if (!token) return;
    setBusyId(roomId);
    try {
      const qs = opts?.force ? "?force=true" : "";
      await apiFetch(`/multiplayer/rooms/${roomId}${qs}`, { method: "DELETE", token });
      toast.success("Room closed", opts?.force ? "The multiplayer room has been force-closed." : "The multiplayer room has been terminated.");
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
        setConfirm({ id: roomId, action: "forceClose" });
      } else {
        toast.error(opts?.force ? "Force failed" : "Action failed", e?.message || (opts?.force ? "Could not force close room" : "Could not close room"));
      }
    } finally {
      setBusyId(null);
    }
  }

  return (
    <AdminShell title="Multiplayer Management" subtitle="Game servers and room control">
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
        <div className="gf-panel p-6 rounded-2xl border border-white/5 relative overflow-hidden group">
          <div className="absolute top-0 right-0 p-4 opacity-10 group-hover:opacity-20 transition-opacity">
            <Server size={48} />
          </div>
          <div className="text-xs font-black text-zinc-500 uppercase tracking-widest mb-2">Active Rooms</div>
          <div className="text-4xl font-black text-white italic gf-chromatic">{rooms.filter(r => r.status !== "empty").length}</div>
        </div>
        <div className="gf-panel p-6 rounded-2xl border border-white/5 relative overflow-hidden group">
          <div className="absolute top-0 right-0 p-4 opacity-10 group-hover:opacity-20 transition-opacity">
            <Users size={48} />
          </div>
          <div className="text-xs font-black text-zinc-500 uppercase tracking-widest mb-2">Concurrent Players</div>
          <div className="text-4xl font-black text-white italic gf-chromatic">
            {rooms.reduce((acc, r) => acc + r.playerCount, 0)}
          </div>
        </div>
        <div className="gf-panel p-6 rounded-2xl border border-white/5 relative overflow-hidden group">
          <div className="absolute top-0 right-0 p-4 opacity-10 group-hover:opacity-20 transition-opacity">
            <Zap size={48} />
          </div>
          <div className="text-xs font-black text-zinc-500 uppercase tracking-widest mb-2">Server Load</div>
          <div className="text-4xl font-black text-cyan-400 italic">12%</div>
        </div>
      </div>

      <div className="flex flex-col md:flex-row md:justify-between md:items-center gap-3 mb-6">
        <div className="text-xs font-black text-zinc-500 uppercase tracking-[0.3em]">Neural Room Matrix</div>
        <div className="flex items-center gap-3">
          <div className="gf-panel h-9 px-3 rounded-xl border border-white/5 flex items-center gap-2">
            <input
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder="Search rooms, hosts, IDs..."
              className="bg-transparent text-xs font-bold text-zinc-200 placeholder:text-zinc-600 outline-none w-52"
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

      <div className="gf-table rounded-2xl border border-white/5 overflow-hidden shadow-2xl">
        <div className="gf-table-head grid grid-cols-[1.5fr_1fr_1fr_0.8fr_1fr] gap-4 px-6 py-4 border-b border-white/10 text-[10px] font-black uppercase tracking-widest text-zinc-500 bg-white/[0.02]">
          <div>Room Name</div>
          <div>Host</div>
          <div>Capacity</div>
          <div>Region</div>
          <div className="text-right">Management</div>
        </div>

        <div className="divide-y divide-white/5 bg-black/20">
          {loading && rooms.length === 0 ? (
             <div className="p-12 text-center text-zinc-500 animate-pulse font-black uppercase tracking-widest">
               Polling multiplayer shard status...
             </div>
          ) : rooms.length === 0 ? (
            <div className="p-12 text-center text-zinc-500 font-black uppercase tracking-widest">
              No active rooms in the matrix
            </div>
          ) : (
            filteredRooms.map((room) => (
              <div key={room.id} className="grid grid-cols-[1.5fr_1fr_1fr_0.8fr_1fr] gap-4 px-6 py-4 items-center hover:bg-white/[0.02] transition-colors group">
                <div className="flex items-center gap-3">
                  <div className="h-10 w-10 rounded-xl bg-cyan-500/10 border border-cyan-500/20 flex items-center justify-center text-cyan-400 group-hover:scale-110 transition-transform">
                    <Server size={20} />
                  </div>
                  <div>
                    <div className="text-sm font-black text-white group-hover:text-cyan-300 transition-colors">{room.name}</div>
                    <div className="text-[10px] text-zinc-500 font-mono">ID: {room.id}</div>
                  </div>
                </div>
                <div className="text-sm text-zinc-300 font-bold">@{room.creatorUsername}</div>
                <div className="flex items-center gap-2">
                  <div className="flex-1 h-1.5 rounded-full bg-white/5 overflow-hidden w-24">
                    <div 
                      className="h-full bg-cyan-500" 
                      style={{ width: `${(room.playerCount / room.maxPlayers) * 100}%` }}
                    />
                  </div>
                  <span className="text-xs font-black text-white whitespace-nowrap">{room.playerCount} / {room.maxPlayers}</span>
                </div>
                <div className="text-[10px] font-black text-zinc-400 uppercase tracking-widest flex items-center gap-2">
                  <Globe size={12} className="text-zinc-600" />
                  {room.region}
                </div>
                <div className="text-right">
                  <div className="flex justify-end gap-2">
                    <button
                      onClick={() => openDetails(room)}
                      className="h-9 px-3 rounded-xl bg-white/5 border border-white/10 text-zinc-200 text-[10px] font-black uppercase tracking-widest hover:bg-white/10 transition-all"
                      title="View / Edit"
                    >
                      <Eye size={14} />
                    </button>
                    <button
                      onClick={() => setConfirm({ id: room.id, action: "close" })}
                      className="h-9 px-4 rounded-xl bg-red-500/10 border border-red-500/20 text-red-400 text-[10px] font-black uppercase tracking-widest hover:bg-red-500/20 transition-all disabled:opacity-50"
                      disabled={busyId === room.id}
                    >
                      Kill Process
                    </button>
                  </div>
                </div>
              </div>
            ))
          )}
        </div>
      </div>

      <ConfirmDialog
        open={Boolean(confirm)}
        title={confirm?.action === "forceClose" ? "Force close room?" : "Close room?"}
        description={
          confirm?.action === "forceClose"
            ? "This room is not owned by you. As admin you can force-close it. Players will be disconnected."
            : "Are you sure you want to close this room? Players will be disconnected."
        }
        confirmText={confirm?.action === "forceClose" ? "Force close" : "Close room"}
        confirmTone={"danger"}
        busy={Boolean(confirm?.id && busyId === confirm.id)}
        onCancel={() => setConfirm(null)}
        onConfirm={async () => {
          if (!confirm) return;
          const { id, action } = confirm;
          setConfirm(null);
          await deleteRoom(id, { force: action === "forceClose" });
        }}
      />

      {selected ? (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/70">
          <div className="gf-panel w-full max-w-3xl rounded-3xl border border-white/10 overflow-hidden">
            <div className="p-5 border-b border-white/10 flex items-center justify-between">
              <div>
                <div className="text-xs font-black uppercase tracking-widest text-zinc-500">Room Control</div>
                <div className="text-lg font-black text-white mt-1">{selected.name}</div>
                <div className="text-[10px] text-zinc-500 font-mono mt-1">ID: {selected.id}</div>
              </div>
              <button
                onClick={() => {
                  setSelected(null);
                  setDetails(null);
                  setEdit(null);
                }}
                className="h-9 w-9 rounded-xl bg-white/5 border border-white/10 text-zinc-200 flex items-center justify-center hover:bg-white/10"
              >
                <X size={16} />
              </button>
            </div>

            <div className="p-5 grid grid-cols-1 md:grid-cols-2 gap-5">
              <div className="space-y-4">
                <div className="text-[10px] font-black uppercase tracking-widest text-zinc-500">Edit Settings</div>
                <div className="space-y-3">
                  <div>
                    <div className="text-[10px] font-black uppercase tracking-widest text-zinc-600 mb-1">Name</div>
                    <input
                      value={edit?.name ?? ""}
                      onChange={(e) => setEdit((p) => (p ? { ...p, name: e.target.value } : p))}
                      className="w-full h-10 px-3 rounded-xl bg-black/30 border border-white/10 text-sm font-bold text-white outline-none"
                    />
                  </div>
                  <div className="grid grid-cols-2 gap-3">
                    <div>
                      <div className="text-[10px] font-black uppercase tracking-widest text-zinc-600 mb-1">Max Players</div>
                      <input
                        type="number"
                        min={2}
                        max={64}
                        value={edit?.maxPlayers ?? 4}
                        onChange={(e) =>
                          setEdit((p) => (p ? { ...p, maxPlayers: Number(e.target.value) } : p))
                        }
                        className="w-full h-10 px-3 rounded-xl bg-black/30 border border-white/10 text-sm font-bold text-white outline-none"
                      />
                    </div>
                    <div>
                      <div className="text-[10px] font-black uppercase tracking-widest text-zinc-600 mb-1">Region</div>
                      <input
                        value={edit?.region ?? ""}
                        onChange={(e) => setEdit((p) => (p ? { ...p, region: e.target.value } : p))}
                        className="w-full h-10 px-3 rounded-xl bg-black/30 border border-white/10 text-sm font-bold text-white outline-none"
                      />
                    </div>
                  </div>
                </div>

                <div className="flex items-center gap-2 pt-2">
                  <button
                    disabled={busyId === selected.id}
                    onClick={saveEdits}
                    className="h-10 px-4 rounded-xl bg-cyan-500/10 border border-cyan-500/20 text-cyan-300 text-xs font-black uppercase tracking-widest hover:bg-cyan-500/20 transition-all disabled:opacity-50 flex items-center gap-2"
                  >
                    <Save size={14} />
                    Save
                  </button>
                  <button
                    disabled={busyId === selected.id}
                    onClick={() => deleteRoom(selected.id)}
                    className="h-10 px-4 rounded-xl bg-red-500/10 border border-red-500/20 text-red-300 text-xs font-black uppercase tracking-widest hover:bg-red-500/20 transition-all disabled:opacity-50"
                  >
                    Kill
                  </button>
                </div>
              </div>

              <div className="space-y-4">
                <div className="text-[10px] font-black uppercase tracking-widest text-zinc-500">Telemetry</div>
                <div className="gf-panel p-4 rounded-2xl border border-white/5 bg-black/20">
                  {detailsLoading ? (
                    <div className="text-sm text-zinc-500 font-black uppercase tracking-widest animate-pulse">Loading...</div>
                  ) : (
                    <pre className="text-[11px] text-zinc-300/90 whitespace-pre-wrap break-words font-mono leading-relaxed max-h-64 overflow-auto">
                      {JSON.stringify(details?.room ?? { hint: "No details loaded" }, null, 2)}
                    </pre>
                  )}
                </div>

                <div className="text-[10px] font-black uppercase tracking-widest text-zinc-500">Recent Messages</div>
                <div className="gf-panel p-4 rounded-2xl border border-white/5 bg-black/20">
                  {detailsLoading ? (
                    <div className="text-sm text-zinc-500 font-black uppercase tracking-widest animate-pulse">Loading...</div>
                  ) : (details?.messages?.length || 0) === 0 ? (
                    <div className="text-xs text-zinc-500 font-black uppercase tracking-widest">No messages</div>
                  ) : (
                    <div className="space-y-2 max-h-56 overflow-auto">
                      {(details?.messages || []).slice(0, 30).map((m: any, idx: number) => (
                        <div key={idx} className="p-2 rounded-xl bg-white/5 border border-white/10">
                          <div className="text-[10px] text-zinc-500 font-mono">
                            {String(m?.createdAt || m?.ts || "").slice(0, 30)}
                          </div>
                          <div className="text-xs text-zinc-200 font-semibold break-words">{String(m?.text || m?.message || JSON.stringify(m))}</div>
                        </div>
                      ))}
                    </div>
                  )}
                </div>
              </div>
            </div>
          </div>
        </div>
      ) : null}
    </AdminShell>
  );
}
