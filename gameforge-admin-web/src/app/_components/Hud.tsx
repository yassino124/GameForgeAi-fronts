"use client";

import { ReactNode } from "react";

function cx(...parts: Array<string | false | null | undefined>) {
  return parts.filter(Boolean).join(" ");
}

export function NeonChip(props: {
  tone: "cyan" | "emerald" | "amber" | "zinc";
  children: ReactNode;
  className?: string;
}) {
  const tone =
    props.tone === "cyan"
      ? "border-cyan-400/25 bg-cyan-500/10 text-cyan-200"
      : props.tone === "emerald"
        ? "border-emerald-400/25 bg-emerald-500/10 text-emerald-200"
        : props.tone === "amber"
          ? "border-amber-400/25 bg-amber-500/10 text-amber-200"
          : "border-white/10 bg-white/5 text-zinc-200";

  return (
    <span
      className={cx(
        "inline-flex items-center gap-2 rounded-full border px-3 py-1 text-[11px] font-semibold tracking-wide",
        tone,
        props.className,
      )}
    >
      {props.children}
    </span>
  );
}

export function PulseDot(props: { tone: "cyan" | "emerald" | "amber"; className?: string }) {
  const cls =
    props.tone === "emerald"
      ? "bg-emerald-300 shadow-[0_0_18px_rgba(52,211,153,0.75)]"
      : props.tone === "amber"
        ? "bg-amber-300 shadow-[0_0_18px_rgba(252,211,77,0.7)]"
        : "bg-cyan-300 shadow-[0_0_18px_rgba(34,211,238,0.75)]";
  return <span className={cx("h-2 w-2 rounded-full animate-pulse", cls, props.className)} />;
}
