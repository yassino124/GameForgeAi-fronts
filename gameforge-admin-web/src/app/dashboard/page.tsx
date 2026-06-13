"use client";

import { ReactNode, useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { apiFetch, ApiError } from "@/lib/api";
import { clearToken, getToken } from "@/lib/auth";
import AdminShell from "@/app/_components/AdminShell";
import ConfirmDialog from "@/app/_components/ConfirmDialog";
import { useToast } from "@/app/_components/ToastProvider";
import { NeonChip, PulseDot } from "@/app/_components/Hud";

type AdminDashboardData = {
  user?: {
    id?: string;
    email?: string;
    username?: string;
    role?: string;
  };
  dashboard?: {
    totalUsers?: number;
    inactiveUsers?: number;
    templates?: {
      total?: number;
      public?: number;
      private?: number;
    };
    activeProjects?: number;
    buildStatus?: {
      queued?: number;
      running?: number;
      ready?: number;
      failed?: number;
    };
    systemStatus?: string;
  };
};

type AdCampaign = {
  id: string;
  advertiserName?: string;
  title?: string;
  description?: string;
  imageUrl?: string;
  videoUrl?: string;
  clickUrl?: string;
  ctaLabel?: string;
  active?: boolean;
  frequency?: number;
  impressionValueCents?: number;
  updatedAt?: string;
};

type SystemHealthLite = {
  status?: string;
  runtime?: {
    uptimeSeconds?: number;
  };
  memory?: {
    rss?: number;
    heapUsed?: number;
    systemTotal?: number;
    systemFree?: number;
  };
};

type BillingOverviewLite = {
  totals?: {
    subscriptions?: number;
    active?: number;
    inactive?: number;
    mrrApproxUsd?: number;
  };
  byStatus?: Record<string, number>;
  byPlan?: Record<string, number>;
  plans?: Array<{
    name: string;
    description?: string;
    priceMonthly?: number;
    stripePriceId?: string;
    isPopular?: boolean;
    entitlements?: any;
  }>;
};

type StripeFinanceSummaryLite = {
  asOf?: string;
  currency?: string;
  balance?: {
    availableUsd?: number;
    pendingUsd?: number;
    totalUsd?: number;
  };
  grossVolume?: {
    todayUsd?: number;
    monthUsd?: number;
  };
  payouts?: {
    todayUsd?: number;
    monthUsd?: number;
  };
};

type Paged<T> = { page: number; limit: number; total: number; items: T[] };

type TemplateRowLite = {
  id: string;
  name?: string;
  category?: string;
};

type ProjectRowLite = {
  id: string;
  templateId?: string;
};

type GameFeedPostLite = {
  id?: string;
  _id?: string;
  kind?: string;
  title?: string;
  name?: string;
  creatorUsername?: string;
  creator?: string;
  creatorId?: string;
  creatorUserId?: string;
  likeCount?: number;
  commentCount?: number;
  playCount?: number;
  remixCount?: number;
  shareCount?: number;
  updatedAt?: string;
  createdAt?: string;
};

function cx(...parts: Array<string | false | null | undefined>) {
  return parts.filter(Boolean).join(" ");
}

function bytes(n?: number) {
  const v = Number(n || 0);
  if (!v) return "0";
  const gb = 1024 * 1024 * 1024;
  const mb = 1024 * 1024;
  if (v >= gb) return (v / gb).toFixed(2) + " GB";
  if (v >= mb) return (v / mb).toFixed(1) + " MB";
  return v + " B";
}

function pct(part: number, total: number) {
  if (!total) return 0;
  return Math.max(0, Math.min(100, (part / total) * 100));
}

function clamp01(n: number) {
  return Math.max(0, Math.min(1, n));
}

function pushSample(arr: number[], next: number, max = 32) {
  const a = [...arr, Number(next || 0)];
  if (a.length > max) return a.slice(a.length - max);
  return a;
}

function svgLinePath(data: number[], w: number, h: number) {
  const d = data.length ? data : [0];
  const max = Math.max(1, ...d);
  const min = Math.min(0, ...d);
  const span = Math.max(1, max - min);
  const step = d.length > 1 ? w / (d.length - 1) : w;

  const pts = d.map((v, i) => {
    const x = i * step;
    const y = h - clamp01((v - min) / span) * h;
    return [x, y] as const;
  });

  const path = pts
    .map(([x, y], i) => {
      const cmd = i === 0 ? "M" : "L";
      return `${cmd}${x.toFixed(2)} ${y.toFixed(2)}`;
    })
    .join(" ");

  return { path, pts, max, min };
}

function AreaWavesChart(props: {
  a: number[];
  b: number[];
  aStrokeClass: string;
  bStrokeClass: string;
  aFillId: string;
  bFillId: string;
}) {
  const w = 520;
  const h = 150;
  const dA = props.a.length ? props.a : [0];
  const dB = props.b.length ? props.b : [0];
  const max = Math.max(1, ...dA, ...dB);
  const step = Math.max(1, (Math.max(dA.length, dB.length) - 1)) ? w / Math.max(1, Math.max(dA.length, dB.length) - 1) : w;

  function toPts(d: number[]) {
    const dd = d.length ? d : [0];
    return dd.map((v, i) => {
      const x = i * step;
      const y = h - clamp01(Number(v || 0) / max) * h;
      return [x, y] as const;
    });
  }

  function toPath(pts: ReadonlyArray<readonly [number, number]>) {
    return pts
      .map(([x, y], i) => {
        const cmd = i === 0 ? "M" : "L";
        return `${cmd}${x.toFixed(2)} ${y.toFixed(2)}`;
      })
      .join(" ");
  }

  function toArea(pts: ReadonlyArray<readonly [number, number]>) {
    const line = toPath(pts);
    const last = pts[pts.length - 1] || [w, h];
    return `${line} L${last[0].toFixed(2)} ${h} L0 ${h} Z`;
  }

  const ptsA = toPts(dA);
  const ptsB = toPts(dB);
  const pathA = toPath(ptsA);
  const pathB = toPath(ptsB);
  const areaA = toArea(ptsA);
  const areaB = toArea(ptsB);

  return (
    <svg width="100%" height={h} viewBox={`0 0 ${w} ${h}`} className="block">
      <defs>
        <linearGradient id={props.aFillId} x1="0" x2="0" y1="0" y2="1">
          <stop offset="0%" stopColor="rgba(34,211,238,0.45)" />
          <stop offset="100%" stopColor="rgba(34,211,238,0)" />
        </linearGradient>
        <linearGradient id={props.bFillId} x1="0" x2="0" y1="0" y2="1">
          <stop offset="0%" stopColor="rgba(236,72,153,0.40)" />
          <stop offset="100%" stopColor="rgba(236,72,153,0)" />
        </linearGradient>
      </defs>
      <path d={areaA} fill={`url(#${props.aFillId})`} />
      <path d={areaB} fill={`url(#${props.bFillId})`} />
      <path d={pathA} fill="none" className={`stroke-[2.5] ${props.aStrokeClass}`} />
      <path d={pathB} fill="none" className={`stroke-[2.5] ${props.bStrokeClass}`} />
    </svg>
  );
}

function DualLineChart(props: {
  a: number[];
  b: number[];
  aStrokeClass: string;
  bStrokeClass: string;
}) {
  const w = 520;
  const h = 150;
  const dA = props.a.length ? props.a : [0];
  const dB = props.b.length ? props.b : [0];

  const max = Math.max(1, ...dA, ...dB);
  const step = Math.max(1, (Math.max(dA.length, dB.length) - 1)) ? w / Math.max(1, Math.max(dA.length, dB.length) - 1) : w;

  function toPath(d: number[]) {
    const dd = d.length ? d : [0];
    const pts = dd.map((v, i) => {
      const x = i * step;
      const y = h - clamp01(Number(v || 0) / max) * h;
      return [x, y] as const;
    });
    return pts
      .map(([x, y], i) => {
        const cmd = i === 0 ? "M" : "L";
        return `${cmd}${x.toFixed(2)} ${y.toFixed(2)}`;
      })
      .join(" ");
  }

  const pathA = toPath(dA);
  const pathB = toPath(dB);
  return (
    <svg width="100%" height={h} viewBox={`0 0 ${w} ${h}`} className="block">
      <path d={pathA} fill="none" className={`stroke-[2.5] ${props.aStrokeClass}`} />
      <path d={pathB} fill="none" className={`stroke-[2.5] ${props.bStrokeClass}`} />
    </svg>
  );
}

function RadarChart(props: {
  values01: number[];
  labels: string[];
  tone: "cyan" | "emerald" | "amber";
}) {
  const size = 180;
  const cx0 = size / 2;
  const cy0 = size / 2;
  const r = 64;
  const n = Math.max(3, props.values01.length);

  const tone =
    props.tone === "emerald"
      ? { stroke: "stroke-emerald-300/90", fill: "rgba(52,211,153,0.18)" }
      : props.tone === "amber"
        ? { stroke: "stroke-amber-300/90", fill: "rgba(252,211,77,0.16)" }
        : props.tone === "cyan"
          ? { stroke: "stroke-cyan-300/90", fill: "rgba(236,72,153,0.16)" }
          : { stroke: "stroke-cyan-300/90", fill: "rgba(34,211,238,0.16)" };

  function pt(i: number, v01: number) {
    const a = (Math.PI * 2 * i) / n - Math.PI / 2;
    const rr = r * clamp01(v01);
    return [cx0 + Math.cos(a) * rr, cy0 + Math.sin(a) * rr] as const;
  }

  const poly = props.values01
    .slice(0, n)
    .map((v, i) => pt(i, v))
    .map(([x, y]) => `${x.toFixed(2)},${y.toFixed(2)}`)
    .join(" ");

  const rings = [0.25, 0.5, 0.75, 1].map((k) => {
    const pts = Array.from({ length: n }).map((_, i) => pt(i, k));
    return pts.map(([x, y]) => `${x.toFixed(2)},${y.toFixed(2)}`).join(" ");
  });

  const axes = Array.from({ length: n }).map((_, i) => {
    const a = (Math.PI * 2 * i) / n - Math.PI / 2;
    return {
      x: cx0 + Math.cos(a) * r,
      y: cy0 + Math.sin(a) * r,
    };
  });

  return (
    <div className="flex items-center gap-4">
      <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`} className="shrink-0">
        {rings.map((pts, i) => (
          <polygon key={i} points={pts} fill="none" className="stroke-white/10" strokeWidth="1" />
        ))}
        {axes.map((a, i) => (
          <line key={i} x1={cx0} y1={cy0} x2={a.x} y2={a.y} className="stroke-white/10" strokeWidth="1" />
        ))}
        <polygon points={poly} fill={tone.fill} className={tone.stroke} strokeWidth="2" />
      </svg>
      <div className="min-w-0 flex-1 space-y-1">
        {props.labels.slice(0, n).map((l, i) => (
          <div key={l} className="flex items-center justify-between text-xs">
            <span className="truncate text-zinc-300">{l}</span>
            <span className="font-mono text-zinc-400">{Math.round(clamp01(props.values01[i] ?? 0) * 100)}%</span>
          </div>
        ))}
      </div>
    </div>
  );
}

function Sparkline(props: { data: number[]; strokeClass: string }) {
  const w = 140;
  const h = 36;
  const d = props.data;
  const max = Math.max(1, ...d);
  const min = Math.min(0, ...d);
  const span = Math.max(1, max - min);
  const step = d.length > 1 ? w / (d.length - 1) : w;

  const pts = d
    .map((v, i) => {
      const x = i * step;
      const y = h - clamp01((v - min) / span) * h;
      return `${x.toFixed(2)},${y.toFixed(2)}`;
    })
    .join(" ");

  return (
    <svg width={w} height={h} viewBox={`0 0 ${w} ${h}`} className="block">
      <polyline fill="none" className={`stroke-[2] ${props.strokeClass}`} points={pts} />
    </svg>
  );
}

function RingGauge(props: {
  label: string;
  valueLabel: string;
  value01: number;
  tone: "cyan" | "emerald" | "amber" | "red" | "zinc";
}) {
  const r = 16;
  const c = 2 * Math.PI * r;
  const v = clamp01(props.value01);
  const dash = c * v;

  const toneCls: Record<string, string> = {
    emerald: "stroke-emerald-300/90",
    cyan: "stroke-cyan-300/90",
    amber: "stroke-amber-300/90",
    red: "stroke-red-300/90",
    zinc: "stroke-white/30",
  };

  return (
    <div className="rounded-2xl border border-white/10 bg-black/20 px-3 py-3">
      <div className="flex items-center justify-between">
        <div className="min-w-0">
          <div className="text-xs font-medium text-zinc-300">{props.label}</div>
          <div className="mt-1 truncate text-sm font-semibold text-white">{props.valueLabel}</div>
        </div>
        <svg width="44" height="44" viewBox="0 0 44 44" className="shrink-0">
          <circle cx="22" cy="22" r={r} fill="none" className="stroke-white/10" strokeWidth="3" />
          <circle
            cx="22"
            cy="22"
            r={r}
            fill="none"
            className={toneCls[props.tone]}
            strokeWidth="3"
            strokeLinecap="round"
            strokeDasharray={`${dash} ${c - dash}`}
            transform="rotate(-90 22 22)"
          />
        </svg>
      </div>
    </div>
  );
}

function MiniBars(props: {
  rows: Array<{ label: string; value: number; total: number; tone: "emerald" | "cyan" | "amber" | "red" | "zinc" }>;
}) {
  const toneCls: Record<string, string> = {
    emerald: "bg-emerald-500/60",
    cyan: "bg-cyan-500/60",
    amber: "bg-amber-500/60",
    red: "bg-red-500/60",
    zinc: "bg-white/20",
  };

  return (
    <div className="space-y-2">
      {props.rows.map((r) => (
        <div key={r.label} className="rounded-xl border border-white/10 bg-black/20 px-3 py-2">
          <div className="flex items-center justify-between text-xs">
            <span className="text-zinc-300">{r.label}</span>
            <span className="font-medium text-white">{r.value}</span>
          </div>
          <div className="mt-2 h-1.5 overflow-hidden rounded-full bg-white/5">
            <div className={`h-full ${toneCls[r.tone]}`} style={{ width: `${pct(r.value, r.total).toFixed(2)}%` }} />
          </div>
        </div>
      ))}
    </div>
  );
}

function OpCard(props: { title: string; subtitle: string; tone: "cyan" | "amber" | "emerald"; onClick: () => void }) {
  const tone =
    props.tone === "cyan"
      ? "from-cyan-500/15 via-transparent to-transparent"
      : props.tone === "amber"
        ? "from-amber-500/15 via-transparent to-transparent"
        : "from-emerald-500/15 via-transparent to-transparent";
  return (
    <button
      className="gf-card group relative overflow-hidden rounded-2xl border border-white/10 p-4 text-left transition-transform duration-200 hover:-translate-y-0.5"
      onClick={props.onClick}
    >
      <div className={`pointer-events-none absolute inset-0 bg-gradient-to-b ${tone}`} />
      <div className="pointer-events-none absolute inset-0 opacity-0 transition-opacity duration-200 group-hover:opacity-100" style={{ backgroundImage: "repeating-linear-gradient(to bottom, rgba(255,255,255,0.06), rgba(255,255,255,0.06) 1px, transparent 1px, transparent 6px)" }} />
      <div className="relative">
        <div className="flex items-start justify-between gap-3">
          <div className="min-w-0">
            <div className="truncate text-sm font-semibold text-white">{props.title}</div>
            <div className="mt-1 truncate text-xs text-zinc-500">{props.subtitle}</div>
          </div>
          <span className="rounded-xl border border-white/10 bg-black/20 px-2 py-1 text-[11px] font-semibold text-zinc-300 transition group-hover:border-white/20 group-hover:text-white">
            Open
          </span>
        </div>
      </div>
    </button>
  );
}

function StatCard(props: {
  label: string;
  value: string;
  hint?: string;
  accentClass: string;
}) {
  return (
    <div className="gf-card group relative overflow-hidden rounded-2xl border border-white/10 p-5 transition-transform duration-200 hover:-translate-y-0.5">
      <div className="pointer-events-none absolute inset-0 opacity-0 transition-opacity duration-200 group-hover:opacity-100">
        <div className="absolute inset-0 bg-gradient-to-b from-white/5 via-transparent to-transparent" />
        <div className="absolute inset-0" style={{ backgroundImage: "repeating-linear-gradient(to bottom, rgba(255,255,255,0.06), rgba(255,255,255,0.06) 1px, transparent 1px, transparent 6px)" }} />
      </div>
      <div className="pointer-events-none absolute -right-10 -top-10 h-32 w-32 rounded-full blur-2xl opacity-70 transition-opacity duration-200 group-hover:opacity-100">
        <div className={`h-full w-full ${props.accentClass}`} />
      </div>
      <div className="pointer-events-none absolute -bottom-16 -left-16 h-48 w-48 rounded-full bg-cyan-500/10 blur-3xl opacity-0 transition-opacity duration-200 group-hover:opacity-100" />
      <div className="flex items-center justify-between gap-4">
        <div className="min-w-0">
          <p className="text-[11px] font-semibold tracking-wide text-zinc-400">{props.label}</p>
          <p className="mt-2 truncate text-3xl font-semibold tracking-tight text-white">{props.value}</p>
          {props.hint ? <p className="mt-1 truncate text-xs text-zinc-500">{props.hint}</p> : null}
        </div>
        <div className="relative">
          <div className={`h-10 w-10 rounded-2xl ${props.accentClass} opacity-80`} />
          <div className="pointer-events-none absolute inset-0 rounded-2xl ring-1 ring-white/10" />
        </div>
      </div>
    </div>
  );
}

export default function DashboardPage() {
  const router = useRouter();
  const toast = useToast();
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [data, setData] = useState<AdminDashboardData | null>(null);

  const [aiLoading, setAiLoading] = useState(false);
  const [aiError, setAiError] = useState<string | null>(null);
  const [aiBrief, setAiBrief] = useState<string[]>([]);
  const [aiActions, setAiActions] = useState<Array<{ title: string; why: string }>>([]);

  const [chatOpen, setChatOpen] = useState(false);
  const [chatInput, setChatInput] = useState("");
  const [chatLoading, setChatLoading] = useState(false);
  const [chatError, setChatError] = useState<string | null>(null);
  const [chatHistory, setChatHistory] = useState<Array<{ role: "user" | "model"; text: string }>>([]);

  const [tplUsageLoading, setTplUsageLoading] = useState(false);
  const [tplUsageError, setTplUsageError] = useState<string | null>(null);
  const [tplUsage, setTplUsage] = useState<Array<{ templateId: string; name: string; count: number }>>([]);
  const [tplBarsOn, setTplBarsOn] = useState(false);

  const [feedLoading, setFeedLoading] = useState(false);
  const [feedError, setFeedError] = useState<string | null>(null);
  const [feedMode, setFeedMode] = useState<"hot" | "total">("hot");
  const [feedBarsOn, setFeedBarsOn] = useState(false);
  const [feedTop, setFeedTop] = useState<
    Array<{
      id: string;
      title: string;
      creator: string;
      score: number;
      hotScore: number;
      ageLabel: string;
      likes: number;
      comments: number;
      plays: number;
      remixes: number;
      shares: number;
    }>
  >([]);

  const [telemetryLoading, setTelemetryLoading] = useState(false);
  const [dashLastAt, setDashLastAt] = useState<number | null>(null);

  const [tsQueued, setTsQueued] = useState<number[]>([]);
  const [tsRunning, setTsRunning] = useState<number[]>([]);
  const [tsFailed, setTsFailed] = useState<number[]>([]);
  const [tsHeapMb, setTsHeapMb] = useState<number[]>([]);
  const [tsMrr, setTsMrr] = useState<number[]>([]);

  const [sysLoading, setSysLoading] = useState(false);
  const [sysError, setSysError] = useState<string | null>(null);
  const [sys, setSys] = useState<SystemHealthLite | null>(null);
  const [sysLastAt, setSysLastAt] = useState<number | null>(null);

  const [billingLoading, setBillingLoading] = useState(false);
  const [billingError, setBillingError] = useState<string | null>(null);
  const [billing, setBilling] = useState<BillingOverviewLite | null>(null);

  const [stripeFinanceLoading, setStripeFinanceLoading] = useState(false);
  const [stripeFinanceError, setStripeFinanceError] = useState<string | null>(null);
  const [stripeFinance, setStripeFinance] = useState<StripeFinanceSummaryLite | null>(null);

  const [adsLoading, setAdsLoading] = useState(false);
  const [adsError, setAdsError] = useState<string | null>(null);
  const [adsActive, setAdsActive] = useState<AdCampaign | null>(null);
  const [adsCampaigns, setAdsCampaigns] = useState<AdCampaign[]>([]);
  const [adsCreateOpen, setAdsCreateOpen] = useState(false);
  const [adsBusyId, setAdsBusyId] = useState<string | null>(null);
  const [adsConfirm, setAdsConfirm] = useState<null | { id: string; action: "activate" | "deactivate"; title?: string }>(null);

  const [adAdvertiserName, setAdAdvertiserName] = useState("Advertiser");
  const [adTitle, setAdTitle] = useState("Sponsored");
  const [adDescription, setAdDescription] = useState("");
  const [adImageUrl, setAdImageUrl] = useState("");
  const [adVideoUrl, setAdVideoUrl] = useState("");
  const [adClickUrl, setAdClickUrl] = useState("");
  const [adCtaLabel, setAdCtaLabel] = useState("Visit");
  const [adFrequency, setAdFrequency] = useState("5");
  const [adImpressionValue, setAdImpressionValue] = useState("1");

  const [now, setNow] = useState(() => Date.now());

  const [notifOpen, setNotifOpen] = useState(false);

  const [activityLog, setActivityLog] = useState<Array<{ ts: number; type: string; msg: string; tone: "emerald" | "cyan" | "amber" | "red" }>>([]);

  const [platformDist, setPlatformDist] = useState<Array<{ target: string; count: number }>>([]);
  const [platformLoading, setPlatformLoading] = useState(false);

  const [quickBusy, setQuickBusy] = useState<string | null>(null);

  const [leaderboard, setLeaderboard] = useState<Array<{ username?: string; email?: string; projects?: number; builds?: number; downloads?: number }>>([]);
  const [leaderboardLoading, setLeaderboardLoading] = useState(false);

  const [userGrowth, setUserGrowth] = useState<Array<{ date: string; count: number }>>([]);
  const [userGrowthLoading, setUserGrowthLoading] = useState(false);

  const [errorLog, setErrorLog] = useState<Array<{ ts: number; msg: string; source?: string }>>([]);
  const [errorLogLoading, setErrorLogLoading] = useState(false);

  const [avgBuildTime, setAvgBuildTime] = useState<number[]>([]);

  const [showConfetti, setShowConfetti] = useState(false);
  const [confettiText, setConfettiText] = useState("");
  const [shortcutsOpen, setShortcutsOpen] = useState(false);
  const [comparisonMode, setComparisonMode] = useState(false);
  const [prevStats, setPrevStats] = useState<{ users?: number; builds?: number; mrr?: number }>({});

  const token = useMemo(() => getToken(), []);

  function pushActivity(type: string, msg: string, tone: "emerald" | "cyan" | "amber" | "red" = "cyan") {
    const entry = { ts: Date.now(), type, msg, tone };
    setActivityLog((prev) => [entry, ...prev].slice(0, 20));
  }

  async function loadPlatformDistribution() {
    if (!token) return;
    setPlatformLoading(true);
    try {
      const builds = await apiFetch<Paged<{ buildTarget?: string }>>(`/admin/builds?page=1&limit=500`, { method: "GET", token });
      const counts = new Map<string, number>();
      for (const b of builds?.items || []) {
        const t = (b?.buildTarget || "unknown").toLowerCase();
        counts.set(t, (counts.get(t) || 0) + 1);
      }
      const dist = Array.from(counts.entries())
        .map(([target, count]) => ({ target, count }))
        .sort((a, b) => b.count - a.count);
      setPlatformDist(dist);
    } catch {
      // ignore
    } finally {
      setPlatformLoading(false);
    }
  }

  async function quickClearFailedBuilds() {
    if (!token) return;
    setQuickBusy("clear-failed");
    try {
      const builds = await apiFetch<Paged<{ id: string; status?: string }>>(`/admin/builds?page=1&limit=100&status=failed`, { method: "GET", token });
      const failed = (builds?.items || []).filter((b) => b?.status === "failed");
      let cleared = 0;
      for (const b of failed.slice(0, 10)) {
        try {
          await apiFetch(`/admin/projects/${encodeURIComponent(b.id)}`, { method: "DELETE", token });
          cleared++;
        } catch {
          // ignore individual errors
        }
      }
      pushActivity("builds", `Cleared ${cleared} failed builds`, "emerald");
      toast.success(`Cleared ${cleared} failed builds`);
      await loadDashboardTelemetry();
    } catch (e: any) {
      pushActivity("error", "Failed to clear builds", "red");
      toast.error("Failed to clear builds", e?.message);
    } finally {
      setQuickBusy(null);
    }
  }

  async function quickRestartStuckBuilds() {
    if (!token) return;
    setQuickBusy("restart-stuck");
    try {
      const builds = await apiFetch<Paged<{ id: string; status?: string }>>(`/admin/builds?page=1&limit=100&status=running`, { method: "GET", token });
      const running = builds?.items || [];
      let restarted = 0;
      for (const b of running.slice(0, 5)) {
        try {
          await apiFetch(`/admin/builds/${encodeURIComponent(b.id)}/rebuild`, { method: "POST", token });
          restarted++;
        } catch {
          // ignore
        }
      }
      pushActivity("builds", `Restarted ${restarted} builds`, "cyan");
      toast.success(`Restarted ${restarted} builds`);
      await loadDashboardTelemetry();
    } catch (e: any) {
      pushActivity("error", "Failed to restart builds", "red");
      toast.error("Failed to restart builds", e?.message);
    } finally {
      setQuickBusy(null);
    }
  }

  async function quickBroadcastNotification() {
    router.push("/notifications");
  }

  async function loadLeaderboard() {
    if (!token) return;
    setLeaderboardLoading(true);
    try {
      const users = await apiFetch<Paged<{ username?: string; email?: string; projects?: number; builds?: number; downloads?: number }>>(`/admin/users?page=1&limit=10`, { method: "GET", token });
      const sorted = (users?.items || [])
        .map((u) => ({ username: u.username, email: u.email, projects: u.projects ?? 0, builds: u.builds ?? 0, downloads: u.downloads ?? 0 }))
        .sort((a, b) => (b.projects + b.builds + b.downloads) - (a.projects + a.builds + a.downloads))
        .slice(0, 8);
      setLeaderboard(sorted);
    } catch {
      // ignore
    } finally {
      setLeaderboardLoading(false);
    }
  }

  async function loadUserGrowth() {
    if (!token) return;
    setUserGrowthLoading(true);
    try {
      const users = await apiFetch<Paged<{ createdAt?: string }>>(`/admin/users?page=1&limit=500`, { method: "GET", token });
      const byDate = new Map<string, number>();
      for (const u of users?.items || []) {
        const d = u.createdAt ? new Date(u.createdAt).toISOString().slice(0, 10) : "unknown";
        byDate.set(d, (byDate.get(d) || 0) + 1);
      }
      const sorted = Array.from(byDate.entries())
        .map(([date, count]) => ({ date, count }))
        .sort((a, b) => a.date.localeCompare(b.date))
        .slice(-14);
      setUserGrowth(sorted);
    } catch {
      // ignore
    } finally {
      setUserGrowthLoading(false);
    }
  }

  async function loadErrorLog() {
    if (!token) return;
    setErrorLogLoading(true);
    try {
      const builds = await apiFetch<Paged<{ id: string; status?: string; updatedAt?: string; buildTarget?: string }>>(`/admin/builds?page=1&limit=20&status=failed`, { method: "GET", token });
      const errors = (builds?.items || []).map((b) => ({
        ts: b.updatedAt ? new Date(b.updatedAt).getTime() : Date.now(),
        msg: `Build failed: ${b.buildTarget || "unknown"}`,
        source: b.id,
      }));
      setErrorLog(errors.slice(0, 10));
    } catch {
      // ignore
    } finally {
      setErrorLogLoading(false);
    }
  }

  function pushErrorLog(msg: string, source?: string) {
    setErrorLog((prev) => [{ ts: Date.now(), msg, source }, ...prev].slice(0, 10));
  }

  function triggerConfetti(text: string) {
    setConfettiText(text);
    setShowConfetti(true);
    setTimeout(() => setShowConfetti(false), 3000);
  }

  async function generatePDFReport() {
    // Dynamic import to avoid SSR issues
    const jsPDF = (await import("jspdf")).default;

    const doc = new jsPDF();
    const pageWidth = doc.internal.pageSize.getWidth();
    const pageHeight = doc.internal.pageSize.getHeight();

    const setOpacity = (opacity: number) => {
      try {
        const GState = (doc as any).GState;
        if (!GState) return;
        doc.setGState(new GState({ opacity }));
      } catch {
        // ignore
      }
    };

    const resetOpacity = () => setOpacity(1);

    const drawCard = (
      x: number,
      y: number,
      w: number,
      h: number,
      r: number,
      fill: [number, number, number],
      stroke?: [number, number, number]
    ) => {
      setOpacity(0.25);
      doc.setFillColor(0, 0, 0);
      doc.roundedRect(x + 1.2, y + 1.2, w, h, r, r, "F");
      resetOpacity();
      doc.setFillColor(fill[0], fill[1], fill[2]);
      doc.roundedRect(x, y, w, h, r, r, "F");
      if (stroke) {
        doc.setDrawColor(stroke[0], stroke[1], stroke[2]);
        doc.setLineWidth(0.3);
        doc.roundedRect(x, y, w, h, r, r, "S");
      }
    };

    const newPage = () => {
      doc.addPage();
      doc.setFillColor(2, 6, 23);
      doc.rect(0, 0, pageWidth, pageHeight, "F");
      return 20;
    };

    const ensureSpace = (y: number, needed: number) => {
      const bottom = pageHeight - 18;
      if (y + needed <= bottom) return y;
      return newPage();
    };

    const clamp01 = (n: number) => Math.max(0, Math.min(1, n));

    const lastN = (arr: number[], n: number) => (n <= 0 ? [] : arr.slice(Math.max(0, arr.length - n)));

    const avg = (arr: number[]) => {
      if (!arr.length) return 0;
      let s = 0;
      for (const v of arr) s += Number(v || 0);
      return s / arr.length;
    };

    const pctChange = (current: number, previous: number) => {
      const c = Number(current || 0);
      const p = Number(previous || 0);
      if (p === 0) return c === 0 ? 0 : 100;
      return ((c - p) / Math.abs(p)) * 100;
    };

    const formatTrend = (t: number) => {
      if (!Number.isFinite(t)) return { label: "0%", up: true };
      const up = t >= 0;
      const mag = Math.abs(t);
      return { label: `${Math.round(mag)}%`, up };
    };

    const drawArcRing = (
      cx: number,
      cy: number,
      r: number,
      thickness: number,
      startDeg: number,
      endDeg: number,
      color: [number, number, number]
    ) => {
      const step = 4;
      doc.setDrawColor(color[0], color[1], color[2]);
      doc.setLineWidth(thickness);
      (doc as any).setLineCap?.("round");
      for (let a = startDeg; a < endDeg; a += step) {
        const a1 = (a * Math.PI) / 180;
        const a2 = (Math.min(a + step, endDeg) * Math.PI) / 180;
        const x1 = cx + Math.cos(a1) * r;
        const y1 = cy + Math.sin(a1) * r;
        const x2 = cx + Math.cos(a2) * r;
        const y2 = cy + Math.sin(a2) * r;
        doc.line(x1, y1, x2, y2);
      }
    };

    const drawDonut = (
      cx: number,
      cy: number,
      r: number,
      thickness: number,
      pct: number,
      fg: [number, number, number],
      bg: [number, number, number]
    ) => {
      const p = clamp01(pct / 100);
      const start = -90;
      const end = start + p * 360;
      drawArcRing(cx, cy, r, thickness, 0, 360, bg);
      if (p > 0) drawArcRing(cx, cy, r, thickness, start, end, fg);
    };

    doc.setFillColor(2, 6, 23);
    doc.rect(0, 0, pageWidth, pageHeight, "F");

    doc.setFillColor(15, 23, 42);
    doc.rect(0, 0, pageWidth, 55, "F");

    // Animated gradient stripes
    for (let i = 0; i < 5; i++) {
      const hue = 240 + i * 15;
      doc.setFillColor(99 - i * 10, 102 + i * 8, 241 - i * 15);
      doc.rect(0, 55 + i, pageWidth, 1, "F");
    }

    // Decorative corner accents
    doc.setFillColor(34, 211, 238);
    doc.circle(0, 0, 20, "F");
    doc.setFillColor(15, 23, 42);
    doc.circle(0, 0, 15, "F");

    doc.setFillColor(236, 72, 153);
    doc.circle(pageWidth, 55, 20, "F");
    doc.setFillColor(15, 23, 42);
    doc.circle(pageWidth, 55, 15, "F");

    // Logo area with premium gradient effect
    doc.setFillColor(99, 102, 241);
    doc.circle(28, 28, 14, "F");
    doc.setFillColor(139, 92, 246);
    doc.circle(28, 28, 10, "F");
    doc.setFillColor(168, 85, 247);
    doc.circle(28, 28, 7, "F");
    doc.setFillColor(192, 132, 252);
    doc.circle(28, 28, 4, "F");
    doc.setTextColor(255, 255, 255);
    doc.setFontSize(14);
    doc.setFont("helvetica", "bold");
    doc.text("GF", 28, 32, { align: "center" });

    // Title with glow effect
    doc.setTextColor(255, 255, 255);
    doc.setFontSize(32);
    doc.setFont("helvetica", "bold");
    doc.text("GameForge", 50, 22);
    doc.setFontSize(12);
    doc.setFont("helvetica", "normal");
    doc.setTextColor(148, 163, 184);
    doc.text("Admin Dashboard Report", 50, 34);

    // Status badge
    doc.setFillColor(16, 185, 129);
    doc.roundedRect(pageWidth - 60, 12, 46, 16, 2, 2, "F");
    doc.setTextColor(255, 255, 255);
    doc.setFontSize(8);
    doc.setFont("helvetica", "bold");
    doc.text("LIVE", pageWidth - 37, 22, { align: "center" });

    // Generated timestamp
    doc.setFontSize(8);
    doc.setTextColor(100, 116, 139);
    const genDate = new Date();
    doc.text(`Generated: ${genDate.toLocaleDateString()} at ${genDate.toLocaleTimeString()}`, pageWidth - 14, 48, { align: "right" });

    let yPos = 68;

    // === ADMIN USER CARD WITH AVATAR ===
    drawCard(14, yPos, pageWidth - 28, 32, 3, [17, 24, 39], [55, 65, 81]);

    // Avatar with gradient
    doc.setFillColor(99, 102, 241);
    doc.circle(32, yPos + 16, 10, "F");
    doc.setFillColor(139, 92, 246);
    doc.circle(32, yPos + 16, 7, "F");
    doc.setTextColor(255, 255, 255);
    doc.setFontSize(14);
    doc.setFont("helvetica", "bold");
    doc.text(`${(data?.user?.username || "Admin").charAt(0).toUpperCase()}`, 32, yPos + 20, { align: "center" });

    // User info
    doc.setTextColor(255, 255, 255);
    doc.setFontSize(14);
    doc.text(data?.user?.username || "Administrator", 48, yPos + 12);
    doc.setTextColor(148, 163, 184);
    doc.setFontSize(9);
    doc.setFont("helvetica", "normal");
    doc.text(`${data?.user?.email || "admin@gameforge.io"}  •  ${data?.user?.role || "admin"}`, 48, yPos + 22);

    // Online indicator
    doc.setFillColor(16, 185, 129);
    doc.circle(pageWidth - 30, yPos + 16, 4, "F");
    doc.setTextColor(16, 185, 129);
    doc.setFontSize(8);
    doc.text("Online", pageWidth - 40, yPos + 18, { align: "right" });

    yPos += 44;

    // === HEALTH SCORE PREMIUM GAUGE ===
    yPos = ensureSpace(yPos, 110);
    drawCard(14, yPos, pageWidth - 28, 92, 4, [17, 24, 39], [55, 65, 81]);

    const healthX = pageWidth / 2;
    const healthY = yPos + 46;
    const healthR = 24;

    // Outer glow rings
    doc.setFillColor(30, 41, 59);
    doc.circle(healthX, healthY, healthR + 12, "F");

    // Animated-looking ring segments
    for (let ring = 0; ring < 3; ring++) {
      doc.setDrawColor(99 - ring * 20, 102 + ring * 10, 241 - ring * 30);
      doc.setLineWidth(0.5);
      doc.circle(healthX, healthY, healthR + 6 + ring * 2, "S");
    }

    // Score arc (simplified as filled segment)
    const scoreColor = healthScore >= 80 ? [16, 185, 129] : healthScore >= 50 ? [245, 158, 11] : [239, 68, 68];
    doc.setFillColor(scoreColor[0], scoreColor[1], scoreColor[2]);
    doc.circle(healthX, healthY, healthR, "F");
    doc.setFillColor(15, 23, 42);
    doc.circle(healthX, healthY, healthR - 8, "F");

    // Inner glow
    doc.setFillColor(scoreColor[0], scoreColor[1], scoreColor[2]);
    doc.circle(healthX, healthY, 6, "F");

    // Score text
    doc.setTextColor(255, 255, 255);
    doc.setFontSize(22);
    doc.setFont("helvetica", "bold");
    doc.text(`${healthScore}`, healthX, healthY + 5, { align: "center" });
    doc.setFontSize(8);
    doc.text("/ 100", healthX, healthY + 12, { align: "center" });

    // Health label with icon
    doc.setTextColor(148, 163, 184);
    doc.setFontSize(10);
    doc.setFont("helvetica", "normal");
    doc.text("HEALTH INDEX", healthX, yPos + 18, { align: "center" });
    doc.setTextColor(scoreColor[0], scoreColor[1], scoreColor[2]);
    doc.setFont("helvetica", "bold");
    doc.setFontSize(11);
    doc.text(healthScore >= 80 ? "Excellent" : healthScore >= 50 ? "Good" : "Needs Attention", healthX, yPos + 84, { align: "center" });

    yPos += 104;

    // === KEY METRICS ROW WITH TRENDS ===
    yPos = ensureSpace(yPos, 60);
    const userSeries = userGrowth.map((u) => Number(u.count || 0));
    const usersPrev = avg(lastN(userSeries.slice(0, -7), 7)) || avg(lastN(userSeries, 14).slice(0, 7));
    const usersCur = avg(lastN(userSeries, 7));
    const usersTrend = formatTrend(pctChange(usersCur, usersPrev));

    const buildSeries = tsRunning.map((v, i) => Number(v || 0) + Number(tsQueued[i] || 0) + Number(tsFailed[i] || 0));
    const buildsPrev = avg(lastN(buildSeries.slice(0, -6), 6)) || avg(lastN(buildSeries, 12).slice(0, 6));
    const buildsCur = avg(lastN(buildSeries, 6));
    const buildsTrend = formatTrend(pctChange(buildsCur, buildsPrev));

    const mrrSeries = tsMrr.map((v) => Number(v || 0));
    const mrrPrev = avg(lastN(mrrSeries.slice(0, -6), 6)) || avg(lastN(mrrSeries, 12).slice(0, 6));
    const mrrCur = avg(lastN(mrrSeries, 6));
    const mrrTrend = formatTrend(pctChange(mrrCur, mrrPrev));

    const metricBoxes = [
      { label: "USERS", value: totalUsers, color: [34, 211, 238], icon: "U", trend: usersTrend.label, trendUp: usersTrend.up },
      { label: "BUILDS", value: buildTotal, color: [236, 72, 153], icon: "B", trend: buildsTrend.label, trendUp: buildsTrend.up },
      { label: "TEMPLATES", value: templateTotal, color: [168, 85, 247], icon: "T", trend: "0%", trendUp: true },
      { label: "MRR", value: `$${Number(billing?.totals?.mrrApproxUsd ?? 0).toFixed(0)}`, color: [16, 185, 129], icon: "$", trend: mrrTrend.label, trendUp: mrrTrend.up },
    ];

    const boxWidth = (pageWidth - 28 - 12) / 4;
    metricBoxes.forEach((box, i) => {
      const bx = 14 + i * (boxWidth + 4);

      // Card background with gradient accent
      drawCard(bx, yPos, boxWidth, 32, 2, [17, 24, 39], [55, 65, 81]);

      // Top accent bar
      doc.setFillColor(box.color[0], box.color[1], box.color[2]);
      doc.roundedRect(bx, yPos, boxWidth, 3, 2, 2, "F");

      // Icon circle with glow
      doc.setFillColor(box.color[0] + 30, box.color[1] + 30, box.color[2] + 30);
      doc.circle(bx + 14, yPos + 16, 7, "F");
      doc.setFillColor(box.color[0], box.color[1], box.color[2]);
      doc.circle(bx + 14, yPos + 16, 5, "F");
      doc.setTextColor(255, 255, 255);
      doc.setFontSize(9);
      doc.setFont("helvetica", "bold");
      doc.text(box.icon, bx + 14, yPos + 18, { align: "center" });

      // Value
      doc.setTextColor(255, 255, 255);
      doc.setFontSize(16);
      doc.setFont("helvetica", "bold");
      doc.text(String(box.value), bx + boxWidth - 6, yPos + 12, { align: "right" });

      // Label
      doc.setTextColor(148, 163, 184);
      doc.setFontSize(7);
      doc.setFont("helvetica", "normal");
      doc.text(box.label, bx + boxWidth - 6, yPos + 20, { align: "right" });

      // Trend indicator with arrow
      doc.setTextColor(box.trendUp ? 16 : 239, box.trendUp ? 185 : 68, box.trendUp ? 129 : 68);
      doc.setFontSize(9);
      doc.setFont("helvetica", "bold");
      doc.text(`${box.trendUp ? "↑" : "↓"} ${box.trend}`, bx + boxWidth - 6, yPos + 28, { align: "right" });
    });

    yPos += 42;

    // === MINI CHARTS ROW ===
    yPos = ensureSpace(yPos, 70);
    // User Growth Sparkline
    drawCard(14, yPos, pageWidth / 2 - 18, 40, 2, [17, 24, 39], [55, 65, 81]);

    // Chart header
    doc.setTextColor(34, 211, 238);
    doc.setFontSize(9);
    doc.setFont("helvetica", "bold");
    doc.text("USER GROWTH", 18, yPos + 8);
    doc.setTextColor(148, 163, 184);
    doc.setFontSize(7);
    doc.text("Last 14 days", 18, yPos + 14);

    // Sparkline bars with gradient
    const sparkData = userGrowth.length > 0 ? userGrowth.map(u => u.count) : [10, 15, 12, 18, 22, 25, 30, 28, 35, 40, 38, 45, 50, 55];
    const maxSpark = Math.max(...sparkData, 1);
    const barW = ((pageWidth / 2 - 18) - 20) / sparkData.length;
    sparkData.forEach((v, i) => {
      const barH = Math.max(2, (v / maxSpark) * 20);
      const intensity = v / maxSpark;
      doc.setFillColor(
        Math.round(34 + intensity * 20),
        Math.round(211 - intensity * 50),
        Math.round(238 - intensity * 30)
      );
      doc.roundedRect(18 + i * barW, yPos + 35 - barH, barW - 1, barH, 0.5, 0.5, "F");
    });

    // Build Success Pie
    drawCard(pageWidth / 2 + 4, yPos, pageWidth / 2 - 18, 40, 2, [17, 24, 39], [55, 65, 81]);

    // Chart header
    doc.setTextColor(236, 72, 153);
    doc.setFontSize(9);
    doc.setFont("helvetica", "bold");
    doc.text("BUILD SUCCESS RATE", pageWidth / 2 + 8, yPos + 8);

    // Pie chart with segments
    const successPct = successRate;
    const pieX = pageWidth / 2 + 28;
    const pieY = yPos + 25;
    const pieR = 12;

    // True donut arc
    drawDonut(pieX, pieY, pieR, 4.5, successPct, [16, 185, 129], [239, 68, 68]);

    // Inner circle for donut effect
    doc.setFillColor(30, 41, 59);
    doc.circle(pieX, pieY, pieR - 6, "F");

    // Percentage text
    doc.setTextColor(255, 255, 255);
    doc.setFontSize(14);
    doc.setFont("helvetica", "bold");
    doc.text(`${successPct}%`, pieX, pieY + 4, { align: "center" });

    // Legend
    doc.setTextColor(16, 185, 129);
    doc.setFontSize(7);
    doc.text(`● Success: ${builds?.ready ?? 0}`, pageWidth / 2 + 50, yPos + 20);
    doc.setTextColor(239, 68, 68);
    doc.text(`● Failed: ${builds?.failed ?? 0}`, pageWidth / 2 + 50, yPos + 28);
    doc.setTextColor(59, 130, 246);
    doc.text(`● Running: ${builds?.running ?? 0}`, pageWidth / 2 + 50, yPos + 36);

    yPos += 48;

    // === SYSTEM HEALTH RADAR-STYLE GRID ===
    yPos = ensureSpace(yPos, 76);
    doc.setFillColor(99, 102, 241);
    doc.roundedRect(14, yPos, pageWidth - 28, 6, 1, 1, "F");
    yPos += 2;
    doc.setTextColor(255, 255, 255);
    doc.setFontSize(10);
    doc.setFont("helvetica", "bold");
    doc.text("SYSTEM HEALTH", 18, yPos + 4);
    yPos += 12;

    // System health grid with visual indicators
    const sysMetrics = [
      { label: "Status", value: sys?.status || "unknown", ok: sys?.status === "healthy", weight: 100 },
      { label: "Uptime", value: uptimeStr, ok: true, weight: 95 },
      { label: "Heap Used", value: bytes(sys?.memory?.heapUsed), ok: true, weight: 80 },
      { label: "Memory Free", value: bytes(sys?.memory?.systemFree), ok: true, weight: 85 },
      { label: "Success Rate", value: `${successRate}%`, ok: successRate >= 80, weight: successRate },
      { label: "Queue Depth", value: String(builds?.queued ?? 0), ok: (builds?.queued ?? 0) < 10, weight: 90 },
    ];

    const colW = (pageWidth - 28) / 2;
    sysMetrics.forEach((m, i) => {
      const mx = 14 + (i % 2) * colW;
      const my = yPos + Math.floor(i / 2) * 16;

      drawCard(mx, my, colW - 4, 14, 1, [17, 24, 39], [55, 65, 81]);

      // Progress bar background
      doc.setFillColor(55, 65, 81);
      doc.roundedRect(mx + 12, my + 10, colW - 28, 2, 0.5, 0.5, "F");

      // Progress bar fill
      const barFill = Math.min(100, m.weight) / 100;
      doc.setFillColor(m.ok ? 16 : 239, m.ok ? 185 : 68, m.ok ? 129 : 68);
      doc.roundedRect(mx + 12, my + 10, (colW - 28) * barFill, 2, 0.5, 0.5, "F");

      // Status dot with glow
      doc.setFillColor(m.ok ? 16 : 239, m.ok ? 185 : 68, m.ok ? 129 : 68);
      doc.circle(mx + 6, my + 7, 3, "F");

      doc.setTextColor(148, 163, 184);
      doc.setFontSize(8);
      doc.setFont("helvetica", "normal");
      doc.text(m.label, mx + 12, my + 5);
      doc.setTextColor(255, 255, 255);
      doc.setFont("helvetica", "bold");
      doc.text(m.value, mx + colW - 10, my + 9, { align: "right" });
    });

    yPos += 52;

    // === BUILD STATUS WITH VISUAL BARS ===
    yPos = ensureSpace(yPos, 56);
    doc.setFillColor(236, 72, 153);
    doc.roundedRect(14, yPos, pageWidth - 28, 6, 1, 1, "F");
    yPos += 2;
    doc.setTextColor(255, 255, 255);
    doc.setFontSize(10);
    doc.setFont("helvetica", "bold");
    doc.text("BUILD STATUS", 18, yPos + 4);
    yPos += 12;

    // Build status cards with progress bars
    const buildMetrics = [
      { label: "Queued", value: builds?.queued ?? 0, color: [251, 191, 36], icon: "⏳" },
      { label: "Running", value: builds?.running ?? 0, color: [59, 130, 246], icon: "▶" },
      { label: "Ready", value: builds?.ready ?? 0, color: [16, 185, 129], icon: "✓" },
      { label: "Failed", value: builds?.failed ?? 0, color: [239, 68, 68], icon: "✗" },
    ];

    buildMetrics.forEach((b, i) => {
      const bx = 14 + i * ((pageWidth - 28) / 4);
      const bw = (pageWidth - 28) / 4 - 3;

      drawCard(bx, yPos, bw, 24, 2, [17, 24, 39], [55, 65, 81]);

      // Top accent
      doc.setFillColor(b.color[0], b.color[1], b.color[2]);
      doc.roundedRect(bx, yPos, bw, 2, 2, 2, "F");

      // Progress bar
      const maxVal = Math.max(...buildMetrics.map(x => x.value), 1);
      const barWidth = Math.max(4, (b.value / maxVal) * (bw - 8));
      doc.setFillColor(b.color[0], b.color[1], b.color[2]);
      doc.roundedRect(bx + 4, yPos + 16, barWidth, 4, 1, 1, "F");

      // Value
      doc.setTextColor(255, 255, 255);
      doc.setFontSize(16);
      doc.setFont("helvetica", "bold");
      doc.text(String(b.value), bx + bw / 2, yPos + 10, { align: "center" });

      // Label
      doc.setTextColor(148, 163, 184);
      doc.setFontSize(7);
      doc.setFont("helvetica", "normal");
      doc.text(b.label.toUpperCase(), bx + bw / 2, yPos + 21, { align: "center" });
    });

    yPos += 32;

    // === BILLING OVERVIEW PREMIUM ===
    yPos = ensureSpace(yPos, 54);
    doc.setFillColor(16, 185, 129);
    doc.roundedRect(14, yPos, pageWidth - 28, 6, 1, 1, "F");
    yPos += 2;
    doc.setTextColor(255, 255, 255);
    doc.setFontSize(10);
    doc.setFont("helvetica", "bold");
    doc.text("BILLING OVERVIEW", 18, yPos + 4);
    yPos += 12;

    // Billing metrics with icons
    const billingMetrics = [
      { label: "MRR (Approx)", value: `$${Number(billing?.totals?.mrrApproxUsd ?? 0).toFixed(2)}`, icon: "$", subtext: "Monthly Recurring Revenue" },
      { label: "Active Subs", value: String(billing?.totals?.active ?? 0), icon: "A", subtext: "Currently Active" },
      { label: "Total Subs", value: String(billing?.totals?.subscriptions ?? 0), icon: "T", subtext: "All Time" },
    ];

    billingMetrics.forEach((m, i) => {
      const mx = 14 + i * ((pageWidth - 28) / 3);
      const mw = (pageWidth - 28) / 3 - 3;

      drawCard(mx, yPos, mw, 22, 2, [17, 24, 39], [55, 65, 81]);

      // Icon with glow
      doc.setFillColor(16, 185, 129);
      doc.circle(mx + 12, yPos + 11, 6, "F");
      doc.setTextColor(15, 23, 42);
      doc.setFontSize(10);
      doc.setFont("helvetica", "bold");
      doc.text(m.icon, mx + 12, yPos + 13, { align: "center" });

      // Value
      doc.setTextColor(255, 255, 255);
      doc.setFontSize(14);
      doc.text(m.value, mx + mw - 6, yPos + 10, { align: "right" });

      // Label
      doc.setTextColor(148, 163, 184);
      doc.setFontSize(7);
      doc.setFont("helvetica", "normal");
      doc.text(m.label, mx + mw - 6, yPos + 16, { align: "right" });
    });

    {
      const mrr = Number(billing?.totals?.mrrApproxUsd ?? 0);
      const daily = mrr / 30;
      const arr = mrr * 12;

      doc.setTextColor(100, 116, 139);
      doc.setFontSize(7);
      doc.setFont("helvetica", "normal");
      doc.text("APP EARNINGS (EST)", 18, yPos + 28);
      doc.setTextColor(255, 255, 255);
      doc.setFont("helvetica", "bold");
      doc.text(`Daily ~$${daily.toFixed(2)}   •   ARR ~$${arr.toFixed(0)}`, pageWidth - 18, yPos + 28, { align: "right" });

      const bal = Number(stripeFinance?.balance?.totalUsd ?? 0);
      const avail = Number(stripeFinance?.balance?.availableUsd ?? 0);
      const pending = Number(stripeFinance?.balance?.pendingUsd ?? 0);
      const grossToday = Number(stripeFinance?.grossVolume?.todayUsd ?? 0);
      const payoutsToday = Number(stripeFinance?.payouts?.todayUsd ?? 0);

      doc.setTextColor(100, 116, 139);
      doc.setFontSize(7);
      doc.setFont("helvetica", "normal");
      doc.text("STRIPE FINANCE", 18, yPos + 36);

      doc.setTextColor(255, 255, 255);
      doc.setFont("helvetica", "bold");
      doc.setFontSize(7);
      doc.text(
        `Balance $${bal.toFixed(2)} (avail $${avail.toFixed(2)} / pend $${pending.toFixed(2)})`,
        18,
        yPos + 42,
      );
      doc.text(`Today gross $${grossToday.toFixed(2)}   •   Today payouts $${payoutsToday.toFixed(2)}`, 18, yPos + 48);

      const statusRows = Object.entries(billing?.byStatus || {})
        .sort((a, b) => Number(b[1]) - Number(a[1]))
        .slice(0, 3);
      const planRows = Object.entries(billing?.byPlan || {})
        .sort((a, b) => Number(b[1]) - Number(a[1]))
        .slice(0, 3);

      if (statusRows.length || planRows.length) {
        doc.setTextColor(100, 116, 139);
        doc.setFontSize(7);
        doc.setFont("helvetica", "normal");
        doc.text("STRIPE BREAKDOWN", 18, yPos + 56);

        doc.setTextColor(148, 163, 184);
        doc.setFontSize(6);
        doc.text("Statuses", 18, yPos + 62);
        doc.text("Plans", pageWidth / 2 + 4, yPos + 62);

        doc.setTextColor(255, 255, 255);
        doc.setFont("helvetica", "bold");
        for (let i = 0; i < 3; i++) {
          const rowY = yPos + 68 + i * 6;
          const s = statusRows[i];
          if (s) doc.text(`${String(s[0]).slice(0, 14)}: ${s[1]}`, 18, rowY);
          const p = planRows[i];
          if (p) doc.text(`${String(p[0]).slice(0, 14)}: ${p[1]}`, pageWidth / 2 + 4, rowY);
        }
      }
    }

    yPos += 30;

    // === PLATFORM DISTRIBUTION WITH ICONS ===
    if (platformDist.length > 0) {
      yPos = ensureSpace(yPos, Math.ceil(platformDist.length / 3) * 20 + 36);
      doc.setFillColor(168, 85, 247);
      doc.roundedRect(14, yPos, pageWidth - 28, 6, 1, 1, "F");
      yPos += 2;
      doc.setTextColor(255, 255, 255);
      doc.setFontSize(10);
      doc.setFont("helvetica", "bold");
      doc.text("PLATFORM DISTRIBUTION", 18, yPos + 4);
      yPos += 12;

      const total = platformDist.reduce((s, x) => s + x.count, 0);
      const platformColors: Record<string, number[]> = {
        webgl: [34, 211, 238],
        android: [16, 185, 129],
        windows: [59, 130, 246],
        macos: [168, 85, 247],
        ios: [236, 72, 153],
      };
      const platformIcons: Record<string, string> = {
        webgl: "W",
        android: "A",
        windows: "W",
        macos: "M",
        ios: "i",
      };

      platformDist.forEach((p, i) => {
        const px = 14 + (i % 3) * ((pageWidth - 28) / 3);
        const pw = (pageWidth - 28) / 3 - 3;
        const py = yPos + Math.floor(i / 3) * 18;

        drawCard(px, py, pw, 16, 2, [17, 24, 39], [55, 65, 81]);

        const color = platformColors[p.target.toLowerCase()] || [148, 163, 184];

        // Platform icon
        doc.setFillColor(color[0], color[1], color[2]);
        doc.circle(px + 10, py + 8, 5, "F");
        doc.setTextColor(255, 255, 255);
        doc.setFontSize(8);
        doc.setFont("helvetica", "bold");
        doc.text(platformIcons[p.target.toLowerCase()] || "?", px + 10, py + 10, { align: "center" });

        // Platform name
        doc.setTextColor(255, 255, 255);
        doc.setFontSize(10);
        doc.text(p.target.toUpperCase(), px + 20, py + 7);

        // Stats
        doc.setTextColor(148, 163, 184);
        doc.setFontSize(8);
        doc.text(`${p.count} builds • ${Math.round((p.count / total) * 100)}%`, px + 20, py + 13);
      });

      yPos += Math.ceil(platformDist.length / 3) * 20 + 10;
    }

    // === TOP CREATORS LEADERBOARD PREMIUM ===
    if (leaderboard.length > 0) {
      yPos = ensureSpace(yPos, 40 + Math.min(5, leaderboard.length) * 16);
      doc.setFillColor(251, 191, 36);
      doc.roundedRect(14, yPos, pageWidth - 28, 6, 1, 1, "F");
      yPos += 2;
      doc.setTextColor(15, 23, 42);
      doc.setFontSize(10);
      doc.setFont("helvetica", "bold");
      doc.text("TOP CREATORS LEADERBOARD", 18, yPos + 4);
      yPos += 12;

      leaderboard.slice(0, 5).forEach((u, i) => {
        // Row background with alternating highlight
        if (i < 3) {
          drawCard(14, yPos + i * 14, pageWidth - 28, 12, 1, [26, 36, 58], [55, 65, 81]);
        } else {
          drawCard(14, yPos + i * 14, pageWidth - 28, 12, 1, [17, 24, 39], [55, 65, 81]);
        }

        // Rank badge with medal colors and glow
        const rankColors = [[251, 191, 36], [192, 192, 192], [205, 127, 50], [99, 102, 241], [99, 102, 241]];
        const rc = rankColors[i];

        // Outer glow
        doc.setFillColor(rc[0], rc[1], rc[2]);
        doc.circle(22, yPos + i * 14 + 6, 5, "F");
        doc.setFillColor(15, 23, 42);
        doc.circle(22, yPos + i * 14 + 6, 3, "F");
        doc.setFillColor(rc[0], rc[1], rc[2]);
        doc.circle(22, yPos + i * 14 + 6, 2, "F");

        doc.setTextColor(15, 23, 42);
        doc.setFontSize(8);
        doc.setFont("helvetica", "bold");
        doc.text(`${i + 1}`, 22, yPos + i * 14 + 8, { align: "center" });

        // Username
        doc.setTextColor(255, 255, 255);
        doc.setFontSize(10);
        doc.text((u.username || u.email || "—").slice(0, 18), 32, yPos + i * 14 + 6);

        // Stats breakdown with icons
        doc.setTextColor(148, 163, 184);
        doc.setFontSize(7);
        doc.text(`P:${u.projects ?? 0}  B:${u.builds ?? 0}  D:${u.downloads ?? 0}`, 32, yPos + i * 14 + 11);

        // Total score with emphasis
        doc.setTextColor(16, 185, 129);
        doc.setFontSize(12);
        doc.setFont("helvetica", "bold");
        doc.text(String((u.projects ?? 0) + (u.builds ?? 0) + (u.downloads ?? 0)), pageWidth - 18, yPos + i * 14 + 8, { align: "right" });
      });
    }

    // === ERROR LOG PREVIEW (if any) ===
    if (errorLog.length > 0) {
      yPos += leaderboard.length > 0 ? 72 : 10;

      yPos = ensureSpace(yPos, 50);

      doc.setFillColor(239, 68, 68);
      doc.roundedRect(14, yPos, pageWidth - 28, 6, 1, 1, "F");
      yPos += 2;
      doc.setTextColor(255, 255, 255);
      doc.setFontSize(10);
      doc.setFont("helvetica", "bold");
      doc.text("RECENT ERRORS", 18, yPos + 4);
      yPos += 12;

      errorLog.slice(0, 3).forEach((err, i) => {
        drawCard(14, yPos + i * 10, pageWidth - 28, 8, 1, [17, 24, 39], [55, 65, 81]);

        // Error icon
        doc.setFillColor(239, 68, 68);
        doc.circle(20, yPos + i * 10 + 4, 2, "F");

        doc.setTextColor(255, 255, 255);
        doc.setFontSize(7);
        doc.text(err.msg.slice(0, 60), 26, yPos + i * 10 + 5);

        doc.setTextColor(148, 163, 184);
        doc.setFontSize(6);
        const errTime = new Date(err.ts).toLocaleTimeString();
        doc.text(errTime, pageWidth - 18, yPos + i * 10 + 5, { align: "right" });
      });
    }

    // === FOOTER ===
    const pageCount = doc.getNumberOfPages();
    for (let i = 1; i <= pageCount; i++) {
      doc.setPage(i);

      // Footer gradient bar
      for (let j = 0; j < 3; j++) {
        doc.setFillColor(99 - j * 10, 102 + j * 5, 241 - j * 10);
        doc.rect(0, pageHeight - 12 + j, pageWidth, 1, "F");
      }

      doc.setFontSize(8);
      doc.setTextColor(100, 116, 139);
      doc.setFont("helvetica", "normal");
      doc.text(
        `GameForge Admin Dashboard  •  Page ${i} of ${pageCount}  •  Confidential`,
        pageWidth / 2,
        pageHeight - 6,
        { align: "center" }
      );
    }

    // Save the PDF
    const filename = `gameforge-report-${new Date().toISOString().slice(0, 10)}.pdf`;
    doc.save(filename);
    toast.success(`Report saved: ${filename}`);
    triggerConfetti("Report Generated!");
  }

  function buildMetricsContext() {
    return {
      system: { status: sys?.status, uptimeSeconds: sys?.runtime?.uptimeSeconds, memory: sys?.memory },
      builds: builds,
      dashboard: data?.dashboard,
      billing: billing,
      ads: {
        activeTitle: adsActive?.title,
        total: adsCampaigns.length,
        activeCount: adsCampaigns.filter((c) => Boolean(c?.active)).length,
      },
      templatesUsageTop: tplUsage,
      feedTop: feedTop,
      computed: {
        successRate,
        queuePressure,
        heapRate,
        memFreeRate,
        bannedRate,
        templatePublicRate,
        adsActiveRate,
      },
      telemetrySeries: {
        tsQueued,
        tsRunning,
        tsFailed,
        tsHeapMb,
        tsMrr,
      },
    };
  }

  function actionHref(title: string) {
    const t = title.toLowerCase();
    if (t.includes("build") || t.includes("queue") || t.includes("reactor")) return "/builds";
    if (t.includes("system") || t.includes("memory") || t.includes("heap") || t.includes("cpu") || t.includes("health")) return "/system";
    if (t.includes("billing") || t.includes("mrr") || t.includes("subscription") || t.includes("stripe")) return "/billing";
    if (t.includes("template") || t.includes("vault") || t.includes("store")) return "/templates";
    if (t.includes("user") || t.includes("ban") || t.includes("role") || t.includes("access")) return "/users";
    if (t.includes("project")) return "/projects";
    return "/dashboard";
  }

  async function sendChat() {
    const msg = chatInput.trim();
    if (!msg) return;
    setChatInput("");
    setChatLoading(true);
    setChatError(null);
    const nextHistory = [...chatHistory, { role: "user" as const, text: msg }];
    setChatHistory(nextHistory);
    try {
      const r = await fetch("/api/ai/chat", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          message: msg,
          history: nextHistory,
          context: buildMetricsContext(),
        }),
      });
      const j = (await r.json().catch(() => null)) as any;
      if (!r.ok || !j || j?.success !== true) {
        throw new Error(j?.message || `AI chat failed (${r.status})`);
      }
      const text = String(j?.data?.text || "").trim();
      setChatHistory((prev: Array<{ role: "user" | "model"; text: string }>) => [...prev, { role: "model", text: text || "(empty)" }]);
    } catch (e: any) {
      setChatError(e?.message || "Chat failed");
    } finally {
      setChatLoading(false);
    }
  }

  function toInt(v: any) {
    if (typeof v === "number" && Number.isFinite(v)) return Math.floor(v);
    const n = Number(String(v ?? "").trim());
    return Number.isFinite(n) ? Math.floor(n) : 0;
  }

  function postId(p: GameFeedPostLite) {
    return String(p?.id || p?._id || "");
  }

  function isAdPost(p: GameFeedPostLite) {
    return String(p?.kind || "").toLowerCase() === "ad";
  }

  function parseTimeMs(v: any) {
    const s = String(v ?? "").trim();
    if (!s) return null;
    const t = Date.parse(s);
    return Number.isFinite(t) ? t : null;
  }

  function ageLabelFromMs(ms: number) {
    const sec = Math.max(0, Math.floor(ms / 1000));
    if (sec < 60) return `${sec}s`;
    const min = Math.floor(sec / 60);
    if (min < 60) return `${min}m`;
    const h = Math.floor(min / 60);
    if (h < 48) return `${h}h`;
    const d = Math.floor(h / 24);
    return `${d}d`;
  }

  async function loadFeedIntel() {
    if (!token) return;
    setFeedLoading(true);
    setFeedError(null);
    setFeedBarsOn(false);
    try {
      const res = await apiFetch<any>("/game-feed?limit=60", { method: "GET", token });
      const list = Array.isArray(res)
        ? (res as GameFeedPostLite[])
        : Array.isArray(res?.data)
          ? (res.data as GameFeedPostLite[])
          : Array.isArray(res?.items)
            ? (res.items as GameFeedPostLite[])
            : [];

      const rows = list
        .filter((p) => !isAdPost(p))
        .map((p) => {
          const id = postId(p);
          const likes = toInt((p as any)?.likeCount);
          const comments = toInt((p as any)?.commentCount);
          const plays = toInt((p as any)?.playCount);
          const remixes = toInt((p as any)?.remixCount);
          const shares = toInt((p as any)?.shareCount);
          const score = likes * 3 + comments * 4 + remixes * 6 + shares * 5 + Math.round(Math.log10(plays + 1) * 10);

          const tMs = parseTimeMs((p as any)?.updatedAt) ?? parseTimeMs((p as any)?.createdAt);
          const ageMs = tMs ? Date.now() - tMs : 24 * 3600 * 1000;
          const ageHours = Math.max(0.1, ageMs / (3600 * 1000));
          const decay = 1 / (1 + ageHours / 10);
          const hotScore = Math.round(score * decay);
          const ageLabel = tMs ? ageLabelFromMs(ageMs) : "—";

          const title = String(p?.title || p?.name || "Game");
          const creator = String(p?.creatorUsername || p?.creator || "—").trim() || "—";
          return { id, title, creator, score, hotScore, ageLabel, likes, comments, plays, remixes, shares };
        })
        .filter((r) => r.id)
        .sort((a, b) => (feedMode === "hot" ? b.hotScore - a.hotScore : b.score - a.score))
        .slice(0, 8);

      setFeedTop(rows);
      setTimeout(() => setFeedBarsOn(true), 30);
    } catch (e: any) {
      setFeedError(e?.message || "Failed to load feed intel");
    } finally {
      setFeedLoading(false);
    }
  }

  async function loadAiOpsBrief(metrics: any) {
    setAiLoading(true);
    setAiError(null);
    try {
      const r = await fetch("/api/ai/ops-brief", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ metrics }),
      });

      const j = (await r.json().catch(() => null)) as any;
      if (!r.ok || !j || j?.success !== true) {
        throw new Error(j?.message || `AI request failed (${r.status})`);
      }
      const d = j?.data || {};
      setAiBrief(Array.isArray(d?.brief) ? d.brief.map((s: any) => String(s)) : []);
      setAiActions(
        Array.isArray(d?.actions)
          ? d.actions
            .map((a: any) => ({ title: String(a?.title || ""), why: String(a?.why || "") }))
            .filter((a: any) => a.title.trim())
          : [],
      );
    } catch (e: any) {
      setAiError(e?.message || "AI brief failed");
    } finally {
      setAiLoading(false);
    }
  }

  async function loadTemplateUsage() {
    if (!token) return;
    setTplUsageLoading(true);
    setTplUsageError(null);
    setTplBarsOn(false);
    try {
      const [projects, templates] = await Promise.all([
        apiFetch<Paged<ProjectRowLite>>(`/admin/projects?page=1&limit=200`, { method: "GET", token }),
        apiFetch<Paged<TemplateRowLite>>(`/admin/templates?page=1&limit=200`, { method: "GET", token }),
      ]);

      const nameById = new Map<string, string>();
      for (const t of templates?.items || []) {
        if (t?.id) nameById.set(t.id, (t?.name || "Unnamed template").toString());
      }

      const counts = new Map<string, number>();
      for (const p of projects?.items || []) {
        const tid = (p?.templateId || "").toString();
        if (!tid) continue;
        counts.set(tid, (counts.get(tid) || 0) + 1);
      }

      const rows = Array.from(counts.entries())
        .map(([templateId, count]) => ({ templateId, count, name: nameById.get(templateId) || "Unknown template" }))
        .sort((a, b) => b.count - a.count)
        .slice(0, 8);

      setTplUsage(rows);
      setTimeout(() => setTplBarsOn(true), 30);
    } catch (e: any) {
      setTplUsageError(e?.message || "Failed to load template usage");
    } finally {
      setTplUsageLoading(false);
    }
  }

  async function loadDashboardTelemetry() {
    if (!token) return;
    setTelemetryLoading(true);
    try {
      const d = await apiFetch<AdminDashboardData>("/admin/dashboard", { method: "GET", token });
      setData(d);
      setDashLastAt(Date.now());

      const b = d?.dashboard?.buildStatus;
      const queued = Number(b?.queued ?? 0);
      const running = Number(b?.running ?? 0);
      const failed = Number(b?.failed ?? 0);
      setTsQueued((prev) => pushSample(prev, queued));
      setTsRunning((prev) => pushSample(prev, running));
      setTsFailed((prev) => pushSample(prev, failed));
    } catch {
      // ignore, dashboard already handles errors on initial load
    } finally {
      setTelemetryLoading(false);
    }
  }

  async function loadBilling() {
    if (!token) return;
    setBillingLoading(true);
    setBillingError(null);
    try {
      const d = await apiFetch<BillingOverviewLite>("/admin/billing/overview", { method: "GET", token });
      setBilling(d);
      const mrr = Number(d?.totals?.mrrApproxUsd ?? 0);
      setTsMrr((prev) => pushSample(prev, mrr));
    } catch (e: any) {
      setBillingError(e?.message || "Failed to load billing");
    } finally {
      setBillingLoading(false);
    }
  }

  async function loadStripeFinance() {
    if (!token) return;
    setStripeFinanceLoading(true);
    setStripeFinanceError(null);
    try {
      const d = await apiFetch<StripeFinanceSummaryLite>("/admin/billing/stripe-finance", { method: "GET", token });
      setStripeFinance(d);
    } catch (e: any) {
      setStripeFinanceError(e?.message || "Failed to load Stripe finance");
    } finally {
      setStripeFinanceLoading(false);
    }
  }

  async function loadSystem() {
    if (!token) return;
    setSysLoading(true);
    setSysError(null);
    try {
      const d = await apiFetch<SystemHealthLite>("/admin/system-health", { method: "GET", token });
      setSys(d);
      setSysLastAt(Date.now());
    } catch (e: any) {
      setSysError(e?.message || "Failed to load system health");
    } finally {
      setSysLoading(false);
    }
  }

  async function loadAds() {
    if (!token) return;
    setAdsLoading(true);
    setAdsError(null);
    try {
      const [active, campaigns] = await Promise.all([
        apiFetch<AdCampaign | null>("/ads/active", { method: "GET", token }),
        apiFetch<AdCampaign[]>("/ads/campaigns", { method: "GET", token }),
      ]);

      setAdsActive(active || null);
      setAdsCampaigns(Array.isArray(campaigns) ? campaigns : []);
    } catch (e: any) {
      const msg = e?.message || "Failed to load ads";
      setAdsError(msg);
    } finally {
      setAdsLoading(false);
    }
  }

  async function setCampaignActive(campaignId: string, active: boolean) {
    if (!token) return;
    setAdsBusyId(campaignId);
    setAdsError(null);
    try {
      await apiFetch(`/ads/campaigns/${encodeURIComponent(campaignId)}/active`, {
        method: "POST",
        token,
        body: { active },
      });
      toast.success(active ? "Campaign activated" : "Campaign deactivated");
      await loadAds();
    } catch (e: any) {
      const msg = e?.message || "Action failed";
      setAdsError(msg);
      toast.error("Ads action failed", msg);
    } finally {
      setAdsBusyId(null);
    }
  }

  async function createCampaign() {
    if (!token) return;
    setAdsBusyId("create");
    setAdsError(null);
    try {
      await apiFetch("/ads/campaigns", {
        method: "POST",
        token,
        body: {
          advertiserName: adAdvertiserName,
          title: adTitle,
          description: adDescription,
          imageUrl: adImageUrl,
          videoUrl: adVideoUrl,
          clickUrl: adClickUrl,
          ctaLabel: adCtaLabel,
          active: false,
          frequency: Number(adFrequency || 5),
          impressionValueCents: Number(adImpressionValue || 1),
        },
      });
      toast.success("Campaign created");
      setAdsCreateOpen(false);
      await loadAds();
    } catch (e: any) {
      const msg = e?.message || "Create failed";
      setAdsError(msg);
      toast.error("Create failed", msg);
    } finally {
      setAdsBusyId(null);
    }
  }

  useEffect(() => {
    if (!token) {
      router.replace("/login");
      return;
    }

    let alive = true;
    (async () => {
      setLoading(true);
      setError(null);
      try {
        const d = await apiFetch<AdminDashboardData>("/admin/dashboard", {
          method: "GET",
          token,
        });
        if (!alive) return;
        setData(d);
        setDashLastAt(Date.now());

        const b = d?.dashboard?.buildStatus;
        setTsQueued((prev) => pushSample(prev, Number(b?.queued ?? 0)));
        setTsRunning((prev) => pushSample(prev, Number(b?.running ?? 0)));
        setTsFailed((prev) => pushSample(prev, Number(b?.failed ?? 0)));
      } catch (e: any) {
        if (!alive) return;
        const msg = e?.message || "Failed to load dashboard";
        setError(msg);
        if (e instanceof ApiError && (e.status === 401 || e.status === 403)) {
          clearToken();
        }
      } finally {
        if (alive) setLoading(false);
      }
    })();

    return () => {
      alive = false;
    };
  }, [router, token]);

  useEffect(() => {
    loadAds();
    loadPlatformDistribution();
    loadLeaderboard();
    loadUserGrowth();
    loadErrorLog();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [token]);

  useEffect(() => {
    loadTemplateUsage();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [token]);

  useEffect(() => {
    loadFeedIntel();
    const t = setInterval(() => {
      loadFeedIntel();
    }, 30000);
    return () => clearInterval(t);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [token]);

  useEffect(() => {
    loadSystem();
    const t = setInterval(() => {
      loadSystem();
    }, 10000);
    return () => clearInterval(t);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [token]);

  useEffect(() => {
    loadBilling();
    loadStripeFinance();
    const t = setInterval(() => {
      loadBilling();
      loadStripeFinance();
    }, 30000);
    return () => clearInterval(t);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [token]);

  useEffect(() => {
    loadDashboardTelemetry();
    const t = setInterval(() => {
      loadDashboardTelemetry();
    }, 8000);
    return () => clearInterval(t);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [token]);

  useEffect(() => {
    if (!token) return;
    if (loading) return;
    const t = setTimeout(() => {
      loadAiOpsBrief(buildMetricsContext());
    }, 350);
    return () => clearTimeout(t);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [token, loading]);

  useEffect(() => {
    const t = setInterval(() => setNow(Date.now()), 1000);
    return () => clearInterval(t);
  }, []);

  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === "?" || (e.shiftKey && e.key === "/")) {
        setShortcutsOpen((v) => !v);
      }
      if (e.key === "Escape") {
        setShortcutsOpen(false);
      }
    };
    window.addEventListener("keydown", handleKeyDown);
    return () => window.removeEventListener("keydown", handleKeyDown);
  }, []);

  const systemStatus = (data?.dashboard?.systemStatus || "unknown").toString();
  const statusPill =
    systemStatus.toLowerCase() === "healthy"
      ? "bg-emerald-500/15 text-emerald-200 border-emerald-400/20"
      : "bg-amber-500/15 text-amber-200 border-amber-400/20";

  const builds = data?.dashboard?.buildStatus;
  const buildsSummary = loading
    ? "—"
    : `Q:${builds?.queued ?? 0}  R:${builds?.running ?? 0}  OK:${builds?.ready ?? 0}  F:${builds?.failed ?? 0}`;

  const templates = data?.dashboard?.templates;
  const templatesSummary = loading
    ? "—"
    : `All:${templates?.total ?? 0}  Public:${templates?.public ?? 0}  Private:${templates?.private ?? 0}`;

  const buildTotal = (builds?.queued ?? 0) + (builds?.running ?? 0) + (builds?.ready ?? 0) + (builds?.failed ?? 0);
  const templateTotal = templates?.total ?? 0;

  const uptime = Number(sys?.runtime?.uptimeSeconds || 0);
  const uptimeStr = uptime ? `${Math.floor(uptime / 3600)}h ${Math.floor((uptime % 3600) / 60)}m` : "—";
  const sysStatus = (sys?.status || "unknown").toString().toLowerCase();
  const sysPill =
    sysStatus === "healthy"
      ? "border-emerald-400/20 bg-emerald-500/10 text-emerald-200"
      : "border-amber-400/20 bg-amber-500/10 text-amber-200";

  const lastPulseAgo = sysLoading
    ? "syncing…"
    : sysLastAt
      ? `${Math.max(0, Math.floor((now - sysLastAt) / 1000))}s`
      : "—";

  const lastDashAgo = telemetryLoading
    ? "syncing…"
    : dashLastAt
      ? `${Math.max(0, Math.floor((now - dashLastAt) / 1000))}s`
      : "—";

  const heapMb = Number(sys?.memory?.heapUsed || 0) / (1024 * 1024);
  useEffect(() => {
    setTsHeapMb((prev) => pushSample(prev, Math.round(heapMb * 10) / 10));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [sys?.memory?.heapUsed]);

  const ready = Number(builds?.ready ?? 0);
  const failed = Number(builds?.failed ?? 0);
  const successRate = ready + failed > 0 ? Math.round((ready / (ready + failed)) * 100) : 0;
  const queuePressure = buildTotal > 0 ? Math.round(((Number(builds?.queued ?? 0) + Number(builds?.running ?? 0)) / buildTotal) * 100) : 0;

  const totalUsers = Number(data?.dashboard?.totalUsers ?? 0);
  const bannedUsers = Number(data?.dashboard?.inactiveUsers ?? 0);
  const bannedRate = totalUsers ? Math.round((bannedUsers / totalUsers) * 100) : 0;

  const publicTemplates = Number(templates?.public ?? 0);
  const templatePublicRate = templateTotal ? Math.round((publicTemplates / templateTotal) * 100) : 0;

  const memTotal = Number(sys?.memory?.systemTotal ?? 0);
  const memFree = Number(sys?.memory?.systemFree ?? 0);
  const memUsed = Math.max(0, memTotal - memFree);
  const memFreeRate = memTotal ? Math.round((memFree / memTotal) * 100) : 0;
  const heapRate = memTotal ? Math.round((Number(sys?.memory?.heapUsed ?? 0) / memTotal) * 100) : 0;

  const adsTotal = adsCampaigns.length;
  const adsActiveCount = adsCampaigns.filter((c) => Boolean(c?.active)).length;
  const adsActiveRate = adsTotal ? Math.round((adsActiveCount / adsTotal) * 100) : 0;

  // Composite Health Score (0-100)
  const healthScore = useMemo(() => {
    if (loading) return 0;
    let score = 100;
    // System health
    if (sysStatus !== "healthy") score -= 15;
    // Build success rate
    if (successRate < 80) score -= Math.round((80 - successRate) * 0.3);
    // Queue pressure
    if (queuePressure > 60) score -= Math.round((queuePressure - 60) * 0.2);
    // Memory pressure
    if (memFreeRate < 20) score -= Math.round((20 - memFreeRate) * 0.5);
    if (heapRate > 30) score -= Math.round((heapRate - 30) * 0.3);
    // Banned users
    if (bannedRate > 10) score -= Math.round((bannedRate - 10) * 0.5);
    // Failed builds
    if (Number(builds?.failed ?? 0) > 5) score -= Math.min(10, Number(builds?.failed ?? 0));
    return Math.max(0, Math.min(100, score));
  }, [loading, sysStatus, successRate, queuePressure, memFreeRate, heapRate, bannedRate, builds?.failed]);

  const tplUsageTotal = tplUsage.reduce((acc, r) => acc + Number(r.count || 0), 0);
  const tplUsageMax = Math.max(1, ...tplUsage.map((r) => Number(r.count || 0)));

  const feedMaxScore = Math.max(1, ...feedTop.map((r) => Number(feedMode === "hot" ? r.hotScore : r.score) || 0));

  const displayName = (data?.user?.username || data?.user?.email || "Admin").toString();
  const avatarText = displayName
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((s) => s[0]?.toUpperCase() || "")
    .join("")
    .slice(0, 2);

  const notifications = (
    [
      sysStatus !== "healthy"
        ? { tone: "amber" as const, title: "System degraded", body: `Status: ${sys?.status || "unknown"}`, href: "/system" }
        : null,
      Number(builds?.failed ?? 0) > 0
        ? { tone: "amber" as const, title: "Build failures", body: `Failed builds: ${Number(builds?.failed ?? 0)}`, href: "/builds" }
        : null,
      billingError
        ? { tone: "amber" as const, title: "Billing fetch issue", body: billingError, href: "/billing" }
        : null,
      adsError
        ? { tone: "amber" as const, title: "Ads fetch issue", body: adsError, href: "/dashboard" }
        : null,
      bannedUsers > 0
        ? { tone: "zinc" as const, title: "Banned users", body: `${bannedUsers} inactive accounts (${bannedRate}%)`, href: "/users?active=0" }
        : null,
      tplUsage.length > 0
        ? {
          tone: "cyan" as const,
          title: "Template leader",
          body: `Top: ${tplUsage[0]?.name || "—"} • ${tplUsage[0]?.count || 0} games`,
          href: "/templates",
        }
        : null,
      feedTop.length > 0
        ? {
          tone: "cyan" as const,
          title: "Feed is active",
          body: `Top game: ${feedTop[0]?.title || "—"} • ${feedMode === "hot" ? "hot" : "score"}: ${feedMode === "hot" ? feedTop[0]?.hotScore || 0 : feedTop[0]?.score || 0
            }`,
          href: "/dashboard",
        }
        : null,
    ].filter(Boolean) as Array<{ tone: "cyan" | "amber" | "emerald" | "zinc"; title: string; body: string; href: string }>
  ).slice(0, 6);

  const unreadCount = notifications.filter((n) => n.tone === "amber").length;

  function avgLast(arr: number[], window: number) {
    const a = arr.slice(Math.max(0, arr.length - window));
    if (!a.length) return 0;
    return a.reduce((s, v) => s + Number(v || 0), 0) / a.length;
  }

  function last(arr: number[]) {
    return arr.length ? Number(arr[arr.length - 1] || 0) : 0;
  }

  const anomalies = (() => {
    const out: Array<{ tone: "emerald" | "amber" | "cyan"; title: string; body: string; href: string }> = [];
    const qNow = last(tsQueued);
    const qAvg = avgLast(tsQueued.slice(0, -1), 8) || avgLast(tsQueued, 8);
    if (tsQueued.length >= 6 && qNow > Math.max(3, qAvg * 1.8)) {
      out.push({ tone: "amber", title: "Queue spike", body: `Queued jumped to ${qNow} (avg ${qAvg.toFixed(1)})`, href: "/builds" });
    }

    const fNow = last(tsFailed);
    const fAvg = avgLast(tsFailed.slice(0, -1), 8) || avgLast(tsFailed, 8);
    if (tsFailed.length >= 6 && fNow > Math.max(2, fAvg * 1.8)) {
      out.push({ tone: "amber", title: "Failures spike", body: `Failed jumped to ${fNow} (avg ${fAvg.toFixed(1)})`, href: "/builds" });
    }

    const heapNow = last(tsHeapMb);
    const heapAvg = avgLast(tsHeapMb.slice(0, -1), 8) || avgLast(tsHeapMb, 8);
    if (tsHeapMb.length >= 6 && heapNow > heapAvg * 1.25 && heapNow - heapAvg > 12) {
      out.push({ tone: "cyan", title: "Heap rising", body: `Heap ${heapNow.toFixed(1)} MB (avg ${heapAvg.toFixed(1)} MB)`, href: "/system" });
    }

    const mrrNow = last(tsMrr);
    const mrrAvg = avgLast(tsMrr.slice(0, -1), 8) || avgLast(tsMrr, 8);
    if (tsMrr.length >= 6 && Math.abs(mrrNow - mrrAvg) > Math.max(50, mrrAvg * 0.15)) {
      out.push({ tone: "cyan", title: "MRR changed", body: `MRR ${mrrNow.toFixed(0)} (avg ${mrrAvg.toFixed(0)})`, href: "/billing" });
    }

    if (!out.length) {
      out.push({ tone: "emerald", title: "No anomalies", body: "Signals are within normal range.", href: "/dashboard" });
    }
    return out.slice(0, 4);
  })();

  return (
    <AdminShell
      title="Dashboard"
      right={
        <div className="flex flex-wrap items-center gap-4">
          <NeonChip tone={systemStatus.toLowerCase() === "healthy" ? "emerald" : "amber"}>
            <PulseDot tone={systemStatus.toLowerCase() === "healthy" ? "emerald" : "amber"} />
            <span className="font-mono">SYS</span>
            <span className="text-white">{systemStatus}</span>
          </NeonChip>

          <div className="relative">
            <button
              type="button"
              onClick={() => setNotifOpen((v) => !v)}
              className="gf-btn relative h-9 rounded-xl px-3 text-sm"
              aria-label="Notifications"
            >
              <span className="font-mono">NOTIFS</span>
              {unreadCount > 0 ? (
                <span className="absolute -right-1 -top-1 inline-flex h-5 min-w-5 items-center justify-center rounded-full border border-cyan-400/30 bg-cyan-500/25 px-1.5 text-[11px] font-semibold text-cyan-100">
                  {unreadCount}
                </span>
              ) : null}
            </button>

            {notifOpen ? (
              <div className="absolute right-0 z-40 mt-2 w-[320px] overflow-hidden rounded-2xl border border-white/10 bg-black/80 shadow-[0_20px_80px_rgba(0,0,0,0.65)] backdrop-blur">
                <div className="flex items-center justify-between border-b border-white/10 px-3 py-2">
                  <div className="text-xs font-semibold text-zinc-200">Notifications</div>
                  <button className="text-xs text-zinc-400 hover:text-white" onClick={() => setNotifOpen(false)} type="button">
                    Close
                  </button>
                </div>
                <div className="max-h-[280px] overflow-auto p-2">
                  {notifications.length === 0 ? (
                    <div className="rounded-xl border border-white/10 bg-white/5 px-3 py-2 text-xs text-zinc-400">All clear.</div>
                  ) : (
                    notifications.map((n, i) => (
                      <button
                        key={i}
                        className="w-full rounded-xl border border-transparent px-3 py-2 text-left transition hover:border-white/10 hover:bg-white/5"
                        onClick={() => {
                          setNotifOpen(false);
                          router.push(n.href);
                        }}
                        type="button"
                      >
                        <div className="flex items-start justify-between gap-3">
                          <div className="min-w-0">
                            <div className="flex items-center gap-2">
                              <span
                                className={cx(
                                  "h-2 w-2 rounded-full",
                                  n.tone === "amber"
                                    ? "bg-amber-300"
                                    : n.tone === "cyan"
                                      ? "bg-cyan-300"
                                      : n.tone === "emerald"
                                        ? "bg-emerald-300"
                                        : "bg-zinc-500",
                                )}
                              />
                              <div className="truncate text-xs font-semibold text-white">{n.title}</div>
                            </div>
                            <div className="mt-1 line-clamp-2 text-[11px] text-zinc-400">{n.body}</div>
                          </div>
                          <div className="shrink-0 text-[11px] text-zinc-500">open</div>
                        </div>
                      </button>
                    ))
                  )}
                </div>
              </div>
            ) : null}
          </div>

          <div className="hidden sm:flex items-center gap-2 rounded-full border border-white/10 bg-black/20 px-2 py-1">
            <div className="h-7 w-7 rounded-full bg-gradient-to-br from-blue-500/40 via-cyan-500/30 to-cyan-500/30 ring-1 ring-white/10 grid place-items-center text-[11px] font-extrabold text-white">
              {loading ? "—" : avatarText || "A"}
            </div>
            <div className="min-w-0">
              <div className="truncate text-[11px] font-semibold text-white">{loading ? "—" : displayName}</div>
              <div className="truncate text-[11px] text-zinc-500">{(data?.user?.role || "admin").toString()}</div>
            </div>
          </div>
        </div>
      }
    >
      <div className="gf-card relative overflow-hidden rounded-3xl border border-white/10 p-6">
        <div className="pointer-events-none absolute inset-0">
          <div
            className="absolute inset-0 opacity-60"
            style={{
              backgroundImage:
                "radial-gradient(circle at 18% 0%, rgba(34,211,238,0.28), transparent 55%), radial-gradient(circle at 82% 100%, rgba(236,72,153,0.22), transparent 55%)",
            }}
          />
          <div className="absolute inset-0 opacity-20" style={{ backgroundImage: "repeating-linear-gradient(to bottom, rgba(255,255,255,0.10), rgba(255,255,255,0.10) 1px, transparent 1px, transparent 7px)" }} />
          <div className="absolute inset-0 opacity-30" style={{ backgroundImage: "linear-gradient(to right, rgba(34,211,238,0.06), transparent 22%, transparent 78%, rgba(236,72,153,0.06))" }} />
        </div>
        <div className="pointer-events-none absolute -left-28 -top-24 h-80 w-80 rounded-full bg-cyan-500/20 blur-3xl" />
        <div className="pointer-events-none absolute -right-28 -bottom-24 h-80 w-80 rounded-full bg-cyan-500/20 blur-3xl" />
        <div className="relative flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <NeonChip tone="cyan">
              <PulseDot tone="cyan" />
              GAMEFORGE CONTROL ROOM
              <span className="text-zinc-500">•</span>
              <span className="font-mono text-zinc-300">LIVE</span>
            </NeonChip>
            <div className="mt-3 text-3xl font-semibold tracking-tight text-white">Admin Overview</div>
            <div className="mt-1 text-sm text-zinc-400">Gaming platform ops: users, builds, templates, ads.</div>
          </div>

          <div className="flex flex-wrap items-center gap-4">
            <button className="gf-btn rounded-xl px-3 py-2 text-sm" onClick={() => router.refresh()}>
              Refresh
            </button>
            <button className="gf-btn rounded-xl px-3 py-2 text-sm flex items-center gap-2" onClick={generatePDFReport}>
              <span>📄</span>
              <span>Export PDF</span>
            </button>
            <button className="gf-btn rounded-xl px-3 py-2 text-sm" onClick={loadAds}>
              Refresh ads
            </button>
            <button className="gf-btn rounded-xl px-3 py-2 text-sm" onClick={() => setAdsCreateOpen(true)}>
              Create ad
            </button>
          </div>
        </div>
      </div>

      <div className="gf-card group relative mt-4 overflow-hidden rounded-2xl border border-white/10 p-5">
        <div className="pointer-events-none absolute -right-10 -top-10 h-56 w-56 rounded-full bg-emerald-500/10 blur-3xl" />
        <div className="pointer-events-none absolute -left-10 -bottom-10 h-56 w-56 rounded-full bg-cyan-500/10 blur-3xl" />
        <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
          <div>
            <div className="text-xs font-medium text-zinc-400">Money</div>
            <h2 className="mt-1 text-base font-semibold text-zinc-100">Stripe finance</h2>
            <div className="mt-1 text-xs text-zinc-500">real balance + volume + payouts</div>
          </div>
          <NeonChip tone="zinc">
            <span className="font-mono">BAL</span>
            <span className="text-white">{stripeFinanceLoading ? "…" : `$${Number(stripeFinance?.balance?.totalUsd ?? 0).toFixed(2)}`}</span>
          </NeonChip>
        </div>

        {stripeFinanceError ? (
          <div className="mt-3 rounded-xl border border-red-400/20 bg-red-500/10 px-3 py-2 text-xs text-red-200">{stripeFinanceError}</div>
        ) : null}

        <div className="mt-4 grid grid-cols-2 gap-2 text-[11px] text-zinc-400 sm:grid-cols-4">
          <div className="rounded-xl border border-white/10 bg-black/20 px-3 py-2">
            <div className="text-zinc-500">Available</div>
            <div className="mt-1 text-sm font-semibold text-white">{stripeFinanceLoading ? "—" : `$${Number(stripeFinance?.balance?.availableUsd ?? 0).toFixed(2)}`}</div>
          </div>
          <div className="rounded-xl border border-white/10 bg-black/20 px-3 py-2">
            <div className="text-zinc-500">Pending</div>
            <div className="mt-1 text-sm font-semibold text-white">{stripeFinanceLoading ? "—" : `$${Number(stripeFinance?.balance?.pendingUsd ?? 0).toFixed(2)}`}</div>
          </div>
          <div className="rounded-xl border border-white/10 bg-black/20 px-3 py-2">
            <div className="text-zinc-500">Gross today</div>
            <div className="mt-1 text-sm font-semibold text-white">{stripeFinanceLoading ? "—" : `$${Number(stripeFinance?.grossVolume?.todayUsd ?? 0).toFixed(2)}`}</div>
          </div>
          <div className="rounded-xl border border-white/10 bg-black/20 px-3 py-2">
            <div className="text-zinc-500">Payouts today</div>
            <div className="mt-1 text-sm font-semibold text-white">{stripeFinanceLoading ? "—" : `$${Number(stripeFinance?.payouts?.todayUsd ?? 0).toFixed(2)}`}</div>
          </div>
        </div>
      </div>

      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <StatCard
          label="Total Users"
          value={loading ? "—" : `${data?.dashboard?.totalUsers ?? "—"}`}
          hint={loading ? "All registered accounts" : `Banned: ${data?.dashboard?.inactiveUsers ?? 0}`}
          accentClass="bg-gradient-to-br from-blue-500/40 to-blue-300/10"
        />
        <StatCard
          label="Active Projects"
          value={loading ? "—" : `${data?.dashboard?.activeProjects ?? "—"}`}
          hint="Queued + running"
          accentClass="bg-gradient-to-br from-cyan-500/40 to-cyan-300/10"
        />
        <StatCard
          label="Builds"
          value={buildsSummary}
          hint="Q/R/OK/F"
          accentClass="bg-gradient-to-br from-cyan-500/40 to-cyan-300/10"
        />
        <StatCard
          label="Templates"
          value={templatesSummary}
          hint="All/Public/Private"
          accentClass="bg-gradient-to-br from-amber-500/35 to-amber-300/10"
        />
      </div>

      <div className="mt-4 grid grid-cols-1 gap-4 lg:grid-cols-3">
        <div className="gf-card group relative overflow-hidden rounded-2xl border border-white/10 p-5 lg:col-span-2">
          <div className="pointer-events-none absolute -left-24 -top-24 h-80 w-80 rounded-full bg-cyan-500/15 blur-3xl" />
          <div className="pointer-events-none absolute -right-24 -bottom-24 h-80 w-80 rounded-full bg-cyan-500/12 blur-3xl" />
          <div className="flex items-start justify-between gap-3">
            <div>
              <div className="text-xs font-medium text-zinc-400">Charts</div>
              <h2 className="mt-1 text-sm font-semibold text-zinc-100">Ops waves</h2>
              <div className="mt-1 text-xs text-zinc-500">Running vs Failed (last samples)</div>
            </div>
            <NeonChip tone="zinc">
              <span className="font-mono">LAST</span>
              <span className="text-white">{lastDashAgo}</span>
            </NeonChip>
          </div>
          <div className="mt-4 rounded-2xl border border-white/10 bg-black/20 p-3">
            <AreaWavesChart
              a={tsRunning}
              b={tsFailed}
              aStrokeClass="stroke-cyan-300/85"
              bStrokeClass="stroke-cyan-300/80"
              aFillId="opsA"
              bFillId="opsB"
            />
          </div>
          <div className="mt-3 grid grid-cols-2 gap-2 sm:grid-cols-4">
            <div className="rounded-xl border border-white/10 bg-black/20 px-3 py-2">
              <div className="text-xs text-zinc-400">Queued</div>
              <div className="mt-1 text-sm font-semibold text-white">{Number(builds?.queued ?? 0)}</div>
            </div>
            <div className="rounded-xl border border-white/10 bg-black/20 px-3 py-2">
              <div className="text-xs text-zinc-400">Running</div>
              <div className="mt-1 text-sm font-semibold text-white">{Number(builds?.running ?? 0)}</div>
            </div>
            <div className="rounded-xl border border-white/10 bg-black/20 px-3 py-2">
              <div className="text-xs text-zinc-400">Ready</div>
              <div className="mt-1 text-sm font-semibold text-white">{Number(builds?.ready ?? 0)}</div>
            </div>
            <div className="rounded-xl border border-white/10 bg-black/20 px-3 py-2">
              <div className="text-xs text-zinc-400">Failed</div>
              <div className="mt-1 text-sm font-semibold text-white">{Number(builds?.failed ?? 0)}</div>
            </div>
          </div>
        </div>

        <div className="gf-card group relative overflow-hidden rounded-2xl border border-white/10 p-5">
          <div className="pointer-events-none absolute -right-14 -top-10 h-44 w-44 rounded-full bg-emerald-500/10 blur-3xl" />
          <div className="flex items-start justify-between">
            <div>
              <div className="text-xs font-medium text-zinc-400">Charts</div>
              <h2 className="mt-1 text-sm font-semibold text-zinc-100">System radar</h2>
              <div className="mt-1 text-xs text-zinc-500">Signals snapshot</div>
            </div>
            <NeonChip tone={sysStatus === "healthy" ? "emerald" : "amber"}>
              <PulseDot tone={sysStatus === "healthy" ? "emerald" : "amber"} />
              <span className="font-mono">SYS</span>
              <span className="text-white">{sysLoading ? "…" : sys?.status || "—"}</span>
            </NeonChip>
          </div>
          <div className="mt-4 rounded-2xl border border-white/10 bg-black/20 p-3">
            <RadarChart
              tone={successRate >= 80 ? "emerald" : successRate >= 50 ? "amber" : "cyan"}
              labels={["Success", "Free mem", "Low heap", "Low queue", "Ads active"]}
              values01={[
                (loading ? 0 : successRate) / 100,
                (sysLoading ? 0 : memFreeRate) / 100,
                1 - (sysLoading ? 0 : heapRate) / 100,
                1 - (loading ? 0 : queuePressure) / 100,
                (adsLoading ? 0 : adsActiveRate) / 100,
              ]}
            />
          </div>
        </div>
      </div>

      <div className="mt-4 gf-card group relative overflow-hidden rounded-2xl border border-white/10 p-5">
        <div className="pointer-events-none absolute -right-10 -top-10 h-44 w-44 rounded-full bg-amber-500/10 blur-3xl" />
        <div className="pointer-events-none absolute -left-14 -bottom-14 h-52 w-52 rounded-full bg-cyan-500/10 blur-3xl" />
        <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
          <div>
            <div className="text-xs font-medium text-zinc-400">Templates intelligence</div>
            <h2 className="mt-1 text-sm font-semibold text-zinc-100">Top templates used in games</h2>
            <div className="mt-1 text-xs text-zinc-500">Derived from projects → templateId</div>
          </div>
          <div className="flex flex-wrap items-center gap-2">
            <NeonChip tone="amber">
              <span className="font-mono">SAMPLES</span>
              <span className="text-white">{tplUsageLoading ? "…" : String(tplUsageTotal)}</span>
            </NeonChip>
            <button className="gf-btn rounded-xl px-3 py-2 text-xs" onClick={loadTemplateUsage}>
              Refresh
            </button>
          </div>
        </div>

        {tplUsageError ? (
          <div className="mt-3 rounded-xl border border-red-400/20 bg-red-500/10 px-3 py-2 text-xs text-red-200">{tplUsageError}</div>
        ) : null}

        <div className="mt-4 rounded-2xl border border-white/10 bg-black/20 p-4">
          <div className="flex items-center justify-between">
            <div className="text-xs text-zinc-400">Usage distribution</div>
            <div className="text-[11px] text-zinc-500">Top 8</div>
          </div>

          <div className="mt-3 flex h-40 items-end gap-2">
            {(tplUsageLoading
              ? Array.from({ length: 8 }).map((_, i) => ({ templateId: String(i), name: "…", count: 0 }))
              : tplUsage.slice(0, 8)
            ).map((r) => {
              const h01 = tplUsageMax ? Number(r.count || 0) / tplUsageMax : 0;
              return (
                <div key={r.templateId} className="group relative flex h-full flex-1 flex-col justify-end">
                  <div className="relative flex-1">
                    <div
                      className={cx(
                        "absolute bottom-0 left-0 right-0 origin-bottom rounded-t-xl border border-white/10 bg-gradient-to-b from-amber-400/45 via-cyan-400/25 to-cyan-300/15 shadow-[0_-10px_40px_rgba(34,211,238,0.12)] transition-transform duration-700 ease-out",
                        tplUsageLoading
                          ? "animate-pulse"
                          : tplBarsOn
                            ? "scale-y-100 group-hover:-translate-y-0.5"
                            : "scale-y-0",
                      )}
                      style={{ height: `${Math.max(6, Math.min(100, h01 * 100))}%` }}
                    />
                    <div className="pointer-events-none absolute inset-x-0 top-0 hidden -translate-y-2 px-2 opacity-0 transition group-hover:block group-hover:opacity-100">
                      <div className="rounded-xl border border-white/10 bg-black/70 px-2 py-1 text-[11px] text-zinc-200">
                        <div className="truncate font-semibold text-white">{r.name}</div>
                        <div className="text-zinc-400">{tplUsageLoading ? "—" : `${r.count} games`}</div>
                      </div>
                    </div>
                  </div>
                </div>
              );
            })}
          </div>

          <div className="mt-3 grid grid-cols-2 gap-2 sm:grid-cols-4">
            {(tplUsageLoading
              ? Array.from({ length: 4 }).map((_, i) => ({ templateId: String(i), name: "…", count: 0 }))
              : tplUsage.slice(0, 4)
            ).map((r, i) => (
              <div key={r.templateId} className="rounded-xl border border-white/10 bg-black/30 px-3 py-2">
                <div className="flex items-center justify-between gap-2">
                  <span className="truncate text-xs font-semibold text-white">{r.name}</span>
                  <span className="rounded-md border border-white/10 bg-black/40 px-1.5 py-0.5 text-[11px] text-zinc-300">#{i + 1}</span>
                </div>
                <div className="mt-1 text-xs text-zinc-500">{tplUsageLoading ? "—" : `${r.count} games`}</div>
              </div>
            ))}
          </div>

          {!tplUsageLoading && tplUsage.length === 0 ? (
            <div className="mt-3 rounded-xl border border-white/10 bg-black/20 px-3 py-2 text-xs text-zinc-400">No projects with templates found.</div>
          ) : null}
        </div>
      </div>

      <div className="mt-4 gf-card group relative overflow-hidden rounded-2xl border border-white/10 p-5">
        <div className="pointer-events-none absolute -right-24 -top-24 h-80 w-80 rounded-full bg-cyan-500/10 blur-3xl" />
        <div className="pointer-events-none absolute -left-24 -bottom-24 h-80 w-80 rounded-full bg-cyan-500/10 blur-3xl" />
        <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
          <div>
            <div className="text-xs font-medium text-zinc-400">Feed intelligence</div>
            <h2 className="mt-1 text-sm font-semibold text-zinc-100">Top games right now</h2>
            <div className="mt-1 text-xs text-zinc-500">score = likes/comments/remix/shares + play signal</div>
          </div>
          <div className="flex flex-wrap items-center gap-2">
            <div className="flex items-center gap-2 rounded-full border border-white/10 bg-black/30 p-1">
              <button
                className={cx(
                  "rounded-full px-3 py-1 text-[11px] font-semibold tracking-wide transition",
                  feedMode === "hot" ? "bg-white/10 text-white" : "text-zinc-400 hover:text-white",
                )}
                onClick={() => setFeedMode("hot")}
                type="button"
              >
                HOT
              </button>
              <button
                className={cx(
                  "rounded-full px-3 py-1 text-[11px] font-semibold tracking-wide transition",
                  feedMode === "total" ? "bg-white/10 text-white" : "text-zinc-400 hover:text-white",
                )}
                onClick={() => setFeedMode("total")}
                type="button"
              >
                TOTAL
              </button>
            </div>
            <NeonChip tone={feedMode === "hot" ? "cyan" : "zinc"}>
              <PulseDot tone="cyan" />
              <span className="font-mono">MODE</span>
              <span className="text-white">{feedMode.toUpperCase()}</span>
            </NeonChip>
            <button className="gf-btn rounded-xl px-3 py-2 text-xs" onClick={loadFeedIntel}>
              Refresh
            </button>
          </div>
        </div>

        {feedError ? (
          <div className="mt-3 rounded-xl border border-red-400/20 bg-red-500/10 px-3 py-2 text-xs text-red-200">{feedError}</div>
        ) : null}

        <div className="mt-4 rounded-2xl border border-white/10 bg-black/20 p-4">
          <div className="flex items-center justify-between">
            <div className="text-xs text-zinc-400">Trending distribution</div>
            <div className="text-[11px] text-zinc-500">Top 8</div>
          </div>

          <div className="mt-3 flex h-40 items-end gap-2">
            {(feedLoading
              ? Array.from({ length: 8 }).map((_, i) => ({
                id: String(i),
                title: "…",
                creator: "…",
                score: 0,
                hotScore: 0,
                ageLabel: "…",
                likes: 0,
                comments: 0,
                plays: 0,
                remixes: 0,
                shares: 0,
              }))
              : feedTop.slice(0, 8)
            ).map((r, idx) => {
              const v = Number(feedMode === "hot" ? r.hotScore : r.score) || 0;
              const h01 = feedMaxScore ? v / feedMaxScore : 0;
              return (
                <div key={r.id} className="group relative flex h-full flex-1 flex-col justify-end">
                  <div className="relative flex-1">
                    <div
                      className={cx(
                        "absolute bottom-0 left-0 right-0 origin-bottom rounded-t-xl border border-white/10 bg-gradient-to-b shadow-[0_-10px_40px_rgba(236,72,153,0.10)] transition-transform duration-700 ease-out",
                        idx % 2 === 0
                          ? "from-cyan-400/45 via-blue-400/25 to-cyan-300/15"
                          : "from-cyan-400/35 via-cyan-400/20 to-blue-300/15",
                        feedLoading
                          ? "animate-pulse"
                          : feedBarsOn
                            ? "scale-y-100 group-hover:-translate-y-0.5"
                            : "scale-y-0",
                      )}
                      style={{ height: `${Math.max(6, Math.min(100, h01 * 100))}%` }}
                    />
                    <div className="pointer-events-none absolute inset-x-0 top-0 hidden -translate-y-2 px-2 opacity-0 transition group-hover:block group-hover:opacity-100">
                      <div className="rounded-xl border border-white/10 bg-black/70 px-2 py-1 text-[11px] text-zinc-200">
                        <div className="flex items-center justify-between gap-2">
                          <div className="truncate font-semibold text-white">#{idx + 1} {r.title}</div>
                          <div className="shrink-0 text-zinc-400">{r.ageLabel}</div>
                        </div>
                        <div className="mt-0.5 text-zinc-400">by {r.creator}</div>
                        <div className="mt-0.5 text-zinc-400">{feedMode === "hot" ? "hot" : "score"}: {feedLoading ? "—" : String(v)}</div>
                      </div>
                    </div>
                  </div>
                </div>
              );
            })}
          </div>

          <div className="mt-3 grid grid-cols-1 gap-2 sm:grid-cols-2">
            {(feedLoading ? Array.from({ length: 4 }).map((_, i) => ({
              id: String(i),
              title: "…",
              creator: "…",
              score: 0,
              hotScore: 0,
              ageLabel: "…",
              likes: 0,
              comments: 0,
              plays: 0,
              remixes: 0,
              shares: 0,
            })) : feedTop.slice(0, 4)).map((r, i) => {
              const v = Number(feedMode === "hot" ? r.hotScore : r.score) || 0;
              return (
                <div key={r.id} className="rounded-xl border border-white/10 bg-black/30 px-3 py-2">
                  <div className="flex items-start justify-between gap-3">
                    <div className="min-w-0">
                      <div className="flex items-center gap-2">
                        <span className="rounded-md border border-white/10 bg-black/40 px-1.5 py-0.5 text-[11px] text-zinc-300">#{i + 1}</span>
                        <span className="truncate text-xs font-semibold text-white">{r.title}</span>
                        <span className="rounded-full border border-white/10 bg-black/40 px-2 py-0.5 text-[11px] text-zinc-400">{r.ageLabel}</span>
                      </div>
                      <div className="mt-1 truncate text-[11px] text-zinc-500">by {r.creator}</div>
                      <div className="mt-2 flex flex-wrap items-center gap-1.5 text-[11px] text-zinc-400">
                        <span className="rounded-full border border-white/10 bg-black/40 px-2 py-0.5">❤ {feedLoading ? "—" : String(r.likes)}</span>
                        <span className="rounded-full border border-white/10 bg-black/40 px-2 py-0.5">💬 {feedLoading ? "—" : String(r.comments)}</span>
                        <span className="rounded-full border border-white/10 bg-black/40 px-2 py-0.5">▶ {feedLoading ? "—" : String(r.plays)}</span>
                        <span className="rounded-full border border-white/10 bg-black/40 px-2 py-0.5">⟲ {feedLoading ? "—" : String(r.remixes)}</span>
                      </div>
                    </div>
                    <div className="shrink-0 text-right">
                      <div className="text-sm font-semibold text-white">{feedLoading ? "—" : String(v)}</div>
                      <div className="text-[11px] text-zinc-500">{feedMode === "hot" ? "hot" : "score"}</div>
                    </div>
                  </div>
                </div>
              );
            })}
          </div>

          {!feedLoading && feedTop.length === 0 ? (
            <div className="mt-3 rounded-xl border border-white/10 bg-black/20 px-3 py-2 text-xs text-zinc-400">No feed posts found.</div>
          ) : null}
        </div>
      </div>

      <div className="mt-4 gf-card group relative overflow-hidden rounded-2xl border border-white/10 p-5">
        <div className="pointer-events-none absolute -right-24 -top-24 h-80 w-80 rounded-full bg-blue-500/10 blur-3xl" />
        <div className="pointer-events-none absolute -left-24 -bottom-24 h-80 w-80 rounded-full bg-cyan-500/10 blur-3xl" />
        <div className="flex items-start justify-between gap-3">
          <div>
            <div className="text-xs font-medium text-zinc-400">Charts</div>
            <h2 className="mt-1 text-sm font-semibold text-zinc-100">MRR vs Heap</h2>
            <div className="mt-1 text-xs text-zinc-500">Dual signal lines (approx)</div>
          </div>
          <NeonChip tone="zinc">
            <span className="font-mono">MRR</span>
            <span className="text-white">{billingLoading ? "…" : `$${Number(billing?.totals?.mrrApproxUsd ?? 0).toFixed(0)}`}</span>
          </NeonChip>
        </div>
        <div className="mt-4 rounded-2xl border border-white/10 bg-black/20 p-3">
          <DualLineChart a={tsMrr} b={tsHeapMb} aStrokeClass="stroke-cyan-300/80" bStrokeClass="stroke-emerald-300/80" />
        </div>
      </div>

      <div className="mt-4 gf-card group relative overflow-hidden rounded-2xl border border-white/10 p-5">
        <div className="pointer-events-none absolute -right-24 -top-24 h-80 w-80 rounded-full bg-cyan-500/10 blur-3xl" />
        <div className="pointer-events-none absolute -left-24 -bottom-24 h-80 w-80 rounded-full bg-cyan-500/10 blur-3xl" />
        <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
          <div>
            <div className="text-xs font-medium text-zinc-400">AI</div>
            <h2 className="mt-1 text-sm font-semibold text-zinc-100">Ops brief</h2>
            <div className="mt-1 text-xs text-zinc-500">Gemini • auto summary + recommended actions</div>
          </div>
          <div className="flex flex-wrap items-center gap-2">
            <NeonChip tone={aiError ? "amber" : aiLoading ? "cyan" : "emerald"}>
              <PulseDot tone={aiError ? "amber" : aiLoading ? "cyan" : "emerald"} />
              <span className="font-mono">AI</span>
              <span className="text-white">{aiLoading ? "thinking…" : aiError ? "degraded" : "ready"}</span>
            </NeonChip>
            <button
              className="gf-btn rounded-xl px-3 py-2 text-xs"
              onClick={() => {
                loadAiOpsBrief(buildMetricsContext());
              }}
              disabled={aiLoading}
            >
              Refresh
            </button>
            <button
              className={cx("gf-btn rounded-xl px-3 py-2 text-xs", chatOpen ? "border-white/20 bg-white/10" : "")}
              onClick={() => setChatOpen((v) => !v)}
              type="button"
            >
              Chat
            </button>
          </div>
        </div>

        {aiError ? (
          <div className="mt-3 rounded-xl border border-amber-400/20 bg-amber-500/10 px-3 py-2 text-xs text-amber-100">{aiError}</div>
        ) : null}

        <div className="mt-4 grid grid-cols-1 gap-3 lg:grid-cols-2">
          <div className="rounded-2xl border border-white/10 bg-black/20 p-4">
            <div className="text-xs font-semibold text-zinc-200">Brief</div>
            <div className="mt-2 space-y-2 text-sm">
              {aiLoading ? (
                <div className="space-y-2">
                  <div className="h-4 w-5/6 animate-pulse rounded bg-white/10" />
                  <div className="h-4 w-4/6 animate-pulse rounded bg-white/10" />
                  <div className="h-4 w-3/6 animate-pulse rounded bg-white/10" />
                </div>
              ) : aiBrief.length ? (
                aiBrief.slice(0, 5).map((b, i) => (
                  <div key={i} className="flex items-start gap-2">
                    <span className="mt-2 h-1.5 w-1.5 shrink-0 rounded-full bg-cyan-300" />
                    <div className="text-zinc-200">{b}</div>
                  </div>
                ))
              ) : (
                <div className="text-xs text-zinc-400">No brief yet.</div>
              )}
            </div>
          </div>

          <div className="rounded-2xl border border-white/10 bg-black/20 p-4">
            <div className="text-xs font-semibold text-zinc-200">Recommended actions</div>
            <div className="mt-2 space-y-2">
              {aiLoading ? (
                <div className="space-y-2">
                  <div className="h-4 w-4/6 animate-pulse rounded bg-white/10" />
                  <div className="h-4 w-5/6 animate-pulse rounded bg-white/10" />
                  <div className="h-4 w-3/6 animate-pulse rounded bg-white/10" />
                </div>
              ) : aiActions.length ? (
                aiActions.slice(0, 4).map((a, i) => (
                  <button
                    key={i}
                    className="w-full rounded-xl border border-white/10 bg-black/30 px-3 py-2 text-left transition hover:border-white/20 hover:bg-white/5"
                    onClick={() => router.push(actionHref(a.title))}
                    type="button"
                  >
                    <div className="flex items-start justify-between gap-3">
                      <div className="min-w-0">
                        <div className="text-xs font-semibold text-white">{a.title}</div>
                        <div className="mt-1 text-[11px] text-zinc-400">{a.why}</div>
                      </div>
                      <div className="shrink-0 text-[11px] text-zinc-500">open</div>
                    </div>
                  </button>
                ))
              ) : (
                <div className="text-xs text-zinc-400">No actions yet.</div>
              )}
            </div>
          </div>
        </div>

        {chatOpen ? (
          <div className="mt-3 rounded-2xl border border-white/10 bg-black/20 p-4">
            <div className="flex items-center justify-between">
              <div className="text-xs font-semibold text-zinc-200">AI chat</div>
              <div className="text-[11px] text-zinc-500">Gemini</div>
            </div>
            {chatError ? (
              <div className="mt-2 rounded-xl border border-amber-400/20 bg-amber-500/10 px-3 py-2 text-xs text-amber-100">{chatError}</div>
            ) : null}

            <div className="mt-3 max-h-[220px] space-y-2 overflow-auto rounded-2xl border border-white/10 bg-black/30 p-3">
              {chatHistory.length ? (
                chatHistory.slice(-12).map((m, i) => (
                  <div key={i} className={cx("rounded-xl px-3 py-2 text-sm", m.role === "user" ? "bg-white/5 text-zinc-100" : "bg-cyan-500/10 text-zinc-100")}>
                    <div className="text-[11px] font-semibold text-zinc-400">{m.role === "user" ? "You" : "AI"}</div>
                    <div className="mt-1 whitespace-pre-wrap text-[13px] text-zinc-200">{m.text}</div>
                  </div>
                ))
              ) : (
                <div className="text-xs text-zinc-400">Ask: "why queue pressure high?" • "what should I fix first?"</div>
              )}
              {chatLoading ? <div className="text-xs text-zinc-400">Thinking…</div> : null}
            </div>

            <div className="mt-3 flex items-center gap-2">
              <input
                value={chatInput}
                onChange={(e) => setChatInput(e.target.value)}
                placeholder="Ask ops copilot…"
                className="gf-input h-10 flex-1 rounded-xl px-3 text-sm placeholder:text-zinc-500"
                onKeyDown={(e) => {
                  if (e.key === "Enter" && !e.shiftKey) {
                    e.preventDefault();
                    if (!chatLoading) sendChat();
                  }
                }}
              />
              <button className="gf-btn h-10 rounded-xl px-3 text-sm" onClick={sendChat} disabled={chatLoading || !chatInput.trim()}>
                Send
              </button>
              <button
                className="gf-btn h-10 rounded-xl px-3 text-sm"
                onClick={() => {
                  setChatHistory([]);
                  setChatError(null);
                }}
                type="button"
              >
                Clear
              </button>
            </div>
          </div>
        ) : null}
      </div>

      <div className="mt-4 gf-card group relative overflow-hidden rounded-2xl border border-white/10 p-5">
        <div className="pointer-events-none absolute -right-24 -top-24 h-80 w-80 rounded-full bg-amber-500/10 blur-3xl" />
        <div className="pointer-events-none absolute -left-24 -bottom-24 h-80 w-80 rounded-full bg-cyan-500/10 blur-3xl" />
        <div className="flex items-start justify-between gap-3">
          <div>
            <div className="text-xs font-medium text-zinc-400">AI</div>
            <h2 className="mt-1 text-sm font-semibold text-zinc-100">Anomaly detector</h2>
            <div className="mt-1 text-xs text-zinc-500">Trends + spikes from live telemetry</div>
          </div>
          <NeonChip tone={anomalies.some((a) => a.tone === "amber" || a.tone === "cyan") ? "amber" : "emerald"}>
            <PulseDot tone={anomalies.some((a) => a.tone === "amber" || a.tone === "cyan") ? "amber" : "emerald"} />
            <span className="font-mono">ALERTS</span>
            <span className="text-white">{anomalies.filter((a) => a.tone !== "emerald").length}</span>
          </NeonChip>
        </div>

        <div className="mt-4 grid grid-cols-1 gap-2 md:grid-cols-2">
          {anomalies.map((a, i) => (
            <button
              key={i}
              className="rounded-xl border border-white/10 bg-black/20 px-3 py-3 text-left transition hover:border-white/20 hover:bg-white/5"
              onClick={() => router.push(a.href)}
              type="button"
            >
              <div className="flex items-start justify-between gap-3">
                <div className="min-w-0">
                  <div className="flex items-center gap-2">
                    <span
                      className={cx(
                        "h-2 w-2 rounded-full",
                        a.tone === "emerald" ? "bg-emerald-300" : a.tone === "amber" ? "bg-amber-300" : "bg-cyan-300",
                      )}
                    />
                    <div className="truncate text-xs font-semibold text-white">{a.title}</div>
                  </div>
                  <div className="mt-1 text-[11px] text-zinc-400">{a.body}</div>
                </div>
                <div className="shrink-0 text-[11px] text-zinc-500">open</div>
              </div>
            </button>
          ))}
        </div>
      </div>

      <div className="mt-4 grid grid-cols-1 gap-4 lg:grid-cols-3">
        <div className="gf-card group relative overflow-hidden rounded-2xl border border-white/10 p-5">
          <div className="pointer-events-none absolute -right-12 -top-12 h-40 w-40 rounded-full bg-cyan-500/10 blur-3xl" />
          <div className="flex items-start justify-between">
            <div>
              <div className="text-xs font-medium text-zinc-400">Bootstrap</div>
              <h2 className="mt-1 text-sm font-semibold text-zinc-100">Build Reactor</h2>
              <div className="mt-1 text-xs text-zinc-500">Queue state distribution</div>
            </div>
            <NeonChip tone="cyan">
              <span className="font-mono">TOTAL</span>
              <span className="text-white">{loading ? "—" : `${buildTotal}`}</span>
            </NeonChip>
          </div>
          <div className="mt-4">
            <MiniBars
              rows={[
                { label: "Queued", value: builds?.queued ?? 0, total: buildTotal, tone: "amber" },
                { label: "Running", value: builds?.running ?? 0, total: buildTotal, tone: "cyan" },
                { label: "Ready", value: builds?.ready ?? 0, total: buildTotal, tone: "emerald" },
                { label: "Failed", value: builds?.failed ?? 0, total: buildTotal, tone: "red" },
              ]}
            />
          </div>
          <div className="mt-4 flex items-center justify-end">
            <button className="gf-btn rounded-xl px-3 py-2 text-xs" onClick={() => router.push("/builds")}>
              Open reactor
            </button>
          </div>
        </div>

        <div className="gf-card group relative overflow-hidden rounded-2xl border border-white/10 p-5">
          <div className="pointer-events-none absolute -right-10 -top-10 h-40 w-40 rounded-full bg-amber-500/10 blur-3xl" />
          <div className="flex items-start justify-between">
            <div>
              <div className="text-xs font-medium text-zinc-400">Bootstrap</div>
              <h2 className="mt-1 text-sm font-semibold text-zinc-100">Template Vault</h2>
              <div className="mt-1 text-xs text-zinc-500">Visibility + counts</div>
            </div>
            <NeonChip tone="amber">
              <span className="font-mono">TOTAL</span>
              <span className="text-white">{loading ? "—" : `${templateTotal}`}</span>
            </NeonChip>
          </div>
          <div className="mt-4">
            <MiniBars
              rows={[
                { label: "Public", value: templates?.public ?? 0, total: templateTotal, tone: "emerald" },
                { label: "Private", value: templates?.private ?? 0, total: templateTotal, tone: "zinc" },
              ]}
            />
          </div>
          <div className="mt-4 flex items-center justify-end">
            <button className="gf-btn rounded-xl px-3 py-2 text-xs" onClick={() => router.push("/templates")}>
              Open vault
            </button>
          </div>
        </div>

        <div className="gf-card group relative overflow-hidden rounded-2xl border border-white/10 p-5">
          <div className="pointer-events-none absolute -right-14 -bottom-14 h-52 w-52 rounded-full bg-emerald-500/10 blur-3xl" />
          <div className="flex items-start justify-between">
            <div>
              <div className="text-xs font-medium text-zinc-400">Bootstrap</div>
              <h2 className="mt-1 text-sm font-semibold text-zinc-100">Forge Pulse</h2>
              <div className="mt-1 text-xs text-zinc-500">Live health snapshot</div>
            </div>
            <div className={`rounded-full border px-3 py-1 text-xs font-medium ${sysPill}`}>{sysLoading ? "…" : `Status: ${sys?.status || "—"}`}</div>
          </div>

          <div className="mt-3 flex items-center justify-between">
            <NeonChip tone={sysStatus === "healthy" ? "emerald" : "amber"}>
              <PulseDot tone={sysStatus === "healthy" ? "emerald" : "amber"} />
              <span className="font-mono">LAST SYNC</span>
              <span className="text-white">{lastPulseAgo}</span>
            </NeonChip>
            <NeonChip tone="zinc">
              <span className="font-mono">UPTIME</span>
              <span className="text-white">{sysLoading ? "—" : uptimeStr}</span>
            </NeonChip>
          </div>

          {sysError ? (
            <div className="mt-3 rounded-xl border border-red-400/20 bg-red-500/10 px-3 py-2 text-xs text-red-200">{sysError}</div>
          ) : null}

          <div className="mt-4 grid grid-cols-2 gap-2 text-sm">
            <div className="rounded-xl border border-white/10 bg-black/20 px-3 py-2">
              <div className="text-xs text-zinc-400">Uptime</div>
              <div className="mt-1 font-semibold text-white">{sysLoading ? "—" : uptimeStr}</div>
            </div>
            <div className="rounded-xl border border-white/10 bg-black/20 px-3 py-2">
              <div className="text-xs text-zinc-400">Heap used</div>
              <div className="mt-1 font-semibold text-white">{sysLoading ? "—" : bytes(sys?.memory?.heapUsed)}</div>
            </div>
            <div className="rounded-xl border border-white/10 bg-black/20 px-3 py-2">
              <div className="text-xs text-zinc-400">RSS</div>
              <div className="mt-1 font-semibold text-white">{sysLoading ? "—" : bytes(sys?.memory?.rss)}</div>
            </div>
            <div className="rounded-xl border border-white/10 bg-black/20 px-3 py-2">
              <div className="text-xs text-zinc-400">Disk/Memory free</div>
              <div className="mt-1 font-semibold text-white">{sysLoading ? "—" : bytes(sys?.memory?.systemFree)}</div>
            </div>
          </div>

          <div className="mt-4 flex items-center justify-end gap-2">
            <button className="gf-btn rounded-xl px-3 py-2 text-xs" onClick={loadSystem}>
              Refresh
            </button>
            <button className="gf-btn rounded-xl px-3 py-2 text-xs" onClick={() => router.push("/system")}>
              Open system
            </button>
          </div>
        </div>
      </div>

      <div className="mt-4 grid grid-cols-1 gap-4 lg:grid-cols-3">
        <div className="gf-card group relative overflow-hidden rounded-2xl border border-white/10 p-5">
          <div className="pointer-events-none absolute -right-12 -top-12 h-40 w-40 rounded-full bg-blue-500/10 blur-3xl" />
          <div className="flex items-start justify-between">
            <div>
              <div className="text-xs font-medium text-zinc-400">Analytics</div>
              <h2 className="mt-1 text-sm font-semibold text-zinc-100">Telemetry</h2>
              <div className="mt-1 text-xs text-zinc-500">Live trends (last ~4 min)</div>
            </div>
            <NeonChip tone="zinc">
              <span className="font-mono">LAST</span>
              <span className="text-white">{lastDashAgo}</span>
            </NeonChip>
          </div>

          <div className="mt-4 space-y-3">
            <div className="flex items-center justify-between rounded-2xl border border-white/10 bg-black/20 px-3 py-2">
              <div>
                <div className="text-xs font-medium text-zinc-300">Running builds</div>
                <div className="mt-0.5 text-xs text-zinc-500">trend</div>
              </div>
              <div className="flex items-center gap-3">
                <Sparkline data={tsRunning} strokeClass="stroke-cyan-300/80" />
                <div className="w-10 text-right text-sm font-semibold text-white">{Number(builds?.running ?? 0)}</div>
              </div>
            </div>

            <div className="flex items-center justify-between rounded-2xl border border-white/10 bg-black/20 px-3 py-2">
              <div>
                <div className="text-xs font-medium text-zinc-300">Failed builds</div>
                <div className="mt-0.5 text-xs text-zinc-500">trend</div>
              </div>
              <div className="flex items-center gap-3">
                <Sparkline data={tsFailed} strokeClass="stroke-red-300/80" />
                <div className="w-10 text-right text-sm font-semibold text-white">{Number(builds?.failed ?? 0)}</div>
              </div>
            </div>

            <div className="flex items-center justify-between rounded-2xl border border-white/10 bg-black/20 px-3 py-2">
              <div>
                <div className="text-xs font-medium text-zinc-300">Queue depth</div>
                <div className="mt-0.5 text-xs text-zinc-500">queued</div>
              </div>
              <div className="flex items-center gap-3">
                <Sparkline data={tsQueued} strokeClass="stroke-amber-300/80" />
                <div className="w-10 text-right text-sm font-semibold text-white">{Number(builds?.queued ?? 0)}</div>
              </div>
            </div>
          </div>
        </div>

        <div className="gf-card group relative overflow-hidden rounded-2xl border border-white/10 p-5">
          <div className="pointer-events-none absolute -right-14 -top-10 h-44 w-44 rounded-full bg-cyan-500/10 blur-3xl" />
          <div className="flex items-start justify-between">
            <div>
              <div className="text-xs font-medium text-zinc-400">Analytics</div>
              <h2 className="mt-1 text-sm font-semibold text-zinc-100">Billing snapshot</h2>
              <div className="mt-1 text-xs text-zinc-500">MRR + subscriptions</div>
            </div>
            <NeonChip tone="cyan">
              <PulseDot tone="cyan" />
              <span className="font-mono">MRR</span>
              <span className="text-white">{billingLoading ? "…" : `$${Number(billing?.totals?.mrrApproxUsd ?? 0).toFixed(0)}`}</span>
            </NeonChip>
          </div>

          {billingError ? (
            <div className="mt-3 rounded-xl border border-red-400/20 bg-red-500/10 px-3 py-2 text-xs text-red-200">{billingError}</div>
          ) : null}

          <div className="mt-4 space-y-3">
            <div className="flex items-center justify-between rounded-2xl border border-white/10 bg-black/20 px-3 py-2">
              <div>
                <div className="text-xs font-medium text-zinc-300">Active subs</div>
                <div className="mt-0.5 text-xs text-zinc-500">active + trialing</div>
              </div>
              <div className="text-right text-sm font-semibold text-white">{billingLoading ? "—" : String(billing?.totals?.active ?? 0)}</div>
            </div>
            <div className="flex items-center justify-between rounded-2xl border border-white/10 bg-black/20 px-3 py-2">
              <div>
                <div className="text-xs font-medium text-zinc-300">Total subs</div>
                <div className="mt-0.5 text-xs text-zinc-500">all rows</div>
              </div>
              <div className="text-right text-sm font-semibold text-white">{billingLoading ? "—" : String(billing?.totals?.subscriptions ?? 0)}</div>
            </div>
            <div className="flex items-center justify-between rounded-2xl border border-white/10 bg-black/20 px-3 py-2">
              <div>
                <div className="text-xs font-medium text-zinc-300">MRR trend</div>
                <div className="mt-0.5 text-xs text-zinc-500">approx</div>
              </div>
              <div className="flex items-center gap-3">
                <Sparkline data={tsMrr} strokeClass="stroke-cyan-300/80" />
              </div>
            </div>
          </div>
        </div>

        <div className="gf-card group relative overflow-hidden rounded-2xl border border-white/10 p-5">
          <div className="pointer-events-none absolute -right-14 -bottom-14 h-52 w-52 rounded-full bg-emerald-500/10 blur-3xl" />
          <div className="flex items-start justify-between">
            <div>
              <div className="text-xs font-medium text-zinc-400">Analytics</div>
              <h2 className="mt-1 text-sm font-semibold text-zinc-100">Insights</h2>
              <div className="mt-1 text-xs text-zinc-500">Ratios + health hints</div>
            </div>
            <NeonChip tone={successRate >= 80 ? "emerald" : successRate >= 50 ? "amber" : "zinc"}>
              <span className="font-mono">SUCCESS</span>
              <span className="text-white">{loading ? "—" : `${successRate}%`}</span>
            </NeonChip>
          </div>

          <div className="mt-4 grid grid-cols-2 gap-2 text-sm">
            <div className="rounded-xl border border-white/10 bg-black/20 px-3 py-2">
              <div className="text-xs text-zinc-400">Queue pressure</div>
              <div className="mt-1 font-semibold text-white">{loading ? "—" : `${queuePressure}%`}</div>
            </div>
            <div className="rounded-xl border border-white/10 bg-black/20 px-3 py-2">
              <div className="text-xs text-zinc-400">Heap (MB)</div>
              <div className="mt-1 font-semibold text-white">{sysLoading ? "—" : heapMb ? heapMb.toFixed(1) : "0.0"}</div>
            </div>
            <div className="rounded-xl border border-white/10 bg-black/20 px-3 py-2">
              <div className="text-xs text-zinc-400">Heap trend</div>
              <div className="mt-2">
                <Sparkline data={tsHeapMb} strokeClass="stroke-emerald-300/80" />
              </div>
            </div>
            <div className="rounded-xl border border-white/10 bg-black/20 px-3 py-2">
              <div className="text-xs text-zinc-400">System</div>
              <div className="mt-1 font-semibold text-white">{sysLoading ? "—" : sys?.status || "—"}</div>
              <div className="mt-1 text-xs text-zinc-500">Pulse: {lastPulseAgo}</div>
            </div>
          </div>
        </div>
      </div>

      <div className="mt-4 grid grid-cols-1 gap-4 lg:grid-cols-3">
        <div className="gf-card group relative overflow-hidden rounded-2xl border border-white/10 p-5">
          <div className="pointer-events-none absolute -right-10 -top-10 h-40 w-40 rounded-full bg-cyan-500/10 blur-3xl" />
          <div className="flex items-start justify-between">
            <div>
              <div className="text-xs font-medium text-zinc-400">HUD</div>
              <h2 className="mt-1 text-sm font-semibold text-zinc-100">Ratios</h2>
              <div className="mt-1 text-xs text-zinc-500">Quick health checks</div>
            </div>
            <NeonChip tone="zinc">
              <span className="font-mono">LIVE</span>
              <span className="text-white">{lastDashAgo}</span>
            </NeonChip>
          </div>

          <div className="mt-4 grid grid-cols-1 gap-2">
            <RingGauge
              label="Build success"
              valueLabel={loading ? "—" : `${successRate}%`}
              value01={(loading ? 0 : successRate) / 100}
              tone={successRate >= 80 ? "emerald" : successRate >= 50 ? "amber" : "red"}
            />
            <RingGauge
              label="Queue pressure"
              valueLabel={loading ? "—" : `${queuePressure}%`}
              value01={(loading ? 0 : queuePressure) / 100}
              tone={queuePressure <= 40 ? "emerald" : queuePressure <= 70 ? "amber" : "red"}
            />
            <RingGauge
              label="Templates public"
              valueLabel={loading ? "—" : `${templatePublicRate}%`}
              value01={(loading ? 0 : templatePublicRate) / 100}
              tone={templatePublicRate >= 60 ? "emerald" : templatePublicRate >= 25 ? "amber" : "zinc"}
            />
            <RingGauge
              label="Banned users"
              valueLabel={loading ? "—" : `${bannedRate}%`}
              value01={(loading ? 0 : bannedRate) / 100}
              tone={bannedRate <= 5 ? "emerald" : bannedRate <= 15 ? "amber" : "red"}
            />
          </div>
        </div>

        <div className="gf-card group relative overflow-hidden rounded-2xl border border-white/10 p-5">
          <div className="pointer-events-none absolute -right-14 -top-10 h-44 w-44 rounded-full bg-gradient-to-br from-cyan-500/20 to-cyan-500/10 blur-3xl" />
          <div className="flex items-start justify-between">
            <div>
              <div className="text-xs font-medium text-zinc-400">Health Index</div>
              <h2 className="mt-1 text-sm font-semibold text-zinc-100">Composite Score</h2>
              <div className="mt-1 text-xs text-zinc-500">System + builds + memory</div>
            </div>
            <NeonChip tone={healthScore >= 80 ? "emerald" : healthScore >= 50 ? "amber" : "cyan"}>
              <PulseDot tone={healthScore >= 80 ? "emerald" : healthScore >= 50 ? "amber" : "cyan"} />
              <span className="font-mono">SCORE</span>
              <span className="text-white">{loading ? "—" : healthScore}</span>
            </NeonChip>
          </div>

          <div className="mt-4 flex flex-col items-center">
            <div className="relative h-32 w-32">
              <svg viewBox="0 0 100 100" className="h-full w-full -rotate-90 transform">
                <circle cx="50" cy="50" r="42" fill="none" className="stroke-white/10" strokeWidth="8" />
                <circle
                  cx="50"
                  cy="50"
                  r="42"
                  fill="none"
                  className={healthScore >= 80 ? "stroke-emerald-400" : healthScore >= 50 ? "stroke-amber-400" : "stroke-red-400"}
                  strokeWidth="8"
                  strokeLinecap="round"
                  strokeDasharray={`${(healthScore / 100) * 264} 264`}
                />
              </svg>
              <div className="absolute inset-0 flex flex-col items-center justify-center">
                <div className="text-3xl font-bold text-white">{loading ? "—" : healthScore}</div>
                <div className="text-xs text-zinc-400">/ 100</div>
              </div>
            </div>
            <div className="mt-3 text-center text-xs text-zinc-400">
              {healthScore >= 80 ? "All systems healthy" : healthScore >= 50 ? "Some issues detected" : "Critical issues found"}
            </div>
          </div>
        </div>

        <div className="gf-card group relative overflow-hidden rounded-2xl border border-white/10 p-5">
          <div className="pointer-events-none absolute -right-14 -bottom-14 h-52 w-52 rounded-full bg-amber-500/10 blur-3xl" />
          <div className="flex items-start justify-between">
            <div>
              <div className="text-xs font-medium text-zinc-400">Analytics</div>
              <h2 className="mt-1 text-sm font-semibold text-zinc-100">Platform Distribution</h2>
              <div className="mt-1 text-xs text-zinc-500">Build targets breakdown</div>
            </div>
            <NeonChip tone="amber">
              <span className="font-mono">TARGETS</span>
              <span className="text-white">{platformLoading ? "…" : String(platformDist.length)}</span>
            </NeonChip>
          </div>

          <div className="mt-4 space-y-2">
            {platformLoading ? (
              <div className="space-y-2">
                {[1, 2, 3].map((i) => (
                  <div key={i} className="h-8 animate-pulse rounded-xl bg-white/10" />
                ))}
              </div>
            ) : platformDist.length === 0 ? (
              <div className="text-xs text-zinc-400">No builds yet</div>
            ) : (
              platformDist.slice(0, 6).map((p) => {
                const total = platformDist.reduce((s, x) => s + x.count, 0);
                const pct = total ? Math.round((p.count / total) * 100) : 0;
                const colors: Record<string, string> = {
                  webgl: "from-cyan-500/50 to-cyan-300/20",
                  android: "from-emerald-500/50 to-emerald-300/20",
                  windows: "from-blue-500/50 to-blue-300/20",
                  macos: "from-cyan-500/50 to-cyan-300/20",
                  ios: "from-amber-500/50 to-amber-300/20",
                };
                const color = colors[p.target] || "from-zinc-500/50 to-zinc-300/20";
                return (
                  <div key={p.target} className="rounded-xl border border-white/10 bg-black/20 px-3 py-2">
                    <div className="flex items-center justify-between text-xs">
                      <span className="font-medium text-zinc-200 uppercase">{p.target}</span>
                      <span className="text-zinc-400">{p.count} ({pct}%)</span>
                    </div>
                    <div className="mt-2 h-1.5 overflow-hidden rounded-full bg-white/5">
                      <div className={`h-full bg-gradient-to-r ${color}`} style={{ width: `${pct}%` }} />
                    </div>
                  </div>
                );
              })
            )}
          </div>
        </div>
      </div>

      <div className="mt-4 gf-card group relative overflow-hidden rounded-2xl border border-white/10 p-5">
        <div className="pointer-events-none absolute -right-24 -top-24 h-80 w-80 rounded-full bg-cyan-500/10 blur-3xl" />
        <div className="pointer-events-none absolute -left-24 -bottom-24 h-80 w-80 rounded-full bg-cyan-500/10 blur-3xl" />
        <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
          <div>
            <div className="text-xs font-medium text-zinc-400">Quick Actions</div>
            <h2 className="mt-1 text-sm font-semibold text-zinc-100">One-click operations</h2>
            <div className="mt-1 text-xs text-zinc-500">Perform common admin tasks instantly</div>
          </div>
          <NeonChip tone="cyan">
            <PulseDot tone="cyan" />
            <span className="font-mono">OPS</span>
            <span className="text-white">QUICK</span>
          </NeonChip>
        </div>

        <div className="mt-4 grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <button
            className="gf-btn group relative overflow-hidden rounded-xl border border-white/10 bg-black/20 p-4 text-left transition hover:border-white/20 hover:bg-white/5 disabled:opacity-50"
            disabled={quickBusy === "clear-failed"}
            onClick={quickClearFailedBuilds}
          >
            <div className="pointer-events-none absolute inset-0 bg-gradient-to-b from-red-500/10 to-transparent opacity-0 transition group-hover:opacity-100" />
            <div className="relative">
              <div className="text-xs font-semibold text-red-300">Clear Failed</div>
              <div className="mt-1 text-[11px] text-zinc-400">Delete up to 10 failed builds</div>
              {quickBusy === "clear-failed" ? <div className="mt-2 text-xs text-zinc-300">Working…</div> : null}
            </div>
          </button>

          <button
            className="gf-btn group relative overflow-hidden rounded-xl border border-white/10 bg-black/20 p-4 text-left transition hover:border-white/20 hover:bg-white/5 disabled:opacity-50"
            disabled={quickBusy === "restart-stuck"}
            onClick={quickRestartStuckBuilds}
          >
            <div className="pointer-events-none absolute inset-0 bg-gradient-to-b from-cyan-500/10 to-transparent opacity-0 transition group-hover:opacity-100" />
            <div className="relative">
              <div className="text-xs font-semibold text-cyan-300">Restart Stuck</div>
              <div className="mt-1 text-[11px] text-zinc-400">Rebuild up to 5 running builds</div>
              {quickBusy === "restart-stuck" ? <div className="mt-2 text-xs text-zinc-300">Working…</div> : null}
            </div>
          </button>

          <button
            className="gf-btn group relative overflow-hidden rounded-xl border border-white/10 bg-black/20 p-4 text-left transition hover:border-white/20 hover:bg-white/5"
            onClick={quickBroadcastNotification}
          >
            <div className="pointer-events-none absolute inset-0 bg-gradient-to-b from-cyan-500/10 to-transparent opacity-0 transition group-hover:opacity-100" />
            <div className="relative">
              <div className="text-xs font-semibold text-cyan-300">Broadcast</div>
              <div className="mt-1 text-[11px] text-zinc-400">Send push notification to users</div>
            </div>
          </button>

          <button
            className="gf-btn group relative overflow-hidden rounded-xl border border-white/10 bg-black/20 p-4 text-left transition hover:border-white/20 hover:bg-white/5"
            onClick={() => router.push("/templates")}
          >
            <div className="pointer-events-none absolute inset-0 bg-gradient-to-b from-amber-500/10 to-transparent opacity-0 transition group-hover:opacity-100" />
            <div className="relative">
              <div className="text-xs font-semibold text-amber-300">Templates</div>
              <div className="mt-1 text-[11px] text-zinc-400">Manage template vault</div>
            </div>
          </button>
        </div>
      </div>

      <div className="mt-4 gf-card group relative overflow-hidden rounded-2xl border border-white/10 p-5">
        <div className="pointer-events-none absolute -right-24 -top-24 h-80 w-80 rounded-full bg-emerald-500/10 blur-3xl" />
        <div className="pointer-events-none absolute -left-24 -bottom-24 h-80 w-80 rounded-full bg-cyan-500/10 blur-3xl" />
        <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
          <div>
            <div className="text-xs font-medium text-zinc-400">Live Activity</div>
            <h2 className="mt-1 text-sm font-semibold text-zinc-100">Activity Stream</h2>
            <div className="mt-1 text-xs text-zinc-500">Recent events and actions</div>
          </div>
          <div className="flex items-center gap-2">
            <NeonChip tone="emerald">
              <PulseDot tone="emerald" />
              <span className="font-mono">LIVE</span>
              <span className="text-white">{activityLog.length}</span>
            </NeonChip>
            <button className="gf-btn rounded-xl px-3 py-2 text-xs" onClick={() => setActivityLog([])}>
              Clear
            </button>
          </div>
        </div>

        <div className="mt-4 max-h-[280px] overflow-auto rounded-2xl border border-white/10 bg-black/20 p-3">
          {activityLog.length === 0 ? (
            <div className="text-xs text-zinc-400">No recent activity. Actions will appear here.</div>
          ) : (
            <div className="space-y-2">
              {activityLog.map((a, i) => {
                const age = Math.floor((Date.now() - a.ts) / 1000);
                const ageStr = age < 60 ? `${age}s ago` : age < 3600 ? `${Math.floor(age / 60)}m ago` : `${Math.floor(age / 3600)}h ago`;
                const toneCls = a.tone === "emerald" ? "bg-emerald-500/15 border-emerald-400/20" : a.tone === "cyan" ? "bg-cyan-500/15 border-cyan-400/20" : a.tone === "amber" ? "bg-amber-500/15 border-amber-400/20" : "bg-red-500/15 border-red-400/20";
                const dotCls = a.tone === "emerald" ? "bg-emerald-400" : a.tone === "cyan" ? "bg-cyan-400" : a.tone === "amber" ? "bg-amber-400" : "bg-red-400";
                return (
                  <div key={i} className={`rounded-xl border px-3 py-2 ${toneCls}`}>
                    <div className="flex items-center justify-between">
                      <div className="flex items-center gap-2">
                        <span className={`h-2 w-2 rounded-full ${dotCls}`} />
                        <span className="text-xs font-medium text-zinc-200">{a.type}</span>
                      </div>
                      <span className="text-[11px] text-zinc-500">{ageStr}</span>
                    </div>
                    <div className="mt-1 text-xs text-zinc-300">{a.msg}</div>
                  </div>
                );
              })}
            </div>
          )}
        </div>
      </div>

      <div className="mt-4 grid grid-cols-1 gap-4 lg:grid-cols-3">
        <div className="gf-card group relative overflow-hidden rounded-2xl border border-white/10 p-5">
          <div className="pointer-events-none absolute -right-14 -top-10 h-44 w-44 rounded-full bg-blue-500/15 blur-3xl" />
          <div className="flex items-start justify-between">
            <div>
              <div className="text-xs font-medium text-zinc-400">Leaderboard</div>
              <h2 className="mt-1 text-sm font-semibold text-zinc-100">Top Creators</h2>
              <div className="mt-1 text-xs text-zinc-500">By projects + builds + downloads</div>
            </div>
            <NeonChip tone="cyan">
              <span className="font-mono">TOP</span>
              <span className="text-white">{leaderboardLoading ? "…" : String(leaderboard.length)}</span>
            </NeonChip>
          </div>

          <div className="mt-4 space-y-2 max-h-[200px] overflow-auto">
            {leaderboardLoading ? (
              <div className="space-y-2">
                {[1, 2, 3].map((i) => (
                  <div key={i} className="h-10 animate-pulse rounded-xl bg-white/10" />
                ))}
              </div>
            ) : leaderboard.length === 0 ? (
              <div className="text-xs text-zinc-400">No users yet</div>
            ) : (
              leaderboard.map((u, i) => (
                <div key={i} className="flex items-center justify-between rounded-xl border border-white/10 bg-black/20 px-3 py-2">
                  <div className="flex items-center gap-2 min-w-0">
                    <span className="shrink-0 w-5 h-5 rounded-full bg-gradient-to-br from-blue-500/40 to-cyan-500/30 grid place-items-center text-[10px] font-bold text-white">{i + 1}</span>
                    <span className="truncate text-xs font-medium text-zinc-200">{u.username || u.email || "—"}</span>
                  </div>
                  <div className="text-[11px] text-zinc-400">{(u.projects ?? 0) + (u.builds ?? 0) + (u.downloads ?? 0)} pts</div>
                </div>
              ))
            )}
          </div>
        </div>

        <div className="gf-card group relative overflow-hidden rounded-2xl border border-white/10 p-5">
          <div className="pointer-events-none absolute -right-14 -bottom-14 h-52 w-52 rounded-full bg-cyan-500/15 blur-3xl" />
          <div className="flex items-start justify-between">
            <div>
              <div className="text-xs font-medium text-zinc-400">Analytics</div>
              <h2 className="mt-1 text-sm font-semibold text-zinc-100">User Growth</h2>
              <div className="mt-1 text-xs text-zinc-500">Registrations (last 14 days)</div>
            </div>
            <NeonChip tone="cyan">
              <PulseDot tone="cyan" />
              <span className="font-mono">USERS</span>
              <span className="text-white">{userGrowthLoading ? "…" : String(userGrowth.reduce((s, d) => s + d.count, 0))}</span>
            </NeonChip>
          </div>

          <div className="mt-4 h-32 rounded-2xl border border-white/10 bg-black/20 p-3">
            {userGrowthLoading ? (
              <div className="h-full animate-pulse rounded bg-white/10" />
            ) : userGrowth.length === 0 ? (
              <div className="h-full flex items-center justify-center text-xs text-zinc-400">No data yet</div>
            ) : (
              <div className="h-full flex items-end gap-1">
                {userGrowth.map((d, i) => {
                  const max = Math.max(...userGrowth.map((x) => x.count), 1);
                  const h = (d.count / max) * 100;
                  return (
                    <div key={i} className="flex-1 flex flex-col items-center gap-1">
                      <div className="relative w-full flex-1">
                        <div
                          className="absolute bottom-0 left-0 right-0 rounded-t bg-gradient-to-t from-cyan-500/50 to-cyan-300/20"
                          style={{ height: `${Math.max(4, h)}%` }}
                        />
                      </div>
                      <span className="text-[9px] text-zinc-500">{d.date.slice(5)}</span>
                    </div>
                  );
                })}
              </div>
            )}
          </div>
        </div>

        <div className="gf-card group relative overflow-hidden rounded-2xl border border-white/10 p-5">
          <div className="pointer-events-none absolute -right-14 -top-10 h-44 w-44 rounded-full bg-amber-500/10 blur-3xl" />
          <div className="flex items-start justify-between">
            <div>
              <div className="text-xs font-medium text-zinc-400">System</div>
              <h2 className="mt-1 text-sm font-semibold text-zinc-100">Error Log</h2>
              <div className="mt-1 text-xs text-zinc-500">Recent failures</div>
            </div>
            <NeonChip tone={errorLog.length > 0 ? "amber" : "emerald"}>
              <PulseDot tone={errorLog.length > 0 ? "amber" : "emerald"} />
              <span className="font-mono">ERRORS</span>
              <span className="text-white">{errorLogLoading ? "…" : String(errorLog.length)}</span>
            </NeonChip>
          </div>

          <div className="mt-4 space-y-2 max-h-[200px] overflow-auto">
            {errorLogLoading ? (
              <div className="space-y-2">
                {[1, 2, 3].map((i) => (
                  <div key={i} className="h-10 animate-pulse rounded-xl bg-white/10" />
                ))}
              </div>
            ) : errorLog.length === 0 ? (
              <div className="flex items-center gap-2 rounded-xl border border-emerald-400/20 bg-emerald-500/10 px-3 py-2 text-xs text-emerald-200">
                <span className="h-2 w-2 rounded-full bg-emerald-400" />
                No recent errors
              </div>
            ) : (
              errorLog.map((e, i) => {
                const age = Math.floor((Date.now() - e.ts) / 1000);
                const ageStr = age < 60 ? `${age}s` : age < 3600 ? `${Math.floor(age / 60)}m` : `${Math.floor(age / 3600)}h`;
                return (
                  <button
                    key={i}
                    className="w-full flex items-center justify-between rounded-xl border border-amber-400/20 bg-amber-500/10 px-3 py-2 text-left hover:bg-amber-500/15 transition"
                    onClick={() => e.source && router.push(`/builds`)}
                    type="button"
                  >
                    <div className="min-w-0">
                      <div className="text-xs text-amber-200 truncate">{e.msg}</div>
                      {e.source && <div className="text-[10px] text-zinc-500 truncate">{e.source}</div>}
                    </div>
                    <span className="text-[10px] text-zinc-500">{ageStr}</span>
                  </button>
                );
              })
            )}
          </div>
        </div>
      </div>

      <div className="mt-4 grid grid-cols-1 gap-4 lg:grid-cols-3">
        <div className="gf-card group relative overflow-hidden rounded-2xl border border-white/10 p-5">
          <div className="pointer-events-none absolute -right-14 -top-10 h-44 w-44 rounded-full bg-cyan-500/10 blur-3xl" />
          <div className="flex items-start justify-between">
            <div>
              <div className="text-xs font-medium text-zinc-400">HUD</div>
              <h2 className="mt-1 text-sm font-semibold text-zinc-100">Ads intel</h2>
              <div className="mt-1 text-xs text-zinc-500">Campaign activity</div>
            </div>
            <NeonChip tone={adsActive?.id ? "cyan" : "zinc"}>
              <PulseDot tone="cyan" />
              <span className="font-mono">ACTIVE</span>
              <span className="text-white">{adsLoading ? "…" : adsActive?.title || "none"}</span>
            </NeonChip>
          </div>

          <div className="mt-4 grid grid-cols-1 gap-2">
            <RingGauge
              label="Active rate"
              valueLabel={adsLoading ? "—" : `${adsActiveRate}%`}
              value01={(adsLoading ? 0 : adsActiveRate) / 100}
              tone={adsActiveRate >= 50 ? "emerald" : adsActiveRate >= 20 ? "amber" : "zinc"}
            />
            <div className="rounded-2xl border border-white/10 bg-black/20 px-3 py-3">
              <div className="flex items-center justify-between">
                <div className="text-xs font-medium text-zinc-300">Campaigns</div>
                <div className="text-sm font-semibold text-white">{adsLoading ? "—" : String(adsTotal)}</div>
              </div>
              <div className="mt-1 text-xs text-zinc-500">Active: {adsLoading ? "—" : String(adsActiveCount)}</div>
            </div>
          </div>
        </div>

        <div className="gf-card group relative overflow-hidden rounded-2xl border border-white/10 p-5">
          <div className="pointer-events-none absolute -right-14 -bottom-14 h-52 w-52 rounded-full bg-emerald-500/10 blur-3xl" />
          <div className="flex items-start justify-between">
            <div>
              <div className="text-xs font-medium text-zinc-400">HUD</div>
              <h2 className="mt-1 text-sm font-semibold text-zinc-100">System capacity</h2>
              <div className="mt-1 text-xs text-zinc-500">Memory/heap signals</div>
            </div>
            <NeonChip tone={sysStatus === "healthy" ? "emerald" : "amber"}>
              <PulseDot tone={sysStatus === "healthy" ? "emerald" : "amber"} />
              <span className="font-mono">SYS</span>
              <span className="text-white">{sysLoading ? "…" : sys?.status || "—"}</span>
            </NeonChip>
          </div>

          <div className="mt-4 grid grid-cols-1 gap-2">
            <RingGauge
              label="Heap share"
              valueLabel={sysLoading ? "—" : `${heapRate}%`}
              value01={(sysLoading ? 0 : heapRate) / 100}
              tone={heapRate <= 10 ? "emerald" : heapRate <= 25 ? "amber" : "red"}
            />
            <RingGauge
              label="System free"
              valueLabel={sysLoading ? "—" : `${memFreeRate}%`}
              value01={(sysLoading ? 0 : memFreeRate) / 100}
              tone={memFreeRate >= 35 ? "emerald" : memFreeRate >= 15 ? "amber" : "red"}
            />
            <div className="rounded-2xl border border-white/10 bg-black/20 px-3 py-3">
              <div className="flex items-center justify-between">
                <div className="text-xs font-medium text-zinc-300">Used / Total</div>
                <div className="text-sm font-semibold text-white">{sysLoading ? "—" : `${bytes(memUsed)} / ${bytes(memTotal)}`}</div>
              </div>
              <div className="mt-1 text-xs text-zinc-500">Pulse: {lastPulseAgo}</div>
            </div>
          </div>
        </div>
      </div>

      <div className="mt-4 grid grid-cols-1 gap-3 sm:grid-cols-2">
        <div className="gf-card rounded-2xl px-4 py-3 text-xs text-zinc-300">
          Signed in as <span className="text-white">{loading ? "—" : `${data?.user?.username || data?.user?.email || "—"}`}</span>
          <span className="text-zinc-500"> • </span>
          Role: <span className="text-white">{loading ? "—" : `${data?.user?.role || "—"}`}</span>
        </div>
        <div className="gf-card rounded-2xl px-4 py-3 text-xs text-zinc-300">
          Builds: <span className="text-white">{buildsSummary}</span>
          <span className="text-zinc-500"> • </span>
          Templates: <span className="text-white">{templatesSummary}</span>
        </div>
      </div>

      {error ? (
        <div className="mt-5 rounded-xl border border-red-400/20 bg-red-500/10 px-4 py-3 text-sm text-red-200">
          {error}
          <div className="mt-2 text-xs text-red-200/80">
            If you see 401/403, make sure the user role is <span className="font-mono">admin</span>.
          </div>
        </div>
      ) : null}

      <div className="mt-5 grid grid-cols-1 gap-4 lg:grid-cols-3">
        <div className="gf-card rounded-2xl border border-white/10 p-5 lg:col-span-2">
          <div className="flex items-center justify-between">
            <div>
              <h2 className="text-sm font-semibold text-zinc-100">Operations</h2>
              <p className="mt-1 text-xs text-zinc-500">Shortcuts to core admin actions</p>
            </div>
            <button
              className="gf-btn rounded-xl px-3 py-2 text-sm"
              onClick={() => router.refresh()}
            >
              Refresh
            </button>
          </div>

          <div className="mt-4 grid grid-cols-1 gap-3 sm:grid-cols-2">
            <OpCard title="Build Reactor" subtitle="Queue, running, failed, ready" tone="cyan" onClick={() => router.push("/builds")} />
            <OpCard title="Users" subtitle="Roles, access, subscriptions" tone="emerald" onClick={() => router.push("/users")} />
            <OpCard title="Projects" subtitle="Status, rebuild, delete" tone="cyan" onClick={() => router.push("/projects")} />
            <OpCard
              title="Switch admin"
              subtitle="Sign out and login again"
              tone="amber"
              onClick={() => {
                clearToken();
                router.replace("/login");
              }}
            />
          </div>

          <div className="mt-4 rounded-2xl border border-white/10 bg-black/20 p-4">
            <div className="flex items-center justify-between">
              <div>
                <div className="text-xs font-medium text-zinc-400">Activity feed</div>
                <div className="mt-1 text-xs text-zinc-500">Auto-generated from current counters</div>
              </div>
              <NeonChip tone="zinc">
                <span className="font-mono">PULSE</span>
                <span className="text-white">{lastPulseAgo}</span>
              </NeonChip>
            </div>

            <div className="mt-3 space-y-2">
              <div className="flex items-center justify-between rounded-xl border border-white/10 bg-white/5 px-3 py-2 text-xs">
                <span className="text-zinc-300">Builds running</span>
                <span className="font-semibold text-white">{loading ? "—" : `${builds?.running ?? 0}`}</span>
              </div>
              <div className="flex items-center justify-between rounded-xl border border-white/10 bg-white/5 px-3 py-2 text-xs">
                <span className="text-zinc-300">Builds failed</span>
                <span className="font-semibold text-white">{loading ? "—" : `${builds?.failed ?? 0}`}</span>
              </div>
              <div className="flex items-center justify-between rounded-xl border border-white/10 bg-white/5 px-3 py-2 text-xs">
                <span className="text-zinc-300">Public templates</span>
                <span className="font-semibold text-white">{loading ? "—" : `${templates?.public ?? 0}`}</span>
              </div>
              <div className="flex items-center justify-between rounded-xl border border-white/10 bg-white/5 px-3 py-2 text-xs">
                <span className="text-zinc-300">Ad campaign</span>
                <span className="font-semibold text-white">{adsLoading ? "—" : adsActive?.title || "none"}</span>
              </div>
            </div>
          </div>
        </div>

        <div className="gf-card rounded-2xl border border-white/10 p-5">
          <div className="flex items-center justify-between">
            <div>
              <NeonChip tone="cyan">
                <PulseDot tone="cyan" />
                AD ARENA
                <span className="text-zinc-500">•</span>
                <span className="font-mono text-zinc-200">SPONSORED</span>
              </NeonChip>
              <p className="mt-2 text-xs text-zinc-500">Create, activate, and preview campaigns</p>
            </div>
            <div className="flex items-center gap-2">
              <button className="gf-btn rounded-xl px-3 py-2 text-xs" onClick={loadAds}>
                Refresh
              </button>
              <button className="gf-btn rounded-xl px-3 py-2 text-xs" onClick={() => setAdsCreateOpen(true)}>
                Create
              </button>
            </div>
          </div>

          {adsError ? (
            <div className="mt-3 rounded-xl border border-red-400/20 bg-red-500/10 px-3 py-2 text-xs text-red-200">
              {adsError}
            </div>
          ) : null}

          <div className="mt-4 rounded-2xl border border-white/10 bg-white/5 p-4">
            <div className="flex items-center justify-between">
              <div className="min-w-0">
                <div className="text-xs font-medium text-zinc-400">Active campaign</div>
                <div className="mt-1 truncate text-sm font-semibold text-white">
                  {adsLoading ? "…" : adsActive?.title || "None"}
                </div>
                <div className="mt-0.5 truncate text-xs text-zinc-500">
                  {adsLoading
                    ? ""
                    : adsActive
                      ? `${adsActive.advertiserName || "—"} • every ${adsActive.frequency || 5} posts`
                      : "Create and activate a campaign"}
                </div>
              </div>
              {adsActive?.id ? (
                <button
                  disabled={adsBusyId === adsActive.id}
                  className="gf-btn gf-btn-danger rounded-xl px-3 py-2 text-xs disabled:opacity-50"
                  onClick={() => setAdsConfirm({ id: adsActive.id, action: "deactivate", title: adsActive.title })}
                >
                  Deactivate
                </button>
              ) : null}
            </div>

            <div className="mt-3 overflow-hidden rounded-xl border border-white/10 bg-black/30">
              <div className="relative h-28 w-full">
                <div className="pointer-events-none absolute inset-0 opacity-20" style={{ backgroundImage: "repeating-linear-gradient(to bottom, rgba(255,255,255,0.10), rgba(255,255,255,0.10) 1px, transparent 1px, transparent 7px)" }} />
                {adsActive?.imageUrl ? (
                  <div
                    className="absolute inset-0"
                    style={{ backgroundImage: `url(${adsActive.imageUrl})`, backgroundSize: "cover", backgroundPosition: "center" }}
                  />
                ) : (
                  <div className="absolute inset-0 flex items-center justify-center text-xs text-zinc-500">Preview slot</div>
                )}
                <div className="pointer-events-none absolute inset-0 bg-gradient-to-t from-black/60 via-transparent to-transparent" />
                <div className="absolute bottom-2 left-2 right-2 flex items-center justify-between">
                  <NeonChip tone="zinc">
                    <span className="font-mono">FREQ</span>
                    <span className="text-white">{adsLoading ? "—" : `${adsActive?.frequency || 5}`}</span>
                  </NeonChip>
                  <NeonChip tone="zinc">
                    <span className="font-mono">VALUE</span>
                    <span className="text-white">{adsLoading ? "—" : `${adsActive?.impressionValueCents ?? 0}`}</span>
                  </NeonChip>
                </div>
              </div>
            </div>
          </div>

          <div className="mt-4">
            <div className="text-xs font-medium text-zinc-400">Campaigns</div>
            <div className="mt-2 space-y-2">
              {(adsLoading ? Array.from({ length: 3 }, () => null) : adsCampaigns.slice(0, 4)).map((c: any, idx: number) => {
                if (!c) {
                  return (
                    <div
                      key={`sk_${idx}`}
                      className="flex items-center justify-between rounded-2xl border border-white/10 bg-black/20 px-3 py-2"
                    >
                      <div className="min-w-0">
                        <div className="h-4 w-40 animate-pulse rounded bg-white/10" />
                        <div className="mt-2 h-3 w-56 animate-pulse rounded bg-white/10" />
                      </div>
                      <div className="h-8 w-24 animate-pulse rounded-xl bg-white/10" />
                    </div>
                  );
                }

                const isActive = Boolean(c?.active);
                const id = String(c?.id || "");
                const title = (c?.title || "—").toString();
                return (
                  <div
                    key={id || idx}
                    className="flex items-center justify-between rounded-2xl border border-white/10 bg-black/20 px-3 py-2"
                  >
                    <div className="min-w-0">
                      <div className="truncate text-sm text-white">{title}</div>
                      <div className="truncate text-xs text-zinc-500">
                        {`${(c?.advertiserName || "—").toString()} • ${isActive ? "active" : "inactive"}`}
                      </div>
                    </div>
                    <button
                      disabled={!id || adsLoading || adsBusyId === id}
                      className={
                        isActive
                          ? "gf-btn gf-btn-danger rounded-xl px-3 py-2 text-xs disabled:opacity-50"
                          : "gf-btn rounded-xl px-3 py-2 text-xs disabled:opacity-50"
                      }
                      onClick={() =>
                        setAdsConfirm({
                          id,
                          action: isActive ? "deactivate" : "activate",
                          title,
                        })
                      }
                    >
                      {isActive ? "Deactivate" : "Activate"}
                    </button>
                  </div>
                );
              })}
            </div>
          </div>

          <div className="mt-4 grid grid-cols-2 gap-2">
            <a className="gf-btn rounded-lg px-3 py-2 text-xs" href="http://localhost:3000/api" target="_blank" rel="noreferrer">
              API base
            </a>
            <a
              className="gf-btn rounded-lg px-3 py-2 text-xs"
              href="http://localhost:3000/api/docs"
              target="_blank"
              rel="noreferrer"
            >
              Swagger
            </a>
          </div>
        </div>
      </div>

      <ConfirmDialog
        open={Boolean(adsConfirm)}
        title={adsConfirm?.action === "activate" ? "Activate campaign?" : "Deactivate campaign?"}
        description={adsConfirm?.title ? `Campaign: ${adsConfirm.title}` : undefined}
        confirmText={adsConfirm?.action === "activate" ? "Activate" : "Deactivate"}
        confirmTone={adsConfirm?.action === "deactivate" ? "danger" : "default"}
        busy={Boolean(adsConfirm?.id && adsBusyId === adsConfirm.id)}
        onCancel={() => setAdsConfirm(null)}
        onConfirm={async () => {
          if (!adsConfirm) return;
          const { id, action } = adsConfirm;
          setAdsConfirm(null);
          await setCampaignActive(id, action === "activate");
        }}
      />

      {adsCreateOpen ? (
        <div className="fixed inset-0 z-[150] flex items-start justify-center pt-20">
          <div className="absolute inset-0 bg-black/70 backdrop-blur-sm" onClick={() => (adsBusyId ? null : setAdsCreateOpen(false))} />
          <div className="gf-panel-strong relative mx-4 w-full max-w-2xl overflow-hidden rounded-2xl">
            <div className="flex items-center justify-between border-b border-white/10 px-5 py-4">
              <div>
                <h3 className="text-sm font-semibold text-white">Create Ad Campaign</h3>
                <p className="mt-1 text-xs text-zinc-500">Create an inactive campaign, then activate it.</p>
              </div>
              <button className="gf-btn h-9 rounded-xl px-3 text-sm" disabled={Boolean(adsBusyId)} onClick={() => setAdsCreateOpen(false)}>
                Close
              </button>
            </div>

            <div className="grid grid-cols-1 gap-4 px-5 py-5 sm:grid-cols-2">
              <div>
                <label className="text-xs font-medium text-zinc-400">Advertiser</label>
                <input value={adAdvertiserName} onChange={(e) => setAdAdvertiserName(e.target.value)} className="mt-2 gf-input w-full rounded-xl px-3 py-2 text-sm" />
              </div>
              <div>
                <label className="text-xs font-medium text-zinc-400">Title</label>
                <input value={adTitle} onChange={(e) => setAdTitle(e.target.value)} className="mt-2 gf-input w-full rounded-xl px-3 py-2 text-sm" />
              </div>

              <div className="sm:col-span-2">
                <label className="text-xs font-medium text-zinc-400">Description</label>
                <textarea value={adDescription} onChange={(e) => setAdDescription(e.target.value)} rows={3} className="mt-2 gf-input w-full resize-none rounded-xl px-3 py-2 text-sm" />
              </div>

              <div>
                <label className="text-xs font-medium text-zinc-400">Image URL</label>
                <input value={adImageUrl} onChange={(e) => setAdImageUrl(e.target.value)} className="mt-2 gf-input w-full rounded-xl px-3 py-2 text-sm" placeholder="https://.../ad.jpg" />
              </div>
              <div>
                <label className="text-xs font-medium text-zinc-400">Video URL</label>
                <input value={adVideoUrl} onChange={(e) => setAdVideoUrl(e.target.value)} className="mt-2 gf-input w-full rounded-xl px-3 py-2 text-sm" placeholder="https://.../ad.mp4" />
              </div>

              <div>
                <label className="text-xs font-medium text-zinc-400">Click URL</label>
                <input value={adClickUrl} onChange={(e) => setAdClickUrl(e.target.value)} className="mt-2 gf-input w-full rounded-xl px-3 py-2 text-sm" placeholder="https://..." />
              </div>
              <div>
                <label className="text-xs font-medium text-zinc-400">CTA label</label>
                <input value={adCtaLabel} onChange={(e) => setAdCtaLabel(e.target.value)} className="mt-2 gf-input w-full rounded-xl px-3 py-2 text-sm" />
              </div>

              <div>
                <label className="text-xs font-medium text-zinc-400">Frequency (N posts)</label>
                <input value={adFrequency} onChange={(e) => setAdFrequency(e.target.value)} className="mt-2 gf-input w-full rounded-xl px-3 py-2 text-sm" placeholder="5" />
              </div>
              <div>
                <label className="text-xs font-medium text-zinc-400">Impression value (cents)</label>
                <input value={adImpressionValue} onChange={(e) => setAdImpressionValue(e.target.value)} className="mt-2 gf-input w-full rounded-xl px-3 py-2 text-sm" placeholder="1" />
              </div>
            </div>

            <div className="flex items-center justify-end gap-2 border-t border-white/10 px-5 py-4">
              <button className="gf-btn h-10 rounded-xl px-4 text-sm disabled:opacity-50" disabled={Boolean(adsBusyId)} onClick={() => setAdsCreateOpen(false)}>
                Cancel
              </button>
              <button className="gf-btn h-10 rounded-xl px-4 text-sm disabled:opacity-50" disabled={Boolean(adsBusyId)} onClick={createCampaign}>
                {adsBusyId ? "Creating…" : "Create"}
              </button>
            </div>
          </div>
        </div>
      ) : null}

      {/* Confetti Celebration */}
      {showConfetti ? (
        <div className="fixed inset-0 z-[200] pointer-events-none flex items-center justify-center">
          <div className="absolute inset-0 overflow-hidden">
            {Array.from({ length: 50 }).map((_, i) => (
              <div
                key={i}
                className="absolute w-3 h-3 rounded-full animate-bounce"
                style={{
                  left: `${Math.random() * 100}%`,
                  top: `${Math.random() * 100}%`,
                  backgroundColor: ["#22d3ee", "#ec4899", "#a855f7", "#10b981", "#f59e0b"][i % 5],
                  animationDelay: `${Math.random() * 0.5}s`,
                  animationDuration: `${1 + Math.random()}s`,
                }}
              />
            ))}
          </div>
          <div className="relative z-10 text-4xl font-bold text-white animate-pulse drop-shadow-[0_0_30px_rgba(34,211,238,0.8)]">
            🎉 {confettiText} 🎉
          </div>
        </div>
      ) : null}

      {/* Keyboard Shortcuts Panel */}
      {shortcutsOpen ? (
        <div className="fixed inset-0 z-[150] flex items-center justify-center" onClick={() => setShortcutsOpen(false)}>
          <div className="absolute inset-0 bg-black/70 backdrop-blur-sm" />
          <div className="gf-panel-strong relative mx-4 w-full max-w-lg overflow-hidden rounded-2xl" onClick={(e) => e.stopPropagation()}>
            <div className="flex items-center justify-between border-b border-white/10 px-5 py-4">
              <h3 className="text-sm font-semibold text-white">⌨️ Keyboard Shortcuts</h3>
              <button className="gf-btn h-9 rounded-xl px-3 text-sm" onClick={() => setShortcutsOpen(false)}>
                Close
              </button>
            </div>
            <div className="grid grid-cols-1 gap-2 p-5">
              {[
                { key: "?", action: "Show this shortcuts panel" },
                { key: "Esc", action: "Close panels/modals" },
                { key: "R", action: "Refresh dashboard" },
                { key: "B", action: "Go to Builds" },
                { key: "U", action: "Go to Users" },
                { key: "T", action: "Go to Templates" },
                { key: "P", action: "Go to Projects" },
                { key: "N", action: "Go to Notifications" },
                { key: "C", action: "Toggle comparison mode" },
              ].map((s, i) => (
                <div key={i} className="flex items-center justify-between rounded-xl border border-white/10 bg-black/20 px-4 py-3">
                  <span className="text-xs text-zinc-300">{s.action}</span>
                  <kbd className="rounded-lg border border-white/20 bg-white/10 px-2 py-1 text-xs font-mono text-white">{s.key}</kbd>
                </div>
              ))}
            </div>
          </div>
        </div>
      ) : null}

      {/* Milestone Celebrations */}
      {totalUsers === 100 || totalUsers === 500 || totalUsers === 1000 ? (
        <div className="fixed bottom-4 right-4 z-[100] animate-bounce">
          <div className="rounded-2xl border border-amber-400/30 bg-gradient-to-r from-amber-500/20 to-cyan-500/20 px-4 py-3 backdrop-blur">
            <div className="text-xs font-semibold text-amber-200">🏆 Milestone Reached!</div>
            <div className="text-sm font-bold text-white">{totalUsers} Users</div>
          </div>
        </div>
      ) : null}

      {/* Stats Comparison Panel */}
      <div className="mt-4 gf-card group relative overflow-hidden rounded-2xl border border-white/10 p-5">
        <div className="pointer-events-none absolute -right-24 -top-24 h-80 w-80 rounded-full bg-gradient-to-br from-cyan-500/10 to-cyan-500/10 blur-3xl" />
        <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
          <div>
            <div className="text-xs font-medium text-zinc-400">Analytics</div>
            <h2 className="mt-1 text-sm font-semibold text-zinc-100">Live Stats Comparison</h2>
            <div className="mt-1 text-xs text-zinc-500">Current vs previous snapshot</div>
          </div>
          <div className="flex items-center gap-2">
            <NeonChip tone="cyan">
              <PulseDot tone="cyan" />
              <span className="font-mono">LIVE</span>
            </NeonChip>
            <button className="gf-btn rounded-xl px-3 py-2 text-xs" onClick={() => {
              setPrevStats({
                users: totalUsers,
                builds: buildTotal,
                mrr: Number(billing?.totals?.mrrApproxUsd ?? 0),
              });
              toast.success("Snapshot saved for comparison");
            }}>
              Snapshot
            </button>
          </div>
        </div>

        <div className="mt-4 grid grid-cols-1 gap-3 sm:grid-cols-3">
          <div className="rounded-2xl border border-white/10 bg-black/20 p-4">
            <div className="text-xs text-zinc-400">Users</div>
            <div className="mt-2 flex items-end gap-2">
              <span className="text-2xl font-bold text-white">{totalUsers}</span>
              {prevStats.users !== undefined && (
                <span className={`text-xs font-semibold ${totalUsers >= prevStats.users ? "text-emerald-400" : "text-red-400"}`}>
                  {totalUsers >= prevStats.users ? "↑" : "↓"} {Math.abs(totalUsers - prevStats.users)}
                </span>
              )}
            </div>
            {prevStats.users !== undefined && (
              <div className="mt-1 text-[11px] text-zinc-500">was {prevStats.users}</div>
            )}
          </div>

          <div className="rounded-2xl border border-white/10 bg-black/20 p-4">
            <div className="text-xs text-zinc-400">Builds</div>
            <div className="mt-2 flex items-end gap-2">
              <span className="text-2xl font-bold text-white">{buildTotal}</span>
              {prevStats.builds !== undefined && (
                <span className={`text-xs font-semibold ${buildTotal >= prevStats.builds ? "text-emerald-400" : "text-red-400"}`}>
                  {buildTotal >= prevStats.builds ? "↑" : "↓"} {Math.abs(buildTotal - prevStats.builds)}
                </span>
              )}
            </div>
            {prevStats.builds !== undefined && (
              <div className="mt-1 text-[11px] text-zinc-500">was {prevStats.builds}</div>
            )}
          </div>

          <div className="rounded-2xl border border-white/10 bg-black/20 p-4">
            <div className="text-xs text-zinc-400">MRR ($)</div>
            <div className="mt-2 flex items-end gap-2">
              <span className="text-2xl font-bold text-white">{Number(billing?.totals?.mrrApproxUsd ?? 0).toFixed(0)}</span>
              {prevStats.mrr !== undefined && (
                <span className={`text-xs font-semibold ${Number(billing?.totals?.mrrApproxUsd ?? 0) >= prevStats.mrr ? "text-emerald-400" : "text-red-400"}`}>
                  {Number(billing?.totals?.mrrApproxUsd ?? 0) >= prevStats.mrr ? "↑" : "↓"} ${Math.abs(Number(billing?.totals?.mrrApproxUsd ?? 0) - prevStats.mrr)}
                </span>
              )}
            </div>
            {prevStats.mrr !== undefined && (
              <div className="mt-1 text-[11px] text-zinc-500">was ${prevStats.mrr}</div>
            )}
          </div>
        </div>
      </div>

      {/* Quick Stats Bar */}
      <div className="mt-4 grid grid-cols-2 gap-2 sm:grid-cols-4">
        {[
          { label: "Success Rate", value: `${successRate}%`, tone: successRate >= 80 ? "emerald" : "amber", icon: "✓" },
          { label: "Queue Depth", value: builds?.queued ?? 0, tone: (builds?.queued ?? 0) < 5 ? "emerald" : "amber", icon: "⏳" },
          { label: "Active Users", value: totalUsers - (data?.dashboard?.inactiveUsers ?? 0), tone: "cyan", icon: "👤" },
          { label: "Public Templates", value: templates?.public ?? 0, tone: "cyan", icon: "📦" },
        ].map((s, i) => (
          <button
            key={i}
            className="gf-card group relative overflow-hidden rounded-xl border border-white/10 p-3 text-left transition hover:border-white/20 hover:bg-white/5"
            onClick={() => {
              if (i === 0) router.push("/builds");
              else if (i === 1) router.push("/builds");
              else if (i === 2) router.push("/users");
              else router.push("/templates");
            }}
            type="button"
          >
            <div className="flex items-center justify-between">
              <span className="text-lg">{s.icon}</span>
              <span className={`text-xs font-semibold ${s.tone === "emerald" ? "text-emerald-400" : s.tone === "amber" ? "text-amber-400" : s.tone === "cyan" ? "text-cyan-400" : "text-cyan-400"}`}>
                {s.value}
              </span>
            </div>
            <div className="mt-1 text-[11px] text-zinc-400">{s.label}</div>
          </button>
        ))}
      </div>
    </AdminShell>
  );
}
