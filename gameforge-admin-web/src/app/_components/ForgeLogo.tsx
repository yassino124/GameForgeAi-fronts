"use client";

import { motion } from "framer-motion";
import { useId } from "react";

export default function ForgeLogo({
  size = 40,
  className = "",
  iconOnly = false
}: {
  size?: number;
  className?: string;
  iconOnly?: boolean;
}) {
  const uid = useId().replace(/:/g, "");

  const padGrad = `padGrad-${uid}`;
  const boltGrad = `boltGrad-${uid}`;
  const forgeGrad = `forgeGrad-${uid}`;
  const bigGlow = `bigGlow-${uid}`;
  const tglow = `tglow-${uid}`;

  // Original aspect ratio is 800:240 (10:3)
  // Icon-only aspect ratio is 296:240 (which makes 148 exact center)
  const width = iconOnly ? size * 1.233 : size * 3.33;
  const height = size;

  return (
    <div className={`relative flex items-center justify-center ${className}`} style={{ height, width }}>
      <svg
        viewBox={iconOnly ? "0 0 296 240" : "0 0 800 240"}
        fill="none"
        xmlns="http://www.w3.org/2000/svg"
        className="h-full w-full"
      >
        <defs>
          {/* Controller gradient */}
          <linearGradient id={padGrad} x1="60" y1="60" x2="220" y2="180" gradientUnits="userSpaceOnUse">
            <stop offset="0%" stopColor="#7c3aed" />
            <stop offset="50%" stopColor="#6366f1" />
            <stop offset="100%" stopColor="#22d3ee" />
          </linearGradient>

          {/* Bolt gradient */}
          <linearGradient id={boltGrad} x1="138" y1="80" x2="152" y2="165" gradientUnits="userSpaceOnUse">
            <stop offset="0%" stopColor="#ffffff" />
            <stop offset="50%" stopColor="#c084fc" />
            <stop offset="100%" stopColor="#22d3ee" />
          </linearGradient>

          {/* FORGE text gradient */}
          <linearGradient id={forgeGrad} x1="320" y1="0" x2="580" y2="0" gradientUnits="userSpaceOnUse">
            <stop offset="0%" stopColor="#22d3ee" />
            <stop offset="100%" stopColor="#a78bfa" />
          </linearGradient>

          {/* Glow filters */}
          <filter id={bigGlow} x="-60%" y="-60%" width="220%" height="220%">
            <feGaussianBlur stdDeviation="14" result="b" />
            <feMerge><feMergeNode in="b" /><feMergeNode in="b" /><feMergeNode in="SourceGraphic" /></feMerge>
          </filter>
          <filter id={tglow} x="-10%" y="-10%" width="120%" height="120%">
            <feGaussianBlur stdDeviation="1.5" result="b" />
            <feMerge><feMergeNode in="b" /><feMergeNode in="SourceGraphic" /></feMerge>
          </filter>
        </defs>

        {/* AMBIENT HALO */}
        <ellipse cx="148" cy="122" rx="90" ry="75" fill="rgba(99,102,241,0.12)" filter={`url(#${bigGlow})`} />

        {/* GAMEPAD BODY */}
        <rect x="62" y="82" width="172" height="96" rx="34" fill="#0d0e1f" stroke={`url(#${padGrad})`} strokeWidth="2" />
        <path d="M62 148 Q58 176 80 180 L98 180 L98 162" fill="#0d0e1f" stroke={`url(#${padGrad})`} strokeWidth="2" />
        <path d="M234 148 Q238 176 216 180 L198 180 L198 162" fill="#0d0e1f" stroke={`url(#${padGrad})`} strokeWidth="2" />

        {/* D-PAD */}
        <rect x="84" y="112" width="38" height="14" rx="4" fill={`url(#${padGrad})`} opacity="0.95" />
        <rect x="96" y="100" width="14" height="38" rx="4" fill={`url(#${padGrad})`} opacity="0.95" />

        {/* ABXY BUTTONS */}
        <circle cx="186" cy="104" r="10" fill="rgba(34,211,238,0.08)" stroke="#22d3ee" strokeWidth="1.8" filter={`url(#${tglow})`} />
        <circle cx="204" cy="120" r="10" fill="rgba(167,139,250,0.08)" stroke="#a78bfa" strokeWidth="1.8" filter={`url(#${tglow})`} />
        <circle cx="186" cy="136" r="10" fill="rgba(34,211,238,0.08)" stroke="#22d3ee" strokeWidth="1.8" filter={`url(#${tglow})`} />
        <circle cx="168" cy="120" r="10" fill="rgba(167,139,250,0.08)" stroke="#a78bfa" strokeWidth="1.8" filter={`url(#${tglow})`} />

        {/* AI BOLT */}
        <motion.path
          animate={{
            opacity: [0.8, 1, 0.8],
            filter: ["drop-shadow(0 0 2px #fff)", "drop-shadow(0 0 8px #c084fc)", "drop-shadow(0 0 2px #fff)"]
          }}
          transition={{ duration: 2, repeat: Infinity }}
          d="M149 87 L138 121 L148 121 L134 160 L161 117 L150 117 L161 87Z"
          fill={`url(#${boltGrad})`}
        />

        {!iconOnly && (
          <>
            {/* DIVIDER */}
            <line x1="270" y1="60" x2="270" y2="180" stroke="rgba(255,255,255,0.08)" strokeWidth="1.5" />

            {/* WORDMARK */}
            <text x="300" y="118" fontFamily="Inter, sans-serif" fontSize="52" fontWeight="900" fill="white" letterSpacing="3">GAME</text>
            <text x="300" y="175" fontFamily="Inter, sans-serif" fontSize="52" fontWeight="900" fill={`url(#${forgeGrad})`} letterSpacing="3" filter={`url(#${tglow})`}>FORGE</text>

            {/* AI BADGE */}
            <rect x="608" y="148" width="64" height="30" rx="7" fill="rgba(34,211,238,0.08)" stroke="rgba(34,211,238,0.35)" strokeWidth="1.2" />
            <text x="640" y="169" fontFamily="Inter, sans-serif" fontSize="14" fontWeight="700" fill="rgba(34,211,238,0.9)" textAnchor="middle" letterSpacing="2">AI</text>

            {/* TAGLINE */}
            <text x="300" y="204" fontFamily="Inter, sans-serif" fontSize="16" fontWeight="700" fill="rgba(255,255,255,0.18)" letterSpacing="6">GENERATE · PLAY · FORGE</text>
          </>
        )}
      </svg>
    </div>
  );
}
