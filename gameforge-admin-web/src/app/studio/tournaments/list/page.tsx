"use client";

import { useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { motion } from "framer-motion";
import UserShell from "@/app/_components/UserShell";
import { apiFetch, ApiError } from "@/lib/api";
import { useAuthToken } from "@/lib/stores/authStore";
import { useLabsContext } from "../../wow-labs/_lib/useLabsContext";
import { useToast } from "@/app/_components/ToastProvider";
import { Coins, Users, Play, Plus, Trophy, CalendarClock, UserPlus, Copy } from "lucide-react";

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

function normalizeTournamentCard(raw: unknown): TournamentCard | null {
  if (!raw || typeof raw !== "object") return null;
  const obj = raw as Record<string, unknown>;
  const id = asStr(obj.id || obj["_id"]);
  if (!id) return null;

  const s = asStr(obj.status, "waiting").toLowerCase();
  const status: TournamentCard["status"] = s === "active" || s === "finished" ? s : "waiting";

  return {
    id,
    gameId: asStr(obj.gameId) || undefined,
    title: asStr(obj.title, "Tournament"),
    status,
    entryFee: asNum(obj.entryFee, 100),
    prizePool: asNum(obj.prizePool, 0),
    playersCount: asNum(obj.playersCount, 0),
    maxPlayers: asNum(obj.maxPlayers, 20),
    startsAt: asNum(obj.startsAt, Date.now()),
    endsAt: asNum(obj.endsAt, Date.now() + 3600_000),
    coverImageUrl: asStr(obj.coverImageUrl) || undefined,
  };
}

function statusTone(status: TournamentCard["status"]) {
  if (status === "active") return "border-emerald-400/40 bg-emerald-500/15 text-emerald-100";
  if (status === "finished") return "border-zinc-400/40 bg-zinc-500/15 text-zinc-100";
  return "border-amber-400/40 bg-amber-500/15 text-amber-100";
}

export default function TournamentsListPage() {
  const router = useRouter();
  const { token } = useAuthToken();
  const { templates } = useLabsContext({ withProjects: false, withTemplates: true });
  const toast = useToast();

  const [tab, setTab] = useState<"active" | "upcoming" | "past">("active");
  const [joinedOnly, setJoinedOnly] = useState(false);
  const [playerId, setPlayerId] = useState("Falcon42");
  const [authUserId, setAuthUserId] = useState("");
  const [isAdmin, setIsAdmin] = useState(false);
  const [loading, setLoading] = useState(false);
  const [joiningId, setJoiningId] = useState<string | null>(null);
  const [items, setItems] = useState<TournamentCard[]>([]);
  const [error, setError] = useState<string | null>(null);

  const [nowMs, setNowMs] = useState(() => Date.now());

  useEffect(() => {
    const t = window.setInterval(() => setNowMs(Date.now()), 1000);
    return () => window.clearInterval(t);
  }, []);

  function fmtCountdown(endsAt: number) {
    const ms = Math.max(0, Number(endsAt || 0) - nowMs);
    const totalSec = Math.floor(ms / 1000);
    const hh = Math.floor(totalSec / 3600);
    const mm = Math.floor((totalSec % 3600) / 60);
    const ss = totalSec % 60;
    const pad = (n: number) => n.toString().padStart(2, "0");
    return `${pad(hh)}:${pad(mm)}:${pad(ss)}`;
  }

  const statusQuery = tab === "active" ? "active" : tab === "upcoming" ? "waiting" : "finished";

  const activeTemplateLabel = useMemo(() => {
    if (!templates.length) return "No templates loaded";
    return `${templates.length} game templates available`;
  }, [templates]);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      if (!token) {
        if (!cancelled) setAuthUserId("");
        if (!cancelled) setIsAdmin(false);
        return;
      }
      try {
        const profile = await apiFetch<any>("/auth/profile", { method: "GET", token: token || undefined });
        const user = profile?.user || profile?.data?.user || profile?.data || profile;
        const uid = String(user?.id || user?._id || user?.sub || "").trim();
        if (!cancelled) setAuthUserId(uid);

        const roleRaw = String(user?.role || user?.roles || "").toLowerCase();
        const admin = roleRaw === "admin" || roleRaw.includes("admin");
        if (!cancelled) setIsAdmin(admin);
      } catch {
        if (!cancelled) setAuthUserId("");
        if (!cancelled) setIsAdmin(false);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [token]);

  async function finishTournament(tournamentId: string) {
    if (!token) {
      setError("Sign in required.");
      return;
    }
    setLoading(true);
    setError(null);
    try {
      await apiFetch(`/platform-labs/tournaments/${encodeURIComponent(tournamentId)}/finish`, {
        method: "POST",
        token: token || undefined,
      });
      await load();
    } catch (e: unknown) {
      const msg = e instanceof ApiError ? e.message : e instanceof Error ? e.message : "Finish failed";
      setError(msg);
    } finally {
      setLoading(false);
    }
  }

  async function load() {
    setLoading(true);
    setError(null);
    try {
      const userFilter = joinedOnly && authUserId.trim() ? `&userId=${encodeURIComponent(authUserId.trim())}` : "";
      const raw = await apiFetch<unknown>(`/platform-labs/tournaments?status=${statusQuery}${userFilter}`, {
        method: "GET",
        token: token || undefined,
      });
      const list = Array.isArray(raw) ? raw.map(normalizeTournamentCard).filter((x): x is TournamentCard => Boolean(x)) : [];
      setItems(list);
    } catch (e: unknown) {
      const msg = e instanceof ApiError ? e.message : e instanceof Error ? e.message : "Failed to load tournaments";
      setError(msg);
      setItems([]);
    } finally {
      setLoading(false);
    }
  }

  async function joinTournament(tournamentId: string) {
    if (!authUserId.trim()) {
      setError("Sign in required before joining.");
      return;
    }
    if (!playerId.trim()) {
      setError("Enter player nickname before joining.");
      return;
    }
    setJoiningId(tournamentId);
    setError(null);
    try {
      await apiFetch("/platform-labs/tournaments/join", {
        method: "POST",
        token: token || undefined,
        body: {
          tournamentId,
          userId: authUserId.trim(),
          playerName: playerId.trim(),
          initialBalance: 5000,
        },
      });
      await load();
    } catch (e: unknown) {
      const msg = e instanceof ApiError ? e.message : e instanceof Error ? e.message : "Join failed";
      setError(msg);
    } finally {
      setJoiningId(null);
    }
  }

  function playTournament(t: TournamentCard) {
    router.push(`/studio/tournaments/${encodeURIComponent(t.id)}/play`);
  }

  useEffect(() => {
    void load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [tab, joinedOnly]);

  return (
    <UserShell title="Tournament List" subtitle="Browse, join, and launch active tournaments with real backend data.">
      <div className="space-y-5">
        {error ? <div className="rounded-xl border border-rose-500/30 bg-rose-500/10 px-4 py-3 text-sm text-rose-200">{error}</div> : null}

        <div className="rounded-xl border border-white/[0.05] bg-[var(--gf-panel-bg-strong)] p-4">
          <div className="flex flex-wrap items-center justify-between gap-3">
            <div>
              <div className="text-xs tracking-wider text-zinc-500 font-semibold">Tournament Control</div>
              <div className="mt-1 text-sm text-zinc-600 font-medium">{activeTemplateLabel}</div>
            </div>
            <div className="flex items-center gap-2">
              <button
                onClick={() => router.push("/studio/tournaments/create")}
                className="rounded-xl border border-white/[0.05] bg-white/[0.02] px-3 py-2 text-xs font-semibold tracking-wide text-white flex items-center gap-2"
              >
                <Plus size={14} /> Create Tournament
              </button>
            </div>
          </div>

          <div className="mt-4 grid grid-cols-1 gap-3 md:grid-cols-3">
            <input
              value={playerId}
              onChange={(e) => setPlayerId(e.target.value)}
              placeholder="Player nickname"
              className="gf-input rounded-xl p-3 text-sm"
            />
            <div className="flex flex-wrap gap-2 md:col-span-2">
              {([
                ["active", "Active"],
                ["upcoming", "Upcoming"],
                ["past", "Past"],
              ] as const).map(([v, label]) => (
                <button
                  key={v}
                  onClick={() => setTab(v)}
                  className={`rounded-xl px-4 py-2 text-xs font-black uppercase tracking-widest transition-all ${tab === v ? "bg-blue-600 text-white shadow-lg shadow-blue-500/30" : "bg-zinc-100 text-zinc-500 hover:bg-zinc-200"}`}
                >
                  {label}
                </button>
              ))}
              <button
                onClick={() => setJoinedOnly((x) => !x)}
                className={`rounded-xl px-4 py-2 text-xs font-black uppercase tracking-widest transition-all ${joinedOnly ? "bg-emerald-600 text-white shadow-lg shadow-emerald-500/30" : "bg-zinc-100 text-zinc-500 hover:bg-zinc-200"}`}
              >
                {joinedOnly ? "Joined Only" : "All"}
              </button>
            </div>
          </div>
        </div>

        <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
          {items.map((t) => {
            const fillPct = Math.max(0, Math.min(100, Math.round((t.playersCount / Math.max(1, t.maxPlayers)) * 100)));
            const timePct = (() => {
              const s = Number(t.startsAt || 0);
              const e = Number(t.endsAt || 0);
              if (!s || !e || e <= s) return null;
              const p = Math.max(0, Math.min(1, (nowMs - s) / (e - s)));
              return Math.round(p * 100);
            })();
            return (
              <motion.div
                key={t.id}
                initial={{ opacity: 0, y: 16, scale: 0.99 }}
                animate={{ opacity: 1, y: 0, scale: 1 }}
                transition={{ type: "spring", stiffness: 220, damping: 22 }}
                whileHover={{ y: -4, scale: 1.01 }}
                whileTap={{ scale: 0.99 }}
                className="rounded-xl border border-white/[0.05] bg-[var(--gf-panel-bg-strong)] overflow-hidden hover:border-white/[0.08] transition-colors shadow-lg"
                style={{ boxShadow: "0 18px 60px rgba(0,0,0,0.35)" }}
              >
                <div className="relative h-40">
                  {t.coverImageUrl ? (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img src={t.coverImageUrl} alt="" className="h-full w-full object-cover" />
                  ) : (
                    <div className="h-full w-full bg-gradient-to-br from-blue-500/30 to-cyan-500/10" />
                  )}
                  <div className="absolute inset-0 bg-gradient-to-t from-black/80 to-transparent" />
                  <div className="absolute left-4 right-4 top-4 flex items-center justify-between">
                    <button
                      onClick={() => router.push(`/studio/tournaments/${encodeURIComponent(t.id)}`)}
                      className="text-left text-[var(--foreground)] font-semibold text-lg hover:underline"
                    >
                      {t.title}
                    </button>
                    <motion.div
                      className={`rounded-full border px-3 py-1 text-[10px] tracking-wider ${statusTone(t.status)}`}
                      animate={t.status === "active" ? { boxShadow: ["0 0 0 rgba(16,185,129,0)", "0 0 22px rgba(16,185,129,0.22)", "0 0 0 rgba(16,185,129,0)"] } : undefined}
                      transition={t.status === "active" ? { duration: 2.2, repeat: Infinity } : undefined}
                    >
                      {t.status}
                    </motion.div>
                  </div>
                </div>

                <div className="p-4 space-y-3">
                  <div className="flex flex-wrap gap-4 text-[11px] font-bold uppercase tracking-wider text-zinc-700">
                    <span className="flex items-center gap-1"><Coins size={13} /> {t.entryFee} Entry</span>
                    <span className="flex items-center gap-1"><Trophy size={13} /> {Number(t.prizePool || 0).toLocaleString()} Pool</span>
                    <span className="flex items-center gap-1"><Users size={13} /> {t.playersCount}/{t.maxPlayers}</span>
                    <span className="flex items-center gap-1"><CalendarClock size={13} /> {new Date(t.endsAt).toLocaleString()}</span>
                  </div>

                  {timePct != null ? (
                    <div className="rounded-xl border border-white/[0.05] bg-[var(--gf-shell-bg)]/50 p-3">
                      <div className="flex items-center justify-between">
                        <div className="text-[10px] font-semibold tracking-wider text-zinc-500">Time</div>
                        <div className={`text-[10px] font-black uppercase tracking-widest ${t.endsAt - nowMs <= 60_000 ? "text-rose-600" : "text-zinc-500"}`}>
                          {fmtCountdown(t.endsAt)}
                        </div>
                      </div>
                      <div className="mt-2 h-2 w-full rounded-full bg-white/10 overflow-hidden">
                        <div
                          className="h-full rounded-full bg-gradient-to-r from-emerald-400 via-cyan-400 to-blue-400"
                          style={{ width: `${timePct}%` }}
                        />
                      </div>
                    </div>
                  ) : null}

                  <div className="h-2 w-full rounded-full bg-white/10 overflow-hidden">
                    <div className="h-full rounded-full bg-gradient-to-r from-emerald-400 to-cyan-400" style={{ width: `${fillPct}%` }} />
                  </div>

                  <div className="flex flex-wrap gap-2">
                    <button
                      onClick={() => router.push(`/studio/tournaments/${encodeURIComponent(t.id)}`)}
                      className="rounded-xl border border-zinc-200 bg-zinc-50 px-4 py-2 text-[10px] font-black uppercase tracking-widest text-zinc-700 hover:bg-zinc-100 transition-all"
                    >
                      Details
                    </button>
                    <button
                      onClick={async () => {
                        try {
                          const url = `${window.location.origin}/studio/tournaments/${encodeURIComponent(t.id)}`;
                          await navigator.clipboard.writeText(url);
                          toast.success("Copied!");
                        } catch {
                          // ignore
                        }
                      }}
                      className="rounded-xl border border-zinc-200 bg-zinc-50 px-4 py-2 text-[10px] font-black uppercase tracking-widest text-zinc-700 hover:bg-zinc-100 transition-all flex items-center gap-2"
                    >
                      <Copy size={13} /> Copy
                    </button>
                    <button
                      onClick={() => joinTournament(t.id)}
                      disabled={joiningId === t.id}
                      className="rounded-xl bg-white px-4 py-2 text-xs font-medium text-black hover:bg-zinc-200 disabled:opacity-50 flex items-center gap-1"
                    >
                      <UserPlus size={13} /> {joiningId === t.id ? "Joining..." : "Join"}
                    </button>
                    <button
                      onClick={() => playTournament(t)}
                      className="rounded-xl border border-zinc-200 bg-zinc-50 px-4 py-2 text-[10px] font-black uppercase tracking-widest text-zinc-700 hover:bg-zinc-100 transition-all flex items-center gap-1"
                    >
                      <Play size={13} /> Play Game
                    </button>

                    {isAdmin && (t.status === "active" || t.status === "waiting") ? (
                      <button
                        onClick={() => finishTournament(t.id)}
                        disabled={loading}
                        className="rounded-xl border border-amber-400/40 bg-amber-500/10 px-4 py-2 text-xs font-semibold tracking-wide text-amber-100 flex items-center gap-1 hover:bg-amber-500/20 active:scale-95 disabled:opacity-50 transition-all"
                        title="Admin: finish tournament now (manual test)"
                      >
                        Finish Now
                      </button>
                    ) : null}
                  </div>
                </div>
              </motion.div>
            );
          })}

          {!loading && items.length === 0 ? (
            <div className="rounded-xl border border-white/[0.05] bg-[var(--gf-panel-bg-strong)] p-5 text-sm text-zinc-400 lg:col-span-2">
              No tournaments found in this tab.
            </div>
          ) : null}
        </div>
      </div>
    </UserShell>
  );
}
