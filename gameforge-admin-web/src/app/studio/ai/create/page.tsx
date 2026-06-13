"use client";

import { useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import UserShell from "@/app/_components/UserShell";
import { apiFetch, ApiError } from "@/lib/api";
import { readAuthToken } from "@/lib/stores/authStore";
import { normalizeImageUrl } from "@/lib/media";
import { Activity, Sparkles, Wand2, Layout, Check, ArrowRight, Zap, Target, Palette, Cpu, Volume2, BrainCircuit, Lightbulb, Shuffle, Gauge, Rocket, Trophy } from "lucide-react";
import { motion } from "framer-motion";

// Types
type GDD = {
  genre: string;
  title: string;
  description: string;
  difficulty: number;
  theme: string;
  mechanics: string[];
  playerSpeed: number;
  primaryColor: string;
  backgroundColor: string;
};

type Template = {
  id?: string;
  _id?: string;
  name?: string;
  title?: string;
  description?: string;
  category?: string;
  tags?: string[];
  previewImageUrl?: string;
  thumbnailUrl?: string;
  imageUrl?: string;
  screenshotUrls?: string[];
  screenshots?: string[];
  coverImageUrl?: string;
  coverUrl?: string;
};

type SmartMatchResponse = {
  detectedIntent?: string;
  rankedTemplates?: Array<Template & { score?: number; reasons?: string[] }>;
};

type GuideState = {
  genre: string;
  perspective: string;
  pace: string;
  vibe: string;
  mechanic: string;
  objective: string;
  difficulty: string;
};

const GUIDE_DEFAULTS: GuideState = {
  genre: "",
  perspective: "",
  pace: "",
  vibe: "",
  mechanic: "",
  objective: "",
  difficulty: "",
};

const QUICK_IDEAS = [
  "ninja",
  "2d runner",
  "cyber samurai",
  "pixel rogue",
  "forest platformer",
  "space dash",
];

const INSPIRATION_PRESETS: Array<{ title: string; subtitle: string; seed: string; tone: "blue" | "cyan" | "emerald" }> = [
  {
    title: "Shadow Ninja Rush",
    subtitle: "High-speed wall-jump action",
    seed: "ninja 2d runner with stealth takedowns and combo score",
    tone: "blue",
  },
  {
    title: "Neon Sky Drifter",
    subtitle: "Arcade flow + synthwave vibe",
    seed: "neon hover runner with air-dash, obstacles, and score multipliers",
    tone: "cyan",
  },
  {
    title: "Forest Relic Hunt",
    subtitle: "Adventure platformer loop",
    seed: "2d platformer in enchanted forest collecting relics and solving movement puzzles",
    tone: "emerald",
  },
];

function clamp01(n: number): number {
  if (Number.isNaN(n)) return 0;
  return Math.max(0, Math.min(1, n));
}

function tokenize(input: string): string[] {
  return String(input || "")
    .toLowerCase()
    .replace(/[^a-z0-9\s-]/g, " ")
    .split(/\s+/)
    .map((x) => x.trim())
    .filter(Boolean);
}

const INTENT_KEYWORDS: Record<string, string[]> = {
  runner: ["runner", "endless", "dash", "speed", "sprint"],
  shooter: ["fps", "shooter", "gun", "weapon", "bullet"],
  ninja: ["ninja", "samurai", "stealth", "shadow", "katana"],
  platformer: ["platformer", "jump", "wall", "obstacle", "side-scroller"],
  puzzle: ["puzzle", "logic", "brain", "match", "solve"],
  roguelite: ["rogue", "roguelite", "dungeon", "procedural"],
};

const GENERIC_TEMPLATE_WORDS = ["classic", "starter", "template", "kit", "2d"];
const LOW_SIGNAL_TOKENS = new Set(["2d", "game", "games", "template", "templates", "project", "create", "build", "webgl"]);

function hasWord(haystack: string, word: string): boolean {
  const safe = word.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  const rgx = new RegExp(`(^|[^a-z0-9])${safe}([^a-z0-9]|$)`, "i");
  return rgx.test(haystack);
}

function detectPrimaryIntent(text: string): string | null {
  const tokens = tokenize(text);
  let best: { key: string; score: number } | null = null;
  for (const [intent, words] of Object.entries(INTENT_KEYWORDS)) {
    const score = words.reduce((acc, w) => acc + (tokens.includes(w) ? 1 : 0), 0);
    if (!best || score > best.score) best = { key: intent, score };
  }
  return best && best.score > 0 ? best.key : null;
}

function buildInlineSuggestions(prompt: string, guide: GuideState): string[] {
  const base = String(prompt || "").trim();
  if (base.length < 2) return [];
  const tokens = tokenize(base);
  const out: string[] = [];

  const intent = detectPrimaryIntent(base);
  if (intent === "runner") {
    out.push("endless runner");
    out.push("speed boost + near-miss scoring");
  }
  if (intent === "platformer") {
    out.push("wall jump + dash");
    out.push("checkpoint + mini-boss");
  }
  if (intent === "shooter") {
    out.push("weapon upgrades + recoil feel");
    out.push("enemy waves + elite spawns");
  }
  if (intent === "puzzle") {
    out.push("short levels + satisfying combos");
    out.push("difficulty curve: easy → tricky");
  }

  if (guide.vibe && !tokens.includes(guide.vibe.toLowerCase())) out.push(guide.vibe);
  if (guide.genre && !tokens.includes(guide.genre.toLowerCase())) out.push(guide.genre);
  if (guide.mechanic && !hasWord(base, guide.mechanic.toLowerCase())) out.push(guide.mechanic);
  if (guide.perspective && !hasWord(base, guide.perspective.toLowerCase())) out.push(guide.perspective);

  return Array.from(new Set(out)).slice(0, 6);
}

function buildGuideSeed(guide: GuideState): string {
  const chunks = [
    guide.genre,
    guide.perspective,
    guide.pace,
    guide.vibe,
    guide.mechanic,
    guide.objective,
    guide.difficulty,
  ].filter(Boolean);
  return chunks.join(" ").trim();
}

function expandPrompt(raw: string, guide: GuideState): string {
  const base = String(raw || "").trim();
  const low = base.toLowerCase();
  
  const isFPS = low.includes("fps") || low.includes("shooter") || low.includes("gun") || low.includes("shooting");
  const isRunner = low.includes("runner") || low.includes("dash");
  const isPlatformer = low.includes("platformer") || low.includes("jump") || low.includes("ninja");
  const isPuzzle = low.includes("puzzle") || low.includes("match") || low.includes("logic");

  const inferredGenre = guide.genre || (isFPS ? "3D First-Person Shooter" : isRunner ? "2D endless runner" : isPlatformer ? "2D action platformer" : isPuzzle ? "Logic Puzzle Game" : "2D arcade game");
  const inferredPerspective = guide.perspective || (isFPS ? "First-Person 3D" : low.includes("2d") ? "side-scroller" : "2.5D side view");
  const inferredPace = guide.pace || (isRunner || isFPS ? "fast" : "medium");
  const inferredObjective = guide.objective || (isFPS ? "eliminate all targets and survive waves" : isRunner ? "survive as long as possible while chaining score multipliers" : "finish handcrafted levels and defeat mini-bosses");
  const inferredMechanic = guide.mechanic || (isFPS ? "aiming + projectile ballistics + tactical movement" : isPlatformer ? "dash-slash + wall jump + stealth takedowns" : "jump, dodge, slide, and combo pickups");
  const inferredVibe = guide.vibe || (isFPS ? "industrial grit with tactical HUD" : "stylized neon with clean readable UX");
  const inferredDifficulty = guide.difficulty || "balanced for casual-to-core players";

  const speedMps = inferredPace.toLowerCase().includes("fast") ? 8.4 : inferredPace.toLowerCase().includes("chill") ? 5.1 : 6.7;
  const primaryColor = inferredVibe.toLowerCase().includes("neon") ? "#5B7CFF" : inferredVibe.toLowerCase().includes("fantasy") ? "#7C4DFF" : inferredVibe.toLowerCase().includes("pixel") ? "#33D1A0" : isFPS ? "#B91C1C" : "#4F46E5";
  const accentColor = inferredVibe.toLowerCase().includes("neon") ? "#FF3EF0" : inferredVibe.toLowerCase().includes("fantasy") ? "#E879F9" : inferredVibe.toLowerCase().includes("pixel") ? "#F59E0B" : isFPS ? "#FACC15" : "#22D3EE";
  const gravityScale = inferredPace.toLowerCase().includes("fast") ? "1.18" : "1.0";
  const spawnDensity = inferredDifficulty.toLowerCase().includes("hard") ? "high" : inferredDifficulty.toLowerCase().includes("casual") ? "low" : "medium";
  const audioProfile = inferredVibe.toLowerCase().includes("neon") ? "synthwave pulse" : inferredVibe.toLowerCase().includes("fantasy") ? "cinematic ambient" : isFPS ? "tactical industrial" : "arcade hybrid";

  return [
    `Create a ${inferredGenre || "2D arcade game"} inspired by: ${base || "original idea"}.`,
    `Perspective: ${inferredPerspective}. Pace: ${inferredPace}.`,
    `Core gameplay loop: ${inferredObjective}.`,
    `Main mechanics: ${inferredMechanic}.`,
    `Visual style and mood: ${inferredVibe}.`,
    `Difficulty curve: ${inferredDifficulty}.`,
    `Technical parameters: player_speed_mps=${speedMps}, jump_gravity_scale=${gravityScale}, obstacle_spawn_density=${spawnDensity}.`,
    `Art parameters: primary_color=${primaryColor}, accent_color=${accentColor}, ui_style=high-contrast readable HUD, parallax_layers=4.`,
    `Audio parameters: profile=${audioProfile}, sfx_clarity=high, feedback_timing=responsive.`,
    "Generate clear player controls, progression hooks, collectible economy, and a polished WebGL-ready build configuration.",
  ].join(" ");
}

function templateRank(template: Template, query: string, guide: GuideState): number {
  const hay = [
    template.name,
    template.title,
    template.description,
    template.category,
    ...(Array.isArray(template.tags) ? template.tags : []),
  ]
    .filter(Boolean)
    .join(" ")
    .toLowerCase();

  const qTokens = tokenize(query);
  const gTokens = tokenize(buildGuideSeed(guide));
  const primaryIntent = detectPrimaryIntent(`${query} ${buildGuideSeed(guide)}`);
  let score = 0;

  for (const t of [...qTokens, ...gTokens]) {
    if (!t) continue;
    if (LOW_SIGNAL_TOKENS.has(t)) continue;
    if (hasWord(hay, t)) score += t.length > 4 ? 4 : 2;
    else if (hay.includes(t)) score += t.length > 4 ? 2 : 1;
  }
  if (guide.genre && hay.includes(guide.genre.toLowerCase())) score += 5;
  if (guide.mechanic && hay.includes(guide.mechanic.toLowerCase())) score += 4;
  if (guide.vibe && hay.includes(guide.vibe.toLowerCase())) score += 2;

  if (primaryIntent) {
    const intentWords = INTENT_KEYWORDS[primaryIntent] || [];
    const hasIntentHit = intentWords.some((w) => hasWord(hay, w));
    score += hasIntentHit ? 14 : -8;
  }

  const queryHasSpecificIntent = Object.values(INTENT_KEYWORDS)
    .flat()
    .some((w) => hasWord(query.toLowerCase(), w));
  const isGenericTemplate = GENERIC_TEMPLATE_WORDS.filter((w) => hasWord(hay, w)).length >= 2;
  if (queryHasSpecificIntent && isGenericTemplate) score -= 6;

  if (hasWord(query.toLowerCase(), "fps") || hasWord(query.toLowerCase(), "shooter")) {
    if (hasWord(hay, "fps") || hasWord(hay, "shooter")) score += 10;
    else score -= 10;
  }

  return score;
}

function dedupeTemplates(input: Template[]): Template[] {
  const seen = new Set<string>();
  const out: Template[] = [];
  for (const t of input) {
    const id = String(t?._id || t?.id || "").trim();
    const key = id || `${String(t?.name || t?.title || "").trim().toLowerCase()}::${String(t?.category || "").trim().toLowerCase()}`;
    if (!key || seen.has(key)) continue;
    seen.add(key);
    out.push(t);
  }
  return out;
}

function getTemplateImageUrl(template: Template): string {
  const screenshotA = Array.isArray(template.screenshotUrls) ? template.screenshotUrls.find((x) => String(x || "").trim()) : "";
  const screenshotB = Array.isArray(template.screenshots) ? template.screenshots.find((x) => String(x || "").trim()) : "";
  return (
    normalizeImageUrl(
      template.previewImageUrl ||
      template.thumbnailUrl ||
      template.imageUrl ||
      template.coverImageUrl ||
      template.coverUrl ||
      screenshotA ||
      screenshotB,
    ) || ""
  );
}

function templateIdentityKeys(template: Template): string[] {
  const out: string[] = [];
  const id = String(template?._id || template?.id || "").trim();
  if (id) out.push(`id:${id}`);
  const byName = `${String(template?.name || template?.title || "").trim().toLowerCase()}::${String(template?.category || "").trim().toLowerCase()}`;
  if (byName !== "::") out.push(`name:${byName}`);
  return out;
}

function mergeTemplateMedia(primary: Template, fallback?: Template): Template {
  if (!fallback) return primary;
  return {
    ...fallback,
    ...primary,
    previewImageUrl: primary.previewImageUrl || fallback.previewImageUrl,
    thumbnailUrl: primary.thumbnailUrl || fallback.thumbnailUrl,
    imageUrl: primary.imageUrl || fallback.imageUrl,
    coverImageUrl: primary.coverImageUrl || fallback.coverImageUrl,
    coverUrl: primary.coverUrl || fallback.coverUrl,
    screenshotUrls: Array.isArray(primary.screenshotUrls) && primary.screenshotUrls.length ? primary.screenshotUrls : fallback.screenshotUrls,
    screenshots: Array.isArray(primary.screenshots) && primary.screenshots.length ? primary.screenshots : fallback.screenshots,
  };
}

export default function AiCreatePage() {
  const router = useRouter();

  const [prompt, setPrompt] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // New States
  const [mode, setMode] = useState<"blueprint" | "scratch">("blueprint");
  const [gdd, setGdd] = useState<GDD | null>(null);
  const [showGdd, setShowGdd] = useState(false);

  const [suggestLoading, setSuggestLoading] = useState(false);
  const [suggestions, setSuggestions] = useState<Template[]>([]);
  const [templateReasons, setTemplateReasons] = useState<Record<string, string[]>>({});
  const [smartIntent, setSmartIntent] = useState<string>("general");
  const [selectedTemplateId, setSelectedTemplateId] = useState<string>("");
  const [templatePinned, setTemplatePinned] = useState(false);
  const [templateCatalog, setTemplateCatalog] = useState<Template[]>([]);
  const [guideOpen, setGuideOpen] = useState(false);
  const [guide, setGuide] = useState<GuideState>(GUIDE_DEFAULTS);
  const [expandedPrompt, setExpandedPrompt] = useState("");

  const guideSeed = useMemo(() => buildGuideSeed(guide), [guide]);
  const effectivePrompt = useMemo(() => {
    const p = prompt.trim();
    if (p) return p;
    return guideSeed;
  }, [prompt, guideSeed]);

  const inlineSuggestions = useMemo(() => buildInlineSuggestions(effectivePrompt, guide), [effectivePrompt, guide]);

  const guideCompletion = useMemo(() => {
    const fields: Array<keyof GuideState> = ["genre", "perspective", "pace", "vibe", "mechanic", "objective", "difficulty"];
    const count = fields.reduce((acc, k) => acc + (guide[k] ? 1 : 0), 0);
    return clamp01(count / fields.length);
  }, [guide]);

  const promptQuality = useMemo(() => {
    const tokens = tokenize(effectivePrompt);
    const lengthScore = clamp01(tokens.length / 26);
    const guideScore = guideCompletion;
    return clamp01(lengthScore * 0.62 + guideScore * 0.38);
  }, [effectivePrompt, guideCompletion]);

  const selectedTemplate = useMemo(() => {
    if (!selectedTemplateId) return null;
    return suggestions.find((t) => String(t._id || t.id || "") === selectedTemplateId) || null;
  }, [selectedTemplateId, suggestions]);

  const visualInspiration = useMemo(() => {
    return dedupeTemplates([...suggestions, ...templateCatalog]).slice(0, 6);
  }, [suggestions, templateCatalog]);

  // Clear error when prompt changes
  useEffect(() => {
    if (prompt.trim() && error) setError(null);
  }, [prompt, error]);

  useEffect(() => {
    if (mode !== "blueprint") return;
  const token = readAuthToken();
    const ac = new AbortController();
    let cancelled = false;

    async function loadTemplateCatalog() {
      try {
        const qp = new URLSearchParams();
        qp.set("limit", "80");
        const res = await apiFetch<any>(`/templates?${qp.toString()}`, {
          method: "GET",
          token: token || undefined,
          signal: ac.signal,
        });
        const data = (res && typeof res === "object" && "data" in res) ? (res as any).data : res;
        const list = Array.isArray((data as any)?.data) ? (data as any).data : (Array.isArray(data) ? data : []);
        const items = list
          .filter(Boolean)
          .map((t: any) => (t && typeof t === "object" ? (t as Template) : ({} as Template)));
        if (!cancelled) setTemplateCatalog(dedupeTemplates(items));
      } catch {
        // no-op
      }
    }

    loadTemplateCatalog();
    return () => {
      cancelled = true;
      ac.abort();
    };
  }, [mode]);

  useEffect(() => {
    if (mode !== "blueprint") return;
  const token = readAuthToken();
    let cancelled = false;
    const ac = new AbortController();

    async function applySmartMatch(candidates: Template[], q: string): Promise<Template[]> {
      const fallback = dedupeTemplates(candidates).slice(0, 6);
      if (!fallback.length) {
        setTemplateReasons({});
        setSmartIntent("general");
        return fallback;
      }

      try {
        const res = await apiFetch<SmartMatchResponse>("/platform-labs/smart-match", {
          method: "POST",
          token: token || undefined,
          body: {
            prompt: q || guideSeed || "arcade",
            guide,
            templates: fallback,
          },
          signal: ac.signal,
        });

        const payload = (res && typeof res === "object" && "data" in (res as any)) ? (res as any).data : res;
        const ranked = Array.isArray((payload as any)?.rankedTemplates)
          ? ((payload as any).rankedTemplates as Array<Template & { reasons?: string[] }>)
          : [];

        const index = new Map<string, Template>();
        for (const item of fallback) {
          for (const key of templateIdentityKeys(item)) {
            if (!index.has(key)) index.set(key, item);
          }
        }

        const rankedMerged = ranked.map((item) => {
          const match = templateIdentityKeys(item)
            .map((k) => index.get(k))
            .find(Boolean);
          return mergeTemplateMedia(item, match);
        });

        const normalized = dedupeTemplates(rankedMerged.length ? rankedMerged : fallback).slice(0, 6);

        const reasonsMap: Record<string, string[]> = {};
        for (const t of ranked) {
          const id = String(t?._id || t?.id || "");
          if (!id) continue;
          reasonsMap[id] = Array.isArray((t as any).reasons) ? ((t as any).reasons as string[]).slice(0, 2) : [];
        }

setTemplateReasons(reasonsMap);
setSmartIntent(String((payload as any)?.detectedIntent || "general"));
return normalized;
} catch {
setTemplateReasons({});
setSmartIntent("general");
return fallback;
}
}

  async function loadSuggestions() {
    const q = effectivePrompt.trim();
    if (q.length < 2) {
      setSuggestions([]);
      setSmartIntent("general");
      setSuggestLoading(false);
      return;
    }

    setSuggestLoading(true);
    try {
      const qp = new URLSearchParams();
      qp.set("q", q);
      const res = await apiFetch<any>(`/templates?${qp.toString()}`, { method: "GET", token: token || undefined, signal: ac.signal });
      const data = (res && typeof res === "object" && "data" in res) ? (res as any).data : res;
      const list = Array.isArray((data as any)?.data) ? (data as any).data : (Array.isArray(data) ? data : []);
      const items = list
        .filter(Boolean)
        .map((t: any) => (t && typeof t === "object" ? (t as Template) : ({} as Template)));

      const localRanked = dedupeTemplates(templateCatalog)
        .sort((a, b) => templateRank(b, q, guide) - templateRank(a, q, guide))
        .slice(0, 6);

      const mergedBase = dedupeTemplates([...items, ...localRanked]).slice(0, 6);
      const merged = await applySmartMatch(mergedBase, q);

      if (!cancelled) {
        const best = merged[0] ? [merged[0]] : [];
        setSuggestions(best);
        const hasCurrent = best.some((t) => String(t._id || t.id || "") === selectedTemplateId);
        if (best[0] && (!templatePinned || !hasCurrent)) {
          setSelectedTemplateId(String(best[0]._id || best[0].id || ""));
        }
      }
    } catch {
      const localRankedBase = dedupeTemplates(templateCatalog)
        .sort((a, b) => templateRank(b, q, guide) - templateRank(a, q, guide))
        .slice(0, 6);
      const localRanked = await applySmartMatch(localRankedBase, q);
      if (!cancelled) {
        const best = localRanked[0] ? [localRanked[0]] : [];
        setSuggestions(best);
        const hasCurrent = best.some((t) => String(t._id || t.id || "") === selectedTemplateId);
        if (best[0] && (!templatePinned || !hasCurrent)) {
          setSelectedTemplateId(String(best[0]._id || best[0].id || ""));
        }
      }
    } finally {
      if (!cancelled) setSuggestLoading(false);
    }
  }

    const t = setTimeout(loadSuggestions, 420);
    return () => {
      cancelled = true;
      clearTimeout(t);
      ac.abort();
    };
  }, [effectivePrompt, guide, guideSeed, mode, selectedTemplateId, templateCatalog, templatePinned]);

  function applyGuideField(field: keyof GuideState, value: string) {
    setGuide((prev) => ({ ...prev, [field]: prev[field] === value ? "" : value }));
  }

  function applyQuickIdea(idea: string) {
    setTemplatePinned(false);
    setSelectedTemplateId("");
    setPrompt((prev) => {
      const current = prev.trim();
      if (!current) return idea;
      if (current.toLowerCase().includes(idea.toLowerCase())) return current;
      return `${current}, ${idea}`;
    });
  }

  function applyInspirationPreset(seed: string) {
    setTemplatePinned(false);
    setSelectedTemplateId("");
    setPrompt(seed);
    setGuideOpen(true);
  }

  function applyVisualInspiration(template: Template) {
    setTemplatePinned(false);
    setSelectedTemplateId("");
    const title = String(template.name || template.title || "").trim();
    const category = String(template.category || "").trim();
    const seed = [title, category, "polished gameplay loop", "clean UX"].filter(Boolean).join(" ");
    setPrompt(seed);
    setGuideOpen(true);
  }

  function materializePrompt() {
    const source = prompt.trim();
    if (!source) return;
    const full = expandPrompt(source, guide);
    setExpandedPrompt(full);
    setTemplatePinned(false);
    setSelectedTemplateId("");
    setPrompt(full);
  }

  async function handleAction() {
    console.log("handleAction triggered", { mode, prompt, gdd });
  const token = readAuthToken();
    if (!token) {
      console.warn("No token found, redirecting to signin");
      router.push("/signin");
      return;
    }
    const p = prompt.trim();
    if (!p) {
      setError("Please enter a prompt or tap Inspire Me to generate one.");
      return;
    }

    const fullPrompt = expandPrompt(p, guide);

    setError(null);
    setLoading(true);

    try {
      if (mode === "scratch" && !gdd) {
        console.log(`[FE] POST -> /ai/generate-gdd-preview | Body:`, { prompt: fullPrompt });
        const res = await apiFetch<any>("/ai/generate-gdd-preview", {
          method: "POST",
          token,
          body: { prompt: fullPrompt }
        });
        console.log(`[FE] Result:`, res);
        const data = res?.data?.gdd || res?.gdd || res;
        if (!data) throw new Error("Failed to generate GDD - No data returned from engine");
        setGdd(data);
        setShowGdd(true);
      } else {
        console.log("Finalizing project creation...");
        await finalizeCreate(fullPrompt);
      }
    } catch (e: any) {
      console.error("handleAction failed", e);
      setError(e instanceof ApiError ? e.message : (e?.message || "Synthesis failed - Check your connection"));
    } finally {
      setLoading(false);
    }
  }

  async function finalizeCreate(promptOverride?: string) {
    const finalPrompt = String(promptOverride || prompt).trim();
    console.log("[FE] finalizeCreate started", { mode, prompt: finalPrompt, selectedTemplateId });
    setLoading(true);
    setError(null);
    try {
      let endpoint = "/projects/ai/create";
      let body: any = { prompt: finalPrompt, buildTarget: "webgl" };

      if (mode === "scratch") {
        console.log("[FE] Scratch Mode -> /ai/generate-from-scratch");
        endpoint = "/ai/generate-from-scratch";
      } else if (selectedTemplateId) {
        console.log("[FE] Blueprint Mode -> templateId:", selectedTemplateId);
        body.templateId = selectedTemplateId;
      }

  const res = await apiFetch<any>(endpoint, { method: "POST", token: readAuthToken(), body });
      console.log("[FE] finalizeCreate Result:", res);
      
      const data = (res && typeof res === "object" && "data" in res) ? (res as any).data : res;
      const payload = (data?.data ?? data) as any;
      const projectId = (payload?.projectId ?? payload?._id ?? payload?.id)?.toString?.() ?? "";
      
      if (!projectId) {
        console.error("[FE] No projectId in response", payload);
        throw new Error("Creation failed: Missing project ID from engine");
      }

      console.log("[FE] Redirecting to build progress:", projectId);
      router.replace(`/studio/builds/progress?projectId=${encodeURIComponent(projectId)}`);
    } catch (e: any) {
      console.error("[FE] finalizeCreate failed", e);
      const msg = e instanceof ApiError ? e.message : (e?.message || "Creation failed - Connection lost");
      setError(msg);
      setLoading(false);
    }
  }

  return (
    <UserShell
      title="Create with AI"
      subtitle="Generate a project from a prompt"
      right={
        <div className="flex items-center gap-2">
          <button className="gf-btn rounded-xl px-3 py-2 text-sm" onClick={() => router.push("/studio/wow-labs")}>
            Wow Labs
          </button>
          <button className="gf-btn rounded-xl px-3 py-2 text-sm" onClick={() => router.push("/studio")}>
            Back
          </button>
        </div>
      }
    >
      {error ? <div className="mb-6 rounded-2xl border border-red-500/20 bg-red-500/10 px-4 py-3 text-sm text-red-200">{error}</div> : null}

      <div className="grid grid-cols-1 lg:grid-cols-12 gap-8">
        <div className="lg:col-span-8 space-y-6">
          {/* Mode Toggle */}
          <div className="flex gap-2 p-1.5 bg-black/40 rounded-2xl border border-white/5 w-fit mb-4">
            <button
              onClick={() => { setMode("blueprint"); setGdd(null); setShowGdd(false); }}
              className={`flex items-center gap-2 px-4 py-2 rounded-xl text-xs font-black uppercase tracking-widest transition-all ${
                mode === "blueprint" ? "bg-blue-500 text-white shadow-lg" : "text-zinc-500 hover:text-white"
              }`}
            >
              <Layout size={14} /> Blueprint Mode
            </button>
            <button
              onClick={() => setMode("scratch")}
              className={`flex items-center gap-2 px-4 py-2 rounded-xl text-xs font-black uppercase tracking-widest transition-all ${
                mode === "scratch" ? "bg-gradient-to-r from-blue-600 to-sky-500 text-white shadow-lg" : "text-zinc-500 hover:text-white"
              }`}
            >
              <Wand2 size={14} /> Magic Forge
            </button>
          </div>

          <div className="gf-panel-strong rounded-[32px] p-8 border border-white/5 relative overflow-hidden group/vision shadow-2xl">
            <div className="absolute inset-0 bg-gradient-to-br from-blue-600/10 via-transparent to-sky-500/5 pointer-events-none opacity-50" />
            <div className="pointer-events-none absolute -top-24 -right-16 h-56 w-56 rounded-full bg-blue-500/15 blur-3xl" />
            <div className="pointer-events-none absolute -bottom-28 -left-20 h-64 w-64 rounded-full bg-blue-600/8 blur-3xl" />
            
            <div className="flex items-center justify-between gap-4 mb-6 flex-wrap">
              <div className="flex items-center gap-4">
              <div className="h-12 w-12 rounded-2xl bg-gradient-to-br from-blue-600 to-sky-500 flex items-center justify-center text-white shadow-lg shadow-blue-500/20">
                <Sparkles size={24} className="animate-pulse" />
              </div>
              <div>
                <h3 className="text-2xl font-black text-[var(--foreground)] italic uppercase tracking-tighter">The Vision</h3>
                <p className="text-[10px] font-bold text-zinc-500 uppercase tracking-widest mt-0.5">Neural Synthesis Input</p>
              </div>
              </div>

              <div className="flex items-center gap-2">
                <button
                  onClick={() => setGuideOpen((v) => !v)}
                  className="rounded-xl border border-blue-500/35 bg-blue-500/10 px-3 py-2 text-[10px] font-black uppercase tracking-[0.18em] text-blue-200 hover:bg-blue-500/20 transition-colors"
                >
                  <span className="inline-flex items-center gap-2"><Lightbulb size={13} /> Inspire Me</span>
                </button>
                <button
                  onClick={materializePrompt}
                  disabled={!effectivePrompt.trim()}
                  className="rounded-xl border border-white/10 bg-white/[0.04] px-3 py-2 text-[10px] font-black uppercase tracking-[0.18em] text-zinc-200 hover:border-white/20 transition-colors disabled:opacity-40"
                >
                  <span className="inline-flex items-center gap-2"><BrainCircuit size={13} /> Expand Prompt</span>
                </button>
              </div>
            </div>

            <div className="mb-5 grid grid-cols-1 sm:grid-cols-3 gap-3">
              <div className="rounded-2xl border border-white/10 bg-black/30 p-3">
                <div className="flex items-center gap-2 text-blue-200 text-[10px] font-black uppercase tracking-widest"><Gauge size={13} /> Prompt Quality</div>
                <div className="mt-2 flex items-center gap-3">
                  <div className="h-1.5 flex-1 rounded-full bg-white/10 overflow-hidden">
                    <div className="h-full rounded-full bg-gradient-to-r from-blue-600 to-sky-400" style={{ width: `${Math.round(promptQuality * 100)}%` }} />
                  </div>
                  <div className="text-[10px] font-black text-white">{Math.round(promptQuality * 100)}%</div>
                </div>
              </div>
              <div className="rounded-2xl border border-white/10 bg-[var(--gf-panel-bg-strong)]/30 p-3">
                <div className="flex items-center gap-2 text-emerald-200 text-[10px] font-black uppercase tracking-widest"><Rocket size={13} /> Guide Completion</div>
                <div className="mt-2 text-lg font-black text-[var(--foreground)]">{Math.round(guideCompletion * 7)}/7</div>
              </div>
              <div className="rounded-2xl border border-white/10 bg-[var(--gf-panel-bg-strong)]/30 p-3">
                <div className="flex items-center gap-2 text-amber-200 text-[10px] font-black uppercase tracking-widest"><Trophy size={13} /> Recommended</div>
                <div className="mt-2 truncate text-sm font-black text-[var(--foreground)] uppercase italic">{selectedTemplate?.name || selectedTemplate?.title || "Auto-selecting"}</div>
              </div>
            </div>

            {guideOpen ? (
              <div className="mb-6 space-y-4 animate-in fade-in slide-in-from-top-2 duration-300">
                <div className="rounded-2xl border border-blue-500/25 bg-blue-500/10 px-4 py-3 text-[10px] text-blue-100 font-semibold">
                  Inspiration mode active — choisis un preset, une image, ou des paramètres guidés, puis fais <span className="font-black uppercase tracking-widest">Expand Prompt</span>.
                </div>

                <div>
                  <div className="mb-3 text-[9px] font-black uppercase tracking-[0.22em] text-zinc-500">Quick sparks</div>
                  <div className="mb-1 flex flex-wrap gap-2">
                    {QUICK_IDEAS.map((idea) => (
                      <button
                        key={idea}
                        onClick={() => applyQuickIdea(idea)}
                        className="rounded-full border border-white/10 bg-white/[0.03] px-3 py-1.5 text-[10px] font-black uppercase tracking-widest text-zinc-300 hover:border-blue-400/50 hover:text-white transition-colors"
                      >
                        {idea}
                      </button>
                    ))}
                  </div>
                </div>

                <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
                  {INSPIRATION_PRESETS.map((preset) => {
                    const toneClass = preset.tone === "cyan"
                      ? "from-cyan-500/20 to-cyan-500/5 border-cyan-400/25"
                      : preset.tone === "emerald"
                        ? "from-emerald-500/20 to-emerald-500/5 border-emerald-400/25"
                        : "from-blue-500/20 to-blue-500/5 border-blue-400/25";
                    return (
                      <button
                        key={preset.title}
                        onClick={() => applyInspirationPreset(preset.seed)}
                        className={`rounded-2xl border bg-gradient-to-br ${toneClass} p-4 text-left transition-all hover:-translate-y-0.5 hover:shadow-lg`}
                      >
                        <div className="text-[10px] font-black uppercase tracking-widest text-white">{preset.title}</div>
                        <div className="mt-1 text-[10px] text-zinc-300 font-semibold">{preset.subtitle}</div>
                        <div className="mt-3 text-[9px] text-zinc-400 line-clamp-2">{preset.seed}</div>
                      </button>
                    );
                  })}
                </div>

                <div className="rounded-2xl border border-white/10 bg-black/25 p-4">
                  <div className="mb-3 flex items-center justify-between gap-3">
                    <div className="text-[10px] font-black uppercase tracking-[0.2em] text-zinc-300">Visual Inspiration</div>
                    <div className="text-[9px] uppercase tracking-widest text-zinc-500 font-bold">Tap an image to auto-seed your prompt</div>
                  </div>
                  <div className="grid grid-cols-2 sm:grid-cols-3 gap-3">
                    {visualInspiration.map((t, i) => {
                      const key = String(t._id || t.id || `${t.name || t.title}-${i}`);
                      const image = getTemplateImageUrl(t);
                      return (
                        <button
                          key={key}
                          onClick={() => applyVisualInspiration(t)}
                          className="group relative h-24 overflow-hidden rounded-xl border border-white/10 text-left"
                        >
                          <div
                            className="absolute inset-0 bg-cover bg-center transition-transform duration-500 group-hover:scale-110"
                            style={{ backgroundImage: image ? `url(${image})` : undefined, backgroundColor: image ? undefined : "rgba(99,102,241,0.25)" }}
                          />
                          <div className="absolute inset-0 bg-gradient-to-t from-black/90 via-black/25 to-transparent" />
                          <div className="absolute left-2 right-2 bottom-2">
                            <div className="truncate text-[10px] font-black uppercase tracking-wide text-white">{t.name || t.title || "Template"}</div>
                            <div className="truncate text-[9px] font-bold uppercase tracking-widest text-zinc-300/90">{t.category || "general"}</div>
                          </div>
                        </button>
                      );
                    })}
                  </div>
                </div>

                <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
                  <div className="rounded-2xl border border-blue-400/20 bg-blue-500/10 p-3">
                    <div className="text-[9px] font-black uppercase tracking-[0.2em] text-blue-200">Step 1</div>
                    <div className="mt-1 text-sm font-black text-white">Describe your vibe</div>
                    <p className="mt-1 text-[10px] text-zinc-300">Write a short idea or click inspiration cards.</p>
                  </div>
                  <div className="rounded-2xl border border-blue-500/20 bg-blue-600/8 p-3">
                    <div className="text-[9px] font-black uppercase tracking-[0.2em] text-sky-200">Step 2</div>
                    <div className="mt-1 text-sm font-black text-white">AI expands it</div>
                    <p className="mt-1 text-[10px] text-zinc-300">We transform your words into a full production-ready prompt.</p>
                  </div>
                  <div className="rounded-2xl border border-emerald-400/20 bg-emerald-500/10 p-3">
                    <div className="text-[9px] font-black uppercase tracking-[0.2em] text-emerald-200">Step 3</div>
                    <div className="mt-1 text-sm font-black text-white">Pick + launch build</div>
                    <p className="mt-1 text-[10px] text-zinc-300">Best templates are matched, then you go straight to build.</p>
                  </div>
                </div>

                <div className="rounded-2xl border border-blue-500/20 bg-blue-500/5 p-4 space-y-4">
                <div className="flex items-center justify-between">
                  <div className="text-[10px] font-black uppercase tracking-[0.2em] text-blue-200">Guided Creation</div>
                  <button
                    onClick={() => {
                      setGuide(GUIDE_DEFAULTS);
                      setExpandedPrompt("");
                    }}
                    className="text-[9px] font-black uppercase tracking-widest text-zinc-400 hover:text-white"
                  >
                    reset guide
                  </button>
                </div>

                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                  <div className="space-y-2">
                    <p className="text-[9px] font-black uppercase tracking-widest text-zinc-500">Genre</p>
                    <div className="flex flex-wrap gap-2">
                      {["Platformer", "Runner", "Roguelite", "Puzzle"].map((v) => (
                        <button key={v} onClick={() => applyGuideField("genre", v)} className={`rounded-full px-2.5 py-1 text-[9px] font-black uppercase tracking-widest border ${guide.genre === v ? "border-blue-400 bg-blue-500/20 text-blue-100" : "border-white/10 bg-white/[0.03] text-zinc-300"}`}>{v}</button>
                      ))}
                    </div>
                  </div>

                  <div className="space-y-2">
                    <p className="text-[9px] font-black uppercase tracking-widest text-zinc-500">Vibe</p>
                    <div className="flex flex-wrap gap-2">
                      {["Neon", "Dark Fantasy", "Cartoon", "Pixel Retro"].map((v) => (
                        <button key={v} onClick={() => applyGuideField("vibe", v)} className={`rounded-full px-2.5 py-1 text-[9px] font-black uppercase tracking-widest border ${guide.vibe === v ? "border-blue-400 bg-blue-600/20 text-blue-100" : "border-white/10 bg-white/[0.03] text-zinc-300"}`}>{v}</button>
                      ))}
                    </div>
                  </div>

                  <div className="space-y-2">
                    <p className="text-[9px] font-black uppercase tracking-widest text-zinc-500">Pace</p>
                    <div className="flex flex-wrap gap-2">
                      {["Fast", "Tactical", "Chill"].map((v) => (
                        <button key={v} onClick={() => applyGuideField("pace", v)} className={`rounded-full px-2.5 py-1 text-[9px] font-black uppercase tracking-widest border ${guide.pace === v ? "border-emerald-400 bg-emerald-500/20 text-emerald-100" : "border-white/10 bg-white/[0.03] text-zinc-300"}`}>{v}</button>
                      ))}
                    </div>
                  </div>

                  <div className="space-y-2">
                    <p className="text-[9px] font-black uppercase tracking-widest text-zinc-500">Main Mechanic</p>
                    <div className="flex flex-wrap gap-2">
                      {["Wall Jump", "Dash", "Grapple", "Stealth"].map((v) => (
                        <button key={v} onClick={() => applyGuideField("mechanic", v)} className={`rounded-full px-2.5 py-1 text-[9px] font-black uppercase tracking-widest border ${guide.mechanic === v ? "border-amber-400 bg-amber-500/20 text-amber-100" : "border-white/10 bg-white/[0.03] text-zinc-300"}`}>{v}</button>
                      ))}
                    </div>
                  </div>

                  <div className="space-y-2">
                    <p className="text-[9px] font-black uppercase tracking-widest text-zinc-500">Perspective</p>
                    <div className="flex flex-wrap gap-2">
                      {["Side View", "2.5D", "Top-Down"].map((v) => (
                        <button key={v} onClick={() => applyGuideField("perspective", v)} className={`rounded-full px-2.5 py-1 text-[9px] font-black uppercase tracking-widest border ${guide.perspective === v ? "border-cyan-400 bg-cyan-500/20 text-cyan-100" : "border-white/10 bg-white/[0.03] text-zinc-300"}`}>{v}</button>
                      ))}
                    </div>
                  </div>

                  <div className="space-y-2">
                    <p className="text-[9px] font-black uppercase tracking-widest text-zinc-500">Objective</p>
                    <div className="flex flex-wrap gap-2">
                      {["High Score", "Story Levels", "Boss Rush"].map((v) => (
                        <button key={v} onClick={() => applyGuideField("objective", v)} className={`rounded-full px-2.5 py-1 text-[9px] font-black uppercase tracking-widest border ${guide.objective === v ? "border-blue-400 bg-blue-600/20 text-blue-100" : "border-white/10 bg-white/[0.03] text-zinc-300"}`}>{v}</button>
                      ))}
                    </div>
                  </div>

                  <div className="space-y-2">
                    <p className="text-[9px] font-black uppercase tracking-widest text-zinc-500">Difficulty Curve</p>
                    <div className="flex flex-wrap gap-2">
                      {["Casual", "Balanced", "Hardcore"].map((v) => (
                        <button key={v} onClick={() => applyGuideField("difficulty", v)} className={`rounded-full px-2.5 py-1 text-[9px] font-black uppercase tracking-widest border ${guide.difficulty === v ? "border-rose-400 bg-rose-500/20 text-rose-100" : "border-white/10 bg-white/[0.03] text-zinc-300"}`}>{v}</button>
                      ))}
                    </div>
                  </div>
                </div>

                <div className="flex items-center justify-between gap-3 flex-wrap">
                  <div className="text-[10px] text-zinc-400 font-semibold">Pick style bits, then hit <span className="text-blue-300">Expand Prompt</span> for a complete production-ready prompt.</div>
                  <button
                    onClick={materializePrompt}
                    disabled={!effectivePrompt.trim()}
                    className="rounded-xl border border-blue-500/30 bg-blue-500/15 px-3 py-2 text-[10px] font-black uppercase tracking-widest text-blue-100 disabled:opacity-40"
                  >
                    <span className="inline-flex items-center gap-2"><Shuffle size={13} /> Auto-compose</span>
                  </button>
                </div>
              </div>
              </div>
            ) : (
              <div className="mb-6 rounded-2xl border border-white/10 bg-white/[0.03] p-4">
                <div className="text-[10px] font-black uppercase tracking-[0.2em] text-zinc-300">Need inspiration?</div>
                <div className="mt-1 text-[11px] text-zinc-400">Clique <span className="text-blue-300 font-bold">Inspire Me</span> pour ouvrir presets, images et étapes guidées.</div>
              </div>
            )}

            <div className="relative group/input">
              <div className="absolute -inset-0.5 bg-gradient-to-r from-blue-600 to-sky-400 rounded-[22px] opacity-0 group-focus-within/input:opacity-30 blur-md transition-all duration-500" />
              <textarea
                className="gf-input relative w-full rounded-2xl px-6 py-5 text-base bg-[var(--gf-shell-bg)] border-2 border-white/5 placeholder:text-zinc-600 focus:border-blue-500/50 transition-all shadow-2xl min-h-[220px] leading-relaxed font-medium text-[var(--foreground)]"
                value={prompt}
                onChange={(e) => setPrompt(e.target.value)}
                placeholder="Describe your game idea… (e.g. 'neon ninja runner with wall-jumps and combo score')"
              />
            </div>

            {!guideOpen && inlineSuggestions.length ? (
              <div className="mt-4 rounded-2xl border border-white/10 bg-white/[0.03] p-4">
                <div className="text-[9px] font-black uppercase tracking-[0.2em] text-zinc-300">Suggestions</div>
                <div className="mt-2 flex flex-wrap gap-2">
                  {inlineSuggestions.map((s) => (
                    <button
                      key={s}
                      onClick={() => applyQuickIdea(s)}
                      className="rounded-full border border-white/10 bg-white/[0.03] px-3 py-1.5 text-[10px] font-black uppercase tracking-widest text-zinc-300 hover:border-blue-400/50 hover:text-white transition-colors"
                    >
                      {s}
                    </button>
                  ))}
                </div>
              </div>
            ) : null}

            {expandedPrompt ? (
              <div className="mt-4 rounded-xl border border-emerald-500/20 bg-emerald-500/10 px-4 py-3">
                <div className="text-[9px] font-black uppercase tracking-[0.2em] text-emerald-200">Expanded Prompt Ready</div>
                <div className="mt-1 text-xs text-emerald-100/90 line-clamp-3">{expandedPrompt}</div>
              </div>
            ) : null}

            <div className="mt-8 flex items-center justify-between">
              <div className="flex items-center gap-4">
                 {mode === "blueprint" && (
                   <div className="flex items-center gap-2 px-3 py-1.5 rounded-full bg-white/5 border border-white/5">
                     <div className={`h-2 w-2 rounded-full ${suggestLoading ? "bg-blue-500 animate-pulse shadow-[0_0_8px_rgba(99,102,241,1)]" : "bg-emerald-500"}`} />
                     <span className="text-[9px] font-black text-zinc-400 uppercase tracking-widest">
                       {suggestLoading ? "Searching Neural Patterns..." : effectivePrompt.trim().length >= 2 && suggestions.length ? "1 Best match" : "Type a prompt"}
                     </span>
                     {!suggestLoading && suggestions.length > 0 ? (
                       <span className="rounded-full border border-blue-400/30 bg-blue-500/15 px-2 py-0.5 text-[8px] font-black uppercase tracking-widest text-blue-100">
                         Intent: {smartIntent}
                       </span>
                     ) : null}
                   </div>
                 )}
              </div>

              <button
                className="group relative overflow-hidden rounded-2xl bg-white text-black px-10 py-4 font-black uppercase tracking-[0.2em] text-xs shadow-[0_0_40px_rgba(255,255,255,0.1)] transition-all hover:scale-105 active:scale-95 disabled:opacity-50 hover:shadow-[0_0_60px_rgba(255,255,255,0.2)]"
                disabled={loading}
                onClick={handleAction}
              >
                <span className="relative z-10 flex items-center gap-3">
                  {loading ? "Aligning Matrices..." : mode === "scratch" ? (gdd ? "Forge Reality" : "Analyze Vision") : "Spawn Blueprint"} 
                  <ArrowRight size={18} className="group-hover:translate-x-1 transition-transform" />
                </span>
                <div className="absolute inset-0 bg-gradient-to-r from-transparent via-blue-500/10 to-transparent -translate-x-full group-hover:translate-x-full transition-transform duration-1000" />
              </button>
            </div>
          </div>

          {mode === "blueprint" && effectivePrompt.trim().length >= 2 && suggestions.length > 0 && (
            <div className="space-y-4 animate-in fade-in slide-in-from-bottom-4 duration-500">
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                {suggestions.map((t, idx) => {
                  const id = (t._id || t.id || "").toString();
                  const active = id && id === selectedTemplateId;
                  return (
                    <button
                      key={id}
                      onClick={() => {
                        setSelectedTemplateId(active ? "" : id);
                        setTemplatePinned(!active && !!id);
                      }}
                      className={`gf-panel group relative flex items-center gap-4 rounded-[28px] border-2 p-4 text-left transition-all ${
                        active ? "border-blue-500 bg-blue-500/10 shadow-lg" : "border-white/5 hover:border-white/10 bg-white/[0.02]"
                      }`}
                    >
                      <span className="absolute right-3 top-3 rounded-full border border-emerald-400/30 bg-emerald-500/20 px-2 py-0.5 text-[8px] font-black uppercase tracking-widest text-emerald-100">
                        Recommended
                      </span>
                      <div className="h-16 w-16 overflow-hidden rounded-2xl border border-white/10">
                        {getTemplateImageUrl(t) ? (
                          <img src={getTemplateImageUrl(t) || undefined} alt="" className="h-full w-full object-cover transition-transform group-hover:scale-110" />
                        ) : (
                          <div className="h-full w-full bg-gradient-to-br from-blue-600/30 via-sky-500/10 to-cyan-500/10" />
                        )}
                      </div>
                      <div className="flex-1 min-w-0">
                        <div className="truncate text-sm font-black text-[var(--foreground)] italic uppercase tracking-tight">{t.name || t.title || "Untitled Template"}</div>
                        <div className="mt-1 truncate text-[10px] font-bold text-zinc-500 uppercase tracking-widest">{t.category || "general"}</div>
                        <div className="mt-2 inline-flex max-w-full rounded-full border border-blue-400/25 bg-blue-500/10 px-2 py-0.5 text-[8px] font-black uppercase tracking-widest text-blue-100 truncate">
                          Matches {smartIntent} intent
                        </div>
                      </div>
                      {active && <Check size={20} className="text-blue-400" />}
                    </button>
                  );
                })}
              </div>

              {selectedTemplate ? (
                <div className="rounded-[28px] border border-blue-500/30 bg-gradient-to-r from-blue-600/10 via-transparent to-sky-500/10 p-5">
                  <div className="text-[9px] font-black uppercase tracking-[0.2em] text-blue-200">Template Spotlight</div>
                  <div className="mt-2 flex items-center gap-4">
                    <div className="h-14 w-14 overflow-hidden rounded-2xl border border-white/10">
                      {getTemplateImageUrl(selectedTemplate) ? (
                        <img src={getTemplateImageUrl(selectedTemplate) || undefined} alt="" className="h-full w-full object-cover" />
                      ) : (
                        <div className="h-full w-full bg-gradient-to-br from-blue-600/30 via-sky-500/10 to-cyan-500/10" />
                      )}
                    </div>
                    <div className="min-w-0">
                      <div className="truncate text-base font-black text-[var(--foreground)] uppercase italic">{selectedTemplate.name || selectedTemplate.title || "Untitled Template"}</div>
                      <div className="mt-1 text-[10px] font-bold uppercase tracking-widest text-zinc-300">{selectedTemplate.category || "general"}</div>
                    </div>
                  </div>
                  {selectedTemplate.description ? (
                    <div className="mt-3 text-xs text-zinc-300/90 line-clamp-2">{selectedTemplate.description}</div>
                  ) : null}
                  {selectedTemplateId && templateReasons[selectedTemplateId]?.length ? (
                    <div className="mt-3 flex flex-wrap gap-2">
                      {templateReasons[selectedTemplateId].map((r, i) => (
                        <span key={`${selectedTemplateId}-reason-${i}`} className="rounded-full border border-blue-400/25 bg-blue-500/10 px-2 py-1 text-[9px] font-bold text-blue-100">
                          {r}
                        </span>
                      ))}
                    </div>
                  ) : null}
                </div>
              ) : null}
            </div>
          )}
        </div>

        <div className="lg:col-span-4 lg:self-start">
          <div className="lg:sticky lg:top-24 max-h-none lg:max-h-[calc(100vh-7rem)] lg:overflow-y-auto lg:pr-1 space-y-6">
            <div className="gf-panel rounded-[28px] border border-white/[0.07] bg-[var(--gf-panel-bg-strong)] overflow-hidden">
              <div className="flex items-center gap-3 px-6 py-4 border-b border-white/[0.05]">
                <div className="h-7 w-7 rounded-xl bg-sky-500/20 flex items-center justify-center border border-sky-500/25">
                  <Target size={14} className="text-sky-400" />
                </div>
                <h4 className="text-[10px] font-black uppercase tracking-[0.24em] text-white">Forge Journey</h4>
              </div>
              <div className="px-6 py-5 space-y-0">
                {[
                  { label: "Vision captured", desc: "Enter your idea", done: effectivePrompt.trim().length > 0 },
                  { label: "Prompt expanded", desc: "AI enrichment", done: expandedPrompt.trim().length > 0 || promptQuality > 0.65 },
                  { label: "Blueprint selected", desc: "Template chosen", done: !!selectedTemplateId || mode === "scratch" },
                  { label: "Ready to forge", desc: "Hit Spawn Blueprint", done: effectivePrompt.trim().length > 0 && (!!selectedTemplateId || mode === "scratch") },
                ].map((step, i, arr) => (
                  <div key={step.label} className="flex gap-4">
                    <div className="flex flex-col items-center">
                      <div className={`h-8 w-8 rounded-xl border-2 text-[10px] font-black flex items-center justify-center shrink-0 transition-all ${
                        step.done ? "border-sky-500 bg-sky-500/20 text-white shadow-[0_0_12px_rgba(139,92,246,0.3)]" : "border-white/15 bg-white/[0.03] text-zinc-600"
                      }`}>
                        {step.done ? <Check size={14} className="text-sky-300" /> : <span className="text-[10px]">{i + 1}</span>}
                      </div>
                      {i < arr.length - 1 && (
                        <div className={`w-[2px] flex-1 my-1 rounded-full transition-all ${
                          step.done ? "bg-gradient-to-b from-sky-500/60 to-sky-500/10" : "bg-white/[0.05]"
                        }`} style={{ minHeight: "16px" }} />
                      )}
                    </div>
                    <div className={`pb-4 ${i < arr.length - 1 ? "" : ""}`}>
                      <div className={`text-[11px] font-black ${step.done ? "text-white" : "text-zinc-500"}`}>{step.label}</div>
                      <div className="text-[9px] text-zinc-600 uppercase tracking-widest mt-0.5">{step.desc}</div>
                    </div>
                  </div>
                ))}
              </div>
            </div>

            <div className={`rounded-[32px] border overflow-hidden transition-all duration-700 ${mode === "scratch" ? "border-sky-500/20 shadow-[0_0_40px_rgba(139,92,246,0.1)]" : "border-white/[0.06] opacity-70"}`}>
              <div className="flex items-center gap-3 px-6 py-4 border-b border-white/[0.05] bg-gradient-to-r from-sky-500/5 to-transparent">
                <div className="h-7 w-7 rounded-xl bg-sky-500/20 flex items-center justify-center border border-sky-500/25">
                  <Cpu size={14} className="text-sky-400" />
                </div>
                <h4 className="text-[10px] font-black uppercase tracking-[0.3em] text-white">System Engine</h4>
                <div className="ml-auto flex items-center gap-1.5">
                  <motion.div animate={{ opacity: [0.5, 1, 0.5] }} transition={{ duration: 1.5, repeat: Infinity }} className="h-1.5 w-1.5 rounded-full bg-sky-500" />
                  <span className="text-[8px] font-black text-sky-400 uppercase tracking-widest">Active</span>
                </div>
              </div>
              <div className="p-6 space-y-4">
                {[
                  { label: "Logic Engine", value: mode === "scratch" ? "Gemini Neural" : "Blueprint" },
                  { label: "Physics Mode", value: "High Precision", accent: "text-emerald-400" },
                  { label: "Build Target", value: "WebGL 2.0" },
                  { label: "AI Model", value: mode === "scratch" ? "Gemini 1.5 Pro" : "Hybrid", accent: "text-sky-400" },
                ].map((row) => (
                  <div key={row.label} className="flex items-center justify-between">
                    <span className="text-[10px] font-black text-zinc-600 uppercase tracking-widest">{row.label}</span>
                    <span className={`text-[10px] font-black uppercase tracking-tight px-2.5 py-1 rounded-lg bg-white/5 border border-white/[0.06] ${
                      row.accent || "text-white"
                    }`}>{row.value}</span>
                  </div>
                ))}
                <div className="pt-4 border-t border-white/[0.05]">
                  <div className="flex items-center gap-3">
                    <Activity size={14} className="text-sky-500 animate-pulse" />
                    <div className="flex-1 h-1 bg-white/5 rounded-full overflow-hidden">
                      <motion.div
                        animate={{ width: ["30%", "70%", "45%"] }}
                        transition={{ duration: 4, repeat: Infinity, ease: "easeInOut" }}
                        className="h-full bg-gradient-to-r from-sky-600 to-blue-500 rounded-full"
                      />
                    </div>
                  </div>
                  <p className="mt-2 text-[9px] font-black text-zinc-700 uppercase tracking-widest text-center">Neural Link Stable</p>
                </div>
              </div>
            </div>

            {mode === "scratch" && (
              <div className="gf-panel rounded-[24px] p-6 border border-amber-500/20 bg-amber-500/5">
                <div className="flex gap-4">
                  <Zap size={24} className="text-amber-400 shrink-0" />
                  <div>
                    <p className="text-[10px] font-black text-white uppercase tracking-widest mb-1 italic">Pro Tip</p>
                    <p className="text-[10px] text-amber-200/60 leading-relaxed font-bold">
                      Scratch mode generates a full Unity project. This process takes 2-3 minutes as the AI writes unique code for your vision.
                    </p>
                  </div>
                </div>
              </div>
            )}
          </div>
        </div>
      </div>

      {/* GDD Preview Modal */}
      {showGdd && gdd && (
        <div className="fixed inset-0 z-[200] flex items-center justify-center p-6 backdrop-blur-xl bg-black/60">
          <div className="relative w-full max-w-4xl max-h-[90vh] overflow-hidden rounded-[40px] border border-white/10 bg-[var(--gf-bg)] shadow-2xl flex flex-col">
            <div className="p-8 border-b border-white/5 bg-gradient-to-r from-blue-500/10 to-transparent flex items-center justify-between">
              <div>
                <h2 className="text-3xl font-black text-[var(--foreground)] italic uppercase tracking-tighter italic">Game Blueprint</h2>
                <p className="text-xs font-black text-blue-400 uppercase tracking-widest mt-1">Generated Design Specification</p>
              </div>
              <button 
                onClick={() => setShowGdd(false)}
                className="h-12 w-12 rounded-2xl hover:bg-white/5 flex items-center justify-center text-zinc-500 transition-colors"
                disabled={loading}
              >
                <Activity size={24} />
              </button>
            </div>

            <div className="flex-1 overflow-y-auto p-10 space-y-12">
               <div className="grid grid-cols-1 md:grid-cols-2 gap-10">
                 <div className="space-y-6">
                   <div className="space-y-2">
                     <label className="text-[10px] font-black text-zinc-600 uppercase tracking-widest">Project Title</label>
                     <div className="text-2xl font-black text-white italic uppercase tracking-tight">{gdd.title}</div>
                   </div>
                   <div className="space-y-2">
                     <label className="text-[10px] font-black text-zinc-600 uppercase tracking-widest">Abstract</label>
                     <p className="text-sm text-zinc-400 font-bold leading-relaxed">{gdd.description}</p>
                   </div>
                 </div>
                 
                 <div className="grid grid-cols-2 gap-6">
                   <div className="gf-panel rounded-2xl p-4 border border-white/5">
                     <Target className="text-blue-400 mb-3" size={20} />
                     <div className="text-[9px] font-black text-zinc-600 uppercase mb-1">Genre</div>
                     <div className="text-xs font-black text-white uppercase">{gdd.genre}</div>
                   </div>
                   <div className="gf-panel rounded-2xl p-4 border border-white/5">
                     <Zap className="text-amber-500 mb-3" size={20} />
                     <div className="text-[9px] font-black text-zinc-600 uppercase mb-1">Difficulty</div>
                     <div className="text-xs font-black text-white uppercase">{Math.round(gdd.difficulty * 100)}%</div>
                   </div>
                   <div className="gf-panel rounded-2xl p-4 border border-white/5">
                     <Palette className="text-blue-500 mb-3" size={20} />
                     <div className="text-[9px] font-black text-zinc-600 uppercase mb-1">Theme</div>
                     <div className="text-xs font-black text-white uppercase">{gdd.theme}</div>
                   </div>
                   <div className="gf-panel rounded-2xl p-4 border border-white/5">
                     <Cpu className="text-emerald-500 mb-3" size={20} />
                     <div className="text-[9px] font-black text-zinc-600 uppercase mb-1">Speed</div>
                     <div className="text-xs font-black text-white uppercase">{gdd.playerSpeed} m/s</div>
                   </div>
                 </div>
               </div>

               <div className="space-y-6">
                  <label className="text-[10px] font-black text-zinc-600 uppercase tracking-widest flex items-center gap-2">
                    <Activity size={14} /> Core Mechanics
                  </label>
                  <div className="flex flex-wrap gap-3">
                    {gdd.mechanics.map(m => (
                      <span key={m} className="px-4 py-2 rounded-xl bg-white/5 border border-white/5 text-[10px] font-black text-white uppercase tracking-widest">
                        {m}
                      </span>
                    ))}
                  </div>
               </div>

               <div className="grid grid-cols-1 md:grid-cols-2 gap-10 pt-10 border-t border-white/5">
                 <div className="space-y-4">
                   <label className="text-[10px] font-black text-zinc-600 uppercase tracking-widest">Color DNA</label>
                   <div className="flex gap-4">
                     <div className="h-10 flex-1 rounded-xl flex items-center justify-center text-[10px] font-black text-white border border-white/10" style={{ backgroundColor: gdd.primaryColor }}>Primary</div>
                     <div className="h-10 flex-1 rounded-xl flex items-center justify-center text-[10px] font-black text-white border border-white/10" style={{ backgroundColor: gdd.backgroundColor }}>Backdrop</div>
                   </div>
                 </div>
                 <div className="space-y-4">
                   <label className="text-[10px] font-black text-zinc-600 uppercase tracking-widest">Audio Profile</label>
                   <div className="flex items-center gap-3 p-4 bg-white/5 rounded-xl border border-white/5">
                     <Volume2 size={20} className="text-blue-400" />
                     <span className="text-xs font-black text-white uppercase">Atmospheric Synth</span>
                   </div>
                 </div>
               </div>
            </div>

            <div className="p-8 border-t border-white/5 bg-black/40 flex items-center justify-between">
              <button 
                onClick={() => setShowGdd(false)}
                className="text-xs font-black text-zinc-500 uppercase tracking-widest hover:text-white transition-colors"
                disabled={loading}
              >
                Re-Generate Vision
              </button>
              <button 
                onClick={() => finalizeCreate()}
                disabled={loading}
                className="px-10 py-4 rounded-2xl bg-white text-black font-black uppercase tracking-[0.2em] text-xs shadow-2xl hover:scale-105 active:scale-95 transition-all flex items-center gap-3"
              >
                {loading ? "Igniting Forge..." : "Initialize Build Engine"} <Zap size={16} />
              </button>
            </div>
          </div>
        </div>
      )}
    </UserShell>
  );
}
