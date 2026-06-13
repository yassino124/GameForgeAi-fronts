"use client";

import { useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import UserShell from "@/app/_components/UserShell";
import { apiFetch, ApiError } from "@/lib/api";
import { useLabsContext } from "../_lib/useLabsContext";
import { ContextMediaCard, WowHero } from "../_components/WowVisual";
import { Crown, Medal, Trophy, Coins, Timer, Users, Plus, Play, Flag, Sparkles, Flame, ShieldAlert, Activity, CreditCard, CheckCircle2, AlertCircle, X, ShieldCheck, Lock } from "lucide-react";
import confetti from "canvas-confetti";
import { motion, AnimatePresence } from "framer-motion";

type LeaderboardRow = {
  playerId: string;
  playerName?: string;
  score: number;
  cheatFlag?: boolean;
  rank?: number;
  coinsWon?: number;
};

type ToastKind = "success" | "error" | "info";

type ToastItem = {
  id: string;
  kind: ToastKind;
  title: string;
  message?: string;
};

type TournamentCard = {
  id: string;
  gameId?: string;
  title: string;
  status: "waiting" | "active" | "finished";
  entryFee: number;
  prizePool: number;
  playersCount: number;
  maxPlayers: number;
  startsAt: number;
  endsAt: number;
  coverImageUrl?: string;
  top3: LeaderboardRow[];
};

type TournamentNotification = {
  id: string;
  type: "info" | "success" | "warning";
  message: string;
  createdAt: number;
};

type TournamentDetail = TournamentCard & {
  leaderboardTop: LeaderboardRow[];
};

type WalletResponse = {
  userId: string;
  coins: number;
};

type ConnectStatus = {
  userId: string;
  connected: boolean;
  accountId: string | null;
  detailsSubmitted: boolean;
  payoutsEnabled: boolean;
};

type CashoutRow = {
  requestId: string;
  amountUsdCents: number;
  currency: string;
  status: "requested" | "processing" | "succeeded" | "failed";
  stripePayoutId?: string | null;
  failureReason?: string | null;
  createdAt: number;
};

type TournamentSystemConfig = {
  demoMode: boolean;
  stripeConfigured: boolean;
  stripeConnectConfigured: boolean;
  mongoConnected: boolean;
};

function asNum(value: unknown, fallback = 0): number {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string") {
    const n = Number(value);
    if (Number.isFinite(n)) return n;
  }
  return fallback;
}

function asStr(value: unknown, fallback = ""): string {
  return typeof value === "string" ? value : fallback;
}

function toastTone(kind: ToastKind) {
  if (kind === "success") return "border-emerald-400/30 bg-emerald-500/15 text-emerald-100";
  if (kind === "error") return "border-rose-400/30 bg-rose-500/15 text-rose-100";
  return "border-blue-400/30 bg-blue-500/15 text-blue-100";
}

function notificationTone(type: TournamentNotification["type"]) {
  if (type === "success") return "border-emerald-400/25 bg-emerald-500/10 text-emerald-100";
  if (type === "warning") return "border-amber-400/25 bg-amber-500/10 text-amber-100";
  return "border-blue-400/25 bg-blue-500/10 text-blue-100";
}

function normalizeLeaderboard(rows: unknown): LeaderboardRow[] {
  if (!Array.isArray(rows)) return [];
  return rows
    .filter((x) => x && typeof x === "object")
    .map((rowRaw, idx) => {
      const row = rowRaw as Record<string, unknown>;
      return {
        playerId: asStr(row.playerId, `player_${idx + 1}`),
        playerName: asStr(row.playerName || row.playerId || `Player ${idx + 1}`),
        score: asNum(row.score, 0),
        cheatFlag: Boolean(row.cheatFlag),
        rank: asNum(row.rank, idx + 1),
        coinsWon: asNum(row.coinsWon, 0),
      };
    });
}

function normalizeTournamentCard(raw: unknown): TournamentCard | null {
  if (!raw || typeof raw !== "object") return null;
  const obj = raw as Record<string, unknown>;
  const id = asStr(obj.id || obj["_id"]);
  if (!id) return null;
  const normalizedStatusRaw = asStr(obj.status, "waiting").toLowerCase();
  const normalizedStatus: TournamentCard["status"] =
    normalizedStatusRaw === "active" || normalizedStatusRaw === "finished" ? normalizedStatusRaw : "waiting";
  return {
    id,
    gameId: asStr(obj.gameId) || undefined,
    title: asStr(obj.title, "Weekly Challenge"),
    status: normalizedStatus,
    entryFee: asNum(obj.entryFee, 100),
    prizePool: asNum(obj.prizePool, 0),
    playersCount: asNum(obj.playersCount, 0),
    maxPlayers: asNum(obj.maxPlayers, 20),
    startsAt: asNum(obj.startsAt, Date.now()),
    endsAt: asNum(obj.endsAt, Date.now() + 60 * 60 * 1000),
    coverImageUrl: asStr(obj.coverImageUrl) || undefined,
    top3: normalizeLeaderboard(obj.top3),
  };
}

function normalizeTournamentDetail(raw: unknown): TournamentDetail | null {
  const base = normalizeTournamentCard(raw);
  if (!base || !raw || typeof raw !== "object") return null;
  const obj = raw as Record<string, unknown>;
  return {
    ...base,
    leaderboardTop: normalizeLeaderboard(obj.leaderboardTop),
  };
}

function statusTone(status?: TournamentCard["status"]) {
  if (status === "active") return "text-emerald-200 border-emerald-300/40 bg-emerald-500/15";
  if (status === "finished") return "text-zinc-200 border-zinc-300/30 bg-zinc-500/15";
  return "text-amber-200 border-amber-300/40 bg-amber-500/15";
}

export default function TournamentsModulePage() {
  const router = useRouter();
  const { token, projects, selectedProject, selectedProjectId, setSelectedProjectId } = useLabsContext({
    withProjects: true,
    withTemplates: false,
  });

  const [showProjectPicker, setShowProjectPicker] = useState(false);
  const [projectQuery, setProjectQuery] = useState("");
  const filteredProjects = useMemo(() => {
    const q = projectQuery.trim().toLowerCase();
    if (!q) return projects;
    return projects.filter((p) => {
      const name = String(p?.name || "").toLowerCase();
      const desc = String((p as any)?.description || "").toLowerCase();
      return name.includes(q) || desc.includes(q) || String(p?.id || "").toLowerCase().includes(q);
    });
  }, [projects, projectQuery]);

  const [tab, setTab] = useState<"active" | "upcoming" | "past">("active");
  const [showJoinedOnly, setShowJoinedOnly] = useState(false);
  const [loading, setLoading] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [playerId, setPlayerId] = useState("Falcon42");
  const [authUserId, setAuthUserId] = useState("");
  const [wallet, setWallet] = useState(5000);
  const [connect, setConnect] = useState<ConnectStatus | null>(null);
  const [cashouts, setCashouts] = useState<CashoutRow[]>([]);
  const [cashoutUsd, setCashoutUsd] = useState(5);
  const runScore = 1200;
  const runDuration = 180;
  const [joinCode, setJoinCode] = useState("");
  const [cards, setCards] = useState<TournamentCard[]>([]);
  const [selectedTournamentId, setSelectedTournamentId] = useState("");
  const [detail, setDetail] = useState<TournamentDetail | null>(null);
  const [notifications, setNotifications] = useState<TournamentNotification[]>([]);
  const [toasts, setToasts] = useState<ToastItem[]>([]);
  const [live, setLive] = useState(false);
  const [showRoulette, setShowRoulette] = useState(false);
  const [rouletteItems, setRouletteItems] = useState<string[]>([]);
  const [spinning, setSpinning] = useState(false);
  const [prizeWinner, setPrizeWinner] = useState<string | null>(null);
  const [shakeScreen, setShakeScreen] = useState(false);
  const [showPaymentModal, setShowPaymentModal] = useState(false);
  const [paymentStep, setPaymentStep] = useState<"input" | "processing" | "success">("input");
  const [topUpAmount, setTopUpAmount] = useState(49);
  const [systemConfig, setSystemConfig] = useState<TournamentSystemConfig | null>(null);

  function pushToast(t: Omit<ToastItem, "id">) {
    const id = `toast_${Date.now()}_${Math.random().toString(16).slice(2)}`;
    const item: ToastItem = { id, ...t };
    setToasts((prev) => [item, ...prev].slice(0, 4));
    window.setTimeout(() => {
      setToasts((prev) => prev.filter((x) => x.id !== id));
    }, 3200);
  }

  const statusQuery = tab === "active" ? "active" : tab === "upcoming" ? "waiting" : "finished";
  const spotlight = useMemo(() => cards.find((x) => x.id === selectedTournamentId) || cards[0] || null, [cards, selectedTournamentId]);
  const displayLeaderboard = detail?.leaderboardTop || spotlight?.top3 || [];
  const joinedRatio = spotlight ? Math.max(0, Math.min(100, Math.round((spotlight.playersCount / Math.max(1, spotlight.maxPlayers)) * 100))) : 0;
  const countdownMs = spotlight ? Math.max(0, spotlight.endsAt - Date.now()) : 0;
  const countdownMinutes = Math.floor(countdownMs / 60000);
  const countdownHours = Math.floor(countdownMinutes / 60);
  const countdownRemainderMin = countdownMinutes % 60;

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

  const prizeFirst = Math.trunc((spotlight?.prizePool || 0) * 0.7);
  const prizeSecond = Math.trunc((spotlight?.prizePool || 0) * 0.2);
  const prizeThird = Math.max(0, (spotlight?.prizePool || 0) - prizeFirst - prizeSecond);

  async function loadWallet() {
    if (!authUserId.trim()) return;
    const data = await apiFetch<WalletResponse>(`/platform-labs/tournaments/wallet/${encodeURIComponent(authUserId.trim())}`, {
      method: "GET",
      token: token || undefined,
    });
    setWallet(asNum(data?.coins, 0));
  }

  async function loadConnectStatus() {
    if (!authUserId.trim()) return;
    try {
      const data = await apiFetch<ConnectStatus>(`/platform-labs/tournaments/connect/status/${encodeURIComponent(authUserId.trim())}`, {
        method: "GET",
        token: token || undefined,
      });
      setConnect(data);
    } catch {
      setConnect(null);
    }
  }

  async function loadCashouts() {
    if (!authUserId.trim()) return;
    try {
      const data = await apiFetch<CashoutRow[]>(`/platform-labs/tournaments/cashout/${encodeURIComponent(authUserId.trim())}`, {
        method: "GET",
        token: token || undefined,
      });
      setCashouts(Array.isArray(data) ? data : []);
    } catch {
      setCashouts([]);
    }
  }

  async function loadSystemConfig() {
    try {
      const data = await apiFetch<TournamentSystemConfig>("/platform-labs/tournaments/system/config", {
        method: "GET",
        token: token || undefined,
      });
      setSystemConfig(data);
    } catch {
      setSystemConfig(null);
    }
  }

  async function loadDetail(tournamentId: string) {
    const d = await apiFetch<unknown>(`/platform-labs/tournaments/${encodeURIComponent(tournamentId)}`, {
      method: "GET",
      token: token || undefined,
    });
    setDetail(normalizeTournamentDetail(d));

    try {
      const n = await apiFetch<unknown>(`/platform-labs/tournaments/${encodeURIComponent(tournamentId)}/notifications`, {
        method: "GET",
        token: token || undefined,
      });
      setNotifications(
        Array.isArray(n)
          ? n
              .filter((x) => x && typeof x === "object")
              .map((itRaw, idx) => {
                const it = itRaw as Record<string, unknown>;
                return {
                id: asStr(it.id, `n_${idx}`),
                type: ((asStr(it.type, "info") as TournamentNotification["type"]) || "info"),
                message: asStr(it.message, "Notification"),
                createdAt: asNum(it.createdAt, Date.now()),
                };
              })
          : [],
      );
    } catch {
      setNotifications([]);
    }
  }

  async function loadTournaments(nextTab?: "active" | "upcoming" | "past", joinedOnly = showJoinedOnly) {
    const status = nextTab ? (nextTab === "active" ? "active" : nextTab === "upcoming" ? "waiting" : "finished") : statusQuery;
    const userFilter = joinedOnly && authUserId.trim() ? `&userId=${encodeURIComponent(authUserId.trim())}` : "";
    const data = await apiFetch<unknown>(`/platform-labs/tournaments?status=${status}${userFilter}`, {
      method: "GET",
      token: token || undefined,
    });

    const next = Array.isArray(data) ? data.map(normalizeTournamentCard).filter((x): x is TournamentCard => Boolean(x)) : [];
    setCards(next);
    const first = next[0];
    if (first) {
      setSelectedTournamentId(first.id);
      await loadDetail(first.id);
    } else {
      setSelectedTournamentId("");
      setDetail(null);
      setNotifications([]);
    }
  }

  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        setLoading("boot");
  await loadSystemConfig();
        await loadWallet();
        await loadConnectStatus();
        await loadCashouts();
        if (!cancelled) await loadTournaments(tab, showJoinedOnly);
      } catch (e: unknown) {
        const msg = e instanceof ApiError ? e.message : e instanceof Error ? e.message : "Failed to load tournaments";
        if (!cancelled) setError(msg);
      } finally {
        if (!cancelled) setLoading(null);
      }
    })();
    return () => {
      cancelled = true;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    // refresh wallet/connect when player changes
    let cancelled = false;
    (async () => {
      try {
        setError(null);
  await loadSystemConfig();
        await loadWallet();
        await loadConnectStatus();
        await loadCashouts();
        await loadTournaments(tab, showJoinedOnly);
      } catch (e: unknown) {
        const msg = e instanceof ApiError ? e.message : e instanceof Error ? e.message : "Failed to refresh player wallet";
        if (!cancelled) setError(msg);
      }
    })();
    return () => {
      cancelled = true;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [authUserId]);

  useEffect(() => {
    (async () => {
      try {
        setError(null);
        setLoading("tab");
        await loadTournaments(tab, showJoinedOnly);
      } catch (e: unknown) {
        const msg = e instanceof ApiError ? e.message : e instanceof Error ? e.message : "Failed to switch tab";
        setError(msg);
      } finally {
        setLoading(null);
      }
    })();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [tab, showJoinedOnly]);

  useEffect(() => {
    if (!spotlight?.id) return;
    const timer = setInterval(() => {
      void loadDetail(spotlight.id);
      void loadTournaments(tab);
    }, 12000);
    return () => clearInterval(timer);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [spotlight?.id, tab]);

  useEffect(() => {
    if (!spotlight?.id) return;
    const tid = spotlight.id;
    const base = (process.env.NEXT_PUBLIC_API_BASE_URL || "").trim();
    const url = `${base.replace(/\/$/, "")}/platform-labs/tournaments/events/stream?tournamentId=${encodeURIComponent(tid)}`;

    let es: EventSource | null = null;
    let stopped = false;
    try {
      es = new EventSource(url);
      setLive(true);
      es.addEventListener("hello", () => {
        setLive(true);
      });
      es.addEventListener("evt", (evt) => {
        if (stopped) return;
        try {
          const data = JSON.parse(String((evt as MessageEvent).data || "{}")) as TournamentNotification;
          if (!data?.id) return;
          setNotifications((prev) => {
            const next = [data, ...prev].slice(0, 25);
            const seen = new Set<string>();
            return next.filter((x) => {
              if (!x?.id) return false;
              if (seen.has(x.id)) return false;
              seen.add(x.id);
              return true;
            });
          });
          if (data.type === "warning") {
            triggerShake();
            pushToast({ kind: "info", title: "Anti-cheat", message: data.message });
          }
        } catch {
          // ignore
        }
      });
      es.onerror = () => {
        setLive(false);
      };
    } catch {
      setLive(false);
    }

    return () => {
      stopped = true;
      try {
        es?.close();
      } catch {
        // ignore
      }
      setLive(false);
    };
  }, [spotlight?.id]);

  async function createTournament() {
    setLoading("create");
    setError(null);
    try {
      if (!playerId.trim()) {
        setError("Enter player nickname before creating a tournament.");
        return;
      }
      if (!selectedProjectId) {
        setError("Choose a project first.");
        return;
      }

      const createdRaw = await apiFetch<unknown>("/platform-labs/tournaments/create", {
        method: "POST",
        token: token || undefined,
        body: {
          creatorId: authUserId.trim() || playerId.trim(),
          gameId: selectedProjectId,
          title: `${selectedProject?.name || "Project"} Weekly Challenge`,
          mode: "score-run",
          seasonId: `season_${new Date().getFullYear()}_spring`,
          entryFee: 100,
          maxPlayers: 32,
          coverImageUrl: selectedProject?.previewImageUrl,
        },
      });
      const created = normalizeTournamentCard(createdRaw);
      if (!created) {
        setError("Backend returned invalid tournament data.");
        return;
      }

      setSelectedTournamentId(created.id);
      setTab("upcoming");
  await loadTournaments("upcoming", showJoinedOnly);
      pushToast({ kind: "success", title: "Tournament Created", message: created.title });
    } catch (e: unknown) {
      const msg = e instanceof ApiError ? e.message : e instanceof Error ? e.message : "Create tournament failed";
      setError(msg);
      pushToast({ kind: "error", title: "Create Failed", message: msg });
    } finally {
      setLoading(null);
    }
  }

  async function joinSpotlight() {
    if (!spotlight) return;
    if (!authUserId.trim()) {
      pushToast({ kind: "error", title: "Sign in required", message: "Please sign in before joining." });
      return;
    }
    setLoading("join");
    setError(null);
    try {
      await apiFetch("/platform-labs/tournaments/join", {
        method: "POST",
        token: token || undefined,
        body: {
          tournamentId: spotlight.id,
          userId: authUserId.trim(),
          playerName: playerId.trim(),
          initialBalance: 5000,
        },
      });
      await loadWallet();
      await loadDetail(spotlight.id);
  await loadTournaments(tab, showJoinedOnly);
      pushToast({ kind: "success", title: "Joined Arena", message: `You joined ${spotlight.title}` });
    } catch (e: unknown) {
      const msg = e instanceof ApiError ? e.message : e instanceof Error ? e.message : "Join tournament failed";
      setError(msg);
      pushToast({ kind: "error", title: "Join Failed", message: msg });
    } finally {
      setLoading(null);
    }
  }

  async function playRun() {
    if (!spotlight) return;
    const gameId = (detail?.gameId || spotlight.gameId || "").trim();
    if (!gameId) {
      pushToast({ kind: "error", title: "Game Missing", message: "This tournament has no linked game yet." });
      return;
    }

    router.push(`/studio/projects/${encodeURIComponent(gameId)}?tournamentId=${encodeURIComponent(spotlight.id)}`);
  }

  function triggerShake() {
    setShakeScreen(true);
    setTimeout(() => setShakeScreen(false), 500);
  }

  function startRoulette() {
    if (!spotlight || spinning) return;
    const players = detail?.leaderboardTop?.map((p) => p.playerName || p.playerId) || [];
    if (players.length === 0) return;

    setRouletteItems(players);
    setShowRoulette(true);
    setSpinning(true);
    setPrizeWinner(null);

    setTimeout(() => {
      setSpinning(false);
      setPrizeWinner(players[0] || "No Winner");
      triggerShake();
      void confetti({
        particleCount: 250,
        spread: 120,
        origin: { y: 0.4 },
        colors: ["#fbbf24", "#ffffff", "#6366f1", "#a855f7"],
        scalar: 1.2,
      });
    }, 4500);
  }

  async function finishCurrentTournament() {
    if (!spotlight) return;
    setLoading("finish");
    setError(null);
    try {
      await apiFetch(`/platform-labs/tournaments/${encodeURIComponent(spotlight.id)}/finish`, {
        method: "POST",
        token: token || undefined,
      });
      setTab("past");
      await loadTournaments("past", showJoinedOnly);
      await loadWallet();
      await loadCashouts();
      pushToast({ kind: "success", title: "Tournament Finished", message: spotlight.title });

      startRoulette();
    } catch (e: unknown) {
      const msg = e instanceof ApiError ? e.message : e instanceof Error ? e.message : "Finish tournament failed";
      setError(msg);
      pushToast({ kind: "error", title: "Finish Failed", message: msg });
    } finally {
      setLoading(null);
    }
  }

  async function requestCashout() {
    if (!connect?.payoutsEnabled) {
      pushToast({ kind: "error", title: "Stripe Not Ready", message: "Complete Stripe onboarding before requesting cash-out." });
      return;
    }
    if (!authUserId.trim()) {
      pushToast({ kind: "error", title: "Sign in required", message: "Please sign in before requesting cash-out." });
      return;
    }
    setLoading("cashout");
    setError(null);
    try {
      const amountUsdCents = Math.max(1, Math.trunc(Number(cashoutUsd || 0) * 100));
      const requestId = `cash_${authUserId.trim()}_${Date.now()}`;
      await apiFetch("/platform-labs/tournaments/cashout/request", {
        method: "POST",
        token: token || undefined,
        body: {
          userId: authUserId.trim(),
          amountUsdCents,
          requestId,
        },
      });
      await loadCashouts();
      pushToast({ kind: "success", title: "Cash-out Requested", message: `$${Number(cashoutUsd || 0).toFixed(0)} sent to Stripe` });
    } catch (e: unknown) {
      const msg = e instanceof ApiError ? e.message : e instanceof Error ? e.message : "Cash-out failed";
      setError(msg);
      pushToast({ kind: "error", title: "Cash-out Failed", message: msg });
    } finally {
      setLoading(null);
    }
  }

  async function startStripeOnboarding() {
    setLoading("connect");
    setError(null);
    try {
      if (!authUserId.trim()) throw new Error("Please sign in before connecting Stripe");
      const data = await apiFetch<{ url: string; accountId: string }>("/platform-labs/tournaments/connect/onboarding-link", {
        method: "POST",
        token: token || undefined,
        body: { userId: authUserId.trim() },
      });
      await loadConnectStatus();
      if (data?.url) {
        window.open(data.url, "_blank", "noopener,noreferrer");
      }
      pushToast({ kind: "info", title: "Stripe Onboarding", message: "Complete onboarding then refresh status." });
    } catch (e: unknown) {
      const msg = e instanceof ApiError ? e.message : e instanceof Error ? e.message : "Stripe onboarding failed";
      setError(msg);
      pushToast({ kind: "error", title: "Stripe Failed", message: msg });
    } finally {
      setLoading(null);
    }
  }

  async function simulateTopUp() {
    if (topUpAmount <= 0) {
      pushToast({ kind: "error", title: "Invalid Amount", message: "Please enter a valid amount" });
      return;
    }
    if (!authUserId.trim()) {
      pushToast({ kind: "error", title: "Sign in required", message: "Please sign in before topping up." });
      return;
    }
    setPaymentStep("processing");
    setTimeout(async () => {
      try {
        if (systemConfig?.demoMode) {
          await apiFetch("/platform-labs/tournaments/wallet/top-up", {
            method: "POST",
            token: token || undefined,
            body: { userId: authUserId.trim(), amountUsd: topUpAmount },
          });
          await loadWallet();
          setPaymentStep("success");
          void confetti({ particleCount: 150, spread: 80, origin: { y: 0.6 }, colors: ["#6366f1", "#10b981", "#fbbf24"] });
          return;
        }

        const base = window.location.origin;
        const successUrl = `${base}/studio/wow-labs/tournaments?topup=success`;
        const cancelUrl = `${base}/studio/wow-labs/tournaments?topup=cancel`;
        const data = await apiFetch<{ url?: string }>("/platform-labs/tournaments/wallet/top-up/checkout", {
          method: "POST",
          token: token || undefined,
          body: {
            userId: authUserId.trim(),
            amountUsd: topUpAmount,
            successUrl,
            cancelUrl,
          },
        });

        if (data?.url) {
          window.location.href = data.url;
          return;
        }

        throw new Error("Stripe checkout URL was not returned.");
      } catch (e: unknown) {
        const msg = e instanceof ApiError ? e.message : e instanceof Error ? e.message : "Top-up failed";
        setError(msg);
        setPaymentStep("input");
        pushToast({ kind: "error", title: "Top-up Failed", message: msg });
      }
    }, 1800);
  }

  useEffect(() => {
    const params = new URLSearchParams(window.location.search);
    const topup = params.get("topup");
    if (topup === "success") {
      void loadWallet();
      pushToast({ kind: "success", title: "Top-up Success", message: "Wallet charged from Stripe payment." });
    } else if (topup === "cancel") {
      pushToast({ kind: "info", title: "Payment Canceled", message: "Stripe top-up was canceled." });
    } else if (topup === "open") {
      setPaymentStep("input");
      setShowPaymentModal(true);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  return (
    <UserShell title="Elite Challenge Hub" subtitle="Real-time arena monitoring with advanced anti-cheat & automated payouts">
      <motion.div animate={shakeScreen ? { x: [-5, 5, -5, 5, 0], y: [-2, 2, -2, 2, 0] } : {}} transition={{ duration: 0.4 }} className="relative z-0">
        {/* Pro Dashboard Motion Toast System */}
      <div className="pointer-events-none fixed right-6 top-20 z-50 flex w-[380px] flex-col gap-3 overflow-hidden">
        <AnimatePresence>
          {toasts.map((t) => (
            <motion.div
              key={t.id}
              initial={{ x: 400, opacity: 0, scale: 0.9 }}
              animate={{ x: 0, opacity: 1, scale: 1 }}
              exit={{ x: 400, opacity: 0, scale: 0.9 }}
              className={`pointer-events-auto flex items-start gap-3 rounded-2xl border p-4 shadow-[0_22px_48px_rgba(0,0,0,0.6)] backdrop-blur-xl ${toastTone(
                t.kind,
              )}`}
            >
              <div className="mt-0.5">
                {t.kind === "success" ? <CheckCircle2 size={18} /> : t.kind === "error" ? <AlertCircle size={18} /> : <Activity size={18} />}
              </div>
              <div className="flex-1">
                <div className="text-[11px] font-black uppercase tracking-[0.2em] leading-none opacity-80">{t.title}</div>
                {t.message ? <div className="mt-1.5 text-[13px] font-bold text-white/95 leading-snug">{t.message}</div> : null}
              </div>
            </motion.div>
          ))}
        </AnimatePresence>
      </div>

      {/* 3D Roulette / Winner Decider Overlay */}
      <AnimatePresence>
        {showRoulette && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 z-[60] flex items-center justify-center bg-black/80 backdrop-blur-md"
          >
            <motion.div
              initial={{ scale: 0, rotate: -180 }}
              animate={{ scale: 1, rotate: 0 }}
              exit={{ scale: 0, rotate: 180 }}
              transition={{ type: "spring", damping: 20, stiffness: 100 }}
              className="relative h-[550px] w-[550px] overflow-hidden rounded-full border-[12px] border-blue-500/20 bg-black/95 p-1 shadow-[0_0_120px_rgba(99,102,241,0.6)]"
            >
              <motion.div
                animate={spinning ? { rotate: 360 * 8, filter: "blur(4px)" } : { rotate: 0, filter: "blur(0px)" }}
                transition={spinning ? { duration: 4.5, ease: [0.45, 0.05, 0.55, 0.95] } : { duration: 0.5 }}
                className="absolute inset-0 opacity-60"
                style={{ background: "conic-gradient(from 0deg, #6366f1, #a855f7, #ec4899, #fbbf24, #22d3ee, #6366f1)" }}
              />
              <div className="absolute inset-[15px] rounded-full bg-black/90 shadow-inner" />
              <div className="relative flex h-full w-full flex-col items-center justify-center text-center p-12">
                {!prizeWinner ? (
                  <div className="space-y-6">
                    <motion.div animate={{ rotateY: [0, 360] }} transition={{ repeat: Infinity, duration: 2, ease: "linear" }}>
                      <Trophy size={120} className="text-white drop-shadow-[0_0_40px_rgba(255,255,255,0.5)]" />
                    </motion.div>
                    <div className="text-4xl font-black uppercase italic tracking-widest text-transparent bg-clip-text bg-gradient-to-r from-blue-300 to-cyan-300">
                      Deciding...
                    </div>
                    <div className="h-16 overflow-hidden relative w-full">
                      <AnimatePresence mode="wait">
                        <motion.div
                          key={Date.now()}
                          initial={{ y: 50, opacity: 0 }}
                          animate={{ y: 0, opacity: 1 }}
                          exit={{ y: -50, opacity: 0 }}
                          className="text-xl font-bold text-blue-400 uppercase"
                        >
                          {rouletteItems[Math.floor(Math.random() * rouletteItems.length)]}
                        </motion.div>
                      </AnimatePresence>
                    </div>
                  </div>
                ) : (
                  <motion.div initial={{ scale: 0.2, opacity: 0 }} animate={{ scale: 1, opacity: 1 }} transition={{ type: "spring" }} className="space-y-6">
                    <div className="inline-block rounded-full bg-amber-400/20 px-6 py-1 border border-amber-400/40 text-amber-400 font-black uppercase tracking-[0.4em] text-[10px]">
                      Grand Champion
                    </div>
                    <div className="text-7xl font-black italic tracking-tighter text-white drop-shadow-[0_0_30px_rgba(251,191,36,0.9)] scale-110">
                      {prizeWinner}
                    </div>
                    <div className="mt-6 flex items-center justify-center gap-3">
                      <div className="h-px w-12 bg-gradient-to-r from-transparent to-blue-500/50" />
                      <div className="text-2xl font-black text-blue-200">
                        +{detail?.leaderboardTop?.[0]?.coinsWon || spotlight?.prizePool || 0} <span className="text-xs opacity-60">COINS</span>
                      </div>
                      <div className="h-px w-12 bg-gradient-to-l from-transparent to-blue-500/50" />
                    </div>
                    <motion.button
                      whileHover={{ scale: 1.05, boxShadow: "0 0 40px rgba(16,185,129,0.5)" }}
                      whileTap={{ scale: 0.95 }}
                      onClick={() => setShowRoulette(false)}
                      className="mt-12 rounded-full bg-gradient-to-r from-emerald-500 to-cyan-500 px-14 py-5 text-xs font-black uppercase tracking-[0.3em] text-white shadow-2xl"
                    >
                      Close Arena
                    </motion.button>
                  </motion.div>
                )}
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>

      {error ? <div className="mb-4 rounded-xl border border-red-500/25 bg-red-500/10 p-3 text-sm text-red-200">{error}</div> : null}
      {systemConfig && !systemConfig.mongoConnected ? (
        <div className="mb-4 rounded-xl border border-amber-500/25 bg-amber-500/10 p-3 text-sm text-amber-100">
          MongoDB is currently unstable. Tournament actions may fail until the database reconnects.
        </div>
      ) : null}

      {/* System Health / Stripe Status Bar */}
      <div className="mb-5 flex flex-wrap gap-3">
        <div
          className={`flex items-center gap-2 rounded-full border px-4 py-1.5 backdrop-blur-md ${
            connect?.payoutsEnabled ? "border-emerald-400/30 bg-emerald-500/10 text-emerald-100" : "border-amber-400/30 bg-amber-500/10 text-amber-100"
          }`}
        >
          <CreditCard size={14} />
          <span className="text-[10px] font-black uppercase tracking-widest">Stripe: {connect?.payoutsEnabled ? "Ready" : "Pending Onboarding"}</span>
        </div>
        <div
          className={`flex items-center gap-2 rounded-full border px-4 py-1.5 backdrop-blur-md ${
            live ? "border-blue-400/30 bg-blue-500/10 text-blue-100" : "border-zinc-400/30 bg-zinc-500/10 text-zinc-100"
          }`}
        >
          <Activity size={14} className={live ? "animate-pulse" : ""} />
          <span className="text-[10px] font-black uppercase tracking-widest">Live Stream: {live ? "Connected" : "Disconnected"}</span>
        </div>
        <div className="flex items-center gap-2 rounded-full border border-white/10 bg-white/5 px-4 py-1.5 backdrop-blur-md text-zinc-100">
          <Flame size={14} className="text-orange-400" />
          <span className="text-[10px] font-black uppercase tracking-widest">Prize Multiplier: 1.2x Active</span>
        </div>
        {!connect?.payoutsEnabled ? (
          <button
            onClick={startStripeOnboarding}
            disabled={loading === "connect" || !playerId.trim()}
            className="rounded-full border border-blue-300/40 bg-blue-500/20 px-4 py-1.5 text-[10px] font-black uppercase tracking-widest text-blue-100 transition hover:bg-blue-500/30 disabled:cursor-not-allowed disabled:opacity-60"
          >
            {loading === "connect" ? "Connecting Stripe..." : "Connect Stripe"}
          </button>
        ) : null}
      </div>

      <div className="mb-4 overflow-hidden rounded-2xl border border-blue-400/20 bg-gradient-to-r from-blue-500/15 via-cyan-500/10 to-cyan-500/10 px-4 py-2">
        <div className="whitespace-nowrap text-[11px] font-semibold uppercase tracking-[0.18em] text-blue-100/90">
          Live circuit • Global qualifiers • Instant score sync • Creator-hosted events • Smart anti-cheat • Tournament broadcast mode
        </div>
      </div>

      <WowHero
        badge="Competitive System"
        title="Weekly Challenge Arena"
        subtitle="Tournament Hub: Recharge your wallet, host custom events, or join active challenges to climb the leaderboard."
        tone="amber"
        mediaUrl={spotlight?.coverImageUrl || selectedProject?.previewImageUrl}
      >
        <div className="grid grid-cols-1 gap-4 lg:grid-cols-2 relative z-10">
          {/* Identity & Wallet Card */}
          <div className="rounded-2xl border border-white/10 bg-black/40 p-5 backdrop-blur-md">
            <div className="flex items-center justify-between mb-4">
              <div className="text-[10px] uppercase tracking-[0.2em] text-zinc-400 font-black">Account Context</div>
              <div
                className={`flex items-center gap-2 rounded-full border px-3 py-1 ${
                  connect?.payoutsEnabled
                    ? "border-emerald-400/30 bg-emerald-500/10 text-emerald-100"
                    : "border-amber-400/30 bg-amber-500/10 text-amber-100"
                }`}
              >
                <div className={`h-1.5 w-1.5 rounded-full ${connect?.payoutsEnabled ? "bg-emerald-400 animate-pulse" : "bg-amber-400"}`} />
                <span className="text-[9px] font-black uppercase tracking-widest">{connect?.payoutsEnabled ? "Verified" : "Unverified"}</span>
              </div>
            </div>
            <input
              value={playerId}
              onChange={(e) => setPlayerId(e.target.value)}
              placeholder="Player nickname"
              className="gf-input w-full rounded-xl p-3 text-sm font-bold bg-black/40 border-white/5 mb-4 text-white"
            />
            <div className="relative overflow-hidden rounded-xl border border-blue-500/30 bg-blue-500/10 p-4">
              <div className="flex items-center justify-between relative z-10">
                <div className="space-y-1">
                  <div className="text-[9px] font-black uppercase tracking-[0.2em] text-blue-300/80">Available Balance</div>
                  <div className="flex items-center gap-2 text-white">
                    <span className="text-3xl font-black italic">{wallet.toLocaleString()}</span>
                    <Coins size={16} className="text-amber-400" />
                  </div>
                </div>
                <button
                  onClick={() => { setPaymentStep("input"); setShowPaymentModal(true); }}
                  className="rounded-xl bg-white text-black px-4 py-2 text-[10px] font-black uppercase tracking-widest hover:bg-blue-50 transition-colors shadow-lg"
                >
                  Add Funds
                </button>
              </div>
            </div>
          </div>

          {/* Quick Host/Join Actions */}
          <div className="space-y-3 h-full">
            <div className="rounded-2xl border border-white/10 bg-black/40 p-5 backdrop-blur-md flex flex-col h-full">
              <div className="text-[10px] uppercase tracking-[0.2em] text-zinc-400 font-black mb-4">Launch & Join</div>
              <div className="flex gap-2">
                <input
                  value={joinCode}
                  onChange={(e) => setJoinCode(e.target.value)}
                  placeholder="Enter Tournament ID..."
                  className="gf-input flex-1 rounded-xl p-3 text-sm bg-black/40 border-white/5 font-bold text-white"
                />
                <button
                  onClick={() => {
                    const found = cards.find((x) => x.id.toLowerCase().includes(joinCode.trim().toLowerCase()));
                    if (found) { setSelectedTournamentId(found.id); void loadDetail(found.id); }
                  }}
                  className="rounded-xl border border-white/10 bg-white/5 px-4 text-[10px] font-black uppercase tracking-widest text-white hover:bg-white/10 transition-all active:scale-95"
                >
                  Find
                </button>
              </div>
              
              <div className="mt-auto pt-4 flex flex-col gap-3">
                <div className="rounded-xl border border-white/5 bg-white/5 p-3">
                  <label className="text-[9px] font-black text-zinc-500 uppercase tracking-widest mb-2 block">
                    Target Game Project
                  </label>
                  <button
                    onClick={() => {
                      setProjectQuery("");
                      setShowProjectPicker(true);
                    }}
                    className="gf-input w-full rounded-xl p-2.5 text-left text-sm bg-black/60 border-white/5 focus:border-cyan-500/50 text-white flex items-center justify-between gap-3"
                  >
                    <div className="min-w-0">
                      <div className="font-black truncate">{selectedProject?.name || "Choose a project"}</div>
                      <div className="text-[11px] text-zinc-500 truncate">{selectedProject?.status || ""}</div>
                    </div>
                    <div className="text-[10px] font-black uppercase tracking-widest text-zinc-400">Pick</div>
                  </button>
                </div>
                <div className="flex items-center justify-between px-1">
                  <div className="text-[10px] uppercase tracking-[0.2em] text-zinc-400 font-black">Quick Host</div>
                  <div className="text-[9px] font-bold text-blue-400 uppercase">Cost: 100 Coins</div>
                </div>
                <button
                  onClick={createTournament}
                  disabled={!!loading || wallet < 100}
                  className="w-full rounded-xl bg-gradient-to-r from-blue-500 via-cyan-500 to-pink-500 py-3.5 text-xs font-black uppercase tracking-widest text-white shadow-lg hover:brightness-110 active:scale-[0.98] transition-all disabled:opacity-30 disabled:grayscale"
                >
                  {loading === "create" ? "Initializing Arena..." : "Launch Tournament Arena"}
                </button>
                {wallet < 100 && <p className="text-[9px] text-rose-400 text-center font-bold animate-pulse">Insufficient balance to host</p>}
              </div>
            </div>
          </div>
        </div>
      </WowHero>

      <div className="mt-8 grid grid-cols-1 gap-6 xl:grid-cols-3">
        <div className="xl:col-span-2 space-y-6">
          {/* Main Tournament Spotlight Card */}
          <div className="rounded-3xl border border-blue-400/30 bg-gradient-to-br from-blue-500/15 via-cyan-500/10 to-black/40 overflow-hidden shadow-2xl relative group">
            <div className="relative h-64 w-full overflow-hidden">
              {spotlight?.coverImageUrl || selectedProject?.previewImageUrl ? (
                // eslint-disable-next-line @next/next/no-img-element
                <img
                  src={spotlight?.coverImageUrl || selectedProject?.previewImageUrl}
                  alt=""
                  className="h-full w-full object-cover transition-transform duration-700 group-hover:scale-105"
                />
              ) : (
                <div className="h-full w-full bg-gradient-to-br from-blue-500/30 to-cyan-500/20" />
              )}
              <div className="absolute inset-0 bg-gradient-to-t from-black via-black/20 to-transparent" />
              <div className="absolute bottom-6 left-6 right-6">
                <div className="flex items-center justify-between gap-4">
                  <div className="space-y-1">
                    <div className="text-4xl font-black uppercase italic tracking-tighter text-white drop-shadow-2xl">
                      {spotlight?.title || "Weekly Challenge"}
                    </div>
                    <div className="flex flex-wrap items-center gap-5 text-sm text-zinc-200 font-bold uppercase tracking-widest opacity-90">
                      <span className="flex items-center gap-1.5"><Coins size={16} className="text-amber-400" /> {spotlight?.entryFee ?? 100} Entry</span>
                      <span className="flex items-center gap-1.5"><Trophy size={16} className="text-blue-400" /> {(spotlight?.prizePool ?? 0).toLocaleString()} Pool</span>
                      <span className="flex items-center gap-1.5"><Users size={16} className="text-cyan-400" /> {spotlight?.playersCount ?? 0}/{spotlight?.maxPlayers ?? 0}</span>
                    </div>
                  </div>
                  <div className={`rounded-2xl border px-4 py-2 text-xs font-black uppercase tracking-[0.2em] backdrop-blur-md ${statusTone(spotlight?.status)}`}>
                    {spotlight?.status || "Waiting"}
                  </div>
                </div>
              </div>
            </div>

            <div className="p-6 flex flex-wrap gap-3 border-t border-white/5 bg-black/20">
              <button
                onClick={joinSpotlight}
                disabled={!spotlight || !!loading}
                className="rounded-2xl bg-gradient-to-r from-emerald-500 to-cyan-500 px-8 py-3 text-sm font-black uppercase tracking-widest text-white shadow-xl hover:brightness-110 active:scale-95 disabled:opacity-50 transition-all"
              >
                {loading === "join" ? "Joining..." : "Enter Tournament"}
              </button>
              <button
                onClick={playRun}
                disabled={!spotlight || !!loading}
                className="rounded-2xl bg-blue-500 px-8 py-3 text-sm font-black uppercase tracking-widest text-white flex items-center gap-2 shadow-xl hover:bg-blue-400 active:scale-95 disabled:opacity-50 transition-all"
              >
                <Play size={18} fill="currentColor" /> Play Run
              </button>
              <button
                onClick={finishCurrentTournament}
                disabled={!spotlight || !!loading}
                className="rounded-2xl border border-amber-400/40 bg-amber-500/10 px-6 py-3 text-sm font-black uppercase tracking-widest text-amber-100 flex items-center gap-2 hover:bg-amber-500/20 active:scale-95 disabled:opacity-50 transition-all"
              >
                <Flag size={18} /> Finish
              </button>
            </div>
            
            <div className="px-6 pb-6 space-y-3">
              <div className="h-2 w-full rounded-full bg-white/5 overflow-hidden p-[1px]">
                <motion.div
                  initial={{ width: 0 }}
                  animate={{ width: `${joinedRatio}%` }}
                  className="h-full rounded-full bg-gradient-to-r from-emerald-400 via-cyan-400 to-blue-400 shadow-[0_0_15px_rgba(16,185,129,0.4)]"
                />
              </div>
              <div className="flex items-center justify-between text-[11px] font-black uppercase tracking-widest text-zinc-400">
                <div className="flex items-center gap-2"><Sparkles size={14} className="text-blue-400" /> Arena Fill Rate</div>
                <div>{spotlight?.playersCount ?? 0} / {spotlight?.maxPlayers ?? 0} Players • {joinedRatio}%</div>
              </div>
            </div>
          </div>

          <div className="mt-8 grid grid-cols-1 md:grid-cols-2 gap-6">
            {/* Cash-out & Payouts Card */}
            <div className="rounded-3xl border border-white/10 bg-black/25 p-6 backdrop-blur-md shadow-2xl">
              <div className="flex items-center justify-between mb-6">
                <div className="text-sm font-black uppercase tracking-[0.2em] text-white">Virtual Payouts</div>
                <CreditCard size={18} className="text-blue-400" />
              </div>
              <p className="text-xs text-zinc-400 leading-relaxed mb-6">
                Convert your tournament winnings into USD instantly. Funds are credited to your active virtual card.
              </p>
              
              <div className="mt-3 grid grid-cols-2 gap-2 relative z-10">
                <div className="rounded-xl border border-white/10 bg-black/30 p-3">
                  <div className="text-[10px] uppercase tracking-[0.2em] text-zinc-300 font-black">Amount (USD)</div>
                  <input
                    type="number"
                    min={1}
                    step={1}
                    value={cashoutUsd}
                    onChange={(e) => setCashoutUsd(Number(e.target.value || 0))}
                    className="gf-input mt-2 w-full rounded-xl p-2.5 text-sm text-white font-bold"
                  />
                </div>
                <div className="rounded-xl border border-white/10 bg-black/30 p-3">
                  <div className="text-[10px] uppercase tracking-[0.2em] text-zinc-300 font-black">Recent</div>
                  <div className="mt-2 text-xs text-zinc-200 font-semibold italic">
                    {cashouts[0] ? `${(cashouts[0].amountUsdCents / 100).toFixed(2)} ${cashouts[0].currency.toUpperCase()} • ${cashouts[0].status}` : "No cash-outs yet"}
                  </div>
                </div>
              </div>
              <div className="mt-3 flex flex-wrap gap-2 relative z-10">
                <button
                  onClick={requestCashout}
                  disabled={!!loading || !connect?.payoutsEnabled}
                  className="rounded-xl bg-gradient-to-r from-emerald-500 to-cyan-500 px-4 py-2 text-sm font-black uppercase tracking-widest text-white shadow-[0_10px_28px_rgba(16,185,129,0.25)] transition hover:scale-[1.02] active:scale-95 disabled:cursor-not-allowed disabled:opacity-70"
                >
                  {loading === "cashout" ? "Sending..." : "Request Cash-out"}
                </button>
                <button
                  onClick={loadCashouts}
                  disabled={!!loading}
                  className="rounded-xl border border-white/10 bg-black/25 px-4 py-2 text-sm font-black uppercase tracking-widest text-zinc-200 hover:bg-black/35 transition-all active:scale-95 disabled:opacity-60"
                >
                  Refresh
                </button>
              </div>
              {!connect?.payoutsEnabled ? (
                <div className="mt-2 text-[10px] font-bold uppercase tracking-widest text-amber-300">
                  Stripe onboarding required before cash-out.
                </div>
              ) : null}
            </div>

            {/* Live Leaderboard Summary */}
            <div className="rounded-3xl border border-white/10 bg-black/25 p-6 backdrop-blur-md shadow-2xl">
              <div className="flex items-center justify-between mb-6">
                <div className="text-sm font-black uppercase tracking-[0.2em] text-white">Leaderboard</div>
                <Trophy size={18} className="text-amber-400" />
              </div>
              <div className="space-y-3">
                {displayLeaderboard.slice(0, 3).map((row, idx) => (
                  <div
                    key={`${row.playerId}-${idx}`}
                    className={`group relative rounded-2xl border px-4 py-3 transition-all ${
                      idx === 0
                        ? "border-amber-400/40 bg-gradient-to-r from-amber-500/20 to-black/40 shadow-[0_10px_30px_rgba(251,191,36,0.15)]"
                        : "border-white/5 bg-white/5"
                    }`}
                  >
                    <div className="flex items-center justify-between text-sm relative z-10">
                      <div className="flex items-center gap-3">
                        <div className={`flex h-7 w-7 items-center justify-center rounded-xl text-[11px] font-black ${
                          idx === 0 ? "bg-amber-400 text-black" : "bg-white/10 text-white"
                        }`}>
                          {idx + 1}
                        </div>
                        <div className="flex items-center gap-2 text-zinc-100 font-bold tracking-tight">
                          {row.playerName || row.playerId}
                          {row.cheatFlag && <ShieldAlert size={14} className="text-rose-500" />}
                        </div>
                      </div>
                      <div className={`font-black ${idx === 0 ? "text-amber-100" : "text-white"}`}>
                        {Number(row.score || 0).toLocaleString()}
                      </div>
                    </div>
                  </div>
                ))}
                {displayLeaderboard.length === 0 && (
                  <div className="py-10 text-center space-y-2 opacity-40">
                    <Medal size={32} className="mx-auto" />
                    <p className="text-[10px] font-bold uppercase tracking-widest text-zinc-400">No results found yet</p>
                  </div>
                )}
              </div>
            </div>
          </div>
        </div>

        {/* Right Sidebar: Quick Stats & Prizes */}
        <div className="space-y-6">
          <div className="rounded-3xl border border-white/10 bg-black/25 p-6 backdrop-blur-md shadow-2xl">
            <div className="text-sm font-black uppercase tracking-[0.2em] text-white mb-6">Prize Distribution</div>
            <div className="space-y-5">
              {[
                { rank: "#1 Champion", amount: prizeFirst, color: "text-amber-400", icon: <Crown size={18} /> },
                { rank: "#2 Runner Up", amount: prizeSecond, color: "text-zinc-300", icon: <Medal size={18} /> },
                { rank: "#3 Third Place", amount: prizeThird, color: "text-orange-400", icon: <Medal size={18} /> },
              ].map((p, i) => (
                <div key={i} className="flex items-center justify-between p-4 rounded-2xl bg-white/5 border border-white/5">
                  <div className="flex items-center gap-3">
                    <div className={p.color}>{p.icon}</div>
                    <div className="text-xs font-black uppercase tracking-widest text-zinc-200">{p.rank}</div>
                  </div>
                  <div className="text-lg font-black text-white italic">{p.amount.toLocaleString()} <span className="text-[10px] not-italic opacity-50">C</span></div>
                </div>
              ))}
            </div>
            <div className="mt-6 flex items-center gap-2 text-[10px] text-amber-200 font-bold uppercase tracking-widest p-4 rounded-2xl bg-amber-500/10 border border-amber-500/20">
              <Flame size={14} /> Dynamic Prize Pool Active
            </div>
          </div>

          <div className="rounded-3xl border border-white/10 bg-black/25 p-6 backdrop-blur-md shadow-2xl">
            <div className="text-sm font-black uppercase tracking-[0.2em] text-white mb-4">Arena Info</div>
            <div className="space-y-4">
              <div className="flex justify-between text-xs">
                <span className="text-zinc-500 font-bold uppercase">Time Remaining</span>
                <span className="text-white font-black">{countdownHours}h {countdownRemainderMin}m</span>
              </div>
              <div className="flex justify-between text-xs">
                <span className="text-zinc-500 font-bold uppercase">Game Engine</span>
                <span className="text-blue-400 font-black">Unity WebGL</span>
              </div>
              <div className="flex justify-between text-xs">
                <span className="text-zinc-500 font-bold uppercase">Anti-cheat</span>
                <span className="text-emerald-400 font-black flex items-center gap-1.5"><ShieldCheck size={14} /> Active</span>
              </div>
            </div>
          </div>
        </div>
      </div>

      <div className="mt-6 flex flex-wrap gap-2">
        {([
          ["active", "Active"],
          ["upcoming", "Upcoming"],
          ["past", "Past"],
        ] as const).map(([value, label]) => (
          <button
            key={value}
            onClick={() => setTab(value)}
            className={`rounded-xl px-4 py-2 text-sm font-black uppercase tracking-widest ${
              tab === value
                ? "border border-blue-300/50 bg-blue-500/20 text-blue-100"
                : "border border-white/10 bg-black/25 text-zinc-300"
            }`}
          >
            {label}
          </button>
        ))}
        <button
          onClick={() => setShowJoinedOnly((v) => !v)}
          className={`rounded-xl px-4 py-2 text-sm font-black uppercase tracking-widest ${
            showJoinedOnly
              ? "border border-emerald-300/50 bg-emerald-500/20 text-emerald-100"
              : "border border-white/10 bg-black/25 text-zinc-300"
          }`}
        >
          {showJoinedOnly ? "Joined Only" : "All Tournaments"}
        </button>
      </div>

      <div className="mt-4 grid grid-cols-1 gap-4 md:grid-cols-2">
        {cards.map((t) => (
          <button
            key={t.id}
            onClick={() => {
              setSelectedTournamentId(t.id);
              void loadDetail(t.id);
            }}
            className={`text-left rounded-2xl border p-4 transition-all ${
              selectedTournamentId === t.id ? "border-blue-400/50 bg-gradient-to-br from-blue-500/20 via-cyan-500/10 to-black/20 shadow-[0_14px_36px_rgba(99,102,241,0.2)]" : "border-white/10 bg-black/25 hover:border-white/25 hover:bg-black/35"
            }`}
          >
            <div className="flex items-center justify-between gap-2">
              <div className="text-lg font-black text-white">{t.title}</div>
              <div className={`rounded-full border px-2.5 py-1 text-[10px] uppercase tracking-[0.18em] ${statusTone(t.status)}`}>{t.status}</div>
            </div>
            <div className="mt-2 flex flex-wrap gap-3 text-xs text-zinc-300">
              <span className="flex items-center gap-1"><Coins size={12} /> {Number(t.prizePool || 0).toLocaleString()}</span>
              <span className="flex items-center gap-1"><Users size={12} /> {t.playersCount}/{t.maxPlayers}</span>
              <span className="flex items-center gap-1"><Timer size={12} /> {new Date(t.endsAt).toLocaleTimeString()}</span>
            </div>
            <div className="mt-3 h-1.5 w-full overflow-hidden rounded-full bg-white/10">
              <div
                className="h-full rounded-full bg-gradient-to-r from-emerald-400 via-cyan-400 to-blue-400"
                style={{ width: `${Math.max(0, Math.min(100, Math.round((t.playersCount / Math.max(1, t.maxPlayers)) * 100)))}%` }}
              />
            </div>
          </button>
        ))}
        {cards.length === 0 ? <div className="rounded-2xl border border-white/10 bg-black/25 p-4 text-sm text-zinc-400 md:col-span-2">No tournaments in this tab. Create one now.</div> : null}
      </div>

      <div className="mt-5">
        <ContextMediaCard
          label="Tournament Theme"
          name={selectedProject?.name || "No project selected"}
          description={selectedProject?.description}
          meta={selectedProject?.status ? `Status • ${String(selectedProject.status)}` : "Choose a project to power the arena"}
          mediaUrl={selectedProject?.previewImageUrl}
        />
      </div>

      {showProjectPicker ? (
        <div className="fixed inset-0 z-[72] flex items-center justify-center bg-black/85 backdrop-blur-xl p-4">
          <div className="w-full max-w-4xl overflow-hidden rounded-[32px] border border-white/10 bg-[#0d0d12] shadow-[0_32px_64px_rgba(0,0,0,0.8)]">
            <div className="p-6">
              <div className="flex items-center justify-between gap-3">
                <div>
                  <div className="text-[10px] font-black uppercase tracking-[0.24em] text-zinc-500">Project / Game</div>
                  <div className="mt-1 text-xl font-black text-white tracking-tight">Choose your arena</div>
                  <div className="mt-1 text-xs text-zinc-500">Arcade-style picker with real project media.</div>
                </div>
                <button
                  onClick={() => setShowProjectPicker(false)}
                  className="rounded-full bg-white/5 p-2 text-zinc-400 hover:bg-white/10 transition-colors"
                >
                  <X size={18} />
                </button>
              </div>

              <div className="mt-5 flex flex-wrap items-center gap-3">
                <input
                  value={projectQuery}
                  onChange={(e) => setProjectQuery(e.target.value)}
                  placeholder="Search projects…"
                  className="gf-input flex-1 min-w-[220px] rounded-2xl p-3"
                />
                <div className="rounded-full border border-white/10 bg-white/5 px-3 py-1.5 text-[10px] font-black uppercase tracking-widest text-zinc-300">
                  {filteredProjects.length} results
                </div>
              </div>

              <div className="mt-5 grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3 max-h-[60vh] overflow-auto pr-1">
                {filteredProjects.map((p) => {
                  const selected = p.id === selectedProjectId;
                  return (
                    <button
                      key={p.id}
                      onClick={() => {
                        setSelectedProjectId(p.id);
                        setShowProjectPicker(false);
                      }}
                      className={`text-left rounded-2xl border overflow-hidden transition-all ${
                        selected
                          ? "border-cyan-300/40 bg-gradient-to-br from-cyan-500/15 via-blue-500/10 to-black/40"
                          : "border-white/10 bg-black/25 hover:border-white/25 hover:bg-black/35"
                      }`}
                    >
                      <div className="relative h-28">
                        {p.previewImageUrl ? (
                          // eslint-disable-next-line @next/next/no-img-element
                          <img src={p.previewImageUrl} alt="" className="h-full w-full object-cover" />
                        ) : (
                          <div className="h-full w-full bg-gradient-to-br from-blue-500/25 via-cyan-500/10 to-black/10" />
                        )}
                        <div className="absolute inset-0 bg-gradient-to-t from-black/85 via-black/20 to-transparent" />
                        {selected ? (
                          <div className="absolute top-3 right-3 rounded-full border border-cyan-300/30 bg-cyan-500/10 px-2 py-1 text-[9px] font-black uppercase tracking-[0.22em] text-cyan-100">
                            Selected
                          </div>
                        ) : null}
                      </div>
                      <div className="p-4">
                        <div className="text-sm font-black text-white truncate">{p.name}</div>
                        <div className="mt-1 text-[11px] text-zinc-500 truncate">{p.status || ""}</div>
                      </div>
                    </button>
                  );
                })}

                {filteredProjects.length === 0 ? (
                  <div className="rounded-2xl border border-white/10 bg-black/25 p-5 text-sm text-zinc-400 sm:col-span-2 lg:col-span-3">
                    No projects found.
                  </div>
                ) : null}
              </div>
            </div>
          </div>
        </div>
      ) : null}

      <div className="mt-5 rounded-2xl border border-white/10 bg-black/25 p-4">
        <div className="flex items-center justify-between gap-2">
          <div className="flex items-center gap-2">
            <div className="text-sm font-black uppercase tracking-widest text-zinc-200">Live Notifications</div>
            <div className={`rounded-full border px-2 py-0.5 text-[10px] font-black uppercase tracking-[0.18em] ${live ? "border-emerald-400/30 bg-emerald-500/10 text-emerald-100" : "border-amber-400/30 bg-amber-500/10 text-amber-100"}`}>
              {live ? "LIVE" : "POLL"}
            </div>
          </div>
          <button onClick={createTournament} disabled={!!loading} className="rounded-xl border border-blue-400/30 bg-blue-500/15 px-3 py-1.5 text-xs font-black uppercase tracking-widest text-blue-100 flex items-center gap-1">
            <Plus size={12} /> {loading === "create" ? "Creating..." : "Create Tournament"}
          </button>
        </div>
        <div className="mt-3 space-y-2">
          {notifications.map((n) => (
            <div key={n.id} className={`rounded-xl border px-3 py-2 text-xs shadow-[0_12px_32px_rgba(0,0,0,0.25)] ${notificationTone(n.type)} animate-[pulseSoft_1.6s_ease-in-out]`}>
              <div className="flex items-center justify-between gap-2">
                <div className="font-semibold">{n.message}</div>
                <div className="text-[10px] font-black uppercase tracking-[0.18em] opacity-90">{n.type}</div>
              </div>
              <div className="mt-1 text-[10px] opacity-75">{new Date(n.createdAt).toLocaleString()}</div>
            </div>
          ))}
          {notifications.length === 0 ? <div className="text-xs text-zinc-400">No notifications yet.</div> : null}
        </div>
      </div>

      {detail?.status === "finished" ? (
        <div className="mt-5 rounded-2xl border border-emerald-500/25 bg-emerald-500/10 p-4">
          <div className="text-sm font-black text-emerald-200">Tournament Finished</div>
          <div className="mt-2 text-xs text-zinc-200">Winner: {detail.leaderboardTop?.[0]?.playerName || detail.leaderboardTop?.[0]?.playerId || "N/A"}</div>
          <div className="text-xs text-zinc-200">Your wallet: {wallet.toLocaleString()} coins</div>
        </div>
      ) : null}
      </motion.div>

      {/* WOW: Stripe Test Payment Modal (Premium Design) */}
      <AnimatePresence>
        {showPaymentModal && (
          <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} className="fixed inset-0 z-[70] flex items-center justify-center bg-black/85 backdrop-blur-xl p-4">
            <motion.div initial={{ scale: 0.9, y: 20 }} animate={{ scale: 1, y: 0 }} exit={{ scale: 0.9, y: 20 }} className="w-full max-w-md overflow-hidden rounded-[32px] border border-white/10 bg-[#0d0d12] shadow-[0_32px_64px_rgba(0,0,0,0.8)]">
              <div className="relative p-6 text-center">
                <div className="flex items-center justify-between mb-4">
                  <h2 className="text-xl font-bold text-white tracking-tight">Tournament Wallet Top-up</h2>
                  <button onClick={() => setShowPaymentModal(false)} className="rounded-full bg-white/5 p-2 text-zinc-400 hover:bg-white/10 transition-colors">
                    <X size={18} />
                  </button>
                </div>
                <p className="text-left text-xs text-zinc-500 mb-6 -mt-3">Pay securely with Stripe Checkout. Funds are credited to your tournament wallet automatically.</p>
                
                {paymentStep === "input" && (
                  <div className="space-y-5 animate-in fade-in duration-500">
                    <div className="rounded-xl bg-white/5 p-4 border border-white/5 flex items-center justify-between">
                      <span className="text-[10px] font-black text-zinc-500 uppercase tracking-widest">Amount</span>
                      <div className="flex items-center gap-1.5">
                        <Coins size={14} className="text-amber-400" />
                        <span className="text-xl font-black text-white italic">${topUpAmount.toFixed(2)}</span>
                      </div>
                    </div>

                    <div className="rounded-xl bg-black/30 border border-white/5 p-3">
                      <div className="text-[10px] font-black text-zinc-500 uppercase tracking-widest mb-2">Montant</div>
                      <div className="flex items-center justify-between gap-3">
                        <div className="flex gap-2">
                          {[10, 49, 100].map((v) => (
                            <button
                              key={v}
                              onClick={() => setTopUpAmount(v)}
                              className={`rounded-lg px-3 py-1.5 text-xs font-black transition-all ${
                                topUpAmount === v ? "bg-blue-500 text-white" : "bg-white/5 text-zinc-400 hover:bg-white/10"
                              }`}
                            >
                              ${v}
                            </button>
                          ))}
                        </div>
                        <div className="flex items-center gap-1">
                          <span className="text-zinc-500 text-sm font-bold">$</span>
                          <input
                            type="number"
                            min={1}
                            step={1}
                            value={topUpAmount}
                            onChange={(e) => setTopUpAmount(Number(e.target.value || 0))}
                            className="bg-transparent text-right text-lg font-black text-white outline-none w-24"
                          />
                        </div>
                      </div>
                    </div>

                    <div className="flex gap-2">
                      <button className="flex-1 flex flex-col items-center justify-center gap-2 rounded-xl bg-blue-500 p-4 border border-blue-400/50 shadow-[0_0_20px_rgba(99,102,241,0.3)]">
                        <CreditCard size={20} className="text-white" />
                        <span className="text-[9px] font-black uppercase text-white tracking-widest text-center">Carte<br/>bancaire</span>
                      </button>
                    </div>

                    <div className="flex items-center gap-2 text-blue-400 text-[11px] font-bold py-1 border-b border-white/5 cursor-pointer group">
                      <Lock size={12} />
                      <span className="group-hover:underline">Paiement sécurisé et rapide avec Link</span>
                      <Plus size={12} className="ml-auto opacity-50" />
                    </div>

                    <div className="rounded-xl border border-white/10 bg-black/30 p-4 text-left">
                      <div className="text-[10px] font-black uppercase tracking-widest text-zinc-500">Checkout</div>
                      <div className="mt-1 text-xs text-zinc-300">You will be redirected to Stripe to complete payment.</div>
                      <div className="mt-2 text-[10px] text-zinc-500">After payment, your wallet is credited automatically via Stripe webhook.</div>
                    </div>

                    <div className="flex gap-3 pt-2">
                      <button onClick={() => setShowPaymentModal(false)} className="flex-1 rounded-xl bg-white/5 py-4 text-xs font-black uppercase tracking-widest text-zinc-400 hover:bg-white/10 transition-all">
                        Cancel
                      </button>
                      <button onClick={simulateTopUp} className="flex-[2] rounded-xl bg-gradient-to-r from-blue-500 to-cyan-600 py-4 text-xs font-black uppercase tracking-widest text-white shadow-[0_15px_35px_rgba(99,102,241,0.4)] transition hover:brightness-110 active:scale-[0.98]">
                        Continue to Stripe
                      </button>
                    </div>
                    
                    <div className="flex items-center justify-center gap-2 text-[9px] text-zinc-600 font-bold uppercase tracking-widest pb-2">
                      <ShieldCheck size={12} className="opacity-50" />
                      Secure SSL Encrypted Payment
                    </div>
                  </div>
                )}

                {paymentStep === "processing" && (
                  <div className="py-20 flex flex-col items-center animate-in zoom-in duration-500">
                    <div className="relative h-20 w-20">
                      <motion.div animate={{ rotate: 360 }} transition={{ repeat: Infinity, duration: 1, ease: "linear" }} className="absolute inset-0 rounded-full border-4 border-blue-500/20 border-t-blue-500" />
                    </div>
                    <h2 className="mt-8 text-xl font-black text-white uppercase italic">Processing...</h2>
                    <p className="mt-2 text-sm text-zinc-500 font-medium tracking-wide">Communicating with Stripe Gateway</p>
                  </div>
                )}

                {paymentStep === "success" && (
                  <div className="py-12 flex flex-col items-center animate-in zoom-in duration-500">
                    <div className="rounded-full bg-emerald-500/20 p-6 text-emerald-400 mb-6 shadow-[0_0_50px_rgba(16,185,129,0.3)]">
                      <CheckCircle2 size={64} />
                    </div>
                    <h2 className="text-3xl font-black text-white italic tracking-tighter">Success!</h2>
                    <p className="mt-2 text-zinc-400 font-medium">Tokens added to your wallet</p>
                    <button onClick={() => setShowPaymentModal(false)} className="mt-10 rounded-2xl border border-white/10 bg-white/5 px-10 py-3 text-xs font-black uppercase tracking-widest text-white hover:bg-white/10">
                      Back to Arena
                    </button>
                  </div>
                )}
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </UserShell>
  );
}
