"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { io, Socket } from "socket.io-client";
import {
  GlobeHemisphereWest,
  Fire,
  Funnel,
  Bell,
  Users,
  TrendUp,
  GameController,
  Lightning,
  Pulse,
  Sparkle,
} from "@phosphor-icons/react";
import UserShell from "@/app/_components/UserShell";
import { API_BASE_URL, apiFetch } from "@/lib/api";

type HeatmapRow = {
  countryCode: string;
  trendingGame: string;
  totalPlays: number;
};

type LiveEventRow = {
  lat: number;
  lng: number;
  gameTitle: string;
  countryCode: string;
  action: string;
  platform: string;
  createdAt: string;
};

type HeatmapResponse = {
  trending: HeatmapRow[];
  liveEvents: LiveEventRow[];
};

type SummaryRow = {
  windowMin: number;
  since: string;
  platform: string;
  totalEvents: number;
  estimatedLivePlayers: number;
  uniqueCountriesCount: number;
  uniqueGamesCount: number;
  uniqueGamesTodayCount: number;
  platformSplit: Array<{ platform: string; count: number }>;
  topCountries: Array<{ countryCode: string; count: number }>;
  topGames: Array<{ gameTitle: string; count: number }>;
  topGamesDetailed: Array<{ gameId: string; gameTitle: string; count: number; previewImageUrl: string }>;
};

function cx(...parts: Array<string | false | null | undefined>) {
  return parts.filter(Boolean).join(" ");
}

function clamp01(n: number) {
  return Math.max(0, Math.min(1, n));
}

function formatCompact(n: number) {
  const v = Math.max(0, Math.floor(Number(n || 0)));
  if (v >= 1_000_000) return (v / 1_000_000).toFixed(1) + "M";
  if (v >= 1000) return (v / 1000).toFixed(1) + "K";
  return String(v);
}

// Rough lon/lat -> x/y mapping for a rectangular world map (equirectangular).
function resolveMediaUrl(raw?: string | null) {
  const s = String(raw ?? "").trim();
  if (!s) return "";
  if (s.startsWith("http://") || s.startsWith("https://")) return s;

  const base = String(API_BASE_URL || "").replace(/\/?api\/?$/, "");
  if (!base) return s;
  if (s.startsWith("/")) return `${base}${s}`;
  return `${base}/${s}`;
}

function projectEquirect(lat: number, lng: number, w: number, h: number) {
  const x = ((lng + 180) / 360) * w;
  const y = ((90 - lat) / 180) * h;
  return { x, y };
}

function useGlobalEventsSocket(opts: { enabled: boolean; onEvent: (e: LiveEventRow) => void }) {
  const { enabled, onEvent } = opts;
  const sockRef = useRef<Socket | null>(null);

  useEffect(() => {
    if (!enabled) return;

    const base = String(API_BASE_URL || "").replace(/\/?api\/?$/, "");
    if (!/^https?:\/\//i.test(base)) return;

    const socket = io(`${base}/global-events`, {
      transports: ["websocket"],
      path: "/socket.io",
    });
    sockRef.current = socket;

    socket.on("connect", () => {
      socket.emit("global-events:join", { room: "global-events:stream" });
    });

    socket.on("global-events:new", (payload: any) => {
      const d = payload?.data;
      if (!d) return;
      onEvent({
        lat: Number(d.lat),
        lng: Number(d.lng),
        gameTitle: String(d.gameTitle || ""),
        countryCode: String(d.countryCode || ""),
        action: String(d.action || ""),
        platform: String(d.platform || ""),
        createdAt: String(d.createdAt || new Date().toISOString()),
      });
    });

    return () => {
      try {
        socket.disconnect();
      } catch {}
      sockRef.current = null;
    };
  }, [enabled, onEvent]);
}

// Ultra continent polygons (lat, lng)
const NA_PATH = [[72,-168],[74,-141],[70,-130],[69,-104],[68,-95],[60,-80],[50,-70],[45,-75],[42,-70],[38,-70],[35,-76],[30,-82],[25,-80],[20,-87],[18,-96],[15,-100],[15,-105],[22,-106],[30,-115],[32,-117],[35,-121],[38,-123],[42,-125],[45,-125],[48,-125],[50,-127],[52,-132],[56,-135],[58,-140],[60,-145],[62,-150],[65,-152],[68,-155],[70,-158],[72,-168]];
const SA_PATH = [[12,-82],[10,-78],[8,-77],[5,-80],[1,-80],[-3,-80],[-5,-78],[-8,-78],[-10,-77],[-12,-77],[-15,-75],[-18,-71],[-20,-70],[-22,-70],[-25,-70],[-28,-70],[-30,-71],[-32,-72],[-35,-73],[-38,-74],[-40,-73],[-42,-73],[-43,-75],[-45,-75],[-48,-75],[-50,-75],[-52,-75],[-53,-72],[-55,-70],[-55,-68],[-52,-65],[-50,-62],[-46,-60],[-40,-62],[-38,-65],[-35,-55],[-32,-52],[-30,-50],[-25,-48],[-22,-44],[-20,-42],[-15,-40],[-10,-37],[-5,-36],[0,-35],[5,-35],[8,-37],[10,-40],[10,-50],[10,-60],[10,-70],[11,-75],[12,-82]];
const EU_PATH = [[72,-25],[72,-18],[70,-10],[68,-5],[65,0],[62,5],[60,10],[58,15],[56,20],[54,25],[52,30],[50,35],[48,38],[45,40],[42,42],[40,44],[38,45],[36,45],[35,48],[33,50],[32,52],[30,55],[28,58],[25,60],[22,62],[20,65],[18,68],[15,70],[12,72],[10,74],[8,75],[5,75],[3,72],[0,70],[-5,68],[-8,65],[-10,60],[-10,55],[-8,50],[-5,45],[0,42],[5,40],[10,38],[15,35],[20,32],[25,30],[30,28],[35,25],[40,22],[42,20],[45,18],[48,15],[50,12],[52,10],[55,8],[58,5],[60,3],[62,0],[65,-2],[68,-5],[70,-10],[72,-15],[72,-25]];
const AF_PATH = [[38,10],[38,30],[38,50],[35,55],[30,55],[25,55],[20,55],[15,55],[10,55],[5,55],[0,55],[-5,55],[-10,55],[-15,55],[-20,55],[-25,55],[-30,55],[-33,55],[-35,50],[-34,45],[-32,40],[-30,35],[-25,30],[-20,25],[-15,20],[-10,15],[-5,12],[0,10],[5,8],[10,6],[15,5],[20,4],[25,3],[30,2],[35,1],[38,0],[38,5],[38,10]];
const ASIA_PATH = [[75,60],[75,80],[75,100],[75,120],[75,140],[70,160],[65,170],[60,175],[55,178],[50,180],[45,180],[40,178],[35,175],[30,170],[25,165],[20,160],[15,155],[10,150],[5,145],[0,140],[-5,135],[-10,130],[-5,125],[0,120],[5,115],[10,110],[15,105],[20,100],[25,95],[30,90],[35,85],[40,80],[45,75],[50,70],[55,65],[60,62],[65,60],[70,60],[75,60]];
const AU_PATH = [[-12,115],[-12,125],[-12,135],[-15,140],[-20,145],[-25,148],[-30,150],[-35,150],[-38,147],[-38,140],[-38,135],[-36,130],[-32,125],[-28,120],[-24,118],[-20,117],[-16,117],[-13,118],[-12,115]];
const WORLD_PATHS = [NA_PATH, SA_PATH, EU_PATH, AF_PATH, ASIA_PATH, AU_PATH];

function MapNeonHeat(props: {
  events: LiveEventRow[];
  accent: "cyan" | "magenta" | "amber";
  density: number;
}) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const eventsRef = useRef(props.events);
  const accentRef = useRef(props.accent);
  const densityRef = useRef(props.density);

  eventsRef.current = props.events;
  accentRef.current = props.accent;
  densityRef.current = props.density;

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;

    const parent = canvas.parentElement;
    if (!parent) return;

    const ctx = canvas.getContext("2d");
    if (!ctx) return;

    let raf = 0;
    let stars: Array<{ x: number; y: number; phase: number; speed: number; size: number; color: string }> = [];
    let shockwaves: Array<{ t0: number; cx: number; cy: number }> = [];

    function initStars(w: number, h: number) {
      stars = [];
      const colors = ["#ffffff", "#a5b4fc", "#67e8f9", "#f0abfc", "#fde047"];
      for (let i = 0; i < 300; i++) {
        stars.push({
          x: Math.random() * w,
          y: Math.random() * h,
          phase: Math.random() * Math.PI * 2,
          speed: 0.2 + Math.random() * 2.5,
          size: 0.3 + Math.random() * 1.6,
          color: colors[Math.floor(Math.random() * colors.length)],
        });
      }
    }

    function resize() {
      const dpr = Math.max(1, Math.floor(window.devicePixelRatio || 1));
      const rect = parent!.getBoundingClientRect();
      canvas!.width = Math.max(1, Math.floor(rect.width * dpr));
      canvas!.height = Math.max(1, Math.floor(rect.height * dpr));
      canvas!.style.width = rect.width + "px";
      canvas!.style.height = rect.height + "px";
      ctx!.setTransform(dpr, 0, 0, dpr, 0, 0);
      initStars(rect.width, rect.height);
    }

    resize();
    const ro = new ResizeObserver(() => resize());
    ro.observe(parent);

    const regions = [
      { x: 0.22, y: 0.38, label: "North America", color: "#6366f1", intensity: 1.0 },
      { x: 0.50, y: 0.22, label: "Europe", color: "#a855f7", intensity: 0.9 },
      { x: 0.78, y: 0.38, label: "Asia", color: "#f59e0b", intensity: 0.85 },
      { x: 0.35, y: 0.75, label: "South America", color: "#06b6d4", intensity: 0.5 },
      { x: 0.52, y: 0.65, label: "Africa", color: "#ec4899", intensity: 0.45 },
      { x: 0.85, y: 0.80, label: "Australia", color: "#8b5cf6", intensity: 0.3 },
    ];

    function draw(t: number) {
      if (!ctx) return;
      const rect = parent!.getBoundingClientRect();
      const w = rect.width;
      const h = rect.height;
      const cx = w / 2;
      const cy = h / 2;
      const maxR = Math.sqrt(cx * cx + cy * cy);

      const accent = accentRef.current;
      const palette =
        accent === "magenta"
          ? { core: "rgba(232,121,249,0.9)", glow: "rgba(232,121,249,0.25)", sec: "#e879f9" }
          : accent === "amber"
            ? { core: "rgba(251,191,36,0.9)", glow: "rgba(251,191,36,0.25)", sec: "#fbbf24" }
            : { core: "rgba(34,211,238,0.9)", glow: "rgba(34,211,238,0.25)", sec: "#22d3ee" };

      // ── 1. Deep Space + Nebula ──
      ctx.fillStyle = "#04050a";
      ctx.fillRect(0, 0, w, h);

      ctx.save();
      ctx.globalCompositeOperation = "screen";
      const neb1 = ctx.createRadialGradient(w * 0.3, h * 0.3, 0, w * 0.3, h * 0.3, w * 0.45);
      neb1.addColorStop(0, "rgba(99,102,241,0.05)");
      neb1.addColorStop(1, "transparent");
      ctx.fillStyle = neb1;
      ctx.fillRect(0, 0, w, h);
      const neb2 = ctx.createRadialGradient(w * 0.75, h * 0.65, 0, w * 0.75, h * 0.65, w * 0.4);
      neb2.addColorStop(0, "rgba(232,121,249,0.035)");
      neb2.addColorStop(1, "transparent");
      ctx.fillStyle = neb2;
      ctx.fillRect(0, 0, w, h);
      ctx.restore();

      // Star field
      stars.forEach((star) => {
        const flicker = 0.15 + 0.85 * Math.abs(Math.sin(t * 0.0015 * star.speed + star.phase));
        ctx.globalAlpha = flicker * 0.9;
        ctx.fillStyle = star.color;
        ctx.beginPath();
        ctx.arc(star.x, star.y, star.size * (0.5 + flicker * 0.5), 0, Math.PI * 2);
        ctx.fill();
      });
      ctx.globalAlpha = 1;

      // ── 2. Hexagonal Tactical Grid ──
      ctx.save();
      ctx.strokeStyle = "rgba(99,102,241,0.04)";
      ctx.lineWidth = 0.4;
      const hexSize = 26;
      for (let row = -2; row < h / hexSize + 2; row++) {
        for (let col = -2; col < w / hexSize + 2; col++) {
          const x = col * hexSize * 1.732 + (row % 2) * hexSize * 0.866;
          const y = row * hexSize * 1.5;
          const d = Math.sqrt((x - cx) * (x - cx) + (y - cy) * (y - cy));
          const fade = Math.max(0, 1 - d / Math.max(w, h));
          if (fade <= 0.05) continue;
          ctx.globalAlpha = fade * 0.6;
          ctx.beginPath();
          for (let i = 0; i < 6; i++) {
            const angle = (Math.PI / 3) * i - Math.PI / 6;
            const hx = x + hexSize * 0.5 * Math.cos(angle);
            const hy = y + hexSize * 0.5 * Math.sin(angle);
            if (i === 0) ctx.moveTo(hx, hy); else ctx.lineTo(hx, hy);
          }
          ctx.closePath();
          ctx.stroke();
        }
      }
      ctx.globalAlpha = 1;
      ctx.restore();

      // ── 3. Range Rings (animated dashes) ──
      ctx.save();
      const maxRR = Math.max(w, h) * 0.55;
      for (let ri = 1; ri <= 6; ri++) {
        const r = (maxRR / 6) * ri;
        const dashPhase = (t / 1800 + ri * 0.18) % 1;
        ctx.setLineDash([4, 8, 2, 8]);
        ctx.lineDashOffset = -dashPhase * 22;
        ctx.strokeStyle = `rgba(99,102,241,${0.05 + ri * 0.018})`;
        ctx.lineWidth = 0.5 + ri * 0.08;
        ctx.beginPath();
        ctx.arc(cx, cy, r, 0, Math.PI * 2);
        ctx.stroke();
      }
      ctx.setLineDash([]);
      ctx.restore();

      // ── 4. Compass Rose ──
      ctx.save();
      const compassR = Math.min(w, h) * 0.42;
      const compassAngle = t / 6000;
      ctx.strokeStyle = "rgba(99,102,241,0.06)";
      ctx.lineWidth = 0.6;
      for (let i = 0; i < 36; i++) {
        const a = (i / 36) * Math.PI * 2 + compassAngle;
        const isMajor = i % 9 === 0;
        const len = isMajor ? 18 : 6;
        ctx.globalAlpha = isMajor ? 0.15 : 0.06;
        ctx.beginPath();
        ctx.moveTo(cx + Math.cos(a) * (compassR - len), cy + Math.sin(a) * (compassR - len));
        ctx.lineTo(cx + Math.cos(a) * compassR, cy + Math.sin(a) * compassR);
        ctx.stroke();
      }
      ctx.globalAlpha = 1;
      ctx.restore();

      // ── 5. Neural Grid Lines ──
      ctx.save();
      ctx.strokeStyle = "rgba(99,102,241,0.045)";
      ctx.lineWidth = 0.5;
      for (let lng = -180; lng <= 180; lng += 30) {
        const x = ((lng + 180) / 360) * w;
        ctx.beginPath();
        ctx.moveTo(x, 0);
        ctx.lineTo(x, h);
        ctx.stroke();
      }
      for (let lat = -90; lat <= 90; lat += 30) {
        const y = ((90 - lat) / 180) * h;
        ctx.beginPath();
        ctx.moveTo(0, y);
        ctx.lineTo(w, y);
        ctx.stroke();
      }
      ctx.restore();

      // ── 5. Glowing Continent Outlines ──
      ctx.save();
      ctx.lineJoin = "round";
      ctx.lineCap = "round";

      WORLD_PATHS.forEach((path) => {
        if (!path.length) return;
        ctx.beginPath();
        path.forEach((coord, i) => {
          const p = projectEquirect(coord[0], coord[1], w, h);
          if (i === 0) ctx.moveTo(p.x, p.y);
          else ctx.lineTo(p.x, p.y);
        });
        ctx.closePath();

        // Deep fill
        ctx.fillStyle = "rgba(99,102,241,0.02)";
        ctx.fill();

        // Massive outer aura
        ctx.shadowBlur = 40;
        ctx.shadowColor = "rgba(99,102,241,0.15)";
        ctx.strokeStyle = "rgba(99,102,241,0.08)";
        ctx.lineWidth = 6;
        ctx.stroke();

        // Outer glow
        ctx.shadowBlur = 24;
        ctx.shadowColor = "rgba(99,102,241,0.25)";
        ctx.strokeStyle = "rgba(99,102,241,0.18)";
        ctx.lineWidth = 3;
        ctx.stroke();

        // Middle glow
        ctx.shadowBlur = 12;
        ctx.shadowColor = "rgba(139,92,246,0.22)";
        ctx.strokeStyle = "rgba(139,92,246,0.28)";
        ctx.lineWidth = 1.5;
        ctx.stroke();

        // Inner bright line
        ctx.shadowBlur = 8;
        ctx.shadowColor = palette.glow;
        ctx.strokeStyle = palette.core;
        ctx.lineWidth = 1.2;
        ctx.globalAlpha = 0.85;
        ctx.stroke();
        ctx.globalAlpha = 1;
      });
      ctx.restore();

      // ── 6. Rotating Radar Sweeps ──
      ctx.save();
      // Primary sweep (cyan, wider & brighter)
      const sweepAngle1 = (t / 1400) % (Math.PI * 2);
      const radarGrad1 = ctx.createConicGradient(sweepAngle1, cx, cy);
      radarGrad1.addColorStop(0, "transparent");
      radarGrad1.addColorStop(0.008, "rgba(34,211,238,0.22)");
      radarGrad1.addColorStop(0.03, "rgba(34,211,238,0.08)");
      radarGrad1.addColorStop(0.12, "rgba(34,211,238,0.01)");
      radarGrad1.addColorStop(1, "transparent");
      ctx.fillStyle = radarGrad1;
      ctx.beginPath();
      ctx.moveTo(cx, cy);
      ctx.arc(cx, cy, maxR, sweepAngle1, sweepAngle1 + Math.PI * 0.28);
      ctx.closePath();
      ctx.fill();

      // Secondary sweep (magenta, slower)
      const sweepAngle2 = (t / 3200 + Math.PI) % (Math.PI * 2);
      const radarGrad2 = ctx.createConicGradient(sweepAngle2, cx, cy);
      radarGrad2.addColorStop(0, "transparent");
      radarGrad2.addColorStop(0.006, "rgba(232,121,249,0.14)");
      radarGrad2.addColorStop(0.025, "rgba(232,121,249,0.04)");
      radarGrad2.addColorStop(0.1, "transparent");
      ctx.fillStyle = radarGrad2;
      ctx.beginPath();
      ctx.moveTo(cx, cy);
      ctx.arc(cx, cy, maxR, sweepAngle2, sweepAngle2 + Math.PI * 0.18);
      ctx.closePath();
      ctx.fill();
      ctx.restore();

      // ── 6b. Shockwave Bursts from Center ──
      if (Math.random() < 0.008) {
        shockwaves.push({ t0: t, cx, cy });
      }
      shockwaves = shockwaves.filter((sw) => t - sw.t0 < 2500);
      ctx.save();
      ctx.globalCompositeOperation = "screen";
      shockwaves.forEach((sw) => {
        const age = (t - sw.t0) / 2500;
        const r = age * maxR * 0.9;
        const alpha = Math.max(0, 1 - age) * 0.25;
        ctx.strokeStyle = `rgba(34,211,238,${alpha})`;
        ctx.lineWidth = 2 - age * 1.5;
        ctx.beginPath();
        ctx.arc(sw.cx, sw.cy, r, 0, Math.PI * 2);
        ctx.stroke();
      });
      ctx.restore();

      // ── 7. Region Pulse Rings (Triple Echo) ──
      regions.forEach((reg, ri) => {
        const rx = reg.x * w;
        const ry = reg.y * h;
        const baseSize = 10 + reg.intensity * 28;
        const ringPhase = (t / 550 + ri * 1.1) % 2;
        const ringR = baseSize + ringPhase * 50;
        const ringAlpha = Math.max(0, 1 - ringPhase / 2) * 0.55;

        ctx.save();
        ctx.globalCompositeOperation = "screen";

        ctx.strokeStyle = reg.color;
        ctx.lineWidth = 1.8;
        ctx.globalAlpha = ringAlpha;
        ctx.beginPath();
        ctx.arc(rx, ry, ringR, 0, Math.PI * 2);
        ctx.stroke();

        const ring2Phase = (ringPhase + 1) % 2;
        const ring2R = baseSize + ring2Phase * 50;
        const ring2Alpha = Math.max(0, 1 - ring2Phase / 2) * 0.35;
        ctx.globalAlpha = ring2Alpha;
        ctx.beginPath();
        ctx.arc(rx, ry, ring2R, 0, Math.PI * 2);
        ctx.stroke();

        const ring3Phase = (ringPhase + 1.5) % 2;
        const ring3R = baseSize + ring3Phase * 50;
        const ring3Alpha = Math.max(0, 1 - ring3Phase / 2) * 0.15;
        ctx.globalAlpha = ring3Alpha;
        ctx.lineWidth = 0.8;
        ctx.beginPath();
        ctx.arc(rx, ry, ring3R, 0, Math.PI * 2);
        ctx.stroke();
        ctx.restore();
      });

      // ── 8. Region Sun Orbs ──
      regions.forEach((reg) => {
        const rx = reg.x * w;
        const ry = reg.y * h;
        const rPulse = 1.0 + 0.3 * Math.sin(t / 450 + reg.x * 25);
        const glowSize = 150 * rPulse * reg.intensity;

        ctx.save();
        ctx.globalCompositeOperation = "screen";

        // Ultra-wide aura
        const g4 = ctx.createRadialGradient(rx, ry, 0, rx, ry, glowSize * 5);
        g4.addColorStop(0, `${reg.color}06`);
        g4.addColorStop(1, "transparent");
        ctx.fillStyle = g4;
        ctx.beginPath();
        ctx.arc(rx, ry, glowSize * 5, 0, Math.PI * 2);
        ctx.fill();

        // Wide aura
        const g3 = ctx.createRadialGradient(rx, ry, 0, rx, ry, glowSize * 2.5);
        g3.addColorStop(0, `${reg.color}18`);
        g3.addColorStop(1, "transparent");
        ctx.fillStyle = g3;
        ctx.beginPath();
        ctx.arc(rx, ry, glowSize * 2.5, 0, Math.PI * 2);
        ctx.fill();

        // Main glow
        const g2 = ctx.createRadialGradient(rx, ry, 0, rx, ry, glowSize * 1.2);
        g2.addColorStop(0, `${reg.color}50`);
        g2.addColorStop(1, "transparent");
        ctx.fillStyle = g2;
        ctx.beginPath();
        ctx.arc(rx, ry, glowSize * 1.2, 0, Math.PI * 2);
        ctx.fill();

        // Core
        const g = ctx.createRadialGradient(rx, ry, 0, rx, ry, glowSize * 0.35);
        g.addColorStop(0, "#ffffff");
        g.addColorStop(0.1, reg.color);
        g.addColorStop(0.4, `${reg.color}70`);
        g.addColorStop(1, "transparent");
        ctx.fillStyle = g;
        ctx.beginPath();
        ctx.arc(rx, ry, glowSize * 0.35, 0, Math.PI * 2);
        ctx.fill();

        const haloAngle = t / 800;
        ctx.strokeStyle = `${reg.color}55`;
        ctx.lineWidth = 1.2;
        ctx.beginPath();
        ctx.arc(rx, ry, glowSize * 0.55, haloAngle, haloAngle + Math.PI * 1.7);
        ctx.stroke();

        const haloAngle2 = -t / 600;
        ctx.strokeStyle = `${reg.color}35`;
        ctx.lineWidth = 0.8;
        ctx.beginPath();
        ctx.arc(rx, ry, glowSize * 0.25, haloAngle2, haloAngle2 + Math.PI * 1.4);
        ctx.stroke();

        ctx.restore();
      });

      // ── 9. Data Corridors (All Regions) ──
      ctx.save();
      ctx.globalCompositeOperation = "screen";
      for (let i = 0; i < regions.length; i++) {
        for (let j = i + 1; j < regions.length; j++) {
          const a = regions[i];
          const b = regions[j];
          const ax = a.x * w, ay = a.y * h;
          const bx = b.x * w, by = b.y * h;
          const midX = (ax + bx) / 2;
          const midY = (ay + by) / 2 - 40;
          const arcPhase = (Math.sin(t / 1000 + i + j) + 1) / 2;

          ctx.beginPath();
          ctx.moveTo(ax, ay);
          ctx.quadraticCurveTo(midX, midY, bx, by);
          ctx.strokeStyle = `rgba(99,102,241,${0.04 + arcPhase * 0.09})`;
          ctx.lineWidth = 0.8;
          ctx.stroke();

          const packetT = (t / 1400 + i * 0.5 + j * 0.3) % 1;
          const invT = 1 - packetT;
          const px = invT * invT * ax + 2 * invT * packetT * midX + packetT * packetT * bx;
          const py = invT * invT * ay + 2 * invT * packetT * midY + packetT * packetT * by;

          ctx.fillStyle = "#ffffff";
          ctx.shadowBlur = 14;
          ctx.shadowColor = a.color;
          ctx.globalAlpha = 0.95;
          ctx.beginPath();
          ctx.arc(px, py, 1.6, 0, Math.PI * 2);
          ctx.fill();
          ctx.shadowBlur = 0;

          ctx.strokeStyle = a.color;
          ctx.lineWidth = 0.4;
          ctx.globalAlpha = 0.25;
          ctx.beginPath();
          ctx.moveTo(px, py);
          const t2 = Math.max(0, packetT - 0.03);
          const invT2 = 1 - t2;
          const tx = invT2 * invT2 * ax + 2 * invT2 * t2 * midX + t2 * t2 * bx;
          const ty = invT2 * invT2 * ay + 2 * invT2 * t2 * midY + t2 * t2 * by;
          ctx.lineTo(tx, ty);
          ctx.stroke();
        }
      }
      ctx.restore();

      // ── 9b. Vertical Data Streams ──
      ctx.save();
      ctx.globalCompositeOperation = "screen";
      for (let i = 0; i < 8; i++) {
        const sx = ((i + 0.5) / 8) * w;
        const streamPhase = (t / 2000 + i * 0.4) % 1;
        const sy = streamPhase * h;
        const alpha = Math.sin(streamPhase * Math.PI) * 0.15;
        ctx.strokeStyle = `rgba(99,102,241,${alpha})`;
        ctx.lineWidth = 0.6;
        ctx.beginPath();
        ctx.moveTo(sx, sy - 30);
        ctx.lineTo(sx, sy + 30);
        ctx.stroke();
        ctx.fillStyle = "rgba(255,255,255,0.4)";
        ctx.beginPath();
        ctx.arc(sx, sy, 1, 0, Math.PI * 2);
        ctx.fill();
      }
      ctx.restore();

      // ── 10. Live Events with Intense Ripples & Flares ──
      const events = eventsRef.current;
      const density = densityRef.current;
      const n = Math.min(800, Math.max(0, events.length));
      const stride = Math.max(1, Math.floor(n / Math.max(1, density)));

      for (let i = 0; i < n; i += stride) {
        const e = events[i];
        const lat = Number(e.lat);
        const lng = Number(e.lng);
        if (!Number.isFinite(lat) || !Number.isFinite(lng)) continue;

        const p = projectEquirect(lat, lng, w, h);
        const life = 1 - i / Math.max(1, n);
        const flicker = 0.4 + 0.6 * Math.sin(t / 90 + i * 1.2);
        const isHot = life > 0.7 && i < 30;

        ctx.save();
        ctx.globalCompositeOperation = "lighter";

        const ripplePhase = (t / 350 + i * 0.4) % 2.5;
        const rippleR = 2 + ripplePhase * 18;
        const rippleAlpha = Math.max(0, 1 - ripplePhase / 2.5) * 0.45 * life;
        ctx.strokeStyle = palette.core;
        ctx.globalAlpha = rippleAlpha;
        ctx.lineWidth = 0.7;
        ctx.beginPath();
        ctx.arc(p.x, p.y, rippleR, 0, Math.PI * 2);
        ctx.stroke();

        ctx.globalAlpha = 0.98 * life * flicker;
        ctx.fillStyle = isHot ? "#ffffff" : palette.sec;
        ctx.shadowBlur = isHot ? 24 : 14;
        ctx.shadowColor = palette.core;
        ctx.beginPath();
        ctx.arc(p.x, p.y, isHot ? 2.2 + 1.8 * life : 1 + 1.5 * life, 0, Math.PI * 2);
        ctx.fill();

        if (isHot) {
          ctx.globalAlpha = 0.15 * flicker;
          ctx.fillStyle = palette.core;
          ctx.shadowBlur = 35;
          ctx.beginPath();
          ctx.arc(p.x, p.y, 10 + 8 * Math.sin(t / 200 + i), 0, Math.PI * 2);
          ctx.fill();
        }
        ctx.restore();
      }

      // ── 11. Holographic Scan Line ──
      const scanY = ((t / 2800) % 1.15 - 0.075) * h;
      ctx.save();
      const scanGrad = ctx.createLinearGradient(0, scanY - 22, 0, scanY + 22);
      scanGrad.addColorStop(0, "transparent");
      scanGrad.addColorStop(0.5, "rgba(34,211,238,0.045)");
      scanGrad.addColorStop(1, "transparent");
      ctx.fillStyle = scanGrad;
      ctx.fillRect(0, scanY - 22, w, 44);
      ctx.fillStyle = "rgba(34,211,238,0.08)";
      ctx.fillRect(0, scanY - 1, w, 2);
      ctx.restore();

      // ── 12. Tactical HUD Corners ──
      ctx.save();
      ctx.strokeStyle = "rgba(34,211,238,0.18)";
      ctx.lineWidth = 1.2;
      const cornerSize = 32;
      const margin = 16;
      ctx.beginPath();
      ctx.moveTo(margin, margin + cornerSize);
      ctx.lineTo(margin, margin);
      ctx.lineTo(margin + cornerSize, margin);
      ctx.stroke();
      ctx.beginPath();
      ctx.moveTo(w - margin, margin + cornerSize);
      ctx.lineTo(w - margin, margin);
      ctx.lineTo(w - margin - cornerSize, margin);
      ctx.stroke();
      ctx.beginPath();
      ctx.moveTo(margin, h - margin - cornerSize);
      ctx.lineTo(margin, h - margin);
      ctx.lineTo(margin + cornerSize, h - margin);
      ctx.stroke();
      ctx.beginPath();
      ctx.moveTo(w - margin, h - margin - cornerSize);
      ctx.lineTo(w - margin, h - margin);
      ctx.lineTo(w - margin - cornerSize, h - margin);
      ctx.stroke();
      ctx.fillStyle = "rgba(34,211,238,0.4)";
      [[margin, margin], [w - margin, margin], [margin, h - margin], [w - margin, h - margin]].forEach(([x, y]) => {
        ctx.beginPath();
        ctx.arc(x, y, 2.5, 0, Math.PI * 2);
        ctx.fill();
      });
      ctx.restore();

      // ── 13. Center Reticle ──
      ctx.save();
      ctx.strokeStyle = "rgba(34,211,238,0.12)";
      ctx.lineWidth = 1;
      const retR = 18 + Math.sin(t / 600) * 3;
      ctx.beginPath();
      ctx.arc(cx, cy, retR, 0, Math.PI * 2);
      ctx.stroke();
      ctx.beginPath();
      ctx.arc(cx, cy, retR * 0.35, 0, Math.PI * 2);
      ctx.stroke();
      ctx.strokeStyle = "rgba(34,211,238,0.045)";
      ctx.lineWidth = 0.8;
      ctx.beginPath();
      ctx.moveTo(cx, 0);
      ctx.lineTo(cx, h);
      ctx.stroke();
      ctx.beginPath();
      ctx.moveTo(0, cy);
      ctx.lineTo(w, cy);
      ctx.stroke();
      const cRingAngle = t / 1500;
      ctx.strokeStyle = "rgba(34,211,238,0.07)";
      ctx.lineWidth = 1.2;
      ctx.beginPath();
      ctx.arc(cx, cy, 35, cRingAngle, cRingAngle + Math.PI * 1.6);
      ctx.stroke();
      ctx.restore();

      // ── 14. Vignette ──
      ctx.save();
      const vig = ctx.createRadialGradient(cx, cy, maxR * 0.5, cx, cy, maxR);
      vig.addColorStop(0, "transparent");
      vig.addColorStop(1, "rgba(0,0,0,0.35)");
      ctx.fillStyle = vig;
      ctx.fillRect(0, 0, w, h);
      ctx.restore();

      raf = requestAnimationFrame(draw);
    }

    raf = requestAnimationFrame(draw);

    return () => {
      cancelAnimationFrame(raf);
      ro.disconnect();
    };
  }, []);

  return <canvas ref={canvasRef} className="absolute inset-0" />;
}

export default function LiveRadarPage() {
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const [platform, setPlatform] = useState<"all" | "webgl" | "mobile">("all");
  const [windowMin, setWindowMin] = useState(60);

  const [heat, setHeat] = useState<HeatmapResponse | null>(null);
  const [summary, setSummary] = useState<SummaryRow | null>(null);
  const [events, setEvents] = useState<LiveEventRow[]>([]);

  const topCountry = useMemo(() => {
    const list = summary?.topCountries || [];
    if (!list.length) return null;
    return list[0];
  }, [summary?.topCountries]);

  const trendingNow = useMemo(() => {
    const list = summary?.topGamesDetailed || [];
    return list.slice(0, 5);
  }, [summary?.topGamesDetailed]);

  async function load() {
    setLoading(true);
    setError(null);
    try {
      const [h, s] = await Promise.all([
        apiFetch<HeatmapResponse>("/global-events/heatmap", { method: "GET" }),
        apiFetch<SummaryRow>(`/global-events/summary?windowMin=${encodeURIComponent(String(windowMin))}&platform=${encodeURIComponent(platform)}`, { method: "GET" }),
      ]);

      setHeat(h);
      setSummary(s);
      setEvents((h?.liveEvents || []).slice(0, 300));
    } catch (e: any) {
      setError(String(e?.message || e));
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    let cancelled = false;
    (async () => {
      await load();
      if (cancelled) return;
    })();
    const t = window.setInterval(() => {
      if (!cancelled) void load();
    }, 15_000);
    return () => {
      cancelled = true;
      window.clearInterval(t);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [platform, windowMin]);

  // Socket stream for live events
  useGlobalEventsSocket({
    enabled: true,
    onEvent: (e) => {
      setEvents((prev) => [e, ...prev].slice(0, 450));
    },
  });

  const livePlayers = summary?.estimatedLivePlayers ?? 0;
  const activeCountries = summary?.uniqueCountriesCount ?? 0;
  const activeGames = summary?.uniqueGamesTodayCount ?? 0;

  const heatAccent: "cyan" | "magenta" | "amber" = platform === "mobile" ? "magenta" : platform === "webgl" ? "cyan" : "amber";

  return (
    <UserShell title="Live Radar" subtitle="Real-time gaming activity around the world">
      <div className="space-y-5">
        {/* Header */}
        <div className="relative overflow-hidden rounded-[32px] border border-white/[0.06] bg-[#0A0A0A] p-6 shadow-2xl">
          <div className="absolute -top-32 -left-24 h-[420px] w-[420px] rounded-full bg-cyan-500/15 blur-[120px]" />
          <div className="absolute -bottom-40 -right-32 h-[500px] w-[500px] rounded-full bg-fuchsia-500/10 blur-[140px]" />

          <div className="relative z-10 flex flex-col gap-4 md:flex-row md:items-center md:justify-between">
            <div className="min-w-0">
              <div className="inline-flex items-center gap-2 rounded-full border border-emerald-500/25 bg-emerald-500/10 px-4 py-1.5 text-[11px] font-black uppercase tracking-[0.28em] text-emerald-300 shadow-[0_0_20px_rgba(16,185,129,0.10)]">
                <Pulse size={14} className="animate-pulse" />
                Live
              </div>
              <div className="mt-4 flex items-end gap-3">
                <div className="h-10 w-10 rounded-2xl bg-white/[0.04] border border-white/10 flex items-center justify-center">
                  <GlobeHemisphereWest size={18} className="text-cyan-300" />
                </div>
                <h1 className="text-3xl md:text-4xl font-black tracking-tight text-transparent bg-clip-text bg-gradient-to-r from-white via-zinc-200 to-zinc-500">
                  GLOBAL EVENTS MAP
                </h1>
              </div>
              <p className="mt-2 text-sm text-zinc-400 max-w-2xl">
                Heat pulses represent real user actions. Filters affect summary and the live feed.
              </p>
            </div>

            <div className="flex flex-wrap items-center gap-2">
              <div className="inline-flex items-center gap-2 rounded-2xl border border-white/10 bg-white/[0.03] px-4 py-3 text-xs font-bold text-zinc-200">
                <Funnel size={14} className="text-zinc-400" />
                <select
                  value={platform}
                  onChange={(e) => setPlatform(e.target.value as any)}
                  className="bg-transparent outline-none text-zinc-200"
                >
                  <option value="all">All Platforms</option>
                  <option value="webgl">WebGL</option>
                  <option value="mobile">Mobile</option>
                </select>
              </div>

              <div className="inline-flex items-center gap-2 rounded-2xl border border-white/10 bg-white/[0.03] px-4 py-3 text-xs font-bold text-zinc-200">
                <Lightning size={14} className="text-zinc-400" />
                <select
                  value={windowMin}
                  onChange={(e) => setWindowMin(Math.max(1, Math.min(1440, parseInt(e.target.value, 10) || 60)))}
                  className="bg-transparent outline-none text-zinc-200"
                >
                  <option value={15}>15 min</option>
                  <option value={60}>60 min</option>
                  <option value={180}>3 hours</option>
                  <option value={1440}>24 hours</option>
                </select>
              </div>

              <button
                onClick={() => void load()}
                className="inline-flex items-center gap-2 rounded-2xl border border-white/10 bg-white/[0.04] px-4 py-3 text-xs font-black text-white hover:bg-white/10 transition"
              >
                <Sparkle size={14} className="text-cyan-300" />
                Refresh
              </button>

              <div className="relative inline-flex items-center justify-center rounded-2xl border border-white/10 bg-white/[0.03] px-4 py-3">
                <Bell size={16} className="text-zinc-300" />
                <span className="absolute -top-1 -right-1 h-4 w-4 rounded-full bg-rose-500 text-[10px] font-black text-white flex items-center justify-center">3</span>
              </div>
            </div>
          </div>
        </div>

        {/* Map + Right rail */}
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-5">
          <div className="lg:col-span-8 space-y-5">
            <div className="relative overflow-hidden rounded-[32px] border border-white/[0.06] bg-[#07080f] shadow-2xl">
              {/* map background */}
              <div className="absolute inset-0 bg-[radial-gradient(circle_at_20%_20%,rgba(99,102,241,0.22),transparent_55%),radial-gradient(circle_at_80%_30%,rgba(34,211,238,0.12),transparent_55%),radial-gradient(circle_at_50%_90%,rgba(232,121,249,0.10),transparent_60%)]" />
              
              <div className="relative aspect-[16/9] min-h-[480px]">
                <div className="absolute inset-0 bg-[#07080f]" />
                <MapNeonHeat events={events} accent={heatAccent} density={180} />

                {/* Top legend */}
                <div className="absolute left-6 top-6 flex flex-wrap items-center gap-3">
                  <div className="rounded-full border border-rose-500/30 bg-black/60 backdrop-blur-md px-3 py-1.5 text-[11px] font-black text-rose-200 flex items-center gap-2">
                    <span className="h-2 w-2 rounded-full bg-rose-400 shadow-[0_0_12px_rgba(251,113,133,0.8)]" />
                    High Activity
                  </div>
                  <div className="rounded-full border border-amber-500/25 bg-black/60 backdrop-blur-md px-3 py-1.5 text-[11px] font-black text-amber-200 flex items-center gap-2">
                    <span className="h-2 w-2 rounded-full bg-amber-300 shadow-[0_0_12px_rgba(251,191,36,0.8)]" />
                    Medium
                  </div>
                  <div className="rounded-full border border-cyan-500/25 bg-black/60 backdrop-blur-md px-3 py-1.5 text-[11px] font-black text-cyan-200 flex items-center gap-2">
                    <span className="h-2 w-2 rounded-full bg-cyan-300 shadow-[0_0_12px_rgba(34,211,238,0.8)]" />
                    Low
                  </div>
                </div>

                {/* Floating Region Stats (デザイン - Image 3 High Precision) */}
                <div className="absolute inset-0 pointer-events-none">
                   {[
                    { name: "NORTH AMERICA", x: "22%", y: "38%", count: "125K", color: "bg-indigo-500", glow: "rgba(99,102,241,0.5)" },
                    { name: "EUROPE", x: "50%", y: "22%", count: "243K", color: "bg-purple-500", glow: "rgba(168,85,247,0.5)" },
                    { name: "ASIA", x: "78%", y: "38%", count: "317K", color: "bg-amber-500", glow: "rgba(245,158,11,0.5)" },
                   ].map((reg, i) => (
                    <motion.div 
                      key={i}
                      initial={{ opacity: 0, scale: 0.8 }}
                      animate={{ opacity: 1, scale: 1 }}
                      transition={{ delay: 0.8 + (i*0.2), type: "spring", stiffness: 100 }}
                      className="absolute group pointer-events-auto"
                      style={{ left: reg.x, top: reg.y }}
                    >
                      <div className="relative -translate-x-1/2 -translate-y-1/2">
                        <div className="flex flex-col items-center gap-3">
                          <div className="relative overflow-hidden px-4 py-2 rounded-[20px] bg-black/40 backdrop-blur-3xl border border-white/10 shadow-[0_0_40px_rgba(0,0,0,0.5)] flex flex-col items-center min-w-[90px] group-hover:bg-black/60 transition-colors">
                            {/* Animated Inner Shine */}
                            <motion.div 
                              animate={{ x: [-100, 200] }}
                              transition={{ repeat: Infinity, duration: 3, ease: "linear" }}
                              className="absolute inset-0 w-full h-full bg-gradient-to-r from-transparent via-white/10 to-transparent skew-x-12"
                            />
                            <span className="relative z-10 text-[14px] font-black text-white tracking-tighter">{reg.count}</span>
                            <span className="relative z-10 text-[7px] font-black uppercase tracking-[0.25em] text-zinc-500">{reg.name}</span>
                          </div>
                          <div className="relative">
                             <div className={cx("absolute inset-0 rounded-full blur-md animate-pulse", reg.color)} />
                             <div className={cx("relative w-2 h-2 rounded-full border-2 border-white shadow-lg", reg.color)} />
                          </div>
                        </div>
                      </div>
                    </motion.div>
                   ))}
                </div>
              </div>
            </div>

            {/* Trending by Region Carousel (Image 3 Style) */}
            <div className="space-y-4">
              <div className="flex items-center justify-between px-2">
                <h3 className="text-[11px] font-black uppercase tracking-[0.35em] text-zinc-500">Trending Games by Region</h3>
                <div className="h-8 w-8 rounded-full border border-white/10 flex items-center justify-center cursor-pointer hover:bg-white/5">
                  <TrendUp size={14} className="text-zinc-400" />
                </div>
              </div>
              
              <div className="flex gap-4 overflow-x-auto pb-4 no-scrollbar">
                {trendingNow.map((g, i) => (
                  <motion.div 
                    key={g.gameId}
                    initial={{ opacity: 0, x: 20 }}
                    animate={{ opacity: 1, x: 0 }}
                    transition={{ delay: i * 0.1 }}
                    className="flex-shrink-0 w-[240px] group relative rounded-[28px] overflow-hidden border border-white/[0.08] bg-[#0A0A0A] shadow-xl"
                  >
                    <div 
                      className="aspect-[4/3] bg-cover bg-center opacity-70 group-hover:opacity-100 transition-opacity duration-500"
                      style={{ backgroundImage: `url(${resolveMediaUrl(g.previewImageUrl)})` }}
                    />
                    <div className="absolute inset-0 bg-gradient-to-t from-black via-black/20 to-transparent" />
                    
                    <div className="absolute bottom-4 left-4 right-4">
                      <div className="flex items-center gap-2 mb-1.5">
                         <div className="h-6 w-6 rounded-lg bg-amber-500/20 border border-amber-500/30 flex items-center justify-center text-[10px] font-black text-amber-400">
                           {i + 1}
                         </div>
                         <span className="text-[9px] font-black text-zinc-400 uppercase tracking-widest">
                           {["US", "EU", "ASIA", "SA", "AF"][i % 5]} TRENDING
                         </span>
                      </div>
                      <div className="text-sm font-black text-white truncate">{g.gameTitle}</div>
                      <div className="flex items-center gap-1.5 mt-1">
                        <Fire size={12} className="text-rose-500" />
                        <span className="text-[10px] font-bold text-zinc-400">{formatCompact(g.count)} players</span>
                      </div>
                    </div>
                  </motion.div>
                ))}
              </div>
            </div>
          </div>

          {/* Right rail */}
          <div className="lg:col-span-4 space-y-5">
            <div className="grid grid-cols-1 gap-5">
               <div className="gf-panel-strong rounded-[28px] p-6 border border-white/5 bg-gradient-to-br from-[#0A0A0A] to-[#0d0e1f]">
                <div className="flex items-center justify-between">
                  <div className="text-[11px] font-black uppercase tracking-[0.32em] text-zinc-500">LIVE PLAYERS</div>
                  <Users size={18} className="text-cyan-300" />
                </div>
                <div className="mt-6 flex flex-col gap-2">
                  <div className="text-5xl font-black text-white tracking-tighter italic">{formatCompact(livePlayers)}</div>
                  <div className="flex items-center gap-2 text-[12px] font-bold text-emerald-400">
                    <TrendUp size={14} />
                    <span>+12.5% <span className="text-zinc-500 ml-1">vs yesterday</span></span>
                  </div>
                </div>
                <div className="mt-8 h-20 w-full bg-gradient-to-t from-cyan-500/10 to-transparent rounded-xl border border-cyan-500/5 flex items-end overflow-hidden px-1 gap-1">
                   {[...Array(24)].map((_, i) => (
                    <motion.div 
                      key={i}
                      initial={{ height: 0 }}
                      animate={{ height: `${20 + Math.random() * 60}%` }}
                      className="flex-1 bg-cyan-400/20 rounded-t-sm"
                    />
                   ))}
                </div>
              </div>

              <div className="gf-panel-strong rounded-[28px] p-6 border border-white/5 bg-gradient-to-br from-[#0A0A0A] to-[#1a1111]">
                <div className="flex items-center justify-between">
                  <div className="text-[11px] font-black uppercase tracking-[0.32em] text-zinc-500">TOP COUNTRY</div>
                  <Fire size={18} className="text-rose-300" />
                </div>
                <div className="mt-6 flex items-center gap-4">
                   <div className="h-12 w-16 rounded-xl bg-white/[0.03] border border-white/5 flex items-center justify-center text-3xl">
                     {topCountry?.countryCode === "US" ? "🇺🇸" : 
                      topCountry?.countryCode === "TN" ? "🇹🇳" :
                      topCountry?.countryCode === "FR" ? "🇫🇷" :
                      topCountry?.countryCode === "JP" ? "🇯🇵" : "🏳️"}
                   </div>
                   <div>
                    <div className="text-3xl font-black text-white italic">{topCountry?.countryCode ?? "—"}</div>
                    <div className="text-[11px] font-bold text-zinc-500 uppercase tracking-widest">{formatCompact(topCountry?.count ?? 0)} Active Nodes</div>
                   </div>
                </div>
                <div className="mt-6 flex flex-col gap-2">
                   {[...Array(3)].map((_, i) => (
                    <div key={i} className="h-1 w-full bg-white/5 rounded-full overflow-hidden">
                       <motion.div 
                        initial={{ width: 0 }}
                        animate={{ width: `${80 - i*20}%` }}
                        className={cx("h-full rounded-full", i === 0 ? "bg-rose-500" : i === 1 ? "bg-amber-500" : "bg-cyan-500")}
                       />
                    </div>
                   ))}
                </div>
              </div>
            </div>

            <div className="gf-panel-strong rounded-[28px] p-6 border border-white/5 bg-[#0A0A0A]">
              <div className="flex items-center justify-between mb-6">
                <div className="text-[11px] font-black uppercase tracking-[0.32em] text-zinc-500 font-black">Live Events Feed</div>
                <div className="flex items-center gap-2">
                  <div className="h-2 w-2 rounded-full bg-emerald-500 animate-pulse" />
                  <span className="text-[10px] font-black text-emerald-400 uppercase tracking-widest">Live Now</span>
                </div>
              </div>

              <div className="space-y-4 max-h-[480px] overflow-auto pr-2 no-scrollbar">
                <AnimatePresence initial={false}>
                  {events.slice(0, 16).map((e, idx) => (
                    <motion.div
                      key={`${e.createdAt}_${idx}`}
                      initial={{ opacity: 0, x: 20 }}
                      animate={{ opacity: 1, x: 0 }}
                      exit={{ opacity: 0, x: -20 }}
                      className="group relative"
                    >
                      <div className="rounded-2xl border border-white/[0.06] bg-white/[0.02] p-4 transition-all duration-300 group-hover:bg-white/[0.05] group-hover:border-white/10 group-hover:translate-x-1">
                        <div className="flex items-start gap-3">
                           <div className="shrink-0 h-10 w-10 rounded-xl bg-white/[0.04] border border-white/5 flex items-center justify-center text-[10px] font-black text-zinc-500">
                             {e.countryCode}
                           </div>
                           <div className="min-w-0 flex-1">
                              <div className="text-[13px] font-black text-white truncate tracking-tight">{e.gameTitle}</div>
                              <div className="mt-1 flex items-center gap-2">
                                <span className="text-[9px] font-black text-zinc-600 uppercase tracking-widest">{e.platform}</span>
                                <span className="h-1 w-1 rounded-full bg-zinc-800" />
                                <span className="text-[9px] font-bold text-cyan-400/80">{e.action.replaceAll("_", " ")}</span>
                              </div>
                           </div>
                           <div className="text-[9px] font-bold text-zinc-600 tabular-nums">
                             {new Date(e.createdAt).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                           </div>
                        </div>
                      </div>
                    </motion.div>
                  ))}
                </AnimatePresence>
              </div>
            </div>
          </div>
        </div>

        {loading ? (
          <div className="text-sm text-zinc-500">Loading live radar…</div>
        ) : null}
        {error ? (
          <div className="rounded-2xl border border-rose-500/30 bg-rose-500/10 px-4 py-3 text-sm text-rose-200">
            {error}
          </div>
        ) : null}
      </div>
    </UserShell>
  );
}
