"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { useParams } from "next/navigation";
import { motion, AnimatePresence } from "framer-motion";
import { MessageCircle, Users, Radio, Copy, Sparkles, Heart, Gift, X, Star, Zap, Trophy, Coins } from "lucide-react";
import { Room, RoomEvent, Track, RemoteTrackPublication, RemoteParticipant } from "livekit-client";

function cx(...parts: Array<string | false | null | undefined>) {
  return parts.filter(Boolean).join(" ");
}

import StripeGiftModal from "@/app/_components/StripeGiftModal";

type GiftType = {
  id: string;
  name: string;
  icon: string;
  price: number;
  color: string;
  anim: string;
};

const GIFTS: GiftType[] = [
  { id: "rose", name: "Rose", icon: "🌹", price: 1, color: "from-rose-500 to-pink-500", anim: "heart" },
  { id: "diamond", name: "Diamond", icon: "💎", price: 10, color: "from-cyan-400 to-blue-500", anim: "sparkle" },
  { id: "rocket", name: "Rocket", icon: "🚀", price: 50, color: "from-orange-500 to-red-600", anim: "blast" },
  { id: "crown", name: "Crown", icon: "👑", price: 100, color: "from-yellow-400 to-orange-500", anim: "confetti" },
];

function Rocket3DAnimation({ user }: { user: string }) {
  return (
    <motion.div
      initial={{ y: 520, x: -140, rotate: -18, scale: 0.7, opacity: 0 }}
      animate={{
        y: [-60, -140, -820],
        x: [0, 70, 240],
        rotate: [-18, -8, 0],
        scale: [1, 1.2, 1.55],
        opacity: [0, 1, 1, 0],
      }}
      transition={{ duration: 3.0, ease: "easeOut" }}
      className="absolute inset-0 pointer-events-none z-[60] flex items-center justify-center"
    >
      <div className="relative">
        <motion.div
          animate={{ y: [0, -5, 0] }}
          transition={{ repeat: Infinity, duration: 0.18 }}
          className="text-[180px] filter drop-shadow-[0_0_55px_rgba(255,120,0,0.85)]"
        >
          🚀
        </motion.div>

        <div className="absolute top-[78%] left-1/2 -translate-x-1/2">
          {[...Array(12)].map((_, i) => (
            <motion.div
              key={i}
              initial={{ opacity: 0.9, scale: 1, y: 0, x: 0 }}
              animate={{
                opacity: 0,
                y: 170 + Math.random() * 120,
                x: (Math.random() - 0.5) * 70,
                scale: 0,
              }}
              transition={{ duration: 0.75, repeat: Infinity, delay: i * 0.06 }}
              className="absolute h-12 w-12 rounded-full bg-gradient-to-t from-red-600 via-orange-500 to-yellow-300 blur-xl"
            />
          ))}
          <motion.div
            animate={{ scale: [1, 1.45, 1], opacity: [0.35, 0.65, 0.35] }}
            transition={{ repeat: Infinity, duration: 0.12 }}
            className="h-32 w-20 bg-orange-500/35 blur-3xl rounded-full"
          />
        </div>

        <motion.div
          initial={{ opacity: 0, y: 18 }}
          animate={{ opacity: 1, y: 44 }}
          className="absolute top-full left-1/2 -translate-x-1/2 whitespace-nowrap"
        >
          <div className="px-8 py-4 rounded-2xl bg-black/80 backdrop-blur-2xl border-2 border-orange-500/45 shadow-[0_0_32px_rgba(249,115,22,0.35)]">
            <span className="text-xl font-black italic uppercase tracking-tighter text-transparent bg-clip-text bg-gradient-to-r from-orange-400 via-yellow-200 to-red-500">
              {user} launched a MEGA ROCKET!
            </span>
          </div>
        </motion.div>
      </div>
    </motion.div>
  );
}

type LiveEvent =
  | { type: "chat"; id: string; at: number; user: string; text: string }
  | { type: "like"; id: string; at: number; user: string }
  | { type: "gift"; id: string; at: number; user: string; giftId: string; giftName?: string };

export default function LiveViewerPage() {
  const params = useParams<{ room: string }>();
  const roomName = decodeURIComponent(String(params?.room || "gameforge-live"));

  const [connecting, setConnecting] = useState(false);
  const [connected, setConnected] = useState(false);
  const [viewerCount, setViewerCount] = useState(0);
  const [error, setError] = useState<string | null>(null);

  const roomRef = useRef<Room | null>(null);

  const screenRef = useRef<HTMLVideoElement | null>(null);
  const camRef = useRef<HTMLVideoElement | null>(null);
  const camPipRef = useRef<HTMLVideoElement | null>(null);

  const [toast, setToast] = useState<string | null>(null);
  const [events, setEvents] = useState<LiveEvent[]>([]);
  const [likes, setLikes] = useState(0);
  const [giftScore, setGiftScore] = useState(0);
  const [chatInput, setChatInput] = useState("");
  const [showGiftPicker, setShowGiftPicker] = useState(false);
  const [activeGiftAnim, setActiveGiftAnim] = useState<{ id: string; giftId: string; user: string } | null>(null);
  const [activeLikeAnim, setActiveLikeAnim] = useState<{ id: string; user: string } | null>(null);
  const [selectedGift, setSelectedGift] = useState<GiftType | null>(null);
  const [showStripeModal, setShowStripeModal] = useState(false);

  const [hasScreen, setHasScreen] = useState(false);
  const [hasCam, setHasCam] = useState(false);

  // SFX Helper
  const playSfx = (type: 'like' | 'gift' | 'pop' | 'rocket') => {
    try {
      const Ctx = (window as any).AudioContext || (window as any).webkitAudioContext;
      if (!Ctx) return;
      const ctx = new Ctx();
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.connect(gain);
      gain.connect(ctx.destination);
      
      if (type === 'like') {
        osc.frequency.setValueAtTime(440, ctx.currentTime);
        osc.frequency.exponentialRampToValueAtTime(880, ctx.currentTime + 0.1);
      } else if (type === 'gift') {
        osc.frequency.setValueAtTime(220, ctx.currentTime);
        osc.frequency.exponentialRampToValueAtTime(1200, ctx.currentTime + 0.3);
      } else if (type === 'rocket') {
        osc.frequency.setValueAtTime(180, ctx.currentTime);
        osc.frequency.exponentialRampToValueAtTime(1400, ctx.currentTime + 0.45);
      } else {
        osc.frequency.setValueAtTime(600, ctx.currentTime);
        osc.frequency.exponentialRampToValueAtTime(100, ctx.currentTime + 0.1);
      }

      gain.gain.setValueAtTime(0.05, ctx.currentTime);
      gain.gain.exponentialRampToValueAtTime(0.01, ctx.currentTime + 0.2);
      
      osc.start();
      osc.stop(ctx.currentTime + 0.3);
    } catch {}
  };

  const identityRef = useRef<string>(`viewer-${Math.random().toString(16).slice(2)}`);
  const nameRef = useRef<string>("Viewer");

  const showToast = useCallback((t: string) => {
    setToast(t);
    setTimeout(() => setToast(null), 1600);
  }, []);

  const pushEvent = useCallback((ev: LiveEvent) => {
    setEvents((prev) => [ev, ...prev].slice(0, 60));
    if (ev.type === "like") {
      setLikes((v) => v + 1);
      playSfx('like');
      setActiveLikeAnim({ id: ev.id, user: ev.user });
      setTimeout(() => setActiveLikeAnim(null), 900);
    }
    if (ev.type === "gift") {
      setGiftScore((v) => v + 1);
      playSfx(ev.giftId === "rocket" ? 'rocket' : 'gift');
      setActiveGiftAnim({ id: ev.id, giftId: ev.giftId, user: ev.user });
      setTimeout(() => setActiveGiftAnim(null), 3000);
    }
  }, []);

  const publish = useCallback(
    async (msg: LiveEvent) => {
      const room = roomRef.current;
      if (!room || !connected) return;
      try {
        await room.localParticipant.publishData(new TextEncoder().encode(JSON.stringify(msg)), { reliable: true });
      } catch {
        // ignore
      }
    },
    [connected],
  );

  const attach = useCallback((participant: RemoteParticipant) => {
    // Find screen first
    const pubs = Array.from(participant.trackPublications.values());

    const pickBySource = (source: any) =>
      pubs.find((p) => {
        const s = (p as any)?.source;
        return s === source;
      });

    const pickByName = (names: string[]) =>
      pubs.find((p) => {
        const n = (p.trackName || p.trackSid || "").toLowerCase();
        return names.some((x) => n.includes(x));
      });

    const screenPub = pickBySource((Track as any).Source?.ScreenShare) || pickByName(["screen", "share", "display"]);
    const camPub = pickBySource((Track as any).Source?.Camera) || pickByName(["camera", "cam"]);

    const attachVideo = (pub: RemoteTrackPublication | undefined, el: HTMLVideoElement | null, muted: boolean) => {
      if (!pub || !el) return;
      if (pub.kind !== Track.Kind.Video) return;
      const track = pub.track;
      if (!track) return;
      try {
        track.attach(el);
        el.muted = muted;
        el.playsInline = true;
        el.autoplay = true;
      } catch {}
    };

    attachVideo(screenPub, screenRef.current, true);
    attachVideo(camPub, camRef.current, true);
    attachVideo(camPub, camPipRef.current, true);

    const screenOk = Boolean(screenPub?.track);
    const camOk = Boolean(camPub?.track);
    setHasScreen(screenOk);
    setHasCam(camOk);
  }, []);

  const connect = useCallback(async () => {
    if (connecting) return;
    setConnecting(true);
    setError(null);
    try {
      const identity = identityRef.current;
      const r = await fetch("/api/livekit/token", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ roomName, identity, name: nameRef.current, role: "viewer" }),
      });
      const j = (await r.json().catch(() => null)) as any;
      if (!r.ok || !j?.success || !j?.token || !j?.livekitUrl) {
        setError(j?.message || `Token error (HTTP ${r.status})`);
        return;
      }

      const room = new Room({ adaptiveStream: true, dynacast: true });
      roomRef.current = room;

      room.on(RoomEvent.ParticipantConnected, (p) => {
        setViewerCount(room.remoteParticipants.size);
        attach(p);
      });
      room.on(RoomEvent.ParticipantDisconnected, () => {
        setViewerCount(room.remoteParticipants.size);
      });
      room.on(RoomEvent.TrackSubscribed, (_track, pub, participant) => {
        // attach when we get video tracks
        attach(participant);
      });
      room.on(RoomEvent.DataReceived, (payload, participant) => {
        try {
          const txt = new TextDecoder().decode(payload);
          const j = JSON.parse(txt);
          const user = String(participant?.identity || j?.user || "viewer");
          const type = String(j?.type || "");
          const id = String(j?.id || `${Date.now()}-${Math.random()}`);
          const at = Number(j?.at || Date.now());
          if (type === "chat") {
            pushEvent({ type: "chat", id, at, user, text: String(j?.text || "").slice(0, 400) });
          } else if (type === "like") {
            pushEvent({ type: "like", id, at, user });
          } else if (type === "gift") {
            pushEvent({ type: "gift", id, at, user, giftId: String(j?.giftId || "gift") });
          }
        } catch {
          // ignore
        }
      });
      room.on(RoomEvent.Disconnected, () => {
        setConnected(false);
        setViewerCount(0);
      });

      await room.connect(j.livekitUrl, j.token);
      setConnected(true);
      setViewerCount(room.remoteParticipants.size);

      // attach existing participants
      for (const p of room.remoteParticipants.values()) {
        attach(p);
      }

      showToast("Connected");
    } catch (e: any) {
      setError(String(e?.message || e));
    } finally {
      setConnecting(false);
    }
  }, [attach, connecting, roomName, showToast]);

  const sendChat = useCallback(async () => {
    const text = chatInput.trim();
    if (!text || !connected) return;
    const msg: Extract<LiveEvent, { type: "chat" }> = {
      type: "chat",
      id: `${Date.now()}-${Math.random()}`,
      at: Date.now(),
      user: nameRef.current,
      text,
    };
    pushEvent(msg);
    await publish(msg);
    setChatInput("");
  }, [chatInput, connected, publish, pushEvent]);

  const sendLike = useCallback(async () => {
    if (!connected) return;
    const msg: Extract<LiveEvent, { type: "like" }> = {
      type: "like",
      id: `${Date.now()}-${Math.random()}`,
      at: Date.now(),
      user: nameRef.current,
    };
    pushEvent(msg);
    await publish(msg);
  }, [connected, publish, pushEvent]);

  const sendGift = useCallback(
    async (giftId: string) => {
      const msg: Extract<LiveEvent, { type: "gift" }> = {
        type: "gift",
        id: `${Date.now()}-${Math.random()}`,
        at: Date.now(),
        user: nameRef.current,
        giftId,
      };
      pushEvent(msg);
      if (!connected) {
        showToast("Gift queued (not connected)");
        return;
      }
      await publish(msg);
    },
    [connected, publish, pushEvent, showToast],
  );

  useEffect(() => {
    connect();
    return () => {
      try {
        roomRef.current?.disconnect();
      } catch {}
      roomRef.current = null;
    };
  }, [connect]);

  const shareUrl = useMemo(() => {
    if (typeof window === "undefined") return "";
    return window.location.href;
  }, []);

  return (
    <div className="gf-app min-h-screen text-white">
      <div className="pointer-events-none absolute inset-0">
        <div className="gf-grid absolute inset-0" />
        <div className="gf-noise absolute inset-0" />
      </div>

      <div className="relative mx-auto max-w-6xl px-5 py-7">
        <div className="gf-panel-strong gf-stroke-gradient rounded-[28px] p-5 overflow-hidden relative">
          <div className="absolute inset-0 bg-gradient-to-br from-blue-500/10 via-transparent to-cyan-500/8 pointer-events-none" />

          <div className="relative flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
            <div>
              <div className="flex items-center gap-2">
                <div className="inline-flex items-center gap-2 rounded-full border border-white/10 bg-black/35 px-3 py-1.5 text-[11px] text-zinc-200">
                  <Radio size={14} className={connected ? "text-emerald-300" : "text-zinc-400"} />
                  {connected ? "LIVE" : connecting ? "CONNECTING" : "OFFLINE"}
                </div>
                <div className="inline-flex items-center gap-2 rounded-full border border-white/10 bg-black/35 px-3 py-1.5 text-[11px] text-zinc-400">
                  <Users size={14} className="text-cyan-300" />
                  {viewerCount} watching
                </div>
                <div className="inline-flex items-center gap-2 rounded-full border border-white/10 bg-black/35 px-3 py-1.5 text-[11px] text-zinc-400">
                  <Sparkles size={14} className="text-cyan-300" />
                  {roomName}
                </div>
              </div>
              <h1 className="mt-2 text-2xl font-semibold tracking-tight">Watching Live</h1>
              <p className="mt-1 text-xs text-zinc-400">Gameplay stream with camera PiP (no new tab needed).</p>
            </div>

            <div className="flex items-center gap-2">
              <button
                className="gf-btn rounded-xl px-3 py-2 text-sm"
                onClick={async () => {
                  try {
                    await navigator.clipboard.writeText(shareUrl);
                    showToast("Link copied");
                  } catch {
                    showToast("Copy failed");
                  }
                }}
              >
                <span className="inline-flex items-center gap-2">
                  <Copy size={16} className="text-blue-300" />
                  Share
                </span>
              </button>
            </div>
          </div>

            <div className="mt-4 relative aspect-video w-full overflow-hidden rounded-2xl border border-white/10 bg-black/40">
            <video
              ref={screenRef}
              className={cx(
                "absolute inset-0 h-full w-full object-contain",
                hasScreen ? "opacity-100" : "opacity-0",
              )}
            />

            {/* camera as main (when screen is OFF) */}
            <video
              ref={camRef}
              className={cx(
                "absolute inset-0 h-full w-full object-contain",
                !hasScreen && hasCam ? "opacity-100" : "opacity-0",
              )}
            />

            {/* Like burst */}
            <AnimatePresence>
              {activeLikeAnim ? (
                <motion.div
                  key={activeLikeAnim.id}
                  initial={{ opacity: 0, scale: 0.7 }}
                  animate={{ opacity: 1, scale: 1 }}
                  exit={{ opacity: 0, scale: 1.2 }}
                  className="absolute inset-0 pointer-events-none z-[55] flex items-center justify-center"
                >
                  <div className="relative">
                    {[...Array(10)].map((_, i) => (
                      <motion.div
                        key={i}
                        initial={{ opacity: 0.9, x: 0, y: 0, scale: 0.9 }}
                        animate={{
                          opacity: 0,
                          x: (Math.random() - 0.5) * 260,
                          y: -120 - Math.random() * 140,
                          scale: 0,
                        }}
                        transition={{ duration: 0.9, ease: "easeOut", delay: i * 0.03 }}
                        className="absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2 text-[22px] filter drop-shadow-[0_0_18px_rgba(244,63,94,0.6)]"
                      >
                        ❤
                      </motion.div>
                    ))}
                    <motion.div
                      initial={{ opacity: 0, y: 14 }}
                      animate={{ opacity: 1, y: 34 }}
                      className="absolute top-full left-1/2 -translate-x-1/2 whitespace-nowrap"
                    >
                      <div className="px-4 py-2 rounded-full bg-black/70 backdrop-blur-xl border border-white/15 shadow-2xl">
                        <span className="text-xs font-black italic tracking-wider uppercase text-transparent bg-clip-text bg-gradient-to-r from-rose-300 via-white to-rose-300">
                          {activeLikeAnim.user} liked!
                        </span>
                      </div>
                    </motion.div>
                  </div>
                </motion.div>
              ) : null}
            </AnimatePresence>

            {/* Gift Overlay Animation */}
            <AnimatePresence>
              {activeGiftAnim && activeGiftAnim.giftId === "rocket" ? (
                <Rocket3DAnimation user={activeGiftAnim.user} />
              ) : activeGiftAnim ? (
                <motion.div
                  initial={{ opacity: 0, scale: 0.5 }}
                  animate={{ opacity: 1, scale: 1 }}
                  exit={{ opacity: 0, scale: 1.5 }}
                  className="absolute inset-0 pointer-events-none z-50 flex items-center justify-center"
                >
                  <div className="relative">
                    <motion.div
                      animate={{
                        rotate: [0, 10, -10, 0],
                        scale: [1, 1.2, 1],
                      }}
                      transition={{ repeat: Infinity, duration: 2 }}
                      className="relative z-10 text-[120px] filter drop-shadow-[0_0_30px_rgba(255,255,255,0.4)]"
                    >
                      {GIFTS.find((g) => g.id === activeGiftAnim.giftId)?.icon || "🎁"}
                    </motion.div>

                    {/* Particles / Burst effect */}
                    {[...Array(12)].map((_, i) => (
                      <motion.div
                        key={i}
                        initial={{ opacity: 1, x: 0, y: 0 }}
                        animate={{
                          opacity: 0,
                          x: Math.cos((i * 30 * Math.PI) / 180) * 200,
                          y: Math.sin((i * 30 * Math.PI) / 180) * 200,
                          scale: 0,
                        }}
                        transition={{ duration: 1, ease: "easeOut" }}
                        className="absolute top-1/2 left-1/2 h-4 w-4 rounded-full bg-white shadow-[0_0_15px_white]"
                        style={{ marginTop: -8, marginLeft: -8 }}
                      />
                    ))}

                    <motion.div
                      initial={{ y: 40, opacity: 0 }}
                      animate={{ y: 20, opacity: 1 }}
                      className="absolute top-full left-1/2 -translate-x-1/2 whitespace-nowrap"
                    >
                      <div className="px-4 py-2 rounded-full bg-black/60 backdrop-blur-md border border-white/20 shadow-2xl">
                        <span className="text-sm font-black italic tracking-wider uppercase text-transparent bg-clip-text bg-gradient-to-r from-yellow-300 via-white to-yellow-300">
                          {activeGiftAnim.user} sent a {GIFTS.find((g) => g.id === activeGiftAnim.giftId)?.name}!
                        </span>
                      </div>
                    </motion.div>
                  </div>
                </motion.div>
              ) : null}
            </AnimatePresence>

            {/* live counters */}
            <div className="absolute right-3 top-3 flex items-center gap-2">
              <div className="rounded-full border border-white/10 bg-black/45 px-3 py-1.5 text-[11px] text-zinc-200">
                ❤ {likes}
              </div>
              <div className="rounded-full border border-white/10 bg-black/45 px-3 py-1.5 text-[11px] text-zinc-200">
                🎁 {giftScore}
              </div>
            </div>

            {/* placeholder */}
            <AnimatePresence>
              {!connected && (
                <motion.div
                  initial={{ opacity: 0, scale: 0.98 }}
                  animate={{ opacity: 1, scale: 1 }}
                  exit={{ opacity: 0, scale: 0.98 }}
                  className="absolute inset-0 flex items-center justify-center"
                >
                  <div className="text-center">
                    <p className="text-sm font-semibold">Waiting for stream…</p>
                    <p className="mt-1 text-xs text-zinc-400">If creator is not live yet, keep this page open.</p>
                    {error ? <p className="mt-2 text-xs text-red-300">{error}</p> : null}
                  </div>
                </motion.div>
              )}
            </AnimatePresence>

            {/* PiP (show when both screen + cam exist) */}
            {hasCam && hasScreen ? (
              <div className="absolute bottom-3 right-3 w-[30%] max-w-[220px] overflow-hidden rounded-2xl border border-white/12 bg-black/45 shadow-2xl">
                <div className="absolute inset-0 bg-gradient-to-br from-cyan-500/10 via-transparent to-cyan-500/8 pointer-events-none" />
                <video ref={camPipRef} className="relative h-full w-full object-cover" />
                <div
                  className={cx(
                    "absolute left-2 top-2 rounded-full border border-white/10 bg-black/45 px-2 py-1 text-[10px] text-zinc-200",
                    connected ? "" : "opacity-60",
                  )}
                >
                  CAM
                </div>
              </div>
            ) : null}

            {/* chat overlay */}
            <div className="absolute left-3 top-3 rounded-full border border-white/10 bg-black/45 px-3 py-1.5 text-[11px] text-zinc-200 inline-flex items-center gap-2">
              <MessageCircle size={14} className="text-white/70" />
              Live chat
            </div>

            <div className="absolute left-3 bottom-3 w-[48%] max-w-[520px] space-y-2">
              {events
                .filter((e) => e.type === "chat")
                .slice(0, 4)
                .reverse()
                .map((e) => {
                  const c = e as Extract<LiveEvent, { type: "chat" }>;
                  return (
                    <div key={c.id} className="rounded-xl border border-white/8 bg-black/35 backdrop-blur-md px-3 py-2">
                      <div className="text-[11px] font-semibold text-white/70">{c.user}</div>
                      <div className="text-sm text-white/90 leading-snug">{c.text}</div>
                    </div>
                  );
                })}
            </div>
          </div>

          {/* interactions */}
          <div className="mt-4 gf-panel rounded-2xl p-4">
            <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
              <div>
                <div className="text-sm font-semibold">Reactions</div>
                <div className="mt-1 text-xs text-zinc-500">Chat / Likes / Gifts in real-time</div>
              </div>

              <div className="flex items-center gap-2 relative">
                <motion.button 
                  whileHover={{ scale: 1.05 }}
                  whileTap={{ scale: 0.95 }}
                  className="gf-btn rounded-xl px-3 py-2 text-sm group" 
                  onClick={sendLike} 
                  disabled={!connected}
                >
                  <span className="inline-flex items-center gap-2">
                    <Heart size={16} className="text-rose-300 group-hover:fill-rose-300 transition-colors" />
                    Like
                  </span>
                </motion.button>
                
                <div className="relative">
                  <motion.button 
                    whileHover={{ scale: 1.05 }}
                    whileTap={{ scale: 0.95 }}
                    className={cx(
                      "gf-btn rounded-xl px-3 py-2 text-sm",
                      showGiftPicker && "border-cyan-500/50 bg-cyan-500/10"
                    )}
                    onClick={() => setShowGiftPicker(!showGiftPicker)}
                    disabled={!connected}
                  >
                    <span className="inline-flex items-center gap-2">
                      <Gift size={16} className="text-cyan-300" />
                      Gifts
                    </span>
                  </motion.button>

                  <AnimatePresence>
                    {showGiftPicker && (
                      <motion.div
                        initial={{ opacity: 0, y: 10, scale: 0.95 }}
                        animate={{ opacity: 1, y: 0, scale: 1 }}
                        exit={{ opacity: 0, y: 10, scale: 0.95 }}
                        className="absolute bottom-full right-0 mb-3 w-[280px] gf-panel-strong rounded-2xl p-3 shadow-2xl z-50 border border-white/10"
                      >
                        <div className="flex items-center justify-between mb-3 px-1">
                          <span className="text-xs font-bold uppercase tracking-wider text-white/40">Choose a Gift</span>
                          <button onClick={() => setShowGiftPicker(false)} className="text-white/40 hover:text-white">
                            <X size={14} />
                          </button>
                        </div>
                        <div className="grid grid-cols-2 gap-2">
                          {GIFTS.map((g) => (
                            <motion.button
                              key={g.id}
                              whileHover={{ scale: 1.02, translateY: -2 }}
                              whileTap={{ scale: 0.98 }}
                              onClick={() => {
                                setSelectedGift(g);
                                setShowStripeModal(true);
                                setShowGiftPicker(false);
                              }}
                              className="relative flex flex-col items-center gap-1 rounded-xl border border-white/5 bg-white/5 p-3 hover:bg-white/10 transition-colors group overflow-hidden"
                            >
                              <div className={cx("absolute inset-0 bg-gradient-to-br opacity-0 group-hover:opacity-10 transition-opacity", g.color)} />
                              <span className="text-2xl mb-1">{g.icon}</span>
                              <span className="text-[11px] font-bold">{g.name}</span>
                              <div className="flex items-center gap-1 mt-1">
                                <Coins size={10} className="text-yellow-400" />
                                <span className="text-[10px] text-white/60">{g.price}</span>
                              </div>
                            </motion.button>
                          ))}
                        </div>
                      </motion.div>
                    )}
                  </AnimatePresence>
                </div>
              </div>
            </div>

            <div className="mt-3 flex gap-2">
              <input
                className="gf-input w-full rounded-xl px-3 py-2 text-sm"
                placeholder={connected ? "Write a comment…" : "Connecting…"}
                value={chatInput}
                onChange={(e) => setChatInput(e.target.value)}
                disabled={!connected}
                onKeyDown={(e) => {
                  if (e.key === "Enter") sendChat();
                }}
              />
              <button className="gf-btn rounded-xl px-3 py-2 text-sm" onClick={sendChat} disabled={!connected || !chatInput.trim()}>
                Send
              </button>
            </div>
          </div>
        </div>
      </div>

      <AnimatePresence>
        {toast ? (
          <motion.div
            initial={{ opacity: 0, y: -8, scale: 0.98 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            exit={{ opacity: 0, y: -8, scale: 0.98 }}
            className="fixed right-6 top-6 z-[9999] gf-panel-strong rounded-2xl px-4 py-3"
          >
            <p className="text-sm font-semibold">{toast}</p>
          </motion.div>
        ) : null}
      </AnimatePresence>

      <StripeGiftModal
        isOpen={showStripeModal}
        onClose={() => setShowStripeModal(false)}
        gift={selectedGift}
        onPurchaseSuccess={(giftId) => {
          sendGift(giftId);
          setShowStripeModal(false);
          showToast(`Gift ${giftId} purchased successfully!`);
        }}
      />
    </div>
  );
}
