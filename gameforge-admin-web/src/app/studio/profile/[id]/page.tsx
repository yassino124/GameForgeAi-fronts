"use client";

import { useEffect, useMemo, useState } from "react";
import { useParams, useRouter } from "next/navigation";
import { motion } from "framer-motion";
import {
  GameController, Users, Trophy, Globe, Calendar,
  ArrowLeft, Envelope as Mail, Play, Heart,
  SealCheck as Crown
} from "@phosphor-icons/react";
import UserShell from "@/app/_components/UserShell";
import { apiFetch } from "@/lib/api";
import { getUserToken } from "@/lib/userAuth";
import { normalizeImageUrl, resolveMediaUrl } from "@/lib/media";

function cx(...parts: Array<string | false | null | undefined>) {
  return parts.filter(Boolean).join(" ");
}

function toNum(v: any) {
  if (typeof v === "number") return v;
  if (typeof v === "string") return Number(v) || 0;
  return 0;
}

export default function UserProfilePage() {
  const params = useParams();
  const router = useRouter();
  const userId = params?.id as string;
  const token = useMemo(() => getUserToken(), []);

  const [me, setMe] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [profile, setProfile] = useState<any>(null);
  const [games, setGames] = useState<any[]>([]);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    async function loadProfile() {
      if (!userId) return;
      setLoading(true);
      try {
        const [userRes, gamesRes, meRes] = await Promise.allSettled([
          apiFetch<any>(`/auth/profile?userId=${userId}`, { method: "GET", token: token || undefined }),
          apiFetch<any>(`/game-feed`, { method: "GET", token: token || undefined }),
          apiFetch<any>(`/auth/profile`, { method: "GET", token: token || undefined })
        ]);

        if (meRes.status === 'fulfilled') {
          const meData = meRes.value?.data || meRes.value;
          setMe(meData?.user || meData);
        }

        if (userRes.status === 'fulfilled') {
          const uData = userRes.value?.data || userRes.value;
          const userData = uData?.user || uData;
          setProfile(userData);
          // If we are looking at our own profile, update 'me' too
          if (userData?.id === userId) setMe(userData);
        } else {
          setError("User systems synchronizing...");
        }

        if (gamesRes.status === 'fulfilled') {
          const gData = gamesRes.value?.data || gamesRes.value;
          const allGames = Array.isArray(gData) ? gData : (Array.isArray(gData?.items) ? gData.items : []);

          // Improved filtering
          const userGames = allGames.filter((g: any) =>
            String(g.creatorId || g.authorId || g.userId) === String(userId) ||
            String(g.creatorUsername).toLowerCase() === String(userId).toLowerCase()
          );
          setGames(userGames);

          if (!profile && userGames.length > 0) {
            setProfile({
              username: userGames[0].creatorUsername || userGames[0].creator || "Creator",
              bio: "Elite GameForge Architect",
              createdAt: new Date().toISOString(),
              avatar: userGames[0].creatorAvatar
            });
            setError(null);
          }
        }
      } catch (e) {
        setError("Failed to load profile");
      } finally {
        setLoading(false);
      }
    }
    loadProfile();
  }, [userId, token]);

  if (loading) {
    return (
      <UserShell title="Creator Profile" subtitle="Loading neural data...">
        <div className="flex items-center justify-center min-h-[60vh]">
          <div className="h-12 w-12 border-4 border-indigo-500 border-t-transparent animate-spin rounded-full" />
        </div>
      </UserShell>
    );
  }

  if (error || !profile) {
    return (
      <UserShell title="Error" subtitle="Profile unreachable">
        <div className="text-center py-20">
          <div className="text-2xl font-black text-white uppercase italic">User Not Found</div>
          <button onClick={() => router.back()} className="mt-6 gf-btn px-6 py-2 rounded-xl">Go Back</button>
        </div>
      </UserShell>
    );
  }

  const username = profile.ownerUsername || profile.username || "Creator";
  
  // Exhaustive search for the correct avatar URL
  const rawAvatar = (me && String(userId) === String(me.id) && me?.avatar)
    ? me.avatar
    : (profile?.avatar || profile?.ownerAvatar || profile?.creatorAvatar || profile?.imageUrl || profile?.avatarUrl || (games.length > 0 ? (games[0].avatarUrl || games[0].ownerAvatar || games[0].creatorAvatar || games[0].avatar) : null));
    
  const avatarUrl = normalizeImageUrl(rawAvatar);

  const handleLike = async (gameId: string) => {
    if (!token) return;
    try {
      await apiFetch(`/game-feed/${gameId}/like`, { method: "POST", token });
      // Optimistic update or refresh
      setGames(prev => prev.map(g => (g.id === gameId || g._id === gameId) ? { ...g, likes: (g.likes || 0) + 1 } : g));
    } catch (e) { }
  };

  const handlePlay = (game: any) => {
    const id = game.id || game._id;
    router.push(`/studio/arcade?play=${id}`);
  };

  return (
    <UserShell
      title={username}
      subtitle={`Member since ${new Date(profile.createdAt || Date.now()).toLocaleDateString()}`}
      right={
        <button onClick={() => router.back()} className="gf-btn px-4 py-2 rounded-xl flex items-center gap-2 font-bold text-sm">
          <ArrowLeft size={16} weight="bold" /> Back
        </button>
      }
    >
      <div className="max-w-6xl mx-auto space-y-12 pb-20">
        {/* Profile Header */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          className="gf-panel-strong rounded-[48px] p-10 relative overflow-hidden border border-white/10"
        >
          <div className="absolute inset-0 bg-gradient-to-br from-indigo-500/10 via-transparent to-fuchsia-500/10" />
          <div className="relative z-10 flex flex-col md:flex-row items-center gap-10">
            <div className="h-40 w-40 rounded-[48px] bg-gradient-to-br from-indigo-600 to-fuchsia-600 flex items-center justify-center text-white text-6xl font-black shadow-2xl border-4 border-white/10 overflow-hidden">
              {avatarUrl ? (
                <img src={avatarUrl} className="h-full w-full object-cover" alt={username} />
              ) : (
                <div className="h-full w-full flex items-center justify-center bg-gradient-to-br from-indigo-500 to-fuchsia-600 font-mono">
                  {username.substring(0, 1).toUpperCase()}
                </div>
              )}
            </div>
            <div className="flex-1 text-center md:text-left space-y-4">
              <div className="flex flex-col md:flex-row md:items-center gap-4">
                <h2 className="text-5xl font-black text-white tracking-tighter italic uppercase gf-chromatic">{username}</h2>
                <div className="px-4 py-1 rounded-full bg-indigo-500/20 border border-indigo-500/30 text-indigo-400 text-[10px] font-black uppercase tracking-widest flex items-center gap-2 self-center md:self-auto">
                  <Crown size={12} weight="fill" />
                  {profile.ownerRole === "admin" ? "System Architect" : profile.ownerRole || "Verified Creator"}
                </div>
              </div>
              <p className="text-zinc-400 font-medium max-w-2xl leading-relaxed">
                {profile.bio || "This elite creator hasn't added a bio yet. Their games speak for themselves."}
              </p>
              <div className="flex flex-wrap justify-center md:justify-start gap-6 pt-4">
                <div className="flex items-center gap-2 text-zinc-500 text-xs font-bold uppercase tracking-widest">
                  <GameController size={16} weight="duotone" className="text-indigo-400" /> {games.length} Games
                </div>
                <div className="flex items-center gap-2 text-zinc-500 text-xs font-bold uppercase tracking-widest">
                  <Users size={16} weight="duotone" className="text-fuchsia-400" /> {profile.followerCount || "1.2k"} Followers
                </div>
                <div className="flex items-center gap-2 text-zinc-500 text-xs font-bold uppercase tracking-widest">
                  <Trophy size={16} weight="duotone" className="text-amber-400" /> {games.reduce((acc, g) => acc + toNum(g.playCount || g.views || 0), 0).toLocaleString()} Plays
                </div>
              </div>
            </div>
          </div>
        </motion.div>

        {/* Creator's Creations */}
        <div className="space-y-8">
          <div className="flex items-center justify-between px-4">
            <h3 className="text-2xl font-black text-white italic uppercase tracking-tighter">Neural Library</h3>
            <div className="text-[10px] font-black text-zinc-500 uppercase tracking-[0.3em]">Latest Deployments</div>
          </div>

          {games.length === 0 ? (
            <div className="gf-panel rounded-[32px] p-20 text-center border-dashed border-white/5">
              <div className="text-4xl mb-4 opacity-20">🎮</div>
              <div className="text-zinc-500 font-bold uppercase tracking-widest">No games published yet</div>
            </div>
          ) : (
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-8">
              {games.map((game, idx) => (
                <motion.div
                  key={game.id || idx}
                  initial={{ opacity: 0, scale: 0.9 }}
                  animate={{ opacity: 1, scale: 1 }}
                  transition={{ delay: idx * 0.1 }}
                  whileHover={{ y: -10 }}
                  className="gf-panel group rounded-[40px] overflow-hidden border border-white/5 hover:border-indigo-500/30 transition-all bg-white/[0.02]"
                >
                  <div className="aspect-[16/10] relative overflow-hidden bg-zinc-900">
                    <img
                      src={resolveMediaUrl(game.thumbnailUrl || game.imageUrl || game.previewImageUrl)}
                      className="h-full w-full object-cover transition-transform duration-700 group-hover:scale-110"
                      alt=""
                      onError={(e) => {
                        (e.target as HTMLImageElement).src = "https://images.unsplash.com/photo-1550745165-9bc0b252726f?q=80&w=2070";
                      }}
                    />
                    <div className="absolute inset-0 bg-gradient-to-t from-black via-black/20 to-transparent" />
                    <div className="absolute bottom-4 left-6">
                      <div className="text-xl font-black text-white italic uppercase tracking-tight gf-chromatic">{game.title || game.name}</div>
                    </div>
                  </div>
                  <div className="p-6 flex items-center justify-between">
                    <div className="flex items-center gap-4">
                      <div className="flex items-center gap-1.5 text-[10px] font-black text-zinc-500 uppercase tracking-widest">
                        <Play size={12} weight="fill" className="text-indigo-400" /> {game.playCount || game.views || 0}
                      </div>
                      <button
                        onClick={() => handleLike(game.id || game._id)}
                        className="flex items-center gap-1.5 text-[10px] font-black text-zinc-500 uppercase tracking-widest hover:text-rose-400 transition-colors"
                      >
                        <Heart size={12} weight="fill" className="text-rose-400" /> {game.likes || game.likeCount || 0}
                      </button>
                    </div>
                    <button
                      onClick={() => handlePlay(game)}
                      className="h-10 w-10 rounded-xl bg-white text-black flex items-center justify-center shadow-lg hover:scale-110 transition-transform"
                    >
                      <Play size={18} weight="fill" className="ml-0.5" />
                    </button>
                  </div>
                </motion.div>
              ))}
            </div>
          )}
        </div>
      </div>
    </UserShell>
  );
}
