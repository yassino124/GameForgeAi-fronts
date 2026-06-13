"use client";

import type { ReactNode } from "react";
import { Sparkles } from "lucide-react";

function cx(...parts: Array<string | false | null | undefined>) {
  return parts.filter(Boolean).join(" ");
}

export function WowHero({
  badge,
  title,
  subtitle,
  tone,
  mediaUrl,
  children,
}: {
  badge: string;
  title: string;
  subtitle: string;
  tone: "blue" | "emerald" | "cyan" | "amber";
  mediaUrl?: string;
  children?: ReactNode;
}) {
  const toneClass =
    tone === "emerald"
      ? "from-emerald-500/20 via-cyan-500/10 to-transparent border-emerald-400/30"
      : tone === "cyan"
        ? "from-cyan-500/20 via-blue-500/10 to-transparent border-cyan-400/30"
        : tone === "amber"
          ? "from-amber-500/20 via-blue-500/10 to-transparent border-amber-400/30"
          : "from-blue-500/20 via-cyan-500/10 to-transparent border-blue-400/30";

  return (
    <div className={cx("relative overflow-hidden rounded-3xl border bg-gradient-to-br p-5 gf-glow", toneClass)}>
      <div className="pointer-events-none absolute -left-14 -top-16 h-44 w-44 rounded-full bg-white/10 blur-3xl" />
      <div className="pointer-events-none absolute -right-10 -bottom-20 h-56 w-56 rounded-full bg-blue-500/20 blur-3xl" />

      {mediaUrl ? (
        <>
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src={mediaUrl} alt="" className="pointer-events-none absolute inset-0 h-full w-full object-cover opacity-[0.16]" />
          <div className="pointer-events-none absolute inset-0 bg-gradient-to-b from-black/10 via-black/35 to-black/70" />
        </>
      ) : null}

      <div className="relative">
        <div className="inline-flex items-center gap-1 rounded-full border border-white/15 bg-white/10 px-3 py-1 text-[10px] font-black uppercase tracking-[0.2em] text-zinc-100">
          <Sparkles size={12} /> {badge}
        </div>
        <h2 className="mt-3 text-2xl font-black uppercase italic tracking-tight text-white">{title}</h2>
        <p className="mt-2 max-w-2xl text-sm text-zinc-200/90">{subtitle}</p>
        {children ? <div className="mt-4">{children}</div> : null}
      </div>
    </div>
  );
}

export function ContextMediaCard({
  label,
  name,
  description,
  meta,
  mediaUrl,
}: {
  label: string;
  name: string;
  description?: string;
  meta?: string;
  mediaUrl?: string;
}) {
  return (
    <div className="group overflow-hidden rounded-2xl border border-white/10 bg-black/25 transition-all hover:-translate-y-0.5 hover:border-white/20">
      <div className="relative h-28 w-full bg-black/40">
        {mediaUrl ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img src={mediaUrl} alt="" className="h-full w-full object-cover transition-transform duration-500 group-hover:scale-105" />
        ) : (
          <div className="h-full w-full bg-gradient-to-br from-blue-500/20 via-cyan-500/10 to-cyan-500/20" />
        )}
        <div className="absolute inset-0 bg-gradient-to-t from-black/80 via-black/35 to-transparent" />
        <div className="absolute left-2 top-2 rounded-full border border-white/15 bg-black/40 px-2 py-0.5 text-[10px] font-black uppercase tracking-wider text-zinc-200">
          {label}
        </div>
      </div>
      <div className="p-3">
        <div className="truncate text-sm font-black text-white">{name}</div>
        <div className="mt-1 line-clamp-2 min-h-[2.5rem] text-xs text-zinc-300/90">{description || "No description available yet."}</div>
        {meta ? <div className="mt-2 text-[11px] font-semibold text-blue-200">{meta}</div> : null}
      </div>
    </div>
  );
}
