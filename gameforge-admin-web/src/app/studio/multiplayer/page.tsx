"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { motion, AnimatePresence } from "framer-motion";
import {
  Users,
  Plus,
  Zap,
  Search,
  ChevronRight,
  Gamepad2,
  Trophy,
  ArrowLeft,
  Hash,
  Shield,
  Wifi,
  X,
} from "lucide-react";
import { apiFetch } from "@/lib/api";
import { getUserToken } from "@/lib/userAuth";
import UserShell from "@/app/_components/UserShell";

interface Room {
  roomId: string;
  name: string;
  members: any[];
  maxPlayers: number;
}

export default function StudioMultiplayerLobby() {
  const router = useRouter();
  const [rooms, setRooms] = useState<Room[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState("");
  const [showCreateModal, setShowCreateModal] = useState(false);
  const [newLobbyName, setNewLobbyName] = useState("");

  const loadRooms = async () => {
    try {
      setLoading(true);
      const token = getUserToken();
      const res = await apiFetch<any>("/multiplayer/rooms", { token });
      if (res && (res as any).items) {
        setRooms((res as any).items);
      }
    } catch (err) {
      console.error("Failed to load rooms", err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadRooms();
  }, []);

  const handleCreateRoom = async () => {
    if (!newLobbyName.trim()) return;
    router.push(`/studio/multiplayer/create?name=${encodeURIComponent(newLobbyName)}`);
  };

  const filteredRooms = rooms.filter(
    (r) => r.name.toLowerCase().includes(search.toLowerCase()) || r.roomId.toLowerCase().includes(search.toLowerCase()),
  );

  return (
    <UserShell title="Multiplayer" subtitle="Public Lobbies">
      {/* Ambient background glows */}
      <div className="absolute top-0 left-0 w-full h-full pointer-events-none overflow-hidden">
        <div className="absolute top-[-15%] left-[20%] w-[600px] h-[600px] bg-indigo-600/10 blur-[140px] rounded-full" />
        <div className="absolute bottom-[-10%] right-[10%] w-[500px] h-[500px] bg-fuchsia-600/8 blur-[130px] rounded-full" />
        <div className="absolute top-[40%] left-[-10%] w-[400px] h-[400px] bg-cyan-600/5 blur-[120px] rounded-full" />
      </div>

      <div className="relative z-10 flex gap-8 h-full min-h-[70vh]">
        {/* LEFT PANEL — Hero + Actions */}
        <div className="w-[420px] shrink-0 flex flex-col gap-8">
          {/* Back button + badge */}
          <motion.div initial={{ opacity: 0, x: -20 }} animate={{ opacity: 1, x: 0 }} className="flex items-center gap-4">
            <button
              onClick={() => router.push("/studio")}
              className="flex items-center justify-center w-10 h-10 rounded-xl border border-white/10 bg-white/5 hover:bg-white/10 text-zinc-400 hover:text-white transition-all"
            >
              <ArrowLeft className="w-5 h-5" />
            </button>
            <div className="flex items-center gap-2 px-3 py-1 rounded-full bg-indigo-500/10 border border-indigo-500/20">
              <Wifi className="w-3 h-3 text-indigo-400" />
              <span className="text-[10px] font-black tracking-[0.2em] text-indigo-400 uppercase">Multiplayer Hub</span>
            </div>
          </motion.div>

          {/* Hero heading */}
          <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.1 }}>
            <h1 className="text-6xl font-black tracking-tighter leading-[0.9] mb-6 text-white">
              BATTLE WITH{" "}
              <br />
              <span className="text-transparent bg-clip-text bg-gradient-to-r from-indigo-400 via-fuchsia-400 to-cyan-300">
                FRIENDS
              </span>
            </h1>
            <p className="text-zinc-300 text-base leading-relaxed max-w-[320px]">
              Enter the arena. Join active global lobbies or architect your own private room for a premium competitive experience.
            </p>
          </motion.div>

          {/* Action Buttons */}
          <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.2 }} className="flex flex-col gap-4">
            <ActionButton
              icon={<Plus className="w-6 h-6" />}
              label="Create Private Lobby"
              subtitle="Host your own custom room"
              variant="primary"
              onClick={() => setShowCreateModal(true)}
            />
            <ActionButton
              icon={<Zap className="w-5 h-5" />}
              label="Quick Match"
              subtitle="Jump into a random game"
              variant="secondary"
              onClick={() => router.push("/studio/multiplayer/matchmaking?mode=matchmaking")}
            />
            <ActionButton
              icon={<Hash className="w-5 h-5" />}
              label="Join by Room ID"
              subtitle="Enter a specific secret code"
              variant="glass"
              onClick={() => {}}
            />
          </motion.div>

          {/* Bottom stats card */}
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ delay: 0.4 }}
            className="mt-auto rounded-3xl border border-white/8 bg-white/[0.03] backdrop-blur-xl p-5 flex items-center gap-4"
          >
            <div className="w-12 h-12 rounded-2xl bg-gradient-to-br from-amber-500/20 to-amber-600/10 flex items-center justify-center border border-amber-500/20">
              <Trophy className="w-5 h-5 text-amber-400" />
            </div>
            <div>
              <div className="text-sm font-bold text-white">Global Ranking</div>
              <div className="text-xs text-zinc-500 mt-0.5">Coming soon for web</div>
            </div>
          </motion.div>
        </div>

        {/* RIGHT PANEL — Active Lobbies */}
        <div className="flex-1 flex flex-col gap-6 min-w-0">
          {/* Header */}
          <motion.div
            initial={{ opacity: 0, y: -10 }}
            animate={{ opacity: 1, y: 0 }}
            className="flex items-center justify-between gap-4"
          >
            <div className="flex items-center gap-4">
              <h2 className="text-2xl font-black tracking-tight text-white">Active Lobbies</h2>
              <div className="px-3 py-1.5 bg-white/5 border border-white/10 rounded-full text-[10px] font-black tracking-widest text-zinc-400 flex items-center gap-2">
                <div className="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-pulse" />
                {filteredRooms.length} ONLINE
              </div>
            </div>
            <div className="relative w-64">
              <Search className="absolute left-4 top-1/2 -translate-y-1/2 w-4 h-4 text-zinc-500" />
              <input
                type="text"
                placeholder="Search rooms..."
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                className="w-full pl-11 pr-4 py-3 bg-white/5 border border-white/10 rounded-2xl focus:outline-none focus:border-indigo-500/40 transition-all text-sm placeholder:text-zinc-600 font-medium"
              />
            </div>
          </motion.div>

          {/* Room Grid */}
          <div className="grid grid-cols-2 gap-5 overflow-y-auto max-h-[calc(100vh-260px)] no-scrollbar pr-1">
            {loading ? (
              Array.from({ length: 6 }).map((_, i) => (
                <div key={i} className="h-44 rounded-[28px] bg-white/[0.03] border border-white/5 animate-pulse" />
              ))
            ) : filteredRooms.length === 0 ? (
              <div className="col-span-2 flex flex-col items-center justify-center py-32 opacity-20">
                <Gamepad2 className="w-20 h-20 mb-4" />
                <p className="text-xl font-bold italic tracking-widest uppercase">No Lobbies Found</p>
              </div>
            ) : (
              filteredRooms.map((room, i) => <RoomCard key={room.roomId} room={room} index={i} />)
            )}
          </div>
        </div>
      </div>

      {/* Create Room Modal */}
      <AnimatePresence>
        {showCreateModal && (
          <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              onClick={() => setShowCreateModal(false)}
              className="absolute inset-0 bg-black/70 backdrop-blur-xl"
            />
            <motion.div
              initial={{ opacity: 0, scale: 0.9, y: 20 }}
              animate={{ opacity: 1, scale: 1, y: 0 }}
              exit={{ opacity: 0, scale: 0.9, y: 20 }}
              className="relative rounded-[40px] p-10 w-full max-w-md border border-white/10 bg-[#0f0f1a] shadow-[0_40px_80px_rgba(0,0,0,0.8)]"
            >
              {/* Close button */}
              <button
                onClick={() => setShowCreateModal(false)}
                className="absolute top-6 right-6 w-8 h-8 flex items-center justify-center rounded-xl border border-white/10 bg-white/5 text-zinc-400 hover:text-white hover:bg-white/10 transition-all"
              >
                <X className="w-4 h-4" />
              </button>

              <div className="w-12 h-12 rounded-2xl bg-gradient-to-br from-indigo-500 to-fuchsia-600 flex items-center justify-center mb-6 shadow-lg">
                <Shield className="w-6 h-6 text-white" />
              </div>
              <h3 className="text-3xl font-black mb-1 tracking-tighter text-white">Initialize Room</h3>
              <p className="text-zinc-400 mb-8 text-sm uppercase tracking-widest font-bold">New Multiplayer Instance</p>

              <input
                autoFocus
                type="text"
                placeholder="Enter lobby name..."
                value={newLobbyName}
                onChange={(e) => setNewLobbyName(e.target.value)}
                onKeyDown={(e) => e.key === "Enter" && handleCreateRoom()}
                className="w-full bg-white/[0.06] border border-white/15 rounded-2xl px-6 py-4 mb-8 focus:outline-none focus:border-indigo-500/60 transition-all font-bold tracking-tight text-white placeholder:text-zinc-500"
              />

              <div className="flex gap-4">
                <button
                  onClick={() => setShowCreateModal(false)}
                  className="flex-1 py-4 rounded-2xl font-bold text-zinc-400 hover:text-white transition-colors border border-white/5 bg-white/[0.02] hover:bg-white/5"
                >
                  Cancel
                </button>
                <button
                  onClick={handleCreateRoom}
                  disabled={!newLobbyName.trim()}
                  className="flex-1 py-4 bg-gradient-to-r from-indigo-600 to-indigo-500 rounded-2xl font-black text-white hover:from-indigo-500 hover:to-indigo-400 transition-all hover:scale-[1.02] active:scale-95 disabled:opacity-40 disabled:pointer-events-none shadow-xl shadow-indigo-500/20"
                >
                  Create Room
                </button>
              </div>
            </motion.div>
          </div>
        )}
      </AnimatePresence>
    </UserShell>
  );
}

function ActionButton({ icon, label, subtitle, variant, onClick }: any) {
  const styles = {
    primary: "bg-gradient-to-r from-indigo-600 to-violet-600 hover:from-indigo-500 hover:to-violet-500 text-white shadow-2xl shadow-indigo-600/25 border border-white/10",
    secondary: "bg-fuchsia-600/10 hover:bg-fuchsia-600/20 text-fuchsia-300 border border-fuchsia-500/20 hover:border-fuchsia-500/40",
    glass: "bg-white/[0.04] hover:bg-white/[0.08] text-white border border-white/10 hover:border-white/20",
  };

  const iconBg = {
    primary: "bg-white/20 text-white",
    secondary: "bg-fuchsia-500/20 text-fuchsia-400",
    glass: "bg-white/10 text-zinc-300",
  };

  return (
    <motion.button
      whileHover={{ scale: 1.02, x: 4 }}
      whileTap={{ scale: 0.97 }}
      onClick={onClick}
      className={`group p-5 rounded-[28px] flex items-center gap-5 transition-all text-left backdrop-blur-xl ${styles[variant as keyof typeof styles]}`}
    >
      <div className={`p-3.5 rounded-2xl shrink-0 transition-transform group-hover:scale-110 ${iconBg[variant as keyof typeof iconBg]}`}>
        {icon}
      </div>
      <div>
        <div className="text-base font-black tracking-tight">{label}</div>
        <div className={`text-xs mt-0.5 ${variant === "primary" ? "text-white/60" : "text-zinc-500"}`}>{subtitle}</div>
      </div>
      <ChevronRight className="w-4 h-4 ml-auto opacity-40 group-hover:opacity-100 group-hover:translate-x-1 transition-all" />
    </motion.button>
  );
}

function RoomCard({ room, index }: { room: Room; index: number }) {
  const isFull = room.members.length >= room.maxPlayers;
  const router = useRouter();
  const fillPct = Math.round((room.members.length / room.maxPlayers) * 100);

  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ delay: index * 0.04 }}
      whileHover={{ y: -5, scale: 1.01 }}
      className="group relative rounded-[24px] overflow-hidden border border-white/10 bg-[#13141f] hover:border-indigo-500/40 hover:bg-[#15162a] transition-all cursor-pointer"
      onClick={() => !isFull && router.push(`/studio/multiplayer/${room.roomId}`)}
    >
      {/* Hover glow */}
      <div className="absolute inset-0 bg-gradient-to-br from-indigo-500/8 via-transparent to-fuchsia-500/5 opacity-0 group-hover:opacity-100 transition-opacity pointer-events-none" />

      <div className="relative z-10 p-5">
        <div className="flex justify-between items-center mb-4">
          <div className="w-11 h-11 rounded-xl bg-gradient-to-br from-indigo-500 to-fuchsia-600 flex items-center justify-center shadow-lg shadow-indigo-500/30 group-hover:scale-105 transition-transform">
            <Gamepad2 className="w-5 h-5 text-white" />
          </div>
          <div
            className={`px-2.5 py-1 rounded-full text-[9px] font-black tracking-[0.15em] border ${
              isFull
                ? "bg-red-500/15 border-red-500/30 text-red-300"
                : "bg-emerald-500/15 border-emerald-500/30 text-emerald-300"
            }`}
          >
            {isFull ? "LOBBY FULL" : "ACTIVE LOBBY"}
          </div>
        </div>

        <h4 className="text-base font-black tracking-tight mb-0.5 text-white group-hover:text-indigo-300 transition-colors truncate">
          {room.name || "Private Room"}
        </h4>
        <div className="text-[10px] font-bold text-zinc-500 uppercase tracking-widest truncate mb-4">{room.roomId}</div>

        <div className="flex items-center justify-between mb-2.5">
          <div className="flex items-center gap-1.5">
            <Users className="w-3.5 h-3.5 text-zinc-500" />
            <span className="text-xs font-bold text-zinc-300">
              {room.members.length} / {room.maxPlayers}
            </span>
          </div>
          <div className="flex items-center gap-1.5">
            <div className={`w-1.5 h-1.5 rounded-full ${isFull ? "bg-red-400" : "bg-emerald-400"} animate-pulse`} />
            <ChevronRight className="w-3.5 h-3.5 text-zinc-500 group-hover:text-indigo-400 group-hover:translate-x-0.5 transition-all" />
          </div>
        </div>

        {/* Fill bar */}
        <div className="h-1 w-full bg-white/[0.06] rounded-full overflow-hidden">
          <motion.div
            initial={{ width: 0 }}
            animate={{ width: `${fillPct}%` }}
            transition={{ duration: 0.8, ease: "easeOut" }}
            className={`h-full rounded-full ${isFull ? "bg-gradient-to-r from-red-500 to-rose-500" : "bg-gradient-to-r from-indigo-500 to-cyan-400"}`}
          />
        </div>
      </div>
    </motion.div>
  );
}
