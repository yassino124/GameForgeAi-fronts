"use client";

import { useState } from "react";
import UserShell from "@/app/_components/UserShell";
import { apiFetch, ApiError } from "@/lib/api";
import { useLabsContext } from "../_lib/useLabsContext";
import { ContextMediaCard, WowHero } from "../_components/WowVisual";

type PlaytestFinding = {
  code: string;
  severity: string;
  detected: boolean;
  evidence: string;
  suggestedFix: string;
};

type PlaytestReport = {
  qualityScore: number;
  summary: string;
  findings: PlaytestFinding[];
  isPlayable?: boolean;
  simulation?: {
    actionsTested?: string[];
    playableRuns?: number;
    blockedRuns?: number;
    playabilityRate?: number;
    avgScore?: number;
    expectedScoreRange?: [number, number];
  };
};

export default function PlaytestModulePage() {
  const {
    token,
    loading: contextLoading,
    projects,
    selectedProject,
    selectedProjectId,
    setSelectedProjectId,
  } = useLabsContext({ withProjects: true, withTemplates: false });
  const [prompt, setPrompt] = useState("neon runner with dense obstacles");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [report, setReport] = useState<PlaytestReport | null>(null);

  async function run() {
    setLoading(true);
    setError(null);
    try {
      if (!selectedProjectId) {
        setError("No real project selected. Please choose one from your projects.");
        return;
      }
      const data = await apiFetch<PlaytestReport>("/platform-labs/playtest/run", {
        method: "POST",
        token: token || undefined,
        body: { projectId: selectedProjectId, prompt },
      });
      setReport(data);
    } catch (e: unknown) {
      const message = e instanceof ApiError ? e.message : e instanceof Error ? e.message : "Playtest failed";
      setError(message);
    } finally {
      setLoading(false);
    }
  }

  return (
    <UserShell title="AI Playtest Bot" subtitle="Auto QA before final build">
      {error ? <div className="mb-4 rounded-xl border border-red-500/25 bg-red-500/10 p-3 text-sm text-red-200">{error}</div> : null}
      <WowHero
        badge="Playtest QA Bot"
        title="Run AI QA on Real Projects"
        subtitle="Generate bug findings, quality score, and practical fixes before shipping. Uses your selected project context from platform data."
        tone="emerald"
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
          <div className="mt-2 text-xs text-zinc-300">{selectedProject?.description || "Pick a project to run AI QA."}</div>
        </div>
        <input value={prompt} onChange={(e) => setPrompt(e.target.value)} className="gf-input w-full rounded-xl p-3" placeholder="prompt" />
        <button onClick={run} disabled={loading} className="rounded-xl bg-white px-4 py-2 text-sm font-black uppercase tracking-widest text-black">
          {loading ? "Running QA..." : "Run Playtest"}
        </button>
      </WowHero>

      <div className="mt-4">
        <ContextMediaCard
          label="Target Project"
          name={selectedProject?.name || "No project selected"}
          description={selectedProject?.description}
          meta={selectedProject?.status ? `Status: ${selectedProject.status}` : "Connected to /projects"}
          mediaUrl={selectedProject?.previewImageUrl}
        />
      </div>

      {report ? (
        <div className="mt-5 rounded-2xl border border-emerald-500/25 bg-gradient-to-br from-emerald-500/15 to-black/30 p-4">
          <div className="text-sm text-white font-black">Quality Score: {report.qualityScore}</div>
          <div className="text-xs text-emerald-200 mt-1">Playable: {report.isPlayable ? "Yes" : "No"} • Rate: {report.simulation?.playabilityRate ?? 0}%</div>
          <div className="text-xs text-zinc-300 mt-1">
            Actions: {(report.simulation?.actionsTested || []).join(", ")} • Score range: {report.simulation?.expectedScoreRange?.[0] ?? 0} - {report.simulation?.expectedScoreRange?.[1] ?? 0}
          </div>
          <div className="text-xs text-zinc-300 mt-1">{report.summary}</div>
          <div className="mt-3 space-y-2">
            {(report.findings || []).filter((f) => f.detected).map((f) => (
              <div key={f.code} className="rounded-xl border border-white/10 bg-black/30 p-3">
                <div className="text-xs text-amber-300 font-black">{f.code} • {f.severity}</div>
                <div className="text-xs text-zinc-300">{f.evidence}</div>
                <div className="text-xs text-blue-200 mt-1">Fix: {f.suggestedFix}</div>
              </div>
            ))}
          </div>
        </div>
      ) : null}
    </UserShell>
  );
}
