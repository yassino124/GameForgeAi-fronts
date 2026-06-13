"use client";

import { useEffect, useMemo, useState } from "react";
import QRCode from "qrcode";
import { X, Copy, Play, Trophy } from "lucide-react";

export default function TournamentShareModal({
  open,
  onClose,
  tournamentId,
}: {
  open: boolean;
  onClose: () => void;
  tournamentId: string;
}) {
  const links = useMemo(() => {
    const tid = String(tournamentId || "").trim();
    if (!tid || typeof window === "undefined") {
      return { details: "", play: "" };
    }
    const base = window.location.origin;
    return {
      details: `${base}/studio/tournaments/${encodeURIComponent(tid)}`,
      play: `${base}/studio/tournaments/${encodeURIComponent(tid)}/play`,
    };
  }, [tournamentId]);

  const [detailsQr, setDetailsQr] = useState<string>("");
  const [playQr, setPlayQr] = useState<string>("");

  useEffect(() => {
    let cancelled = false;
    if (!open) return;
    (async () => {
      try {
        const details = links.details;
        const play = links.play;
        const [d, p] = await Promise.all([
          details ? QRCode.toDataURL(details, { margin: 1, width: 220 }) : Promise.resolve(""),
          play ? QRCode.toDataURL(play, { margin: 1, width: 220 }) : Promise.resolve(""),
        ]);
        if (!cancelled) {
          setDetailsQr(String(d || ""));
          setPlayQr(String(p || ""));
        }
      } catch {
        if (!cancelled) {
          setDetailsQr("");
          setPlayQr("");
        }
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [open, links.details, links.play]);

  if (!open) return null;

  return (
    <div className="fixed inset-0 z-[80] flex items-center justify-center bg-black/85 backdrop-blur-xl p-4">
      <div className="w-full max-w-3xl overflow-hidden rounded-[32px] border border-white/10 bg-[#0d0d12] shadow-[0_32px_64px_rgba(0,0,0,0.8)]">
        <div className="p-6">
          <div className="flex items-center justify-between gap-3">
            <div>
              <div className="text-[10px] font-black uppercase tracking-[0.24em] text-zinc-500">Share</div>
              <div className="mt-1 text-xl font-black text-white tracking-tight">Tournament Links</div>
              <div className="mt-1 text-xs text-zinc-500">Copy links or scan QR codes.</div>
            </div>
            <button onClick={onClose} className="rounded-full bg-white/5 p-2 text-zinc-400 hover:bg-white/10 transition-colors">
              <X size={18} />
            </button>
          </div>

          <div className="mt-5 grid grid-cols-1 gap-4 md:grid-cols-2">
            <div className="rounded-3xl border border-white/10 bg-black/25 p-5">
              <div className="flex items-center justify-between gap-2">
                <div className="flex items-center gap-2 text-sm font-black text-white">
                  <Trophy size={16} className="text-cyan-200" /> Details
                </div>
                <button
                  onClick={async () => {
                    try {
                      await navigator.clipboard.writeText(links.details);
                    } catch {
                      // ignore
                    }
                  }}
                  className="rounded-full border border-white/10 bg-white/5 px-3 py-1.5 text-[10px] font-black uppercase tracking-widest text-zinc-200 hover:bg-white/10 inline-flex items-center gap-2"
                >
                  <Copy size={14} /> Copy
                </button>
              </div>

              <div className="mt-3 break-all text-xs text-zinc-300 rounded-2xl border border-white/10 bg-black/30 p-3">{links.details || "—"}</div>

              <div className="mt-4 flex items-center justify-center rounded-2xl border border-white/10 bg-white/5 p-4">
                {detailsQr ? (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img src={detailsQr} alt="" className="h-[180px] w-[180px]" />
                ) : null}
              </div>
            </div>

            <div className="rounded-3xl border border-white/10 bg-black/25 p-5">
              <div className="flex items-center justify-between gap-2">
                <div className="flex items-center gap-2 text-sm font-black text-white">
                  <Play size={16} className="text-emerald-200" /> Play
                </div>
                <button
                  onClick={async () => {
                    try {
                      await navigator.clipboard.writeText(links.play);
                    } catch {
                      // ignore
                    }
                  }}
                  className="rounded-full border border-white/10 bg-white/5 px-3 py-1.5 text-[10px] font-black uppercase tracking-widest text-zinc-200 hover:bg-white/10 inline-flex items-center gap-2"
                >
                  <Copy size={14} /> Copy
                </button>
              </div>

              <div className="mt-3 break-all text-xs text-zinc-300 rounded-2xl border border-white/10 bg-black/30 p-3">{links.play || "—"}</div>

              <div className="mt-4 flex items-center justify-center rounded-2xl border border-white/10 bg-white/5 p-4">
                {playQr ? (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img src={playQr} alt="" className="h-[180px] w-[180px]" />
                ) : null}
              </div>

              <div className="mt-3 text-[10px] text-zinc-500">
                Spectator mode:
                <span className="text-zinc-300"> add </span>
                <span className="font-mono text-zinc-200">?spectate=1</span>
              </div>
            </div>
          </div>

          <div className="mt-5 flex justify-end">
            <button
              onClick={onClose}
              className="rounded-2xl border border-white/10 bg-white/5 px-4 py-2 text-xs font-black uppercase tracking-widest text-white hover:bg-white/10"
            >
              Close
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
