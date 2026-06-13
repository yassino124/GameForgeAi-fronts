"use client";

import { useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { motion } from "framer-motion";
import {
  MagnifyingGlass as Search,
  Compass,
  Play,
  Plus,
  Check,
  X,
  Sparkle,
  FilmSlate,
  Fire,
} from "@phosphor-icons/react";
import UserShell from "@/app/_components/UserShell";
import { apiFetch } from "@/lib/api";
import { useAuthToken } from "@/lib/stores/authStore";
import { normalizeImageUrl } from "@/lib/media";

const TABS = ["Trending", "New", "Following", "For You", "Creators", "Collections"] as const;

function getId(it: any, idx: number) {
  return String(it?.id || it?._id || it?.projectId || it?.buildId || `item-${idx}`);
}

function getTitle(it: any) {
  return String(it?.title || it?.name || "Untitled");
}

function getCreator(it: any) {
  return String(
    it?.ownerUsername ||
      it?.creatorUsername ||
      it?.creator?.username ||
      it?.creator?.name ||
      it?.creator ||
      "creator",
  ).trim();
}

function getCreatorId(it: any) {
  return String(it?.creatorId || it?.ownerId || it?.userId || it?.authorId || it?.creator?.id || it?.creator?._id || "").trim();
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
      "",
  );
}

function getCreatedAtMs(it: any) {
  const raw = it?.createdAt || it?.publishedAt || it?.updatedAt || it?.date || null;
  const ms = raw ? Date.parse(String(raw)) : NaN;
  return Number.isFinite(ms) ? ms : 0;
}

function getTrendScore(it: any) {
  const plays = Number(it?.playCount || 0);
  const likes = Number(it?.likeCount || 0);
  const comments = Number(it?.commentCount || 0);
  const wow = Number(it?.wowScore || 0);
  const createdMs = getCreatedAtMs(it);
  const ageHours = createdMs ? Math.max(1, (Date.now() - createdMs) / (1000 * 60 * 60)) : 72;
  const freshnessBoost = Math.max(0, 42 - ageHours) * 1.35;
  return plays * 0.7 + likes * 2.4 + comments * 2 + wow * 1.6 + freshnessBoost;
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
  return (
    normalizeImageUrl(raw) ||
    "https://images.unsplash.com/photo-1550745165-9bc0b252726f?auto=format&fit=crop&q=80&w=1200"
  );
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

function getContentKind(it: any): "Game" | "Reel" {
  const kind = String(it?.kind || "").trim().toLowerCase();
  if (kind === "reel") return "Reel";
  if (kind === "game") return "Game";
  const title = String(it?.title || it?.name || "").toLowerCase();
  if (title.includes("reel") || title.includes("trailer") || title.includes("clip")) return "Reel";
  if (getReelVideoUrl(it)) return "Reel";
  const hasPlayableGame = Boolean(it?.playUrl || it?.webglUrl || it?.gameUrl || it?.previewUrl);
  return hasPlayableGame ? "Game" : "Reel";
}

function SmartMediaThumb({ item, title, className }: { item: any; title: string; className?: string }) {
  const fallback = getThumb(item);
  const trailerUrl = getReelVideoUrl(item);
  const [frame, setFrame] = useState<string | null>(null);
  const [failed, setFailed] = useState(false);

  useEffect(() => {
    if (!trailerUrl || frame || failed) return;
    let disposed = false;

    const video = document.createElement("video");
    video.crossOrigin = "anonymous";
    video.preload = "metadata";
    video.muted = true;
    video.playsInline = true;

    const cleanup = () => {
      video.pause();
      video.removeAttribute("src");
      try {
        video.load();
      } catch {
        // ignore
      }
    };

    video.addEventListener("loadeddata", () => {
      try {
        const duration = Number.isFinite(video.duration) ? Math.max(0, Number(video.duration || 0)) : 0;
        const target = duration > 0
          ? Math.min(Math.max(duration * 0.35, 0.65), Math.max(0.2, duration - 0.15))
          : 1.1;
        video.currentTime = target;
      } catch {
        setFailed(true);
      }
    });

    video.addEventListener("seeked", () => {
      if (disposed) return;
      try {
        const width = Math.max(1, video.videoWidth || 640);
        const height = Math.max(1, video.videoHeight || 360);
        const canvas = document.createElement("canvas");
        canvas.width = width;
        canvas.height = height;
        const ctx = canvas.getContext("2d");
        if (!ctx) {
          setFailed(true);
          return;
        }
        ctx.drawImage(video, 0, 0, width, height);
        const sample = ctx.getImageData(0, 0, Math.min(width, 96), Math.min(height, 96)).data;
        let sum = 0;
        let count = 0;
        for (let i = 0; i < sample.length; i += 16) {
          const r = sample[i] ?? 0;
          const g = sample[i + 1] ?? 0;
          const b = sample[i + 2] ?? 0;
          sum += 0.299 * r + 0.587 * g + 0.114 * b;
          count += 1;
        }
        const avgLuma = count > 0 ? sum / count : 255;
        if (avgLuma < 22) {
          setFailed(true);
          return;
        }
        const captured = canvas.toDataURL("image/jpeg", 0.86);
        if (!disposed && captured.startsWith("data:image/")) {
          setFrame(captured);
        }
      } catch {
        setFailed(true);
      } finally {
        cleanup();
      }
    });

    video.addEventListener("error", () => {
      if (!disposed) setFailed(true);
      cleanup();
    });

    try {
      video.src = trailerUrl;
      video.load();
    } catch {
      setFailed(true);
      cleanup();
    }

    return () => {
      disposed = true;
      cleanup();
    };
  }, [failed, frame, trailerUrl]);

  return <img src={frame || fallback} alt={title} className={className} />;
}

export default function StudioDiscoveryPage() {
  type ReelCollection = {
    id: string;
    name: string;
    description?: string;
    reelIds: string[];
    createdAt: string;
  };

  const COLLECTIONS_STORAGE_KEY = "gf.discovery.collections.v1";
  const router = useRouter();
  const { token } = useAuthToken();
  const [loading, setLoading] = useState(true);
  const [items, setItems] = useState<any[]>([]);
  const [q, setQ] = useState("");
  const [activeTab, setActiveTab] = useState<(typeof TABS)[number]>("Trending");
  const [collections, setCollections] = useState<ReelCollection[]>([]);
  const [collectionName, setCollectionName] = useState("");
  const [collectionDescription, setCollectionDescription] = useState("");
  const [selectedReelIds, setSelectedReelIds] = useState<string[]>([]);
  const [activeCollectionId, setActiveCollectionId] = useState<string | null>(null);
  const [pickerOpen, setPickerOpen] = useState(false);
  const [pickerSearch, setPickerSearch] = useState("");
  const [pickerFilter, setPickerFilter] = useState<"All" | "Games" | "Reels">("All");

  const trendingItems = useMemo(
    () => [...items].sort((a: any, b: any) => getTrendScore(b) - getTrendScore(a)),
    [items],
  );

  const preferenceProfile = useMemo(() => {
    const creatorWeights = new Map<string, number>();
    const tagWeights = new Map<string, number>();
    const sourceReelIds = new Set(collections.flatMap((c) => c.reelIds));

    sourceReelIds.forEach((rid) => {
      const it = items.find((entry: any, idx: number) => getId(entry, idx) === rid);
      if (!it) return;
      const creatorId = getCreatorId(it) || getCreator(it).toLowerCase();
      creatorWeights.set(creatorId, (creatorWeights.get(creatorId) || 0) + 1);
      for (const tag of Array.isArray(it?.tags) ? it.tags : []) {
        const key = String(tag || "").toLowerCase().trim();
        if (!key) continue;
        tagWeights.set(key, (tagWeights.get(key) || 0) + 1);
      }
    });

    return { creatorWeights, tagWeights };
  }, [collections, items]);

  const forYouItems = useMemo(() => {
    const { creatorWeights, tagWeights } = preferenceProfile;
    return [...items].sort((a: any, b: any) => {
      const aCreatorId = getCreatorId(a) || getCreator(a).toLowerCase();
      const bCreatorId = getCreatorId(b) || getCreator(b).toLowerCase();

      const aCreatorBoost = (creatorWeights.get(aCreatorId) || 0) * 14;
      const bCreatorBoost = (creatorWeights.get(bCreatorId) || 0) * 14;

      const aTagBoost = (Array.isArray(a?.tags) ? a.tags : []).reduce((sum: number, tag: any) => {
        const key = String(tag || "").toLowerCase().trim();
        return sum + (tagWeights.get(key) || 0) * 4;
      }, 0);
      const bTagBoost = (Array.isArray(b?.tags) ? b.tags : []).reduce((sum: number, tag: any) => {
        const key = String(tag || "").toLowerCase().trim();
        return sum + (tagWeights.get(key) || 0) * 4;
      }, 0);

      const aScore = getTrendScore(a) * 0.72 + aCreatorBoost + aTagBoost;
      const bScore = getTrendScore(b) * 0.72 + bCreatorBoost + bTagBoost;
      return bScore - aScore;
    });
  }, [items, preferenceProfile]);

  useEffect(() => {
    const params = new URLSearchParams(window.location.search);
    const seedQ = String(params.get("q") || "").trim();
    setQ(seedQ);
  }, []);

  useEffect(() => {
    try {
      const raw = localStorage.getItem(COLLECTIONS_STORAGE_KEY);
      if (!raw) return;
      const parsed = JSON.parse(raw);
      if (Array.isArray(parsed)) {
        const normalized = parsed
          .map((entry: any) => ({
            id: String(entry?.id || "").trim(),
            name: String(entry?.name || "").trim(),
            description: String(entry?.description || "").trim(),
            reelIds: Array.isArray(entry?.reelIds) ? entry.reelIds.map((x: any) => String(x || "").trim()).filter(Boolean) : [],
            createdAt: String(entry?.createdAt || new Date().toISOString()),
          }))
          .filter((entry: ReelCollection) => entry.id && entry.name && entry.reelIds.length);
        setCollections(normalized);
      }
    } catch {
      setCollections([]);
    }
  }, []);

  useEffect(() => {
    try {
      localStorage.setItem(COLLECTIONS_STORAGE_KEY, JSON.stringify(collections));
    } catch {
      // ignore storage errors
    }
  }, [collections]);

  useEffect(() => {
    let cancelled = false;
    async function load() {
      setLoading(true);
      try {
        const res = await apiFetch<any>("/game-feed?limit=120", {
          method: "GET",
          token: token || undefined,
        });
        const list = Array.isArray(res) ? res : Array.isArray(res?.items) ? res.items : [];
        if (!cancelled) setItems(list.filter((it: any) => it?.kind !== "ad"));
      } catch {
        if (!cancelled) setItems([]);
      } finally {
        if (!cancelled) setLoading(false);
      }
    }
    void load();
    return () => {
      cancelled = true;
    };
  }, [token]);

  const filtered = useMemo(() => {
    const needle = q.trim().toLowerCase();
    let base = trendingItems;

    if (activeTab === "New") {
      base = [...items].sort((a: any, b: any) => getCreatedAtMs(b) - getCreatedAtMs(a));
    } else if (activeTab === "For You") {
      base = forYouItems;
    } else if (activeTab === "Creators") {
      base = trendingItems;
    } else if (activeTab === "Collections") {
      base = trendingItems;
    }

    if (!needle) return base;

    return base.filter((it: any) =>
      [
        it?.title,
        it?.name,
        it?.description,
        it?.reelPromoText,
        it?.creatorUsername,
        it?.ownerUsername,
        ...(Array.isArray(it?.tags) ? it.tags : []),
      ]
        .map((x) => String(x || "").toLowerCase())
        .some((x) => x.includes(needle)),
    );
  }, [activeTab, forYouItems, items, q, trendingItems]);

  const itemById = useMemo(() => {
    const map = new Map<string, any>();
    items.forEach((it: any, idx: number) => map.set(getId(it, idx), it));
    return map;
  }, [items]);

  const selectedDraftItems = useMemo(
    () => selectedReelIds.map((id) => itemById.get(id)).filter(Boolean),
    [itemById, selectedReelIds],
  );

  const pickerItems = useMemo(() => {
    const needle = pickerSearch.trim().toLowerCase();
    return items.filter((it: any) => {
      const kind = getContentKind(it);
      if (pickerFilter === "Games" && kind !== "Game") return false;
      if (pickerFilter === "Reels" && kind !== "Reel") return false;
      if (!needle) return true;
      return [
        getTitle(it),
        getCreator(it),
        it?.description,
        it?.reelPromoText,
        ...(Array.isArray(it?.tags) ? it.tags : []),
      ]
        .map((x) => String(x || "").toLowerCase())
        .some((x) => x.includes(needle));
    });
  }, [items, pickerFilter, pickerSearch]);

  const selectedCollection = useMemo(
    () => collections.find((c) => c.id === activeCollectionId) || null,
    [activeCollectionId, collections],
  );

  const creatorProfiles = useMemo(() => {
    const groups = new Map<string, {
      id: string;
      username: string;
      avatar: string;
      reels: any[];
      totalPlays: number;
      totalLikes: number;
      trendScore: number;
    }>();

    items.forEach((it: any, idx: number) => {
      const id = getCreatorId(it) || `creator-${getCreator(it).toLowerCase()}-${idx}`;
      const username = getCreator(it);
      const avatar = getCreatorAvatar(it);
      const prev = groups.get(id);
      const nextReels = [...(prev?.reels || []), it];
      const totalPlays = (prev?.totalPlays || 0) + Number(it?.playCount || 0);
      const totalLikes = (prev?.totalLikes || 0) + Number(it?.likeCount || 0);
      groups.set(id, {
        id,
        username,
        avatar: avatar || prev?.avatar || "",
        reels: nextReels,
        totalPlays,
        totalLikes,
        trendScore: (prev?.trendScore || 0) + getTrendScore(it),
      });
    });

    return [...groups.values()]
      .map((creator) => ({
        ...creator,
        topReels: [...creator.reels]
          .sort((a: any, b: any) => getTrendScore(b) - getTrendScore(a))
          .slice(0, 3),
      }))
      .sort((a, b) => b.trendScore - a.trendScore);
  }, [items]);

  const creatorsVisible = useMemo(() => {
    const needle = q.trim().toLowerCase();
    if (!needle) return creatorProfiles;
    return creatorProfiles.filter((creator) => {
      if (creator.username.toLowerCase().includes(needle)) return true;
      return creator.reels.some((it: any) =>
        [
          getTitle(it),
          it?.description,
          ...(Array.isArray(it?.tags) ? it.tags : []),
        ]
          .map((x) => String(x || "").toLowerCase())
          .some((x) => x.includes(needle)),
      );
    });
  }, [creatorProfiles, q]);

  const tabCounters = useMemo(() => ({
    Trending: trendingItems.length,
    New: items.length,
    Following: items.length,
    "For You": forYouItems.length,
    Creators: creatorProfiles.length,
    Collections: collections.length,
  }), [collections.length, creatorProfiles.length, forYouItems.length, items.length, trendingItems.length]);

  const visibleItems = useMemo(() => {
    if (activeTab !== "Collections") return filtered;
    if (!selectedCollection) return filtered;
    const idSet = new Set(selectedCollection.reelIds);
    return filtered.filter((it: any, idx: number) => idSet.has(getId(it, idx)));
  }, [activeTab, filtered, selectedCollection]);

  const toggleSelectedReel = (reelId: string) => {
    setSelectedReelIds((prev) => (prev.includes(reelId) ? prev.filter((id) => id !== reelId) : [...prev, reelId]));
  };

  const createCollection = () => {
    const cleanName = collectionName.trim().slice(0, 48);
    if (!cleanName || selectedReelIds.length === 0) return;
    const created: ReelCollection = {
      id: `col-${Date.now()}`,
      name: cleanName,
      description: collectionDescription.trim().slice(0, 120),
      reelIds: selectedReelIds,
      createdAt: new Date().toISOString(),
    };
    setCollections((prev) => [created, ...prev]);
    setCollectionName("");
    setCollectionDescription("");
    setSelectedReelIds([]);
    setActiveCollectionId(created.id);
    setPickerOpen(false);
    setPickerSearch("");
    setPickerFilter("All");
  };

  const removeCollection = (collectionId: string) => {
    setCollections((prev) => prev.filter((entry) => entry.id !== collectionId));
    setActiveCollectionId((prev) => (prev === collectionId ? null : prev));
  };

  return (
    <UserShell title="Discovery" subtitle="Explore games, creators, tags and collections">
      <div className="space-y-8 pb-16">
        <section className="gf-panel-strong rounded-[48px] border border-white/10 p-8 md:p-12 relative overflow-hidden group">
          {/* Animated Background */}
          <div className="absolute top-0 right-0 w-[500px] h-[500px] bg-blue-500/20 blur-[120px] rounded-full mix-blend-screen pointer-events-none group-hover:bg-blue-500/30 transition-all duration-1000" />
          <div className="absolute bottom-0 left-0 w-[400px] h-[400px] bg-cyan-500/10 blur-[100px] rounded-full mix-blend-screen pointer-events-none group-hover:bg-cyan-500/20 transition-all duration-1000" />
          
          <div className="relative z-10 space-y-6 max-w-3xl">
            <div className="inline-flex items-center gap-2 rounded-full border border-blue-500/30 bg-blue-500/10 backdrop-blur-md px-4 py-1.5 text-xs font-black uppercase tracking-widest text-blue-300 shadow-[0_0_20px_rgba(99,102,241,0.15)]">
              <Compass size={14} className="animate-spin-slow" />
              Global Neural Network
            </div>
            
            <h1 className="text-5xl md:text-6xl font-black tracking-tighter text-white italic uppercase gf-chromatic drop-shadow-[0_0_25px_rgba(255,255,255,0.2)]">
              Discover Content
            </h1>
            
            <p className="text-sm font-medium text-zinc-400 max-w-xl leading-relaxed">
              Explore the multiverse of games, reels, and creators generated across the GameForge network.
            </p>
          </div>

          <div className="relative z-10 mt-10 flex flex-col lg:flex-row gap-6">
            <div className="flex flex-wrap items-center gap-2 lg:gap-3 bg-white/[0.02] p-2 rounded-[28px] border border-white/5 backdrop-blur-xl shrink-0 shadow-2xl">
              {TABS.map((tab) => (
                <button
                  key={tab}
                  onClick={() => setActiveTab(tab)}
                  className={`rounded-[20px] px-6 py-3 text-[11px] font-black uppercase tracking-widest transition-all inline-flex items-center gap-2 ${
                    activeTab === tab
                      ? "bg-gradient-to-br from-blue-500 to-cyan-600 text-white shadow-[0_0_25px_rgba(99,102,241,0.4)] border border-white/20"
                      : "bg-transparent text-zinc-400 hover:text-white hover:bg-white/5"
                  }`}
                >
                  {tab}
                  <span className={`rounded-full px-2 py-0.5 text-[9px] font-black tracking-tight ${activeTab === tab ? "bg-black/30 text-white" : "bg-black/40 text-zinc-500"}`}>
                    {tabCounters[tab].toLocaleString()}
                  </span>
                </button>
              ))}
            </div>

            <div className="relative flex-1 group/search">
              <div className="absolute inset-0 bg-blue-500/5 blur-xl opacity-0 group-focus-within/search:opacity-100 transition-opacity" />
              <Search className="absolute left-6 top-1/2 -translate-y-1/2 text-zinc-500 group-focus-within/search:text-blue-400 transition-colors" size={24} />
              <input
                value={q}
                onChange={(e) => setQ(e.target.value)}
                placeholder="Search games, creators, tags..."
                className="gf-input w-full rounded-[28px] border border-white/10 focus:border-blue-500/40 bg-black/40 pl-16 pr-6 py-5 text-sm font-bold text-white outline-none shadow-inner transition-all h-full"
              />
            </div>
          </div>
        </section>

        {activeTab === "Collections" && !loading ? (
          <section className="space-y-6">
            <div className="gf-panel-strong gf-stroke-gradient rounded-[48px] p-8 md:p-12 relative overflow-hidden group">
              <div className="absolute inset-0 bg-gradient-to-br from-blue-500/5 via-transparent to-transparent pointer-events-none" />
              <div className="relative z-10 space-y-8">
                <div className="flex flex-col md:flex-row md:items-center justify-between gap-6">
                  <div>
                    <h2 className="text-4xl md:text-5xl font-black tracking-tight text-white italic uppercase gf-chromatic">My Curations</h2>
                    <p className="text-sm font-bold text-zinc-500 mt-2 uppercase tracking-widest">Build custom neural drops</p>
                  </div>
                  <button
                    onClick={() => setPickerOpen(true)}
                    className="inline-flex items-center gap-2 rounded-[20px] bg-white text-black px-6 py-4 text-[10px] font-black uppercase tracking-widest hover:scale-105 active:scale-95 transition-all shadow-xl"
                  >
                    <Plus size={16} strokeWidth={3} />
                    New Drop
                  </button>
                </div>

                <div className="grid grid-cols-1 lg:grid-cols-[1fr_1fr_auto] gap-4 bg-black/20 p-4 rounded-[32px] border border-white/5 backdrop-blur-xl">
                  <label className="space-y-2">
                    <div className="text-[10px] font-black uppercase tracking-[0.24em] text-zinc-500 ml-2">Collection name</div>
                    <input
                      value={collectionName}
                      onChange={(e) => setCollectionName(e.target.value)}
                      placeholder="e.g. Premium Platformers"
                      className="gf-input w-full rounded-[20px] border border-white/10 bg-black/40 px-5 py-4 text-sm text-white font-bold outline-none focus:border-blue-500/50 transition-all shadow-inner"
                    />
                  </label>
                  <label className="space-y-2">
                    <div className="text-[10px] font-black uppercase tracking-[0.24em] text-zinc-500 ml-2">Description</div>
                    <input
                      value={collectionDescription}
                      onChange={(e) => setCollectionDescription(e.target.value)}
                      placeholder="Best hand-picked drops"
                      className="gf-input w-full rounded-[20px] border border-white/10 bg-black/40 px-5 py-4 text-sm text-white font-bold outline-none focus:border-blue-500/50 transition-all shadow-inner"
                    />
                  </label>
                  <button
                    onClick={createCollection}
                    disabled={!collectionName.trim() || selectedReelIds.length === 0}
                    className="self-end h-[54px] rounded-[20px] bg-blue-500 px-8 text-[11px] font-black uppercase tracking-widest text-white disabled:opacity-20 shadow-[0_10px_30px_rgba(99,102,241,0.2)]"
                  >
                    Draft Drop
                  </button>
                </div>

                {selectedDraftItems.length ? (
                  <div className="flex flex-wrap items-center gap-3 bg-white/[0.02] p-6 rounded-[28px] border border-white/5">
                    {selectedDraftItems.slice(0, 8).map((it: any, idx: number) => {
                      const id = getId(it, idx);
                      return (
                        <button
                          key={`draft-${id}`}
                          onClick={() => toggleSelectedReel(id)}
                          className="group inline-flex items-center gap-3 rounded-full border border-blue-500/30 bg-blue-500/10 p-1.5 pr-4 hover:bg-rose-500/10 hover:border-rose-500/30 transition-all"
                        >
                          <SmartMediaThumb
                            item={it}
                            title={getTitle(it)}
                            className="h-8 w-8 rounded-full object-cover border border-white/20 shadow-md"
                          />
                          <span className="text-xs font-black text-blue-100 max-w-[120px] truncate uppercase tracking-tight group-hover:text-rose-200">{getTitle(it)}</span>
                          <X size={12} className="text-blue-400 group-hover:text-rose-400 group-hover:scale-110 transition-all" />
                        </button>
                      );
                    })}
                    {selectedDraftItems.length > 8 ? (
                      <span className="text-[10px] font-black uppercase tracking-widest text-zinc-500 ml-2">+{selectedDraftItems.length - 8} stacked</span>
                    ) : null}
                  </div>
                ) : (
                  <div className="bg-white/[0.02] p-8 rounded-[28px] border border-dashed border-white/10 text-center">
                    <div className="text-sm font-medium text-zinc-500">Cart empty. Tap <strong className="text-blue-400">New Drop</strong> to curate.</div>
                  </div>
                )}
              </div>
            </div>

            {collections.length ? (
              <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
                {collections.map((col) => {
                  const previewItems = col.reelIds
                    .map((rid) => itemById.get(rid))
                    .filter(Boolean)
                    .slice(0, 4);
                  const heroItem = previewItems[0];
                  return (
                    <article
                      key={col.id}
                      className={`rounded-[26px] border p-3 transition-all overflow-hidden relative ${
                        activeCollectionId === col.id
                          ? "border-blue-400/60 bg-blue-500/15 shadow-[0_0_40px_rgba(99,102,241,0.2)]"
                          : "border-white/10 bg-black/35 hover:border-blue-500/30"
                      }`}
                    >
                      <div className="absolute inset-0 bg-gradient-to-b from-blue-500/10 via-transparent to-black/30 pointer-events-none" />
                      <div className="relative z-10">
                        <div className="rounded-2xl overflow-hidden border border-white/10 bg-black/40 h-36">
                          {heroItem ? (
                            <SmartMediaThumb
                              item={heroItem}
                              title={getTitle(heroItem)}
                              className="h-full w-full object-cover"
                            />
                          ) : (
                            <div className="h-full w-full bg-black/40" />
                          )}
                        </div>
                        <div className="mt-2 grid grid-cols-3 gap-2">
                          {previewItems.slice(1, 4).map((it: any, idx: number) => (
                            <SmartMediaThumb
                              key={`${col.id}-thumb-${idx}`}
                              item={it}
                              title={getTitle(it)}
                              className="h-14 w-full rounded-xl object-cover border border-white/10"
                            />
                          ))}
                          {!previewItems.length ? (
                            <div className="col-span-3 h-14 rounded-xl border border-dashed border-white/10 bg-black/30" />
                          ) : null}
                        </div>

                        <div className="mt-3">
                          <div className="text-sm font-black text-white truncate">{col.name}</div>
                          {col.description ? <div className="text-xs text-zinc-300 mt-1 line-clamp-2">{col.description}</div> : null}
                          <div className="mt-2 flex items-center justify-between">
                            <div className="text-[11px] uppercase tracking-[0.2em] text-zinc-400 font-black">{col.reelIds.length} reels</div>
                            <div className="inline-flex items-center gap-1 text-[10px] text-blue-200 font-bold uppercase tracking-wide">
                              <Sparkle size={11} weight="fill" />
                              Smart cover
                            </div>
                          </div>
                        </div>

                        <div className="mt-3 flex items-center justify-between gap-2">
                          <button
                            onClick={() => setActiveCollectionId(col.id)}
                            className="rounded-full border border-blue-500/35 bg-blue-500/20 px-3 py-1.5 text-[11px] font-black uppercase tracking-wide text-blue-100"
                          >
                            Open
                          </button>
                          <button
                            onClick={() => removeCollection(col.id)}
                            className="rounded-full border border-rose-500/30 bg-rose-500/10 px-3 py-1.5 text-[11px] font-black uppercase tracking-wide text-rose-200"
                          >
                            Delete
                          </button>
                        </div>
                      </div>
                    </article>
                  );
                })}
              </div>
            ) : (
              <div className="rounded-[20px] border border-dashed border-white/10 p-8 text-center">
                <div className="text-4xl mb-3">✨</div>
                <div className="text-xl font-black text-zinc-200">No collections yet</div>
                <div className="text-sm text-zinc-500 mt-1">Click <span className="text-blue-300">New</span>, pick reels, then create your first curated drop.</div>
              </div>
            )}

            {pickerOpen ? (
              <div className="fixed inset-0 z-[120] bg-black/70 backdrop-blur-sm" onClick={() => setPickerOpen(false)}>
                <div
                  className="absolute left-1/2 top-4 md:top-6 w-[min(92vw,760px)] max-h-[calc(100vh-2rem)] md:max-h-[calc(100vh-3rem)] -translate-x-1/2 rounded-[30px] border border-white/10 bg-[#050913] overflow-hidden shadow-[0_30px_120px_rgba(0,0,0,0.65)] flex flex-col"
                  onClick={(e) => e.stopPropagation()}
                >
                  <div className="p-5 border-b border-white/10 flex items-center justify-between">
                    <div>
                      <div className="text-2xl font-black text-white tracking-tight">Pick games / reels</div>
                      <div className="text-xs text-zinc-400">Select content for your new collection</div>
                    </div>
                    <button
                      onClick={() => setPickerOpen(false)}
                      className="h-9 w-9 rounded-xl border border-white/10 bg-white/5 text-zinc-300 inline-flex items-center justify-center"
                    >
                      <X size={16} />
                    </button>
                  </div>

                  <div className="p-5 border-b border-white/10 space-y-3">
                    <div className="relative">
                      <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-zinc-500" size={18} />
                      <input
                        value={pickerSearch}
                        onChange={(e) => setPickerSearch(e.target.value)}
                        placeholder="Search in feed..."
                        className="w-full rounded-xl border border-white/10 bg-black/40 pl-10 pr-3 py-2.5 text-sm text-white outline-none"
                      />
                    </div>

                    <div className="flex items-center gap-2">
                      {(["All", "Games", "Reels"] as const).map((f) => (
                        <button
                          key={f}
                          onClick={() => setPickerFilter(f)}
                          className={`rounded-xl px-4 py-2 text-sm font-black transition-colors ${
                            pickerFilter === f
                              ? "bg-blue-500/35 text-blue-100 border border-blue-400/40"
                              : "bg-white/[0.03] text-zinc-300 border border-white/10"
                          }`}
                        >
                          {pickerFilter === f ? <Check size={14} className="inline mr-1" /> : null}
                          {f}
                        </button>
                      ))}
                    </div>
                  </div>

                  <div className="p-3 md:p-4 overflow-y-auto flex-1 min-h-0 space-y-2">
                    {pickerItems.map((it: any, idx: number) => {
                      const id = getId(it, idx);
                      const selected = selectedReelIds.includes(id);
                      const kind = getContentKind(it);
                      const plays = Number(it?.playCount || 0);
                      return (
                        <button
                          key={`pick-${id}`}
                          onClick={() => toggleSelectedReel(id)}
                          className={`w-full rounded-2xl border px-3 py-2 text-left transition-colors ${
                            selected
                              ? "border-blue-400/50 bg-blue-500/10 shadow-[0_0_25px_rgba(99,102,241,0.18)]"
                              : "border-white/10 bg-white/[0.02] hover:bg-white/[0.05]"
                          }`}
                        >
                          <div className="flex items-center gap-3">
                            <div className={`h-6 w-6 rounded-md border inline-flex items-center justify-center ${selected ? "border-blue-300 bg-blue-500/30" : "border-white/20"}`}>
                              {selected ? <Check size={14} className="text-blue-100" weight="bold" /> : null}
                            </div>
                            <div className="min-w-0 flex-1">
                              <div className="text-lg font-black text-white truncate">{getTitle(it)}</div>
                              <div className="text-sm text-zinc-400 inline-flex items-center gap-2 flex-wrap">
                                <span className={`inline-flex items-center rounded-full border px-2 py-0.5 text-[10px] font-black uppercase tracking-wide ${kind === "Reel" ? "border-cyan-400/40 bg-cyan-500/15 text-cyan-100" : "border-cyan-400/40 bg-cyan-500/15 text-cyan-100"}`}>
                                  {kind}
                                </span>
                                <span>@{getCreator(it)}</span>
                                <span className="text-zinc-500">• {plays.toLocaleString()} plays</span>
                              </div>
                            </div>
                            <SmartMediaThumb
                              item={it}
                              title={getTitle(it)}
                              className={`h-12 w-12 rounded-xl object-cover border ${selected ? "border-blue-300/60" : "border-white/10"}`}
                            />
                          </div>
                        </button>
                      );
                    })}

                    {!pickerItems.length ? (
                      <div className="rounded-2xl border border-dashed border-white/10 p-5 text-sm text-zinc-500 text-center">
                        No feed items found for this filter.
                      </div>
                    ) : null}
                  </div>

                  <div className="p-4 border-t border-white/10 bg-black/40 flex items-center justify-between">
                    <div className="text-xs text-zinc-400 inline-flex items-center gap-2">
                      <FilmSlate size={14} />
                      {selectedReelIds.length} selected
                    </div>
                    <button
                      onClick={() => setPickerOpen(false)}
                      className="rounded-xl border border-blue-500/40 bg-blue-500/20 px-4 py-2 text-xs font-black uppercase tracking-wide text-blue-100"
                    >
                      Done
                    </button>
                  </div>
                </div>
              </div>
            ) : null}
          </section>
        ) : null}

        {loading ? (
          <div className="gf-panel-strong rounded-[36px] p-12 text-center border border-white/10 text-zinc-400">Syncing discovery graph…</div>
        ) : activeTab === "Creators" ? (
          creatorsVisible.length === 0 ? (
            <div className="gf-panel-strong rounded-[36px] p-12 text-center border border-white/10">
              <div className="text-zinc-500">No creators found for this filter.</div>
            </div>
          ) : (
            <section className="grid grid-cols-1 xl:grid-cols-2 gap-4">
              {creatorsVisible.map((creator, idx) => {
                const leadReel = creator.topReels[0];
                return (
                  <motion.article
                    key={creator.id}
                    initial={{ opacity: 0, y: 16 }}
                    animate={{ opacity: 1, y: 0 }}
                    transition={{ delay: Math.min(0.25, idx * 0.03) }}
                    className="rounded-[28px] border border-white/10 bg-black/40 overflow-hidden"
                  >
                    <div className="relative h-40 border-b border-white/10">
                      {leadReel ? (
                        <SmartMediaThumb item={leadReel} title={getTitle(leadReel)} className="h-full w-full object-cover" />
                      ) : (
                        <div className="h-full w-full bg-black/50" />
                      )}
                      <div className="absolute inset-0 bg-gradient-to-t from-[#050813] via-black/30 to-transparent" />
                      <div className="absolute top-3 right-3 inline-flex items-center gap-2 rounded-full border border-amber-400/40 bg-amber-500/15 px-3 py-1 text-[10px] font-black uppercase tracking-wide text-amber-100">
                        <Fire size={12} weight="fill" />
                        Trending creator
                      </div>
                    </div>

                    <div className="p-4">
                      <div className="flex items-center justify-between gap-3">
                        <div className="flex items-center gap-3 min-w-0">
                          {creator.avatar ? (
                            <img src={creator.avatar} alt={creator.username} className="h-12 w-12 rounded-2xl object-cover border border-white/20" />
                          ) : (
                            <div className="h-12 w-12 rounded-2xl border border-white/20 bg-blue-500/25 text-white font-black flex items-center justify-center">
                              {creator.username.slice(0, 1).toUpperCase()}
                            </div>
                          )}
                          <div className="min-w-0">
                            <div className="text-xl font-black text-white truncate">@{creator.username}</div>
                            <div className="text-[11px] text-zinc-500 uppercase tracking-[0.22em] font-black">Creator Profile</div>
                          </div>
                        </div>
                        <button
                          onClick={() => {
                            if (creator.id.startsWith("creator-")) return;
                            router.push(`/studio/profile/${creator.id}`);
                          }}
                          className="rounded-full border border-blue-500/35 bg-blue-500/20 px-4 py-1.5 text-xs font-black uppercase tracking-wide text-blue-100"
                        >
                          Profile
                        </button>
                      </div>

                      <div className="mt-4 grid grid-cols-3 gap-2">
                        <div className="rounded-xl border border-white/10 bg-white/[0.02] p-2">
                          <div className="text-[10px] text-zinc-500 uppercase tracking-[0.22em] font-black">Reels</div>
                          <div className="text-lg font-black text-white">{creator.reels.length}</div>
                        </div>
                        <div className="rounded-xl border border-white/10 bg-white/[0.02] p-2">
                          <div className="text-[10px] text-zinc-500 uppercase tracking-[0.22em] font-black">Plays</div>
                          <div className="text-lg font-black text-white">{creator.totalPlays.toLocaleString()}</div>
                        </div>
                        <div className="rounded-xl border border-white/10 bg-white/[0.02] p-2">
                          <div className="text-[10px] text-zinc-500 uppercase tracking-[0.22em] font-black">Likes</div>
                          <div className="text-lg font-black text-white">{creator.totalLikes.toLocaleString()}</div>
                        </div>
                      </div>

                      <div className="mt-4 flex items-center gap-2 overflow-x-auto pb-1">
                        {creator.topReels.map((reel: any, reelIdx: number) => {
                          const reelId = getId(reel, reelIdx);
                          return (
                            <button
                              key={`${creator.id}-reel-${reelId}`}
                              onClick={() => router.push(`/studio/arcade?play=${encodeURIComponent(reelId)}`)}
                              className="min-w-[132px] rounded-xl border border-white/10 bg-black/35 p-2 text-left"
                            >
                              <SmartMediaThumb item={reel} title={getTitle(reel)} className="h-16 w-full rounded-lg object-cover" />
                              <div className="mt-1 text-xs text-zinc-200 truncate font-bold">{getTitle(reel)}</div>
                            </button>
                          );
                        })}
                      </div>
                    </div>
                  </motion.article>
                );
              })}
            </section>
          )
        ) : visibleItems.length === 0 ? (
          <div className="gf-panel-strong rounded-[36px] p-12 text-center border border-white/10">
            <div className="text-zinc-500">No results for this discovery filter.</div>
          </div>
        ) : (
          <section className="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-3 2xl:grid-cols-4 gap-4">
            {visibleItems.map((it: any, idx: number) => {
              const id = getId(it, idx);
              const title = getTitle(it);
              const creator = getCreator(it);
              const selected = selectedReelIds.includes(id);
              const kind = getContentKind(it);
              return (
                <motion.article
                  key={id}
                  initial={{ opacity: 0, y: 14 }}
                  animate={{ opacity: 1, y: 0 }}
                  transition={{ delay: Math.min(0.35, idx * 0.015) }}
                  className="relative rounded-[26px] overflow-hidden border border-white/10 bg-black/40"
                >
                  <SmartMediaThumb item={it} title={title} className="h-52 w-full object-cover" />
                  <div className="absolute inset-0 bg-gradient-to-t from-[#060814] via-black/20 to-transparent" />

                  <div className="absolute top-3 left-3 inline-flex items-center gap-2 rounded-full border border-white/20 bg-black/40 px-3 py-1 text-xs text-zinc-100 font-bold">
                    <Play size={12} weight="fill" /> {Number(it?.playCount || 0)}
                  </div>

                  <div className="absolute right-3 top-3 rounded-full border border-white/20 bg-black/40 px-3 py-1 text-xs text-zinc-100 font-black uppercase tracking-wider">
                    {kind}
                  </div>

                  {activeTab === "Collections" ? (
                    <button
                      onClick={() => toggleSelectedReel(id)}
                      className={`absolute left-3 top-14 rounded-full border px-3 py-1 text-[11px] font-black uppercase tracking-wide transition-colors ${
                        selected
                          ? "border-emerald-400/50 bg-emerald-500/25 text-emerald-100"
                          : "border-white/20 bg-black/45 text-zinc-200"
                      }`}
                    >
                      {selected ? "Selected" : "Add"}
                    </button>
                  ) : null}

                  <div className="absolute bottom-0 left-0 right-0 p-4">
                    <div className="text-2xl font-black text-white leading-tight line-clamp-2">{title}</div>
                    <div className="mt-1 text-zinc-300 font-semibold text-sm">@{creator}</div>
                    <div className="mt-3 flex items-center justify-between">
                      <button
                        onClick={() => router.push(`/studio/profile/${String(it?.creatorId || it?.ownerId || it?.userId || "")}`)}
                        className="text-xs text-zinc-400 hover:text-blue-300 uppercase tracking-[0.2em] font-black"
                      >
                        Creator
                      </button>
                      <button
                        onClick={() => router.push(`/studio/arcade?play=${encodeURIComponent(id)}`)}
                        className="rounded-full border border-blue-500/35 bg-blue-500/20 px-4 py-1.5 text-xs font-black uppercase tracking-wide text-blue-100"
                      >
                        Preview
                      </button>
                    </div>
                  </div>
                </motion.article>
              );
            })}
          </section>
        )}

        <div className="flex justify-center">
          <button
            onClick={() => router.push("/studio/arcade")}
            className="inline-flex items-center gap-2 rounded-2xl border border-white/10 bg-white/[0.04] px-4 py-2 text-sm font-black text-zinc-200"
          >
            <Compass size={16} weight="duotone" />
            Back to Arcade Feed
          </button>
        </div>
      </div>
    </UserShell>
  );
}
