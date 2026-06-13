"use client";

import { Suspense } from "react";
import { useQuery } from "@tanstack/react-query";
import { useRouter, useSearchParams } from "next/navigation";
import UserShell from "@/app/_components/UserShell";
import { apiFetch, ApiError } from "@/lib/api";
import { useAuthToken } from "@/lib/stores/authStore";

type DownloadUrlRes = { url?: string };

type PreviewUrlRes = { url?: string };

export default function BuildResultsPage() {
  return (
    <Suspense fallback={null}>
      <BuildResultsPageInner />
    </Suspense>
  );
}

function BuildResultsPageInner() {
  const router = useRouter();
  const sp = useSearchParams();
  const { token, hydrated } = useAuthToken();
  const projectId = (sp?.get("projectId") ?? "").trim();
  const target = (sp?.get("target") ?? "").trim();

  const resultsQuery = useQuery<{
    downloadUrl: string | null;
    previewUrl: string | null;
  }>({
    queryKey: ["build-results", token, projectId, target],
    enabled: hydrated && !!token && !!projectId,
    queryFn: async () => {
      const q = target ? `?target=${encodeURIComponent(target)}` : "";
      const [dl, pr] = await Promise.all([
        apiFetch(`/projects/${encodeURIComponent(projectId)}/download-url${q}`, { method: "GET", token: token! }),
        apiFetch(`/projects/${encodeURIComponent(projectId)}/preview-url`, { method: "GET", token: token! }),
      ]);

      const dlData = (dl && typeof dl === "object" && "data" in dl)
        ? (dl as { data?: DownloadUrlRes | { data?: DownloadUrlRes } }).data
        : dl;
      const prData = (pr && typeof pr === "object" && "data" in pr)
        ? (pr as { data?: PreviewUrlRes | { data?: PreviewUrlRes } }).data
        : pr;

      const dlObj = (dlData && typeof dlData === "object" && "data" in (dlData as object))
        ? (dlData as { data?: DownloadUrlRes }).data
        : (dlData as DownloadUrlRes | undefined);
      const prObj = (prData && typeof prData === "object" && "data" in (prData as object))
        ? (prData as { data?: PreviewUrlRes }).data
        : (prData as PreviewUrlRes | undefined);

      return {
        downloadUrl: dlObj?.url || null,
        previewUrl: prObj?.url || null,
      };
    },
  });

  const loading = !hydrated || resultsQuery.isLoading;
  const error = !projectId
    ? "Missing projectId"
    : resultsQuery.error instanceof ApiError
      ? resultsQuery.error.message
      : resultsQuery.error instanceof Error
        ? resultsQuery.error.message
        : null;
  const downloadUrl = resultsQuery.data?.downloadUrl ?? null;
  const previewUrl = resultsQuery.data?.previewUrl ?? null;

  return (
    <UserShell
      title="Build Matrix"
      subtitle={target ? `Target compilation: ${target.toUpperCase()}` : "Your neural build is ready to deploy"}
      right={
        <div className="flex flex-wrap items-center gap-3">
          <button
            className="rounded-2xl border border-white/10 bg-white/[0.03] px-6 py-3 text-[10px] font-black uppercase tracking-widest text-zinc-300 hover:text-white hover:bg-white/10 transition-all shadow-lg"
            onClick={() => router.push(`/studio/builds/progress?projectId=${encodeURIComponent(projectId)}${target ? `&target=${encodeURIComponent(target)}` : ""}`)}
          >
            Terminal Output
          </button>
          <button className="rounded-2xl border border-blue-500/30 bg-blue-500/20 px-6 py-3 text-[10px] font-black uppercase tracking-widest text-blue-100 hover:bg-blue-500/35 transition-all shadow-[0_0_20px_rgba(99,102,241,0.2)]" onClick={() => router.push(`/studio/projects/${encodeURIComponent(projectId)}`)}>
            Manage Project
          </button>
        </div>
      }
    >
      {error ? (
        <div className="mb-6 rounded-[24px] border border-rose-500/30 bg-rose-500/10 px-6 py-4 text-sm font-bold text-rose-200 flex items-center gap-3 shadow-[0_0_30px_rgba(244,63,94,0.15)]">
          <div className="h-2 w-2 rounded-full bg-rose-500 animate-pulse" />
          {error}
        </div>
      ) : null}

      <div className="gf-panel-strong gf-stroke-gradient rounded-[48px] p-8 md:p-12 relative overflow-hidden group">
        <div className="absolute inset-0 bg-gradient-to-br from-blue-500/10 via-transparent to-transparent pointer-events-none" />
        
        <div className="relative z-10 flex flex-col md:flex-row md:items-center justify-between gap-6 pb-8 border-b border-white/10">
          <div>
            <div className="inline-flex items-center gap-2 rounded-full border border-blue-500/30 bg-blue-500/10 backdrop-blur-md px-3 py-1 mb-4 text-[9px] font-black uppercase tracking-[0.2em] text-blue-300">
              <span className={`h-1.5 w-1.5 rounded-full ${loading ? "bg-amber-400 animate-pulse" : "bg-emerald-400"}`} />
              System Status
            </div>
            <h1 className="text-4xl md:text-5xl font-black tracking-tight text-white italic uppercase gf-chromatic">
              {loading ? "Compiling Node..." : "Build Successful"}
            </h1>
          </div>
          <div className="h-16 w-16 md:h-20 md:w-20 rounded-[24px] bg-gradient-to-br from-blue-500/35 via-cyan-500/25 to-cyan-500/25 flex items-center justify-center border border-white/20 shadow-[-10px_10px_30px_rgba(99,102,241,0.2)]">
             <div className="text-3xl">📦</div>
          </div>
        </div>

        <div className="mt-8 grid grid-cols-1 gap-6 sm:grid-cols-2 relative z-10">
          {/* Preview Card */}
          <div className="relative overflow-hidden rounded-[32px] border border-white/10 bg-black/40 p-8 backdrop-blur-xl group/card hover:border-blue-500/40 transition-all shadow-2xl">
            <div className="absolute inset-0 bg-gradient-to-br from-cyan-500/5 to-transparent pointer-events-none opacity-0 group-hover/card:opacity-100 transition-opacity" />
            <div className="relative z-10">
              <div className="text-[10px] font-black uppercase tracking-[0.3em] text-cyan-500 mb-2">Live Preview</div>
              <div className="text-2xl font-black text-white italic tracking-tight">Interactive Sandbox</div>
              <div className="mt-3 text-sm font-medium text-zinc-400 leading-relaxed max-w-[250px]">
                Test your build directly in the browser via our high-performance WebGL sandbox container.
              </div>
              <div className="mt-8">
                {previewUrl ? (
                  <a className="inline-flex items-center gap-3 w-full rounded-[20px] border border-cyan-500/40 bg-cyan-500/20 px-6 py-4 text-xs font-black uppercase tracking-widest text-cyan-100 hover:scale-[1.02] active:scale-95 transition-all justify-center shadow-[0_10px_20px_rgba(6,182,212,0.15)]" href={previewUrl} target="_blank" rel="noreferrer">
                    Launch Simulator <span className="text-lg leading-none">🚀</span>
                  </a>
                ) : (
                  <div className="rounded-[20px] border border-dashed border-white/10 p-4 text-center text-xs font-bold text-zinc-500 bg-white/[0.02]">
                    Preview stream unavailable
                  </div>
                )}
              </div>
            </div>
          </div>

          {/* Download Card */}
          <div className="relative overflow-hidden rounded-[32px] border border-white/10 bg-black/40 p-8 backdrop-blur-xl group/card hover:border-cyan-500/40 transition-all shadow-2xl">
            <div className="absolute inset-0 bg-gradient-to-br from-cyan-500/5 to-transparent pointer-events-none opacity-0 group-hover/card:opacity-100 transition-opacity" />
            <div className="relative z-10">
              <div className="text-[10px] font-black uppercase tracking-[0.3em] text-cyan-500 mb-2">Source Artifacts</div>
              <div className="text-2xl font-black text-white italic tracking-tight">Package Download</div>
              <div className="mt-3 text-sm font-medium text-zinc-400 leading-relaxed max-w-[250px]">
                Acquire the compiled bundle for deployment or local execution on your target architecture.
              </div>
              <div className="mt-8">
                {downloadUrl ? (
                  <a className="inline-flex items-center gap-3 w-full rounded-[20px] border border-cyan-500/40 bg-cyan-500/20 px-6 py-4 text-xs font-black uppercase tracking-widest text-cyan-100 hover:scale-[1.02] active:scale-95 transition-all justify-center shadow-[0_10px_20px_rgba(217,70,239,0.15)]" href={downloadUrl} target="_blank" rel="noreferrer">
                    Download Archive <span className="text-lg leading-none">💾</span>
                  </a>
                ) : (
                  <div className="rounded-[20px] border border-dashed border-white/10 p-4 text-center text-xs font-bold text-zinc-500 bg-white/[0.02]">
                    Artifacts not ready
                  </div>
                )}
              </div>
            </div>
          </div>
        </div>
      </div>
    </UserShell>
  );
}
