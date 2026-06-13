"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import { useParams, useRouter } from "next/navigation";
import { AnimatePresence, motion } from "framer-motion";
import UserShell from "@/app/_components/UserShell";
import { apiFetch, ApiError } from "@/lib/api";
import { useAuthToken } from "@/lib/stores/authStore";
import TournamentShareModal from "../_components/TournamentShareModal";
import {
  ArrowLeft,
  CalendarClock,
  CheckCircle2,
  Coins,
  Copy,
  Crown,
  Flag,
  Loader2,
  Play,
  ShieldAlert,
  Trophy,
  UserPlus,
  Users,
} from "lucide-react";

type LeaderRow = {
  playerId: string;
  playerName: string;
  score: number;
  cheatFlag: boolean;
  rank: number;
  coinsWon?: number;
};

type LiveEventRow = {
  id: string;
  type: "info" | "success" | "warning";
  message: string;
  createdAt: number;
};

type TournamentDetail = {
  id: string;
  gameId?: string | null;
  title: string;
  status: "waiting" | "active" | "finished";
  entryFee: number;
  prizePool: number;
  maxPlayers: number;
  playersCount: number;
  startsAt: number;
  endsAt: number;
  coverImageUrl?: string | null;
  players?: Array<{ userId: string; playerName: string; joinedAt: number }>;
  leaderboardTop: LeaderRow[];
  top3: LeaderRow[];
};

function asNum(value: unknown, fallback = 0) {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string") {
    const n = Number(value);
    if (Number.isFinite(n)) return n;
  }
  return fallback;
}

function asStr(value: unknown, fallback = "") {
  return typeof value === "string" ? value : fallback;
}

function asRecord(value: unknown): Record<string, unknown> | null {
  if (!value || typeof value !== "object" || Array.isArray(value)) return null;
  return value as Record<string, unknown>;
}

function normalizeLeaderRow(raw: unknown, idx: number): LeaderRow | null {
  const obj = asRecord(raw);
  if (!obj) return null;
  const playerId = asStr(obj.playerId || obj.userId || obj.id);
  if (!playerId) return null;
  return {
    playerId,
    playerName: asStr(obj.playerName, playerId) || playerId,
    score: Math.max(0, Math.trunc(asNum(obj.score, 0))),
    cheatFlag: Boolean(obj.cheatFlag),
    rank: Math.max(1, Math.trunc(asNum(obj.rank, idx + 1))),
    coinsWon: obj.coinsWon != null ? Math.max(0, Math.trunc(asNum(obj.coinsWon, 0))) : undefined,
  };
}

function normalizeDetail(raw: unknown): TournamentDetail | null {
  const obj = asRecord(raw);
  if (!obj) return null;

  const id = asStr(obj.id || obj._id);
  if (!id) return null;

  const statusRaw = asStr(obj.status, "waiting").toLowerCase();
  const status: TournamentDetail["status"] =
    statusRaw === "active" || statusRaw === "finished" ? (statusRaw as any) : "waiting";

  const leaderboardRaw = Array.isArray(obj.leaderboardTop) ? obj.leaderboardTop : [];
  const leaderboardTop = leaderboardRaw
    .map((r, i) => normalizeLeaderRow(r, i))
    .filter((x): x is LeaderRow => Boolean(x));

  const top3Raw = Array.isArray(obj.top3) ? obj.top3 : leaderboardTop.slice(0, 3);
  const top3 = top3Raw
    .map((r, i) => normalizeLeaderRow(r, i))
    .filter((x): x is LeaderRow => Boolean(x))
    .slice(0, 3);

  return {
    id,
    gameId: asStr(obj.gameId) || null,
    title: asStr(obj.title, "Tournament"),
    status,
    entryFee: Math.max(0, Math.trunc(asNum(obj.entryFee, 0))),
    prizePool: Math.max(0, Math.trunc(asNum(obj.prizePool, 0))),
    maxPlayers: Math.max(2, Math.trunc(asNum(obj.maxPlayers, 2))),
    playersCount: Math.max(0, Math.trunc(asNum(obj.playersCount, 0))),
    startsAt: Math.max(0, Math.trunc(asNum(obj.startsAt, 0))),
    endsAt: Math.max(0, Math.trunc(asNum(obj.endsAt, 0))),
    coverImageUrl: asStr(obj.coverImageUrl) || null,
    leaderboardTop,
    top3,
  };
}

function tone(status: TournamentDetail["status"]) {
  if (status === "active") return "border-emerald-400/30 bg-emerald-500/10 text-emerald-100";
  if (status === "finished") return "border-zinc-400/30 bg-zinc-500/10 text-zinc-100";
  return "border-amber-400/30 bg-amber-500/10 text-amber-100";
}

function fmtTime(ms: number) {
  if (!ms) return "—";
  try {
    return new Date(ms).toLocaleString();
  } catch {
    return "—";
  }
}

export default function TournamentDetailsPage() {
  const router = useRouter();
  const params = useParams<{ id: string }>();
  const { token } = useAuthToken();
  const tournamentId = String(params?.id || "").trim();

  const [authUserId, setAuthUserId] = useState("");
  const [playerName, setPlayerName] = useState("Falcon42");

  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [detail, setDetail] = useState<TournamentDetail | null>(null);
  const [busy, setBusy] = useState<"join" | "play" | null>(null);

  const [nowMs, setNowMs] = useState(() => Date.now());
  const pollTimerRef = useRef<number | null>(null);

  const prevRankRef = useRef<number | null>(null);
  const toastTimerRef = useRef<number | null>(null);
  const [rankToast, setRankToast] = useState<{ kind: "up" | "down"; from: number; to: number } | null>(null);

  const [live, setLive] = useState(false);
  const [events, setEvents] = useState<LiveEventRow[]>([]);
  const [shareOpen, setShareOpen] = useState(false);

  const [showCelebration, setShowCelebration] = useState(false);
  const prevStatusRef = useRef<TournamentDetail["status"] | null>(null);
  const celebrateTimerRef = useRef<number | null>(null);

  const joined = useMemo(() => {
    if (!detail || !authUserId.trim()) return false;
    const uid = authUserId.trim();
    const players = Array.isArray(detail.players) ? detail.players : [];
    return players.some((p) => String(p?.userId || "").trim() === uid);
  }, [detail, authUserId]);

  const myRank = useMemo(() => {
    const me = authUserId.trim();
    if (!me) return null;
    const row = (detail?.leaderboardTop || []).find((r) => r.playerId === me);
    return row?.rank ?? null;
  }, [detail?.leaderboardTop, authUserId]);

  const myPodiumRow = useMemo(() => {
    if (myRank == null) return null;
    if (myRank > 3) return null;
    const me = authUserId.trim();
    if (!me) return null;
    return (detail?.top3 || []).find((r) => r.playerId === me) || null;
  }, [detail?.top3, myRank, authUserId]);

  const celebrationParticles = useMemo(() => {
    const palette = ["#f59e0b", "#f97316", "#22d3ee", "#3b82f6", "#a78bfa", "#34d399"];
    const count = 64;
    return Array.from({ length: count }).map((_, i) => {
      const seed = Math.random();
      const size = 6 + Math.round(seed * 10);
      const left = Math.round(Math.random() * 100);
      const delay = Math.random() * 0.6;
      const dur = 1.8 + Math.random() * 1.4;
      const drift = (Math.random() * 2 - 1) * 220;
      const rot = (Math.random() * 2 - 1) * 540;
      const color = palette[i % palette.length];
      return { id: `${i}_${Date.now()}`, size, left, delay, dur, drift, rot, color };
    });
  }, [showCelebration]);

  useEffect(() => {
    const prev = prevStatusRef.current;
    const next = detail?.status || null;
    prevStatusRef.current = next;

    if (!detail || !authUserId.trim()) return;
    if (prev === "finished") return;
    if (next !== "finished") return;

    const r = myRank;
    if (r == null || r > 3) return;

    setShowCelebration(true);
    if (celebrateTimerRef.current) window.clearTimeout(celebrateTimerRef.current);
    celebrateTimerRef.current = window.setTimeout(() => {
      setShowCelebration(false);
      celebrateTimerRef.current = null;
    }, 6500);

    return () => {
      if (celebrateTimerRef.current) window.clearTimeout(celebrateTimerRef.current);
      celebrateTimerRef.current = null;
    };
  }, [detail, authUserId, myRank]);

  useEffect(() => {
    if (myRank == null) return;
    const prev = prevRankRef.current;
    prevRankRef.current = myRank;
    if (prev == null || prev === myRank) return;
    const kind: "up" | "down" = myRank < prev ? "up" : "down";
    setRankToast({ kind, from: prev, to: myRank });
    if (toastTimerRef.current) window.clearTimeout(toastTimerRef.current);
    toastTimerRef.current = window.setTimeout(() => {
      setRankToast(null);
      toastTimerRef.current = null;
    }, 2200);
  }, [myRank]);

  const remaining = useMemo(() => {
    const endsAt = Number(detail?.endsAt || 0);
    if (!endsAt) return null;
    const ms = Math.max(0, endsAt - nowMs);
    const totalSec = Math.floor(ms / 1000);
    const hh = Math.floor(totalSec / 3600);
    const mm = Math.floor((totalSec % 3600) / 60);
    const ss = totalSec % 60;
    const pad = (n: number) => n.toString().padStart(2, "0");
    return { ms, label: `${pad(hh)}:${pad(mm)}:${pad(ss)}` };
  }, [detail?.endsAt, nowMs]);

  const timeProgressPct = useMemo(() => {
    const startsAt = Number(detail?.startsAt || 0);
    const endsAt = Number(detail?.endsAt || 0);
    if (!startsAt || !endsAt || endsAt <= startsAt) return null;
    const t = Math.max(0, Math.min(1, (nowMs - startsAt) / (endsAt - startsAt)));
    return Math.round(t * 100);
  }, [detail?.startsAt, detail?.endsAt, nowMs]);

  useEffect(() => {
    const t = window.setInterval(() => setNowMs(Date.now()), 1000);
    return () => window.clearInterval(t);
  }, []);

  function normalizeEventRow(raw: any): LiveEventRow | null {
    if (!raw || typeof raw !== "object") return null;
    const id = String(raw.id || raw._id || "").trim();
    if (!id) return null;
    const typeRaw = String(raw.type || "info").toLowerCase();
    const type: LiveEventRow["type"] = typeRaw === "success" || typeRaw === "warning" ? (typeRaw as any) : "info";
    return {
      id,
      type,
      message: String(raw.message || ""),
      createdAt: Number(raw.createdAt || raw.createdAtMs || 0) || 0,
    };
  }

  async function loadEvents() {
    if (!tournamentId) return;
    try {
      const raw = await apiFetch<any>(`/platform-labs/tournaments/${encodeURIComponent(tournamentId)}/notifications`, {
        method: "GET",
        token: token || undefined,
      });
      const list = Array.isArray(raw) ? raw : Array.isArray(raw?.items) ? raw.items : Array.isArray(raw?.data) ? raw.data : [];
      const next = (Array.isArray(list) ? list : [])
        .map(normalizeEventRow)
        .filter((x): x is LiveEventRow => Boolean(x))
        .sort((a, b) => b.createdAt - a.createdAt)
        .slice(0, 20);
      setEvents(next);
    } catch {
      // ignore
    }
  }

  useEffect(() => {
    if (!tournamentId) return;
    let stopped = false;
    setLive(false);

    try {
      const url = new URL(`${window.location.origin}/api/platform-labs/tournaments/events/stream`);
      url.searchParams.set("tournamentId", tournamentId);
      const es = new EventSource(url.toString());

      es.onopen = () => {
        if (stopped) return;
        setLive(true);
      };

      es.onmessage = (ev) => {
        if (stopped) return;
        try {
          const parsed = JSON.parse(ev.data || "{}");
          const row = normalizeEventRow(parsed);
          if (!row) return;
          setEvents((prev) => {
            const next = [row, ...prev.filter((x) => x.id !== row.id)].slice(0, 20);
            return next;
          });
        } catch {
          // ignore
        }
      };

      es.onerror = () => {
        if (stopped) return;
        setLive(false);
      };

      void loadEvents();
      return () => {
        stopped = true;
        try {
          es.close();
        } catch {
          // ignore
        }
        setLive(false);
      };
    } catch {
      setLive(false);
      void loadEvents();
      return;
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [tournamentId]);

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

  async function load() {
    if (!tournamentId) return;
    setLoading(true);
    setError(null);
    try {
      const raw = await apiFetch<unknown>(`/platform-labs/tournaments/${encodeURIComponent(tournamentId)}`, {
        method: "GET",
        token: token || undefined,
      });
      const normalized = normalizeDetail(raw);
      if (!normalized) throw new Error("Invalid tournament payload");
      setDetail(normalized);
    } catch (e: unknown) {
      const msg = e instanceof ApiError ? e.message : e instanceof Error ? e.message : "Failed to load tournament";
      setError(msg);
      setDetail(null);
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    void load();
    if (pollTimerRef.current) window.clearInterval(pollTimerRef.current);
    pollTimerRef.current = window.setInterval(() => {
      void load();
    }, 10_000);
    return () => {
      if (pollTimerRef.current) window.clearInterval(pollTimerRef.current);
      pollTimerRef.current = null;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [tournamentId]);

  async function join() {
    if (!detail) return;
    if (!authUserId.trim()) {
      setError("Sign in required before joining.");
      return;
    }
    if (!playerName.trim()) {
      setError("Enter a nickname before joining.");
      return;
    }
    setBusy("join");
    setError(null);
    try {
      await apiFetch("/platform-labs/tournaments/join", {
        method: "POST",
        token: token || undefined,
        body: {
          tournamentId: detail.id,
          userId: authUserId.trim(),
          playerName: playerName.trim(),
          initialBalance: 5000,
        },
      });
      await load();
    } catch (e: unknown) {
      const msg = e instanceof ApiError ? e.message : e instanceof Error ? e.message : "Join failed";
      setError(msg);
    } finally {
      setBusy(null);
    }
  }

  function play() {
    if (!detail) return;
    setBusy("play");
    router.push(`/studio/tournaments/${encodeURIComponent(detail.id)}/play`);
  }

  const top3 = detail?.top3 || [];
  const leaderboard = detail?.leaderboardTop || [];

  return (
    <UserShell title="Tournament Details" subtitle="Live leaderboard, top 3 prizes, and instant score sync.">
      <div className="space-y-5">
        {error ? <div className="rounded-xl border border-rose-500/30 bg-rose-500/10 px-4 py-3 text-sm text-rose-200">{error}</div> : null}

        <AnimatePresence>
          {showCelebration && myRank != null && myRank <= 3 ? (
            <motion.div
              key="celebration"
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              className="fixed inset-0 z-[80]"
              onClick={() => setShowCelebration(false)}
            >
              <div className="absolute inset-0 bg-black/70 backdrop-blur-sm" />

              <div className="absolute inset-0 overflow-hidden">
                <div className="absolute -top-32 left-1/2 h-[520px] w-[520px] -translate-x-1/2 rounded-full bg-amber-500/20 blur-[90px]" />
                <div className="absolute -top-24 left-[18%] h-[420px] w-[420px] rounded-full bg-cyan-500/16 blur-[100px]" />
                <div className="absolute -top-24 right-[14%] h-[420px] w-[420px] rounded-full bg-blue-500/14 blur-[100px]" />

                {celebrationParticles.map((p) => (
                  <motion.div
                    key={p.id}
                    className="absolute top-[-40px] rounded-sm"
                    style={{ left: `${p.left}%`, width: p.size, height: Math.max(6, Math.round(p.size * 0.6)), backgroundColor: p.color }}
                    initial={{ y: -60, x: 0, rotate: 0, opacity: 0 }}
                    animate={{ y: 900, x: p.drift, rotate: p.rot, opacity: [0, 1, 1, 0] }}
                    transition={{ delay: p.delay, duration: p.dur, ease: "easeOut" }}
                  />
                ))}
              </div>

              <div className="absolute inset-0 flex items-center justify-center p-4">
                <motion.div
                  aria-hidden
                  className="absolute h-[520px] w-[520px] rounded-full border border-amber-300/15"
                  style={{ filter: "drop-shadow(0 0 60px rgba(245,158,11,0.18))" }}
                  initial={{ opacity: 0, scale: 0.94, rotate: -15 }}
                  animate={{ opacity: 1, scale: 1, rotate: 345 }}
                  exit={{ opacity: 0, scale: 0.98 }}
                  transition={{ duration: 6.5, ease: "linear" }}
                />
                <motion.div
                  initial={{ y: 18, scale: 0.96, opacity: 0 }}
                  animate={{ y: 0, scale: 1, opacity: 1 }}
                  exit={{ y: 10, scale: 0.98, opacity: 0 }}
                  transition={{ type: "spring", stiffness: 220, damping: 18 }}
                  className="w-full max-w-lg overflow-hidden rounded-2xl border border-white/[0.05] bg-gradient-to-b from-white/10 to-black/30 shadow-sm"
                >
                  <div className="relative p-7">
                    <div className="absolute inset-0 " />
                    <div className="relative">
                      <div className="inline-flex items-center gap-2 rounded-full border border-amber-300/30 bg-amber-500/10 px-3 py-1 text-[10px] font-semibold tracking-wider text-amber-100">
                        {myRank === 1 ? <Crown size={12} className="text-amber-200" /> : <Trophy size={12} className="text-amber-200" />}
                        Tournament Finished
                      </div>

                      <div className="mt-4 text-3xl font-semibold tracking-tight text-[var(--foreground)]">
                        {myRank === 1 ? "Champion" : myRank === 2 ? "Runner-up" : "Top 3"}
                      </div>
                      <div className="mt-2 text-sm text-[var(--gf-text-muted)]">
                        {myRank === 1
                          ? "You took #1 and earned the prize."
                          : `You finished #${myRank} and earned a prize.`}
                      </div>

                      <div className="mt-5 grid grid-cols-2 gap-3">
                        <div className="rounded-xl border border-white/[0.05] bg-[var(--gf-shell-bg)] p-4">
                          <div className="text-[10px] font-semibold tracking-wider text-zinc-500">Rank</div>
                          <div className="mt-2 text-2xl font-semibold text-[var(--foreground)]">#{myRank}</div>
                        </div>
                        <div className="rounded-xl border border-white/[0.05] bg-[var(--gf-shell-bg)] p-4">
                          <div className="text-[10px] font-semibold tracking-wider text-zinc-500">Prize</div>
                          <div className="mt-2 text-2xl font-semibold text-[var(--foreground)] tabular-nums">
                            {myPodiumRow?.coinsWon != null ? myPodiumRow.coinsWon.toLocaleString() : "—"}
                          </div>
                          <div className="text-[11px] text-zinc-400">coins (paid as USD to Creator Wallet)</div>
                        </div>
                      </div>

                      <div className="mt-6 flex gap-3">
                        <button
                          onClick={(e) => {
                            e.preventDefault();
                            e.stopPropagation();
                            setShowCelebration(false);
                          }}
                          className="flex-1 rounded-xl border border-white/[0.05] bg-white/[0.02] px-5 py-3 text-xs font-semibold tracking-wide text-zinc-200 hover:bg-white/10"
                        >
                          Close
                        </button>
                        <button
                          onClick={(e) => {
                            e.preventDefault();
                            e.stopPropagation();
                            router.push("/studio/wallet");
                          }}
                          className="flex-[1.2] rounded-xl border border-amber-300/30 bg-gradient-to-r from-amber-500/20 to-yellow-500/10 px-5 py-3 text-xs font-semibold tracking-wide text-amber-100 hover:brightness-110"
                        >
                          View Wallet
                        </button>
                      </div>
                    </div>
                  </div>
                </motion.div>
              </div>
            </motion.div>
          ) : null}
        </AnimatePresence>

        <div className="relative overflow-hidden rounded-2xl border border-white/[0.05] bg-[var(--gf-panel-bg-strong)]">
          <div className="absolute inset-0 " />
          <div className="relative p-6">
            <div className="flex flex-wrap items-start justify-between gap-3">
              <div className="min-w-[260px]">
                <div className="inline-flex items-center gap-2 rounded-full border border-white/[0.05] bg-white/[0.02] px-3 py-1 text-[10px] font-semibold tracking-wider text-[var(--gf-text-muted)]">
                  <Trophy size={12} /> Arena Intelligence
                </div>
                <div className="mt-3 text-3xl font-black tracking-tight text-white">
                  {loading ? "Loading…" : detail?.title || "Tournament"}
                </div>
                <div className="mt-2 flex flex-wrap items-center gap-2">
                  <div className={`rounded-full border px-3 py-1 text-[10px] font-semibold tracking-wider ${detail ? tone(detail.status) : "border-white/[0.05] bg-white/[0.02] text-zinc-200"}`}>
                    {detail?.status || "…"}
                  </div>
                  <div className="rounded-full border border-white/[0.05] bg-white/[0.02] px-3 py-1 text-[10px] font-semibold tracking-wider text-zinc-200">
                    ID: {tournamentId || "—"}
                  </div>
                </div>
              </div>

              <div className="flex flex-wrap gap-2">
                <button
                  onClick={() => router.push("/studio/tournaments/list")}
                  className="rounded-xl border border-white/[0.05] bg-white/[0.02] px-4 py-2 text-xs font-semibold tracking-wide text-zinc-200 flex items-center gap-2"
                >
                  <ArrowLeft size={14} /> Back
                </button>
                <button
                  onClick={async () => {
                    try {
                      await navigator.clipboard.writeText(window.location.href);
                    } catch {
                      // ignore
                    }
                  }}
                  className="rounded-xl border border-white/[0.05] bg-white/[0.02] px-4 py-2 text-xs font-semibold tracking-wide text-zinc-200 flex items-center gap-2"
                >
                  <Copy size={14} /> Copy Link
                </button>
                <button
                  onClick={() => setShareOpen(true)}
                  className="rounded-xl border border-white/[0.05] bg-gradient-to-r from-cyan-500/15 to-blue-500/10 px-4 py-2 text-xs font-semibold tracking-wide text-white flex items-center gap-2"
                >
                  Share
                </button>
                <button
                  onClick={join}
                  disabled={!detail || busy === "join" || detail?.status === "finished"}
                  className="rounded-xl bg-white px-4 py-2 text-xs font-medium text-black hover:bg-zinc-200 disabled:opacity-60 flex items-center gap-2"
                >
                  {busy === "join" ? <Loader2 size={14} className="animate-spin" /> : <UserPlus size={14} />} Join
                </button>
                <button
                  onClick={play}
                  disabled={!detail?.gameId}
                  className="rounded-xl border border-white/[0.05] bg-white/[0.02] px-4 py-2 text-xs font-medium text-white hover:bg-white/[0.05] flex items-center gap-2"
                >
                  <Play size={14} /> Play
                </button>
              </div>
            </div>

            <div className="mt-6 grid grid-cols-1 gap-4 lg:grid-cols-12">
              <div className="lg:col-span-7 space-y-4">
                <div className="rounded-xl border border-white/[0.05] bg-white/[0.03] p-5 shadow-sm">
                  <div className="text-[11px] font-black uppercase tracking-widest text-white/90">Arena Stats</div>
                  {timeProgressPct != null ? (
                    <div className="mt-3 rounded-xl border border-white/[0.05] bg-[var(--gf-shell-bg)]/50 p-4">
                      <div className="flex items-center justify-between">
                        <div className="text-[10px] font-semibold tracking-wider text-zinc-500">Tournament Progress</div>
                        <div className="text-[10px] font-semibold tracking-wider text-zinc-400 tabular-nums">{timeProgressPct}%</div>
                      </div>
                      <div className="mt-2 h-2 w-full rounded-full bg-white/10 overflow-hidden">
                        <div
                          className="h-full rounded-full bg-gradient-to-r from-emerald-400 via-cyan-400 to-blue-400"
                          style={{ width: `${timeProgressPct}%` }}
                        />
                      </div>
                      {remaining ? (
                        <div className="mt-2 text-xs text-zinc-400">Ends in {remaining.label}</div>
                      ) : null}
                    </div>
                  ) : null}
                  <div className="mt-4 grid grid-cols-2 gap-3 md:grid-cols-4">
                    <div className="rounded-xl border border-white/[0.05] bg-white/[0.02] p-3">
                      <div className="text-[10px] font-black uppercase tracking-widest text-zinc-500">Entry</div>
                      <div className="mt-1 text-lg font-black text-white flex items-center gap-1"><Coins size={14} className="text-amber-500" /> {detail?.entryFee ?? 0}</div>
                      <div className="text-[10px] font-bold text-zinc-400 uppercase">coins</div>
                    </div>
                    <div className="rounded-xl border border-white/[0.05] bg-white/[0.02] p-3">
                      <div className="text-[10px] font-black uppercase tracking-widest text-zinc-500">Pool</div>
                      <div className="mt-1 text-lg font-black text-white flex items-center gap-1"><Trophy size={14} className="text-blue-500" /> {(detail?.prizePool ?? 0).toLocaleString()}</div>
                      <div className="text-[10px] font-bold text-zinc-400 uppercase">coins</div>
                    </div>
                    <div className="rounded-xl border border-white/[0.05] bg-white/[0.02] p-3">
                      <div className="text-[10px] font-black uppercase tracking-widest text-zinc-500">Players</div>
                      <div className="mt-1 text-lg font-black text-white flex items-center gap-1"><Users size={14} className="text-cyan-500" /> {detail?.playersCount ?? 0}/{detail?.maxPlayers ?? 0}</div>
                      <div className="text-[10px] font-bold text-zinc-400 uppercase">joined</div>
                    </div>
                    <div className="rounded-xl border border-white/[0.05] bg-white/[0.02] p-3">
                      <div className="text-[10px] font-black uppercase tracking-widest text-zinc-500">Ends</div>
                      <div className="mt-1 text-[12px] font-black text-white flex items-center gap-1"><CalendarClock size={14} className="text-zinc-500" /> {fmtTime(detail?.endsAt ?? 0)}</div>
                      <div className="text-[10px] font-bold text-zinc-400 uppercase">deadline</div>
                    </div>
                  </div>

                  <div className="mt-4 grid grid-cols-1 gap-3 md:grid-cols-2">
                    <div className="rounded-xl border border-white/[0.05] bg-[var(--gf-shell-bg)]/50 p-4">
                      <div className="text-[10px] font-semibold tracking-wider text-zinc-500">Your Identity</div>
                      <div className="mt-2 text-sm font-semibold text-[var(--foreground)]">{authUserId.trim() ? authUserId.trim() : "—"}</div>
                      <div className="mt-3">
                        <label className="block text-[10px] font-semibold tracking-wider text-zinc-500">Nickname</label>
                        <input value={playerName} onChange={(e) => setPlayerName(e.target.value)} className="gf-input w-full rounded-xl p-3" />
                      </div>
                    </div>
                    <div className="rounded-xl border border-white/[0.05] bg-[var(--gf-shell-bg)]/50 p-4">
                      <div className="text-[10px] font-semibold tracking-wider text-zinc-500">Participation</div>
                      <div className="mt-2 flex items-center gap-2 text-sm font-bold">
                        {joined ? <CheckCircle2 size={16} className="text-emerald-400" /> : <Flag size={16} className="text-amber-300" />}
                        <span className="text-zinc-200">{joined ? "Joined" : "Not joined yet"}</span>
                      </div>
                      {myRank != null ? (
                        <div className="mt-2 inline-flex items-center gap-2 rounded-full border border-white/[0.05] bg-cyan-500/10 px-3 py-1.5 text-[11px] font-semibold text-white">
                          <Trophy size={14} className="text-cyan-200" /> You are #{myRank}
                        </div>
                      ) : null}
                      <div className="mt-2 text-xs text-zinc-400">
                        Join first, then press Play. Scores are submitted automatically when the game sends score events.
                      </div>
                    </div>
                  </div>
                </div>

                <div className="rounded-xl border border-white/[0.05] bg-white/[0.03] p-5 shadow-sm">
                  <div className="flex items-center justify-between gap-2">
                    <div>
                      <div className="text-[11px] font-black uppercase tracking-widest text-white/90">Leaderboard</div>
                      <div className="mt-1 text-sm font-bold text-zinc-500">Top 10 ranking (server computed)</div>
                    </div>
                    <button
                      onClick={load}
                      disabled={loading}
                      className="rounded-xl border border-white/[0.05] bg-white/[0.02] px-3 py-2 text-[10px] font-semibold tracking-wide text-zinc-200 hover:bg-white/10 disabled:opacity-60"
                    >
                      {loading ? "Refreshing…" : "Refresh"}
                    </button>
                  </div>

                  {!loading && leaderboard.length === 0 ? (
                    <div className="mt-4 rounded-xl border border-white/[0.05] bg-[var(--gf-shell-bg)]/50 p-4 text-sm text-zinc-400 flex items-center gap-2">
                      <ShieldAlert size={16} /> No scores yet. Be the first to play.
                    </div>
                  ) : null}

                  {leaderboard.length ? (
                    <div className="mt-4 overflow-hidden rounded-xl border border-white/[0.05]">
                      <div className="grid grid-cols-12 bg-white/[0.02] px-4 py-3 text-[10px] font-semibold tracking-wider text-zinc-400">
                        <div className="col-span-1">#</div>
                        <div className="col-span-6">Player</div>
                        <div className="col-span-3">Score</div>
                        <div className="col-span-2 text-right">Trust</div>
                      </div>
                      {leaderboard.slice(0, 10).map((r) => (
                        <div key={`${r.playerId}_${r.rank}`} className="grid grid-cols-12 border-t border-white/[0.05] px-4 py-3">
                          <div className="col-span-1 text-sm font-semibold text-white">{r.rank}</div>
                          <div className="col-span-6">
                            <div className="text-sm font-semibold text-white truncate">{r.playerName}</div>
                            <div className="text-[11px] text-zinc-500 truncate">{r.playerId}</div>
                          </div>
                          <div className="col-span-3 text-sm font-semibold text-white">{r.score.toLocaleString()}</div>
                          <div className="col-span-2 text-right">
                            {r.cheatFlag ? (
                              <span className="inline-flex items-center gap-1 rounded-full border border-rose-500/30 bg-rose-500/10 px-2 py-1 text-[10px] font-semibold tracking-wide text-rose-200">
                                <ShieldAlert size={12} /> Flagged
                              </span>
                            ) : (
                              <span className="inline-flex items-center gap-1 rounded-full border border-emerald-500/30 bg-emerald-500/10 px-2 py-1 text-[10px] font-semibold tracking-wide text-emerald-200">
                                <CheckCircle2 size={12} /> OK
                              </span>
                            )}
                          </div>
                        </div>
                      ))}
                    </div>
                  ) : null}
                </div>
              </div>

              <div className="lg:col-span-5 space-y-4">
                {rankToast ? (
                  <div
                    className={`rounded-xl border px-4 py-3 text-sm font-semibold tracking-wide ${
                      rankToast.kind === "up"
                        ? "border-emerald-400/25 bg-emerald-500/10 text-emerald-100"
                        : "border-rose-400/25 bg-rose-500/10 text-rose-200"
                    }`}
                  >
                    {rankToast.kind === "up" ? "Rank Up" : "Rank Down"} • #{rankToast.from} → #{rankToast.to}
                  </div>
                ) : null}

                <div className="rounded-xl border border-white/[0.05] bg-[var(--gf-shell-bg)] overflow-hidden">
                  <div className="relative h-52">
                    {detail?.coverImageUrl ? (
                      // eslint-disable-next-line @next/next/no-img-element
                      <img src={detail.coverImageUrl} alt="" className="h-full w-full object-cover" />
                    ) : (
                      <div className="h-full w-full bg-gradient-to-br from-blue-500/25 via-cyan-500/10 to-black/10" />
                    )}
                    <div className="absolute inset-0 bg-gradient-to-t from-black/85 via-black/20 to-transparent" />
                    <div className="absolute left-5 right-5 bottom-4">
                      <div className="text-xs font-semibold tracking-wider text-cyan-200/90">Top 3</div>
                      <div className="mt-1 text-sm text-zinc-300">Prize pool is distributed automatically when the tournament ends.</div>
                    </div>
                  </div>

                  <div className="p-5 space-y-3">
                    <div className="flex flex-wrap items-center justify-between gap-2">
                      <div className="text-[10px] font-semibold tracking-wider text-zinc-500">Podium</div>
                      <button
                        onClick={async () => {
                          try {
                            const url = `${window.location.origin}/studio/tournaments/${encodeURIComponent(detail?.id || tournamentId)}/play`;
                            await navigator.clipboard.writeText(url);
                          } catch {
                            // ignore
                          }
                        }}
                        className="rounded-xl border border-white/[0.05] bg-white/[0.02] px-3 py-2 text-[10px] font-semibold tracking-wide text-zinc-200 hover:bg-white/10"
                      >
                        Copy Play Link
                      </button>
                    </div>

                    {top3.length === 0 ? (
                      <div className="rounded-xl border border-white/[0.05] bg-[var(--gf-shell-bg)]/50 p-4 text-sm text-zinc-400">Top 3 will appear once players submit scores.</div>
                    ) : (
                      <div className="grid grid-cols-3 gap-3">
                        {[2, 1, 3].map((rank) => {
                          const row = top3.find((r) => r.rank === rank);
                          const crown = rank === 1;
                          return (
                            <div
                              key={`pod_${rank}`}
                              className={`rounded-xl border p-3 text-center ${
                                crown
                                  ? "border-amber-300/30 bg-amber-500/10"
                                  : rank === 2
                                    ? "border-blue-300/30 bg-blue-500/10"
                                    : "border-emerald-300/30 bg-emerald-500/10"
                              }`}
                            >
                              <div className="flex items-center justify-center gap-1.5">
                                {crown ? <Crown size={16} className="text-amber-200" /> : <Trophy size={14} className="text-white/80" />}
                                <span className="text-[10px] font-semibold tracking-wide text-white/80">#{rank}</span>
                              </div>
                              <div className="mt-2 text-xs font-semibold text-white truncate">{row?.playerName || "—"}</div>
                              <div className="mt-1 text-[11px] text-white/70 tabular-nums">{row ? row.score.toLocaleString() : "—"}</div>
                            </div>
                          );
                        })}
                      </div>
                    )}

                    {top3.length ? (
                      <div className="pt-2 space-y-2">
                        {top3.map((r) => (
                          <div key={`top_${r.rank}_${r.playerId}`} className="rounded-xl border border-white/[0.05] bg-white/[0.02] p-4 flex items-center gap-3">
                            <div className={`h-11 w-11 rounded-xl flex items-center justify-center border ${r.rank === 1 ? "border-amber-300/30 bg-amber-500/15 text-amber-200" : r.rank === 2 ? "border-blue-300/30 bg-blue-500/15 text-blue-200" : "border-emerald-300/30 bg-emerald-500/15 text-emerald-200"}`}>
                              {r.rank === 1 ? <Crown size={18} /> : <Trophy size={18} />}
                            </div>
                            <div className="min-w-0 flex-1">
                              <div className="text-sm font-semibold text-white truncate">{r.playerName}</div>
                              <div className="text-[11px] text-zinc-500 truncate">{r.playerId}</div>
                            </div>
                            <div className="text-right">
                              <div className="text-sm font-semibold text-white">{r.score.toLocaleString()}</div>
                              <div className="text-[11px] text-zinc-400">score</div>
                            </div>
                          </div>
                        ))}
                      </div>
                    ) : null}
                  </div>
                </div>

                <div className="rounded-xl border border-white/[0.05] bg-[var(--gf-shell-bg)] p-5">
                  <div className="flex items-center justify-between">
                    <div className="text-[11px] font-semibold tracking-wider text-zinc-400">Live Event Feed</div>
                    <div className={`rounded-full border px-2 py-0.5 text-[10px] font-semibold tracking-wider ${live ? "border-emerald-400/30 bg-emerald-500/10 text-emerald-100" : "border-amber-400/30 bg-amber-500/10 text-amber-100"}`}>
                      {live ? "LIVE" : "POLL"}
                    </div>
                  </div>
                  <div className="mt-3 space-y-2 max-h-[340px] overflow-auto pr-1">
                    {events.length === 0 ? (
                      <div className="rounded-xl border border-white/[0.05] bg-[var(--gf-shell-bg)]/50 p-4 text-sm text-zinc-400">No events yet.</div>
                    ) : (
                      events.map((e) => (
                        <div
                          key={e.id}
                          className={`rounded-xl border px-3 py-2 ${
                            e.type === "success"
                              ? "border-emerald-400/20 bg-emerald-500/10"
                              : e.type === "warning"
                                ? "border-amber-400/20 bg-amber-500/10"
                                : "border-white/[0.05] bg-white/[0.02]"
                          }`}
                        >
                          <div className="flex items-center justify-between gap-3">
                            <div className="text-[10px] font-semibold tracking-wider text-zinc-400">{e.type}</div>
                            <div className="text-[10px] font-semibold tracking-wider text-zinc-500">
                              {e.createdAt ? new Date(e.createdAt).toLocaleTimeString() : ""}
                            </div>
                          </div>
                          <div className="mt-1 text-xs text-zinc-200">{e.message}</div>
                        </div>
                      ))
                    )}
                  </div>
                  <button
                    onClick={() => void loadEvents()}
                    className="mt-3 w-full rounded-xl border border-white/[0.05] bg-white/[0.02] px-3 py-2 text-[10px] font-semibold tracking-wide text-zinc-200 hover:bg-white/10"
                  >
                    Refresh Feed
                  </button>
                </div>

                <div className="rounded-xl border border-white/[0.05] bg-[var(--gf-shell-bg)] p-5">
                  <div className="text-[11px] font-semibold tracking-wider text-zinc-400">How scoring works</div>
                  <div className="mt-2 text-sm text-zinc-200 font-semibold">You play the project. The game posts a score event. The platform submits it.</div>
                  <div className="mt-2 text-xs text-zinc-500">
                    If your build doesn\'t send score events yet, we can wire it into the WebGL loader with `window.parent.postMessage`.
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <TournamentShareModal open={shareOpen} onClose={() => setShareOpen(false)} tournamentId={tournamentId} />
    </UserShell>
  );
}
