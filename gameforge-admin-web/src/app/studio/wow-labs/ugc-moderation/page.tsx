"use client";

import { useEffect, useState } from "react";
import UserShell from "@/app/_components/UserShell";
import { apiFetch, ApiError } from "@/lib/api";
import { useLabsContext } from "../_lib/useLabsContext";
import { ContextMediaCard, WowHero } from "../_components/WowVisual";

type UgcInputItem = {
  id: string;
  type: string;
  text?: string;
  url?: string;
};

type ModerationSummary = {
  allowed: number;
  manualReview: number;
  quarantined: number;
};

type ModerationItem = {
  id: string;
  type: string;
  action: string;
  risk: number;
  status?: string;
};

type ModerationResult = {
  status?: string;
  trustScore: number;
  summary?: ModerationSummary;
  items?: ModerationItem[];
};

export default function UgcModerationModulePage() {
  const {
    token,
    loading: contextLoading,
    projects,
    selectedProject,
    selectedProjectId,
    setSelectedProjectId,
  } = useLabsContext({ withProjects: true, withTemplates: false });
  const [creatorId, setCreatorId] = useState("");
  const [payload, setPayload] = useState('[{"id":"txt1","type":"text","text":"friendly patch note"},{"id":"txt2","type":"text","text":"scam abuse content"}]');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [result, setResult] = useState<ModerationResult | null>(null);

  useEffect(() => {
    if (!creatorId && selectedProjectId) {
      setCreatorId(selectedProjectId);
    }
  }, [creatorId, selectedProjectId]);

  async function run() {
    setLoading(true);
    setError(null);
    try {
      const items = JSON.parse(payload) as UgcInputItem[];
      const data = await apiFetch<ModerationResult>("/platform-labs/ugc-moderation/scan", {
        method: "POST",
        token: token || undefined,
        body: { creatorId, items },
      });
      setResult(data);
    } catch (e: unknown) {
      const message = e instanceof ApiError ? e.message : e instanceof Error ? e.message : "Moderation scan failed";
      setError(message);
    } finally {
      setLoading(false);
    }
  }

  return (
    <UserShell title="UGC Moderation AI" subtitle="Scan text/image/audio/video + trust score + quarantine flow">
      {error ? <div className="mb-4 rounded-xl border border-red-500/25 bg-red-500/10 p-3 text-sm text-red-200">{error}</div> : null}
      <WowHero
        badge="Safety & Trust AI"
        title="Moderate UGC with Real Game Context"
        subtitle="Scan community submissions, assign trust score, and produce clear actions (allow/manual/quarantine) tied to your selected project."
        tone="cyan"
        mediaUrl={selectedProject?.previewImageUrl}
      >
        <div>
          <div className="text-[10px] uppercase tracking-[0.2em] text-zinc-300 font-black">Project Context</div>
          <select
            value={selectedProjectId}
            onChange={(e) => {
              const next = e.target.value;
              setSelectedProjectId(next);
              if (!creatorId || creatorId === selectedProjectId) setCreatorId(next);
            }}
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
          <div className="mt-2 text-xs text-zinc-300">{selectedProject?.description || "Use project context so moderation stats stay linked to a real game."}</div>
        </div>
        <input value={creatorId} onChange={(e) => setCreatorId(e.target.value)} className="gf-input w-full rounded-xl p-3" placeholder="creatorId" />
        <textarea value={payload} onChange={(e) => setPayload(e.target.value)} className="gf-input w-full min-h-[130px] rounded-xl p-3" />
        <button onClick={run} disabled={loading} className="rounded-xl bg-white px-4 py-2 text-sm font-black uppercase tracking-widest text-black">
          {loading ? "Scanning..." : "Scan UGC"}
        </button>
      </WowHero>

      <div className="mt-4">
        <ContextMediaCard
          label="Moderation Scope"
          name={selectedProject?.name || "No project selected"}
          description={selectedProject?.description}
          meta="Creator identity and trust score stay linked to this project context"
          mediaUrl={selectedProject?.previewImageUrl}
        />
      </div>

      {result ? (
        <div className="mt-5 rounded-2xl border border-cyan-500/25 bg-gradient-to-br from-cyan-500/15 to-black/30 p-4">
          <div className="text-xs uppercase tracking-widest text-cyan-200 font-black">Status: {result.status || "n/a"}</div>
          <div className="text-sm text-white font-black">Trust Score: {result.trustScore}</div>
          <div className="text-xs text-zinc-300 mt-1">
            Allowed: {result.summary?.allowed} • Manual: {result.summary?.manualReview} • Quarantine: {result.summary?.quarantined}
          </div>
          <div className="mt-3 space-y-2">
            {(result.items || []).map((it) => (
              <div key={it.id} className="rounded-xl border border-white/10 bg-black/30 p-2 text-xs text-zinc-200">
                {it.id} ({it.type}) → <span className="font-black">{it.status || it.action}</span> • risk {it.risk}
              </div>
            ))}
          </div>
        </div>
      ) : null}
    </UserShell>
  );
}
