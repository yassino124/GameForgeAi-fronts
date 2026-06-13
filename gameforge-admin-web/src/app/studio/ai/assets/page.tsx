"use client";
import { useEffect, useRef, useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import UserShell from "@/app/_components/UserShell";
import { apiFetch } from "@/lib/api";
import { useAuthToken } from "@/lib/stores/authStore";

const ASSET_TYPES = [
  { id: "photo_asset",   label: "Photo Asset",    icon: "📸",  desc: "High-quality game asset photo", prompt_hint: "a high-quality game asset photo via Gemini" },
  { id: "svg_sprite",    label: "Game Sprite",    icon: "🧝",  desc: "SVG character/enemy sprite",   prompt_hint: "a pixel-art style game character sprite in SVG" },
  { id: "svg_bg",        label: "Background",     icon: "🌄",  desc: "SVG scene background",          prompt_hint: "a game background scene in SVG" },
  { id: "svg_icon",      label: "UI Icon",        icon: "🎯",  desc: "Game UI icon SVG",              prompt_hint: "a clean game UI icon SVG" },
  { id: "color_palette", label: "Color Palette",  icon: "🎨",  desc: "Game color system",             prompt_hint: "a harmonious color palette for a game" },
  { id: "css_effect",    label: "CSS Effect",     icon: "✨",  desc: "CSS particle / animation",      prompt_hint: "a CSS animation effect for a game" },
  { id: "canvas_art",    label: "Canvas Asset",   icon: "🖼️", desc: "JS Canvas drawing code",        prompt_hint: "JavaScript canvas drawing code for a game asset" },
  { id: "tile_map",      label: "Tile Map",       icon: "🗺️", desc: "SVG tile/map element",         prompt_hint: "an SVG tile map element for a 2D game" },
  { id: "particle",      label: "Particle FX",    icon: "💥",  desc: "CSS/JS particle system",       prompt_hint: "a CSS/JS particle explosion effect" },
];

const GAME_STYLES = [
  { id: "pixel",     label: "Pixel Art",    icon: "👾" },
  { id: "cartoon",   label: "Cartoon",      icon: "🎭" },
  { id: "sci-fi",    label: "Sci-Fi",       icon: "🚀" },
  { id: "fantasy",   label: "Fantasy",      icon: "🧙" },
  { id: "minimal",   label: "Minimal",      icon: "⬜" },
  { id: "neon",      label: "Neon",         icon: "💜" },
];

type Asset = {
  id: string;
  title: string;
  type: string;
  style: string;
  model: string;
  code: string;       // SVG / CSS / JS code
  preview: string;    // rendered preview (for SVG = data URI)
  description: string;
  colors: string[];
  timestamp: number;
};

// Build prompt for each asset type
function buildPrompt(type: string, style: string, userDesc: string, gameContext: string): string {
  const styleDesc = { pixel: "pixel-art 16x16 style", cartoon: "cartoon vector style", "sci-fi": "futuristic sci-fi style", fantasy: "fantasy medieval style", minimal: "clean minimal flat style", neon: "neon cyberpunk glow style" }[style] || style;
  const typeHint = ASSET_TYPES.find(t => t.id === type)?.prompt_hint || "game asset";

  return `You are an expert game asset creator. Generate ${typeHint} for a ${styleDesc} game.
Game context: ${gameContext || "a 2D action game"}
Asset description: ${userDesc}

${type === "color_palette" ? `
Return ONLY a JSON object like:
{"palette": [{"name": "Primary", "hex": "#...", "use": "..."}, ...], "description": "..."}
Generate 6-8 colors with names and usage descriptions.` : `
Return ONLY the raw ${type.includes("svg") ? "SVG" : type.includes("css") ? "CSS" : "JavaScript canvas"} code.
${type.includes("svg") ? "Start with <svg> and end with </svg>. Make it 200x200px. Use ${styleDesc} art style." : ""}
${type.includes("css") ? "Return complete CSS with keyframe animations. Include a .game-effect class." : ""}
${type.includes("canvas") ? "Return a drawAsset(ctx, x, y) function using HTML5 Canvas 2D API." : ""}
No explanations, no markdown fences. ONLY the raw code.`}`;
}

// Extract colors from SVG
function extractColors(svgCode: string): string[] {
  const matches = svgCode.match(/#[0-9a-fA-F]{6}/g) || [];
  return [...new Set(matches)].slice(0, 8);
}

// ─────────────────────────────────────────────────────────────
// PREVIEW COMPONENTS
// ─────────────────────────────────────────────────────────────
function AssetPreview({ asset }: { asset: Asset }) {
  if (asset.type === "photo_asset") {
    return (
      <div className="flex items-center justify-center bg-zinc-900/50 rounded-xl overflow-hidden border border-white/[0.05] min-h-[180px]">
        <img src={asset.code} alt={asset.title} className="w-full object-cover" />
      </div>
    );
  }

  if (asset.type === "color_palette") {
    try {
      const data = JSON.parse(asset.code);
      return (
        <div className="space-y-2">
          {data.palette?.map((c: any) => (
            <div key={c.hex} className="flex items-center gap-3">
              <div className="h-8 w-8 rounded-lg border border-white/10 shrink-0" style={{ backgroundColor: c.hex }} />
              <div>
                <p className="text-[11px] font-bold text-white">{c.name} <span className="text-zinc-500 font-mono">{c.hex}</span></p>
                <p className="text-[10px] text-zinc-600">{c.use}</p>
              </div>
            </div>
          ))}
        </div>
      );
    } catch { return <pre className="text-[10px] text-green-400 font-mono whitespace-pre-wrap">{asset.code}</pre>; }
  }

  if (asset.type.includes("svg")) {
    return (
      <div className="flex items-center justify-center p-4 bg-zinc-900/50 rounded-xl border border-white/[0.05] min-h-[180px]">
        <div dangerouslySetInnerHTML={{ __html: asset.code }} className="max-w-full max-h-[180px] [&_svg]:max-w-full [&_svg]:max-h-[180px]" />
      </div>
    );
  }

  return (
    <pre className="text-[10px] text-green-300 font-mono whitespace-pre-wrap max-h-48 overflow-y-auto gf-scrollbar bg-black/40 rounded-xl p-3 border border-white/[0.05]">
      {asset.code}
    </pre>
  );
}

// ─────────────────────────────────────────────────────────────
// MAIN PAGE
// ─────────────────────────────────────────────────────────────
export default function AssetForgePage() {
  const { token } = useAuthToken();

  const [model, setModel]           = useState("claude");
  const [assetType, setAssetType]   = useState("svg_sprite");
  const [style, setStyle]           = useState("pixel");
  const [desc, setDesc]             = useState("");
  const [gameCtx, setGameCtx]       = useState("");
  const [generating, setGenerating] = useState(false);
  const [error, setError]           = useState<string | null>(null);
  const [ollamaOk, setOllamaOk]     = useState<boolean | null>(null);
  const [assets, setAssets]         = useState<Asset[]>([]);
  const [selected, setSelected]     = useState<Asset | null>(null);
  const [copyDone, setCopyDone]     = useState(false);
  const abortRef = useRef<AbortController | null>(null);

  useEffect(() => {
    checkOllama();
  }, [token]);

  // ── Check Claude health (backend) ──
  const checkOllama = async () => {
    try {
      if (!token) return;
      const res = await apiFetch<any>("/ai/assets/health", { token, signal: AbortSignal.timeout(6000) });
      setOllamaOk(res?.online === true);

      // Keep UI model field in sync with server-advertised models (currently 'claude')
      const models = Array.isArray(res?.models) ? res.models : [];
      if (models.length > 0) setModel(String(models[0]));
    } catch {
      setOllamaOk(false);
    }
  };

  // ── Generate ──
  const generate = async () => {
    if (!desc.trim() || !token) return;
    setGenerating(true); setError(null);
    abortRef.current = new AbortController();
    try {
      const res = await apiFetch<any>("/ai/assets/generate", {
        method: "POST",
        token,
        body: {
          assetType,
          style,
          description: desc,
          gameContext: gameCtx,
        },
        signal: abortRef.current.signal,
      });

      const raw = String(res?.code || "");
      const clean = raw.replace(/```[\w]*\n?/g, "").replace(/```/g, "").trim();

      const typeInfo = ASSET_TYPES.find(t => t.id === assetType);
      const newAsset: Asset = {
        id: Date.now().toString(),
        title: desc.slice(0, 40),
        type: assetType,
        style,
        model: String(res?.model || model || "claude"),
        code: clean,
        preview: assetType.includes("svg") ? `data:image/svg+xml;base64,${btoa(clean)}` : "",
        description: desc,
        colors: assetType.includes("svg") ? extractColors(clean) : [],
        timestamp: Date.now(),
      };
      setAssets(prev => [newAsset, ...prev]);
      setSelected(newAsset);
    } catch (e: any) {
      setError(e.message || "Claude generation failed");
    } finally {
      setGenerating(false);
    }
  };

  const copyCode = () => {
    if (!selected) return;
    navigator.clipboard.writeText(selected.code);
    setCopyDone(true);
    setTimeout(() => setCopyDone(false), 2000);
  };

  const downloadAsset = () => {
    if (!selected) return;

    if (selected.type === "photo_asset") {
      const a = document.createElement("a");
      a.href = selected.code;
      a.download = `gameforge-photo-${selected.id}.png`;
      a.click();
      return;
    }

    const ext = selected.type.includes("svg") ? "svg" : selected.type.includes("css") ? "css" : "js";
    const blob = new Blob([selected.code], { type: "text/plain" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a"); a.href = url;
    a.download = `gameforge-asset-${selected.id}.${ext}`; a.click();
    URL.revokeObjectURL(url);
  };

  const selType = ASSET_TYPES.find(t => t.id === assetType);
  const selModel = assetType === "photo_asset"
    ? { label: "Gemini", color: "#8b5cf6", subtitle: "Gemini Image Generation" }
    : { label: "Claude", color: "#10b981", subtitle: "AgentRouter Claude CLI" };

  return (
    <UserShell title="AssetForge" subtitle="AI Asset Generator · Powered by Claude & Gemini">
      <div className="grid xl:grid-cols-[340px_1fr_320px] lg:grid-cols-[300px_1fr] gap-5 h-full">

        {/* ─── LEFT: Controls ─── */}
        <div className="flex flex-col gap-4 overflow-y-auto gf-scrollbar pr-1">

          {/* Claude Status */}
          <div className="p-3.5 rounded-2xl border border-white/[0.07] bg-white/[0.02] flex items-center justify-between">
            <div className="flex items-center gap-2.5">
              <div className={`h-2.5 w-2.5 rounded-full ${ollamaOk === true ? "bg-emerald-400 animate-pulse" : ollamaOk === false ? "bg-red-400" : "bg-zinc-600"}`} />
              <span className="text-[12px] font-bold text-zinc-400">
                Claude {ollamaOk === true ? "Connected ✓" : ollamaOk === false ? "Offline ✗" : "Not checked"}
              </span>
            </div>
            <button onClick={checkOllama} className="text-[11px] px-3 py-1.5 rounded-lg bg-white/[0.05] hover:bg-white/[0.08] text-zinc-400 hover:text-white transition-all border border-white/[0.07]">
              Check
            </button>
          </div>

          {/* Model selector */}
          <div>
            <p className="text-[10px] font-black uppercase tracking-widest text-zinc-500 mb-2.5">AI Model</p>
            <div className="w-full flex items-center gap-3 p-2.5 rounded-xl border text-left"
              style={{ backgroundColor: `${selModel.color}15`, borderColor: `${selModel.color}50` }}>
              <div className="flex-1 min-w-0">
                <p className="text-[12px] font-bold text-white">{selModel.label}</p>
                <p className="text-[10px] text-zinc-600">{selModel.subtitle}</p>
              </div>
              <span className="text-[9px] font-black px-1.5 py-0.5 rounded-md shrink-0"
                style={{ color: selModel.color, backgroundColor: `${selModel.color}15` }}>
                ACTIVE
              </span>
            </div>
          </div>

          {/* Asset type */}
          <div>
            <p className="text-[10px] font-black uppercase tracking-widest text-zinc-500 mb-2.5">Asset Type</p>
            <div className="grid grid-cols-2 gap-2">
              {ASSET_TYPES.map(t => (
                <button key={t.id} onClick={() => setAssetType(t.id)}
                  className="flex flex-col items-start p-2.5 rounded-xl border text-left transition-all"
                  style={assetType === t.id
                    ? { backgroundColor: "rgba(251,146,60,0.12)", borderColor: "rgba(251,146,60,0.4)" }
                    : { backgroundColor: "rgba(255,255,255,0.02)", borderColor: "rgba(255,255,255,0.07)" }}>
                  <span className="text-base mb-1">{t.icon}</span>
                  <p className="text-[11px] font-bold" style={{ color: assetType === t.id ? "#fb923c" : "#a1a1aa" }}>{t.label}</p>
                  <p className="text-[9px] text-zinc-700 leading-tight">{t.desc}</p>
                </button>
              ))}
            </div>
          </div>

          {/* Style */}
          <div>
            <p className="text-[10px] font-black uppercase tracking-widest text-zinc-500 mb-2.5">Art Style</p>
            <div className="flex flex-wrap gap-2">
              {GAME_STYLES.map(s => (
                <button key={s.id} onClick={() => setStyle(s.id)}
                  className="px-3 py-1.5 rounded-full text-[11px] font-bold border transition-all"
                  style={style === s.id
                    ? { backgroundColor: "rgba(99,102,241,0.2)", borderColor: "rgba(99,102,241,0.5)", color: "#818cf8" }
                    : { backgroundColor: "rgba(255,255,255,0.02)", borderColor: "rgba(255,255,255,0.07)", color: "#71717a" }}>
                  {s.icon} {s.label}
                </button>
              ))}
            </div>
          </div>
        </div>

        {/* ─── CENTER: Generator ─── */}
        <div className="flex flex-col gap-4">
          {/* Description */}
          <div>
            <p className="text-[10px] font-black uppercase tracking-widest text-zinc-500 mb-2">
              {selType?.icon} Describe Your {selType?.label}
            </p>
            <textarea value={desc} onChange={e => setDesc(e.target.value)} rows={3}
              placeholder={`e.g. "A brave knight with a sword and shield, facing right, armored"` }
              className="w-full rounded-xl bg-white/[0.04] border border-white/[0.08] text-white placeholder:text-zinc-600 text-[13px] p-4 outline-none focus:border-orange-500/40 resize-none" />
          </div>

          {/* Game context */}
          <div>
            <p className="text-[10px] font-black uppercase tracking-widest text-zinc-500 mb-2">Game Context (optional)</p>
            <input value={gameCtx} onChange={e => setGameCtx(e.target.value)}
              placeholder='e.g. "Medieval fantasy RPG with dark atmosphere"'
              className="w-full rounded-xl bg-white/[0.04] border border-white/[0.08] text-white placeholder:text-zinc-600 text-[13px] p-3 outline-none focus:border-orange-500/40" />
          </div>

          {/* Error */}
          {error && (
            <div className="p-3 rounded-xl bg-red-500/10 border border-red-500/30 text-[12px] text-red-300">
              ⚠️ {error}
              {error.includes("fetch") && <p className="mt-1 text-red-400/70">Make sure Ollama is running: <code className="bg-black/30 px-1 rounded">ollama serve</code></p>}
            </div>
          )}

          {/* Generate button */}
          <button onClick={generate} disabled={generating || !desc.trim()}
            className="py-4 rounded-xl font-black text-white text-[15px] transition-all disabled:opacity-40 relative overflow-hidden"
            style={{ background: "linear-gradient(135deg, #f97316, #ea580c)", boxShadow: "0 8px 28px rgba(249,115,22,0.35)" }}>
            <motion.div animate={generating ? { opacity: [0.5, 1, 0.5] } : { opacity: 1 }} transition={{ duration: 1.2, repeat: Infinity }}>
              {generating ? (
                <span className="flex items-center justify-center gap-3">
                  <span className="h-5 w-5 rounded-full border-2 border-white/30 border-t-white animate-spin" />
                  {selModel.label} is generating…
                </span>
              ) : `🎨 Generate ${selType?.label} with ${selModel.label}`}
            </motion.div>
          </button>

          {/* Info panel */}
          <div className="p-4 rounded-xl bg-orange-500/[0.06] border border-orange-500/20 text-[12px] space-y-2">
            <p className="font-bold text-orange-300">How Claude generates assets</p>
            <div className="space-y-1 text-orange-400/60">
              <p>• <strong>SVG sprites/bg/icons</strong> → Claude writes SVG code directly → renders instantly in browser</p>
              <p>• <strong>Color palettes</strong> → Returns JSON with hex colors + usage guide</p>
              <p>• <strong>CSS effects</strong> → Generates CSS animations you can paste in your game</p>
              <p>• <strong>Canvas assets</strong> → JS drawAsset() function for HTML5 Canvas</p>
            </div>
            <p className="text-orange-500/50 text-[10px] mt-2">
              Requires backend configured with Claude CLI + <code className="bg-black/30 px-1 rounded">ANTHROPIC_AUTH_TOKEN</code>
            </p>
          </div>

          {/* Generated asset preview */}
          {selected && (
            <motion.div initial={{ opacity: 0, y: 12 }} animate={{ opacity: 1, y: 0 }}
              className="p-4 rounded-2xl bg-white/[0.03] border border-orange-500/20">
              <div className="flex items-center justify-between mb-3">
                <p className="text-[12px] font-bold text-white">{selected.title}</p>
                <div className="flex gap-2">
                  <button onClick={copyCode}
                    className="text-[11px] px-3 py-1.5 rounded-lg bg-white/[0.05] border border-white/[0.08] text-zinc-400 hover:text-white transition-all">
                    {copyDone ? "✓ Copied!" : "📋 Copy"}
                  </button>
                  <button onClick={downloadAsset}
                    className="text-[11px] px-3 py-1.5 rounded-lg bg-orange-500/20 border border-orange-500/30 text-orange-300 hover:bg-orange-500/30 transition-all">
                    ⬇ Download
                  </button>
                </div>
              </div>
              <AssetPreview asset={selected} />
              {selected.colors.length > 0 && (
                <div className="flex gap-1.5 mt-3 flex-wrap">
                  {selected.colors.map(c => (
                    <div key={c} className="flex items-center gap-1.5 px-2 py-1 rounded-lg bg-black/30 border border-white/[0.06]">
                      <div className="h-3 w-3 rounded-full border border-white/20" style={{ backgroundColor: c }} />
                      <span className="text-[9px] font-mono text-zinc-500">{c}</span>
                    </div>
                  ))}
                </div>
              )}
            </motion.div>
          )}
        </div>

        {/* ─── RIGHT: Library ─── */}
        <div className="hidden xl:flex flex-col gap-3">
          <div className="flex items-center justify-between">
            <p className="text-[10px] font-black uppercase tracking-widest text-zinc-500">Asset Library ({assets.length})</p>
            {assets.length > 0 && <button onClick={() => setAssets([])} className="text-[10px] text-zinc-700 hover:text-red-400 transition-colors">Clear</button>}
          </div>

          {assets.length === 0 ? (
            <div className="flex-1 flex flex-col items-center justify-center rounded-2xl bg-white/[0.02] border border-white/[0.05] text-zinc-700 p-8">
              <span className="text-4xl mb-3 opacity-30">🎨</span>
              <p className="text-sm text-center">Generated assets appear here</p>
            </div>
          ) : (
            <div className="flex-1 overflow-y-auto gf-scrollbar space-y-2 pr-1">
              <AnimatePresence>
                {assets.map(a => {
                  const typeInfo = ASSET_TYPES.find(t => t.id === a.type);
                  const isSelected = selected?.id === a.id;
                  return (
                    <motion.button key={a.id} initial={{ opacity: 0, x: 12 }} animate={{ opacity: 1, x: 0 }} exit={{ opacity: 0, x: -8 }}
                      onClick={() => setSelected(a)}
                      className="w-full flex items-start gap-3 p-3 rounded-xl border text-left transition-all"
                      style={isSelected
                        ? { backgroundColor: "rgba(249,115,22,0.1)", borderColor: "rgba(249,115,22,0.4)" }
                        : { backgroundColor: "rgba(255,255,255,0.02)", borderColor: "rgba(255,255,255,0.06)" }}>
                      <span className="text-xl shrink-0">{typeInfo?.icon}</span>
                      <div className="flex-1 min-w-0">
                        <p className="text-[11px] font-bold text-white truncate">{a.title}</p>
                        <p className="text-[10px] text-zinc-600">{typeInfo?.label} · {a.style} · {a.model}</p>
                      </div>
                      {a.colors.length > 0 && (
                        <div className="flex gap-0.5 shrink-0">
                          {a.colors.slice(0, 4).map(c => (
                            <div key={c} className="h-3 w-3 rounded-sm border border-black/20" style={{ backgroundColor: c }} />
                          ))}
                        </div>
                      )}
                    </motion.button>
                  );
                })}
              </AnimatePresence>
            </div>
          )}
        </div>
      </div>
    </UserShell>
  );
}
