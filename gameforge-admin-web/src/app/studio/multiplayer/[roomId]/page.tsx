"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { useParams, useRouter, useSearchParams } from "next/navigation";
import { motion, AnimatePresence } from "framer-motion";
import {
  Users, Mic, MicOff, Send, Shield, LogOut, Settings,
  MessageSquare, Play, Copy, ChevronRight, Wifi, WifiOff,
  Gamepad2, Circle, CheckCircle2, Volume2, VolumeX, X,
  PhoneCall, PhoneOff,
} from "lucide-react";
import { useMultiplayerSocket } from "@/lib/multiplayer";
import { readAuthToken } from "@/lib/stores/authStore";
import { apiFetch } from "@/lib/api";
import UserShell from "@/app/_components/UserShell";
import { useToast } from "@/app/_components/ToastProvider";

// ─── WebRTC config ───────────────────────────────────────────────────────────
const ICE_SERVERS = { iceServers: [{ urls: "stun:stun.l.google.com:19302" }] };

export default function StudioMultiplayerRoom() {
  const { roomId } = useParams();
  const router = useRouter();
  const searchParams = useSearchParams();
  const mode = searchParams.get("mode");
  const initialName = searchParams.get("name");
  const toast = useToast();

  const token = readAuthToken();
  const { socket, connected, error } = useMultiplayerSocket(token);

  // ─── Room state ───────────────────────────────────────────────────────────
  const [room, setRoom] = useState<any>(null);
  const [messages, setMessages] = useState<any[]>([]);
  const [chatInput, setChatInput] = useState("");
  const [readyUserIds, setReadyUserIds] = useState<string[]>([]);
  const [loading, setLoading] = useState(true);
  const [myUserId, setMyUserId] = useState<string | null>(null);

  // ─── Game session state ───────────────────────────────────────────────────
  const [gameUrl, setGameUrl] = useState<string | null>(null);
  const [sessionId, setSessionId] = useState<string | null>(null);
  const [sessionStarted, setSessionStarted] = useState(false);
  const [sessionViewMode, setSessionViewMode] = useState<"split" | "shared">("split");
  const [showStartPicker, setShowStartPicker] = useState(false);
  const [startingSession, setStartingSession] = useState(false);
  const [loadingArcade, setLoadingArcade] = useState(false);
  const [arcadeItems, setArcadeItems] = useState<any[]>([]);

  // ─── Voice chat state ─────────────────────────────────────────────────────
  const [voiceJoined, setVoiceJoined] = useState(false);
  const [voiceMuted, setVoiceMuted] = useState(false);
  const [voiceMembers, setVoiceMembers] = useState<string[]>([]); // userIds in voice
  const [sharingGameView, setSharingGameView] = useState(false);
  const [remoteGameStream, setRemoteGameStream] = useState<MediaStream | null>(null);
  const [localBridgeActive, setLocalBridgeActive] = useState(false);
  const [remoteGameplayActive, setRemoteGameplayActive] = useState(false);
  const localStreamRef = useRef<MediaStream | null>(null);
  const localGameStreamRef = useRef<MediaStream | null>(null);
  const remoteVideoRef = useRef<HTMLVideoElement | null>(null);
  const gameFrameRef = useRef<HTMLIFrameElement | null>(null);
  const autoShareAttemptedRef = useRef(false);
  const peerConnsRef = useRef<Map<string, RTCPeerConnection>>(new Map()); // key = peer socketId
  const remoteAudiosRef = useRef<Map<string, HTMLAudioElement>>(new Map()); // key = peer socketId
  const peerUserBySocketRef = useRef<Map<string, string>>(new Map());

  const members = (room?.members ?? []) as any[];
  const teammate = members.find((m: any) => String(m?.userId || "") !== String(myUserId || ""));
  const allReady = members.length > 0 && members.every((m: any) => readyUserIds.includes(String(m?.userId || "")));
  const isHost = Boolean(myUserId && room?.hostUserId && String(room.hostUserId) === String(myUserId));
  const iAmReady = Boolean(myUserId && readyUserIds.includes(String(myUserId)));

  const scrollRef = useRef<HTMLDivElement>(null);

  // ─── Auth guard ───────────────────────────────────────────────────────────
  useEffect(() => {
    if (!token) {
      toast.error("Sign in required", "Please sign in to use Multiplayer");
      router.replace("/signin");
    }
    if (error) {
      toast.error("Multiplayer connection failed", error);
      router.replace("/studio/multiplayer");
    }
  }, [token, error, router, toast]);

  // ─── WebRTC helpers ───────────────────────────────────────────────────────
  const createPeerConn = useCallback((peerSocketId: string, peerUserId?: string): RTCPeerConnection => {
    const pc = new RTCPeerConnection(ICE_SERVERS);
    if (peerUserId) {
      peerUserBySocketRef.current.set(peerSocketId, String(peerUserId));
    }

  // Add local voice tracks
    localStreamRef.current?.getTracks().forEach(t => pc.addTrack(t, localStreamRef.current!));

  // Add local game stream tracks (if sharing enabled)
  localGameStreamRef.current?.getVideoTracks().forEach(t => pc.addTrack(t, localGameStreamRef.current!));

    // ICE candidates → send via socket
    pc.onicecandidate = (e) => {
      if (e.candidate && socket) {
        socket.emit("voice:ice", {
          token,
          roomId: room?.roomId,
          to: peerSocketId,
          data: {
            candidate: e.candidate.candidate,
            sdpMid: e.candidate.sdpMid,
            sdpMLineIndex: e.candidate.sdpMLineIndex,
          },
        });
      }
    };

    // Remote audio track
    pc.ontrack = (e) => {
      if (e.track.kind === "video") {
        const stream = e.streams?.[0] || null;
        if (stream) {
          setRemoteGameStream(stream);
        }
        return;
      }
      const audio = new Audio();
      audio.srcObject = e.streams[0];
      audio.autoplay = true;
      remoteAudiosRef.current.set(peerSocketId, audio);
    };

    peerConnsRef.current.set(peerSocketId, pc);
    return pc;
  }, [socket, token, room?.roomId]);

  const cleanupPeerConn = (peerSocketId: string) => {
    peerConnsRef.current.get(peerSocketId)?.close();
    peerConnsRef.current.delete(peerSocketId);
    const el = remoteAudiosRef.current.get(peerSocketId);
    if (el) {
      el.srcObject = null;
      remoteAudiosRef.current.delete(peerSocketId);
    }
    peerUserBySocketRef.current.delete(peerSocketId);
    if (peerConnsRef.current.size === 0) {
      setRemoteGameStream(null);
    }
  };

  const renegotiatePeer = useCallback(async (peerSocketId: string, pc: RTCPeerConnection) => {
    if (!socket) return;
    const offer = await pc.createOffer();
    await pc.setLocalDescription(offer);
    socket.emit("voice:offer", {
      token,
      roomId: room?.roomId,
      to: peerSocketId,
      data: { type: offer.type, sdp: offer.sdp },
    });
  }, [socket, token, room?.roomId]);

  const recomputeVoiceMembers = useCallback(() => {
    const ids = Array.from(peerUserBySocketRef.current.values()).filter(Boolean);
    setVoiceMembers(Array.from(new Set(ids)));
  }, []);

  const extractPlayUrl = useCallback((it: any) => {
    const raw =
      it?.playUrl ||
      it?.webglUrl ||
      it?.previewUrl ||
      it?.url ||
      it?.gameUrl ||
      it?.webUrl ||
      "";
    const s = String(raw || "").trim();
    return s;
  }, []);

  const buildSharedGameUrl = useCallback((baseUrl: string, sid?: string | null) => {
    const b = String(baseUrl || '').trim();
    if (!b) return '';
    try {
      const u = new URL(b);
      if (room?.roomId) u.searchParams.set('mpRoomId', String(room.roomId));
      if (sid) u.searchParams.set('mpSessionId', String(sid));
      if (myUserId) u.searchParams.set('mpUserId', String(myUserId));
      return u.toString();
    } catch {
      return b;
    }
  }, [room?.roomId, myUserId]);

  const withMpUserId = useCallback((url: string, uid?: string | null) => {
    const u = String(url || '').trim();
    const id = String(uid || '').trim();
    if (!u || !id) return u;
    try {
      const next = new URL(u);
      next.searchParams.set('mpUserId', id);
      return next.toString();
    } catch {
      return u;
    }
  }, []);

  const loadArcadeForStart = useCallback(async () => {
    if (loadingArcade) return;
    try {
      setLoadingArcade(true);
      const data = await apiFetch<any>("/game-feed", { method: "GET", token: token || undefined });
      const list = Array.isArray(data) ? data : (Array.isArray(data?.items) ? data.items : []);
      setArcadeItems(Array.isArray(list) ? list : []);
    } catch {
      setArcadeItems([]);
      toast.error("Arcade unavailable", "Could not load arcade feed right now");
    } finally {
      setLoadingArcade(false);
    }
  }, [loadingArcade, token, toast]);

  const startSessionWithArcade = useCallback(async (item: any) => {
    if (!socket || !room) return;
    const runtimeUrl = extractPlayUrl(item);
    const arcadePostId = String(item?.id || item?._id || "").trim();
    if (!runtimeUrl) {
      toast.error("Missing game URL", "This arcade game does not provide a playable WebGL URL");
      return;
    }
    try {
      setStartingSession(true);
      socket.emit("room:start", {
        token,
        roomId: room.roomId,
        runtimeUrl,
        ...(arcadePostId ? { arcadePostId } : {}),
      });
      setShowStartPicker(false);
      toast.info("Starting session...", "Launching selected arcade game for all players");
    } finally {
      setStartingSession(false);
    }
  }, [socket, room, token, toast, extractPlayUrl]);

  const leaveVoice = useCallback(() => {
    localStreamRef.current?.getTracks().forEach(t => t.stop());
    localStreamRef.current = null;
    peerConnsRef.current.forEach((_, uid) => cleanupPeerConn(uid));
    setVoiceJoined(false);
    setVoiceMuted(false);
    setVoiceMembers([]);
    if (socket && room) socket.emit("voice:leave", { token, roomId: room.roomId });
  }, [socket, token, room]);

  const stopGameShare = useCallback(async () => {
    const gs = localGameStreamRef.current;
    if (gs) {
      gs.getTracks().forEach((t) => t.stop());
      localGameStreamRef.current = null;
    }
    setSharingGameView(false);

    for (const [peerSocketId, pc] of peerConnsRef.current.entries()) {
      const sender = pc.getSenders().find((s) => s.track?.kind === "video");
      if (sender) {
        await sender.replaceTrack(null);
        const shouldOffer = String(socket?.id || "").localeCompare(peerSocketId) < 0;
        if (shouldOffer) {
          await renegotiatePeer(peerSocketId, pc);
        }
      }
    }
  }, [socket?.id, renegotiatePeer]);

  const startGameShare = useCallback(async (opts?: { silent?: boolean }) => {
    const silent = Boolean(opts?.silent);
    if (localGameStreamRef.current) {
      setSharingGameView(true);
      return;
    }

    try {
      const display = await navigator.mediaDevices.getDisplayMedia({
        video: true,
        audio: false,
      });
      localGameStreamRef.current = display;
      setSharingGameView(true);

      const track = display.getVideoTracks()[0];
      if (track) {
        track.onended = () => {
          stopGameShare();
        };
      }

      for (const [peerSocketId, pc] of peerConnsRef.current.entries()) {
        if (!track) continue;
        const existingSender = pc
          .getSenders()
          .find((s) => s.track?.kind === "video");
        if (existingSender) {
          await existingSender.replaceTrack(track);
        } else {
          pc.addTrack(track, display);
        }

        const shouldOffer = String(socket?.id || "").localeCompare(peerSocketId) < 0;
        if (shouldOffer) {
          await renegotiatePeer(peerSocketId, pc);
        }
      }
    } catch {
      if (!silent) {
        toast.error("Share cancelled", "Enable screen/tab share to stream your gameplay live");
      }
    }
  }, [stopGameShare, toast, socket?.id, renegotiatePeer]);

  useEffect(() => {
    if (!sessionStarted || sessionViewMode !== "split" || sharingGameView) return;
    if (autoShareAttemptedRef.current) return;

    const triggerAutoShare = () => {
      if (autoShareAttemptedRef.current) return;
      if (!sessionStarted || sessionViewMode !== "split" || sharingGameView) return;
      autoShareAttemptedRef.current = true;
      void startGameShare({ silent: true });
    };

    window.addEventListener("pointerdown", triggerAutoShare, { once: true, capture: true });

    return () => {
      window.removeEventListener("pointerdown", triggerAutoShare, true);
    };
  }, [sessionStarted, sessionViewMode, sharingGameView, startGameShare]);

  useEffect(() => {
    const el = remoteVideoRef.current;
    if (!el) return;
    if (!remoteGameStream) {
      el.srcObject = null;
      return;
    }
    el.srcObject = remoteGameStream;
    void el.play().catch(() => {});
  }, [remoteGameStream]);

  // ─── Main socket effect ───────────────────────────────────────────────────
  useEffect(() => {
    if (!socket || !connected) return;

    const timeout = window.setTimeout(() => {
      if (!room) {
        toast.error("Multiplayer timeout", "Could not connect to Multiplayer server");
        router.replace("/studio/multiplayer");
      }
    }, 9000);

    socket.emit("mp:auth", { token });

    // Room update (join/member changes)
    const handleRoomUpdate = (payload: any) => {
      const updated = payload?.data?.room ?? payload?.room ?? payload;
      if (!updated || typeof updated !== "object") return;
      setRoom((prev: any) => ({ ...(prev ?? {}), ...updated }));
      if (Array.isArray(updated?.readyUserIds)) {
        setReadyUserIds(updated.readyUserIds.map((x: any) => String(x)));
      }
      setLoading(false);
      window.clearTimeout(timeout);
    };

    const handleReadyUpdate = (payload: any) => {
      const ids = payload?.data?.readyUserIds;
      if (!Array.isArray(ids)) return;
      setReadyUserIds(ids.map((x: any) => String(x)));
    };

    // Someone joined
    const handleMemberJoined = (payload: any) => {
      const m = payload?.data?.member ?? payload?.member ?? payload;
      if (!m) return;
      setRoom((prev: any) => {
        if (!prev) return prev;
        const existing = (prev.members ?? []) as any[];
        if (existing.some((x: any) => String(x.userId) === String(m.userId))) return prev;
        return { ...prev, members: [...existing, m] };
      });
      toast.info(`${m.username || "Someone"} joined`);
    };

    // Someone left
    const handleMemberLeft = (payload: any) => {
      const uid = payload?.data?.userId ?? payload?.userId;
      if (!uid) return;
      setRoom((prev: any) => {
        if (!prev) return prev;
        return { ...prev, members: (prev.members ?? []).filter((m: any) => String(m.userId) !== String(uid)) };
      });
      const targetUserId = String(uid);
      const peerSockets = Array.from(peerUserBySocketRef.current.entries())
        .filter(([, userId]) => String(userId) === targetUserId)
        .map(([socketId]) => socketId);
      for (const sid of peerSockets) cleanupPeerConn(sid);
      recomputeVoiceMembers();
    };

    // Chat
    const handleChatHistory = (payload: any) => {
      const items = payload?.data?.items ?? payload?.items ?? [];
      if (Array.isArray(items)) setMessages(items);
    };
    const handleChatMessage = (payload: any) => {
      const item = payload?.data?.item ?? payload?.item ?? payload;
      if (!item) return;
      setMessages(prev => [...prev, item]);
    };

    // Game start → show game iframe for ALL players
    const handleGameStart = (payload: any) => {
      const url =
        payload?.data?.runtimeUrl ??
        payload?.runtimeUrl ??
        payload?.data?.gameUrl ??
        payload?.gameUrl ??
        payload?.url ??
        null;
      const sessionId = payload?.data?.sessionId ?? payload?.sessionId;
      setLocalBridgeActive(false);
      setRemoteGameplayActive(false);
    autoShareAttemptedRef.current = false;
    setSessionViewMode("split");
      setSessionId(sessionId ? String(sessionId) : null);
      setGameUrl(buildSharedGameUrl(url, sessionId ? String(sessionId) : null));
      setSessionStarted(true);
      toast.success("Session started!", sessionId ? `ID: ${sessionId}` : "All players launching...");
    };

    const handleGameInput = (payload: any) => {
      const data = payload?.data ?? payload;
      if (!data) return;
      if (String(data?.userId || '') === String(myUserId || '')) return;
      setRemoteGameplayActive(true);
      const frameWin = gameFrameRef.current?.contentWindow;
      if (!frameWin) return;
      frameWin.postMessage({
        type: 'gf:mp:remote-input',
        data,
      }, '*');
    };

    const handleGameState = (payload: any) => {
      const data = payload?.data ?? payload;
      if (!data) return;
      if (String(data?.userId || '') === String(myUserId || '')) return;
      setRemoteGameplayActive(true);
      const frameWin = gameFrameRef.current?.contentWindow;
      if (!frameWin) return;
      frameWin.postMessage({
        type: 'gf:mp:state',
        data,
      }, '*');
    };

    // My identity
    const handleAuthOk = (payload: any) => {
      const uid = payload?.data?.userId ?? payload?.userId ?? payload?.id;
      if (uid) setMyUserId(String(uid));
    };

    // ── Voice signaling ──────────────────────────────────────────────────────
    const handleVoiceJoined = async (payload: any) => {
      const peers = payload?.data?.peers;
      setVoiceJoined(true);
      if (!Array.isArray(peers) || !localStreamRef.current) return;
      for (const p of peers) {
        const peerSocketId = String(p?.socketId || "").trim();
        const peerUserId = String(p?.userId || "").trim();
        if (!peerSocketId || peerSocketId === socket.id) continue;
        if (!peerConnsRef.current.has(peerSocketId)) {
          const pc = createPeerConn(peerSocketId, peerUserId);
          const shouldOffer = String(socket.id || "").localeCompare(peerSocketId) < 0;
          if (shouldOffer) {
            const offer = await pc.createOffer();
            await pc.setLocalDescription(offer);
            await renegotiatePeer(peerSocketId, pc);
          }
        } else if (peerUserId) {
          peerUserBySocketRef.current.set(peerSocketId, peerUserId);
        }
      }
      recomputeVoiceMembers();
    };

    const handleVoicePeerJoined = async (payload: any) => {
      const peerSocketId = String(payload?.data?.socketId || payload?.socketId || "").trim();
      const peerUserId = String(payload?.data?.userId || payload?.userId || "").trim();
      if (!peerSocketId || peerSocketId === socket.id || !localStreamRef.current) return;
      if (peerConnsRef.current.has(peerSocketId)) {
        if (peerUserId) peerUserBySocketRef.current.set(peerSocketId, peerUserId);
        recomputeVoiceMembers();
        return;
      }
      const pc = createPeerConn(peerSocketId, peerUserId);
      const shouldOffer = String(socket.id || "").localeCompare(peerSocketId) < 0;
      if (!shouldOffer) {
        recomputeVoiceMembers();
        return;
      }
      await renegotiatePeer(peerSocketId, pc);
      recomputeVoiceMembers();
    };

    const handleVoiceOffer = async (payload: any) => {
      const from = String(payload?.data?.from || payload?.from || "").trim();
      const sdp = payload?.data?.data || payload?.data || payload?.sdp;
      if (!from || !localStreamRef.current || !sdp) return;
      const pc = peerConnsRef.current.get(from) ?? createPeerConn(from);
      await pc.setRemoteDescription(new RTCSessionDescription(sdp));
      const answer = await pc.createAnswer();
      await pc.setLocalDescription(answer);
      socket.emit("voice:answer", {
        token,
        roomId: room?.roomId,
        to: from,
        data: { type: answer.type, sdp: answer.sdp },
      });
    };

    const handleVoiceAnswer = async (payload: any) => {
      const from = String(payload?.data?.from || payload?.from || "").trim();
      const sdp = payload?.data?.data || payload?.data || payload?.sdp;
      const pc = peerConnsRef.current.get(from);
      if (pc && sdp) await pc.setRemoteDescription(new RTCSessionDescription(sdp));
    };

    const handleVoiceIce = async (payload: any) => {
      const from = String(payload?.data?.from || payload?.from || "").trim();
      const candidate = payload?.data?.data || payload?.data || payload?.candidate;
      const pc = peerConnsRef.current.get(from);
      if (pc && candidate) {
        await pc.addIceCandidate(
          new RTCIceCandidate({
            candidate: candidate?.candidate,
            sdpMid: candidate?.sdpMid,
            sdpMLineIndex: candidate?.sdpMLineIndex,
          }),
        );
      }
    };

    const handleVoicePeerLeft = (payload: any) => {
      const peerSocketId = String(payload?.data?.socketId || payload?.socketId || "").trim();
      if (!peerSocketId) return;
      cleanupPeerConn(peerSocketId);
      recomputeVoiceMembers();
    };

    const handleMpError = (payload: any) => {
      window.clearTimeout(timeout);
      toast.error("Multiplayer error", payload?.message ? String(payload.message) : "Unexpected error");
    };

    // Join / Create / Matchmake
  if (mode === "matchmaking") socket.emit("matchmaking:queue", { token });
  else if (mode === "create") socket.emit("room:create", { token, name: initialName });
  else if (roomId) socket.emit("room:join", { token, roomId });

    socket.on("room:update", handleRoomUpdate);
  socket.on("room:ready:update", handleReadyUpdate);
    socket.on("member:joined", handleMemberJoined);
    socket.on("member:left", handleMemberLeft);
    socket.on("chat:history", handleChatHistory);
    socket.on("chat:message", handleChatMessage);
    socket.on("game:start", handleGameStart);
  socket.on("game:input", handleGameInput);
  socket.on("game:state", handleGameState);
  socket.on("mp:auth:ok", handleAuthOk);
  socket.on("voice:joined", handleVoiceJoined);
  socket.on("voice:peer:joined", handleVoicePeerJoined);
    socket.on("voice:offer", handleVoiceOffer);
    socket.on("voice:answer", handleVoiceAnswer);
    socket.on("voice:ice", handleVoiceIce);
  socket.on("voice:peer:left", handleVoicePeerLeft);
    socket.on("mp:error", handleMpError);

    return () => {
      window.clearTimeout(timeout);
      socket.off("room:update", handleRoomUpdate);
      socket.off("room:ready:update", handleReadyUpdate);
      socket.off("member:joined", handleMemberJoined);
      socket.off("member:left", handleMemberLeft);
      socket.off("chat:history", handleChatHistory);
      socket.off("chat:message", handleChatMessage);
      socket.off("game:start", handleGameStart);
  socket.off("game:input", handleGameInput);
  socket.off("game:state", handleGameState);
      socket.off("mp:auth:ok", handleAuthOk);
      socket.off("voice:joined", handleVoiceJoined);
      socket.off("voice:peer:joined", handleVoicePeerJoined);
      socket.off("voice:offer", handleVoiceOffer);
      socket.off("voice:answer", handleVoiceAnswer);
      socket.off("voice:ice", handleVoiceIce);
      socket.off("voice:peer:left", handleVoicePeerLeft);
      socket.off("mp:error", handleMpError);
    };
  }, [socket, connected, roomId, mode, initialName, toast, router, createPeerConn, room?.roomId, token, recomputeVoiceMembers, renegotiatePeer, buildSharedGameUrl, myUserId]);

  useEffect(() => {
    const onMessage = (event: MessageEvent) => {
      if (!sessionStarted) return;
      const d: any = event?.data;
      if (!d || typeof d !== 'object') return;
      if (!socket || !room?.roomId || !sessionId) return;

      if (d.type === 'gf:mp:input' || d.type === 'gf:mp:local-input') {
        setLocalBridgeActive(true);
        socket.emit('game:input', {
          token,
          roomId: room.roomId,
          sessionId,
          type: String(d.inputType || d.kind || 'input'),
          payload: d.payload ?? d.data ?? {},
          ts: typeof d.ts === 'number' ? d.ts : Date.now(),
        });
      }

      if (d.type === 'gf:mp:state' || d.type === 'gf:mp:local-state') {
        setLocalBridgeActive(true);
        socket.emit('game:state', {
          token,
          roomId: room.roomId,
          sessionId,
          state: d.state ?? d.payload ?? d.data ?? {},
          ts: typeof d.ts === 'number' ? d.ts : Date.now(),
        });
      }
    };

    window.addEventListener('message', onMessage);
    return () => window.removeEventListener('message', onMessage);
  }, [sessionStarted, socket, room?.roomId, sessionId, token]);

  // Auto-scroll chat
  useEffect(() => {
    if (scrollRef.current) scrollRef.current.scrollTop = scrollRef.current.scrollHeight;
  }, [messages]);

  // Cleanup on unmount
  useEffect(() => () => {
    void stopGameShare();
    leaveVoice();
  }, [stopGameShare, leaveVoice]);

  // ─── Actions ─────────────────────────────────────────────────────────────
  const handleSendChat = () => {
    if (!chatInput.trim() || !socket) return;
    socket.emit("chat:send", { token, text: chatInput, roomId: room?.roomId });
    setChatInput("");
  };

  const toggleReady = () => {
    if (!socket || !room || !myUserId) return;
    const next = !iAmReady;
    socket.emit("room:ready", { token, ready: next, roomId: room.roomId });
  };

  const handleOpenStartSession = async () => {
    if (!room) return;
    if (!isHost) {
      toast.info("Host only", "Only the room host can start the session");
      return;
    }
    if (!allReady) {
      toast.info("Waiting players", "All room members must be ready before starting");
      return;
    }
    setShowStartPicker(true);
    if (!arcadeItems.length) {
      await loadArcadeForStart();
    }
  };

  const handleLeave = () => {
    leaveVoice();
    if (socket && room) socket.emit("room:leave", { token, roomId: room.roomId });
    router.push("/studio/multiplayer");
  };

  const handleJoinVoice = async () => {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true, video: false });
      localStreamRef.current = stream;
      socket?.emit("voice:join", { token, roomId: room?.roomId });
      toast.success("Voice connected", "You're now in the voice channel");
    } catch {
      toast.error("Microphone denied", "Allow microphone access to use voice chat");
    }
  };

  const toggleMute = () => {
    if (!localStreamRef.current) return;
    const next = !voiceMuted;
    localStreamRef.current.getAudioTracks().forEach(t => (t.enabled = !next));
    setVoiceMuted(next);
  };

  // ─── Loading screen ───────────────────────────────────────────────────────
  if (loading && mode !== "matchmaking") {
    return (
      <UserShell title="Multiplayer" subtitle="Loading">
        <div className="h-[60vh] flex items-center justify-center">
          <div className="flex flex-col items-center gap-6">
            <div className="relative">
              <div className="w-20 h-20 border border-blue-500/30 rounded-full flex items-center justify-center bg-blue-500/5">
                <Gamepad2 className="w-8 h-8 text-blue-400" />
              </div>
              <div className="absolute inset-0 border-2 border-blue-500 rounded-full animate-ping opacity-15" />
            </div>
            <p className="font-black tracking-[0.3em] text-blue-400 uppercase text-sm">Initializing Instance...</p>
          </div>
        </div>
      </UserShell>
    );
  }

  return (
    <UserShell title={room?.name || "Lobby"} subtitle={`Room: ${room?.roomId || "..."}`}>
      {/* Ambient glow */}
      <div className="absolute inset-0 pointer-events-none overflow-hidden">
        <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[700px] h-[700px] bg-blue-600/8 blur-[160px] rounded-full" />
      </div>

      {/* ─── Game Session Overlay ─── */}
      <AnimatePresence>
        {sessionStarted && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 z-50 bg-black flex flex-col"
          >
            {/* Top bar */}
            <div className="flex items-center justify-between px-6 py-3 bg-black/80 border-b border-white/10 shrink-0">
              <div className="flex items-center gap-3">
                <div className="w-2 h-2 rounded-full bg-emerald-500 animate-pulse" />
                <span className="text-xs font-black uppercase tracking-widest text-emerald-400">Session Live</span>
                <span className="text-zinc-600 text-xs">·</span>
                <span className="text-xs font-bold text-zinc-400">{room?.name}</span>
              </div>
              <div className="flex items-center gap-3">
                <button
                  onClick={() => setSessionViewMode((m) => (m === "split" ? "shared" : "split"))}
                  className="px-3 py-1.5 rounded-xl border border-white/10 bg-white/5 text-zinc-300 hover:bg-white/10 transition-all text-xs font-bold"
                >
                  {sessionViewMode === "split" ? "Split Live" : "Shared Sync"}
                </button>
                {sessionViewMode === "split" && (
                  <button
                    onClick={() => {
                      autoShareAttemptedRef.current = true;
                      if (sharingGameView) {
                        void stopGameShare();
                      } else {
                        void startGameShare();
                      }
                    }}
                    className={`px-3 py-1.5 rounded-xl border text-xs font-bold transition-all ${sharingGameView ? "bg-blue-500/20 border-blue-500/40 text-blue-300" : "bg-white/5 border-white/10 text-zinc-300 hover:bg-white/10"}`}
                  >
                    {sharingGameView ? "Stop Share" : "Share Game"}
                  </button>
                )}
                {/* Mini voice controls in session */}
                {voiceJoined && (
                  <button onClick={toggleMute} className={`flex items-center gap-2 px-3 py-1.5 rounded-xl border text-xs font-bold transition-all ${voiceMuted ? "bg-red-500/10 border-red-500/20 text-red-400" : "bg-emerald-500/10 border-emerald-500/20 text-emerald-400"}`}>
                    {voiceMuted ? <MicOff className="w-3.5 h-3.5" /> : <Mic className="w-3.5 h-3.5" />}
                    {voiceMuted ? "Muted" : "Live"}
                  </button>
                )}
                <button
                  onClick={() => {
                    autoShareAttemptedRef.current = false;
                    setSessionStarted(false);
                  }}
                  className="flex items-center gap-2 px-3 py-1.5 rounded-xl border border-white/10 bg-white/5 text-zinc-400 hover:text-white hover:bg-white/10 transition-all text-xs font-bold"
                >
                  <X className="w-3.5 h-3.5" /> Exit Game
                </button>
              </div>
            </div>

            <div className="flex-1 min-h-0 flex bg-[#05060a]">
              <div className="flex-1 min-h-0 p-3 md:p-4 flex flex-col gap-3">
                {sessionViewMode === "split" ? (
                  <>
                    <div className="flex-1 min-h-0 rounded-2xl border border-blue-500/30 overflow-hidden bg-black relative">
                      <div className="absolute left-3 top-3 z-10 px-2.5 py-1 rounded-lg bg-black/70 border border-white/15 text-[10px] font-black tracking-widest text-blue-300 uppercase">
                        You · Top Screen
                      </div>
                      {gameUrl ? (
                        <iframe
                          ref={gameFrameRef}
                          src={gameUrl}
                          className="h-full w-full border-0"
                          allow="fullscreen; autoplay; gamepad; clipboard-write"
                          sandbox="allow-scripts allow-same-origin allow-pointer-lock allow-forms allow-popups"
                        />
                      ) : (
                        <div className="h-full w-full flex flex-col items-center justify-center gap-4 text-zinc-400 text-center p-8">
                          <Gamepad2 className="w-10 h-10 text-blue-400" />
                          <p className="text-xs uppercase tracking-widest font-black">Loading your game view…</p>
                        </div>
                      )}
                    </div>

                    <div className="flex-1 min-h-0 rounded-2xl border border-cyan-500/30 overflow-hidden bg-black relative">
                      <div className="absolute left-3 top-3 z-10 px-2.5 py-1 rounded-lg bg-black/70 border border-white/15 text-[10px] font-black tracking-widest text-cyan-300 uppercase">
                        {teammate?.username || "Teammate"} · Bottom Screen
                      </div>
                      {remoteGameStream ? (
                        <video
                          ref={remoteVideoRef}
                          className="h-full w-full object-cover"
                          autoPlay
                          playsInline
                          muted
                        />
                      ) : gameUrl && teammate?.userId ? (
                        <iframe
                          src={withMpUserId(gameUrl, String(teammate.userId))}
                          className="h-full w-full border-0"
                          allow="fullscreen; autoplay; gamepad; clipboard-write"
                          sandbox="allow-scripts allow-same-origin allow-pointer-lock allow-forms allow-popups"
                        />
                      ) : (
                        <div className="h-full w-full flex flex-col items-center justify-center gap-4 text-zinc-500 text-center p-8">
                          <Users className="w-9 h-9 text-cyan-400" />
                          <p className="text-xs uppercase tracking-widest font-black">Waiting teammate live stream… (or click Share Game if browser blocked auto-share)</p>
                        </div>
                      )}
                    </div>
                  </>
                ) : (
                  <>
                    <div className="flex-1 min-h-0 rounded-2xl border border-blue-500/30 overflow-hidden bg-black relative">
                      <div className="absolute left-3 top-3 z-10 px-2.5 py-1 rounded-lg bg-black/70 border border-white/15 text-[10px] font-black tracking-widest text-blue-300 uppercase">
                        Shared Multiplayer Game
                      </div>
                      {gameUrl ? (
                        <iframe
                          ref={gameFrameRef}
                          src={gameUrl}
                          className="h-full w-full border-0"
                          allow="fullscreen; autoplay; gamepad; clipboard-write"
                          sandbox="allow-scripts allow-same-origin allow-pointer-lock allow-forms allow-popups"
                        />
                      ) : (
                        <div className="h-full w-full flex flex-col items-center justify-center gap-4 text-zinc-400 text-center p-8">
                          <Gamepad2 className="w-10 h-10 text-blue-400" />
                          <p className="text-xs uppercase tracking-widest font-black">Loading your game view…</p>
                        </div>
                      )}
                    </div>

                    <div className="rounded-2xl border border-cyan-500/20 bg-[#0a0d16] px-4 py-3 text-xs text-zinc-400 flex items-center justify-between">
                      <span>
                        {localBridgeActive
                          ? 'Game bridge connected.'
                          : 'Game bridge not detected yet (runtime must emit gf:mp events).'}
                      </span>
                      <span className={`font-black uppercase tracking-widest ${remoteGameplayActive ? 'text-emerald-300' : 'text-cyan-300'}`}>
                        {remoteGameplayActive
                          ? `${teammate?.username || 'Teammate'} gameplay syncing`
                          : `waiting ${teammate?.username || 'teammate'} gameplay events`}
                      </span>
                    </div>
                  </>
                )}
              </div>

              <div className="w-[320px] max-w-[40vw] border-l border-white/10 bg-[#090b12] flex flex-col">
                <div className="px-4 py-3 border-b border-white/10">
                  <div className="text-sm font-black text-white">Live Chat + Voice</div>
                  <div className="text-[10px] uppercase tracking-widest text-zinc-500 mt-1">In-session communication</div>
                </div>

                <div className="p-3 border-b border-white/10 flex items-center gap-2">
                  {voiceJoined ? (
                    <>
                      <button
                        onClick={toggleMute}
                        className={`flex-1 flex items-center justify-center gap-2 px-3 py-2 rounded-xl border text-xs font-bold ${voiceMuted ? "bg-red-500/10 border-red-500/20 text-red-400" : "bg-emerald-500/10 border-emerald-500/20 text-emerald-400"}`}
                      >
                        {voiceMuted ? <MicOff className="w-3.5 h-3.5" /> : <Mic className="w-3.5 h-3.5" />}
                        {voiceMuted ? "Unmute" : "Mute"}
                      </button>
                      <button
                        onClick={leaveVoice}
                        className="px-3 py-2 rounded-xl border border-red-500/30 bg-red-500/10 text-red-400"
                        title="Leave voice"
                      >
                        <PhoneOff className="w-3.5 h-3.5" />
                      </button>
                    </>
                  ) : (
                    <button
                      onClick={handleJoinVoice}
                      className="w-full flex items-center justify-center gap-2 px-3 py-2 rounded-xl border border-emerald-500/25 bg-emerald-500/10 text-emerald-300 text-xs font-bold"
                    >
                      <PhoneCall className="w-3.5 h-3.5" /> Join Voice
                    </button>
                  )}
                </div>

                <div className="flex-1 overflow-y-auto p-3 space-y-2">
                  {messages.length === 0 ? (
                    <div className="h-full flex items-center justify-center text-zinc-500 text-xs uppercase tracking-widest font-black">No chat yet</div>
                  ) : (
                    messages.slice(-80).map((msg, i) => (
                      <ChatBubble
                        key={`${msg?.id || i}`}
                        msg={msg}
                        isMe={myUserId && String(msg.userId) === String(myUserId)}
                      />
                    ))
                  )}
                </div>

                <div className="p-3 border-t border-white/10">
                  <div className="relative">
                    <input
                      type="text"
                      placeholder="Type message..."
                      value={chatInput}
                      onChange={(e) => setChatInput(e.target.value)}
                      onKeyDown={(e) => e.key === "Enter" && handleSendChat()}
                      className="w-full bg-white/5 border border-white/10 rounded-xl pl-3 pr-10 py-2.5 text-sm text-white placeholder:text-zinc-600"
                    />
                    <button
                      onClick={handleSendChat}
                      className="absolute right-1.5 top-1/2 -translate-y-1/2 p-1.5 rounded-lg bg-blue-500 text-white"
                    >
                      <Send className="w-3.5 h-3.5" />
                    </button>
                  </div>
                </div>
              </div>
            </div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* ─── Main 3-Panel Layout ─── */}
      <div className="relative z-10 flex h-[calc(100vh-220px)] min-h-[560px] gap-5 overflow-hidden rounded-3xl">

        {/* LEFT: Room Info + Members */}
        <div className="w-[320px] shrink-0 flex flex-col rounded-[28px] border border-white/[0.07] bg-[var(--gf-panel-bg-strong)] overflow-hidden">
          {/* Header */}
          <div className="p-5 border-b border-white/[0.06]">
            <div className="flex items-center justify-between mb-5">
              <button
                onClick={handleLeave}
                className="flex items-center gap-2 px-3 py-2 rounded-xl border border-white/10 bg-white/5 hover:bg-red-500/10 hover:border-red-500/20 hover:text-red-400 text-zinc-400 transition-all text-xs font-bold"
              >
                <LogOut className="w-3.5 h-3.5" /> Leave
              </button>
              <div className={`flex items-center gap-2 px-3 py-1.5 rounded-full border text-[10px] font-black tracking-widest uppercase ${connected ? "bg-emerald-500/10 border-emerald-500/20 text-emerald-400" : "bg-red-500/10 border-red-500/20 text-red-400"}`}>
                {connected ? <Wifi className="w-3 h-3" /> : <WifiOff className="w-3 h-3" />}
                {connected ? "Live" : "Offline"}
              </div>
            </div>

            <h2 className="text-xl font-black tracking-tighter text-[var(--foreground)] mb-1">{room?.name || "Initializing..."}</h2>
            <div className="flex items-center gap-2 mb-4">
              <span className="text-[10px] font-bold tracking-widest text-zinc-600 truncate max-w-[180px]">{room?.roomId || "..."}</span>
              <button
                onClick={() => { navigator.clipboard.writeText(room?.roomId || ""); toast.success("Copied!"); }}
                className="text-zinc-600 hover:text-blue-400 transition-colors"
              >
                <Copy className="w-3 h-3" />
              </button>
            </div>

            <div className="flex gap-2 flex-wrap">
              <div className="flex items-center gap-1.5 px-2.5 py-1 rounded-full bg-white/5 border border-white/10 text-[10px] font-black text-zinc-400">
                <Users className="w-3 h-3 text-blue-400" />
                {room?.members?.length || 0}/{room?.maxPlayers || 4}
              </div>
              <div className="flex items-center gap-1.5 px-2.5 py-1 rounded-full bg-white/5 border border-white/10 text-[10px] font-black text-zinc-400">
                <Shield className="w-3 h-3 text-cyan-400" />
                HOST: {room?.hostUserId ? "SET" : "..."}
              </div>
            </div>
          </div>

          {/* Members list */}
          <div className="flex-1 overflow-y-auto no-scrollbar p-4 flex flex-col gap-2">
            <div className="text-[10px] font-black tracking-[0.22em] text-zinc-600 mb-1.5 uppercase px-1">
              Party Members ({members.length})
            </div>
            {members.length === 0 ? (
              <div className="flex flex-col items-center justify-center py-10 opacity-20 gap-2">
                <Users className="w-8 h-8" />
                <p className="text-xs font-bold uppercase tracking-widest">Waiting...</p>
              </div>
            ) : (
              members.map((member: any) => (
                <MemberTile
                  key={member.userId}
                  member={member}
                  isHost={room?.hostUserId === member.userId}
                  isReady={readyUserIds.includes(String(member.userId))}
                  inVoice={voiceMembers.includes(String(member.userId))}
                />
              ))
            )}
          </div>

          {/* Voice Channel */}
          <div className="p-4 border-t border-white/[0.06] bg-black/20 space-y-2">
            {voiceJoined ? (
              <div className="flex gap-2">
                <button
                  onClick={toggleMute}
                  className={`flex-1 flex items-center justify-center gap-2 p-3 rounded-2xl border font-bold text-sm transition-all ${voiceMuted ? "bg-red-500/10 border-red-500/20 text-red-400 hover:bg-red-500/20" : "bg-emerald-500/10 border-emerald-500/20 text-emerald-400 hover:bg-emerald-500/20"}`}
                >
                  {voiceMuted ? <MicOff className="w-4 h-4" /> : <Mic className="w-4 h-4" />}
                  {voiceMuted ? "Unmute" : "Mute"}
                </button>
                <button
                  onClick={leaveVoice}
                  className="flex items-center justify-center gap-2 px-4 p-3 rounded-2xl border border-red-500/20 bg-red-500/10 text-red-400 hover:bg-red-500/20 font-bold text-sm transition-all"
                >
                  <PhoneOff className="w-4 h-4" />
                </button>
              </div>
            ) : (
              <button
                onClick={handleJoinVoice}
                className="w-full flex items-center justify-between p-4 rounded-2xl border border-white/10 bg-white/[0.04] hover:bg-green-500/10 hover:border-green-500/20 text-zinc-400 hover:text-green-400 transition-all group"
              >
                <div className="flex items-center gap-3">
                  <div className="p-2 rounded-xl bg-white/5 group-hover:bg-green-500/10">
                    <PhoneCall className="w-4 h-4" />
                  </div>
                  <span className="font-bold text-sm">Join Voice Channel</span>
                </div>
                <div className="flex items-center gap-1.5">
                  {voiceMembers.length > 0 && (
                    <span className="text-[10px] font-black text-zinc-500">{voiceMembers.length} online</span>
                  )}
                  <ChevronRight className="w-4 h-4 group-hover:translate-x-0.5 transition-all" />
                </div>
              </button>
            )}
          </div>
        </div>

        {/* CENTER: Waiting Room */}
        <div className="flex-1 flex flex-col rounded-[28px] border border-white/[0.07] bg-[var(--gf-panel-bg-strong)] overflow-hidden relative">
          <div className="absolute inset-0 flex items-center justify-center pointer-events-none">
            <div className="w-[400px] h-[400px] bg-blue-500/8 blur-[100px] rounded-full animate-pulse" />
          </div>

          {mode === "matchmaking" && !room ? (
            <div className="flex-1 flex flex-col items-center justify-center p-12 relative z-10 text-center gap-8">
              <div className="relative">
                <div className="w-28 h-28 border border-blue-500/30 rounded-full flex items-center justify-center bg-blue-500/5">
                  <Users className="w-10 h-10 text-blue-400" />
                </div>
                <div className="absolute inset-0 border-2 border-blue-500 rounded-full animate-ping opacity-15" />
                <div className="absolute inset-[-14px] border border-blue-500/15 rounded-full animate-spin" style={{ animationDuration: "5s" }} />
              </div>
              <div>
                <h3 className="text-4xl font-black tracking-tighter text-[var(--foreground)] uppercase mb-2">Finding Players</h3>
                <p className="text-zinc-500 italic text-sm">Assembling your elite squad...</p>
              </div>
              <button onClick={handleLeave} className="px-8 py-3 rounded-2xl border border-white/10 bg-white/5 hover:bg-white/10 font-bold text-xs uppercase tracking-widest text-zinc-400 hover:text-white transition-all">
                Cancel Queue
              </button>
            </div>
          ) : (
            <div className="flex-1 flex flex-col items-center justify-center p-8 relative z-10">
              {/* Watermark title */}
              <div className="absolute inset-0 flex items-center justify-center overflow-hidden pointer-events-none select-none">
                <div className="text-[100px] leading-none font-black italic uppercase tracking-tighter text-white/[0.04]">
                  WAITING<br />ROOM
                </div>
              </div>

              <div className="relative z-10 text-center mb-8">
                <p className="text-[var(--gf-text-muted)] text-base leading-relaxed max-w-xs mx-auto">
                  Synchronize readiness with your squad to initialize the session.
                </p>
              </div>

              {/* Ready / Start buttons */}
              <div className="flex gap-4 w-full max-w-md relative z-10">
                {/* Ready button */}
                <motion.button
                  whileHover={{ scale: 1.03 }}
                  whileTap={{ scale: 0.97 }}
                  onClick={toggleReady}
                  className={`flex-1 group relative p-6 rounded-[28px] border-2 transition-all overflow-hidden ${iAmReady
                      ? "bg-emerald-500/10 border-emerald-500/40 text-emerald-400"
                      : "bg-white/[0.04] border-white/10 hover:border-white/20 text-zinc-300"
                    }`}
                >
                  {iAmReady && <div className="absolute inset-0 bg-emerald-500/5 animate-pulse" />}
                  <div className="relative z-10 flex flex-col items-center gap-3">
                    <div className={`w-12 h-12 rounded-2xl flex items-center justify-center transition-all ${iAmReady ? "bg-emerald-500 text-white shadow-lg shadow-emerald-500/30" : "bg-white/10 group-hover:bg-white/20"}`}>
                      {iAmReady ? <CheckCircle2 className="w-6 h-6" /> : <Circle className="w-6 h-6" />}
                    </div>
                    <div>
                      <div className="text-base font-black tracking-tight text-center">{iAmReady ? "I AM READY" : "PREPARE READY"}</div>
                      <div className="text-[10px] font-bold opacity-50 uppercase tracking-widest mt-0.5 text-center">Status Sync</div>
                    </div>
                  </div>
                </motion.button>

                {/* Start Session button */}
                <motion.button
                  whileHover={{ scale: 1.03 }}
                  whileTap={{ scale: 0.97 }}
                  onClick={handleOpenStartSession}
                  disabled={!room || !isHost || !allReady || startingSession}
                  className="flex-1 group relative p-6 rounded-[28px] bg-gradient-to-br from-blue-500 via-blue-600 to-cyan-600 text-white shadow-2xl shadow-blue-500/25 hover:shadow-blue-500/40 transition-all disabled:opacity-25 disabled:pointer-events-none overflow-hidden"
                >
                  <div className="absolute inset-0 bg-gradient-to-r from-transparent via-white/10 to-transparent -translate-x-full group-hover:translate-x-full transition-transform duration-700" />
                  <div className="relative z-10 flex flex-col items-center gap-3">
                    <div className="w-12 h-12 rounded-2xl bg-white/20 group-hover:bg-white/30 flex items-center justify-center transition-all">
                      <Play className="w-6 h-6 fill-current ml-0.5" />
                    </div>
                    <div>
                      <div className="text-base font-black tracking-tight text-center">START SESSION</div>
                      <div className="text-[10px] font-bold opacity-70 uppercase tracking-widest mt-0.5 text-center">
                        {isHost ? (allReady ? "Choose Arcade Game" : "Waiting Members") : "Host Only"}
                      </div>
                    </div>
                  </div>
                </motion.button>
              </div>

              {/* Ready count */}
              <div className="mt-6 flex items-center gap-2 text-xs font-bold text-zinc-600 uppercase tracking-widest relative z-10">
                <div className={`w-2 h-2 rounded-full ${allReady && members.length > 0 ? "bg-emerald-500 animate-pulse" : "bg-zinc-700"}`} />
                {readyUserIds.length}/{members.length} Members Ready
              </div>
            </div>
          )}
        </div>

        {/* RIGHT: Chat */}
        <div className="w-[300px] shrink-0 flex flex-col rounded-[28px] border border-white/[0.07] bg-[var(--gf-panel-bg-strong)] overflow-hidden">
          <div className="p-5 border-b border-white/[0.06] flex items-center justify-between">
            <div className="flex items-center gap-3">
              <div className="w-9 h-9 rounded-xl bg-blue-500/10 border border-blue-500/20 flex items-center justify-center">
                <MessageSquare className="w-4 h-4 text-blue-400" />
              </div>
              <div>
                <div className="text-sm font-bold text-[var(--foreground)]">Lobby Chat</div>
                <div className="text-[9px] font-black tracking-widest text-zinc-600 uppercase">Real-time Comms</div>
              </div>
            </div>
            <button className="p-2 rounded-lg border border-white/10 bg-white/5 hover:bg-white/10 transition-all">
              <Settings className="w-3.5 h-3.5 text-zinc-500" />
            </button>
          </div>

          <div ref={scrollRef} className="flex-1 overflow-y-auto p-4 flex flex-col gap-3 no-scrollbar">
            {messages.length === 0 ? (
              <div className="flex flex-col items-center justify-center py-12 opacity-20 gap-2">
                <MessageSquare className="w-8 h-8" />
                <p className="text-xs font-bold uppercase tracking-widest text-center">Start the conversation!</p>
              </div>
            ) : (
              messages.map((msg, i) => (
                <ChatBubble
                  key={i}
                  msg={msg}
                  isMe={myUserId && String(msg.userId) === String(myUserId)}
                />
              ))
            )}
          </div>

          <div className="p-4 border-t border-white/[0.06] bg-black/20">
            <div className="relative">
              <input
                type="text"
                placeholder="Broadcast a message..."
                value={chatInput}
                onChange={(e) => setChatInput(e.target.value)}
                onKeyDown={(e) => e.key === "Enter" && handleSendChat()}
                className="w-full bg-white/5 border border-white/10 rounded-2xl pl-4 pr-12 py-3 focus:outline-none focus:border-blue-500/40 transition-all font-medium text-sm placeholder:text-zinc-700 text-[var(--foreground)]"
              />
              <button
                onClick={handleSendChat}
                className="absolute right-2.5 top-1/2 -translate-y-1/2 p-2 bg-blue-500 hover:bg-blue-400 active:scale-95 rounded-xl transition-all shadow-lg"
              >
                <Send className="w-3.5 h-3.5 text-white" />
              </button>
            </div>
          </div>
        </div>
      </div>

      <AnimatePresence>
        {showStartPicker && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 z-50"
          >
            <button
              onClick={() => setShowStartPicker(false)}
              className="absolute inset-0 bg-black/70 backdrop-blur-sm"
              aria-label="Close"
            />
            <motion.div
              initial={{ opacity: 0, y: 20, scale: 0.96 }}
              animate={{ opacity: 1, y: 0, scale: 1 }}
              exit={{ opacity: 0, y: 20, scale: 0.96 }}
              className="absolute left-1/2 top-1/2 w-[min(860px,92vw)] -translate-x-1/2 -translate-y-1/2 rounded-3xl border border-white/10 bg-[var(--gf-panel-bg-strong)] shadow-2xl overflow-hidden"
            >
              <div className="px-6 py-4 border-b border-white/10 flex items-center justify-between">
                <div>
                  <h3 className="text-white font-black text-lg tracking-tight">Start Session from Arcade</h3>
                  <p className="text-zinc-500 text-xs uppercase tracking-widest mt-1">All players will launch the same game</p>
                </div>
                <button
                  onClick={() => setShowStartPicker(false)}
                  className="p-2 rounded-xl border border-white/10 bg-white/5 hover:bg-white/10 text-zinc-400"
                >
                  <X className="w-4 h-4" />
                </button>
              </div>

              <div className="p-6 max-h-[65vh] overflow-y-auto space-y-3">
                {loadingArcade ? (
                  <div className="py-12 text-center text-zinc-400 text-sm font-bold uppercase tracking-widest">Loading arcade feed…</div>
                ) : arcadeItems.length === 0 ? (
                  <div className="py-12 text-center text-zinc-500 text-sm">No arcade games available right now.</div>
                ) : (
                  arcadeItems.slice(0, 16).map((it: any, idx: number) => {
                    const title = String(it?.title || it?.name || `Game ${idx + 1}`);
                    const creator = String(it?.ownerUsername || it?.creatorUsername || it?.creator || "creator");
                    const playUrl = extractPlayUrl(it);
                    const playable = playUrl.trim().length > 0;
                    return (
                      <button
                        key={`${String(it?.id || it?._id || 'arcade')}-${idx}`}
                        disabled={!playable || startingSession}
                        onClick={() => startSessionWithArcade(it)}
                        className="w-full text-left p-4 rounded-2xl border border-white/10 bg-white/[0.03] hover:bg-blue-500/10 hover:border-blue-500/30 disabled:opacity-40 disabled:cursor-not-allowed transition-all"
                      >
                        <div className="flex items-center justify-between gap-3">
                          <div>
                            <div className="text-white font-black text-sm tracking-tight">{title}</div>
                            <div className="text-zinc-500 text-xs mt-1">by {creator}</div>
                          </div>
                          <div className="text-[10px] font-black uppercase tracking-widest text-zinc-500">
                            {playable ? "Launch" : "No URL"}
                          </div>
                        </div>
                      </button>
                    );
                  })
                )}
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </UserShell>
  );
}

function MemberTile({ member, isHost, isReady, inVoice }: any) {
  return (
    <motion.div
      initial={{ opacity: 0, x: -8 }}
      animate={{ opacity: 1, x: 0 }}
      className={`p-3 rounded-xl flex items-center justify-between border transition-all ${isReady ? "border-emerald-500/15 bg-emerald-500/5" : "border-white/[0.05] bg-white/[0.02] hover:bg-white/[0.04]"
        } ${!member.isOnline ? "opacity-40" : ""}`}
    >
      <div className="flex items-center gap-3">
        <div className="relative">
          <div className="w-9 h-9 rounded-xl bg-gradient-to-br from-blue-600 to-cyan-600 flex items-center justify-center font-black text-xs text-white shadow-md">
            {member.username?.substring(0, 2).toUpperCase() || "??"}
          </div>
          {member.isOnline && (
            <div className="absolute -top-1 -right-1 w-2.5 h-2.5 bg-green-500 border-2 border-[#0f1018] rounded-full" />
          )}
        </div>
        <div>
          <div className="flex items-center gap-1.5">
            <span className="font-bold text-sm text-white">{member.username}</span>
            {isHost && <Shield className="w-3 h-3 text-cyan-400" />}
            {inVoice && <Volume2 className="w-3 h-3 text-emerald-400" />}
          </div>
          <div className={`text-[9px] font-black tracking-widest uppercase mt-0.5 ${isReady ? "text-emerald-400" : "text-zinc-600"}`}>
            {isReady ? "Squad Ready" : "Waiting"}
          </div>
        </div>
      </div>
      {isReady && <div className="w-2 h-2 rounded-full bg-emerald-500 shadow-[0_0_6px_rgba(34,197,94,0.7)]" />}
    </motion.div>
  );
}

function ChatBubble({ msg, isMe }: any) {
  const time = msg.createdAt
    ? new Date(msg.createdAt).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })
    : "";
  return (
    <div className={`flex flex-col ${isMe ? "items-end" : "items-start"}`}>
      <div className="flex items-center gap-1.5 mb-1 px-1">
        <span className="text-[9px] font-black tracking-widest text-zinc-600 uppercase">{msg.username}</span>
        {time && <span className="text-[8px] text-zinc-700">{time}</span>}
      </div>
      <div className={`px-3.5 py-2 rounded-2xl max-w-[90%] text-sm font-medium leading-snug ${isMe
          ? "bg-gradient-to-br from-blue-600 to-blue-500 text-white rounded-tr-sm shadow-md"
          : "bg-white/[0.07] text-zinc-200 rounded-tl-sm border border-white/[0.06]"
        }`}>
        {msg.text}
      </div>
    </div>
  );
}
