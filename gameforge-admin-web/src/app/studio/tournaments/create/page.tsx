"use client";

import { useEffect, useMemo, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { motion } from "framer-motion";
import UserShell from "@/app/_components/UserShell";
import { apiFetch, ApiError } from "@/lib/api";
import { useAuthToken } from "@/lib/stores/authStore";
import { normalizeImageUrl } from "@/lib/media";
import { useLabsContext } from "../../wow-labs/_lib/useLabsContext";
import { Elements, PaymentElement, useElements, useStripe } from "@stripe/react-stripe-js";
import { loadStripe } from "@stripe/stripe-js";
import { Sparkles, Trophy, ArrowLeft, CheckCircle2, Coins, CreditCard, Lock, Plus, ShieldCheck, X } from "lucide-react";

type CreateForm = {
  title: string;
  entryFee: number;
  maxPlayers: number;
  startsAt: string;
  endsAt: string;
  mode: string;
};

const STRIPE_PUBLISHABLE_KEY = process.env.NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY || "";
const stripePromise = STRIPE_PUBLISHABLE_KEY ? loadStripe(STRIPE_PUBLISHABLE_KEY) : null;

function TopUpCheckoutForm({
  amount,
  onSuccess,
  onCancel,
  userId,
  token,
}: {
  amount: number;
  onSuccess: () => void;
  onCancel: () => void;
  userId: string;
  token: string | null;
}) {
  const stripe = useStripe();
  const elements = useElements();
  const [error, setError] = useState<string | null>(null);
  const [processing, setProcessing] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!stripe || !elements) return;
    setProcessing(true);
    setError(null);
    try {
      const res = await stripe.confirmPayment({
        elements,
        redirect: "if_required",
      });

      if (res.error) {
        setError(res.error.message || "Payment failed");
        setProcessing(false);
        return;
      }

      const status = (res as any)?.paymentIntent?.status;
      if (status && status !== "succeeded") {
        setError(`Payment status: ${status}`);
        setProcessing(false);
        return;
      }

      const paymentIntentId = String((res as any)?.paymentIntent?.id || "").trim();
      if (paymentIntentId) {
        try {
          await apiFetch<any>("/platform-labs/tournaments/wallet/top-up/payment-intent/confirm", {
            method: "POST",
            token: token || undefined,
            body: {
              paymentIntentId,
              userId: String(userId || "").trim(),
            },
          });
        } catch {
          // ignore; webhook may still credit later
        }
      }

      setProcessing(false);
      onSuccess();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Payment failed");
      setProcessing(false);
    }
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      <div className="rounded-xl bg-white/[0.02] p-4 border border-white/5 flex items-center justify-between">
        <span className="text-[10px] font-semibold text-zinc-500 tracking-wide">Total</span>
        <div className="flex items-center gap-1.5">
          <Coins size={14} className="text-amber-400" />
          <span className="text-xl font-semibold text-white italic">${Number(amount || 0).toFixed(2)}</span>
        </div>
      </div>

      <div className="rounded-xl border border-white/[0.05] bg-[#07080f] p-3 text-left">
        <PaymentElement
          options={{
            layout: { type: "tabs", defaultCollapsed: false },
            paymentMethodOrder: ["link", "card"],
          }}
        />
      </div>

      {error ? (
        <div className="rounded-xl border border-rose-500/30 bg-rose-500/10 px-4 py-3 text-sm text-rose-200 text-left">{error}</div>
      ) : null}

      <div className="flex gap-3 pt-1">
        <button
          type="button"
          onClick={onCancel}
          disabled={processing}
          className="flex-1 rounded-xl bg-white/[0.02] py-4 text-xs font-semibold tracking-wide text-zinc-400 hover:bg-white/10 transition-all disabled:opacity-60"
        >
          Cancel
        </button>
        <button
          type="submit"
          disabled={!stripe || processing}
          className="flex-[2] rounded-xl bg-gradient-to-r from-blue-500 to-cyan-600 py-4 text-xs font-semibold tracking-wide text-white shadow-[0_15px_35px_rgba(99,102,241,0.4)] transition hover:brightness-110 active:scale-[0.98] disabled:opacity-60"
        >
          Pay
        </button>
      </div>

      <div className="flex items-center justify-center gap-2 text-[9px] text-zinc-600 font-bold tracking-wide pb-2">
        <ShieldCheck size={12} className="opacity-50" />
        Secure SSL Encrypted Payment
      </div>
    </form>
  );
}

export default function CreateTournamentPage() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const { token } = useAuthToken();
  const { projects, selectedProjectId, selectedProject } = useLabsContext({
    withProjects: true,
    withTemplates: false,
  });

  const [selectedGameId, setSelectedGameId] = useState("");

  const [arcadeGames, setArcadeGames] = useState<any[]>([]);
  const [arcadeLoading, setArcadeGamesLoading] = useState(false);

  // Fetch public arcade games so anyone can create tournaments on them
  useEffect(() => {
    if (!token) return;
    let cancelled = false;
    (async () => {
      try {
        setArcadeGamesLoading(true);
        const res = await apiFetch<any>("/game-feed", { 
          method: "GET",
          token: token 
        });
        const data = res?.data || res || [];
        if (!cancelled && Array.isArray(data)) {
          // Map Arcade Feed Posts to the picker format
          // We use post.projectId as the gameId because tournaments play actual projects
          setArcadeGames(data.map((p: any) => ({
            ...p,
            id: p.projectId || p._id || p.id,
            name: p.title || "Untitled Arcade Game",
            status: "ready", // Feed posts are already published/ready
            previewImageUrl: p.previewImageUrl || p.thumbnailUrl,
          })));
        }
      } catch (err) {
        console.error("Failed to load arcade games", err);
      } finally {
        if (!cancelled) setArcadeGamesLoading(false);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [token]);

  const [creatorId, setCreatorId] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [successId, setSuccessId] = useState<string | null>(null);
  const [topUpError, setTopUpError] = useState<string | null>(null);
  const [showPaymentModal, setShowPaymentModal] = useState(false);
  const [paymentStep, setPaymentStep] = useState<"input" | "processing" | "success">("input");
  const [topUpAmount, setTopUpAmount] = useState(49);
  const [topUpClientSecret, setTopUpClientSecret] = useState<string | null>(null);
  const [topUpInitLoading, setTopUpInitLoading] = useState(false);
  const [walletCoins, setWalletCoins] = useState<number | null>(null);
  const [walletLoading, setWalletLoading] = useState(false);
  const [showProjectPicker, setShowProjectPicker] = useState(false);
  const [projectQuery, setProjectQuery] = useState("");
  const [gameScope, setGameScope] = useState<"all" | "my" | "arcade">("all");

  useEffect(() => {
    // Keep default behavior for "My" projects, but allow arcade IDs that aren't part of projects.
    if (!selectedGameId && selectedProjectId) {
      setSelectedGameId(String(selectedProjectId));
    }
  }, [selectedProjectId, selectedGameId]);

  const defaultStartsAt = useMemo(() => new Date(Date.now() + 10 * 60_000).toISOString().slice(0, 16), []);
  const defaultEndsAt = useMemo(() => new Date(Date.now() + 70 * 60_000).toISOString().slice(0, 16), []);

  const [form, setForm] = useState<CreateForm>({
    title: "Weekly Challenge Arena",
    entryFee: 100,
    maxPlayers: 32,
    startsAt: defaultStartsAt,
    endsAt: defaultEndsAt,
    mode: "score-run",
  });

  useEffect(() => {
    let cancelled = false;
    (async () => {
      if (!token) return;
      try {
        const profile = await apiFetch<any>("/auth/profile", { method: "GET", token: token || undefined });
        const user = profile?.user || profile?.data?.user || profile?.data || profile;
        const id = String(user?.id || user?._id || user?.sub || user?.username || user?.email || "").trim();
        if (!cancelled && id) setCreatorId(id);
      } catch {
        // keep fallback creator id
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [token]);

  async function loadWallet(opts?: { attempts?: number }) {
    if (!creatorId.trim()) return;
    const attempts = Math.max(1, Math.trunc(opts?.attempts ?? 1));

    setWalletLoading(true);
    try {
      for (let i = 0; i < attempts; i++) {
        const data = await apiFetch<any>(`/platform-labs/tournaments/wallet/${encodeURIComponent(creatorId.trim())}`,
          {
            method: "GET",
            token: token || undefined,
          },
        );

        const coinsRaw = (data as any)?.coins;
        const n = Number(coinsRaw);
        const coins = Number.isFinite(n) ? Math.max(0, Math.trunc(n)) : 0;
        setWalletCoins(coins);

        if (coins > 0) break;
        if (i < attempts - 1) {
          await new Promise((r) => window.setTimeout(r, 850));
        }
      }
    } catch {
      setWalletCoins(null);
    } finally {
      setWalletLoading(false);
    }
  }

  useEffect(() => {
    void loadWallet({ attempts: 1 });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [creatorId]);

  const allAvailableGames = useMemo(() => {
    const userProjects = projects.map((p) => ({ ...p, isArcade: false }));
    const publicGames = arcadeGames.map((t) => ({
      id: t.projectId || t.id || t._id,
      name: t.name || t.title,
      status: t.status || "ready",
      previewImageUrl: normalizeImageUrl(
        t.previewImageUrl || t.thumbnailUrl || t.iconUrl || t.imageUrl,
      ),
      isArcade: true,
    }));

    // Dedupe by ID in case user owns a public template
    const map = new Map<string, any>();
    [...publicGames, ...userProjects].forEach((g) => {
      if (g.id) map.set(String(g.id), g);
    });
    return Array.from(map.values());
  }, [projects, arcadeGames]);

  const selectedGame = useMemo(() => {
    const id = String(selectedGameId || "").trim();
    if (!id) return null;
    return (
      allAvailableGames.find((g) => String(g?.id || "").trim() === id) ||
      (selectedProject as any) ||
      null
    );
  }, [allAvailableGames, selectedGameId, selectedProject]);

  const filteredProjects = useMemo(() => {
    const q = projectQuery.trim().toLowerCase();
    const scoped = allAvailableGames.filter((g: any) => {
      if (gameScope === "my") return !g?.isArcade;
      if (gameScope === "arcade") return !!g?.isArcade;
      return true;
    });

    const searched = !q
      ? scoped
      : scoped.filter((p) => {
        const name = String(p?.name || "").toLowerCase();
        const desc = String((p as any)?.description || "").toLowerCase();
        return name.includes(q) || desc.includes(q) || String(p?.id || "").toLowerCase().includes(q);
      });

    const scoreStatus = (s: any) => {
      const st = String(s || "").toLowerCase();
      if (st === "ready") return 0;
      if (st === "running") return 1;
      return 2;
    };

    return searched
      .slice()
      .sort((a: any, b: any) => {
        const aa = a?.isArcade ? 0 : 1;
        const bb = b?.isArcade ? 0 : 1;
        if (aa !== bb) return aa - bb;
        const sa = scoreStatus(a?.status);
        const sb = scoreStatus(b?.status);
        if (sa !== sb) return sa - sb;
        return String(a?.name || "").localeCompare(String(b?.name || ""));
      });
  }, [allAvailableGames, projectQuery, gameScope]);

  useEffect(() => {
    const topup = searchParams?.get("topup");
    if (topup === "success") {
      setTopUpError(null);
      setPaymentStep("success");
      setShowPaymentModal(true);
      void loadWallet({ attempts: 4 });
    } else if (topup === "cancel") {
      setTopUpError("Stripe top-up was canceled.");
      setPaymentStep("input");
      setShowPaymentModal(true);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  async function initTopUpPaymentIntent(nextAmount?: number) {
    setTopUpError(null);
    if (!STRIPE_PUBLISHABLE_KEY) {
      setTopUpError("Missing NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY");
      return;
    }
    if (!creatorId.trim()) {
      setTopUpError("Sign in required before top-up.");
      return;
    }
    const amt = Number(nextAmount ?? topUpAmount);
    if (!Number.isFinite(amt) || amt <= 0) {
      setTopUpError("Please enter a valid amount.");
      return;
    }

    try {
      setTopUpInitLoading(true);
      setPaymentStep("processing");
      setTopUpClientSecret(null);
      const data = await apiFetch<{ clientSecret?: string }>("/platform-labs/tournaments/wallet/top-up/payment-intent", {
        method: "POST",
        token: token || undefined,
        body: {
          userId: creatorId.trim(),
          amountUsd: Math.round(amt * 100) / 100,
        },
      });

      const cs = String((data as any)?.clientSecret || "").trim();
      if (!cs) throw new Error("Missing Stripe client secret");
      setTopUpClientSecret(cs);
      setPaymentStep("input");
    } catch (e: unknown) {
      const msg = e instanceof ApiError ? e.message : e instanceof Error ? e.message : "Top-up init failed";
      setPaymentStep("input");
      setTopUpError(msg);
    } finally {
      setTopUpInitLoading(false);
    }
  }

  async function submit() {
    setLoading(true);
    setError(null);
    setSuccessId(null);
    try {
      if (!creatorId.trim()) throw new Error("Missing creator identity");
      if (!selectedGameId) throw new Error("Choose a game");
      if (!form.title.trim()) throw new Error("Tournament title is required");

      const startsAtIso = new Date(form.startsAt).toISOString();
      const endsAtIso = new Date(form.endsAt).toISOString();

      const created = await apiFetch<any>("/platform-labs/tournaments/create", {
        method: "POST",
        token: token || undefined,
        body: {
          creatorId: creatorId.trim(),
          gameId: selectedGameId,
          title: form.title.trim(),
          mode: form.mode.trim() || "score-run",
          seasonId: `season_${new Date().getFullYear()}`,
          entryFee: Math.max(0, Math.trunc(form.entryFee || 0)),
          maxPlayers: Math.max(2, Math.trunc(form.maxPlayers || 2)),
          startsAt: startsAtIso,
          endsAt: endsAtIso,
          coverImageUrl: (selectedGame as any)?.previewImageUrl,
          gameConfig: {
            projectName: (selectedGame as any)?.name,
          },
        },
      });

      const tid = String(created?.id || created?._id || "").trim();
      setSuccessId(tid || "created");
    } catch (e: unknown) {
      const msg = e instanceof ApiError ? e.message : e instanceof Error ? e.message : "Failed to create tournament";
      setError(msg);
      const lower = String(msg || "").toLowerCase();
      if (lower.includes("wallet not funded") || lower.includes("top up") || lower.includes("topup")) {
        window.setTimeout(() => {
          setPaymentStep("input");
          setShowPaymentModal(true);
        }, 650);
      }
    } finally {
      setLoading(false);
    }
  }

  return (
    <UserShell title="Create Tournament" subtitle="A premium creator flow wired to real backend rules, wallet, and Stripe.">
      <div className="space-y-5">
        {error ? <div className="rounded-xl border border-rose-500/30 bg-rose-500/10 px-4 py-3 text-sm text-rose-200">{error}</div> : null}
        {successId ? (
          <div className="rounded-xl border border-emerald-500/30 bg-emerald-500/10 px-4 py-3 text-sm text-emerald-100 flex items-center gap-2">
            <CheckCircle2 size={16} /> Tournament created successfully ({successId}).
          </div>
        ) : null}

        <motion.div
          initial={{ opacity: 0, y: 14 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ type: "spring", stiffness: 220, damping: 22 }}
          className="relative overflow-hidden rounded-2xl border border-white/[0.05] bg-[#07080f]"
          style={{ boxShadow: "0 24px 90px rgba(0,0,0,0.45)" }}
        >
          <div className="absolute inset-0 " />
          <div className="relative p-6">
            <div className="flex flex-wrap items-start justify-between gap-4">
              <div className="min-w-[260px]">
                <div className="inline-flex items-center gap-2 rounded-full border border-white/[0.05] bg-white/[0.02] px-3 py-1 text-[10px] font-semibold tracking-wider text-white">
                  <Sparkles size={12} /> Creator Arena Setup
                </div>
                <div className="mt-3 text-3xl font-semibold tracking-tight text-white">Tournament Forge</div>
                <div className="mt-1 text-sm text-zinc-300">
                  Build an event with a real entry fee, live leaderboard, and server-driven payouts.
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
                  onClick={submit}
                  disabled={loading}
                  className="rounded-xl border border-white/[0.05] bg-white/[0.05] hover:bg-white/[0.08] px-5 py-2 text-xs font-semibold tracking-wide text-white shadow-sm disabled:opacity-60 transition-all hover:brightness-110 active:scale-[0.98]"
                >
                  {loading ? "Creating..." : "Create Tournament"}
                </button>
              </div>
            </div>

            <div className="mt-6 grid grid-cols-1 gap-4 lg:grid-cols-12">
              <div className="lg:col-span-7 space-y-4">
                <motion.div
                  initial={{ opacity: 0, y: 10 }}
                  animate={{ opacity: 1, y: 0 }}
                  transition={{ delay: 0.05, type: "spring", stiffness: 220, damping: 22 }}
                  className="rounded-xl border border-blue-400/15 bg-gradient-to-r from-blue-500/10 via-cyan-500/10 to-black/20 p-5"
                >
                  <div className="flex flex-wrap items-center justify-between gap-3">
                    <div>
                      <div className="text-[11px] font-semibold tracking-wider text-zinc-400">Funding</div>
                      <div className="mt-1 text-sm font-semibold text-zinc-200">
                        Top up your wallet with Stripe, then use coins as entry fees and payouts.
                      </div>
                      <div className="mt-3 flex flex-wrap items-center gap-2">
                        <div className="inline-flex items-center gap-2 rounded-full border border-white/[0.05] bg-[#07080f] px-3 py-1.5">
                          <Coins size={14} className="text-amber-400" />
                          <span className="text-[11px] font-semibold tracking-wide text-zinc-400">Balance</span>
                          <span className="text-sm font-semibold text-white">
                            {walletLoading ? "…" : walletCoins == null ? "—" : walletCoins.toLocaleString()}
                          </span>
                          <span className="text-[11px] text-zinc-400">coins</span>
                        </div>
                        {walletCoins != null && walletCoins < Math.max(0, Math.trunc(form.entryFee || 0)) ? (
                          <div className="rounded-full border border-amber-500/20 bg-amber-500/10 px-3 py-1.5 text-[11px] font-bold text-amber-200">
                            Insufficient for entry fee
                          </div>
                        ) : null}
                        <button
                          onClick={() => void loadWallet({ attempts: 1 })}
                          className="rounded-full border border-white/[0.05] bg-white/[0.02] px-3 py-1.5 text-[10px] font-semibold tracking-wide text-zinc-200 hover:bg-white/10"
                        >
                          Refresh
                        </button>
                      </div>
                    </div>
                    <button
                      onClick={() => {
                        setTopUpError(null);
                        setPaymentStep("input");
                        setTopUpClientSecret(null);
                        setShowPaymentModal(true);
                        void initTopUpPaymentIntent(topUpAmount);
                      }}
                      className="rounded-xl border border-white/[0.05] bg-white text-black px-4 py-2 text-[10px] font-semibold tracking-wide hover:bg-blue-50 transition-colors"
                    >
                      Fund Wallet via Stripe
                    </button>
                  </div>
                </motion.div>

                <motion.div
                  initial={{ opacity: 0, y: 10 }}
                  animate={{ opacity: 1, y: 0 }}
                  transition={{ delay: 0.1, type: "spring", stiffness: 220, damping: 22 }}
                  className="rounded-xl border border-white/[0.05] bg-[#07080f] p-5"
                >
                  <div className="text-[11px] font-semibold tracking-wider text-zinc-400">Core Details</div>
                  <div className="mt-4 grid grid-cols-1 gap-4">
                    <div>
                      <label className="block text-[11px] font-semibold tracking-wider text-zinc-400">Creator ID</label>
                      <input value={creatorId} readOnly className="gf-input w-full rounded-xl p-3 opacity-70" />
                    </div>

                    <div>
                      <label className="block text-[11px] font-semibold tracking-wider text-zinc-400">Tournament title</label>
                      <input
                        value={form.title}
                        onChange={(e) => setForm((f) => ({ ...f, title: e.target.value }))}
                        className="gf-input w-full rounded-xl p-3"
                      />
                    </div>

                    <div>
                      <label className="block text-[11px] font-semibold tracking-wider text-zinc-400">Project / Game</label>
                      <button
                        type="button"
                        onClick={() => {
                          setProjectQuery("");
                          setShowProjectPicker(true);
                        }}
                        className="gf-input w-full rounded-xl p-3 text-left flex items-center justify-between gap-3"
                      >
                        <div className="min-w-0">
                          <div className="text-sm font-semibold text-white truncate">{(selectedGame as any)?.name || "Choose a game"}</div>
                          <div className="text-[11px] text-zinc-500 truncate">{(selectedGame as any)?.status || ""}</div>
                        </div>
                        <div className="text-zinc-400 text-xs font-semibold tracking-wide">Pick</div>
                      </button>
                    </div>
                  </div>
                </motion.div>

                <div className="rounded-xl border border-white/[0.05] bg-[#07080f] p-5">
                  <div className="text-[11px] font-semibold tracking-wider text-zinc-400">Rules & Timing</div>
                  <div className="mt-4 grid grid-cols-1 gap-4">
                    <div className="grid grid-cols-1 gap-3 md:grid-cols-2">
                      <div>
                        <label className="block text-[11px] font-semibold tracking-wider text-zinc-400">Entry fee</label>
                        <input
                          type="number"
                          min={0}
                          value={form.entryFee}
                          onChange={(e) => setForm((f) => ({ ...f, entryFee: Number(e.target.value || 0) }))}
                          className="gf-input w-full rounded-xl p-3"
                        />
                      </div>
                      <div>
                        <label className="block text-[11px] font-semibold tracking-wider text-zinc-400">Max players</label>
                        <input
                          type="number"
                          min={2}
                          value={form.maxPlayers}
                          onChange={(e) => setForm((f) => ({ ...f, maxPlayers: Number(e.target.value || 2) }))}
                          className="gf-input w-full rounded-xl p-3"
                        />
                      </div>
                    </div>

                    <div className="grid grid-cols-1 gap-3 md:grid-cols-2">
                      <div>
                        <label className="block text-[11px] font-semibold tracking-wider text-zinc-400">Starts at</label>
                        <input
                          type="datetime-local"
                          value={form.startsAt}
                          onChange={(e) => setForm((f) => ({ ...f, startsAt: e.target.value }))}
                          className="gf-input w-full rounded-xl p-3"
                        />
                      </div>

                      <div>
                        <label className="block text-[11px] font-semibold tracking-wider text-zinc-400">Ends at</label>
                        <input
                          type="datetime-local"
                          value={form.endsAt}
                          onChange={(e) => setForm((f) => ({ ...f, endsAt: e.target.value }))}
                          className="gf-input w-full rounded-xl p-3"
                        />
                      </div>
                    </div>

                    <div>
                      <label className="block text-[11px] font-semibold tracking-wider text-zinc-400">Mode</label>
                      <input
                        value={form.mode}
                        onChange={(e) => setForm((f) => ({ ...f, mode: e.target.value }))}
                        className="gf-input w-full rounded-xl p-3"
                      />
                    </div>
                  </div>
                </div>
              </div>

              <div className="lg:col-span-5 space-y-4">
                <div className="rounded-xl border border-white/[0.05] bg-[#07080f] overflow-hidden">
                  <div className="relative h-48">
                    {(selectedGame as any)?.previewImageUrl ? (
                      // eslint-disable-next-line @next/next/no-img-element
                      <img src={(selectedGame as any).previewImageUrl} alt="" className="h-full w-full object-cover" />
                    ) : (
                      <div className="h-full w-full bg-gradient-to-br from-blue-500/25 via-cyan-500/10 to-black/10" />
                    )}
                    <div className="absolute inset-0 bg-gradient-to-t from-black/85 via-black/20 to-transparent" />
                    <div className="absolute left-5 right-5 bottom-4">
                      <div className="text-xs font-semibold tracking-wider text-cyan-200/90">Selected Game</div>
                      <div className="mt-1 text-xl font-semibold text-white tracking-tight">{(selectedGame as any)?.name || "Choose a game"}</div>
                      <div className="mt-1 text-sm text-zinc-300">{(selectedGame as any)?.status || ""}</div>
                    </div>
                  </div>
                  <div className="p-5">
                    <div className="grid grid-cols-3 gap-3">
                      <div className="rounded-xl border border-white/[0.05] bg-white/[0.02] p-3">
                        <div className="text-[10px] font-semibold tracking-wider text-zinc-400">Entry</div>
                        <div className="mt-1 text-lg font-semibold text-white">{Math.max(0, Math.trunc(form.entryFee || 0))}</div>
                        <div className="text-[11px] text-zinc-400">coins</div>
                      </div>
                      <div className="rounded-xl border border-white/[0.05] bg-white/[0.02] p-3">
                        <div className="text-[10px] font-semibold tracking-wider text-zinc-400">Capacity</div>
                        <div className="mt-1 text-lg font-semibold text-white">{Math.max(2, Math.trunc(form.maxPlayers || 2))}</div>
                        <div className="text-[11px] text-zinc-400">players</div>
                      </div>
                      <div className="rounded-xl border border-white/[0.05] bg-white/[0.02] p-3">
                        <div className="text-[10px] font-semibold tracking-wider text-zinc-400">Mode</div>
                        <div className="mt-1 text-sm font-semibold text-white truncate">{form.mode || "score-run"}</div>
                        <div className="text-[11px] text-zinc-400">rule</div>
                      </div>
                    </div>

                    <div className="mt-4 rounded-xl border border-white/[0.05] bg-[#07080f] p-4 text-sm text-zinc-200 flex items-center gap-2">
                      <Trophy size={16} className="text-amber-300" />
                      Prize split is handled by backend (Top 3), and all join/leaderboard/finish logic is server-driven.
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </motion.div>

        {showPaymentModal ? (
          <div className="fixed inset-0 z-[70] flex items-center justify-center bg-black/85 backdrop-blur-xl p-4">
            <div className="w-full max-w-md overflow-hidden rounded-2xl border border-white/[0.05] bg-[#0d0d12] shadow-sm">
              <div className="relative p-6 text-center">
                <div className="flex items-center justify-between mb-4">
                  <h2 className="text-xl font-bold text-white tracking-tight">Tournament Wallet Top-up</h2>
                  <button
                    onClick={() => {
                      setShowPaymentModal(false);
                      setPaymentStep("input");
                      setTopUpError(null);
                      setTopUpClientSecret(null);
                    }}
                    className="rounded-full bg-white/[0.02] p-2 text-zinc-400 hover:bg-white/10 transition-colors"
                  >
                    <X size={18} />
                  </button>
                </div>
                <p className="text-left text-xs text-zinc-500 mb-6 -mt-3">Pay securely with Stripe. Funds are credited to your tournament wallet automatically.</p>

                {topUpError ? (
                  <div className="mb-4 rounded-xl border border-rose-500/30 bg-rose-500/10 px-4 py-3 text-sm text-rose-200 text-left">{topUpError}</div>
                ) : null}

                {paymentStep === "input" && (
                  <div className="space-y-5 animate-in fade-in duration-500">
                    <div className="rounded-xl bg-[#07080f] border border-white/5 p-3">
                      <div className="text-[10px] font-semibold text-zinc-500 tracking-wide mb-2">Montant</div>
                      <div className="flex items-center justify-between gap-3">
                        <div className="flex gap-2">
                          {[10, 49, 100].map((v) => (
                            <button
                              key={v}
                              onClick={() => {
                                setTopUpAmount(v);
                                void initTopUpPaymentIntent(v);
                              }}
                              className={`rounded-lg px-3 py-1.5 text-xs font-semibold transition-all ${
                                topUpAmount === v ? "bg-blue-500 text-white" : "bg-white/[0.02] text-zinc-400 hover:bg-white/10"
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
                            className="bg-transparent text-right text-lg font-semibold text-white outline-none w-24"
                          />
                        </div>
                      </div>
                    </div>

                    {topUpInitLoading || !topUpClientSecret || !stripePromise ? (
                      <div className="rounded-xl border border-white/[0.05] bg-[#07080f] p-4 text-left">
                        <div className="flex items-center justify-between gap-3">
                          <div>
                            <div className="text-[10px] font-semibold tracking-wide text-zinc-500">Payment</div>
                            <div className="mt-1 text-xs text-zinc-300">Preparing secure card form...</div>
                          </div>
                          <button
                            onClick={() => void initTopUpPaymentIntent(topUpAmount)}
                            className="rounded-xl bg-white/[0.02] px-3 py-2 text-[10px] font-semibold tracking-wide text-zinc-200 hover:bg-white/10"
                          >
                            Refresh
                          </button>
                        </div>
                      </div>
                    ) : (
                      <Elements
                        stripe={stripePromise}
                        options={{
                          clientSecret: topUpClientSecret as string,
                          appearance: {
                            theme: "night",
                            variables: {
                              colorPrimary: "#38bdf8",
                              colorBackground: "#0b0b10",
                              colorText: "#e4e4e7",
                              colorDanger: "#fb7185",
                            },
                          },
                        }}
                      >
                        <TopUpCheckoutForm
                          amount={topUpAmount}
                          userId={creatorId}
                          token={token}
                          onCancel={() => {
                            setShowPaymentModal(false);
                            setPaymentStep("input");
                            setTopUpError(null);
                            setTopUpClientSecret(null);
                          }}
                          onSuccess={() => {
                            setPaymentStep("success");
                            void loadWallet({ attempts: 4 });
                          }}
                        />
                      </Elements>
                    )}
                  </div>
                )}

                {paymentStep === "processing" && (
                  <div className="py-20 flex flex-col items-center animate-in zoom-in duration-500">
                    <div className="relative h-20 w-20">
                      <div className="absolute inset-0 rounded-full border-4 border-blue-500/20 border-t-blue-500 animate-spin" />
                    </div>
                    <h2 className="mt-8 text-xl font-semibold text-white uppercase italic">Processing...</h2>
                    <p className="mt-2 text-sm text-zinc-500 font-medium tracking-wide">Preparing secure payment</p>
                  </div>
                )}

                {paymentStep === "success" && (
                  <div className="py-12 flex flex-col items-center animate-in zoom-in duration-500">
                    <div className="rounded-full bg-emerald-500/20 p-6 text-emerald-400 mb-6 shadow-[0_0_50px_rgba(16,185,129,0.3)]">
                      <CheckCircle2 size={64} />
                    </div>
                    <h2 className="text-3xl font-semibold text-white italic tracking-tighter">Success!</h2>
                    <p className="mt-2 text-zinc-400 font-medium">Wallet charged from Stripe payment</p>
                    <button
                      onClick={() => {
                        setShowPaymentModal(false);
                        setPaymentStep("input");
                        setTopUpError(null);
                      }}
                      className="mt-10 rounded-xl border border-white/[0.05] bg-white/[0.02] px-10 py-3 text-xs font-semibold tracking-wide text-white hover:bg-white/10"
                    >
                      Back to Create
                    </button>
                  </div>
                )}
              </div>
            </div>
          </div>
        ) : null}

        {showProjectPicker ? (
          <div className="fixed inset-0 z-[72] flex items-center justify-center bg-black/85 backdrop-blur-xl p-4">
            <div className="w-full max-w-3xl overflow-hidden rounded-2xl border border-white/[0.05] bg-[#0d0d12] shadow-sm">
              <div className="p-6">
                <div className="flex items-center justify-between gap-3">
                  <div>
                    <div className="text-[10px] font-semibold tracking-wider text-zinc-500">Project / Game</div>
                    <div className="mt-1 text-xl font-semibold text-white tracking-tight">Choose your arena</div>
                    <div className="mt-1 text-xs text-zinc-500">Arcade-style picker with real project media.</div>
                  </div>
                  <button
                    onClick={() => setShowProjectPicker(false)}
                    className="rounded-full bg-white/[0.02] p-2 text-zinc-400 hover:bg-white/10 transition-colors"
                  >
                    <X size={18} />
                  </button>
                </div>

                <div className="mt-5 flex flex-wrap items-center gap-3">
                  <div className="inline-flex items-center rounded-full border border-white/[0.05] bg-white/[0.02] p-1">
                    {([
                      { k: "all", label: "All" },
                      { k: "my", label: "My" },
                      { k: "arcade", label: "Arcade" },
                    ] as const).map((x) => (
                      <button
                        key={x.k}
                        type="button"
                        onClick={() => setGameScope(x.k)}
                        className={`rounded-full px-3 py-1.5 text-[10px] font-semibold tracking-wide transition-all ${
                          gameScope === x.k
                            ? "bg-gradient-to-r from-cyan-500/30 to-blue-500/20 text-cyan-50 border border-cyan-300/20"
                            : "text-zinc-400 hover:text-zinc-200"
                        }`}
                      >
                        {x.label}
                      </button>
                    ))}
                  </div>
                  <input
                    value={projectQuery}
                    onChange={(e) => setProjectQuery(e.target.value)}
                    placeholder="Search games (your projects + public arcade)…"
                    className="gf-input flex-1 min-w-[220px] rounded-xl p-3"
                  />
                  <div className="rounded-full border border-white/[0.05] bg-white/[0.02] px-3 py-1.5 text-[10px] font-semibold tracking-wide text-zinc-300">
                    {filteredProjects.length} results
                  </div>
                  {arcadeLoading ? (
                    <div className="rounded-full border border-cyan-300/20 bg-cyan-500/10 px-3 py-1.5 text-[10px] font-semibold tracking-wide text-white">
                      Loading arcade…
                    </div>
                  ) : null}
                </div>

                <div className="mt-5 grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3 max-h-[60vh] overflow-auto pr-1">
                  {arcadeLoading && filteredProjects.length === 0 ? (
                    <div className="rounded-xl border border-white/[0.05] bg-[#07080f] p-5 text-sm text-zinc-400 sm:col-span-2 lg:col-span-3">
                      Loading public arcade games…
                    </div>
                  ) : null}
                  {filteredProjects.map((p) => {
                    const selected = String(p.id) === String(selectedGameId);
                    const status = String(p?.status || "").toLowerCase();
                    const canSelect = status === "ready";
                    const statusUi =
                      status === "ready"
                        ? { label: "READY", cls: "border-emerald-300/25 bg-emerald-500/10 text-emerald-100" }
                        : status === "running"
                          ? { label: "RUNNING", cls: "border-cyan-300/25 bg-cyan-500/10 text-white" }
                          : { label: String(p?.status || "").toUpperCase() || "—", cls: "border-white/[0.05] bg-white/[0.02] text-zinc-300" };
                    return (
                      <button
                        key={p.id}
                        disabled={!canSelect}
                        onClick={() => {
                          if (!canSelect) return;
                          setSelectedGameId(String(p.id));
                          setShowProjectPicker(false);
                        }}
                        className={`text-left rounded-xl border overflow-hidden transition-all ${
                          selected
                            ? "border-cyan-300/40 bg-gradient-to-br from-cyan-500/15 via-blue-500/10 to-black/40"
                            : canSelect
                              ? "border-white/[0.05] bg-[#07080f] hover:border-white/25 hover:bg-[#07080f]"
                              : "border-white/[0.05] bg-[#07080f]/50 opacity-60 cursor-not-allowed"
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
                          <div className="absolute left-3 top-3 flex items-center gap-2">
                            {p.isArcade ? (
                              <div className="rounded-full border border-amber-300/25 bg-amber-500/10 px-2 py-1 text-[9px] font-semibold tracking-wider text-amber-100">
                                Arcade
                              </div>
                            ) : (
                              <div className="rounded-full border border-white/[0.05] bg-white/[0.02] px-2 py-1 text-[9px] font-semibold tracking-wider text-zinc-300">
                                Project
                              </div>
                            )}
                            <div className={`rounded-full border px-2 py-1 text-[9px] font-semibold tracking-wider ${statusUi.cls}`}>
                              {statusUi.label}
                            </div>
                          </div>
                          {selected ? (
                            <div className="absolute top-3 right-3 rounded-full border border-white/[0.05] bg-cyan-500/10 px-2 py-1 text-[9px] font-semibold tracking-wider text-white">
                              Selected
                            </div>
                          ) : (!canSelect ? (
                            <div className="absolute top-3 right-3 rounded-full border border-white/[0.05] bg-[#07080f] px-2 py-1 text-[9px] font-semibold tracking-wider text-zinc-200">
                              Not Ready
                            </div>
                          ) : (p.isArcade ? (
                            <div className="absolute top-3 right-3 rounded-full border border-amber-300/30 bg-amber-500/10 px-2 py-1 text-[9px] font-semibold tracking-wider text-amber-100">
                              Hot
                            </div>
                          ) : null))}
                        </div>
                        <div className="p-4">
                          <div className="text-sm font-semibold text-white truncate">{p.name}</div>
                          <div className="mt-1 text-[11px] text-zinc-500 truncate">{p.status || ""}</div>
                        </div>
                      </button>
                    );
                  })}

                  {filteredProjects.length === 0 ? (
                    <div className="rounded-xl border border-white/[0.05] bg-[#07080f] p-5 text-sm text-zinc-400 sm:col-span-2 lg:col-span-3">
                      No projects found.
                    </div>
                  ) : null}
                </div>
              </div>
            </div>
          </div>
        ) : null}
      </div>
    </UserShell>
  );
}
