"use client";

import { Suspense, useEffect, useMemo, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import UserShell from "@/app/_components/UserShell";
import { apiFetch, ApiError } from "@/lib/api";
import { getUserToken } from "@/lib/userAuth";

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
  const token = useMemo(() => getUserToken(), []);
  const projectId = (sp?.get("projectId") ?? "").trim();
  const target = (sp?.get("target") ?? "").trim();

  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [downloadUrl, setDownloadUrl] = useState<string | null>(null);
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    async function load() {
      if (!token || !projectId) {
        setLoading(false);
        setError("Missing projectId");
        return;
      }

      setLoading(true);
      setError(null);
      try {
        const q = target ? `?target=${encodeURIComponent(target)}` : "";
        const dl = await apiFetch<any>(`/projects/${encodeURIComponent(projectId)}/download-url${q}`, { method: "GET", token });
        const dlData = (dl && typeof dl === "object" && "data" in dl) ? (dl as any).data : dl;
        const dlObj = (dlData?.data ?? dlData) as DownloadUrlRes;
        if (!cancelled) setDownloadUrl(dlObj?.url || null);
      } catch (e: any) {
        if (!cancelled) setError(e instanceof ApiError ? e.message : (e?.message || "Failed to load download url"));
      }

      try {
        const pr = await apiFetch<any>(`/projects/${encodeURIComponent(projectId)}/preview-url`, { method: "GET", token });
        const prData = (pr && typeof pr === "object" && "data" in pr) ? (pr as any).data : pr;
        const prObj = (prData?.data ?? prData) as PreviewUrlRes;
        if (!cancelled) setPreviewUrl(prObj?.url || null);
      } catch {
        // ignore
      } finally {
        if (!cancelled) setLoading(false);
      }
    }
    load();
    return () => {
      cancelled = true;
    };
  }, [token, projectId, target]);

  return (
    <UserShell
      title="Build Results"
      subtitle={target ? `Target: ${target}` : "Your build is ready"}
      right={
        <div className="flex flex-wrap items-center gap-2">
          <button
            className="gf-btn rounded-xl px-3 py-2 text-sm"
            onClick={() => router.push(`/studio/builds/progress?projectId=${encodeURIComponent(projectId)}${target ? `&target=${encodeURIComponent(target)}` : ""}`)}
          >
            Status
          </button>
          <button className="gf-btn rounded-xl px-3 py-2 text-sm" onClick={() => router.push(`/studio/projects/${encodeURIComponent(projectId)}`)}>
            Project
          </button>
        </div>
      }
    >
      {error ? <div className="mb-4 rounded-2xl border border-red-500/20 bg-red-500/10 px-4 py-3 text-sm text-red-200">{error}</div> : null}

      <div className="gf-panel-strong rounded-3xl p-6">
        <div className="flex items-center justify-between">
          <div>
            <div className="text-xs text-zinc-400">Artifacts</div>
            <div className="mt-1 text-lg font-semibold text-white">{loading ? "Loading…" : "Ready"}</div>
          </div>
          <div className="h-10 w-10 rounded-2xl bg-gradient-to-br from-indigo-500/35 via-fuchsia-500/25 to-cyan-500/25" />
        </div>

        <div className="mt-5 grid grid-cols-1 gap-3 sm:grid-cols-2">
          <div className="rounded-2xl border border-white/10 bg-black/20 p-4">
            <div className="text-xs text-zinc-400">Preview</div>
            <div className="mt-2 text-sm text-zinc-200">Run it in the browser.</div>
            <div className="mt-4">
              {previewUrl ? (
                <a className="gf-btn inline-flex rounded-xl px-3 py-2 text-sm" href={previewUrl} target="_blank" rel="noreferrer">
                  Open preview
                </a>
              ) : (
                <div className="text-xs text-zinc-500">No preview url</div>
              )}
            </div>
          </div>

          <div className="rounded-2xl border border-white/10 bg-black/20 p-4">
            <div className="text-xs text-zinc-400">Download</div>
            <div className="mt-2 text-sm text-zinc-200">Get the build output.</div>
            <div className="mt-4">
              {downloadUrl ? (
                <a className="gf-btn inline-flex rounded-xl px-3 py-2 text-sm" href={downloadUrl} target="_blank" rel="noreferrer">
                  Download build
                </a>
              ) : (
                <div className="text-xs text-zinc-500">No download url</div>
              )}
            </div>
          </div>
        </div>
      </div>
    </UserShell>
  );
}
