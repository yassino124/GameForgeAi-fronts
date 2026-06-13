"use client";

import { useMemo, useState } from "react";
import UserShell from "@/app/_components/UserShell";
import { apiFetch, ApiError } from "@/lib/api";
import { useLabsContext } from "../_lib/useLabsContext";
import { ContextMediaCard, WowHero } from "../_components/WowVisual";
import { WandSparkles } from "lucide-react";

type RankedTemplate = {
  _id?: string;
  id?: string;
  name?: string;
  title?: string;
  score?: number;
  reasons?: string[];
};

type SmartMatchResult = {
  detectedIntent?: string;
  preferred?: string;
  playerProfile?: {
    avgSessionMin?: number;
    avgScore?: number;
    topCategory?: string;
    sampleSize?: number;
  };
  rankedTemplates?: RankedTemplate[];
};

export default function SmartMatchModulePage() {
  const {
    token,
    loading: contextLoading,
    templates,
    selectedTemplate,
    selectedTemplateId,
    setSelectedTemplateId,
  } = useLabsContext({ withProjects: false, withTemplates: true });
  const [prompt, setPrompt] = useState("dark 2d fps shooter with tactical movement");
  const [playerSignalsRaw, setPlayerSignalsRaw] = useState(
    '[{"gameId":"g_arc_1","category":"arcade","durationMin":8,"score":620,"completed":true},{"gameId":"g_run_2","category":"runner","durationMin":11,"score":840,"completed":true},{"gameId":"g_arc_3","category":"arcade","durationMin":9,"score":760,"completed":true}]',
  );
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [result, setResult] = useState<SmartMatchResult | null>(null);

  const rankedInputTemplates = useMemo(() => {
    if (!templates.length) return [];
    if (!selectedTemplateId) return templates;
    const selected = templates.find((t) => t.id === selectedTemplateId);
    const rest = templates.filter((t) => t.id !== selectedTemplateId);
    return selected ? [selected, ...rest] : templates;
  }, [templates, selectedTemplateId]);

  async function run() {
    setLoading(true);
    setError(null);
    try {
      if (!rankedInputTemplates.length) {
        setError("No real templates found. Add templates first, then retry.");
        return;
      }
      const res = await apiFetch<SmartMatchResult>("/platform-labs/smart-match/run", {
        method: "POST",
        token: token || undefined,
        body: {
          prompt,
          templates: rankedInputTemplates,
          playerSignals: { sessions: JSON.parse(playerSignalsRaw) },
        },
      });
      setResult(res);
    } catch (e: unknown) {
      const message = e instanceof ApiError ? e.message : e instanceof Error ? e.message : "Smart match failed";
      setError(message);
    } finally {
      setLoading(false);
    }
  }

  return (
    <UserShell title="Smart Match v2" subtitle="Intent classifier + hard rerank + explanation chips">
      {error ? <div className="mb-4 rounded-xl border border-red-500/25 bg-red-500/10 p-3 text-sm text-red-200">{error}</div> : null}
      <WowHero
        badge="Smart Match Engine"
        title="Rank Templates with AI Intent"
        subtitle="Pick any real template from your catalog, then run a prompt-aware rerank that returns explainable reasons for the top matches."
        tone="blue"
        mediaUrl={selectedTemplate?.previewImageUrl}
      >
        <div className="grid grid-cols-1 gap-3 lg:grid-cols-2">
          <div className="rounded-xl border border-white/10 bg-black/25 p-3">
            <div className="flex items-center gap-2 text-[10px] uppercase tracking-[0.2em] text-zinc-300 font-black"><WandSparkles size={12} /> Template Catalog</div>
            <select
              value={selectedTemplateId}
              onChange={(e) => setSelectedTemplateId(e.target.value)}
              className="gf-input mt-2 w-full rounded-xl p-2.5 text-sm"
              disabled={contextLoading}
            >
              {templates.length === 0 ? <option value="">No templates found</option> : null}
              {templates.map((t) => (
                <option key={t.id} value={t.id}>
                  {t.name}
                </option>
              ))}
            </select>
            <div className="mt-2 text-xs text-zinc-300">{selectedTemplate?.category || "Category unknown"}</div>
          </div>
          <div className="rounded-xl border border-white/10 bg-black/25 p-3 text-xs text-zinc-300">
            <div className="font-black uppercase tracking-widest text-[10px] text-blue-200">Connected Source</div>
            <div className="mt-1">Using real `/templates` catalog instead of mock templates.</div>
            <div className="mt-1">Total candidates: {rankedInputTemplates.length}</div>
          </div>
        </div>
        <textarea value={prompt} onChange={(e) => setPrompt(e.target.value)} className="gf-input w-full min-h-[120px] rounded-xl p-3" />
        <textarea
          value={playerSignalsRaw}
          onChange={(e) => setPlayerSignalsRaw(e.target.value)}
          className="gf-input w-full min-h-[120px] rounded-xl p-3 text-xs"
          placeholder='[{"gameId":"g1","category":"arcade","durationMin":8,"score":600}]'
        />
        <button onClick={run} disabled={loading} className="rounded-xl bg-white px-4 py-2 text-sm font-black uppercase tracking-widest text-black">
          {loading ? "Matching..." : "Run Smart Match"}
        </button>
      </WowHero>

      <div className="mt-4">
        <ContextMediaCard
          label="Active Template"
          name={selectedTemplate?.name || "No template selected"}
          description={selectedTemplate?.description}
          meta={selectedTemplate?.category ? `${selectedTemplate.category} • ${(selectedTemplate.tags || []).slice(0, 4).join(" • ")}` : "Select from your real catalog"}
          mediaUrl={selectedTemplate?.previewImageUrl}
        />
      </div>

      {result ? (
        <div className="mt-5 rounded-2xl border border-blue-500/25 bg-gradient-to-br from-blue-500/15 to-black/30 p-4">
          <div className="text-xs uppercase tracking-widest text-blue-200 font-black">Detected intent: {result.detectedIntent}</div>
          <div className="mt-1 text-sm text-white font-black">Preferred: {result.preferred || "n/a"}</div>
          <div className="text-xs text-zinc-300">
            Avg session: {result.playerProfile?.avgSessionMin ?? 0} min • Avg score: {result.playerProfile?.avgScore ?? 0} • Category: {result.playerProfile?.topCategory || "n/a"}
          </div>
          <div className="mt-2 space-y-2">
            {(result.rankedTemplates || []).slice(0, 5).map((t) => (
              <div key={String(t._id || t.id || t.name)} className="rounded-xl border border-white/10 bg-black/30 p-3">
                <div className="text-white font-black">{t.name || t.title}</div>
                <div className="text-xs text-zinc-400">score: {t.score}</div>
                <div className="mt-1 flex flex-wrap gap-2">
                  {(t.reasons || []).slice(0, 2).map((r: string, i: number) => (
                    <span key={i} className="rounded-full border border-blue-400/25 bg-blue-500/10 px-2 py-0.5 text-[10px] text-blue-100">{r}</span>
                  ))}
                </div>
              </div>
            ))}
          </div>
        </div>
      ) : null}
    </UserShell>
  );
}
