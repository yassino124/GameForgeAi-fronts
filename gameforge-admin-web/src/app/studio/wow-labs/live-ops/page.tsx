"use client";

import { useState } from "react";
import UserShell from "@/app/_components/UserShell";
import { apiFetch, ApiError } from "@/lib/api";
import { useLabsContext } from "../_lib/useLabsContext";
import { ContextMediaCard, WowHero } from "../_components/WowVisual";

type Mission = {
  id: string;
  title: string;
  goal: string;
  reward: string;
};

type SeasonalEvent = {
  name: string;
  durationDays: number;
  eventQuests: number;
};

type BattlePassLite = {
  tiers: number;
};

type LiveOpsPlan = {
  dailyMissions: Mission[];
  seasonalEvent?: SeasonalEvent;
  battlePassLite?: BattlePassLite;
  runtimeEvent?: {
    event?: string;
    title?: string;
    durationHours?: number;
  };
};

export default function LiveOpsModulePage() {
  const {
    token,
    loading: contextLoading,
    projects,
    selectedProject,
    selectedProjectId,
    setSelectedProjectId,
  } = useLabsContext({ withProjects: true, withTemplates: false });
  const [genre, setGenre] = useState("Action");
  const [audience, setAudience] = useState("Core + Casual");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [plan, setPlan] = useState<LiveOpsPlan | null>(null);

  async function run() {
    setLoading(true);
    setError(null);
    try {
      if (!selectedProjectId) {
        setError("No real project selected. Please choose one from your projects.");
        return;
      }
      const data = await apiFetch<LiveOpsPlan>("/platform-labs/live-ops/plan", {
        method: "POST",
        token: token || undefined,
        body: { projectId: selectedProjectId, genre, audience },
      });
      setPlan(data);
    } catch (e: unknown) {
      const message = e instanceof ApiError ? e.message : e instanceof Error ? e.message : "Live ops planning failed";
      setError(message);
    } finally {
      setLoading(false);
    }
  }

  return (
    <UserShell title="Live Ops Engine" subtitle="Missions, seasonal events, timed boosts, battle pass lite">
      {error ? <div className="mb-4 rounded-xl border border-red-500/25 bg-red-500/10 p-3 text-sm text-red-200">{error}</div> : null}
      <WowHero
        badge="Live Ops Planner"
        title="Generate Retention Events"
        subtitle="Create daily missions, seasonal arcs and battle pass cadence personalized for your selected project."
        tone="cyan"
        mediaUrl={selectedProject?.previewImageUrl}
      >
        <div>
          <div className="text-[10px] uppercase tracking-[0.2em] text-zinc-300 font-black">Real Project</div>
          <select
            value={selectedProjectId}
            onChange={(e) => setSelectedProjectId(e.target.value)}
            className="gf-input mt-2 w-full rounded-xl p-2.5 text-sm"
            disabled={contextLoading}
          >
            {projects.length === 0 ? <option value="">No projects found</option> : null}
            {projects.map((p) => (
              <option key={p.id} value={p.id}>
                {p.name}
              </option>
            ))}
          </select>
          <div className="mt-2 text-xs text-zinc-300">{selectedProject?.description || "Select a project to generate a tailored live-ops cadence."}</div>
        </div>
        <div className="grid grid-cols-2 gap-3">
          <input value={genre} onChange={(e) => setGenre(e.target.value)} className="gf-input rounded-xl p-3" placeholder="genre" />
          <input value={audience} onChange={(e) => setAudience(e.target.value)} className="gf-input rounded-xl p-3" placeholder="audience" />
        </div>
        <button onClick={run} disabled={loading} className="rounded-xl bg-white px-4 py-2 text-sm font-black uppercase tracking-widest text-black">
          {loading ? "Planning..." : "Generate Live Ops Plan"}
        </button>
      </WowHero>

      <div className="mt-4">
        <ContextMediaCard
          label="Game Context"
          name={selectedProject?.name || "No project selected"}
          description={selectedProject?.description}
          meta={selectedProject?.status ? `Status: ${selectedProject.status}` : "Connected to /projects"}
          mediaUrl={selectedProject?.previewImageUrl}
        />
      </div>

      {plan ? (
        <div className="mt-5 grid grid-cols-1 lg:grid-cols-2 gap-4">
          <div className="rounded-2xl border border-white/10 bg-black/30 p-4">
            <div className="text-xs uppercase tracking-widest text-blue-200 font-black">Daily Missions</div>
            {(plan.dailyMissions || []).map((m) => (
              <div key={m.id} className="mt-2 text-sm text-zinc-200">• {m.title} — <span className="text-zinc-400">{m.reward}</span></div>
            ))}
          </div>
          <div className="rounded-2xl border border-white/10 bg-black/30 p-4">
            <div className="text-xs uppercase tracking-widest text-cyan-200 font-black">Seasonal Event</div>
            <div className="mt-2 text-sm text-white font-bold">{plan.seasonalEvent?.name}</div>
            <div className="text-xs text-zinc-400">{plan.seasonalEvent?.durationDays} days • {plan.seasonalEvent?.eventQuests} quests</div>
            <div className="mt-3 text-xs text-blue-200">Battle Pass: {plan.battlePassLite?.tiers} tiers</div>
            <div className="mt-2 text-xs text-emerald-200">Runtime Event: {plan.runtimeEvent?.event} ({plan.runtimeEvent?.durationHours}h)</div>
          </div>
        </div>
      ) : null}
    </UserShell>
  );
}
