"use client";

import { useEffect, useMemo, useState } from "react";
import AdminShell from "@/app/_components/AdminShell";
import { apiFetch, ApiError } from "@/lib/api";
import { getToken } from "@/lib/auth";
import { NeonChip } from "@/app/_components/Hud";
import { useToast } from "@/app/_components/ToastProvider";
import { Users, Server, Zap, XCircle, Globe, Shield, RefreshCw } from "lucide-react";
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

export default function MultiplayerAdminPage() {
  const toast = useToast();
  const token = useMemo(() => getToken(), []);
  const [loading, setLoading] = useState(true);
  const [rooms, setRooms] = useState<MultiplayerRoom[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [busyId, setBusyId] = useState<string | null>(null);

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

  async function deleteRoom(roomId: string) {
    if (!token) return;
    if (!confirm("Are you sure you want to close this room? Players will be disconnected.")) return;
    
    setBusyId(roomId);
    try {
      await apiFetch(`/multiplayer/rooms/${roomId}`, { method: "DELETE", token });
      toast.success("Room closed", "The multiplayer room has been terminated.");
      await load();
    } catch (e: any) {
      toast.error("Action failed", e?.message || "Could not close room");
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

      <div className="flex justify-between items-center mb-6">
        <div className="text-xs font-black text-zinc-500 uppercase tracking-[0.3em]">Neural Room Matrix</div>
        <button 
          onClick={load}
          className="gf-btn h-9 px-4 rounded-xl flex items-center gap-2 text-xs font-black uppercase tracking-widest"
        >
          <RefreshCw size={14} className={loading ? "animate-spin" : ""} />
          Refresh
        </button>
      </div>

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
            rooms.map((room) => (
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
                  <button 
                    disabled={busyId === room.id}
                    onClick={() => deleteRoom(room.id)}
                    className="h-9 px-4 rounded-xl bg-red-500/10 border border-red-500/20 text-red-400 text-[10px] font-black uppercase tracking-widest hover:bg-red-500/20 transition-all disabled:opacity-50"
                  >
                    Kill Process
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
