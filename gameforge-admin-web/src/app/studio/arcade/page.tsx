"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { motion, AnimatePresence } from "framer-motion";
import { Elements, PaymentElement, useElements, useStripe } from "@stripe/react-stripe-js";
import { loadStripe } from "@stripe/stripe-js";
import {
  GameController, Play, Heart, ChatCircleDots, ShareNetwork,
  Trophy, Users, MagnifyingGlass as Search, Lightning,
  TrendUp as TrendingUp, X, Crown, Medal, CurrencyDollar,
  ArrowSquareOut, Compass, PaperPlaneTilt
} from "@phosphor-icons/react";
import UserShell from "@/app/_components/UserShell";
import { useToast } from "@/app/_components/ToastProvider";
import { apiFetch, API_BASE_URL } from "@/lib/api";
import { clearUserToken } from "@/lib/userAuth";
import { useAuthToken } from "@/lib/stores/authStore";
import { normalizeImageUrl } from "@/lib/media";

function cx(...parts: Array<string | false | null | undefined>) {
  return parts.filter(Boolean).join(" ");
}

const FEED_PAGE_LIMIT = 40;
const STRIPE_PUBLISHABLE_KEY = process.env.NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY || "";
const stripePromise = STRIPE_PUBLISHABLE_KEY ? loadStripe(STRIPE_PUBLISHABLE_KEY) : null;

type FeedPage = {
  items: any[];
  nextCursor: string | null;
  unauthorized?: boolean;
  errorMessage?: string | null;
};
type FeedComment = {
  id: string;
  userId?: string;
  username?: string;
  text?: string;
  avatarUrl?: string;
  createdAt?: string;
};

type InstantArcadeGame = {
  id: string;
  title: string;
  description: string;
  tags: string[];
  thumbUrl: string;
  playUrl: string;
  source?: "instant" | "phaser" | "threejs";
};

async function fetchInstantArcadeGames(): Promise<InstantArcadeGame[]> {
  const url = `${API_BASE_URL}/instant-arcade/games`;
  const res = await fetch(url, {
    method: "GET",
    headers: { Accept: "application/json" },
    cache: "no-store",
  });
  const json = await res.json().catch(() => null);
  const list = Array.isArray(json?.data) ? json.data : [];
  return list as InstantArcadeGame[];
}

async function fetchFeedPage(token: string | null, cursor?: string | null): Promise<FeedPage> {
  const qp = new URLSearchParams();
  qp.set("limit", String(FEED_PAGE_LIMIT));
  if (cursor && cursor.trim()) qp.set("cursor", cursor.trim());

  const url = `${API_BASE_URL}/game-feed?${qp.toString()}`;
  const res = await fetch(url, {
    method: "GET",
    headers: {
      Accept: "application/json",
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    cache: "no-store",
  });

  const json = await res.json().catch(() => null);
  if (!res.ok) {
    const msg = json?.message || `Failed to load arcade feed (${res.status})`;
    if (res.status === 401 || res.status === 403) {
      return {
        items: [],
        nextCursor: null,
        unauthorized: true,
        errorMessage: "Session expired. Please login again.",
      };
    }
    return {
      items: [],
      nextCursor: null,
      unauthorized: false,
      errorMessage: msg,
    };
  }

  const list = Array.isArray(json?.data)
    ? json.data
    : Array.isArray(json?.data?.items)
      ? json.data.items
      : [];

  const nextCursor = String(json?.nextCursor || json?.data?.nextCursor || "").trim() || null;
  return { items: list, nextCursor };
}

function TipCardPaymentForm({
  amountUsd,
  onBack,
  onCancel,
  onSuccess,
}: {
  amountUsd: number;
  onBack: () => void;
  onCancel: () => void;
  onSuccess: (paymentIntentId?: string) => Promise<void>;
}) {
  const stripe = useStripe();
  const elements = useElements();
  const [processing, setProcessing] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!stripe || !elements || processing) return;

    setProcessing(true);
    setError(null);

    try {
      const res = await stripe.confirmPayment({
        elements,
        redirect: "if_required",
      });

      if (res.error) {
        setError(res.error.message || "Payment confirmation failed.");
        setProcessing(false);
        return;
      }

      const status = String(res.paymentIntent?.status || "").toLowerCase();
      if (!["succeeded", "processing", "requires_capture"].includes(status)) {
        setError(status ? `Payment status: ${status}` : "Payment not completed.");
        setProcessing(false);
        return;
      }

      await onSuccess(res.paymentIntent?.id);
    } catch (e: any) {
      setError(e?.message || "Unexpected payment error.");
    } finally {
      setProcessing(false);
    }
  };

  return (
    <form onSubmit={submit} className="space-y-4">
      <div className="rounded-xl border border-white/10 bg-white/[0.03] p-3">
        <div className="text-[10px] uppercase tracking-[0.24em] text-zinc-500 font-black">Secure card payment</div>
        <div className="mt-1 text-sm text-zinc-200">Amount: ${Number(amountUsd || 0).toFixed(2)}</div>
      </div>

      <PaymentElement
        options={{
          layout: { type: "tabs", defaultCollapsed: false },
          paymentMethodOrder: ["link", "card"],
        }}
      />

      {error ? (
        <div className="rounded-xl border border-rose-500/35 bg-rose-500/10 px-3 py-2 text-xs text-rose-200">{error}</div>
      ) : null}

      <div className="rounded-xl border border-emerald-500/25 bg-emerald-500/10 px-3 py-2 text-xs text-emerald-100 font-semibold">
        🔒 Payment stays in-app and is credited to the creator wallet.
      </div>

      <div className="flex items-center gap-2">
        <button
          type="button"
          onClick={onBack}
          disabled={processing}
          className="rounded-xl border border-white/15 bg-white/[0.03] px-4 py-3 text-xs font-black uppercase tracking-wide text-zinc-200 disabled:opacity-40"
        >
          Back
        </button>
        <button
          type="button"
          onClick={onCancel}
          disabled={processing}
          className="rounded-xl border border-white/15 bg-white/[0.03] px-4 py-3 text-xs font-black uppercase tracking-wide text-zinc-200 disabled:opacity-40"
        >
          Cancel
        </button>
        <button
          type="submit"
          disabled={!stripe || processing}
          className="flex-1 rounded-xl border border-emerald-500/35 bg-emerald-500/20 px-4 py-3 text-sm font-black uppercase tracking-wide text-emerald-100 disabled:opacity-40"
        >
          {processing ? "Processing…" : `Pay $${Number(amountUsd || 0).toFixed(2)}`}
        </button>
      </div>
    </form>
  );
}

export default function ArcadeFeedPage() {
  const router = useRouter();
  const toast = useToast();
  const { token } = useAuthToken();
  const authRedirectScheduledRef = useRef(false);
  const [loading, setLoading] = useState(true);
  const [items, setItems] = useState<any[]>([]);
  const [leaderboard, setLeaderboard] = useState<any[]>([]);
  const [nextCursor, setNextCursor] = useState<string | null>(null);
  const [loadingMore, setLoadingMore] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [search, setSearch] = useState("");
  const scrollerRef = useRef<HTMLDivElement | null>(null);
  const [activeIndex, setActiveIndex] = useState(0);
  const [playingId, setPlayingId] = useState<string | null>(null);
  const [me, setMe] = useState<any>(null);
  const [tipOpen, setTipOpen] = useState(false);
  const [tipCreatorId, setTipCreatorId] = useState("");
  const [tipCreatorName, setTipCreatorName] = useState("creator");
  const [tipAmountUsd, setTipAmountUsd] = useState(5);
  const [tipMessage, setTipMessage] = useState("");
  const [tipStep, setTipStep] = useState<"compose" | "card">("compose");
  const [tipBusy, setTipBusy] = useState(false);
  const [tipClientSecret, setTipClientSecret] = useState<string | null>(null);
  const [tipPaymentIntentId, setTipPaymentIntentId] = useState<string | null>(null);
  const [tipInitError, setTipInitError] = useState<string | null>(null);
  const [tipContextPostId, setTipContextPostId] = useState<string | null>(null);
  const [commentsOpenPostId, setCommentsOpenPostId] = useState<string | null>(null);
  const [commentsByPost, setCommentsByPost] = useState<Record<string, FeedComment[]>>({});
  const [commentsLoadingPostId, setCommentsLoadingPostId] = useState<string | null>(null);
  const [commentDraft, setCommentDraft] = useState("");
  const [commentBusy, setCommentBusy] = useState(false);

  const [instantGames, setInstantGames] = useState<InstantArcadeGame[]>([]);
  const [instantLoading, setInstantLoading] = useState(true);
  const [instantError, setInstantError] = useState<string | null>(null);
  const [instantPlayingId, setInstantPlayingId] = useState<string | null>(null);
  const [instantActiveIndex, setInstantActiveIndex] = useState(0);
  const instantScrollerRef = useRef<HTMLDivElement | null>(null);

  const [feedMode, setFeedMode] = useState<"toilet" | "unity">("unity");

  const handleAuthExpired = () => {
    clearUserToken();
    setError("Session expired. Redirecting to login…");
    if (authRedirectScheduledRef.current) return;
    authRedirectScheduledRef.current = true;
    window.setTimeout(() => {
      const next = encodeURIComponent("/studio/arcade");
      router.push(`/login?reason=expired&next=${next}`);
    }, 700);
  };

  useEffect(() => {
    const params = new URLSearchParams(window.location.search);
    const playId = params.get("play");
    if (playId) {
      setPlayingId(playId);
    }
  }, []);

  useEffect(() => {
    let cancelled = false;
    async function loadInstant() {
      setInstantLoading(true);
      try {
        const list = await fetchInstantArcadeGames();
        if (!cancelled) {
          let sortedList = Array.isArray(list) ? [...list] : [];
          
          // Boost specific games to the top
          const boostIds = [
            "69CF86F21D5AA7940CC6BEFE", // Three.js Platformer
            "69CF73431D5AA7940CC6B59E", // Three.js Runner
            "69CF728E1D5AA7940CC6B522", // Three.js Game Over experience
            "69D2BA15A3DEF30695FFDCB8", // Arkanoid/Brick Breaker
            "69CFC91E0DE0981C90CF9E13"  // Snake
          ];
          
          boostIds.forEach(id => {
            const idx = sortedList.findIndex(g => String(g.id || "").includes(id));
            if (idx > -1) {
              const [game] = sortedList.splice(idx, 1);
              sortedList.unshift(game);
            }
          });
          
          setInstantGames(sortedList);
          setInstantError(null);
        }
      } catch (e: any) {
        if (!cancelled) {
          setInstantGames([]);
          setInstantError(e?.message || "Could not load instant arcade games");
        }
      } finally {
        if (!cancelled) setInstantLoading(false);
      }
    }
    loadInstant();
    return () => {
      cancelled = true;
    };
  }, []);

  useEffect(() => {
    const el = instantScrollerRef.current;
    if (!el) return;
    const onScroll = () => {
      const children = Array.from(el.querySelectorAll('[data-instant-item="1"]')) as HTMLElement[];
      const top = el.scrollTop;
      let bestIdx = 0;
      let bestDist = Number.POSITIVE_INFINITY;
      for (let i = 0; i < children.length; i++) {
        const c = children[i];
        const dist = Math.abs(c.offsetTop - top);
        if (dist < bestDist) {
          bestDist = dist;
          bestIdx = i;
        }
      }
      setInstantActiveIndex(bestIdx);
    };
    el.addEventListener('scroll', onScroll, { passive: true } as any);
    return () => el.removeEventListener('scroll', onScroll as any);
  }, [instantGames.length]);

  useEffect(() => {
    if (feedMode !== "toilet") return;
    const active = instantGames[instantActiveIndex];
    if (!active?.id) return;
    setInstantPlayingId(active.id);
    
    // Force set activeIndex for toilet too if we use common logic
    setActiveIndex(instantActiveIndex);
  }, [feedMode, instantActiveIndex, instantGames]);

  useEffect(() => {
    if (feedMode === "toilet") {
      setPlayingId(null);
      setCommentsOpenPostId(null);
      setTipOpen(false);
    } else {
      setInstantPlayingId(null);
    }
  }, [feedMode]);

  useEffect(() => {
    const onKeyDown = (e: KeyboardEvent) => {
      if (e.key !== "ArrowDown" && e.key !== "ArrowUp") return;
      const t = e.target as HTMLElement | null;
      const tag = (t?.tagName || "").toLowerCase();
      if (tag === "input" || tag === "textarea" || (t as any)?.isContentEditable) return;

      const el = (feedMode === "toilet" ? instantScrollerRef.current : scrollerRef.current);
      if (!el) return;
      const sel = feedMode === "toilet" ? '[data-instant-item="1"]' : "[data-arcade-item='1']";
      const children = Array.from(el.querySelectorAll(sel)) as HTMLElement[];
      if (!children.length) return;
      const curIdx = feedMode === "toilet" ? instantActiveIndex : activeIndex;
      const nextIdx = Math.max(0, Math.min(children.length - 1, curIdx + (e.key === "ArrowDown" ? 1 : -1)));
      const target = children[nextIdx];
      if (!target) return;
      e.preventDefault();
      el.scrollTo({ top: target.offsetTop, behavior: "smooth" });
    };

    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, [feedMode, activeIndex, instantActiveIndex]);

  const patchFeedItem = (id: string, patch: Record<string, any>) => {
    setItems((prev) => prev.map((it: any, idx: number) => (getId(it, idx) === id ? { ...it, ...patch } : it)));
  };

  const openDiscovery = (seed?: string) => {
    const q = String(seed || "").trim();
    const qs = q ? `?q=${encodeURIComponent(q)}` : "";
    router.push(`/studio/discovery${qs}`);
  };

  const handleLike = async (id: string) => {
    if (!token) return;
    try {
      const target = items.find((it: any, idx: number) => getId(it, idx) === id);
      const likedByMe = Boolean(target?.likedByMe);
      const endpoint = likedByMe ? `/game-feed/${id}/unlike` : `/game-feed/${id}/like`;
      const res = await apiFetch<any>(endpoint, { method: "POST", token });
      patchFeedItem(id, {
        likedByMe: typeof res?.liked === "boolean" ? res.liked : !likedByMe,
        likeCount: Number.isFinite(Number(res?.likeCount))
          ? Number(res.likeCount)
          : Math.max(0, Number(target?.likeCount || 0) + (likedByMe ? -1 : 1)),
      });
    } catch (e) { }
  };

  const handleShare = async (id: string) => {
    try {
      if (token) {
        await apiFetch(`/game-feed/${id}/share`, { method: "POST", token });
      }
      const url = `${window.location.origin}/studio/arcade?play=${id}`;
      await navigator.clipboard.writeText(url);
      toast.success("Link copied", "Neural link copied to clipboard.");
    } catch (e) { }
  };

  const handleDonate = async (creatorId: string, creatorName?: string, postId?: string) => {
    if (!token) {
      toast.info("Sign in required", "Please login to send donations.");
      return;
    }
    setTipCreatorId(creatorId);
    setTipCreatorName(String(creatorName || "creator"));
    setTipMessage("");
    setTipAmountUsd(5);
    setTipClientSecret(null);
    setTipPaymentIntentId(null);
    setTipInitError(null);
    setTipStep("compose");
    setTipContextPostId(String(postId || "").trim() || null);
    setCommentsOpenPostId(null);
    setTipOpen(true);
  };

  const closeTipModal = () => {
    setTipOpen(false);
    setTipStep("compose");
    setTipClientSecret(null);
    setTipPaymentIntentId(null);
    setTipInitError(null);
    setTipBusy(false);
  };

  const openTipCardStep = async () => {
    if (!token || !tipCreatorId || tipBusy) return;
    if (!STRIPE_PUBLISHABLE_KEY || !stripePromise) {
      setTipInitError("Stripe key missing on frontend (NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY).");
      return;
    }
    try {
      setTipBusy(true);
      setTipInitError(null);
      setTipClientSecret(null);
      setTipPaymentIntentId(null);
      const safeAmount = Math.max(1, Math.min(50000, Number(tipAmountUsd || 0)));
      const safeMessage = String(tipMessage || "").trim().slice(0, 240);
      const res = await apiFetch<any>("/creator-monetization/payment-sheet", {
        method: "POST",
        token,
        body: {
          creatorUserId: tipCreatorId,
          type: "tip",
          amountUsd: safeAmount,
          message: safeMessage || undefined,
        },
      });

      const clientSecret = String(res?.paymentIntentClientSecret || "").trim();
      const paymentIntentId = String(res?.paymentIntentId || "").trim();
      if (!clientSecret) {
        throw new Error("Missing Stripe client secret from payment-sheet response.");
      }
      setTipClientSecret(clientSecret);
      setTipPaymentIntentId(paymentIntentId || null);
      setTipStep("card");
    } catch (e: any) {
      setTipInitError(e?.message || "Could not initialize in-app payment.");
    } finally {
      setTipBusy(false);
    }
  };

  const confirmTipLedger = async (paymentIntentIdFromStripe?: string) => {
    if (!token) return;
    const paymentIntentId = String(paymentIntentIdFromStripe || tipPaymentIntentId || "").trim();
    if (!paymentIntentId) throw new Error("Missing payment intent id for confirmation.");

    await apiFetch<any>("/creator-monetization/payment-intent/confirm", {
      method: "POST",
      token,
      body: { paymentIntentId },
    });

    toast.success("Tip sent", `Sent successfully to @${tipCreatorName} ✅`);
    closeTipModal();
  };

  const loadComments = async (postId: string) => {
    if (!token || !postId) return;
    try {
      setCommentsLoadingPostId(postId);
      const res = await apiFetch<any>(`/game-feed/${postId}/comments?limit=50`, {
        method: "GET",
        token,
      });
      const list = Array.isArray(res) ? res : Array.isArray(res?.items) ? res.items : [];
      setCommentsByPost((prev) => ({ ...prev, [postId]: list }));
    } catch {
      setCommentsByPost((prev) => ({ ...prev, [postId]: [] }));
    } finally {
      setCommentsLoadingPostId(null);
    }
  };

  const openComments = async (postId: string) => {
    setTipOpen(false);
    setTipContextPostId(null);
    setCommentsOpenPostId(postId);
    setCommentDraft("");
    if (!commentsByPost[postId]?.length) {
      await loadComments(postId);
    }
  };

  const submitComment = async () => {
    const postId = String(commentsOpenPostId || "").trim();
    if (!token || !postId || commentBusy) return;
    const text = String(commentDraft || "").trim();
    if (!text) return;
    try {
      setCommentBusy(true);
      const created = await apiFetch<any>(`/game-feed/${postId}/comments`, {
        method: "POST",
        token,
        body: { text },
      });
      const normalized: FeedComment = {
        ...created,
        id: String(created?.id || created?._id || Date.now()),
      };
      setCommentsByPost((prev) => ({
        ...prev,
        [postId]: [normalized, ...(prev[postId] || [])],
      }));
      patchFeedItem(postId, {
        commentCount: Number.isFinite(Number(created?.commentCount))
          ? Number(created.commentCount)
          : Math.max(0, Number(items.find((it: any, idx: number) => getId(it, idx) === postId)?.commentCount || 0) + 1),
      });
      setCommentDraft("");
    } catch (e: any) {
      toast.error("Comment failed", e?.message || "Could not post your comment");
    } finally {
      setCommentBusy(false);
    }
  };


  useEffect(() => {
    let cancelled = false;
    async function load() {
      setLoading(true);
      try {
        const [feedRes, leaderboardRes, meRes] = await Promise.allSettled([
          fetchFeedPage(token || null, null),
          apiFetch<any>("/daily/creator/leaderboard?period=weekly&limit=12", {
            method: "GET",
            token: token || undefined,
          }),
          apiFetch<any>("/auth/profile", { method: "GET", token: token || undefined }),
        ]);

        if (!cancelled) {
          if (meRes.status === 'fulfilled') {
            const meData = meRes.value?.data || meRes.value;
            setMe(meData?.user || meData);
          }

          if (feedRes.status === 'fulfilled') {
            setItems(Array.isArray(feedRes.value.items) ? feedRes.value.items : []);
            setNextCursor(feedRes.value.nextCursor || null);
            if (feedRes.value.unauthorized) {
              handleAuthExpired();
            }
          } else {
            console.error("Feed error:", feedRes.reason);
            setItems([]);
            setNextCursor(null);
          }

          if (leaderboardRes.status === 'fulfilled') {
            const lbData = leaderboardRes.value;
            const data = (lbData && typeof lbData === "object" && "data" in lbData) ? lbData.data : lbData;
            setLeaderboard(Array.isArray(data) ? data : (Array.isArray(data?.items) ? data.items : []));
          } else {
            setLeaderboard([]);
          }

          if (feedRes.status === 'fulfilled' && feedRes.value.unauthorized) {
            // already handled in handleAuthExpired
          } else if (feedRes.status === 'fulfilled' && feedRes.value.errorMessage) {
            setError(feedRes.value.errorMessage);
          } else if (feedRes.status === 'rejected' && leaderboardRes.status === 'rejected') {
            setError("Arcade systems initializing. Please check back shortly.");
          } else {
            setError(null);
          }
        }
      } catch (e: any) {
        if (!cancelled) setError("Neural link interrupted. Reconnecting...");
      } finally {
        if (!cancelled) setLoading(false);
      }
    }
    load();
    return () => { cancelled = true; };
  }, [token]);

  const loadMoreFeed = async () => {
    if (loading || loadingMore) return;
    if (!nextCursor || !nextCursor.trim()) return;
    try {
      setLoadingMore(true);
      const page = await fetchFeedPage(token || null, nextCursor);
      if (page.unauthorized) {
        handleAuthExpired();
        setNextCursor(null);
        return;
      }
      if (page.errorMessage) {
        setError(page.errorMessage);
        return;
      }
      setItems((prev) => {
        const seen = new Set(prev.map((it: any, idx: number) => getId(it, idx)));
        const fresh = page.items.filter((it: any, idx: number) => !seen.has(getId(it, idx)));
        return [...prev, ...fresh];
      });
      setNextCursor(page.nextCursor || null);
    } catch {
      // silent for infinite-scroll retries
    } finally {
      setLoadingMore(false);
    }
  };

  const filteredItems = useMemo(() => {
    const q = search.trim().toLowerCase();
    if (!q) return items;
    return items.filter(item =>
      [
        item?.title,
        item?.name,
        item?.creatorUsername,
        item?.creator,
        item?.description,
        ...(Array.isArray(item?.tags) ? item.tags : []),
      ]
        .map((x) => String(x || "").toLowerCase())
        .some((s) => s.includes(q))
    );
  }, [items, search]);

  useEffect(() => {
    if (feedMode !== "unity") return;
    const it = filteredItems[activeIndex];
    if (!it) return;
    const id = getId(it, activeIndex);
    setPlayingId(id);
  }, [feedMode, activeIndex, filteredItems]);

  const commentsTargetItem = useMemo(() => {
    const postId = String(commentsOpenPostId || "").trim();
    if (!postId) return null;
    return filteredItems.find((it: any, idx: number) => getId(it, idx) === postId)
      || items.find((it: any, idx: number) => getId(it, idx) === postId)
      || null;
  }, [commentsOpenPostId, filteredItems, items]);

  const tipTargetItem = useMemo(() => {
    const postId = String(tipContextPostId || "").trim();
    if (!postId) return null;
    return filteredItems.find((it: any, idx: number) => getId(it, idx) === postId)
      || items.find((it: any, idx: number) => getId(it, idx) === postId)
      || null;
  }, [tipContextPostId, filteredItems, items]);

  const sidePanelMode = tipOpen ? "tip" : commentsOpenPostId ? "comments" : null;
  const sidePanelPostId = String(tipOpen ? tipContextPostId || "" : commentsOpenPostId || "").trim();

  const discovery = useMemo(() => {
    const tags = new Map<string, number>();
    const creators = new Map<string, { id: string; username: string; avatar?: string; score: number }>();

    for (const it of items) {
      const cId = String(it?.creatorId || it?.ownerId || it?.userId || "").trim();
      const cName = String(it?.creatorUsername || it?.ownerUsername || it?.creator || "creator").trim();
      const cAvatar = normalizeImageUrl(it?.avatarUrl || it?.creatorAvatar || it?.avatar || "");
      const score = Number(it?.playCount || 0) + Number(it?.likeCount || 0) * 2 + Number(it?.wowScore || 0);
      if (cId && cName) {
        const prev = creators.get(cId);
        creators.set(cId, {
          id: cId,
          username: cName,
          avatar: cAvatar || prev?.avatar,
          score: (prev?.score || 0) + score,
        });
      }
      for (const t of Array.isArray(it?.tags) ? it.tags : []) {
        const key = String(t || "").trim().toLowerCase();
        if (!key) continue;
        tags.set(key, (tags.get(key) || 0) + 1);
      }
    }

    return {
      topTags: [...tags.entries()].sort((a, b) => b[1] - a[1]).slice(0, 8),
      topCreators: [...creators.values()].sort((a, b) => b.score - a.score).slice(0, 6),
    };
  }, [items]);

  useEffect(() => {
    if (loading || loadingMore) return;
    if (!nextCursor || search.trim()) return;
    if (!filteredItems.length) return;
    if (activeIndex >= Math.max(0, filteredItems.length - 3)) {
      void loadMoreFeed();
    }
  }, [activeIndex, filteredItems.length, nextCursor, loading, loadingMore, search]);

  useEffect(() => {
    const el = feedMode === "toilet" ? instantScrollerRef.current : scrollerRef.current;
    if (!el) return;

    const sel = feedMode === "toilet" ? '[data-instant-item="1"]' : "[data-arcade-item='1']";
    const children = Array.from(el.querySelectorAll(sel)) as HTMLElement[];
    if (!children.length) return;

    const obs = new IntersectionObserver(
      (entries) => {
        const visible = entries
          .filter((e) => e.isIntersecting)
          .sort((a, b) => (b.intersectionRatio ?? 0) - (a.intersectionRatio ?? 0));
        const top = visible[0];
        if (!top?.target) return;
        const idx = children.indexOf(top.target as HTMLElement);
        if (idx >= 0) {
          if (feedMode === "toilet") setInstantActiveIndex(idx);
          else setActiveIndex(idx);
        }
      },
      { root: el, threshold: [0.6, 0.8, 0.9] },
    );

    for (const c of children) obs.observe(c);
    return () => obs.disconnect();
  }, [filteredItems.length, instantGames.length, feedMode, loading, loadingMore]);

  function getId(it: any, idx: number) {
    return String(it?.id || it?._id || it?.projectId || it?.buildId || `item-${idx}`);
  }

  function getTitle(it: any) {
    return String(it?.title || it?.name || "Untitled");
  }

  function getCreatorId(it: any) {
    return String(
      it?.creatorId ||
      it?.ownerId ||
      it?.authorId ||
      it?.userId ||
      it?.creator?.id ||
      it?.creator?._id ||
      "",
    ).trim();
  }

  function getCreator(it: any) {
    return String(
      it?.ownerUsername ||
      it?.creatorUsername ||
      it?.creator?.username ||
      it?.creator?.name ||
      it?.creator ||
      it?.author ||
      "creator",
    ).trim();
  }

  function getCreatorAvatar(it: any) {
    return normalizeImageUrl(
      it?.avatarUrl ||
      it?.avatar ||
      it?.ownerAvatar ||
      it?.creatorAvatar ||
      it?.creatorAvatarUrl ||
      it?.creator?.avatarUrl ||
      it?.creator?.avatar ||
      it?.imageUrl ||
      "",
    );
  }

  function getThumb(it: any) {
    const raw =
      it?.thumbnailUrl ||
      it?.previewImageUrl ||
      it?.reel?.thumbnailUrl ||
      it?.imageUrl ||
      it?.coverUrl ||
      it?.posterUrl ||
      "";
    const normalized = normalizeImageUrl(raw);
    return normalized || "https://images.unsplash.com/photo-1550745165-9bc0b252726f?auto=format&fit=crop&q=80&w=2070";
  }

  function getPlayUrl(it: any) {
    const raw =
      it?.playUrl ||
      it?.webglUrl ||
      it?.previewUrl ||
      it?.url ||
      it?.gameUrl ||
      it?.webUrl ||
      "";
    const s = String(raw || "").trim();
    if (!s) return "";
    if (s.startsWith("http://") || s.startsWith("https://")) return s;
    return normalizeImageUrl(s);
  }

  function getReelVideoUrl(it: any) {
    const raw =
      it?.previewVideoUrl ||
      it?.trailerVideoUrl ||
      it?.videoUrl ||
      it?.reel?.previewVideoUrl ||
      it?.reel?.trailerVideoUrl ||
      it?.reel?.videoUrl ||
      "";
    return normalizeImageUrl(raw) || "";
  }

  function getAdVideoUrl(it: any) {
    const raw =
      it?.adVideoUrl ||
      it?.videoUrl ||
      it?.ad?.videoUrl ||
      it?.adCampaign?.videoUrl ||
      it?.campaign?.videoUrl ||
      it?.media?.videoUrl ||
      it?.creative?.videoUrl ||
      it?.ad?.creative?.videoUrl ||
      it?.reel?.videoUrl ||
      it?.video?.url ||
      it?.video?.src ||
      "";

    const resolved = normalizeImageUrl(raw) || "";
    if (!resolved && String(it?.kind || "").toLowerCase() === "ad" && process.env.NODE_ENV !== "production") {
      try {
        console.debug("[Arcade] Ad post missing video URL", {
          id: it?.id || it?._id,
          adVideoUrl: it?.adVideoUrl,
          videoUrl: it?.videoUrl,
          mediaVideoUrl: it?.media?.videoUrl,
          creativeVideoUrl: it?.creative?.videoUrl,
          ad: it?.ad,
          campaign: it?.campaign,
          adCampaign: it?.adCampaign,
        });
      } catch { }
    }

    return resolved;
  }

  function getCaptionLines(it: any) {
    const v = it?.reelCaptionLines || it?.reel?.captionLines;
    if (!Array.isArray(v)) return [] as string[];
    return v.map((x: any) => String(x || "").trim()).filter(Boolean).slice(0, 3);
  }

  function getDescription(it: any) {
    return String(it?.description || it?.reelPromoText || it?.reel?.promoText || "").trim();
  }

  return (
    <UserShell title="Community Arcade" subtitle="Discover and play the best community creations">
      <div className="space-y-12 pb-20">

        {/* Top bar with Search */}
        <div className="flex flex-col md:flex-row gap-6 items-center justify-between">
          <div className="relative flex-1 w-full group">
            <div className="absolute inset-0 bg-blue-500/5 blur-xl opacity-0 group-focus-within:opacity-100 transition-opacity" />
            <Search className="absolute left-5 top-1/2 -translate-y-1/2 text-zinc-500" size={20} />
            <input
              className="gf-input w-full rounded-[24px] pl-14 pr-6 py-4 text-sm border-white/10 focus:border-blue-500/50 bg-black/40 transition-all font-bold"
              placeholder="Search games or creators in Discovery..."
              value={search}
              readOnly
              onClick={() => openDiscovery(search)}
              onFocus={() => openDiscovery(search)}
            />
          </div>
          <div className="flex items-center gap-3 text-[10px] font-black text-zinc-500 uppercase tracking-[0.2em] leading-none">
            <button
              onClick={() => openDiscovery(search)}
              className="inline-flex items-center gap-2 rounded-2xl border border-blue-500/30 bg-blue-500/10 px-4 py-2 text-blue-200 hover:bg-blue-500/20 transition-colors"
            >
              <Compass size={15} weight="duotone" />
              Discovery
            </button>
            <span className="text-[var(--foreground)] text-lg font-mono">{items.length}</span> Total
            <span className="text-zinc-700">•</span>
            <span className="text-blue-300 text-xs">{filteredItems.length} visible</span>
            {loadingMore ? (
              <span className="text-zinc-400 animate-pulse">syncing…</span>
            ) : null}
          </div>
        </div>

        {!loading && items.length > 0 ? (
          <section className="gf-panel-strong rounded-[30px] border border-white/10 p-5 md:p-6 relative overflow-hidden">
            <div className="absolute inset-0 bg-gradient-to-r from-blue-600/10 via-transparent to-sky-500/10 pointer-events-none" />
            <div className="relative z-10 flex flex-col lg:flex-row gap-5 lg:items-center lg:justify-between">
              <div className="space-y-2">
                <div className="text-[10px] uppercase tracking-[0.32em] font-black text-blue-300">Discovery Pulse</div>
                <div className="flex flex-wrap gap-2">
                  {discovery.topTags.length ? discovery.topTags.map(([tag, count]) => (
                    <span key={tag} className="rounded-full border border-white/10 bg-white/5 px-3 py-1 text-[11px] text-zinc-200 font-bold">
                      #{tag} <span className="text-zinc-500">{count}</span>
                    </span>
                  )) : (
                    <span className="text-xs text-zinc-500">Publish more tagged reels to unlock smart discovery.</span>
                  )}
                </div>
              </div>
              <div className="flex flex-wrap items-center gap-2">
                <button
                  onClick={() => openDiscovery(search)}
                  className="rounded-full border border-blue-500/35 bg-blue-500/15 px-3 py-1.5 text-[11px] font-black text-blue-100 uppercase tracking-wide"
                >
                  Open Discovery Hub
                </button>
                {discovery.topCreators.map((c) => (
                  <button
                    key={c.id}
                    onClick={() => router.push(`/studio/profile/${c.id}`)}
                    className="inline-flex items-center gap-2 rounded-full border border-white/10 bg-black/40 px-3 py-1.5 hover:border-blue-400/40 transition-colors"
                  >
                    {c.avatar ? (
                      <img src={c.avatar} alt={c.username} className="h-6 w-6 rounded-full object-cover border border-white/20" />
                    ) : (
                      <span className="h-6 w-6 rounded-full bg-blue-500/30 text-[10px] text-white font-black inline-flex items-center justify-center">
                        {c.username.slice(0, 1).toUpperCase()}
                      </span>
                    )}
                    <span className="text-xs text-zinc-200 font-bold">@{c.username}</span>
                  </button>
                ))}
              </div>
            </div>
          </section>
        ) : null}

        <section className="gf-panel-strong gf-stroke-gradient rounded-[40px] p-0 overflow-hidden shadow-[0_0_100px_rgba(0,0,0,0.5)] border border-white/5 relative">
          <div className="absolute inset-0 bg-gradient-to-r from-emerald-600/10 via-transparent to-fuchsia-500/10 pointer-events-none" />
          <div className="absolute inset-0 gf-grid opacity-10 pointer-events-none" />
          <div className="relative z-10 p-5 md:p-6 border-b border-white/10">
            <div className="flex flex-col md:flex-row md:items-end md:justify-between gap-4">
              <div>
                <div className="text-[10px] uppercase tracking-[0.36em] font-black text-zinc-500">
                  {feedMode === "unity" ? "Arcade Hub" : "Toilet Games"}
                </div>
                <div className="mt-2 text-3xl md:text-4xl font-black italic uppercase tracking-tighter text-white">
                  {feedMode === "unity" ? "Community Arcade Reels" : "Instant Arcade Reels"}
                </div>
                <div className="mt-2 text-sm text-zinc-300/85 max-w-2xl">
                  {feedMode === "unity"
                    ? "Scroll like TikTok. Auto-play Unity builds from the global community feed."
                    : "Scroll like TikTok. Auto-play instant HTML5 toilet games streamed from backend."}
                </div>
              </div>
              <div className="flex items-center gap-3">
                <div className="inline-flex items-center gap-2 rounded-2xl border border-white/10 bg-black/40 p-1 text-[10px] font-black uppercase tracking-[0.28em] text-zinc-400">
                  <button
                    onClick={() => setFeedMode("toilet")}
                    className={cx(
                      "px-4 py-2 rounded-xl transition-colors",
                      feedMode === "toilet" ? "bg-emerald-500/20 text-emerald-200 border border-emerald-500/25" : "text-zinc-400 hover:text-white",
                    )}
                  >
                    Toilet
                  </button>
                  <button
                    onClick={() => setFeedMode("unity")}
                    className={cx(
                      "px-4 py-2 rounded-xl transition-colors",
                      feedMode === "unity" ? "bg-blue-500/20 text-blue-200 border border-blue-500/25" : "text-zinc-400 hover:text-white",
                    )}
                  >
                    Unity
                  </button>
                </div>
                {feedMode === "toilet" ? (
                  <div className="hidden sm:flex items-center gap-2 rounded-2xl border border-white/10 bg-black/40 px-4 py-2 text-[10px] font-black uppercase tracking-[0.28em] text-zinc-400">
                    <span className="h-2 w-2 rounded-full bg-emerald-400 animate-ping" />
                    HTML5
                  </div>
                ) : (
                  <div className="hidden sm:flex items-center gap-2 rounded-2xl border border-white/10 bg-black/40 px-4 py-2 text-[10px] font-black uppercase tracking-[0.28em] text-zinc-400">
                    <span className="h-2 w-2 rounded-full bg-blue-400 animate-ping" />
                    UNITY
                  </div>
                )}
                  <div className="flex items-center gap-3">
                    <div className="text-[10px] font-black text-zinc-500 uppercase tracking-[0.26em]">
                      {feedMode === "toilet" ? `${instantGames.length} games` : `${filteredItems.length} reels`}
                    </div>
                    <div className="h-4 w-[1px] bg-white/10" />
                    <div className="text-[10px] font-black text-emerald-400 uppercase tracking-[0.26em] animate-pulse">Live Feed</div>
                  </div>
              </div>
            </div>
          </div>

          {feedMode === "toilet" ? (
            instantLoading ? (
              <div className="p-10 md:p-14 text-center">
                <div className="text-xl font-black italic uppercase tracking-tight text-[var(--foreground)] gf-chromatic animate-pulse">
                  Loading instant arcade…
                </div>
                <div className="mt-3 text-[10px] font-black text-zinc-500 uppercase tracking-[0.4em]">syncing HTML5 nodes</div>
              </div>
            ) : instantError ? (
              <div className="p-10 md:p-14 text-center border-t border-rose-500/20 bg-rose-500/10">
                <div className="text-xl font-black italic uppercase tracking-tight text-[var(--foreground)]">Instant arcade offline</div>
                <div className="mt-2 text-sm text-rose-200/80">{instantError}</div>
              </div>
            ) : instantGames.length === 0 ? (
              <div className="p-12 md:p-16 text-center border-t border-white/10">
                <div className="text-5xl mb-5 opacity-20">🧻</div>
                <div className="text-xl font-black italic uppercase tracking-tight text-[var(--foreground)]">No toilet games yet</div>
                <div className="mt-2 text-sm text-zinc-500">Seed games in backend under uploads/projects/instant-arcade/*</div>
              </div>
            ) : (
              <div ref={instantScrollerRef} className="h-[82vh] overflow-y-auto snap-y snap-mandatory gf-scrollbar-none scroll-smooth">
                {instantGames.map((g, idx) => {
                  const isActive = idx === instantActiveIndex;
                  const isPlaying = isActive;
                  return (
                    <section key={g.id} data-instant-item="1" className="snap-start h-[82vh] relative border-b border-white/5 overflow-hidden group/item">
                      {/* Full-bleed Ambient Background */}
                      <div className="absolute inset-0 z-0">
                        {normalizeImageUrl(g.thumbUrl) ? (
                          <img 
                            src={normalizeImageUrl(g.thumbUrl)} 
                            alt="" 
                            className="h-full w-full object-cover scale-110 blur-[60px] opacity-30 saturate-150 transition-transform duration-1000 group-hover/item:scale-125" 
                          />
                        ) : (
                          <div className="h-full w-full bg-gradient-to-br from-emerald-500/20 via-blue-500/10 to-fuchsia-500/20 blur-[60px] opacity-30" />
                        )}
                        <div className="absolute inset-0 bg-black/40" />
                        <div className="absolute inset-0 bg-gradient-to-t from-[#05060b] via-transparent to-[#05060b]/80" />
                      </div>

                      <div className="absolute inset-0 p-4 z-10 flex items-center justify-center">
                        <div data-fullscreen-root="1" className="relative h-full w-full max-w-[460px] rounded-[32px] border border-white/15 bg-black overflow-hidden shadow-[0_0_100px_rgba(0,0,0,0.8),0_0_40px_rgba(16,185,129,0.15)] group/reel">
                          <div className="absolute inset-0 bg-gradient-to-tr from-emerald-500/10 to-transparent opacity-0 group-hover/reel:opacity-100 transition-opacity pointer-events-none z-20" />
                          {isActive ? (
                            <div className="absolute inset-0 z-10">
                              <iframe
                                key={`${g.id}-${idx}-iframe`}
                                src={`${g.playUrl}${g.playUrl.includes("?") ? "&" : "?" }autostart=1`}
                                className="h-full w-full border-0"
                                allow="fullscreen; autoplay; gamepad; clipboard-write"
                                sandbox="allow-scripts allow-same-origin allow-pointer-lock allow-forms allow-popups"
                              />
                            </div>
                          ) : (
                            <div className="absolute inset-0 bg-black flex items-center justify-center">
                               <div className="h-12 w-12 rounded-full border-2 border-white/10 border-t-emerald-500 animate-spin" />
                            </div>
                          )}

                          <button
                            type="button"
                            onClick={(e) => {
                              e.stopPropagation();
                              const root = (e.currentTarget as HTMLElement).closest('[data-fullscreen-root="1"]') as any;
                              try {
                                if (root && typeof root.requestFullscreen === 'function') {
                                  root.requestFullscreen();
                                  return;
                                }
                              } catch { }
                              window.open(g.playUrl, '_blank');
                            }}
                            className="pointer-events-auto absolute top-4 right-4 z-30 h-11 w-11 rounded-2xl bg-black/60 backdrop-blur-xl border border-white/20 flex items-center justify-center text-white opacity-100 md:opacity-0 md:group-hover/reel:opacity-100 transition-all hover:bg-emerald-500/25"
                            title="Full Screen"
                          >
                            <ArrowSquareOut size={20} weight="bold" />
                          </button>

                          {/* Floating TikTok Info Overlay */}
                          <div className="absolute inset-x-0 bottom-0 pointer-events-none z-30 flex flex-col justify-end p-6 bg-gradient-to-t from-black/90 via-transparent to-transparent h-[44%]">
                            <div className="pointer-events-auto flex items-end justify-between gap-4 relative z-40">
                              <div className="flex-1 min-w-0">
                                <div className="inline-flex items-center gap-2 mb-3 rounded-full bg-emerald-500/20 border border-emerald-500/30 px-3 py-1 text-[9px] font-black text-emerald-300 uppercase tracking-widest">
                                  <div className="h-1.5 w-1.5 rounded-full bg-emerald-500 animate-ping" />
                                  {g.source || 'INSTANT'}
                                </div>
                                <div className="text-2xl font-black italic uppercase text-white tracking-tighter drop-shadow-lg">{g.title}</div>
                                <div className="mt-1 text-xs text-white/70 line-clamp-1 max-w-[280px]">{g.description}</div>
                              </div>
                              <div className="flex flex-col gap-4">
                                <div className="flex flex-col items-center gap-1">
                                  <button className="pointer-events-auto h-12 w-12 rounded-full bg-white/10 backdrop-blur-xl border border-white/20 flex items-center justify-center text-emerald-400 hover:bg-emerald-400/20 transition-all">
                                    <GameController size={24} weight="fill" />
                                  </button>
                                  <span className="text-[10px] font-black text-white">PLAY</span>
                                </div>
                                <div className="flex flex-col items-center gap-1">
                                  <button className="pointer-events-auto h-12 w-12 rounded-full bg-white/10 backdrop-blur-xl border border-white/20 flex items-center justify-center text-white hover:bg-white/20 transition-all">
                                    <ShareNetwork size={24} weight="bold" />
                                  </button>
                                </div>
                              </div>
                            </div>
                          </div>
                        </div>
                      </div>
                    </section>
                  );
                })}
              </div>
            )
          ) : loading ? (
            <div className="p-10 md:p-14 text-center">
              <div className="text-xl font-black italic uppercase tracking-tight text-[var(--foreground)] gf-chromatic animate-pulse">
                Initializing community feed…
              </div>
              <div className="mt-3 text-[10px] font-black text-zinc-500 uppercase tracking-[0.4em]">booting arcade nodes</div>
            </div>
          ) : error ? (
            <div className="p-10 md:p-14 text-center border-t border-rose-500/20 bg-rose-500/10">
              <div className="text-xl font-black italic uppercase tracking-tight text-[var(--foreground)]">Arcade offline</div>
              <div className="mt-2 text-sm text-rose-200/80">{error}</div>
            </div>
          ) : filteredItems.length === 0 ? (
            <div className="p-12 md:p-16 text-center border-t border-white/10">
              <div className="text-5xl mb-5 opacity-20">🕹️</div>
              <div className="text-xl font-black italic uppercase tracking-tight text-[var(--foreground)]">Arcade is quiet</div>
              <div className="mt-2 text-sm text-zinc-500">Be the first to publish a game to the global feed!</div>
            </div>
          ) : (
            <div ref={scrollerRef} className="h-[82vh] overflow-y-auto snap-y snap-mandatory gf-scrollbar-none scroll-smooth">
              {filteredItems
                .map((it, idx) => {
                  const id = getId(it, idx);
                  const title = getTitle(it);
                  const creator = getCreator(it);
                  const creatorId = getCreatorId(it);
                  const avatarUrl = getCreatorAvatar(it);
                  const thumb = getThumb(it);
                  const playUrl = getPlayUrl(it);
                  const adVideoUrl = getAdVideoUrl(it);
                  const isActive = idx === activeIndex;
                  const isPlaying = isActive;
                  const isMe = me && String(creatorId) === String(me.id);
                  const safeAvatarUrl = (isMe && me?.avatar) ? normalizeImageUrl(me.avatar) : avatarUrl;
                  const showCommentsPanel = sidePanelMode === "comments" && sidePanelPostId === id;
                  const showTipPanel = sidePanelMode === "tip" && sidePanelPostId === id;
                  const showSidePanel = showCommentsPanel || showTipPanel;

                  return (
                    <section key={`${id}-${idx}`} data-arcade-item="1" className="snap-start h-[82vh] relative border-b border-white/5 overflow-hidden group/item">
                      {/* Full-bleed Ambient Background */}
                      <div className="absolute inset-0 z-0">
                        <img 
                          src={thumb} 
                          alt="" 
                          className="h-full w-full object-cover scale-110 blur-[60px] opacity-30 saturate-150 transition-transform duration-1000 group-hover/item:scale-125" 
                        />
                        <div className="absolute inset-0 bg-black/40" />
                        <div className="absolute inset-0 bg-gradient-to-t from-[#05060b] via-transparent to-[#05060b]/80" />
                      </div>

                      <div className="absolute inset-0 p-4 z-10 flex items-center justify-center">
                        <div className="relative h-full w-full max-w-[460px] md:flex md:items-stretch md:gap-5">
                          <motion.div
                            layout
                            data-fullscreen-root="1"
                            className="relative h-full w-full rounded-[32px] border border-white/15 bg-black overflow-hidden shadow-[0_0_100px_rgba(0,0,0,0.8),0_0_40px_rgba(59,130,246,0.15)] flex-1 group/reel"
                          >
                            <div className="absolute inset-0 bg-gradient-to-tr from-blue-500/10 to-transparent opacity-0 group-hover/reel:opacity-100 transition-opacity pointer-events-none z-20" />
                            
                            {isPlaying && playUrl ? (
                              <div className="absolute inset-0 z-10">
                                <iframe
                                  key={`${id}-${idx}-iframe`}
                                  src={`${playUrl}${playUrl.includes("?") ? "&" : "?"}autostart=1`}
                                  className="h-full w-full border-0"
                                  allow="fullscreen; autoplay; gamepad; clipboard-write"
                                  sandbox="allow-scripts allow-same-origin allow-pointer-lock allow-forms allow-popups"
                                />
                              </div>
                            ) : it.kind === 'ad' && adVideoUrl ? (
                              <video
                                src={adVideoUrl}
                                poster={thumb}
                                autoPlay
                                muted
                                loop
                                playsInline
                                preload="metadata"
                                className="absolute inset-0 h-full w-full object-cover"
                              />
                            ) : (
                              <div className="absolute inset-0 bg-black flex items-center justify-center">
                                <div className="h-12 w-12 rounded-full border-2 border-white/10 border-t-blue-500 animate-spin" />
                              </div>
                            )}

                            <button
                              type="button"
                              onClick={(e) => {
                                e.stopPropagation();
                                const root = (e.currentTarget as HTMLElement).closest('[data-fullscreen-root="1"]') as any;
                                try {
                                  if (root && typeof root.requestFullscreen === 'function') {
                                    root.requestFullscreen();
                                    return;
                                  }
                                } catch { }
                                if (playUrl) window.open(playUrl, '_blank');
                              }}
                              className="pointer-events-auto absolute top-4 right-4 h-11 w-11 rounded-2xl bg-black/60 backdrop-blur-xl border border-white/20 flex items-center justify-center text-white opacity-100 md:opacity-0 md:group-hover/reel:opacity-100 transition-all hover:bg-blue-500/25 z-30"
                              title="Full Screen"
                            >
                              <ArrowSquareOut size={20} weight="bold" />
                            </button>

                            {/* Floating TikTok UI Overlay */}
                            <div className="absolute inset-x-0 bottom-0 pointer-events-none z-30 flex flex-col justify-end p-6 bg-gradient-to-t from-black/90 via-transparent to-transparent h-[44%]">
                              {it.kind === 'ad' && (
                                <div className="absolute left-6 top-6 flex items-center gap-2 rounded-full bg-rose-500/20 border border-rose-500/30 px-3 py-1 text-[9px] font-black text-rose-400 uppercase tracking-widest animate-pulse">
                                  <Lightning size={10} weight="fill" />
                                  SPONSORED
                                </div>
                              )}
                              <div className="pointer-events-auto flex items-end justify-between gap-4 relative z-40">
                                <div className="flex-1 min-w-0">
                                  <button
                                    onClick={() => creatorId && router.push(`/studio/profile/${creatorId}`)}
                                    className="flex items-center gap-2 mb-4 group"
                                  >
                                    <div className="h-9 w-9 rounded-full border border-white/20 overflow-hidden">
                                      {safeAvatarUrl ? (
                                        <img src={safeAvatarUrl} className="h-full w-full object-cover" alt="" />
                                      ) : (
                                        <div className="h-full w-full bg-blue-500 flex items-center justify-center text-[10px] font-black text-white">
                                          {String(creator || "U").slice(0, 1).toUpperCase()}
                                        </div>
                                      )}
                                    </div>
                                    <span className="text-sm font-black text-white drop-shadow-md">@{creator}</span>
                                  </button>
                                  <div className="text-2xl font-black italic uppercase text-white tracking-tighter drop-shadow-lg">{title}</div>
                                  <div className="mt-1 text-xs text-white/70 line-clamp-2 max-w-[320px]">{getDescription(it)}</div>
                                  {it.kind === 'ad' && it.clickUrl && (
                                    <a
                                      href={it.clickUrl}
                                      target="_blank"
                                      rel="noopener noreferrer"
                                      className="pointer-events-auto inline-flex items-center gap-2 mt-4 bg-white px-6 py-2.5 rounded-full text-sm font-black text-black hover:scale-105 transition-transform shadow-xl"
                                    >
                                      {it.ctaLabel || "Visit Website"}
                                      <ArrowSquareOut size={16} weight="bold" />
                                    </a>
                                  )}
                                </div>
                                <div className="flex flex-col gap-5 pb-2">
                                  <div className="flex flex-col items-center gap-1">
                                    <button onClick={() => handleLike(id)} className="pointer-events-auto h-12 w-12 rounded-full bg-white/10 backdrop-blur-xl border border-white/20 flex items-center justify-center text-rose-400 hover:bg-rose-400/20 transition-all">
                                      <Heart size={24} weight={it?.likedByMe ? "fill" : "bold"} />
                                    </button>
                                    <span className="text-[10px] font-black text-white">{it?.likeCount || 0}</span>
                                  </div>
                                  <div className="flex flex-col items-center gap-1">
                                    <button onClick={() => creatorId && handleDonate(creatorId, creator, id)} className="pointer-events-auto h-12 w-12 rounded-full bg-white/10 backdrop-blur-xl border border-white/20 flex items-center justify-center text-emerald-400 hover:bg-emerald-400/20 transition-all">
                                      <CurrencyDollar size={24} weight="bold" />
                                    </button>
                                    <span className="text-[10px] font-black text-white">TIP</span>
                                  </div>
                                  <div className="flex flex-col items-center gap-1">
                                    <button onClick={() => openComments(id)} className="pointer-events-auto h-12 w-12 rounded-full bg-white/10 backdrop-blur-xl border border-white/20 flex items-center justify-center text-white hover:bg-white/20 transition-all">
                                      <ChatCircleDots size={24} weight="bold" />
                                    </button>
                                    <span className="text-[10px] font-black text-white">{it?.commentCount || 0}</span>
                                  </div>
                                  <div className="flex flex-col items-center gap-1">
                                    <button onClick={() => handleShare(id)} className="pointer-events-auto h-12 w-12 rounded-full bg-white/10 backdrop-blur-xl border border-white/20 flex items-center justify-center text-white hover:bg-white/20 transition-all">
                                      <ShareNetwork size={24} weight="bold" />
                                    </button>
                                  </div>
                                </div>
                              </div>
                            </div>
                          </motion.div>

                          <AnimatePresence>
                            {showSidePanel ? (
                              <motion.aside
                                initial={{ x: 44, opacity: 0 }}
                                animate={{ x: 0, opacity: 1 }}
                                exit={{ x: 44, opacity: 0 }}
                                transition={{ duration: 0.34, ease: [0.22, 1, 0.36, 1] }}
                                className="hidden md:flex h-full w-[23.5rem] lg:w-[27.5rem] rounded-[30px] border border-white/10 bg-[var(--gf-shell-bg)]/95 backdrop-blur-xl overflow-hidden shadow-[0_20px_80px_rgba(0,0,0,0.55)]"
                              >
                                {showCommentsPanel ? (
                                  <div className="flex h-full w-full flex-col">
                                    <div className="px-4 py-3 border-b border-white/10 flex items-center justify-between bg-gradient-to-r from-blue-500/10 to-transparent">
                                      <div>
                                        <div className="text-sm font-black text-[var(--foreground)] uppercase tracking-wide">Comments</div>
                                        <div className="text-[10px] text-zinc-500 uppercase tracking-[0.26em]">Live community thread</div>
                                        <div className="mt-1 text-[11px] text-blue-200 font-semibold truncate max-w-[250px]">
                                          {title} • @{creator}
                                        </div>
                                      </div>
                                      <button onClick={() => setCommentsOpenPostId(null)} className="h-9 w-9 rounded-xl border border-white/10 bg-white/5 text-zinc-300">
                                        <X size={16} className="mx-auto" />
                                      </button>
                                    </div>

                                    <div className="px-4 py-3 space-y-3 overflow-y-auto flex-1 min-h-0">
                                      {commentsLoadingPostId === id ? (
                                        <div className="text-sm text-zinc-500">Loading comments…</div>
                                      ) : (commentsByPost[id] || []).length ? (
                                        (commentsByPost[id] || []).map((c) => (
                                          <div key={c.id} className="rounded-2xl border border-white/10 bg-white/[0.03] p-3">
                                            <div className="flex items-center gap-2 mb-1">
                                              {c.avatarUrl ? (
                                                <img src={normalizeImageUrl(c.avatarUrl)} alt={c.username || "user"} className="h-7 w-7 rounded-full object-cover border border-white/20" />
                                              ) : (
                                                <span className="h-7 w-7 rounded-full bg-blue-500/25 border border-white/20 inline-flex items-center justify-center text-[10px] text-white font-black">
                                                  {String(c.username || "u").slice(0, 1).toUpperCase()}
                                                </span>
                                              )}
                                              <span className="text-xs font-black text-zinc-200">@{c.username || "player"}</span>
                                            </div>
                                            <div className="text-sm text-zinc-300 whitespace-pre-wrap break-words">{c.text || "(voice comment)"}</div>
                                          </div>
                                        ))
                                      ) : (
                                        <div className="text-sm text-zinc-500">No comments yet. Be the first one ✨</div>
                                      )}
                                    </div>

                                    <div className="p-3 border-t border-white/10 bg-black/30">
                                      <div className="flex items-center gap-2">
                                        <input
                                          value={commentDraft}
                                          onChange={(e) => setCommentDraft(e.target.value)}
                                          onKeyDown={(e) => {
                                            if (e.key === "Enter") {
                                              e.preventDefault();
                                              void submitComment();
                                            }
                                          }}
                                          placeholder="Write a comment…"
                                          className="flex-1 rounded-xl border border-white/10 bg-white/[0.03] px-3 py-2 text-sm text-white outline-none"
                                        />
                                        <button
                                          onClick={() => void submitComment()}
                                          disabled={commentBusy || !commentDraft.trim()}
                                          className="h-10 px-4 rounded-xl border border-blue-500/40 bg-blue-500/20 text-blue-100 text-xs font-black uppercase tracking-wide disabled:opacity-40 inline-flex items-center gap-2"
                                        >
                                          <PaperPlaneTilt size={14} weight="fill" />
                                          Send
                                        </button>
                                      </div>
                                    </div>
                                  </div>
                                ) : (
                                  <div className="flex h-full w-full flex-col">
                                    <div className="px-4 py-3 border-b border-white/10 flex items-center justify-between bg-gradient-to-r from-emerald-500/10 via-transparent to-transparent">
                                      <div>
                                        <div className="text-[11px] text-emerald-300 font-black uppercase tracking-[0.22em]">Creator Tip</div>
                                        <div className="text-base font-bold text-white">Send support to @{tipCreatorName}</div>
                                        <div className="mt-1 text-xs text-zinc-300 truncate max-w-[250px]">For reel: {title}</div>
                                      </div>
                                      <button onClick={closeTipModal} className="h-9 w-9 rounded-xl border border-white/10 bg-white/5 text-zinc-300">
                                        <X size={16} className="mx-auto" />
                                      </button>
                                    </div>

                                    <div className="p-4 space-y-3 overflow-y-auto flex-1 min-h-0">
                                      <div className="rounded-2xl border border-white/10 bg-white/[0.04] p-3 flex items-center justify-between">
                                        <div>
                                          <div className="text-[10px] uppercase tracking-[0.26em] text-zinc-500 font-black">Total payment</div>
                                          <div className="text-xs text-zinc-400">Secure checkout powered by Stripe</div>
                                        </div>
                                        <div className="text-2xl font-black text-white">${Number(tipAmountUsd || 0).toFixed(2)}</div>
                                      </div>

                                      <label className="space-y-1 block">
                                        <div className="text-[10px] text-zinc-500 uppercase tracking-[0.22em]">Amount (USD)</div>
                                        <input
                                          type="number"
                                          min={1}
                                          max={50000}
                                          value={tipAmountUsd}
                                          onChange={(e) => setTipAmountUsd(Math.max(1, Math.min(50000, Number(e.target.value || 1))))}
                                          className="w-full rounded-xl border border-white/10 bg-white/[0.03] px-3 py-2 text-white"
                                        />
                                      </label>

                                      <label className="space-y-1 block">
                                        <div className="text-[10px] text-zinc-500 uppercase tracking-[0.22em]">Message to creator (optional)</div>
                                        <textarea
                                          rows={3}
                                          value={tipMessage}
                                          onChange={(e) => setTipMessage(e.target.value.slice(0, 240))}
                                          placeholder="Great reel! Keep cooking 🔥"
                                          className="w-full rounded-xl border border-white/10 bg-white/[0.03] px-3 py-2 text-white resize-none"
                                        />
                                      </label>

                                      {tipStep === "compose" ? (
                                        <>
                                          <div className="rounded-xl border border-blue-500/25 bg-blue-500/10 px-3 py-2 text-xs text-blue-100 font-semibold">
                                            Step 1/2: set amount and message. This donation is linked to @{tipCreatorName}&apos;s creator wallet.
                                          </div>
                                          <button
                                            onClick={() => void openTipCardStep()}
                                            disabled={!tipCreatorId || tipBusy}
                                            className="w-full rounded-xl border border-blue-500/35 bg-blue-500/20 px-4 py-3 text-sm font-black uppercase tracking-wide text-blue-100 disabled:opacity-40"
                                          >
                                            {tipBusy ? "Preparing secure payment…" : "Continue to card"}
                                          </button>
                                        </>
                                      ) : (
                                        <>
                                          {tipBusy && !tipClientSecret ? (
                                            <div className="rounded-xl border border-blue-500/25 bg-blue-500/10 px-3 py-3 text-sm text-blue-100">
                                              Preparing secure in-app card form…
                                            </div>
                                          ) : tipInitError ? (
                                            <div className="space-y-2">
                                              <div className="rounded-xl border border-rose-500/35 bg-rose-500/10 px-3 py-2 text-xs text-rose-200 font-semibold">
                                                {tipInitError}
                                              </div>
                                              <button
                                                onClick={() => void openTipCardStep()}
                                                className="w-full rounded-xl border border-blue-500/35 bg-blue-500/20 px-4 py-3 text-sm font-black uppercase tracking-wide text-blue-100"
                                              >
                                                Retry card setup
                                              </button>
                                            </div>
                                          ) : tipClientSecret && stripePromise ? (
                                            <Elements
                                              stripe={stripePromise as any}
                                              options={{
                                                clientSecret: tipClientSecret,
                                                appearance: {
                                                  theme: "night",
                                                  variables: {
                                                    colorPrimary: "#a855f7",
                                                    colorBackground: "#0b0b12",
                                                    colorText: "#ffffff",
                                                    colorDanger: "#fb7185",
                                                    fontFamily:
                                                      "ui-sans-serif, system-ui, -apple-system, Segoe UI, Roboto, Helvetica, Arial",
                                                  },
                                                },
                                              }}
                                            >
                                              <TipCardPaymentForm
                                                amountUsd={tipAmountUsd}
                                                onBack={() => {
                                                  setTipStep("compose");
                                                  setTipInitError(null);
                                                }}
                                                onCancel={closeTipModal}
                                                onSuccess={confirmTipLedger}
                                              />
                                            </Elements>
                                          ) : (
                                            <div className="rounded-xl border border-rose-500/35 bg-rose-500/10 px-3 py-2 text-xs text-rose-200 font-semibold">
                                              Payment form unavailable right now. Please retry in a few seconds.
                                            </div>
                                          )}
                                        </>
                                      )}
                                    </div>
                                  </div>
                                )}
                              </motion.aside>
                            ) : null}
                          </AnimatePresence>
                        </div>
                      </div>
                    </section>
                  );
                })}

              {!search.trim() && nextCursor ? (
                <div className="snap-start min-h-[110px] flex items-center justify-center border-t border-white/5">
                  <button
                    onClick={() => void loadMoreFeed()}
                    disabled={loadingMore}
                    className="rounded-2xl border border-white/10 bg-white/5 px-5 py-3 text-xs font-black uppercase tracking-wider text-zinc-300 hover:bg-white/10 disabled:opacity-40"
                  >
                    {loadingMore ? "Syncing more reels…" : "Load more"}
                  </button>
                </div>
              ) : null}

              {!search.trim() && !nextCursor && items.length > FEED_PAGE_LIMIT ? (
                <div className="min-h-[70px] flex items-center justify-center text-[10px] uppercase tracking-[0.26em] text-zinc-600 font-black border-t border-white/5">
                  End of neural feed
                </div>
              ) : null}
            </div>
          )}
        </section>

        {!loading && filteredItems.length > 0 ? (
          <section className="gf-panel-strong rounded-[34px] border border-white/10 p-5 md:p-6 relative overflow-hidden">
            <div className="absolute inset-0 bg-gradient-to-r from-blue-600/10 via-transparent to-fuchsia-500/10 pointer-events-none" />
            <div className="relative z-10 flex items-center justify-between gap-4">
              <div>
                <div className="text-[10px] uppercase tracking-[0.32em] font-black text-zinc-500">Reels</div>
                <div className="mt-1 text-2xl font-black italic uppercase tracking-tighter text-white">Reel Highlights</div>
              </div>
              <div className="text-[10px] font-black text-zinc-500 uppercase tracking-[0.26em]">auto preview</div>
            </div>

            <div className="relative z-10 mt-5 overflow-x-auto gf-scrollbar">
              <div className="flex gap-4 min-w-max">
                {filteredItems
                  .map((it, idx) => ({ it, idx, url: getReelVideoUrl(it) }))
                  .filter((x) => !!x.url)
                  .slice(0, 18)
                  .map(({ it, idx, url }) => {
                    const id = getId(it, idx);
                    const title = getTitle(it);
                    const thumb = getThumb(it);
                    return (
                      <button
                        key={`hl-${id}-${idx}`}
                        onClick={() => {
                          setFeedMode("unity");
                          window.setTimeout(() => {
                            const el = scrollerRef.current;
                            const children = el ? (Array.from(el.querySelectorAll("[data-arcade-item='1']")) as HTMLElement[]) : [];
                            const t = children[idx];
                            if (el && t) el.scrollTo({ top: t.offsetTop, behavior: "smooth" });
                          }, 50);
                        }}
                        className="relative h-[240px] w-[150px] md:h-[280px] md:w-[170px] rounded-[26px] border border-white/10 bg-black/40 overflow-hidden shadow-[0_0_60px_rgba(99,102,241,0.12)]"
                        title={title}
                      >
                        <video
                          src={url as string}
                          poster={thumb}
                          autoPlay
                          muted
                          loop
                          playsInline
                          controls={false}
                          className="absolute inset-0 h-full w-full object-cover"
                        />
                        <div className="absolute inset-0 bg-gradient-to-t from-black/80 via-black/15 to-transparent" />
                        <div className="absolute left-3 right-3 bottom-3">
                          <div className="text-xs font-black text-white line-clamp-2">{title}</div>
                        </div>
                      </button>
                    );
                  })}
              </div>
            </div>
          </section>
        ) : null}

        {/* Global Leaderboard Section (Moved to Bottom) */}
        {!loading && leaderboard.length > 0 && (
          <section className="animate-in fade-in slide-in-from-bottom-8 duration-1000">
            <div className="gf-panel-strong gf-stroke-gradient rounded-[60px] p-12 relative overflow-hidden shadow-[0_0_100px_rgba(99,102,241,0.1)] border border-white/10">
              <div className="absolute inset-0 bg-gradient-to-br from-blue-600/10 via-transparent to-sky-500/10 pointer-events-none" />
              <div className="absolute inset-0 gf-grid opacity-10 pointer-events-none" />

              <div className="relative z-10">
                <div className="flex flex-col md:flex-row md:items-center justify-between gap-6 mb-16">
                  <div className="flex items-center gap-6">
                    <motion.div
                      animate={{ rotate: [0, 10, -10, 0] }}
                      transition={{ duration: 4, repeat: Infinity }}
                      className="h-16 w-16 rounded-[24px] bg-blue-500/20 flex items-center justify-center text-blue-400 border border-blue-500/30 shadow-[0_0_30px_rgba(99,102,241,0.2)]"
                    >
                      <Trophy size={32} />
                    </motion.div>
                    <div>
                      <h2 className="text-4xl font-black text-white tracking-tighter italic uppercase gf-chromatic">Global Hall of Fame</h2>
                      <p className="text-[10px] text-zinc-500 font-black uppercase tracking-[0.4em] mt-2">Neural Performance Distribution Network</p>
                    </div>
                  </div>
                  <div className="flex items-center gap-3 text-[10px] font-black text-emerald-400 bg-emerald-500/10 px-5 py-2.5 rounded-2xl border-2 border-emerald-500/20 shadow-[0_0_20px_rgba(16,185,129,0.1)]">
                    <div className="h-2 w-2 rounded-full bg-emerald-500 animate-ping" />
                    LIVE TELEMETRY
                  </div>
                </div>

                <div className="grid grid-cols-1 gap-6">
                  {leaderboard.slice(0, 5).map((item, i) => (
                    (() => {
                      const lbCreatorId = String(item?.userId || item?.creatorId || item?.ownerId || "").trim();
                      const lbCreator = String(item?.username || item?.creatorUsername || item?.creator || "creator").trim();
                      const lbAvatar = normalizeImageUrl(item?.avatar || item?.avatarUrl || "");
                      const scoreValue = Number(item?.score || item?.highScore || 0);
                      const xpValue = Number(item?.xp || item?.playCount || 0);
                      const coinsValue = Number(item?.coins || item?.installs || 0);
                      const trend = item?.streak ? `+${item.streak} streak` : "+live";

                      return (
                        <motion.div
                          key={i}
                          initial={{ opacity: 0, y: 20 }}
                          animate={{ opacity: 1, y: 0 }}
                          transition={{ delay: i * 0.1 }}
                          whileHover={{ y: -5, scale: 1.01 }}
                          className="group flex flex-col md:flex-row md:items-center gap-8 p-8 rounded-[40px] bg-white/[0.02] border-2 border-white/5 hover:border-blue-500/40 hover:bg-blue-500/[0.03] transition-all cursor-pointer relative overflow-hidden"
                        >
                          {/* Interactive Glow */}
                          <div className="absolute inset-0 bg-gradient-to-r from-blue-600/10 via-transparent to-sky-500/10 opacity-0 group-hover:opacity-100 transition-opacity" />

                          <div className="w-16 text-center shrink-0 relative z-10">
                            {i === 0 ? (
                              <div className="relative">
                                <Crown size={40} weight="duotone" className="text-amber-400 mx-auto drop-shadow-[0_0_20px_#fbbf24]" />
                                <motion.div animate={{ opacity: [0.2, 0.4, 0.2] }} transition={{ duration: 2, repeat: Infinity }} className="absolute inset-0 bg-amber-400 blur-2xl rounded-full" />
                              </div>
                            ) : i === 1 ? (
                              <Medal size={36} weight="duotone" className="text-zinc-300 mx-auto drop-shadow-[0_0_15px_#d4d4d8]" />
                            ) : i === 2 ? (
                              <Medal size={36} weight="duotone" className="text-amber-700/80 mx-auto" />
                            ) : (
                              <span className="text-3xl font-black text-zinc-800 group-hover:text-zinc-500 italic">0{i + 1}</span>
                            )}
                          </div>

                          <div className="flex-1 min-w-0 relative z-10">
                            <div className="flex items-center gap-3">
                              {lbAvatar ? (
                                <img src={lbAvatar} alt={lbCreator} className="h-11 w-11 rounded-2xl object-cover border border-white/20" />
                              ) : (
                                <div className="h-11 w-11 rounded-2xl bg-blue-500/30 border border-white/20 text-white text-sm font-black flex items-center justify-center">
                                  {(lbCreator || "C").slice(0, 1).toUpperCase()}
                                </div>
                              )}
                              <div>
                                <div className="text-2xl font-black text-white tracking-tighter uppercase italic group-hover:gf-chromatic transition-all truncate">{lbCreator || item.title || item.name}</div>
                                <div className="text-[10px] text-zinc-500 font-black uppercase tracking-[0.24em]">Creator Performance Rank</div>
                              </div>
                            </div>
                            <button
                              onClick={(e) => {
                                e.stopPropagation();
                                const creatorId = lbCreatorId || item.ownerId || item.creatorId || item.authorId || item.userId;
                                if (creatorId) router.push(`/studio/profile/${creatorId}`);
                              }}
                              className="mt-2 text-xs text-zinc-500 font-black tracking-[0.2em] uppercase hover:text-blue-400 transition-colors"
                            >
                              CREATOR: <span className="text-blue-400">@{lbCreator || item.ownerUsername || item.creatorUsername || item.creator}</span>
                            </button>
                          </div>

                          <div className="flex items-center gap-16 text-right shrink-0 relative z-10">
                            <div className="space-y-2">
                              <div className="text-[9px] font-black text-zinc-600 uppercase tracking-[0.3em]">Peak Score</div>
                              <div className="text-2xl font-black text-white italic tracking-tighter">{scoreValue.toLocaleString()}</div>
                            </div>
                            <div className="space-y-2 hidden sm:block">
                              <div className="text-[9px] font-black text-zinc-600 uppercase tracking-[0.3em]">XP</div>
                              <div className="text-2xl font-black text-white italic tracking-tighter">{xpValue.toLocaleString()}</div>
                            </div>
                            <div className="flex items-center gap-3 px-4 py-2 rounded-2xl bg-black/40 border-2 border-white/5">
                              <TrendingUp size={16} weight="bold" className="text-emerald-400" />
                              <span className="text-xs font-black text-emerald-400 tracking-tighter">{trend}</span>
                            </div>
                            <div className="space-y-2 hidden lg:block">
                              <div className="text-[9px] font-black text-zinc-600 uppercase tracking-[0.3em]">Coins</div>
                              <div className="text-2xl font-black text-white italic tracking-tighter">{coinsValue.toLocaleString()}</div>
                            </div>
                          </div>

                          <motion.button
                            whileHover={{ scale: 1.1, rotate: 5 }}
                            whileTap={{ scale: 0.9 }}
                            className="h-16 w-16 rounded-[24px] bg-white text-black flex items-center justify-center shadow-[0_15px_30px_rgba(255,255,255,0.2)] transition-all shrink-0 relative z-10 ml-4 group/btn"
                          >
                            <Play size={28} weight="fill" className="ml-1 group-hover/btn:scale-110 transition-transform" />
                          </motion.button>
                        </motion.div>
                      );
                    })()
                  ))}
                </div>
              </div>
            </div>
          </section>
        )}

        <AnimatePresence>
          {commentsOpenPostId ? (
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              className="fixed inset-0 z-[90] bg-black/70 backdrop-blur-sm md:hidden"
              onClick={() => setCommentsOpenPostId(null)}
            >
              <motion.div
                initial={{ y: 18, opacity: 0, scale: 0.98 }}
                animate={{ y: 0, opacity: 1, scale: 1 }}
                exit={{ y: 18, opacity: 0, scale: 0.98 }}
                onClick={(e) => e.stopPropagation()}
                className="absolute left-1/2 top-4 md:top-6 w-[min(92vw,560px)] max-h-[calc(100vh-2rem)] md:max-h-[calc(100vh-3rem)] -translate-x-1/2 rounded-3xl border border-white/10 bg-[var(--gf-bg)] overflow-hidden shadow-[0_20px_80px_rgba(0,0,0,0.55)] flex flex-col"
              >
                <div className="px-5 py-4 border-b border-white/10 flex items-center justify-between bg-gradient-to-r from-blue-500/10 to-transparent">
                  <div>
                    <div className="text-sm font-black text-white uppercase tracking-wide">Comments</div>
                    <div className="text-[10px] text-zinc-500 uppercase tracking-[0.26em]">Live community thread</div>
                    {commentsTargetItem ? (
                      <div className="mt-1 text-xs text-blue-200 font-semibold truncate max-w-[280px]">
                        {getTitle(commentsTargetItem)} • @{getCreator(commentsTargetItem)}
                      </div>
                    ) : null}
                  </div>
                  <button onClick={() => setCommentsOpenPostId(null)} className="h-9 w-9 rounded-xl border border-white/10 bg-white/5 text-zinc-300">
                    <X size={16} className="mx-auto" />
                  </button>
                </div>

                <div className="px-5 py-4 space-y-3 overflow-y-auto flex-1 min-h-0">
                  {commentsLoadingPostId === commentsOpenPostId ? (
                    <div className="text-sm text-zinc-500">Loading comments…</div>
                  ) : (commentsByPost[commentsOpenPostId] || []).length ? (
                    (commentsByPost[commentsOpenPostId] || []).map((c) => (
                      <div key={c.id} className="rounded-2xl border border-white/10 bg-white/[0.03] p-3">
                        <div className="flex items-center gap-2 mb-1">
                          {c.avatarUrl ? (
                            <img src={normalizeImageUrl(c.avatarUrl)} alt={c.username || "user"} className="h-7 w-7 rounded-full object-cover border border-white/20" />
                          ) : (
                            <span className="h-7 w-7 rounded-full bg-blue-500/25 border border-white/20 inline-flex items-center justify-center text-[10px] text-white font-black">
                              {String(c.username || "u").slice(0, 1).toUpperCase()}
                            </span>
                          )}
                          <span className="text-xs font-black text-zinc-200">@{c.username || "player"}</span>
                        </div>
                        <div className="text-sm text-zinc-300 whitespace-pre-wrap break-words">{c.text || "(voice comment)"}</div>
                      </div>
                    ))
                  ) : (
                    <div className="text-sm text-zinc-500">No comments yet. Be the first one ✨</div>
                  )}
                </div>

                <div className="p-4 border-t border-white/10 bg-black/30">
                  <div className="flex items-center gap-2">
                    <input
                      value={commentDraft}
                      onChange={(e) => setCommentDraft(e.target.value)}
                      onKeyDown={(e) => {
                        if (e.key === "Enter") {
                          e.preventDefault();
                          void submitComment();
                        }
                      }}
                      placeholder="Write a comment…"
                      className="flex-1 rounded-xl border border-white/10 bg-white/[0.03] px-3 py-2 text-sm text-white outline-none"
                    />
                    <button
                      onClick={() => void submitComment()}
                      disabled={commentBusy || !commentDraft.trim()}
                      className="h-10 px-4 rounded-xl border border-blue-500/40 bg-blue-500/20 text-blue-100 text-xs font-black uppercase tracking-wide disabled:opacity-40 inline-flex items-center gap-2"
                    >
                      <PaperPlaneTilt size={14} weight="fill" />
                      Send
                    </button>
                  </div>
                </div>
              </motion.div>
            </motion.div>
          ) : null}
        </AnimatePresence>

        <AnimatePresence>
          {tipOpen ? (
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              className="fixed inset-0 z-[95] bg-black/70 backdrop-blur-sm md:hidden"
              onClick={closeTipModal}
            >
              <motion.div
                initial={{ y: 18, opacity: 0, scale: 0.98 }}
                animate={{ y: 0, opacity: 1, scale: 1 }}
                exit={{ y: 18, opacity: 0, scale: 0.98 }}
                onClick={(e) => e.stopPropagation()}
                className="absolute left-1/2 top-4 md:top-6 w-[min(92vw,620px)] max-h-[calc(100vh-2rem)] md:max-h-[calc(100vh-3rem)] -translate-x-1/2 rounded-3xl border border-white/10 bg-[var(--gf-bg)] overflow-hidden shadow-[0_20px_90px_rgba(0,0,0,0.6)] flex flex-col"
              >
                <div className="px-5 py-4 border-b border-white/10 flex items-center justify-between bg-gradient-to-r from-emerald-500/10 via-transparent to-transparent">
                  <div>
                    <div className="text-[11px] text-emerald-300 font-black uppercase tracking-[0.22em]">Creator Tip</div>
                    <div className="text-base font-bold text-white">Send support to @{tipCreatorName}</div>
                    {tipTargetItem ? (
                      <div className="mt-1 text-xs text-zinc-300">For reel: {getTitle(tipTargetItem)}</div>
                    ) : null}
                  </div>
                  <button
                    onClick={closeTipModal}
                    className="h-9 w-9 rounded-xl border border-white/10 bg-white/5 text-zinc-300"
                  >
                    <X size={16} className="mx-auto" />
                  </button>
                </div>

                <div className="p-5 space-y-4 overflow-y-auto flex-1 min-h-0">
                  <div className="rounded-2xl border border-white/10 bg-white/[0.04] p-3 flex items-center justify-between">
                    <div>
                      <div className="text-[10px] uppercase tracking-[0.26em] text-zinc-500 font-black">Total payment</div>
                      <div className="text-xs text-zinc-400">Secure checkout powered by Stripe</div>
                    </div>
                    <div className="text-3xl font-black text-white">${Number(tipAmountUsd || 0).toFixed(2)}</div>
                  </div>

                  <div className="grid grid-cols-4 gap-2">
                    <button className="col-span-2 rounded-xl border border-blue-500/40 bg-blue-600/60 px-3 py-3 text-left">
                      <div className="text-xs font-black text-white">💳 Card</div>
                      <div className="text-[11px] text-white/80">Bank card</div>
                    </button>
                    <button className="rounded-xl border border-white/10 bg-white/[0.02] px-3 py-3 text-left">
                      <div className="text-xs font-black text-zinc-100">Pay</div>
                      <div className="text-[11px] text-zinc-500">Wallet</div>
                    </button>
                    <button className="rounded-xl border border-white/10 bg-white/[0.02] px-3 py-3 text-left">
                      <div className="text-xs font-black text-zinc-100">Link</div>
                      <div className="text-[11px] text-zinc-500">Fast</div>
                    </button>
                  </div>

                  <label className="space-y-1 block">
                    <div className="text-[10px] text-zinc-500 uppercase tracking-[0.22em]">Amount (USD)</div>
                    <input
                      type="number"
                      min={1}
                      max={50000}
                      value={tipAmountUsd}
                      onChange={(e) => setTipAmountUsd(Math.max(1, Math.min(50000, Number(e.target.value || 1))))}
                      className="w-full rounded-xl border border-white/10 bg-white/[0.03] px-3 py-2 text-white"
                    />
                  </label>

                  <label className="space-y-1 block">
                    <div className="text-[10px] text-zinc-500 uppercase tracking-[0.22em]">Message to creator (optional)</div>
                    <textarea
                      rows={3}
                      value={tipMessage}
                      onChange={(e) => setTipMessage(e.target.value.slice(0, 240))}
                      placeholder="Great reel! Keep cooking 🔥"
                      className="w-full rounded-xl border border-white/10 bg-white/[0.03] px-3 py-2 text-white resize-none"
                    />
                  </label>

                  {tipStep === "compose" ? (
                    <>
                      <div className="rounded-xl border border-blue-500/25 bg-blue-500/10 px-3 py-2 text-xs text-blue-100 font-semibold">
                        Step 1/2: set amount and message. This donation is linked to @{tipCreatorName}&apos;s creator wallet.
                      </div>
                      <button
                        onClick={() => void openTipCardStep()}
                        disabled={!tipCreatorId || tipBusy}
                        className="w-full rounded-xl border border-blue-500/35 bg-blue-500/20 px-4 py-3 text-sm font-black uppercase tracking-wide text-blue-100 disabled:opacity-40"
                      >
                        {tipBusy ? "Preparing secure payment…" : "Continue to card"}
                      </button>
                    </>
                  ) : (
                    <>
                      {tipBusy && !tipClientSecret ? (
                        <div className="rounded-xl border border-blue-500/25 bg-blue-500/10 px-3 py-3 text-sm text-blue-100">
                          Preparing secure in-app card form…
                        </div>
                      ) : tipInitError ? (
                        <div className="space-y-2">
                          <div className="rounded-xl border border-rose-500/35 bg-rose-500/10 px-3 py-2 text-xs text-rose-200 font-semibold">
                            {tipInitError}
                          </div>
                          <button
                            onClick={() => void openTipCardStep()}
                            className="w-full rounded-xl border border-blue-500/35 bg-blue-500/20 px-4 py-3 text-sm font-black uppercase tracking-wide text-blue-100"
                          >
                            Retry card setup
                          </button>
                        </div>
                      ) : tipClientSecret && stripePromise ? (
                        <Elements
                          stripe={stripePromise as any}
                          options={{
                            clientSecret: tipClientSecret,
                            appearance: {
                              theme: "night",
                              variables: {
                                colorPrimary: "#a855f7",
                                colorBackground: "#0b0b12",
                                colorText: "#ffffff",
                                colorDanger: "#fb7185",
                                fontFamily:
                                  "ui-sans-serif, system-ui, -apple-system, Segoe UI, Roboto, Helvetica, Arial",
                              },
                            },
                          }}
                        >
                          <TipCardPaymentForm
                            amountUsd={tipAmountUsd}
                            onBack={() => {
                              setTipStep("compose");
                              setTipInitError(null);
                            }}
                            onCancel={closeTipModal}
                            onSuccess={confirmTipLedger}
                          />
                        </Elements>
                      ) : (
                        <div className="rounded-xl border border-rose-500/35 bg-rose-500/10 px-3 py-2 text-xs text-rose-200 font-semibold">
                          Payment form unavailable right now. Please retry in a few seconds.
                        </div>
                      )}
                    </>
                  )}
                </div>
              </motion.div>
            </motion.div>
          ) : null}
        </AnimatePresence>
      </div>
    </UserShell>
  );
}
