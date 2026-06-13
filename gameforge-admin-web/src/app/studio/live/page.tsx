"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import {
  Camera,
  Mic,
  MicOff,
  MonitorUp,
  Video,
  VideoOff,
  Radio,
  Users,
  MessageCircle,
  Sparkles,
  Volume2,
  VolumeX,
  Settings,
  Gift,
  Coins,
  X,
  Star,
  Zap,
  Trophy,
} from "lucide-react";
import {
  Room,
  RoomEvent,
  LocalAudioTrack,
  LocalVideoTrack,
  Track,
  type LocalTrack,
} from "livekit-client";
import UserShell from "@/app/_components/UserShell";
import { apiFetch } from "@/lib/api";
import { readAuthToken } from "@/lib/stores/authStore";
import { normalizeImageUrl } from "@/lib/media";

type UserProfile = {
  id: string;
  email: string;
  username: string;
  fullName?: string;
  avatar?: string;
};

type Toast = { id: string; title: string; subtitle?: string };

type LiveEvent =
  | { type: "chat"; id: string; at: number; user: string; text: string }
  | { type: "like"; id: string; at: number; user: string }
  | { type: "gift"; id: string; at: number; user: string; giftId: string };

function cx(...parts: Array<string | false | null | undefined>) {
  return parts.filter(Boolean).join(" ");
}

function useSfx(enabled: boolean) {
  const ctxRef = useRef<AudioContext | null>(null);

  const beep = useCallback(
    (freq = 880, ms = 70, gain = 0.04) => {
      if (!enabled) return;
      try {
        const Ctx = (window as any).AudioContext || (window as any).webkitAudioContext;
        if (!Ctx) return;
        if (!ctxRef.current) ctxRef.current = new Ctx();
        const ctx = ctxRef.current;
        if (!ctx) return;
        const o = ctx.createOscillator();
        const g = ctx.createGain();
        o.type = "sine";
        o.frequency.value = freq;
        g.gain.value = gain;
        o.connect(g);
        g.connect(ctx.destination);
        o.start();
        setTimeout(() => {
          try {
            o.stop();
            o.disconnect();
            g.disconnect();
          } catch { }
        }, ms);
      } catch { }
    },
    [enabled],
  );

  const playRocketSfx = useCallback(() => {
    if (!enabled) return;
    // Launch sound: rising frequency
    beep(220, 180, 0.08);
    setTimeout(() => beep(320, 220, 0.08), 120);
    setTimeout(() => beep(540, 260, 0.09), 240);
    setTimeout(() => beep(900, 320, 0.1), 360);
  }, [beep, enabled]);

  return { beep, playRocketSfx };
}

const GIFTS = [
  { id: "rose", name: "Rose", icon: "🌹", price: 1, color: "from-rose-500 to-pink-500" },
  { id: "diamond", name: "Diamond", icon: "💎", price: 10, color: "from-cyan-400 to-blue-500" },
  { id: "rocket", name: "Rocket", icon: "🚀", price: 50, color: "from-orange-500 to-red-600" },
  { id: "crown", name: "Crown", icon: "👑", price: 100, color: "from-yellow-400 to-orange-500" },
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

export default function LiveStudioPage() {
  const [screenStream, setScreenStream] = useState<MediaStream | null>(null);
  const [camStream, setCamStream] = useState<MediaStream | null>(null);
  const [micStream, setMicStream] = useState<MediaStream | null>(null);

  const [profile, setProfile] = useState<UserProfile | null>(null);

  const [camOn, setCamOn] = useState(false);
  const [micOn, setMicOn] = useState(false);
  const [screenOn, setScreenOn] = useState(false);
  const [muted, setMuted] = useState(true);
  const [sfx, setSfx] = useState(true);

  const [toasts, setToasts] = useState<Toast[]>([]);

  const [roomName, setRoomName] = useState("gameforge-live");
  const [connecting, setConnecting] = useState(false);
  const [connected, setConnected] = useState(false);
  const [viewerCount, setViewerCount] = useState(0);

  const [events, setEvents] = useState<LiveEvent[]>([]);
  const [likes, setLikes] = useState(0);
  const [giftScore, setGiftScore] = useState(0);
  const [chatInput, setChatInput] = useState("");
  const [activeGiftAnim, setActiveGiftAnim] = useState<{ id: string; giftId: string; user: string } | null>(null);
  const [activeLikeAnim, setActiveLikeAnim] = useState<{ id: string; user: string } | null>(null);
  const [giftLeaderboard, setGiftLeaderboard] = useState<Record<string, number>>({});

  const roomRef = useRef<Room | null>(null);
  const publishedRef = useRef<{ screen?: LocalVideoTrack; cam?: LocalVideoTrack; mic?: LocalAudioTrack }>({});

  const screenRef = useRef<HTMLVideoElement | null>(null);
  const camRef = useRef<HTMLVideoElement | null>(null);
  const camPipRef = useRef<HTMLVideoElement | null>(null);

  const { beep, playRocketSfx } = useSfx(sfx);

  useEffect(() => {
    let cancelled = false;
    async function loadProfile() {
      try {
  const token = readAuthToken();
        if (!token) return;
        const res = await apiFetch<any>("/auth/profile", { method: "GET", token });
        const data = (res && typeof res === "object" && "data" in res) ? res.data : res;
        if (!cancelled && data) {
          setProfile((data.user ?? data) as UserProfile);
        }
      } catch (e) {
        console.error("Failed to fetch profile", e);
      }
    }
    loadProfile();
    return () => { cancelled = true; };
  }, []);

  const addToast = useCallback((title: string, subtitle?: string) => {
    const id = `${Date.now()}-${Math.random()}`;
    setToasts((t) => [{ id, title, subtitle }, ...t].slice(0, 4));
    setTimeout(() => setToasts((t) => t.filter((x) => x.id !== id)), 2400);
  }, []);

  useEffect(() => {
    if (screenRef.current) {
      screenRef.current.srcObject = screenStream;
    }
  }, [screenStream]);

  useEffect(() => {
    if (camRef.current) {
      camRef.current.srcObject = camStream;
    }
    if (camPipRef.current) {
      camPipRef.current.srcObject = camStream;
    }
  }, [camStream]);

  const stopPublishedScreen = useCallback(async () => {
    const pub = publishedRef.current;
    if (!pub.screen) return;
    try {
      await roomRef.current?.localParticipant.unpublishTrack(pub.screen);
    } catch { }
    try {
      pub.screen.stop();
    } catch { }
    delete pub.screen;
  }, []);

  const stopPublishedCam = useCallback(async () => {
    const pub = publishedRef.current;
    if (!pub.cam) return;
    try {
      await roomRef.current?.localParticipant.unpublishTrack(pub.cam);
    } catch { }
    try {
      pub.cam.stop();
    } catch { }
    delete pub.cam;
  }, []);

  const startScreen = useCallback(async () => {
    try {
      const s = await (navigator.mediaDevices as any).getDisplayMedia({
        video: {
          frameRate: 30,
          width: { ideal: 1920 },
          height: { ideal: 1080 },
        },
        audio: true,
      });
      setScreenStream(s);
      setScreenOn(true);
      beep(920);
      addToast("Screen capture enabled", "Your gameplay is now visible");

      const track = s.getVideoTracks()[0];
      track?.addEventListener("ended", () => {
        setScreenOn(false);
        setScreenStream(null);
        addToast("Screen capture ended");
      });
    } catch (e: any) {
      addToast("Screen capture denied", "Allow screen recording permission");
    }
  }, [addToast, beep]);

  const stopScreen = useCallback(() => {
    try {
      screenStream?.getTracks().forEach((t) => t.stop());
    } catch { }
    setScreenStream(null);
    setScreenOn(false);
    beep(520);
    addToast("Screen capture stopped");
    // best-effort unpublish if already live
    void stopPublishedScreen();
  }, [addToast, beep, screenStream, stopPublishedScreen]);

  const startCam = useCallback(async () => {
    try {
      const s = await navigator.mediaDevices.getUserMedia({
        video: { width: { ideal: 1280 }, height: { ideal: 720 }, frameRate: { ideal: 30 } },
        audio: false,
      });
      setCamStream(s);
      setCamOn(true);
      beep(820);
      addToast("Camera enabled", "PiP camera overlay is live");
    } catch {
      addToast("Camera denied", "Allow camera permission");
    }
  }, [addToast, beep]);

  const stopCam = useCallback(() => {
    try {
      camStream?.getTracks().forEach((t) => t.stop());
    } catch { }
    setCamStream(null);
    setCamOn(false);
    beep(420);
    addToast("Camera stopped");
    // best-effort unpublish if already live
    void stopPublishedCam();
  }, [addToast, beep, camStream, stopPublishedCam]);

  const startMic = useCallback(async () => {
    try {
      const s = await navigator.mediaDevices.getUserMedia({ audio: true, video: false });
      setMicStream(s);
      setMicOn(true);
      beep(740);
      addToast("Microphone enabled");
    } catch {
      addToast("Microphone denied", "Allow microphone permission");
    }
  }, [addToast, beep]);

  const stopMic = useCallback(() => {
    try {
      micStream?.getTracks().forEach((t) => t.stop());
    } catch { }
    setMicStream(null);
    setMicOn(false);
    beep(360);
    addToast("Microphone muted");
  }, [addToast, beep, micStream]);

  useEffect(() => {
    return () => {
      try {
        screenStream?.getTracks().forEach((t) => t.stop());
        camStream?.getTracks().forEach((t) => t.stop());
        micStream?.getTracks().forEach((t) => t.stop());
      } catch { }
    };
  }, [camStream, micStream, screenStream]);

  const disconnectLivekit = useCallback(async () => {
    try {
      const room = roomRef.current;
      roomRef.current = null;
      setConnected(false);
      setViewerCount(0);

      try {
        await fetch("/api/live-sessions", {
          method: "DELETE",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ roomName: roomName.trim() || "gameforge-live" }),
        });
      } catch { }

      const pub = publishedRef.current;
      publishedRef.current = {};
      const tracks: LocalTrack[] = [];
      if (pub.screen) tracks.push(pub.screen);
      if (pub.cam) tracks.push(pub.cam);
      if (pub.mic) tracks.push(pub.mic);
      for (const t of tracks) {
        try {
          await room?.localParticipant.unpublishTrack(t);
        } catch { }
        try {
          t.stop();
        } catch { }
      }

      try {
        await room?.disconnect();
      } catch { }
      addToast("Disconnected", "LiveKit room closed");
    } catch {
      addToast("Disconnect failed");
    }
  }, [addToast]);

  const connectAndGoLive = useCallback(async () => {
    if (connecting) return;
    if (!roomName.trim()) {
      addToast("Missing room name");
      return;
    }
    if (!screenStream && !camStream) {
      addToast("Enable screen share or camera first");
      return;
    }

    setConnecting(true);
    try {
      const identity = `creator-${Math.random().toString(16).slice(2)}`;
      const r = await fetch("/api/livekit/token", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ roomName: roomName.trim(), identity, name: "Creator", role: "creator" }),
      });
      const j = (await r.json().catch(() => null)) as any;
      if (!r.ok || !j?.success || !j?.token || !j?.livekitUrl) {
        addToast("Token error", j?.message || `HTTP ${r.status}`);
        return;
      }

      const room = new Room({
        adaptiveStream: true,
        dynacast: true,
      });

      const pushEvent = (ev: LiveEvent) => {
        setEvents((prev) => {
          const next = [ev, ...prev].slice(0, 60);
          return next;
        });
        if (ev.type === "like") setLikes((v) => v + 1);
        if (ev.type === "gift") setGiftScore((v) => v + 1);
      };

      room.on(RoomEvent.ParticipantConnected, () => {
        setViewerCount(room.remoteParticipants.size);
      });
      room.on(RoomEvent.ParticipantDisconnected, () => {
        setViewerCount(room.remoteParticipants.size);
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
            beep(440, 100, 0.05);
            setActiveLikeAnim({ id, user });
            setTimeout(() => setActiveLikeAnim(null), 900);
          } else if (type === "gift") {
            const giftId = String(j?.giftId || "gift");
            pushEvent({ type: "gift", id, at, user, giftId });
            if (giftId === "rocket") {
              playRocketSfx();
            } else {
              beep(880, 200, 0.1);
            }
            setActiveGiftAnim({ id, giftId, user });

            // Update leaderboard
            const giftValue = GIFTS.find(g => g.id === giftId)?.price || 1;
            setGiftLeaderboard(prev => ({
              ...prev,
              [user]: (prev[user] || 0) + giftValue
            }));

            setTimeout(() => setActiveGiftAnim(null), 3500);
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
      roomRef.current = room;
      setConnected(true);
      setViewerCount(room.remoteParticipants.size);
      addToast("Connected", "Publishing tracks...");

      try {
        const creatorName = profile?.username || profile?.fullName?.split(" ")[0] || "Creator";
        const creatorAvatarUrl = profile?.avatar
          ? normalizeImageUrl(profile.avatar)
          : `https://api.dicebear.com/7.x/lorelei/svg?seed=${identity}&backgroundColor=b6e3f4,c0aede,d1d4f9,ffdfbf,ffd5dc`;

        await fetch("/api/live-sessions", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            roomName: roomName.trim(),
            creatorIdentity: identity,
            creatorName,
            creatorAvatarUrl,
            gameTitle: "Gameplay",
          }),
        });
      } catch { }

      // Screen (video)
      const screenTrack = screenStream?.getVideoTracks?.()?.[0];
      if (screenTrack) {
        const lkScreen = new LocalVideoTrack(screenTrack);
        await room.localParticipant.publishTrack(lkScreen, { name: "screen", source: Track.Source.ScreenShare });
        publishedRef.current.screen = lkScreen;
      }

      // Camera (video)
      const camTrack = camStream?.getVideoTracks?.()?.[0];
      if (camTrack) {
        const lkCam = new LocalVideoTrack(camTrack);
        await room.localParticipant.publishTrack(lkCam, { name: "camera", source: Track.Source.Camera });
        publishedRef.current.cam = lkCam;
      }

      // Mic (audio)
      const micTrack = micStream?.getAudioTracks?.()?.[0];
      if (micTrack) {
        const lkMic = new LocalAudioTrack(micTrack);
        await room.localParticipant.publishTrack(lkMic, { name: "mic" });
        publishedRef.current.mic = lkMic;
      }

      addToast("Live", `Share /live/${encodeURIComponent(roomName.trim())}`);
      beep(1200);
    } catch (e: any) {
      addToast("Connect failed", String(e?.message || e));
    } finally {
      setConnecting(false);
    }
  }, [addToast, beep, camStream, connecting, micStream, playRocketSfx, roomName, screenStream]);

  const sendCreatorChat = useCallback(async () => {
    const room = roomRef.current;
    const text = chatInput.trim();
    if (!room || !connected || !text) return;
    try {
      const msg: Extract<LiveEvent, { type: "chat" }> = {
        type: "chat",
        id: `${Date.now()}-${Math.random()}`,
        at: Date.now(),
        user: "Creator",
        text,
      };
      await room.localParticipant.publishData(new TextEncoder().encode(JSON.stringify(msg)), { reliable: true });
      setEvents((prev) => [msg, ...prev].slice(0, 60));
      setChatInput("");
    } catch {
      addToast("Send failed");
    }
  }, [addToast, chatInput, connected]);

  const liveReady = (screenOn || camOn) && micOn;

  const right = useMemo(() => {
    return (
      <div className="flex items-center gap-2">
        <button
          className={cx("gf-btn rounded-xl px-3 py-2 text-sm", sfx && "border-white/20")}
          onClick={() => {
            setSfx((v) => !v);
            addToast(!sfx ? "SFX enabled" : "SFX disabled");
          }}
        >
          <span className="inline-flex items-center gap-2">
            <Sparkles size={16} className={sfx ? "text-cyan-300" : "text-zinc-400"} />
            SFX
          </span>
        </button>

        <button
          className={cx("gf-btn rounded-xl px-3 py-2 text-sm", !muted && "border-white/20")}
          onClick={() => setMuted((m) => !m)}
          title="Toggle local preview audio"
        >
          <span className="inline-flex items-center gap-2">
            {muted ? <VolumeX size={16} className="text-zinc-400" /> : <Volume2 size={16} className="text-emerald-300" />}
            Audio
          </span>
        </button>

        <button className="gf-btn rounded-xl px-3 py-2 text-sm" title="Settings (coming soon)">
          <span className="inline-flex items-center gap-2">
            <Settings size={16} className="text-blue-300" />
            Settings
          </span>
        </button>

        {connected ? (
          <button className="gf-btn-danger rounded-xl px-3 py-2 text-sm" onClick={disconnectLivekit}>
            Disconnect
          </button>
        ) : null}
      </div>
    );
  }, [addToast, connected, disconnectLivekit, muted, sfx]);

  return (
    <UserShell
      title="Live Studio"
      subtitle="Capture gameplay + camera + mic (Twitch/Kick style)"
      right={right}
    >
      <div className="grid grid-cols-1 gap-5 xl:grid-cols-[1.7fr_1fr]">
        {/* Main stage */}
        <div className="gf-panel-strong gf-stroke-gradient relative overflow-hidden rounded-[28px] p-4">
          <div className="absolute inset-0 bg-gradient-to-br from-blue-500/8 via-transparent to-cyan-500/6 pointer-events-none" />

          <div className="relative">
            <div className="flex items-center justify-between gap-3">
              <div className="flex items-center gap-2">
                <div className="inline-flex items-center gap-2 rounded-full border border-white/10 bg-black/30 px-3 py-1.5 text-[11px] text-zinc-200">
                  <Radio size={14} className={liveReady ? "text-emerald-300" : "text-zinc-400"} />
                  {liveReady ? "LIVE READY" : "SETUP"}
                </div>
                <div className="inline-flex items-center gap-2 rounded-full border border-white/10 bg-black/30 px-3 py-1.5 text-[11px] text-zinc-400">
                  <Users size={14} className="text-cyan-300" />
                  {viewerCount} watching
                </div>
                {connected ? (
                  <div className="inline-flex items-center gap-2 rounded-full border border-emerald-400/25 bg-emerald-500/10 px-3 py-1.5 text-[11px] text-emerald-200">
                    <span className="h-2 w-2 rounded-full bg-emerald-300 shadow-[0_0_18px_rgba(52,211,153,0.55)]" />
                    LIVE
                  </div>
                ) : null}
              </div>

              <div className="flex items-center gap-2">
                <button
                  className={cx(
                    "gf-btn rounded-xl px-3 py-2 text-sm",
                    screenOn && "border-emerald-400/30 bg-emerald-500/10",
                  )}
                  onClick={screenOn ? stopScreen : startScreen}
                >
                  <span className="inline-flex items-center gap-2">
                    <MonitorUp size={16} className={screenOn ? "text-emerald-300" : "text-zinc-300"} />
                    {screenOn ? "Stop Share" : "Share Screen"}
                  </span>
                </button>

                <button
                  className={cx(
                    "gf-btn rounded-xl px-3 py-2 text-sm",
                    camOn && "border-cyan-400/30 bg-cyan-500/10",
                  )}
                  onClick={camOn ? stopCam : startCam}
                >
                  <span className="inline-flex items-center gap-2">
                    {camOn ? <Video size={16} className="text-cyan-300" /> : <VideoOff size={16} className="text-zinc-300" />}
                    {camOn ? "Cam On" : "Cam Off"}
                  </span>
                </button>

                <button
                  className={cx(
                    "gf-btn rounded-xl px-3 py-2 text-sm",
                    micOn && "border-cyan-400/30 bg-cyan-500/10",
                  )}
                  onClick={micOn ? stopMic : startMic}
                >
                  <span className="inline-flex items-center gap-2">
                    {micOn ? <Mic size={16} className="text-cyan-300" /> : <MicOff size={16} className="text-zinc-300" />}
                    {micOn ? "Mic On" : "Mic Off"}
                  </span>
                </button>
              </div>
            </div>

            <div className="mt-4 relative aspect-video w-full overflow-hidden rounded-2xl border border-white/10 bg-black/40">
              {/* stage grid */}
              <div className="absolute inset-0 gf-grid opacity-40" />
              <div className="absolute inset-0 gf-noise" />

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

              {/* Gift Overlay Animation (Wow effect) */}
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
                        className="relative z-10 text-[120px] filter drop-shadow-[0_0_35px_rgba(255,255,255,0.5)]"
                      >
                        {GIFTS.find(g => g.id === activeGiftAnim.giftId)?.icon || "🎁"}
                      </motion.div>

                      {/* Burst particles */}
                      {[...Array(14)].map((_, i) => (
                        <motion.div
                          key={i}
                          initial={{ opacity: 1, x: 0, y: 0 }}
                          animate={{
                            opacity: 0,
                            x: Math.cos(i * 25 * Math.PI / 180) * 220,
                            y: Math.sin(i * 25 * Math.PI / 180) * 220,
                            scale: 0
                          }}
                          transition={{ duration: 1.2, ease: "easeOut" }}
                          className="absolute top-1/2 left-1/2 h-5 w-5 rounded-full bg-white shadow-[0_0_20px_white]"
                          style={{ marginTop: -10, marginLeft: -10 }}
                        />
                      ))}

                      <motion.div
                        initial={{ y: 50, opacity: 0 }}
                        animate={{ y: 30, opacity: 1 }}
                        className="absolute top-full left-1/2 -translate-x-1/2 whitespace-nowrap"
                      >
                        <div className="px-6 py-3 rounded-full bg-black/70 backdrop-blur-xl border border-white/20 shadow-2xl flex items-center gap-3">
                          <Zap size={18} className="text-yellow-400 animate-pulse" />
                          <span className="text-base font-black italic tracking-wider uppercase text-transparent bg-clip-text bg-gradient-to-r from-yellow-300 via-white to-yellow-300">
                            {activeGiftAnim.user} sent a {GIFTS.find(g => g.id === activeGiftAnim.giftId)?.name}!
                          </span>
                        </div>
                      </motion.div>
                    </div>
                  </motion.div>
                ) : null}
              </AnimatePresence>

              {/* screen */}
              <video
                ref={screenRef}
                autoPlay
                playsInline
                muted={muted}
                className={cx(
                  "absolute inset-0 h-full w-full object-contain",
                  screenOn ? "opacity-100" : "opacity-0",
                )}
              />

              {/* camera as main (when screen is OFF) */}
              <video
                ref={camRef}
                autoPlay
                playsInline
                muted
                className={cx(
                  "absolute inset-0 h-full w-full object-contain",
                  !screenOn && camOn ? "opacity-100" : "opacity-0",
                )}
              />

              {/* placeholder */}
              <AnimatePresence>
                {!screenOn && !camOn && (
                  <motion.div
                    initial={{ opacity: 0, scale: 0.97 }}
                    animate={{ opacity: 1, scale: 1 }}
                    exit={{ opacity: 0, scale: 0.97 }}
                    className="absolute inset-0 flex items-center justify-center"
                  >
                    <div className="text-center">
                      <div className="relative mx-auto mb-5 w-20 h-20">
                        <motion.div
                          animate={{ scale: [1, 1.6, 1], opacity: [0.2, 0.05, 0.2] }}
                          transition={{ duration: 2.5, repeat: Infinity }}
                          className="absolute inset-0 rounded-full bg-red-500/30 blur-xl"
                        />
                        <div className="relative h-full w-full rounded-full bg-[var(--gf-shell-bg)] border border-red-500/20 flex items-center justify-center backdrop-blur-md">
                          <Radio size={28} className="text-red-400" />
                        </div>
                        <motion.div
                          animate={{ opacity: [1, 0, 1] }}
                          transition={{ duration: 1.2, repeat: Infinity }}
                          className="absolute top-1 right-1 h-3 w-3 rounded-full bg-red-500 shadow-[0_0_10px_rgba(239,68,68,0.8)]"
                        />
                      </div>
                      <p className="text-base font-black text-[var(--foreground)] uppercase tracking-wider">Broadcast Ready</p>
                      <p className="mt-2 text-xs text-zinc-500 max-w-[200px] mx-auto leading-relaxed">
                        Enable Screen Share or Camera to begin your live session
                      </p>
                      <div className="mt-4 flex items-center justify-center gap-3">
                        {["SCREEN", "CAM", "MIC"].map((s) => (
                          <div key={s} className="flex items-center gap-1.5 bg-white/[0.04] border border-white/[0.06] rounded-lg px-3 py-1.5">
                            <div className="h-1.5 w-1.5 rounded-full bg-zinc-600" />
                            <span className="text-[9px] font-black uppercase tracking-wider text-zinc-600">{s}</span>
                          </div>
                        ))}
                      </div>
                    </div>
                  </motion.div>
                )}
              </AnimatePresence>

              {/* PiP Camera (only when screen is ON) */}
              <AnimatePresence>
                {screenOn && camOn && (
                  <motion.div
                    initial={{ opacity: 0, y: 12, scale: 0.98 }}
                    animate={{ opacity: 1, y: 0, scale: 1 }}
                    exit={{ opacity: 0, y: 12, scale: 0.98 }}
                    className="absolute bottom-3 right-3 w-[30%] max-w-[220px] overflow-hidden rounded-2xl border border-white/12 bg-black/40 shadow-2xl"
                  >
                    <div className="absolute inset-0 bg-gradient-to-br from-cyan-500/10 via-transparent to-cyan-500/8 pointer-events-none" />
                    <video ref={camPipRef} autoPlay playsInline muted className="relative h-full w-full object-cover" />
                    <div className="absolute left-2 top-2 rounded-full border border-white/10 bg-black/45 px-2 py-1 text-[10px] text-zinc-200">
                      CAM
                    </div>
                  </motion.div>
                )}
              </AnimatePresence>

              {/* chat overlay hint */}
              <div className="absolute left-3 top-3 rounded-full border border-white/10 bg-[var(--gf-shell-bg)]/45 px-3 py-1.5 text-[11px] text-zinc-200 inline-flex items-center gap-2">
                <MessageCircle size={14} className="text-white/70" />
                Live chat
              </div>

              {/* live counters */}
              <div className="absolute right-3 top-3 flex items-center gap-2">
                <div className="rounded-full border border-white/10 bg-black/45 px-3 py-1.5 text-[11px] text-zinc-200">
                  ❤ {likes}
                </div>
                <div className="rounded-full border border-white/10 bg-black/45 px-3 py-1.5 text-[11px] text-zinc-200">
                  🎁 {giftScore}
                </div>
              </div>

              {/* chat overlay (top-left stack) */}
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

            <div className="mt-4 flex flex-wrap items-center gap-2">
              <div className="rounded-full border border-white/10 bg-black/30 px-3 py-1.5 text-[11px] text-zinc-400">
                Output: <span className="text-zinc-200">1080p / 30fps</span>
              </div>
              <div className="rounded-full border border-white/10 bg-black/30 px-3 py-1.5 text-[11px] text-zinc-400">
                Layout: <span className="text-zinc-200">Screen + PiP</span>
              </div>
              <div className="rounded-full border border-white/10 bg-black/30 px-3 py-1.5 text-[11px] text-zinc-400">
                Next: <span className="text-zinc-200">Connect to LiveKit room</span>
              </div>
            </div>
          </div>
        </div>

        {/* Side panel */}
        <div className="space-y-5">
          {/* Gift Leaderboard */}
          <AnimatePresence>
            {Object.keys(giftLeaderboard).length > 0 && (
              <motion.div
                initial={{ opacity: 0, height: 0 }}
                animate={{ opacity: 1, height: 'auto' }}
                className="gf-panel-strong rounded-[24px] p-4 border border-yellow-500/20 bg-yellow-500/5"
              >
                <div className="flex items-center gap-2 mb-3">
                  <Trophy size={16} className="text-yellow-400" />
                  <p className="text-sm font-black uppercase tracking-wider text-yellow-200">Top Supporters</p>
                </div>
                <div className="space-y-2">
                  {Object.entries(giftLeaderboard)
                    .sort(([, a], [, b]) => b - a)
                    .slice(0, 5)
                    .map(([user, total], i) => (
                      <div key={user} className="flex items-center justify-between text-xs">
                        <div className="flex items-center gap-2">
                          <span className="w-4 text-white/30 font-bold">{i + 1}</span>
                          <span className="font-semibold text-white/80">{user}</span>
                        </div>
                        <div className="flex items-center gap-1 text-yellow-400 font-black">
                          <Coins size={10} />
                          {total}
                        </div>
                      </div>
                    ))}
                </div>
              </motion.div>
            )}
          </AnimatePresence>

          <div className="gf-panel-strong rounded-[24px] border border-white/[0.07] overflow-hidden">
            {/* Go Live header */}
            <div className="flex items-center justify-between px-5 py-4 border-b border-white/[0.05]">
              <div className="flex items-center gap-3">
                <div className="h-8 w-8 rounded-xl bg-red-500/15 flex items-center justify-center border border-red-500/25">
                  <Radio size={16} className="text-red-400" />
                </div>
                <span className="text-sm font-black text-[var(--foreground)] uppercase tracking-wider">Broadcast Control</span>
              </div>
              <span className="text-[9px] font-black uppercase tracking-[0.2em] text-zinc-600 border border-white/5 px-2 py-1 rounded-lg">BETA</span>
            </div>

            <div className="p-5 space-y-4">
              {/* Status toggle pills */}
              <div className="grid grid-cols-3 gap-2">
                {[
                  { label: "Screen", on: screenOn, color: "emerald" },
                  { label: "Camera", on: camOn, color: "cyan" },
                  { label: "Mic", on: micOn, color: "cyan" },
                ].map((s) => (
                  <div
                    key={s.label}
                    className={`rounded-2xl border p-3 text-center transition-all ${
                      s.on
                        ? s.color === "emerald" ? "bg-emerald-500/10 border-emerald-500/25" :
                          s.color === "cyan" ? "bg-cyan-500/10 border-cyan-500/25" :
                          "bg-cyan-500/10 border-cyan-500/25"
                        : "bg-black/20 border-white/[0.06]"
                    }`}
                  >
                    <div className={`flex items-center justify-center mb-1 ${
                      s.on
                        ? s.color === "emerald" ? "text-emerald-400" :
                          s.color === "cyan" ? "text-cyan-400" :
                          "text-cyan-400"
                        : "text-zinc-600"
                    }`}>
                      <motion.div
                        animate={s.on ? { opacity: [1, 0.4, 1] } : { opacity: 1 }}
                        transition={{ duration: 1.2, repeat: Infinity }}
                        className={`h-1.5 w-1.5 rounded-full ${s.on ? (s.color === "emerald" ? "bg-emerald-500" : s.color === "cyan" ? "bg-cyan-500" : "bg-cyan-500") : "bg-zinc-700"}`}
                      />
                    </div>
                    <div className="text-[9px] font-black uppercase tracking-[0.15em] text-zinc-400">{s.label}</div>
                    <div className={`text-[11px] font-black mt-0.5 ${
                      s.on
                        ? s.color === "emerald" ? "text-emerald-400" :
                          s.color === "cyan" ? "text-cyan-300" :
                          "text-cyan-300"
                        : "text-zinc-600"
                    }`}>{s.on ? "ON" : "OFF"}</div>
                  </div>
                ))}
              </div>

              {/* Main CTA */}
              <button
                className={cx(
                  "w-full relative overflow-hidden rounded-2xl px-4 py-4 text-sm font-black uppercase tracking-[0.2em] transition-all",
                  liveReady
                    ? connected
                      ? "bg-red-500/80 hover:bg-red-500 text-white shadow-lg shadow-red-500/20"
                      : "bg-gradient-to-r from-red-600 to-rose-600 hover:from-red-500 hover:to-rose-500 text-white shadow-xl shadow-red-500/25 hover:scale-[1.02]"
                    : "border border-white/10 bg-white/5 text-white/40 cursor-not-allowed",
                )}
                disabled={!liveReady}
                onClick={() => { if (connected) { disconnectLivekit(); } else { connectAndGoLive(); } }}
              >
                {liveReady ? (
                  <span className="relative z-10 flex items-center justify-center gap-2">
                    {connected ? (
                      <>End Broadcast</>
                    ) : connecting ? (
                      "Connecting..."
                    ) : (
                      <><Radio size={16} className="animate-pulse" /> Go Live Now</>
                    )}
                  </span>
                ) : "Enable screen + cam/mic first"}
                {liveReady && !connected && (
                  <motion.div
                    animate={{ x: ["-100%", "200%"] }}
                    transition={{ duration: 3, repeat: Infinity, ease: "linear" }}
                    className="absolute inset-0 bg-gradient-to-r from-transparent via-white/10 to-transparent skew-x-12"
                  />
                )}
              </button>

              {/* Viewer link */}
              <div className="rounded-2xl border border-white/[0.06] bg-black/20 p-4">
                <p className="text-[9px] text-zinc-600 uppercase tracking-[0.25em] mb-2">Viewer Link</p>
                <p className="text-xs text-zinc-300 break-all font-mono">/live/{encodeURIComponent(roomName.trim() || "gameforge-live")}</p>
                <div className="mt-3 flex gap-2">
                  <input
                    value={roomName}
                    onChange={(e) => setRoomName(e.target.value)}
                    className="gf-input flex-1 rounded-xl px-3 py-2 text-xs"
                    placeholder="room name"
                  />
                  <button
                    className="gf-btn rounded-xl px-3 py-2 text-xs font-black uppercase tracking-wider"
                    onClick={async () => {
                      try {
                        const link = `${window.location.origin}/live/${encodeURIComponent(roomName.trim() || "gameforge-live")}`;
                        await navigator.clipboard.writeText(link);
                        beep(980);
                        addToast("Copied", "Viewer link copied");
                      } catch {
                        addToast("Copy failed");
                      }
                    }}
                  >
                    Copy
                  </button>
                </div>
              </div>
            </div>
          </div>

          <div className="gf-panel rounded-[24px] p-4">
            <p className="text-sm font-semibold">Chat & Reactions</p>
            <div className="mt-3 space-y-2">
              {[
                { u: "@viewer_01", m: "gg 🔥" },
                { u: "@cyberkid", m: "camera overlay is clean" },
                { u: "@neonfox", m: "drop the link" },
              ].map((x, i) => (
                <motion.div
                  key={i}
                  initial={{ opacity: 0, y: 6 }}
                  animate={{ opacity: 1, y: 0 }}
                  transition={{ delay: 0.05 * i }}
                  className="rounded-2xl border border-white/6 bg-black/20 p-3"
                >
                  <p className="text-[11px] text-white/55 font-semibold">{x.u}</p>
                  <p className="text-sm text-white/85">{x.m}</p>
                </motion.div>
              ))}
            </div>
            <div className="mt-3 flex gap-2">
              <input
                className="gf-input w-full rounded-xl px-3 py-2 text-sm"
                placeholder={connected ? "Type as Creator…" : "Connect to go live"}
                value={chatInput}
                onChange={(e) => setChatInput(e.target.value)}
                disabled={!connected}
              />
              <button className="gf-btn rounded-xl px-3 py-2 text-sm" onClick={sendCreatorChat} disabled={!connected || !chatInput.trim()}>
                Send
              </button>
            </div>
          </div>
        </div>
      </div>

      {/* toasts */}
      <div className="fixed right-6 top-6 z-[9999] space-y-2">
        <AnimatePresence>
          {toasts.map((t) => (
            <motion.div
              key={t.id}
              initial={{ opacity: 0, x: 10, y: -6 }}
              animate={{ opacity: 1, x: 0, y: 0 }}
              exit={{ opacity: 0, x: 10, y: -6 }}
              className="gf-panel-strong rounded-2xl p-3 min-w-[260px]"
            >
              <p className="text-sm font-semibold">{t.title}</p>
              {t.subtitle ? <p className="text-xs text-zinc-400 mt-0.5">{t.subtitle}</p> : null}
            </motion.div>
          ))}
        </AnimatePresence>
      </div>
    </UserShell>
  );
}
