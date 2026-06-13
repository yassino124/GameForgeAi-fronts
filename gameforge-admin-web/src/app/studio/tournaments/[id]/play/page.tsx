"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import { useParams, useRouter, useSearchParams } from "next/navigation";
import { AnimatePresence, motion } from "framer-motion";
import UserShell from "@/app/_components/UserShell";
import { apiFetch, ApiError } from "@/lib/api";
import { useAuthToken } from "@/lib/stores/authStore";
import TournamentShareModal from "../../_components/TournamentShareModal";
import { ArrowLeft, CheckCircle2, Coins, Crown, Copy, Expand, Loader2, ShieldAlert, Trophy, UserPlus, Users } from "lucide-react";

type PlayUrlResponse = {
  url: string;
  tournamentId: string;
  projectId: string;
};

type LeaderRow = {
  playerId: string;
  playerName: string;
  score: number;
  rank: number;
  cheatFlag?: boolean;
  coinsWon?: number;
};

type TournamentDetail = {
  id: string;
  title?: string;
  status?: "waiting" | "active" | "finished";
  entryFee?: number;
  prizePool?: number;
  playersCount?: number;
  maxPlayers?: number;
  startsAt?: number;
  endsAt?: number;
  leaderboardTop?: LeaderRow[];
  top3?: LeaderRow[];
  players?: Array<{ userId: string; playerName: string; joinedAt: number }>;
};

function asStr(v: unknown) {
  return typeof v === "string" ? v : "";
}

export default function TournamentPlayPage() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const params = useParams<{ id: string }>();
  const { token } = useAuthToken();
  const tournamentId = String(params?.id || "").trim();

  const spectate = String(searchParams?.get("spectate") || "").trim() === "1";

  const [authUserId, setAuthUserId] = useState("");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [playUrl, setPlayUrl] = useState<string | null>(null);
  const [viewerCountry, setViewerCountry] = useState<string>("");

  const [detail, setDetail] = useState<TournamentDetail | null>(null);
  const [detailErr, setDetailErr] = useState<string | null>(null);
  const [joining, setJoining] = useState(false);
  const [joinErr, setJoinErr] = useState<string | null>(null);
  const [joined, setJoined] = useState(false);
  const [playerName, setPlayerName] = useState("Falcon42");

  const [lastScore, setLastScore] = useState<number | null>(null);
  const [lastDurationSec, setLastDurationSec] = useState<number | null>(null);
  const [submitBusy, setSubmitBusy] = useState(false);
  const [submitErr, setSubmitErr] = useState<string | null>(null);

  const [iframeMsgCount, setIframeMsgCount] = useState(0);
  const [lastIframeMsgType, setLastIframeMsgType] = useState<string | null>(null);
  const [lastIframeMsgAt, setLastIframeMsgAt] = useState<number | null>(null);

  const [manualScore, setManualScore] = useState<string>("");
  const [manualDurationSec, setManualDurationSec] = useState<string>("");

  const [nowMs, setNowMs] = useState(() => Date.now());

  const iframeRef = useRef<HTMLIFrameElement | null>(null);
  const prevRankRef = useRef<number | null>(null);
  const toastTimerRef = useRef<number | null>(null);
  const [rankToast, setRankToast] = useState<{ kind: "up" | "down"; from: number; to: number } | null>(null);

  const [shareOpen, setShareOpen] = useState(false);

  const [showFinishOverlay, setShowFinishOverlay] = useState(false);
  const finishTimerRef = useRef<number | null>(null);

  const title = useMemo(() => (tournamentId ? `Tournament Play • ${tournamentId}` : "Tournament Play"), [tournamentId]);

  useEffect(() => {
    const t = window.setInterval(() => setNowMs(Date.now()), 1000);
    return () => window.clearInterval(t);
  }, []);

  const myRank = useMemo(() => {
    const me = authUserId.trim();
    if (!me) return null;
    const rows = detail?.leaderboardTop || [];
    const found = rows.find((r) => r.playerId === me);
    return found?.rank ?? null;
  }, [detail?.leaderboardTop, authUserId]);

  const myTop3Row = useMemo(() => {
    if (myRank == null || myRank > 3) return null;
    const me = authUserId.trim();
    if (!me) return null;
    return (detail?.top3 || []).find((r) => r.playerId === me) || null;
  }, [detail?.top3, myRank, authUserId]);

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

  function normalizeLeader(raw: any, idx: number): LeaderRow | null {
    if (!raw || typeof raw !== "object") return null;
    const playerId = String((raw as any).playerId || "").trim();
    if (!playerId) return null;
    return {
      playerId,
      playerName: String((raw as any).playerName || playerId),
      score: Math.max(0, Math.trunc(Number((raw as any).score || 0))),
      rank: Math.max(1, Math.trunc(Number((raw as any).rank || idx + 1))),
      cheatFlag: Boolean((raw as any).cheatFlag),
    };
  }

  function normalizeDetail(raw: unknown): TournamentDetail | null {
    if (!raw || typeof raw !== "object") return null;
    const obj: any = raw as any;
    const id = String(obj.id || obj._id || "").trim();
    if (!id) return null;
    const leaderboardTop = Array.isArray(obj.leaderboardTop)
      ? obj.leaderboardTop.map((r: any, i: number) => normalizeLeader(r, i)).filter(Boolean)
      : [];
    const top3 = Array.isArray(obj.top3) ? obj.top3.map((r: any, i: number) => normalizeLeader(r, i)).filter(Boolean) : [];
    const players = Array.isArray(obj.players)
      ? obj.players
          .map((p: any) => {
            const userId = String(p?.userId || "").trim();
            if (!userId) return null;
            return {
              userId,
              playerName: String(p?.playerName || userId).trim(),
              joinedAt: Number(p?.joinedAt || 0) || 0,
            };
          })
          .filter(Boolean)
      : [];
    return {
      id,
      title: String(obj.title || ""),
      status: (String(obj.status || "").toLowerCase() as any) || undefined,
      entryFee: Number.isFinite(Number(obj.entryFee)) ? Math.max(0, Math.trunc(Number(obj.entryFee))) : undefined,
      prizePool: Number.isFinite(Number(obj.prizePool)) ? Math.max(0, Math.trunc(Number(obj.prizePool))) : undefined,
      playersCount: Number.isFinite(Number(obj.playersCount)) ? Math.max(0, Math.trunc(Number(obj.playersCount))) : undefined,
      maxPlayers: Number.isFinite(Number(obj.maxPlayers)) ? Math.max(0, Math.trunc(Number(obj.maxPlayers))) : undefined,
      startsAt: Number.isFinite(Number(obj.startsAt)) ? Math.max(0, Math.trunc(Number(obj.startsAt))) : undefined,
      endsAt: Number.isFinite(Number(obj.endsAt)) ? Math.max(0, Math.trunc(Number(obj.endsAt))) : undefined,
      leaderboardTop: leaderboardTop as any,
      top3: top3 as any,
      players: players as any,
    };
  }

  async function loadDetail() {
    if (!tournamentId) return;
    setDetailErr(null);
    try {
      const raw = await apiFetch<unknown>(`/platform-labs/tournaments/${encodeURIComponent(tournamentId)}`,
        { method: "GET", token: token || undefined },
      );
      const d = normalizeDetail(raw);
      if (!d) throw new Error("Invalid tournament detail payload");
      setDetail(d);
      if (authUserId.trim()) {
        const me = authUserId.trim();
        const isPlayer = (Array.isArray(d.players) ? d.players : []).some((p) => String((p as any)?.userId || "").trim() === me);
        if (isPlayer) setJoined(true);
      }
    } catch (e: unknown) {
      const msg = e instanceof ApiError ? e.message : e instanceof Error ? e.message : "Failed to load tournament";
      setDetailErr(msg);
    }
  }

  async function joinNow() {
    if (!tournamentId) return;
    if (!token) {
      setJoinErr("Sign in required before joining.");
      return;
    }
    if (!authUserId.trim()) {
      setJoinErr("Missing user identity.");
      return;
    }
    if (!playerName.trim()) {
      setJoinErr("Enter a nickname.");
      return;
    }
    setJoining(true);
    setJoinErr(null);
    try {
      await apiFetch("/platform-labs/tournaments/join", {
        method: "POST",
        token,
        body: {
          tournamentId,
          userId: authUserId.trim(),
          playerName: playerName.trim(),
          initialBalance: 5000,
        },
      });
      setJoined(true);
      await loadDetail();
    } catch (e: unknown) {
      const msg = e instanceof ApiError ? e.message : e instanceof Error ? e.message : "Join failed";
      const lower = String(msg || "").toLowerCase();
      if (lower.includes("already joined")) {
        setJoined(true);
        await loadDetail();
      } else {
        setJoinErr(msg);
      }
    } finally {
      setJoining(false);
    }
  }

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
    void loadDetail();
    const timer = window.setInterval(() => {
      void loadDetail();
    }, 5000);
    return () => window.clearInterval(timer);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [tournamentId]);

  useEffect(() => {
    if (!tournamentId) return;
    if (detail?.status !== "finished") return;

    try {
      iframeRef.current?.contentWindow?.postMessage({ type: "gameforge_stop" }, "*");
    } catch {
      // ignore
    }
    try {
      if (iframeRef.current) iframeRef.current.src = "about:blank";
    } catch {
      // ignore
    }

    setPlayUrl(null);
    setShowFinishOverlay(true);

    if (finishTimerRef.current) window.clearTimeout(finishTimerRef.current);
    finishTimerRef.current = window.setTimeout(() => {
      finishTimerRef.current = null;
      router.replace(`/studio/tournaments/${encodeURIComponent(tournamentId)}`);
    }, 8000);
  }, [detail?.status, tournamentId, router]);

  useEffect(() => {
    return () => {
      if (finishTimerRef.current) window.clearTimeout(finishTimerRef.current);
      finishTimerRef.current = null;
    };
  }, []);

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
    }, 2300);
  }, [myRank]);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      if (!tournamentId) return;
      setLoading(true);
      setError(null);
      try {
        let cc = "";
        try {
          const geo: any = await apiFetch("/geo/country", { method: "GET", token: token || undefined });
          const c = String(geo?.countryCode || geo?.data?.countryCode || "").trim().toUpperCase();
          cc = c;
          if (!cancelled) setViewerCountry(c);
        } catch {
          cc = "";
          if (!cancelled) setViewerCountry("");
        }

        const data = await apiFetch<PlayUrlResponse>(`/platform-labs/tournaments/${encodeURIComponent(tournamentId)}/play-url`, {
          method: "GET",
          token: token || undefined,
        });
        const url = asStr((data as any)?.url);
        if (!url) throw new Error("Missing play url");
        if (!cancelled) {
          try {
            const u = new URL(url);
            const finalCc = (String(cc || "").trim().toUpperCase() || String(u.searchParams.get("countryCode") || "").trim().toUpperCase());
            if (finalCc) u.searchParams.set("countryCode", finalCc);
            setPlayUrl(u.toString());
          } catch {
            setPlayUrl(url);
          }
        }
      } catch (e: unknown) {
        const msg = e instanceof ApiError ? e.message : e instanceof Error ? e.message : "Failed to load play url";
        if (!cancelled) {
          setError(msg);
          setPlayUrl(null);
        }
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [tournamentId, token]);

  useEffect(() => {
    if (!tournamentId || !authUserId.trim()) return;

    const onMsg = (ev: MessageEvent) => {
      try {
        const srcWin = iframeRef.current?.contentWindow;
        if (!srcWin || ev.source !== srcWin) return;
        const data: any = ev.data;
        if (!data || typeof data !== "object") return;
        const type = String(data.type || data.kind || "").trim().toLowerCase();

        setIframeMsgCount((v) => v + 1);
        setLastIframeMsgType(type || "(missing)");
        setLastIframeMsgAt(Date.now());

        const isScore = type === "gameforge_score" || type === "tournament_score" || type === "score";
        if (!isScore) return;

        const score = Math.max(0, Math.trunc(Number(data.score || 0)));
        const durationSec = Math.max(1, Math.trunc(Number(data.durationSec || data.duration || 1)));
        const runId = String(data.runId || data.run_id || "").trim();
        const deviceId = String(data.deviceId || data.device_id || "web" + "_" + tournamentId).trim();
        const clientTimeMs = Number.isFinite(Number(data.clientTimeMs)) ? Math.trunc(Number(data.clientTimeMs)) : Date.now();
        const signature = String(data.signature || "").trim();
        const telemetryHash = String(data.telemetryHash || "").trim();

        setLastScore(score);
        setLastDurationSec(durationSec);
        setSubmitErr(null);

        if (spectate) return;

        // Stable deviceId + required runId fallback.
        let stableDeviceId = "";
        try {
          const key = "gf:tournament:deviceId";
          stableDeviceId = window.localStorage.getItem(key) || "";
          if (!stableDeviceId) {
            stableDeviceId = `web_${Math.random().toString(16).slice(2)}_${Date.now().toString(16)}`;
            window.localStorage.setItem(key, stableDeviceId);
          }
        } catch {
          stableDeviceId = "web";
        }

        const finalRunId = runId || `run_${Date.now().toString(36)}_${Math.random().toString(16).slice(2)}`;
        const finalDeviceId = (deviceId || stableDeviceId || "web").trim();

        setSubmitBusy(true);
        apiFetch("/platform-labs/tournaments/submit-score", {
          method: "POST",
          token: token || undefined,
          body: {
            tournamentId,
            playerId: authUserId.trim(),
            score,
            durationSec,
            runId: finalRunId,
            deviceId: finalDeviceId,
            clientTimeMs,
            signature: signature || undefined,
            telemetryHash: telemetryHash || undefined,
          },
        })
          .catch((e: any) => {
            const msg = e instanceof ApiError ? e.message : e?.message || "Score submit failed";
            setSubmitErr(msg);
          })
          .finally(() => {
            setSubmitBusy(false);
          });
      } catch {
        // ignore
      }
    };

    window.addEventListener("message", onMsg);
    return () => window.removeEventListener("message", onMsg);
  }, [tournamentId, authUserId, token, spectate, playUrl]);

  return (
    <UserShell title={detail?.title || title} subtitle="Arcade-style WebGL runner with automatic tournament score submission.">
      <div className="space-y-4">
        {error ? <div className="rounded-xl border border-rose-500/30 bg-rose-500/10 px-4 py-3 text-sm text-rose-200">{error}</div> : null}
        {detailErr ? <div className="rounded-xl border border-rose-500/30 bg-rose-500/10 px-4 py-3 text-sm text-rose-200">{detailErr}</div> : null}

        <AnimatePresence>
          {showFinishOverlay && detail?.status === "finished" ? (
            <motion.div
              key="finish-overlay"
              className="fixed inset-0 z-[90]"
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              onClick={() => {
                setShowFinishOverlay(false);
                router.replace(`/studio/tournaments/${encodeURIComponent(tournamentId)}`);
              }}
            >
              <div className="absolute inset-0 bg-black/75 backdrop-blur-sm" />
              <div className="absolute inset-0 overflow-hidden">
                <div className="absolute -top-32 left-1/2 h-[560px] w-[560px] -translate-x-1/2 rounded-full bg-amber-500/22 blur-[100px]" />
                <div className="absolute -top-28 left-[12%] h-[440px] w-[440px] rounded-full bg-cyan-500/16 blur-[110px]" />
                <div className="absolute -top-28 right-[10%] h-[440px] w-[440px] rounded-full bg-blue-500/14 blur-[110px]" />

                {Array.from({ length: 70 }).map((_, i) => {
                  const left = Math.round(Math.random() * 100);
                  const size = 6 + Math.round(Math.random() * 10);
                  const delay = Math.random() * 0.6;
                  const dur = 1.8 + Math.random() * 1.4;
                  const drift = (Math.random() * 2 - 1) * 240;
                  const rot = (Math.random() * 2 - 1) * 540;
                  const palette = ["#f59e0b", "#f97316", "#22d3ee", "#3b82f6", "#a78bfa", "#34d399"];
                  const color = palette[i % palette.length];
                  return (
                    <motion.div
                      key={`p_${i}`}
                      className="absolute top-[-40px] rounded-sm"
                      style={{ left: `${left}%`, width: size, height: Math.max(6, Math.round(size * 0.6)), backgroundColor: color }}
                      initial={{ y: -60, x: 0, rotate: 0, opacity: 0 }}
                      animate={{ y: 980, x: drift, rotate: rot, opacity: [0, 1, 1, 0] }}
                      transition={{ delay, duration: dur, ease: "easeOut" }}
                    />
                  );
                })}
              </div>

              <div className="absolute inset-0 flex items-center justify-center p-4">
                <motion.div
                  aria-hidden
                  className="absolute h-[520px] w-[520px] rounded-full border border-amber-300/15"
                  style={{ filter: "drop-shadow(0 0 70px rgba(245,158,11,0.18))" }}
                  initial={{ opacity: 0, scale: 0.94, rotate: -15 }}
                  animate={{ opacity: 1, scale: 1, rotate: 345 }}
                  exit={{ opacity: 0, scale: 0.98 }}
                  transition={{ duration: 8, ease: "linear" }}
                />

                <motion.div
                  initial={{ y: 18, scale: 0.96, opacity: 0 }}
                  animate={{ y: 0, scale: 1, opacity: 1 }}
                  exit={{ y: 10, scale: 0.98, opacity: 0 }}
                  transition={{ type: "spring", stiffness: 220, damping: 18 }}
                  className="w-full max-w-xl overflow-hidden rounded-[28px] border border-white/10 bg-[var(--gf-shell-bg)] shadow-[0_30px_90px_rgba(0,0,0,0.75)]"
                  onClick={(e) => {
                    e.preventDefault();
                    e.stopPropagation();
                  }}
                >
                  <div className="relative p-7">
                    <div className="absolute inset-0 bg-[radial-gradient(circle_at_25%_20%,rgba(245,158,11,0.22),transparent_55%),radial-gradient(circle_at_70%_30%,rgba(34,211,238,0.16),transparent_55%),radial-gradient(circle_at_50%_90%,rgba(59,130,246,0.12),transparent_55%)]" />
                    <div className="relative">
                      <div className="inline-flex items-center gap-2 rounded-full border border-amber-300/30 bg-amber-500/10 px-3 py-1 text-[10px] font-black uppercase tracking-[0.24em] text-amber-100">
                        <Trophy size={12} className="text-amber-200" /> Tournament Finished
                      </div>
                      <div className="mt-4 text-3xl font-black tracking-tight text-[var(--foreground)]">Final Podium</div>
                      <div className="mt-2 text-sm text-zinc-300">Prizes are being credited now. You can view the final standings below.</div>

                      <div className="mt-5 grid grid-cols-3 gap-3">
                        {[2, 1, 3].map((rank) => {
                          const row = (detail?.top3 || []).find((r: any) => r.rank === rank);
                          const crown = rank === 1;
                          const me = authUserId.trim() && row?.playerId === authUserId.trim();
                          return (
                            <div
                              key={`pod_${rank}`}
                              className={`rounded-2xl border p-3 text-center ${
                                crown
                                  ? "border-amber-300/30 bg-amber-500/10"
                                  : rank === 2
                                    ? "border-blue-300/30 bg-blue-500/10"
                                    : "border-emerald-300/30 bg-emerald-500/10"
                              } ${me ? "ring-2 ring-cyan-300/30" : ""}`}
                            >
                              <div className="flex items-center justify-center gap-1.5">
                                {crown ? <Crown size={16} className="text-amber-200" /> : <Trophy size={14} className="text-white/80" />}
                                <span className="text-[10px] font-black uppercase tracking-widest text-white/80">#{rank}</span>
                              </div>
                              <div className="mt-2 text-xs font-black text-white truncate">{row?.playerName || "—"}</div>
                              <div className="mt-1 text-[11px] text-white/70 tabular-nums">{row ? row.score.toLocaleString() : "—"}</div>
                            </div>
                          );
                        })}
                      </div>

                      <div className="mt-5 grid grid-cols-2 gap-3">
                        <div className="rounded-2xl border border-white/10 bg-[var(--gf-panel-bg-strong)]/30 p-4">
                          <div className="text-[10px] font-black uppercase tracking-[0.22em] text-zinc-500">Your Rank</div>
                          <div className="mt-2 text-2xl font-black text-[var(--foreground)]">{myRank == null ? "—" : `#${myRank}`}</div>
                        </div>
                        <div className="rounded-2xl border border-white/10 bg-[var(--gf-panel-bg-strong)]/30 p-4">
                          <div className="text-[10px] font-black uppercase tracking-[0.22em] text-zinc-500">Your Prize</div>
                          <div className="mt-2 text-2xl font-black text-[var(--foreground)] tabular-nums">
                            {myTop3Row?.coinsWon != null ? myTop3Row.coinsWon.toLocaleString() : "—"}
                          </div>
                          <div className="text-[11px] text-zinc-400">coins</div>
                        </div>
                      </div>

                      <div className="mt-6 flex gap-3">
                        <button
                          onClick={() => router.replace(`/studio/tournaments/${encodeURIComponent(tournamentId)}`)}
                          className="flex-1 rounded-2xl border border-white/10 bg-white/5 px-5 py-3 text-xs font-black uppercase tracking-widest text-zinc-200 hover:bg-white/10"
                        >
                          View Details
                        </button>
                        <button
                          onClick={() => router.push("/studio/wallet")}
                          className="flex-[1.2] rounded-2xl border border-amber-300/30 bg-gradient-to-r from-amber-500/20 to-yellow-500/10 px-5 py-3 text-xs font-black uppercase tracking-widest text-amber-100 hover:brightness-110"
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

        <div className="flex flex-wrap items-center justify-between gap-2">
          <button
            onClick={() => router.push(`/studio/tournaments/${encodeURIComponent(tournamentId)}`)}
            className="rounded-2xl border border-white/10 bg-white/5 px-4 py-2 text-xs font-black uppercase tracking-widest text-zinc-200 flex items-center gap-2"
          >
            <ArrowLeft size={14} /> Back
          </button>

          <div className="flex flex-wrap items-center gap-2">
            <button
              onClick={() => setShareOpen(true)}
              className="inline-flex items-center gap-2 rounded-full border border-cyan-300/30 bg-gradient-to-r from-cyan-500/15 to-blue-500/10 px-3 py-1.5 text-[10px] font-black uppercase tracking-widest text-cyan-100 hover:brightness-110"
            >
              Share
            </button>
            <button
              onClick={async () => {
                try {
                  const url = window.location.href;
                  await navigator.clipboard.writeText(url);
                } catch {
                  // ignore
                }
              }}
              className="inline-flex items-center gap-2 rounded-full border border-white/10 bg-white/5 px-3 py-1.5 text-[10px] font-black uppercase tracking-widest text-zinc-200 hover:bg-white/10"
            >
              <Copy size={14} /> Copy link
            </button>

            <button
              onClick={() => {
                const el = iframeRef.current;
                const anyEl = el as any;
                const req = anyEl?.requestFullscreen || anyEl?.webkitRequestFullscreen || anyEl?.mozRequestFullScreen || anyEl?.msRequestFullscreen;
                try {
                  req?.call(anyEl);
                } catch {
                  // ignore
                }
              }}
              className="inline-flex items-center gap-2 rounded-full border border-white/10 bg-white/5 px-3 py-1.5 text-[10px] font-black uppercase tracking-widest text-zinc-200 hover:bg-white/10"
            >
              <Expand size={14} /> Fullscreen
            </button>

            {myRank != null ? (
              <div className="inline-flex items-center gap-2 rounded-full border border-cyan-300/30 bg-cyan-500/10 px-3 py-1.5">
                <Trophy size={14} className="text-cyan-200" />
                <span className="text-[10px] font-black uppercase tracking-widest text-cyan-100">You</span>
                <span className="text-sm font-black text-white">#{myRank}</span>
              </div>
            ) : null}

            {remaining ? (
              <div className={`inline-flex items-center gap-2 rounded-full border px-3 py-1.5 ${remaining.ms <= 60_000 ? "border-rose-400/30 bg-rose-500/10" : "border-white/10 bg-black/30"}`}>
                <Coins size={14} className={remaining.ms <= 60_000 ? "text-rose-300" : "text-amber-400"} />
                <span className="text-[10px] font-black uppercase tracking-widest text-zinc-400">Ends In</span>
                <span className="text-sm font-black text-white tabular-nums">{remaining.label}</span>
              </div>
            ) : null}

            <div className="inline-flex items-center gap-2 rounded-full border border-white/10 bg-black/30 px-3 py-1.5">
              <Trophy size={14} className="text-blue-300" />
              <span className="text-[10px] font-black uppercase tracking-widest text-zinc-400">Last</span>
              <span className="text-sm font-black text-white">{lastScore == null ? "—" : lastScore.toLocaleString()}</span>
              {lastDurationSec != null ? <span className="text-[11px] text-zinc-400">({lastDurationSec}s)</span> : null}
            </div>
            <div
              className={`inline-flex items-center gap-2 rounded-full border px-3 py-1.5 text-[10px] font-black uppercase tracking-widest ${
                submitBusy
                  ? "border-amber-400/30 bg-amber-500/10 text-amber-100"
                  : submitErr
                    ? "border-rose-500/30 bg-rose-500/10 text-rose-200"
                    : "border-emerald-500/30 bg-emerald-500/10 text-emerald-100"
              }`}
            >
              {submitBusy ? <Loader2 size={14} className="animate-spin" /> : submitErr ? <ShieldAlert size={14} /> : <CheckCircle2 size={14} />}
              {submitBusy ? "Submitting" : submitErr ? "Submit failed" : "Live"}
            </div>
            {submitErr ? (
              <div className="rounded-full border border-rose-500/30 bg-rose-500/10 px-3 py-1.5 text-[10px] font-black text-rose-200">
                {submitErr}
              </div>
            ) : null}
          </div>
        </div>

        <div className="grid grid-cols-1 gap-4 lg:grid-cols-12">
          <div className="lg:col-span-8 rounded-3xl border border-white/10 bg-[var(--gf-panel-bg-strong)]/25 overflow-hidden relative">
            <div className="border-b border-white/10 bg-gradient-to-r from-blue-500/10 via-cyan-500/10 to-black/10 px-4 py-3 flex items-center justify-between">
              <div className="text-[10px] font-black uppercase tracking-[0.22em] text-zinc-400 flex items-center gap-2">
                <Trophy size={12} className="text-blue-300" /> WebGL Arena
              </div>
              <div className="text-[10px] font-black uppercase tracking-[0.22em] text-zinc-500 flex items-center gap-2">
                <Coins size={12} className="text-amber-400" /> Scores auto-sync
              </div>
            </div>

            {timeProgressPct != null ? (
              <div className="px-4 py-3 border-b border-white/10">
                <div className="flex items-center justify-between gap-3">
                  <div className="text-[10px] font-black uppercase tracking-[0.22em] text-zinc-500">Tournament Progress</div>
                  <div className="text-[10px] font-black uppercase tracking-[0.22em] text-zinc-400 tabular-nums">{timeProgressPct}%</div>
                </div>
                <div className="mt-2 h-2 w-full rounded-full bg-white/10 overflow-hidden">
                  <div
                    className="h-full rounded-full bg-gradient-to-r from-emerald-400 via-cyan-400 to-blue-400"
                    style={{ width: `${timeProgressPct}%` }}
                  />
                </div>
              </div>
            ) : null}

            {loading ? (
              <div className="p-10 text-sm text-zinc-300 flex items-center gap-2">
                <Loader2 size={16} className="animate-spin" /> Loading runner…
              </div>
            ) : playUrl ? (
              <iframe
                ref={iframeRef}
                src={playUrl}
                className="h-[640px] w-full bg-black"
                allow="autoplay; fullscreen; gamepad"
                sandbox="allow-scripts allow-same-origin allow-pointer-lock allow-forms"
              />
            ) : (
              <div className="p-10 text-sm text-zinc-300">No runner URL available.</div>
            )}

            {!spectate && !joined ? (
              <div className="absolute inset-0 bg-black/70 backdrop-blur-sm flex items-center justify-center p-4">
                <div className="w-full max-w-md rounded-[28px] border border-cyan-400/20 bg-[var(--gf-bg)]/95 p-6 shadow-[0_32px_64px_rgba(0,0,0,0.75)]">
                  <div className="text-[10px] font-black uppercase tracking-[0.24em] text-cyan-100">Join Required</div>
                  <div className="mt-2 text-2xl font-black text-[var(--foreground)] tracking-tight">Enter the arena</div>
                  <div className="mt-2 text-sm text-zinc-300">
                    Join first to activate scoring and compete on the leaderboard.
                  </div>

                  <div className="mt-4 grid grid-cols-2 gap-3">
                    <div className="rounded-2xl border border-white/10 bg-[var(--gf-panel-bg-strong)]/30 p-3">
                      <div className="text-[10px] font-black uppercase tracking-[0.22em] text-zinc-400">Entry</div>
                      <div className="mt-1 text-lg font-black text-[var(--foreground)] flex items-center gap-1">
                        <Coins size={14} className="text-amber-400" /> {detail?.entryFee ?? 0}
                      </div>
                      <div className="text-[11px] text-zinc-500">coins</div>
                    </div>
                    <div className="rounded-2xl border border-white/10 bg-[var(--gf-panel-bg-strong)]/30 p-3">
                      <div className="text-[10px] font-black uppercase tracking-[0.22em] text-zinc-400">Pool</div>
                      <div className="mt-1 text-lg font-black text-[var(--foreground)] flex items-center gap-1">
                        <Trophy size={14} className="text-blue-300" /> {(detail?.prizePool ?? 0).toLocaleString()}
                      </div>
                      <div className="text-[11px] text-zinc-500">coins</div>
                    </div>
                  </div>

                  <div className="mt-4">
                    <label className="block text-[10px] font-black uppercase tracking-[0.22em] text-zinc-500">Nickname</label>
                    <input value={playerName} onChange={(e) => setPlayerName(e.target.value)} className="gf-input w-full rounded-2xl p-3 mt-2" />
                  </div>

                  {joinErr ? (
                    <div className="mt-3 rounded-xl border border-rose-500/30 bg-rose-500/10 px-4 py-3 text-sm text-rose-200">{joinErr}</div>
                  ) : null}

                  <div className="mt-4 flex gap-3">
                    <button
                      onClick={() => router.push(`/studio/tournaments/${encodeURIComponent(tournamentId)}`)}
                      className="flex-1 rounded-2xl border border-white/10 bg-white/5 px-4 py-3 text-xs font-black uppercase tracking-widest text-zinc-200 hover:bg-white/10"
                    >
                      Details
                    </button>
                    <button
                      onClick={joinNow}
                      disabled={joining}
                      className="flex-[2] rounded-2xl border border-cyan-300/30 bg-gradient-to-r from-cyan-500/20 to-blue-500/20 px-4 py-3 text-xs font-black uppercase tracking-widest text-cyan-100 disabled:opacity-60 flex items-center justify-center gap-2"
                    >
                      {joining ? <Loader2 size={16} className="animate-spin" /> : <UserPlus size={16} />}
                      Join & Play
                    </button>
                  </div>
                </div>
              </div>
            ) : null}
          </div>

          <div className="lg:col-span-4 space-y-4">
            {rankToast ? (
              <div
                className={`rounded-3xl border px-4 py-3 text-sm font-black uppercase tracking-widest ${
                  rankToast.kind === "up"
                    ? "border-emerald-400/25 bg-emerald-500/10 text-emerald-100"
                    : "border-rose-400/25 bg-rose-500/10 text-rose-200"
                }`}
              >
                {rankToast.kind === "up" ? "Rank Up" : "Rank Down"} • #{rankToast.from} → #{rankToast.to}
              </div>
            ) : null}

            <div className="rounded-3xl border border-white/10 bg-black/25 overflow-hidden">
              <div className="border-b border-white/10 bg-white/5 px-4 py-3 flex items-center justify-between">
                <div className="text-[10px] font-black uppercase tracking-[0.22em] text-zinc-400">Top 3 Podium</div>
                <div className="text-[10px] font-black uppercase tracking-[0.22em] text-zinc-500">Auto-payout</div>
              </div>
              <div className="p-4">
                {((detail?.top3 || []).length === 0) ? (
                  <div className="rounded-2xl border border-white/10 bg-black/20 p-4 text-sm text-zinc-400 flex items-center gap-2">
                    <ShieldAlert size={16} /> No podium yet.
                  </div>
                ) : (
                  <div className="grid grid-cols-3 gap-3">
                    {[2, 1, 3].map((rank) => {
                      const row = (detail?.top3 || []).find((r) => r.rank === rank);
                      const crown = rank === 1;
                      return (
                        <div
                          key={rank}
                          className={`rounded-2xl border p-3 text-center ${
                            crown
                              ? "border-amber-300/30 bg-amber-500/10"
                              : rank === 2
                                ? "border-blue-300/30 bg-blue-500/10"
                                : "border-emerald-300/30 bg-emerald-500/10"
                          }`}
                        >
                          <div className="flex items-center justify-center gap-1.5">
                            {crown ? <Crown size={16} className="text-amber-200" /> : <Trophy size={14} className="text-white/80" />}
                            <span className="text-[10px] font-black uppercase tracking-widest text-white/80">#{rank}</span>
                          </div>
                          <div className="mt-2 text-xs font-black text-white truncate">{row?.playerName || "—"}</div>
                          <div className="mt-1 text-[11px] text-white/70 tabular-nums">{row ? row.score.toLocaleString() : "—"}</div>
                        </div>
                      );
                    })}
                  </div>
                )}
              </div>
            </div>

            <div className="rounded-3xl border border-white/10 bg-black/25 overflow-hidden">
              <div className="border-b border-white/10 bg-white/5 px-4 py-3 flex items-center justify-between">
                <div className="text-[10px] font-black uppercase tracking-[0.22em] text-zinc-400">Live Leaderboard</div>
                <div className="text-[10px] font-black uppercase tracking-[0.22em] text-zinc-500 flex items-center gap-2">
                  <Users size={12} /> {(detail?.playersCount ?? 0).toLocaleString()}
                </div>
              </div>

              <div className="p-4">
                {(detail?.leaderboardTop || []).length === 0 ? (
                  <div className="rounded-2xl border border-white/10 bg-black/20 p-4 text-sm text-zinc-400 flex items-center gap-2">
                    <ShieldAlert size={16} /> No scores yet.
                  </div>
                ) : (
                  <div className="space-y-2">
                    {(detail?.leaderboardTop || []).slice(0, 10).map((r) => {
                      const me = authUserId.trim() && r.playerId === authUserId.trim();
                      return (
                        <div
                          key={`${r.playerId}_${r.rank}`}
                          className={`rounded-2xl border px-3 py-2 flex items-center gap-3 ${
                            me
                              ? "border-cyan-300/30 bg-cyan-500/10"
                              : r.rank === 1
                                ? "border-amber-300/25 bg-amber-500/10"
                                : "border-white/10 bg-white/5"
                          }`}
                        >
                          <div className={`h-9 w-9 rounded-2xl flex items-center justify-center border ${r.rank === 1 ? "border-amber-300/30 bg-amber-500/10 text-amber-200" : "border-white/10 bg-black/20 text-zinc-200"}`}>
                            {r.rank === 1 ? <Crown size={16} /> : <span className="text-sm font-black">{r.rank}</span>}
                          </div>
                          <div className="min-w-0 flex-1">
                            <div className="text-sm font-black text-white truncate">{r.playerName}</div>
                            <div className="text-[11px] text-zinc-500 truncate">{r.playerId}</div>
                          </div>
                          <div className="text-right">
                            <div className="text-sm font-black text-white">{r.score.toLocaleString()}</div>
                            <div className="text-[11px] text-zinc-500">score</div>
                          </div>
                        </div>
                      );
                    })}
                  </div>
                )}
              </div>
            </div>

            <div className="rounded-3xl border border-white/10 bg-black/25 p-4">
              <div className="text-[10px] font-black uppercase tracking-[0.22em] text-zinc-400">Scoring</div>
              <div className="mt-2 text-sm text-zinc-200 font-semibold">Score events are captured in real-time and submitted automatically.</div>
              <div className="mt-2 text-xs text-zinc-500">
                Iframe messages: {iframeMsgCount}
                {lastIframeMsgType ? ` • last type: ${lastIframeMsgType}` : ""}
                {lastIframeMsgAt ? ` • last: ${new Date(lastIframeMsgAt).toLocaleTimeString()}` : ""}
              </div>
              <div className="mt-3 rounded-2xl border border-white/10 bg-black/20 p-3">
                <div className="text-[10px] font-black uppercase tracking-[0.22em] text-zinc-500">Last capture</div>
                <div className="mt-1 text-sm font-black text-white">{lastScore == null ? "—" : lastScore.toLocaleString()}</div>
                <div className="mt-1 text-xs text-zinc-500">{lastDurationSec != null ? `${lastDurationSec}s run` : ""}</div>
              </div>

              {!spectate && joined ? (
                <div className="mt-3 rounded-2xl border border-white/10 bg-black/20 p-3">
                  <div className="text-[10px] font-black uppercase tracking-[0.22em] text-zinc-500">Manual submit (fallback)</div>
                  <div className="mt-2 grid grid-cols-2 gap-2">
                    <input
                      value={manualScore}
                      onChange={(e) => setManualScore(e.target.value)}
                      placeholder="Score"
                      inputMode="numeric"
                      className="h-10 rounded-xl border border-white/10 bg-black/30 px-3 text-sm text-white placeholder:text-zinc-600 outline-none focus:border-cyan-400/40"
                    />
                    <input
                      value={manualDurationSec}
                      onChange={(e) => setManualDurationSec(e.target.value)}
                      placeholder="Duration (sec)"
                      inputMode="numeric"
                      className="h-10 rounded-xl border border-white/10 bg-black/30 px-3 text-sm text-white placeholder:text-zinc-600 outline-none focus:border-cyan-400/40"
                    />
                  </div>
                  <button
                    disabled={submitBusy}
                    onClick={() => {
                      const score = Math.max(0, Math.trunc(Number(manualScore || 0)));
                      const durationSec = Math.max(1, Math.trunc(Number(manualDurationSec || 1)));
                      const finalRunId = `manual_${Date.now().toString(36)}_${Math.random().toString(16).slice(2)}`;
                      let stableDeviceId = "";
                      try {
                        const key = "gf:tournament:deviceId";
                        stableDeviceId = window.localStorage.getItem(key) || "";
                        if (!stableDeviceId) {
                          stableDeviceId = `web_${Math.random().toString(16).slice(2)}_${Date.now().toString(16)}`;
                          window.localStorage.setItem(key, stableDeviceId);
                        }
                      } catch {
                        stableDeviceId = "web";
                      }

                      setLastScore(score);
                      setLastDurationSec(durationSec);
                      setSubmitErr(null);
                      setSubmitBusy(true);
                      apiFetch("/platform-labs/tournaments/submit-score", {
                        method: "POST",
                        token: token || undefined,
                        body: {
                          tournamentId,
                          playerId: authUserId.trim(),
                          score,
                          durationSec,
                          runId: finalRunId,
                          deviceId: stableDeviceId,
                          clientTimeMs: Date.now(),
                        },
                      })
                        .catch((e: any) => {
                          const msg = e instanceof ApiError ? e.message : e?.message || "Score submit failed";
                          setSubmitErr(msg);
                        })
                        .finally(() => {
                          setSubmitBusy(false);
                        });
                    }}
                    className="mt-2 h-10 w-full rounded-xl border border-cyan-300/30 bg-cyan-500/10 text-xs font-black uppercase tracking-widest text-cyan-100 hover:brightness-110 disabled:opacity-60"
                  >
                    Submit score
                  </button>
                </div>
              ) : null}
            </div>
          </div>
        </div>
      </div>

      <TournamentShareModal open={shareOpen} onClose={() => setShareOpen(false)} tournamentId={tournamentId} />
    </UserShell>
  );
}
