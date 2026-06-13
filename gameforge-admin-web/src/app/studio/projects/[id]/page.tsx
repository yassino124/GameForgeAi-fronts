"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import { useParams, useRouter } from "next/navigation";
import { motion } from "framer-motion";
import UserShell from "@/app/_components/UserShell";
import { apiFetch, apiFetchForm, ApiError } from "@/lib/api";
import { useAuthToken } from "@/lib/stores/authStore";
import { normalizeImageUrl } from "@/lib/media";
import { Zap as ZapIcon, Play, Box, Settings2, RefreshCcw, Activity, Globe, Layers, Download, Smartphone, Monitor, Clapperboard, Sparkles, X, ExternalLink } from "lucide-react";

type TrailerStyle = "energetic" | "cinematic" | "funny";
type TrailerTarget = "tiktok" | "reels" | "short";
type HighlightMode = "auto" | "trim";
type MusicMode = "auto" | "custom";
type AIDirectorProvider = "gemini" | "ollama";

type AIDirectorPlan = {
  style: TrailerStyle;
  target: TrailerTarget;
  highlightMode: HighlightMode;
  musicMode: MusicMode;
  customMusicUrl?: string;
  musicCue?: string;
  reelTitle?: string;
  captionHook?: string;
};

type TrailerJob = {
  id: string;
  trailerId?: string;
  status: "queued" | "processing" | "ready" | "failed";
  stage?: string;
  progress?: number;
  elapsedSec?: number;
  etaSec?: number;
  estimatedTotalSec?: number;
  error?: string;
  style?: TrailerStyle;
  target?: TrailerTarget;
  reelTitle?: string;
  feedPostId?: string | null;
};

type TrailerResult = {
  trailerId: string;
  videoUrl: string;
  thumbnailUrl?: string;
  durationSec?: number;
  captions?: string[];
  highlightsSec?: number[];
  overlayText?: string;
  style?: TrailerStyle;
  target?: TrailerTarget;
  reelTitle?: string;
  feedPostId?: string | null;
};

type RecordingState = "idle" | "requesting" | "recording" | "uploading" | "ready" | "failed";
type TrailerEventPayload = { t: number; type: string; scoreDelta?: number };

type Project = {
  id?: string;
  _id?: string;
  name?: string;
  description?: string;
  status?: string;
  buildTarget?: string;
  androidApkStorageKey?: string;
  macosZipStorageKey?: string;
  windowsZipStorageKey?: string;
  updatedAt?: string;
  createdAt?: string;
  downloadCount?: number;
  downloadsCount?: number;
  previewImageUrl?: string;
  thumbnailUrl?: string;
  iconUrl?: string;
  imageUrl?: string;
};

function clampNum(v: any, min: number, max: number, fallback: number) {
  const n = typeof v === "number" ? v : Number(v);
  if (!Number.isFinite(n)) return fallback;
  return Math.max(min, Math.min(max, n));
}

function normHex(v: any, fallback: string) {
  const s = (typeof v === "string" ? v : "").trim();
  if (!s) return fallback;
  const n = s.startsWith("#") ? s : `#${s}`;
  if (!/^#[0-9a-fA-F]{6}$/.test(n)) return fallback;
  return n.toUpperCase();
}

function formatDuration(totalSec: number) {
  const safe = Math.max(0, Math.floor(Number(totalSec) || 0));
  const mm = Math.floor(safe / 60)
    .toString()
    .padStart(2, "0");
  const ss = Math.floor(safe % 60)
    .toString()
    .padStart(2, "0");
  return `${mm}:${ss}`;
}

function parseJsonBlock(text: string) {
  const raw = String(text || "");
  const fenced = raw.match(/```json\s*([\s\S]*?)```/i) || raw.match(/```\s*([\s\S]*?)```/i);
  const candidate = (fenced?.[1] || raw).trim();
  try {
    return JSON.parse(candidate);
  } catch {}

  const first = raw.indexOf("{");
  const last = raw.lastIndexOf("}");
  if (first >= 0 && last > first) {
    try {
      return JSON.parse(raw.slice(first, last + 1));
    } catch {}
  }
  return null;
}

function trailerJobId(job: Partial<TrailerJob> | null | undefined) {
  return String(job?.id || job?.trailerId || "").trim();
}

function normalizeTrailerJob(raw: any): TrailerJob {
  const id = String(raw?.id || raw?.trailerId || "").trim();
  return {
    ...(raw || {}),
    id,
    trailerId: String(raw?.trailerId || id || "").trim() || undefined,
  } as TrailerJob;
}

const EmbeddedWebgl = ({ url }: { url: string }) => (
  <div className="relative h-[440px] w-full overflow-hidden rounded-3xl bg-black/40 border border-white/5">
    <div className="absolute inset-0 bg-gradient-to-br from-blue-600/10 via-transparent to-sky-500/10 pointer-events-none" />
    <iframe
      src={url}
      className="relative z-10 h-full w-full"
      allow="autoplay; fullscreen; gamepad"
      sandbox="allow-scripts allow-same-origin allow-pointer-lock allow-forms"
    />
  </div>
);

const Scene3D = ({ config }: { config: any }) => (
  <div className="relative h-64 w-full flex items-center justify-center perspective-1000 overflow-hidden rounded-3xl bg-black/40 border border-white/5">
    <div className="absolute inset-0 bg-gradient-to-br from-blue-600/10 via-transparent to-sky-500/10 pointer-events-none" />
    
    <motion.div 
      animate={{ 
        rotateY: 360,
        rotateX: [0, 10, 0, -10, 0],
      }}
      transition={{ 
        rotateY: { duration: 20, repeat: Infinity, ease: "linear" },
        rotateX: { duration: 10, repeat: Infinity, ease: "easeInOut" }
      }}
      className="relative w-32 h-32 preserve-3d"
    >
      {/* 3D Cube representing the project core */}
      {[
        { transform: "rotateY(0deg) translateZ(64px)", color: "primary" },
        { transform: "rotateY(90deg) translateZ(64px)", color: "secondary" },
        { transform: "rotateY(180deg) translateZ(64px)", color: "primary" },
        { transform: "rotateY(270deg) translateZ(64px)", color: "secondary" },
        { transform: "rotateX(90deg) translateZ(64px)", color: "accent" },
        { transform: "rotateX(-90deg) translateZ(64px)", color: "accent" },
      ].map((face, i) => (
        <div 
          key={i}
          className="absolute inset-0 border border-white/20 backdrop-blur-md flex items-center justify-center overflow-hidden"
          style={{ 
            transform: face.transform,
            backgroundColor: i === 0 ? (config.primaryColor || "#6366f1") + "44" : "rgba(255,255,255,0.03)"
          }}
        >
          <div className="gf-grid absolute inset-0 opacity-30" />
          {i === 0 && <Box className="text-white" size={40} strokeWidth={1} />}
        </div>
      ))}
    </motion.div>

    {/* HUD Overlays */}
    <div className="absolute top-6 left-6 flex flex-col gap-2">
      <div className="flex items-center gap-2">
        <div className="h-1.5 w-1.5 rounded-full bg-blue-500 animate-pulse" />
        <span className="text-[10px] font-black uppercase tracking-widest text-blue-400">Engine Core v4</span>
      </div>
      <div className="text-[9px] font-bold text-zinc-500 uppercase tracking-widest leading-none">
        {config.buildTarget || "WEBGL"} // RENDER_ACTIVE
      </div>
    </div>

    <div className="absolute bottom-6 right-6 flex flex-col items-end gap-1">
      <div className="text-[10px] font-mono text-zinc-500">POS: 0.0, 0.0, 0.0</div>
      <div className="text-[10px] font-mono text-zinc-500">ROT: AUTO_SPIN</div>
    </div>
  </div>
);

const SandboxPreview = ({ config, previewUrl }: { config: any; previewUrl?: string | null }) => {
  return (
    <div className="space-y-6">
      {previewUrl ? <EmbeddedWebgl url={previewUrl} /> : <Scene3D config={config} />}
      
      {/* Simulation HUD */}
      <div className="flex justify-between items-start">
        <div className="flex flex-col gap-1">
          <span className="text-[10px] font-black text-blue-400 uppercase tracking-widest bg-blue-500/10 px-2 py-1 rounded-lg border border-blue-500/20">
            Sandbox Active
          </span>
          <div className="flex items-center gap-2 mt-2">
            <div className="h-1.5 w-1.5 rounded-full bg-emerald-500 animate-pulse" />
            <span className="text-[9px] font-bold text-zinc-500 uppercase tracking-tighter">Physics: {config.useAdvancedPhysics ? "Adv" : "Standard"}</span>
          </div>
        </div>
        <div className="flex flex-col items-end gap-1">
          <span className="text-[10px] font-mono text-zinc-500">{config.speed} m/s</span>
          <span className="text-[10px] font-mono text-zinc-500">{config.gravityY} G</span>
        </div>
      </div>
    </div>
  );
};

const LogicNode = ({ title, desc, icon: Icon, delay = 0 }: { title: string, desc: string, icon: any, delay?: number }) => (
  <motion.div
    initial={{ opacity: 0, scale: 0.9, y: 20 }}
    whileInView={{ opacity: 1, scale: 1, y: 0 }}
    viewport={{ once: true }}
    transition={{ delay, duration: 0.5 }}
    className="gf-panel p-4 rounded-2xl border border-white/5 bg-white/[0.02] relative group"
  >
    <div className="flex items-start gap-4">
      <div className="h-10 w-10 rounded-xl bg-blue-500/10 flex items-center justify-center text-blue-400 shrink-0 group-hover:bg-blue-500/20 transition-colors">
        <Icon size={20} />
      </div>
      <div className="min-w-0">
        <div className="text-[10px] font-black text-white uppercase tracking-widest leading-none mb-1">{title}</div>
        <p className="text-[10px] text-zinc-500 font-medium leading-relaxed line-clamp-2">{desc}</p>
      </div>
    </div>
  </motion.div>
);

const LogicVisualizer = ({ project }: { project: any }) => {
  const nodes = [
    { title: "Input Mapping", desc: "Adaptive control binding for WebGL/Touch", icon: ZapIcon },
    { title: "Physics Matrix", desc: `Gravity: ${project?.gravityY} | Speed: ${project?.speed}`, icon: Activity },
    { title: "Collision Core", desc: project?.useAdvancedPhysics ? "High-fidelity kinematic solver" : "Standard axis-aligned logic", icon: Box },
    { title: "Asset Pipeline", desc: "Streaming neural texture compression", icon: Layers },
  ];

  return (
    <div className="relative">
      {/* Background connecting lines (SVG) */}
      <svg className="absolute inset-0 w-full h-full pointer-events-none opacity-10">
        <line x1="50%" y1="0" x2="50%" y2="100%" stroke="white" strokeWidth="1" strokeDasharray="4 4" />
      </svg>
      
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 relative z-10">
        {nodes.map((n, i) => (
          <LogicNode key={i} {...n} delay={i * 0.1} />
        ))}
      </div>
    </div>
  );
};

export default function StudioProjectDetailsPage() {
  const router = useRouter();
  const params = useParams<{ id: string }>();
  const { token } = useAuthToken();
  const id = (params?.id || "").toString();

  const [authUserId, setAuthUserId] = useState("");
  const [tournamentId, setTournamentId] = useState<string | null>(null);
  const [tournamentLastScore, setTournamentLastScore] = useState<number | null>(null);
  const [tournamentLastDurationSec, setTournamentLastDurationSec] = useState<number | null>(null);
  const [tournamentSubmitBusy, setTournamentSubmitBusy] = useState(false);
  const [tournamentSubmitErr, setTournamentSubmitErr] = useState<string | null>(null);

  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [project, setProject] = useState<any | null>(null);
  const [busy, setBusy] = useState<string | null>(null);

  const [previewUrl, setPreviewUrl] = useState<string | null>(null);
  const [draft, setDraft] = useState<any>({});
  const [dirty, setDirty] = useState(false);
  const [autoApply, setAutoApply] = useState(true);
  const [toast, setToast] = useState<{ id: number; kind: "ok" | "err" | "info"; msg: string } | null>(null);
  const [iframeNonce, setIframeNonce] = useState(0);
  const autoSaveTimerRef = useRef<any>(null);
  const trailerPollTimerRef = useRef<any>(null);
  const mediaRecorderRef = useRef<MediaRecorder | null>(null);
  const recordingStreamRef = useRef<MediaStream | null>(null);
  const recordingChunksRef = useRef<Blob[]>([]);
  const recordingTickRef = useRef<any>(null);
  const recordingStartedAtRef = useRef(0);
  const recordingEventsRef = useRef<TrailerEventPayload[]>([]);
  const recordingDetachInputRef = useRef<(() => void) | null>(null);

  const [trailerOpen, setTrailerOpen] = useState(false);
  const [trailerStyle, setTrailerStyle] = useState<TrailerStyle>("energetic");
  const [trailerTarget, setTrailerTarget] = useState<TrailerTarget>("tiktok");
  const [highlightMode, setHighlightMode] = useState<HighlightMode>("auto");
  const [musicMode, setMusicMode] = useState<MusicMode>("auto");
  const [customMusicUrl, setCustomMusicUrl] = useState("");
  const [musicUploadBusy, setMusicUploadBusy] = useState(false);
  const [directorMode, setDirectorMode] = useState(true);
  const [directorProvider, setDirectorProvider] = useState<AIDirectorProvider>("gemini");
  const [directorBusy, setDirectorBusy] = useState(false);
  const [directorNote, setDirectorNote] = useState<string | null>(null);
  const [autoGenerateAfterRecording, setAutoGenerateAfterRecording] = useState(false);
  const [trailerBusy, setTrailerBusy] = useState<"create" | "poll" | "publish" | null>(null);
  const [trailerJob, setTrailerJob] = useState<TrailerJob | null>(null);
  const [trailerResult, setTrailerResult] = useState<TrailerResult | null>(null);
  const [recordingState, setRecordingState] = useState<RecordingState>("idle");
  const [recordingError, setRecordingError] = useState<string | null>(null);
  const [recordingElapsedSec, setRecordingElapsedSec] = useState(0);
  const [recordingEventsCount, setRecordingEventsCount] = useState(0);
  const [recordedBlobUrl, setRecordedBlobUrl] = useState<string | null>(null);
  const [recordedSourceVideoUrl, setRecordedSourceVideoUrl] = useState<string | null>(null);
  const [trimStartSec, setTrimStartSec] = useState(0);
  const [trimEndSec, setTrimEndSec] = useState(0);

  const showToast = (kind: "ok" | "err" | "info", msg: string) => {
    const id = Date.now() + Math.floor(Math.random() * 1000);
    setToast({ id, kind, msg });
    window.setTimeout(() => {
      setToast((t) => (t?.id === id ? null : t));
    }, 2400);
  };

  useEffect(() => {
    const qp = typeof window !== "undefined" ? new URLSearchParams(window.location.search) : null;
    const tid = (qp?.get("tournamentId") || "").trim();
    setTournamentId(tid ? tid : null);
  }, []);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      if (!token) {
        if (!cancelled) setAuthUserId("");
        return;
      }
      try {
        const profile = await apiFetch<any>("/auth/profile", { method: "GET", token });
        const user = profile?.user || profile?.data?.user || profile?.data || profile;
        const uid = String(user?.id || user?._id || user?.sub || "").trim();
        if (!cancelled) setAuthUserId(uid);
      } catch {
        if (!cancelled) setAuthUserId("");
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [token]);

  useEffect(() => {
    if (!tournamentId || !authUserId.trim()) return;

    const onMsg = (ev: MessageEvent) => {
      try {
        if (typeof window !== "undefined" && ev.origin !== window.location.origin) return;
        const data: any = ev.data;
        if (!data || typeof data !== "object") return;

        const type = String(data.type || data.kind || "").trim().toLowerCase();
        const isScore = type === "gameforge_score" || type === "tournament_score" || type === "score";
        if (!isScore) return;

        const score = Math.max(0, Math.trunc(Number(data.score || 0)));
        const durationSec = Math.max(1, Math.trunc(Number(data.durationSec || data.duration || 1)));
        const runId = String(data.runId || data.run_id || "").trim();
        const deviceId = String(data.deviceId || data.device_id || "web" + "_" + id).trim();
        const clientTimeMs = Number.isFinite(Number(data.clientTimeMs)) ? Math.trunc(Number(data.clientTimeMs)) : Date.now();
        const signature = String(data.signature || "").trim();
        const telemetryHash = String(data.telemetryHash || "").trim();

        setTournamentLastScore(score);
        setTournamentLastDurationSec(durationSec);
        setTournamentSubmitErr(null);

        setTournamentSubmitBusy(true);
        apiFetch("/platform-labs/tournaments/submit-score", {
          method: "POST",
          token: token || undefined,
          body: {
            tournamentId,
            playerId: authUserId.trim(),
            score,
            durationSec,
            runId: runId || undefined,
            deviceId: deviceId || undefined,
            clientTimeMs,
            signature: signature || undefined,
            telemetryHash: telemetryHash || undefined,
          },
        })
          .then(() => {
            showToast("ok", `Score submitted: ${score}`);
          })
          .catch((e: any) => {
            const msg = e instanceof ApiError ? e.message : e?.message || "Score submit failed";
            setTournamentSubmitErr(msg);
            showToast("err", msg);
          })
          .finally(() => {
            setTournamentSubmitBusy(false);
          });
      } catch {
        // ignore
      }
    };

    window.addEventListener("message", onMsg);
    return () => window.removeEventListener("message", onMsg);
  }, [tournamentId, authUserId, token, id]);

  const stopTrailerPolling = () => {
    if (!trailerPollTimerRef.current) return;
    try {
      clearInterval(trailerPollTimerRef.current);
    } catch {}
    trailerPollTimerRef.current = null;
  };

  const stopRecordingTicker = () => {
    if (!recordingTickRef.current) return;
    try {
      clearInterval(recordingTickRef.current);
    } catch {}
    recordingTickRef.current = null;
  };

  const stopRecordingTracks = () => {
    try {
      recordingStreamRef.current?.getTracks().forEach((t) => t.stop());
    } catch {}
    recordingStreamRef.current = null;
  };

  const detachRecordingInputs = () => {
    if (!recordingDetachInputRef.current) return;
    try {
      recordingDetachInputRef.current();
    } catch {}
    recordingDetachInputRef.current = null;
  };

  const recordingNowSec = () => {
    if (!recordingStartedAtRef.current) return 0;
    return Math.max(0, (performance.now() - recordingStartedAtRef.current) / 1000);
  };

  const pushRecordingEvent = (type: string, scoreDelta = 0) => {
    const safeType = String(type || "action").trim().toLowerCase().slice(0, 32) || "action";
    const t = Number(recordingNowSec().toFixed(2));
    recordingEventsRef.current.push({ t, type: safeType, scoreDelta });
    if (recordingEventsRef.current.length > 240) {
      recordingEventsRef.current = recordingEventsRef.current.slice(-240);
    }
    setRecordingEventsCount(recordingEventsRef.current.length);
  };

  const attachRecordingInputs = () => {
    detachRecordingInputs();
    const lastByType = new Map<string, number>();

    const throttlePush = (type: string, scoreDelta = 0) => {
      const now = recordingNowSec();
      const prev = Number(lastByType.get(type) || 0);
      if (now - prev < 0.45) return;
      lastByType.set(type, now);
      pushRecordingEvent(type, scoreDelta);
    };

    const onKey = (ev: KeyboardEvent) => {
      if (mediaRecorderRef.current?.state !== "recording") return;
      const k = String(ev.key || "").toLowerCase();
      if (k === " " || k === "arrowup" || k === "w") return throttlePush("jump", 40);
      if (k === "f" || k === "x" || k === "j" || k === "k") return throttlePush("kill", 110);
      if (k === "c") return throttlePush("combo", 160);
      if (k === "shift" || k === "arrowright" || k === "d") return throttlePush("dash", 25);
      if (k === "arrowleft" || k === "a") return throttlePush("dodge", 20);
      throttlePush("action", 10);
    };

    const onPointer = (ev: PointerEvent) => {
      if (mediaRecorderRef.current?.state !== "recording") return;
      const isPrimary = ev.button === 0;
      throttlePush(isPrimary ? "kill" : "action", isPrimary ? 95 : 18);
    };

    window.addEventListener("keydown", onKey);
    window.addEventListener("pointerdown", onPointer);

    recordingDetachInputRef.current = () => {
      window.removeEventListener("keydown", onKey);
      window.removeEventListener("pointerdown", onPointer);
    };
  };

  const recordingLabel: Record<RecordingState, string> = {
    idle: "Idle",
    requesting: "Waiting Permission",
    recording: "Recording Live",
    uploading: "Processing Upload",
    ready: "Ready",
    failed: "Failed",
  };

  const startGameplayRecording = async () => {
    if (!token || !id) return;
    if (recordingState === "recording" || recordingState === "uploading") return;

    try {
      setRecordingError(null);
      setRecordingState("requesting");
      setRecordingElapsedSec(0);
      setRecordingEventsCount(0);
      recordingEventsRef.current = [];
      recordingStartedAtRef.current = 0;
      setRecordedSourceVideoUrl(null);
      detachRecordingInputs();
      if (recordedBlobUrl) {
        try {
          URL.revokeObjectURL(recordedBlobUrl);
        } catch {}
      }
      setRecordedBlobUrl(null);

      const stream = await navigator.mediaDevices.getDisplayMedia({
        video: {
          frameRate: { ideal: 60, max: 60 },
        },
        audio: true,
      });

      recordingStreamRef.current = stream;
      recordingChunksRef.current = [];

      const preferredMimeTypes = [
        "video/webm;codecs=vp9,opus",
        "video/webm;codecs=vp8,opus",
        "video/webm",
      ];
      const mimeType = preferredMimeTypes.find((m) => MediaRecorder.isTypeSupported(m));
      const rec = mimeType ? new MediaRecorder(stream, { mimeType }) : new MediaRecorder(stream);
      mediaRecorderRef.current = rec;

      rec.ondataavailable = (ev: BlobEvent) => {
        if (ev.data && ev.data.size > 0) recordingChunksRef.current.push(ev.data);
      };

      rec.onerror = (ev: any) => {
        const msg = ev?.error?.message || "Recording failed unexpectedly";
        setRecordingState("failed");
        setRecordingError(msg);
        showToast("err", msg);
      };

      rec.onstop = async () => {
        stopRecordingTicker();
        stopRecordingTracks();
        detachRecordingInputs();
        mediaRecorderRef.current = null;

        const blob = new Blob(recordingChunksRef.current, { type: rec.mimeType || "video/webm" });
        if (!blob.size) {
          setRecordingState("failed");
          setRecordingError("Recording is empty. Please try again.");
          return;
        }

        const localUrl = URL.createObjectURL(blob);
        setRecordedBlobUrl(localUrl);
    const approxDuration = Math.max(1, Math.floor(recordingNowSec()) || recordingElapsedSec);
    setRecordingElapsedSec(approxDuration);
        setTrimStartSec(0);
        setTrimEndSec(approxDuration);

        try {
          setRecordingState("uploading");
          const filename = `${id}-gameplay-${Date.now()}.webm`;
          const form = new FormData();
          form.append("file", new File([blob], filename, { type: blob.type || "video/webm" }));
          form.append("type", "video");
          form.append("name", filename);
          form.append("tags", "trailer,gameplay,recording");

          const uploaded = await apiFetchForm<any>("/assets/upload", {
            method: "POST",
            token,
            form,
          });

          const assetId = String(uploaded?.id || uploaded?._id || uploaded?.data?.id || uploaded?.data?._id || "").trim();
          if (!assetId) throw new Error("Upload completed but no asset id returned");

          let sourceUrl = "";
          try {
            const dl = await apiFetch<any>(`/assets/${encodeURIComponent(assetId)}/download-url`, {
              method: "GET",
              token,
            });
            sourceUrl = String(dl?.url || dl?.data?.url || "").trim();
          } catch {}

          if (!sourceUrl) {
            sourceUrl = String(
              uploaded?.publicUrl || uploaded?.data?.publicUrl || uploaded?.url || uploaded?.data?.url || "",
            ).trim();
          }

          sourceUrl = normalizeImageUrl(sourceUrl) || "";
          if (!sourceUrl) throw new Error("Could not resolve uploaded video URL");

          setRecordedSourceVideoUrl(sourceUrl);
          setRecordingState("ready");
          showToast("ok", "Gameplay recorded and uploaded");

          if (autoGenerateAfterRecording) {
            window.setTimeout(() => {
              showToast("info", "Auto mode: AI Director is generating your reel...");
              void handleGenerateTrailer();
            }, 250);
          }
        } catch (e: any) {
          setRecordingState("failed");
          setRecordingError(e instanceof ApiError ? e.message : (e?.message || "Upload failed"));
          showToast("err", e instanceof ApiError ? e.message : (e?.message || "Upload failed"));
        }
      };

      rec.start(500);
      recordingStartedAtRef.current = performance.now();
      pushRecordingEvent("run_start", 40);
      attachRecordingInputs();
      setRecordingState("recording");
      showToast("info", "Recording started. Play your game, then press Stop Recording.");
      recordingTickRef.current = window.setInterval(() => {
        setRecordingElapsedSec(Math.max(0, Math.floor(recordingNowSec())));
      }, 1000);

      const stopTrack = stream.getVideoTracks()[0];
      if (stopTrack) {
        stopTrack.onended = () => {
          if (mediaRecorderRef.current && mediaRecorderRef.current.state === "recording") {
            mediaRecorderRef.current.stop();
          }
        };
      }
    } catch (e: any) {
      stopRecordingTicker();
      stopRecordingTracks();
      detachRecordingInputs();
      setRecordingState("failed");
      const rawMsg = String(e?.message || "Screen capture permission denied");
      const msg = rawMsg.toLowerCase().includes("invalid state")
        ? "Recording session got interrupted. Keep the game tab open, then try Play + Record again."
        : rawMsg;
      setRecordingError(msg);
      showToast("err", msg);
    }
  };

  const stopGameplayRecording = () => {
    const rec = mediaRecorderRef.current;
    if (!rec || rec.state !== "recording") return;
    pushRecordingEvent("run_end", 65);
    setRecordingState("uploading");
    rec.stop();
  };

  const fetchTrailerState = async (jobId: string) => {
    if (!token) return;
    const jobRaw = await apiFetch<TrailerJob>(`/trailers/${encodeURIComponent(jobId)}`, {
      method: "GET",
      token,
    });
    const job = normalizeTrailerJob(jobRaw);
    setTrailerJob(job);
    const resolvedJobId = trailerJobId(job);

    if (job.status === "ready") {
      const result = await apiFetch<TrailerResult>(`/trailers/${encodeURIComponent(resolvedJobId || jobId)}/result`, {
        method: "GET",
        token,
      });
      setTrailerResult(result);
      stopTrailerPolling();
      setTrailerBusy(null);

      return;
    }

    if (job.status === "failed") {
      stopTrailerPolling();
      setTrailerBusy(null);
      showToast("err", job.error || "Trailer generation failed");
    }
  };

  const beginTrailerPolling = async (jobId: string) => {
    stopTrailerPolling();
    setTrailerBusy("poll");
    await fetchTrailerState(jobId);
    trailerPollTimerRef.current = window.setInterval(() => {
      void fetchTrailerState(jobId);
    }, 2500);
  };

  const handleUploadCustomMusic = async (file: File | null) => {
    if (!file || !token) return;
    const mime = String(file.type || "").toLowerCase();
    const ext = String(file.name || "").toLowerCase();
    const looksAudio = mime.startsWith("audio/") || /\.(mp3|wav|m4a|aac|ogg)$/i.test(ext);
    if (!looksAudio) {
      showToast("err", "Please select an audio file (mp3/wav/m4a/aac/ogg)");
      return;
    }

    try {
      setMusicUploadBusy(true);
      const safeName = `${id || "project"}-reel-music-${Date.now()}-${file.name}`;
      const form = new FormData();
      form.append("file", new File([file], safeName, { type: file.type || "audio/mpeg" }));
      form.append("type", "audio");
      form.append("name", safeName);
      form.append("tags", "trailer,music,reel");

      const uploaded = await apiFetchForm<any>("/assets/upload", {
        method: "POST",
        token,
        form,
      });

      const assetId = String(uploaded?.id || uploaded?._id || uploaded?.data?.id || uploaded?.data?._id || "").trim();
      if (!assetId) throw new Error("Upload completed but no asset id returned");

      let audioUrl = "";
      try {
        const dl = await apiFetch<any>(`/assets/${encodeURIComponent(assetId)}/download-url`, {
          method: "GET",
          token,
        });
        audioUrl = String(dl?.url || dl?.data?.url || "").trim();
      } catch {}

      if (!audioUrl) {
        audioUrl = String(
          uploaded?.publicUrl || uploaded?.data?.publicUrl || uploaded?.url || uploaded?.data?.url || "",
        ).trim();
      }
      audioUrl = normalizeImageUrl(audioUrl) || "";
      if (!audioUrl) throw new Error("Could not resolve uploaded audio URL");

      setMusicMode("custom");
      setCustomMusicUrl(audioUrl);
      showToast("ok", "Music uploaded and linked to trailer");
    } catch (e: any) {
      showToast("err", e instanceof ApiError ? e.message : (e?.message || "Music upload failed"));
    } finally {
      setMusicUploadBusy(false);
    }
  };

  const runAIDirectorPlanning = async (): Promise<AIDirectorPlan | null> => {
    if (!directorMode) return null;
    try {
      setDirectorBusy(true);
      setDirectorNote("AI Director is analyzing your run…");

      const endpoint = directorProvider === "ollama" ? "/ollama/chat" : "/ai/chat";
      const prompt = [
        "You are an AI Trailer Director for a gaming reel.",
        "Return ONLY strict JSON with this exact shape:",
  '{"style":"energetic|cinematic|funny","target":"tiktok|reels|short","highlightMode":"auto|trim","musicMode":"auto|custom","customMusicUrl":"https://... (optional)","musicCue":"short soundtrack cue","reelTitle":"short game-specific title","captionHook":"short viral hook"}',
        "Constraints:",
        "- Pick the most viral combo based on context and game genre/theme.",
        "- If no safe custom URL, set musicMode:auto.",
        "- captionHook max 90 chars and MUST mention game vibe (example: ninja/space/racing).",
        "- musicCue max 60 chars, genre-like (example: Ninja Trap • 128 BPM).",
        "- reelTitle max 50 chars and MUST be game-specific (example for ninja game: Shadow Blade Rush).",
      ].join("\n");

      const ai = await apiFetch<{ text?: string; modelUsed?: string }>(endpoint, {
        method: "POST",
        body: {
          message: prompt,
          context: {
            projectId: id,
            projectName: project?.name,
            trailerStyle,
            trailerTarget,
            recordingDurationSec: recordingElapsedSec,
            recordingEventsCount,
            recentEvents: recordingEventsRef.current.slice(-80),
            hasCustomRecording: Boolean(recordedSourceVideoUrl),
          },
        },
      });

      const parsed = parseJsonBlock(String(ai?.text || "")) as any;
      if (!parsed || typeof parsed !== "object") {
        setDirectorNote("AI response parsed in fallback mode");
        return null;
      }

      const nextStyle: TrailerStyle = ["energetic", "cinematic", "funny"].includes(String(parsed.style))
        ? (parsed.style as TrailerStyle)
        : trailerStyle;
      const nextTarget: TrailerTarget = ["tiktok", "reels", "short"].includes(String(parsed.target))
        ? (parsed.target as TrailerTarget)
        : trailerTarget;
      const nextHighlightMode: HighlightMode = ["auto", "trim"].includes(String(parsed.highlightMode))
        ? (parsed.highlightMode as HighlightMode)
        : highlightMode;
      const nextMusicMode: MusicMode = ["auto", "custom"].includes(String(parsed.musicMode))
        ? (parsed.musicMode as MusicMode)
        : musicMode;
      const rawMusicUrl = String(parsed.customMusicUrl || "").trim();
      const safeMusicUrl = /^https?:\/\//i.test(rawMusicUrl) ? rawMusicUrl : "";
    const nextMusicCue = String(parsed.musicCue || "").trim().slice(0, 60);
    const nextReelTitle = String(parsed.reelTitle || "").trim().slice(0, 50);
      const nextHook = String(parsed.captionHook || "").trim().slice(0, 90);

      setTrailerStyle(nextStyle);
      setTrailerTarget(nextTarget);
      setHighlightMode(nextHighlightMode);
      setMusicMode(nextMusicMode);
      if (nextMusicMode === "custom" && safeMusicUrl) setCustomMusicUrl(safeMusicUrl);
      setDirectorNote(
        `AI Director (${String(ai?.modelUsed || directorProvider)}) → ${nextStyle}/${nextTarget}${nextReelTitle ? ` • ${nextReelTitle}` : ""}${nextHook ? ` • ${nextHook}` : ""}${nextMusicCue ? ` • ${nextMusicCue}` : ""}`,
      );

      return {
        style: nextStyle,
        target: nextTarget,
        highlightMode: nextHighlightMode,
        musicMode: nextMusicMode,
        customMusicUrl: safeMusicUrl || undefined,
        musicCue: nextMusicCue || undefined,
        reelTitle: nextReelTitle || undefined,
        captionHook: nextHook || undefined,
      };
    } catch (e: any) {
      setDirectorNote("AI Director fallback: using your current settings");
      showToast("info", e instanceof ApiError ? `AI Director fallback (${e.message})` : "AI Director fallback");
      return null;
    } finally {
      setDirectorBusy(false);
    }
  };

  const handleGenerateTrailer = async () => {
    if (!token || !id) return;
    try {
      setTrailerBusy("create");
      setTrailerResult(null);
      const aiPlan = await runAIDirectorPlanning();
      const effectiveStyle = aiPlan?.style || trailerStyle;
      const effectiveTarget = aiPlan?.target || trailerTarget;
      const effectiveHighlightMode = aiPlan?.highlightMode || highlightMode;
      const effectiveMusicMode = aiPlan?.musicMode || musicMode;
      const effectiveMusicUrl = (aiPlan?.customMusicUrl || customMusicUrl).trim();
    const effectiveCaptionHook = String(aiPlan?.captionHook || "").trim().slice(0, 90);
    const effectiveMusicCue = String(aiPlan?.musicCue || "").trim().slice(0, 60);
    const effectiveReelTitle = String(aiPlan?.reelTitle || "").trim().slice(0, 50);

      const start = Math.max(0, Number(trimStartSec || 0));
      const end = Math.max(start, Number(trimEndSec || 0));

      const trimEvents: TrailerEventPayload[] = end > start
        ? [
            { t: Number(start.toFixed(2)), type: "trim_start", scoreDelta: 0 },
            { t: Number(end.toFixed(2)), type: "trim_end", scoreDelta: 0 },
          ]
        : [];

      const interactionEvents = effectiveHighlightMode === "auto"
        ? recordingEventsRef.current
            .filter((ev) => Number.isFinite(Number(ev.t)))
            .filter((ev) => ev.t >= start && (end <= start || ev.t <= end))
            .map((ev) => ({
              t: Number(ev.t.toFixed(2)),
              type: String(ev.type || "action").slice(0, 32),
              scoreDelta: Number(ev.scoreDelta || 0),
            }))
        : [];

      const events = [...trimEvents, ...interactionEvents]
        .sort((a, b) => a.t - b.t)
        .slice(0, 200);

      if (effectiveMusicMode === "custom" && effectiveMusicUrl && !/^https?:\/\//i.test(effectiveMusicUrl)) {
        setTrailerBusy(null);
        showToast("err", "Custom music URL must start with http:// or https://");
        return;
      }

      const created = await apiFetch<TrailerJob>(`/trailers`, {
        method: "POST",
        token,
        body: {
          projectId: id,
          sourceVideoUrl: recordedSourceVideoUrl || undefined,
          style: effectiveStyle,
          target: effectiveTarget,
          events: events.length ? events : undefined,
          musicUrl: effectiveMusicMode === "custom" && effectiveMusicUrl ? effectiveMusicUrl : undefined,
          captionHook: effectiveCaptionHook || undefined,
          musicCue: effectiveMusicCue || undefined,
          reelTitle: effectiveReelTitle || undefined,
        },
      });
      const createdJob = normalizeTrailerJob(created);
      const createdJobId = trailerJobId(createdJob);
      if (!createdJobId) {
        setTrailerBusy(null);
        showToast("err", "Trailer job created but no id returned");
        return;
      }
      setTrailerJob(createdJob);
      showToast("info", effectiveHighlightMode === "auto" ? "AI Trailer job created with gameplay highlights" : "AI Trailer job created");
      await beginTrailerPolling(createdJobId);
    } catch (e: any) {
      setTrailerBusy(null);
      showToast("err", e instanceof ApiError ? e.message : (e?.message || "Trailer generation failed"));
    }
  };

  const handlePublishTrailerFeed = async (jobIdOverride?: string) => {
    if (!token) return;
    const publishJobId = String(jobIdOverride || trailerJobId(trailerJob) || "").trim();
    if (!publishJobId) return;
    try {
      setTrailerBusy("publish");
      const res = await apiFetch<any>(`/trailers/${encodeURIComponent(publishJobId)}/publish-feed`, {
        method: "POST",
        token,
      });
      const nextFeedPostId = String(res?.feedPostId || trailerJob?.feedPostId || "").trim();
      if (nextFeedPostId) {
        setTrailerJob((prev) => (prev ? { ...prev, feedPostId: nextFeedPostId } : prev));
        setTrailerResult((prev) => (prev ? { ...prev, feedPostId: nextFeedPostId } : prev));
      }
      showToast("ok", res?.alreadyPublished ? "Already published to feed" : "Trailer published to feed ✨");
    } catch (e: any) {
      showToast("err", e instanceof ApiError ? e.message : (e?.message || "Publish failed"));
    } finally {
      setTrailerBusy(null);
    }
  };

  useEffect(() => {
    let cancelled = false;
    async function load() {
      if (!token || !id) return;
      setLoading(true);
      setError(null);
      try {
        const p = await apiFetch<any>(`/projects/${encodeURIComponent(id)}`, { method: "GET", token });
        const data = (p && typeof p === "object" && "data" in p) ? (p as any).data : p;
        if (!cancelled) {
          setProject(data);
          const cfg = (data?.aiUnityConfig && typeof data.aiUnityConfig === "object") ? data.aiUnityConfig : {};
          setDraft({
            name: (data?.name ?? "").toString(),
            speed: typeof cfg.speed === "number" ? cfg.speed : 7,
            timeScale: typeof cfg.timeScale === "number" ? cfg.timeScale : 1.0,
            difficulty: typeof cfg.difficulty === "number" ? cfg.difficulty : 0.5,
            gravityY: typeof cfg.gravityY === "number" ? cfg.gravityY : -9.8,
            jumpForce: typeof cfg.jumpForce === "number" ? cfg.jumpForce : 12,
            primaryColor: normHex(cfg.primaryColor, "#6366F1"),
            secondaryColor: normHex(cfg.secondaryColor, "#A855F7"),
            accentColor: normHex(cfg.accentColor, "#22D3EE"),
            playerColor: normHex(cfg.playerColor, "#F59E0B"),
          });
          setDirty(false);
        }
      } catch (e: any) {
        if (!cancelled) setError(e instanceof ApiError ? e.message : (e?.message || "Failed to load project"));
      } finally {
        if (!cancelled) setLoading(false);
      }
    }
    load();
    return () => {
      cancelled = true;
    };
  }, [token, id]);

   useEffect(() => {
     let cancelled = false;
     async function loadPreview() {
       if (!token || !id) return;
       try {
         const pr = await apiFetch<any>(`/projects/${encodeURIComponent(id)}/preview-url`, { method: "GET", token });
         const url = (pr as any)?.url || (pr as any)?.data?.url;
         if (!cancelled) setPreviewUrl(typeof url === "string" ? url : null);
       } catch {
         if (!cancelled) setPreviewUrl(null);
       }
     }
     loadPreview();
     return () => {
       cancelled = true;
     };
   }, [token, id, project?.status]);

   useEffect(() => {
     return () => {
       if (autoSaveTimerRef.current) {
         try {
           clearTimeout(autoSaveTimerRef.current);
         } catch {}
         autoSaveTimerRef.current = null;
       }
     };
   }, []);

   useEffect(() => {
     return () => {
       stopTrailerPolling();
       stopRecordingTicker();
       stopRecordingTracks();
       detachRecordingInputs();
       if (recordedBlobUrl) {
         try {
           URL.revokeObjectURL(recordedBlobUrl);
         } catch {}
       }
     };
   }, [recordedBlobUrl]);

   const saveDraft = async (opts?: { rebuild?: boolean; silent?: boolean }) => {
     if (!token || !id) return;
     setBusy(opts?.rebuild ? "save_rebuild" : "save");
     setError(null);
     try {
       const payload: any = {
         name: (draft?.name ?? "").toString().trim(),
         speed: clampNum(draft?.speed, 0, 20, 7),
         timeScale: clampNum(draft?.timeScale, 0.5, 2.0, 1.0),
         difficulty: clampNum(draft?.difficulty, 0, 1, 0.5),
         gravityY: clampNum(draft?.gravityY, -50, 0, -9.8),
         jumpForce: clampNum(draft?.jumpForce, 0, 50, 12),
         primaryColor: normHex(draft?.primaryColor, "#6366F1"),
         secondaryColor: normHex(draft?.secondaryColor, "#A855F7"),
         accentColor: normHex(draft?.accentColor, "#22D3EE"),
         playerColor: normHex(draft?.playerColor, "#F59E0B"),
       };

       const updated = await apiFetch<any>(`/projects/${encodeURIComponent(id)}`, { method: "PUT", token, body: payload });
       setProject(updated);
       setDraft((d: any) => ({ ...d, ...payload }));
       setDirty(false);

       if (!opts?.silent) showToast("ok", opts?.rebuild ? "Saved. Rebuilding…" : "Saved");

       if (opts?.rebuild) {
         await apiFetch(`/projects/${encodeURIComponent(id)}/rebuild`, { method: "POST", token });
         router.push(`/studio/builds/progress?projectId=${encodeURIComponent(id)}`);
       }
     } catch (e: any) {
       setError(e instanceof ApiError ? e.message : (e?.message || "Save failed"));
       showToast("err", e instanceof ApiError ? e.message : (e?.message || "Save failed"));
     } finally {
       setBusy(null);
     }
   };

  useEffect(() => {
    if (!autoApply) return;
    if (!dirty) return;
    if (!token || !id) return;
    if (busy !== null) return;
    if (autoSaveTimerRef.current) {
      try {
        clearTimeout(autoSaveTimerRef.current);
      } catch {}
    }
    autoSaveTimerRef.current = window.setTimeout(() => {
      autoSaveTimerRef.current = null;
      saveDraft({ silent: true }).catch(() => null);
      showToast("info", "Auto-applied");
    }, 700);
  }, [autoApply, dirty, draft, token, id, busy]);

  const title = project?.name?.trim() ? project.name : "Project";
  const status = (project?.status ?? "").toString().toLowerCase();

  return (
    <UserShell
      title={title}
      subtitle={project?.status ? `Build Status: ${project.status.toUpperCase()}` : "System Analysis"}
      right={
        <div className="flex gap-2">
          <button className="gf-btn rounded-xl px-4 py-2 text-xs font-bold text-zinc-400" onClick={() => router.push("/studio/projects")}>
            Exit
          </button>
          <button className="gf-glow rounded-xl bg-blue-500 px-4 py-2 text-xs font-black uppercase tracking-widest text-white transition-all hover:scale-105 active:scale-95 shadow-[0_10px_25px_rgba(37,99,235,0.3)]">
            Publish
          </button>
        </div>
      }
    >
      {toast ? (
        <motion.div
          key={toast.id}
          initial={{ opacity: 0, y: -10, scale: 0.98 }}
          animate={{ opacity: 1, y: 0, scale: 1 }}
          exit={{ opacity: 0, y: -10, scale: 0.98 }}
          transition={{ duration: 0.25 }}
          className={
            "mb-4 rounded-2xl border px-4 py-3 text-sm " +
            (toast.kind === "ok"
              ? "border-emerald-500/20 bg-emerald-500/10 text-emerald-100"
              : toast.kind === "err"
                ? "border-red-500/20 bg-red-500/10 text-red-200"
                : "border-blue-500/20 bg-blue-500/10 text-blue-100")
          }
        >
          {toast.msg}
        </motion.div>
      ) : null}

      {error ? <div className="mb-4 rounded-2xl border border-red-500/20 bg-red-500/10 px-4 py-3 text-sm text-red-200">{error}</div> : null}

      <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 pb-20">
        
        {/* Left Column: Sandbox & Actions */}
        <div className="lg:col-span-8 space-y-8">
          <div className="gf-panel-strong gf-stroke-gradient rounded-[40px] p-10">
            <div className="flex items-center justify-between mb-8">
              <div className="flex items-center gap-4">
                <div className="h-12 w-12 rounded-2xl bg-blue-500/20 flex items-center justify-center text-blue-400">
                  <Play size={24} fill="currentColor" />
                </div>
                <div>
                  <h3 className="text-2xl font-bold text-white tracking-tight">Interactive Sandbox</h3>
                  <p className="text-sm text-zinc-500 font-medium">Real-time parameter simulation</p>
                </div>
              </div>
              <div className="flex items-center gap-2">
                <button
                  className="gf-btn rounded-2xl p-3 text-zinc-400 hover:text-white transition-all"
                  onClick={async () => {
                    if (!token || !id) return;
                    try {
                      const pr = await apiFetch<any>(`/projects/${encodeURIComponent(id)}/preview-url`, { method: "GET", token });
                      const url = (pr as any)?.url || (pr as any)?.data?.url;
                      setPreviewUrl(typeof url === "string" ? url : null);
                      setIframeNonce((n) => n + 1);
                      showToast("info", "Preview refreshed");
                    } catch (e: any) {
                      showToast("err", e instanceof ApiError ? e.message : (e?.message || "Refresh failed"));
                    }
                  }}
                >
                  <RefreshCcw size={20} />
                </button>
                <button
                  className="gf-btn rounded-2xl px-4 py-3 text-[10px] font-black uppercase tracking-widest text-zinc-400 hover:text-white transition-all disabled:opacity-30"
                  disabled={!previewUrl}
                  onClick={() => {
                    if (previewUrl) window.open(previewUrl, "_blank");
                  }}
                >
                  Fullscreen
                </button>
              </div>
            </div>

            {tournamentId ? (
              <div className="mb-6 rounded-3xl border border-cyan-400/20 bg-cyan-500/10 px-5 py-4">
                <div className="flex flex-wrap items-center justify-between gap-3">
                  <div>
                    <div className="text-[10px] font-black uppercase tracking-[0.24em] text-cyan-100">Tournament Mode</div>
                    <div className="mt-1 text-xs text-zinc-200">
                      Listening for score events from the game and submitting automatically.
                    </div>
                  </div>
                  <div className="flex flex-wrap items-center gap-2">
                    <div className="rounded-full border border-white/10 bg-black/30 px-3 py-1.5 text-[11px] font-black text-zinc-200">
                      ID: <span className="text-cyan-200">{tournamentId}</span>
                    </div>
                    <div className="rounded-full border border-white/10 bg-black/30 px-3 py-1.5 text-[11px] font-black text-zinc-200">
                      Last: {tournamentLastScore == null ? "—" : tournamentLastScore.toLocaleString()}
                      {tournamentLastDurationSec != null ? ` (${tournamentLastDurationSec}s)` : ""}
                    </div>
                    <div className={`rounded-full border px-3 py-1.5 text-[11px] font-black ${tournamentSubmitBusy ? "border-amber-400/30 bg-amber-500/10 text-amber-100" : tournamentSubmitErr ? "border-rose-500/30 bg-rose-500/10 text-rose-200" : "border-emerald-500/30 bg-emerald-500/10 text-emerald-100"}`}>
                      {tournamentSubmitBusy ? "Submitting…" : tournamentSubmitErr ? "Submit failed" : "Ready"}
                    </div>
                  </div>
                </div>
                {tournamentSubmitErr ? (
                  <div className="mt-3 text-xs text-rose-200">{tournamentSubmitErr}</div>
                ) : null}
              </div>
            ) : null}

            <SandboxPreview
              key={previewUrl ? `${previewUrl}::${iframeNonce}` : `fallback::${iframeNonce}`}
              config={{ ...(project || {}), ...(draft || {}) }}
              previewUrl={previewUrl}
            />

            <div className="mt-8 space-y-4">
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <button
                  className="group relative flex flex-col justify-between overflow-hidden rounded-[28px] border border-blue-500/20 bg-blue-500/5 p-6 text-left transition-all hover:bg-blue-500/10 hover:scale-[1.02] active:scale-[0.98]"
                  onClick={() => router.push(`/studio/builds/progress?projectId=${encodeURIComponent(id)}`)}
                >
                  <div className="h-10 w-10 rounded-2xl bg-blue-500/20 flex items-center justify-center text-blue-400 mb-8">
                    <Activity size={20} />
                  </div>
                  <div>
                    <div className="text-sm font-bold text-white uppercase tracking-wider">Live Pipeline</div>
                    <div className="mt-1 text-xs text-zinc-500 font-medium">Monitor build process</div>
                  </div>
                </button>

                <button
                  className="group relative flex flex-col justify-between overflow-hidden rounded-[28px] border border-white/5 bg-white/[0.03] p-6 text-left transition-all hover:bg-white/[0.06] hover:scale-[1.02] active:scale-[0.98] disabled:opacity-30"
                  disabled={status !== "ready"}
                  onClick={async () => {
                    if (!token || !id) return;
                    const pr = await apiFetch<any>(`/projects/${encodeURIComponent(id)}/preview-url`, { method: "GET", token });
                    const url = (pr?.data || pr)?.url;
                    if (url) window.open(url, "_blank");
                  }}
                >
                  <div className="h-10 w-10 rounded-2xl bg-emerald-500/20 flex items-center justify-center text-emerald-400 mb-8">
                    <Globe size={20} />
                  </div>
                  <div>
                    <div className="text-sm font-bold text-white uppercase tracking-wider">WebGL Preview</div>
                    <div className="mt-1 text-xs text-zinc-500 font-medium">Run in full screen</div>
                  </div>
                </button>

                <button
                  className="group relative flex flex-col justify-between overflow-hidden rounded-[28px] border border-blue-500/25 bg-blue-600/5 p-6 text-left transition-all hover:bg-blue-600/10 hover:scale-[1.02] active:scale-[0.98]"
                  onClick={() => setTrailerOpen(true)}
                >
                  <div className="h-10 w-10 rounded-2xl bg-blue-600/20 flex items-center justify-center text-blue-300 mb-8">
                    <Clapperboard size={20} />
                  </div>
                  <div>
                    <div className="text-sm font-bold text-white uppercase tracking-wider">AI Trailer</div>
                    <div className="mt-1 text-xs text-zinc-500 font-medium">Generate vertical promo reel</div>
                  </div>
                </button>
              </div>

              {/* Native Downloads Row */}
              {status === "ready" && (project?.androidApkStorageKey || project?.macosZipStorageKey || project?.windowsZipStorageKey) && (
                <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
                  {project?.androidApkStorageKey && (
                    <button
                      onClick={async () => {
                        const res = await apiFetch<any>(`/projects/${id}/download-url?target=android`, { method: 'GET', token });
                        const url = res?.data?.url || res?.url;
                        if (url) window.open(url, '_blank');
                      }}
                      className="group flex items-center gap-4 rounded-2xl border border-white/5 bg-white/[0.02] p-4 text-left transition-all hover:bg-white/[0.05]"
                    >
                      <div className="h-10 w-10 shrink-0 rounded-xl bg-emerald-500/10 flex items-center justify-center text-emerald-400">
                        <Smartphone size={20} />
                      </div>
                      <div className="min-w-0">
                        <div className="text-[10px] font-black text-white uppercase tracking-widest leading-none mb-1">Android Build</div>
                        <div className="text-[9px] text-zinc-500 font-bold uppercase tracking-tighter flex items-center gap-1">
                          Download APK <Download size={10} />
                        </div>
                      </div>
                    </button>
                  )}

                  {project?.macosZipStorageKey && (
                    <button
                      onClick={async () => {
                        const res = await apiFetch<any>(`/projects/${id}/download-url?target=macos`, { method: 'GET', token });
                        const url = res?.data?.url || res?.url;
                        if (url) window.open(url, '_blank');
                      }}
                      className="group flex items-center gap-4 rounded-2xl border border-white/5 bg-white/[0.02] p-4 text-left transition-all hover:bg-white/[0.05]"
                    >
                      <div className="h-10 w-10 shrink-0 rounded-xl bg-blue-500/10 flex items-center justify-center text-blue-400">
                        <Monitor size={20} />
                      </div>
                      <div className="min-w-0">
                        <div className="text-[10px] font-black text-white uppercase tracking-widest leading-none mb-1">macOS Build</div>
                        <div className="text-[9px] text-zinc-500 font-bold uppercase tracking-tighter flex items-center gap-1">
                          Download ZIP <Download size={10} />
                        </div>
                      </div>
                    </button>
                  )}

                  {project?.windowsZipStorageKey && (
                    <button
                      onClick={async () => {
                        const res = await apiFetch<any>(`/projects/${id}/download-url?target=windows`, { method: 'GET', token });
                        const url = res?.data?.url || res?.url;
                        if (url) window.open(url, '_blank');
                      }}
                      className="group flex items-center gap-4 rounded-2xl border border-white/5 bg-white/[0.02] p-4 text-left transition-all hover:bg-white/[0.05]"
                    >
                      <div className="h-10 w-10 shrink-0 rounded-xl bg-blue-500/10 flex items-center justify-center text-blue-400">
                        <Monitor size={20} />
                      </div>
                      <div className="min-w-0">
                        <div className="text-[10px] font-black text-white uppercase tracking-widest leading-none mb-1">Windows Build</div>
                        <div className="text-[9px] text-zinc-500 font-bold uppercase tracking-tighter flex items-center gap-1">
                          Download EXE <Download size={10} />
                        </div>
                      </div>
                    </button>
                  )}
                </div>
              )}
            </div>
          </div>

          {/* Advanced Logic Visualizer */}
          <div className="gf-panel rounded-[40px] p-10">
            <div className="flex items-center gap-4 mb-10">
              <div className="h-10 w-10 rounded-xl bg-white/5 flex items-center justify-center text-blue-400 shadow-[0_0_15px_rgba(99,102,241,0.2)]">
                <Settings2 size={20} />
              </div>
              <div>
                <h3 className="text-xl font-bold text-white tracking-tight">Engine Intelligence</h3>
                <p className="text-xs text-zinc-500 font-medium uppercase tracking-widest mt-1">Neural Mapping Matrix</p>
              </div>
            </div>

            <LogicVisualizer project={project} />
          </div>

          {/* Live Multiplayer Previewer */}
          <div className="gf-panel rounded-[40px] p-10 relative overflow-hidden group">
            <div className="absolute inset-0 bg-gradient-to-br from-cyan-500/5 via-transparent to-transparent opacity-50" />
            <div className="relative z-10">
              <div className="flex items-center justify-between mb-10">
                <div className="flex items-center gap-4">
                  <div className="h-10 w-10 rounded-xl bg-cyan-500/10 flex items-center justify-center text-cyan-400">
                    <Globe size={20} />
                  </div>
                  <div>
                    <h3 className="text-xl font-bold text-white tracking-tight italic uppercase">Network Lobby</h3>
                    <p className="text-[10px] text-zinc-500 font-bold uppercase tracking-widest mt-1">Real-time Synchronization</p>
                  </div>
                </div>
                <div className="px-3 py-1.5 rounded-full bg-emerald-500/10 border border-emerald-500/20 flex items-center gap-2">
                  <div className="h-1.5 w-1.5 rounded-full bg-emerald-500 animate-pulse" />
                  <span className="text-[9px] font-black text-emerald-400 uppercase tracking-widest">Server Live</span>
                </div>
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-3 gap-6">
                {[
                  { name: "Player_Alpha", ping: "24ms", status: "Connected" },
                  { name: "Game_Master", ping: "12ms", status: "Syncing" },
                  { name: "Nova_01", ping: "45ms", status: "Idle" },
                ].map((p, i) => (
                  <div key={i} className="p-4 rounded-2xl bg-white/[0.02] border border-white/5 flex items-center justify-between group-hover:bg-white/[0.04] transition-all">
                    <div className="flex items-center gap-3">
                      <div className="h-8 w-8 rounded-lg bg-zinc-800 flex items-center justify-center text-[10px] font-black text-zinc-500">
                        {p.name[0]}
                      </div>
                      <div className="text-[10px] font-bold text-white uppercase tracking-tight">{p.name}</div>
                    </div>
                    <div className="text-right">
                      <div className="text-[9px] font-mono text-cyan-400">{p.ping}</div>
                    </div>
                  </div>
                ))}
              </div>

              <div className="mt-8 pt-8 border-t border-white/5 flex items-center justify-between">
                <div className="flex gap-4">
                  <div className="text-[9px] font-black text-zinc-600 uppercase tracking-widest">Protocol: <span className="text-white">UDP_FORGE</span></div>
                  <div className="text-[9px] font-black text-zinc-600 uppercase tracking-widest">Encryption: <span className="text-white">AES-256</span></div>
                </div>
                <button className="text-[9px] font-black text-blue-400 uppercase tracking-[0.2em] hover:text-white transition-colors">
                  Open Debug Console
                </button>
              </div>
            </div>
          </div>
        </div>

        {/* Right Column: Identity & Build */}
        <div className="lg:col-span-4 space-y-8">
          <div className="gf-panel-strong gf-stroke-gradient rounded-[40px] p-8 space-y-8 shadow-2xl">
            <div className="aspect-[16/10] rounded-[24px] overflow-hidden border border-white/5 relative group bg-black/40">
              <img 
                src={normalizeImageUrl(project?.previewImageUrl || project?.thumbnailUrl)} 
                alt="" 
                className="w-full h-full object-cover grayscale opacity-30 group-hover:grayscale-0 group-hover:opacity-100 transition-all duration-700"
              />
              <div className="absolute inset-0 bg-gradient-to-t from-black/80 via-transparent to-transparent opacity-60" />
              <div className="absolute bottom-4 left-4">
                <div className="text-[9px] font-black text-blue-400 uppercase tracking-[0.2em] bg-blue-500/10 px-3 py-1 rounded-full border border-blue-500/20 mb-2 inline-block">
                  Visual Identity
                </div>
                <div className="text-white font-bold tracking-tight">{title}</div>
              </div>
            </div>

            <div className="space-y-4 pt-4 border-t border-white/5">
              <div className="flex justify-between items-center text-[10px] font-black tracking-widest leading-none">
                <span className="text-zinc-600 uppercase">Platform</span>
                <span className="text-white uppercase">{(project?.buildTarget || "webgl")}</span>
              </div>
              <div className="flex justify-between items-center text-[10px] font-black tracking-widest leading-none">
                <span className="text-zinc-600 uppercase">Engine</span>
                <span className="text-white uppercase">Neural Weaver v4</span>
              </div>
              <div className="flex justify-between items-center text-[10px] font-black tracking-widest leading-none">
                <span className="text-zinc-600 uppercase">Status</span>
                <span className={`font-bold ${status === "ready" ? "text-emerald-400" : "text-amber-400"}`}>
                  {status.toUpperCase()}
                </span>
              </div>
            </div>

            <div className="space-y-3 pt-4">
              <motion.div
                initial={{ opacity: 0, y: 12 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ duration: 0.5 }}
                className="rounded-[24px] border border-white/5 bg-white/[0.02] p-5 space-y-4"
              >
                <div className="flex items-center justify-between">
                  <div>
                    <div className="text-[10px] font-black uppercase tracking-widest text-zinc-400">Live Config</div>
                    <div className="mt-1 text-sm font-semibold text-white">Sandbox Controls</div>
                  </div>
                  <div className={`text-[10px] font-black uppercase tracking-widest ${dirty ? "text-amber-300" : "text-emerald-400"}`}>
                    {dirty ? "UNSAVED" : "SYNCED"}
                  </div>
                </div>

                <button
                  onClick={() => {
                    setAutoApply((v) => !v);
                    showToast("info", !autoApply ? "Auto-Apply ON" : "Auto-Apply OFF");
                  }}
                  className={
                    "w-full rounded-xl border px-3 py-2 text-[10px] font-black uppercase tracking-widest transition-all " +
                    (autoApply
                      ? "border-emerald-500/20 bg-emerald-500/10 text-emerald-200 hover:bg-emerald-500/15"
                      : "border-white/10 bg-black/30 text-zinc-300 hover:bg-white/[0.06]")
                  }
                >
                  Auto-Apply: {autoApply ? "ON" : "OFF"}
                </button>

                <div className="space-y-2">
                  <div className="text-[10px] font-black uppercase tracking-widest text-zinc-500">Name</div>
                  <input
                    value={(draft?.name ?? "").toString()}
                    onChange={(e) => {
                      const v = e.target.value;
                      setDraft((d: any) => ({ ...d, name: v }));
                      setDirty(true);
                    }}
                    className="w-full rounded-xl border border-white/10 bg-black/30 px-3 py-2 text-sm text-white outline-none focus:border-blue-500/40"
                    placeholder="Project name"
                  />
                </div>

                <div className="grid grid-cols-1 gap-4">
                  <div className="space-y-2">
                    <div className="flex items-center justify-between">
                      <div className="text-[10px] font-black uppercase tracking-widest text-zinc-500">Speed</div>
                      <div className="text-[10px] font-mono text-zinc-400">{clampNum(draft?.speed, 0, 20, 7).toFixed(1)}</div>
                    </div>
                    <input
                      type="range"
                      min={0}
                      max={20}
                      step={0.1}
                      value={clampNum(draft?.speed, 0, 20, 7)}
                      onChange={(e) => {
                        const v = Number(e.target.value);
                        setDraft((d: any) => ({ ...d, speed: v }));
                        setDirty(true);
                      }}
                      className="w-full"
                    />
                  </div>

                  <div className="space-y-2">
                    <div className="flex items-center justify-between">
                      <div className="text-[10px] font-black uppercase tracking-widest text-zinc-500">Time Scale</div>
                      <div className="text-[10px] font-mono text-zinc-400">{clampNum(draft?.timeScale, 0.5, 2.0, 1.0).toFixed(2)}</div>
                    </div>
                    <input
                      type="range"
                      min={0.5}
                      max={2}
                      step={0.01}
                      value={clampNum(draft?.timeScale, 0.5, 2.0, 1.0)}
                      onChange={(e) => {
                        const v = Number(e.target.value);
                        setDraft((d: any) => ({ ...d, timeScale: v }));
                        setDirty(true);
                      }}
                      className="w-full"
                    />
                  </div>

                  <div className="space-y-2">
                    <div className="flex items-center justify-between">
                      <div className="text-[10px] font-black uppercase tracking-widest text-zinc-500">Difficulty</div>
                      <div className="text-[10px] font-mono text-zinc-400">{clampNum(draft?.difficulty, 0, 1, 0.5).toFixed(2)}</div>
                    </div>
                    <input
                      type="range"
                      min={0}
                      max={1}
                      step={0.01}
                      value={clampNum(draft?.difficulty, 0, 1, 0.5)}
                      onChange={(e) => {
                        const v = Number(e.target.value);
                        setDraft((d: any) => ({ ...d, difficulty: v }));
                        setDirty(true);
                      }}
                      className="w-full"
                    />
                  </div>

                  <div className="grid grid-cols-2 gap-4">
                    <div className="space-y-2">
                      <div className="flex items-center justify-between">
                        <div className="text-[10px] font-black uppercase tracking-widest text-zinc-500">Gravity Y</div>
                        <div className="text-[10px] font-mono text-zinc-400">{clampNum(draft?.gravityY, -50, 0, -9.8).toFixed(1)}</div>
                      </div>
                      <input
                        type="number"
                        value={clampNum(draft?.gravityY, -50, 0, -9.8)}
                        onChange={(e) => {
                          const v = Number(e.target.value);
                          setDraft((d: any) => ({ ...d, gravityY: v }));
                          setDirty(true);
                        }}
                        className="w-full rounded-xl border border-white/10 bg-black/30 px-3 py-2 text-sm text-white outline-none focus:border-blue-500/40"
                      />
                    </div>
                    <div className="space-y-2">
                      <div className="flex items-center justify-between">
                        <div className="text-[10px] font-black uppercase tracking-widest text-zinc-500">Jump Force</div>
                        <div className="text-[10px] font-mono text-zinc-400">{clampNum(draft?.jumpForce, 0, 50, 12).toFixed(1)}</div>
                      </div>
                      <input
                        type="number"
                        value={clampNum(draft?.jumpForce, 0, 50, 12)}
                        onChange={(e) => {
                          const v = Number(e.target.value);
                          setDraft((d: any) => ({ ...d, jumpForce: v }));
                          setDirty(true);
                        }}
                        className="w-full rounded-xl border border-white/10 bg-black/30 px-3 py-2 text-sm text-white outline-none focus:border-blue-500/40"
                      />
                    </div>
                  </div>

                  <div className="grid grid-cols-2 gap-4">
                    {[
                      { k: "primaryColor", label: "Primary" },
                      { k: "secondaryColor", label: "Secondary" },
                      { k: "accentColor", label: "Accent" },
                      { k: "playerColor", label: "Player" },
                    ].map((c) => (
                      <div key={c.k} className="space-y-2">
                        <div className="text-[10px] font-black uppercase tracking-widest text-zinc-500">{c.label}</div>
                        <div className="flex items-center gap-2">
                          <input
                            type="color"
                            value={normHex((draft as any)?.[c.k], "#6366F1")}
                            onChange={(e) => {
                              const v = e.target.value;
                              setDraft((d: any) => ({ ...d, [c.k]: v }));
                              setDirty(true);
                            }}
                            className="h-9 w-10 rounded-lg border border-white/10 bg-black/30"
                          />
                          <input
                            value={normHex((draft as any)?.[c.k], "#6366F1")}
                            onChange={(e) => {
                              const v = e.target.value;
                              setDraft((d: any) => ({ ...d, [c.k]: v }));
                              setDirty(true);
                            }}
                            className="w-full rounded-xl border border-white/10 bg-black/30 px-3 py-2 text-xs font-mono text-white outline-none focus:border-blue-500/40"
                          />
                        </div>
                      </div>
                    ))}
                  </div>
                </div>

                <div className="grid grid-cols-1 gap-3">
                  <button
                    onClick={() => saveDraft()}
                    disabled={busy !== null || !dirty}
                    className="w-full rounded-[18px] bg-white text-black py-4 font-black uppercase tracking-widest shadow-xl hover:scale-[1.02] active:scale-95 transition-all disabled:opacity-30"
                  >
                    {busy === "save" ? "Saving…" : dirty ? "Save" : "Saved"}
                  </button>
                  <button
                    onClick={() => saveDraft({ rebuild: true })}
                    disabled={busy !== null}
                    className="w-full gf-glow rounded-[18px] bg-blue-500 py-4 text-[10px] font-black uppercase tracking-widest text-white transition-all hover:scale-[1.03] active:scale-95 shadow-[0_10px_25px_rgba(37,99,235,0.3)] disabled:opacity-30"
                  >
                    {busy === "save_rebuild" ? "Saving & Rebuilding…" : "Save & Rebuild"}
                  </button>
                </div>
              </motion.div>

              <button 
                onClick={async () => {
                  setBusy("rebuild");
                  await apiFetch(`/projects/${id}/rebuild`, { method: "POST", token });
                  router.push(`/studio/builds/progress?projectId=${id}`);
                }}
                disabled={busy !== null}
                className="w-full rounded-[24px] bg-white text-black py-5 font-black uppercase tracking-widest shadow-xl hover:scale-[1.03] active:scale-95 transition-all flex items-center justify-center gap-3 disabled:opacity-30"
              >
                {busy === "rebuild" ? (
                  <div className="h-4 w-4 border-2 border-black/30 border-t-black animate-spin rounded-full" />
                ) : (
                  <>Re-Bake Engine <ZapIcon size={20} fill="currentColor" /></>
                )}
              </button>
              <button 
                className="w-full gf-btn rounded-[24px] py-4 text-[10px] font-black uppercase tracking-widest text-zinc-500 hover:text-white transition-colors"
                onClick={async () => {
                  const dl = await apiFetch<any>(`/projects/${encodeURIComponent(id)}/download-url`, { method: "GET", token });
                  const url = (dl?.data || dl)?.url;
                  if (url) window.open(url, "_blank");
                }}
                disabled={status !== "ready"}
              >
                Download Package
              </button>
            </div>
          </div>
        </div>

      </div>

      {trailerOpen && (
        <div className="fixed inset-0 z-[90] bg-black/70 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="w-full max-w-2xl rounded-3xl border border-white/10 bg-[#0b0d17] shadow-2xl overflow-hidden">
            <div className="px-6 py-4 border-b border-white/10 flex items-center justify-between">
              <div>
                <div className="text-xs text-sky-300 font-black uppercase tracking-widest">AI Trailer Forge</div>
                <h3 className="text-lg font-bold text-white">Generate Reel from Project</h3>
              </div>
              <button
                onClick={() => setTrailerOpen(false)}
                className="h-9 w-9 rounded-xl border border-white/10 bg-white/5 text-zinc-300 hover:text-white"
              >
                <X size={16} className="mx-auto" />
              </button>
            </div>

            <div className="p-6 space-y-5">
              <div className="rounded-2xl border border-white/10 bg-white/[0.02] p-4 space-y-3">
                <div className="flex items-center justify-between">
                  <div>
                    <div className="text-[11px] font-black uppercase tracking-widest text-zinc-500">Gameplay Capture</div>
                    <div className="text-xs text-zinc-400 mt-1">Play your game, stop recording, then generate trailer from that recording.</div>
                  </div>
                  <div className={`text-[10px] font-black uppercase tracking-widest ${recordingState === "ready" ? "text-emerald-300" : recordingState === "failed" ? "text-red-300" : recordingState === "recording" ? "text-sky-300" : "text-zinc-400"}`}>
                    {recordingLabel[recordingState]}
                  </div>
                </div>

                <div className="rounded-xl border border-red-500/20 bg-red-500/5 px-3 py-2 flex flex-wrap items-center justify-between gap-2">
                  <div className="flex items-center gap-2 text-xs text-red-100">
                    <span className={`h-2 w-2 rounded-full ${recordingState === "recording" ? "bg-red-500 animate-pulse" : "bg-zinc-600"}`} />
                    <span className="font-black uppercase tracking-widest">REC {recordingState === "recording" ? "Live" : "Standby"}</span>
                  </div>
                  <div className="text-xs text-zinc-300 font-mono">{formatDuration(recordingElapsedSec)}</div>
                </div>

                <div className="flex flex-wrap items-center gap-2">
                  <button
                    onClick={startGameplayRecording}
                    disabled={recordingState === "requesting" || recordingState === "recording" || recordingState === "uploading"}
                    className="rounded-xl border border-blue-500/30 bg-blue-600/10 px-3 py-2 text-xs font-black uppercase tracking-wider text-sky-200 disabled:opacity-40"
                  >
                    Play + Record
                  </button>
                  <button
                    onClick={stopGameplayRecording}
                    disabled={recordingState !== "recording"}
                    className="rounded-xl border border-red-500/30 bg-red-500/10 px-3 py-2 text-xs font-black uppercase tracking-wider text-red-200 disabled:opacity-40"
                  >
                    Stop Recording
                  </button>
                  <button
                    onClick={() => {
                      if (previewUrl) window.open(previewUrl, "_blank", "noopener,noreferrer");
                    }}
                    disabled={!previewUrl}
                    className="rounded-xl border border-blue-500/30 bg-blue-500/10 px-3 py-2 text-xs font-black uppercase tracking-wider text-blue-200 disabled:opacity-40"
                  >
                    Open Game Tab
                  </button>
                  {recordingState === "recording" ? (
                    <span className="text-xs text-zinc-400">REC • {recordingElapsedSec}s • {recordingEventsCount} hot events</span>
                  ) : null}
                </div>

                {recordingError ? (
                  <div className="text-xs text-red-300 border border-red-500/20 bg-red-500/10 rounded-xl px-3 py-2">{recordingError}</div>
                ) : null}

                {recordedSourceVideoUrl ? (
                  <div className="text-[11px] text-emerald-300">Recorded gameplay uploaded and ready for AI trailer.</div>
                ) : (
                  <div className="text-[11px] text-zinc-500">No custom recording yet. Generate will fallback to project preview video.</div>
                )}
              </div>

              <div className="rounded-2xl border border-blue-500/20 bg-blue-500/5 p-4 space-y-3">
                <div className="text-[11px] font-black uppercase tracking-widest text-blue-300">AI Reel Boost</div>
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                  <label className="space-y-1">
                    <div className="text-[10px] uppercase tracking-widest text-zinc-500">AI Director</div>
                    <select
                      value={directorMode ? "on" : "off"}
                      onChange={(e) => setDirectorMode(e.target.value === "on")}
                      className="w-full rounded-xl border border-white/10 bg-black/30 px-3 py-2 text-sm text-white outline-none"
                    >
                      <option value="on">Autopilot ON (Best settings)</option>
                      <option value="off">Manual</option>
                    </select>
                  </label>

                  <label className="space-y-1">
                    <div className="text-[10px] uppercase tracking-widest text-zinc-500">Model Provider</div>
                    <select
                      value={directorProvider}
                      onChange={(e) => setDirectorProvider(e.target.value as AIDirectorProvider)}
                      disabled={!directorMode}
                      className="w-full rounded-xl border border-white/10 bg-black/30 px-3 py-2 text-sm text-white outline-none disabled:opacity-40"
                    >
                      <option value="gemini">Gemini (Cloud)</option>
                      <option value="ollama">Ollama (Local)</option>
                    </select>
                  </label>
                </div>

                <label className="flex items-center gap-2 text-xs text-zinc-300">
                  <input
                    type="checkbox"
                    checked={autoGenerateAfterRecording}
                    onChange={(e) => setAutoGenerateAfterRecording(e.target.checked)}
                    className="h-4 w-4 rounded border-white/20 bg-black/30"
                  />
                  Auto generate reel right after recording upload
                </label>

                {directorNote ? (
                  <div className="text-[11px] text-blue-200 border border-blue-500/20 bg-blue-500/10 rounded-xl px-3 py-2">
                    {directorBusy ? "Analyzing... " : ""}{directorNote}
                  </div>
                ) : null}

                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                  <label className="space-y-1">
                    <div className="text-[10px] uppercase tracking-widest text-zinc-500">Highlights</div>
                    <select
                      value={highlightMode}
                      onChange={(e) => setHighlightMode(e.target.value as HighlightMode)}
                      className="w-full rounded-xl border border-white/10 bg-black/30 px-3 py-2 text-sm text-white outline-none"
                    >
                      <option value="auto">Auto Best Moments</option>
                      <option value="trim">Trim Window Only</option>
                    </select>
                  </label>

                  <label className="space-y-1">
                    <div className="text-[10px] uppercase tracking-widest text-zinc-500">Music</div>
                    <select
                      value={musicMode}
                      onChange={(e) => setMusicMode(e.target.value as MusicMode)}
                      className="w-full rounded-xl border border-white/10 bg-black/30 px-3 py-2 text-sm text-white outline-none"
                    >
                      <option value="auto">Auto by Style</option>
                      <option value="custom">Custom Upload / URL</option>
                    </select>
                  </label>
                </div>

                {musicMode === "custom" ? (
                  <div className="space-y-2">
                    <div className="grid grid-cols-1 sm:grid-cols-[1fr_auto] gap-2 items-end">
                      <label className="space-y-1 block">
                        <div className="text-[10px] uppercase tracking-widest text-zinc-500">Custom Music URL (optional)</div>
                        <input
                          type="url"
                          value={customMusicUrl}
                          onChange={(e) => setCustomMusicUrl(e.target.value)}
                          placeholder="https://.../music-track.mp3"
                          className="w-full rounded-xl border border-white/10 bg-black/30 px-3 py-2 text-sm text-white outline-none"
                        />
                      </label>
                      <label className="rounded-xl border border-white/10 bg-white/5 px-3 py-2 text-xs font-black uppercase tracking-wider text-zinc-200 cursor-pointer text-center">
                        {musicUploadBusy ? "Uploading..." : "Upload Music"}
                        <input
                          type="file"
                          accept="audio/*,.mp3,.wav,.m4a,.aac,.ogg"
                          className="hidden"
                          disabled={musicUploadBusy}
                          onChange={(e) => {
                            const f = e.target.files?.[0] || null;
                            void handleUploadCustomMusic(f);
                            e.currentTarget.value = "";
                          }}
                        />
                      </label>
                    </div>
                    <div className="text-[11px] text-zinc-500">If empty, backend auto-selects soundtrack based on style.</div>
                  </div>
                ) : null}

                <div className="text-[11px] text-zinc-500">Manual publish mode: reel stays private until you click Publish Feed.</div>
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <label className="space-y-2">
                  <div className="text-[11px] font-black uppercase tracking-widest text-zinc-500">Style</div>
                  <select
                    value={trailerStyle}
                    onChange={(e) => setTrailerStyle(e.target.value as TrailerStyle)}
                    className="w-full rounded-xl border border-white/10 bg-black/30 px-3 py-2 text-sm text-white outline-none"
                  >
                    <option value="energetic">Energetic</option>
                    <option value="cinematic">Cinematic</option>
                    <option value="funny">Funny</option>
                  </select>
                </label>

                <label className="space-y-2">
                  <div className="text-[11px] font-black uppercase tracking-widest text-zinc-500">Target</div>
                  <select
                    value={trailerTarget}
                    onChange={(e) => setTrailerTarget(e.target.value as TrailerTarget)}
                    className="w-full rounded-xl border border-white/10 bg-black/30 px-3 py-2 text-sm text-white outline-none"
                  >
                    <option value="tiktok">TikTok</option>
                    <option value="reels">Reels</option>
                    <option value="short">YouTube Shorts</option>
                  </select>
                </label>
              </div>

              {recordedBlobUrl ? (
                <div className="space-y-3 rounded-2xl border border-white/10 bg-white/[0.02] p-4">
                  <div className="text-[11px] font-black uppercase tracking-widest text-zinc-500">Trim Focus Window</div>
                  <video src={recordedBlobUrl} controls className="w-full rounded-xl border border-white/10 bg-black" />
                  <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                    <label className="space-y-1">
                      <div className="text-[10px] uppercase tracking-widest text-zinc-500">Start</div>
                      <input
                        type="range"
                        min={0}
                        max={Math.max(1, Math.floor(trimEndSec || recordingElapsedSec || 1))}
                        step={1}
                        value={Math.min(trimStartSec, Math.max(0, trimEndSec - 1))}
                        onChange={(e) => {
                          const v = Number(e.target.value);
                          setTrimStartSec(v);
                          if (v >= trimEndSec) setTrimEndSec(v + 1);
                        }}
                        className="w-full"
                      />
                      <div className="text-xs text-zinc-400">{Math.floor(trimStartSec)}s</div>
                    </label>
                    <label className="space-y-1">
                      <div className="text-[10px] uppercase tracking-widest text-zinc-500">End</div>
                      <input
                        type="range"
                        min={Math.floor(trimStartSec + 1)}
                        max={Math.max(Math.floor(trimStartSec + 1), Math.floor(recordingElapsedSec || trimEndSec || 1))}
                        step={1}
                        value={Math.max(trimStartSec + 1, trimEndSec)}
                        onChange={(e) => setTrimEndSec(Number(e.target.value))}
                        className="w-full"
                      />
                      <div className="text-xs text-zinc-400">{Math.floor(trimEndSec)}s</div>
                    </label>
                  </div>
                </div>
              ) : null}

              <div className="rounded-2xl border border-white/10 bg-white/[0.02] px-4 py-3">
                <div className="flex items-center justify-between text-xs">
                  <span className="text-zinc-400">Status</span>
                  <span className={`font-black uppercase tracking-widest ${trailerJob?.status === "ready" ? "text-emerald-300" : trailerJob?.status === "failed" ? "text-red-300" : "text-blue-300"}`}>
                    {trailerJob?.status || "idle"}
                  </span>
                </div>
                <div className="mt-2 text-xs text-zinc-500">
                  {trailerJob ? `${trailerJob.stage || "queued"} • ${Math.max(0, Math.min(100, Number(trailerJob.progress || 0)))}%` : "Configure style/target then generate"}
                </div>
                {trailerJob ? (
                  <div className="mt-1 text-[11px] text-zinc-500">
                    elapsed {formatDuration(trailerJob.elapsedSec || 0)}
                    {typeof trailerJob.etaSec === "number" && trailerJob.status !== "ready" && trailerJob.status !== "failed" ? ` • ETA ${formatDuration(trailerJob.etaSec)}` : ""}
                  </div>
                ) : null}
              </div>

              {trailerResult?.videoUrl ? (
                <div className="space-y-3">
                  {trailerResult.reelTitle ? (
                    <div className="text-sm font-black text-white rounded-xl border border-blue-500/30 bg-blue-500/10 px-3 py-2">
                      AI Reel Title: {trailerResult.reelTitle}
                    </div>
                  ) : null}
                  <video
                    src={trailerResult.videoUrl}
                    controls
                    className="w-full rounded-2xl border border-white/10 bg-black"
                    poster={trailerResult.thumbnailUrl || undefined}
                  />
                  <div className="flex flex-wrap items-center gap-2 text-xs text-zinc-400">
                    <span className="px-2 py-1 rounded-lg border border-white/10 bg-white/5 uppercase tracking-widest">{trailerResult.style || trailerStyle}</span>
                    <span className="px-2 py-1 rounded-lg border border-white/10 bg-white/5 uppercase tracking-widest">{trailerResult.target || trailerTarget}</span>
                    {typeof trailerResult.durationSec === "number" ? (
                      <span className="px-2 py-1 rounded-lg border border-white/10 bg-white/5">{trailerResult.durationSec}s</span>
                    ) : null}
                  </div>

                  {trailerResult.overlayText ? (
                    <div className="text-xs text-sky-200 rounded-xl border border-blue-500/30 bg-blue-600/8 px-3 py-2">
                      Overlay hook: {trailerResult.overlayText}
                    </div>
                  ) : null}

                  {Array.isArray(trailerResult.highlightsSec) && trailerResult.highlightsSec.length ? (
                    <div className="flex flex-wrap items-center gap-2 text-[11px] text-amber-200">
                      <span className="uppercase tracking-widest text-zinc-500">Highlights:</span>
                      {trailerResult.highlightsSec.map((t, idx) => (
                        <span key={`${t}-${idx}`} className="px-2 py-1 rounded-lg border border-amber-500/30 bg-amber-500/10">
                          {t}s
                        </span>
                      ))}
                    </div>
                  ) : null}

                  {Array.isArray(trailerResult.captions) && trailerResult.captions.length ? (
                    <div className="space-y-1 rounded-xl border border-white/10 bg-white/[0.02] p-3">
                      <div className="text-[10px] uppercase tracking-widest text-zinc-500 font-black">AI Captions</div>
                      {trailerResult.captions.map((line, idx) => (
                        <div key={`${line}-${idx}`} className="text-xs text-zinc-300">• {line}</div>
                      ))}
                    </div>
                  ) : null}
                </div>
              ) : null}
            </div>

            <div className="px-6 py-4 border-t border-white/10 flex flex-wrap items-center gap-2 justify-end">
              <button
                onClick={() => {
                  const jid = trailerJobId(trailerJob);
                  if (jid) {
                    void fetchTrailerState(jid);
                  }
                }}
                disabled={!trailerJobId(trailerJob) || trailerBusy === "create" || trailerBusy === "poll"}
                className="rounded-xl border border-white/10 bg-white/5 px-3 py-2 text-xs font-black uppercase tracking-wider text-zinc-300 disabled:opacity-40"
              >
                Check Status
              </button>
              <button
                onClick={() => {
                  void handlePublishTrailerFeed();
                }}
                disabled={!trailerJobId(trailerJob) || trailerJob?.status !== "ready" || trailerBusy === "publish"}
                className="rounded-xl border border-emerald-500/30 bg-emerald-500/15 px-3 py-2 text-xs font-black uppercase tracking-wider text-emerald-200 disabled:opacity-40"
              >
                {trailerBusy === "publish" ? "Publishing…" : trailerJob?.feedPostId ? "Published" : "Publish Feed"}
              </button>
              <button
                onClick={() => {
                  if (trailerResult?.videoUrl) window.open(trailerResult.videoUrl, "_blank");
                }}
                disabled={!trailerResult?.videoUrl}
                className="rounded-xl border border-blue-500/30 bg-blue-500/15 px-3 py-2 text-xs font-black uppercase tracking-wider text-blue-200 disabled:opacity-40 flex items-center gap-1"
              >
                Open Video <ExternalLink size={13} />
              </button>
              <button
                onClick={handleGenerateTrailer}
                disabled={directorBusy || trailerBusy === "create" || trailerBusy === "poll" || recordingState === "requesting" || recordingState === "recording" || recordingState === "uploading"}
                className="rounded-xl bg-blue-600 px-4 py-2 text-xs font-black uppercase tracking-wider text-white disabled:opacity-40 flex items-center gap-2"
              >
                <Sparkles size={14} />
                {directorBusy ? "AI Planning…" : trailerBusy === "create" || trailerBusy === "poll" ? "Generating…" : "Generate Trailer"}
              </button>
            </div>
          </div>
        </div>
      )}
    </UserShell>
  );
}
