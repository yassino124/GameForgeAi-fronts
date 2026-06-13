"use client";
import { useState, useRef, useEffect } from "react";
import { motion, AnimatePresence } from "framer-motion";
import UserShell from "@/app/_components/UserShell";
import { useAuthToken } from "@/lib/stores/authStore";

const GAME_TYPES = [
  { id: "platformer", label: "Platformer", icon: "🏃", color: "#10B981", desc: "Jump & run" },
  { id: "shooter", label: "Shooter", icon: "🚀", color: "#EF4444", desc: "Space shooter" },
  { id: "puzzle", label: "Puzzle", icon: "🧩", color: "#8B5CF6", desc: "Block puzzle" },
  { id: "rpg", label: "RPG", icon: "⚔️", color: "#F59E0B", desc: "Top-down RPG" },
  { id: "arcade", label: "Arcade", icon: "👾", color: "#6366F1", desc: "Classic arcade" },
  { id: "racing", label: "Racing", icon: "🏎️", color: "#F97316", desc: "Top-down race" },
];

const PROMPT = (type: string, desc: string, userPrompt: string) => `You are an expert HTML5 Canvas game developer. Generate a COMPLETE, FULLY WORKING HTML5 game.

GAME TYPE: ${type} — ${desc}
USER REQUEST: "${userPrompt}"

MANDATORY RULES:
1. Output ONLY the raw HTML — NO markdown, NO backticks, NO explanation whatsoever
2. Start exactly with <!DOCTYPE html>
3. Use HTML5 Canvas (id="c", 800x500)
4. Use plain var/function style — NO ES6 classes
5. keyboard: track keys with keydown/keyup into a keys={} object
6. requestAnimationFrame game loop
7. Score + lives display in canvas
8. Game over screen + restart button
9. Web Audio API beep() function for sounds — NO Audio() or .mp3 files
10. Neon/dark visual style with vibrant colors
11. ALL braces must be properly closed — complete, syntactically valid JS

Begin output now with <!DOCTYPE html>:`;

function fixCode(raw: string): string {
  let s = raw.replace(/```html/gi, "").replace(/```javascript/gi, "").replace(/```/g, "").trim();
  const i = s.indexOf("<!DOCTYPE"); if (i > 0) s = s.slice(i);
  if (s.includes("<script>") && !s.includes("</script>")) s += "\n</script></body></html>";
  const e = s.lastIndexOf("</html>"); if (e > 0) s = s.slice(0, e + 7);
  s = s.replace(/new Audio\([^)]*\)/g, "null").replace(/\.play\(\)/g, "/*play*/");
  return s;
}

export default function GameGenPage() {
  const { token } = useAuthToken();
  const [gameType, setGameType] = useState("shooter");
  const [prompt, setPrompt] = useState("");
  const [refining, setRefining] = useState(false);
  const [loading, setLoading] = useState(false);
  const [progress, setProgress] = useState(0);
  const [htmlCode, setHtmlCode] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [tab, setTab] = useState<"preview" | "code">("preview");
  const abortRef = useRef<AbortController | null>(null);

  const sel = GAME_TYPES.find(g => g.id === gameType)!;

  const cancel = () => { abortRef.current?.abort(); setLoading(false); };

  const generate = async () => {
    if (!prompt.trim()) return;
    abortRef.current?.abort();
    const ctrl = new AbortController();
    abortRef.current = ctrl;
    setLoading(true); setError(null); setHtmlCode(""); setProgress(0);

    try {
      // Use our backend proxy which handles Claude CLI via AgentRouter
      const res = await fetch("/api/ai/game-gen/generate-stream", {
        method: "POST",
        signal: ctrl.signal,
        headers: {
          "Content-Type": "application/json",
          ...(token ? { "Authorization": `Bearer ${token}` } : {}),
        },
        body: JSON.stringify({
          prompt: PROMPT(sel.label, sel.desc, prompt),
        }),
      });

      if (!res.ok) {
        const j = await res.json().catch(() => ({}));
        throw new Error(j?.error?.message || `Claude API error ${res.status}`);
      }

      const reader = res.body!.getReader();
      const dec = new TextDecoder();
      let raw = "", chars = 0;
      const TOTAL = 6000;

      while (true) {
        const { done, value } = await reader.read();
        if (done || ctrl.signal.aborted) break;
        const lines = dec.decode(value, { stream: true }).split("\n");
        for (const line of lines) {
          if (!line.startsWith("data: ")) continue;
          const data = line.slice(6).trim();
          if (data === "[DONE]") break;
          try {
            const j = JSON.parse(data);
            const chunk = j?.delta?.text || "";
            if (!chunk) continue;
            raw += chunk; chars += chunk.length;
            setProgress(Math.min(95, Math.round((chars / TOTAL) * 100)));
            if (chars % 500 < chunk.length) {
              const p = fixCode(raw);
              if (p.includes("<canvas") || p.includes("requestAnimationFrame")) setHtmlCode(p);
            }
          } catch { }
        }
      }

      if (ctrl.signal.aborted) return;
      const final = fixCode(raw);
      if (!final.includes("<!DOCTYPE")) throw new Error("Claude did not return valid HTML. Try again.");
      setHtmlCode(final); setProgress(100); setTab("preview");
    } catch (e: any) {
      if (!ctrl.signal.aborted) setError(e.message || "Generation failed");
    } finally {
      setLoading(false);
    }
  };

  const refinePrompt = async () => {
    if (!prompt.trim() || refining) return;
    setRefining(true); setError(null);
    try {
      const res = await fetch("/api/ai/game-gen/refine-prompt", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          ...(token ? { "Authorization": `Bearer ${token}` } : {}),
        },
        body: JSON.stringify({ prompt }),
      });
      const data = await res.json();
      if (data.refined) setPrompt(data.refined);
      else if (data.error) throw new Error(data.error.message);
    } catch (e: any) {
      setError(e.message || "Refinement failed");
    } finally {
      setRefining(false);
    }
  };

  const download = () => {
    const b = new Blob([htmlCode], { type: "text/html" });
    const u = URL.createObjectURL(b);
    const a = document.createElement("a"); a.href = u; a.download = `${gameType}-game.html`; a.click();
    URL.revokeObjectURL(u);
  };

  return (
    <UserShell title="GameGen AI" subtitle="Claude AI → Full HTML5 Game Generator">
      <div className="flex flex-col gap-5 h-full pb-6">

        <div className="grid grid-cols-1 xl:grid-cols-3 gap-5">
          {/* Game Types */}
          <div>
            <p className="text-[10px] font-black uppercase tracking-widest text-zinc-500 mb-3">Game Type</p>
            <div className="grid grid-cols-3 gap-2">
              {GAME_TYPES.map(g => (
                <button key={g.id} onClick={() => setGameType(g.id)}
                  className="flex flex-col items-center gap-1.5 py-3 px-2 rounded-2xl border transition-all"
                  style={{ backgroundColor: gameType === g.id ? g.color + "20" : "rgba(255,255,255,0.02)", borderColor: gameType === g.id ? g.color + "60" : "rgba(255,255,255,0.07)" }}>
                  <span className="text-xl">{g.icon}</span>
                  <span className="text-[10px] font-black text-white">{g.label}</span>
                  <span className="text-[8px] text-zinc-600">{g.desc}</span>
                </button>
              ))}
            </div>
          </div>

          {/* Config */}
          <div className="xl:col-span-2 flex flex-col gap-4">
            <div>
              <div className="flex justify-between items-center mb-2">
                <p className="text-[10px] font-black uppercase tracking-widest text-zinc-500">Describe Your Game</p>
                <button 
                  onClick={refinePrompt} 
                  disabled={!prompt.trim() || refining || loading}
                  className="flex items-center gap-1.5 px-3 py-1 rounded-lg bg-violet-500/10 border border-violet-500/20 text-violet-400 text-[10px] font-black uppercase tracking-widest hover:bg-violet-500/20 transition-all disabled:opacity-40"
                >
                  {refining ? <span className="h-2 w-2 rounded-full border border-t-transparent border-violet-400 animate-spin" /> : "✨"}
                  {refining ? "Refining..." : "AI Refine"}
                </button>
              </div>
              <textarea rows={4} value={prompt} onChange={e => setPrompt(e.target.value)}
                placeholder={`e.g. "Neon ${sel.label.toLowerCase()} with 3 enemy types, boss at wave 5, shield power-up, particle explosions"`}
                className="w-full rounded-2xl bg-white/[0.03] border border-white/[0.07] text-white placeholder:text-zinc-600 text-sm p-4 outline-none focus:border-violet-500/40 resize-none transition-colors"
              />
            </div>

            {error && (
              <div className="p-3 rounded-xl bg-red-500/10 border border-red-500/20 text-red-400 text-xs whitespace-pre-line">⚠️ {error}</div>
            )}

            <AnimatePresence>
              {loading && (
                <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} className="space-y-2">
                  <div className="flex justify-between text-[11px]">
                    <span className="text-zinc-400 font-bold flex items-center gap-2">
                      <span className="h-3 w-3 rounded-full border-2 border-t-violet-400 border-violet-400/20 animate-spin inline-block" />
                      Claude generating… {progress}%
                    </span>
                    <span className="text-zinc-600">~10-30 seconds</span>
                  </div>
                  <div className="h-1.5 rounded-full bg-white/5 overflow-hidden">
                    <motion.div className="h-full rounded-full" animate={{ width: `${progress}%` }}
                      style={{ background: `linear-gradient(90deg, ${sel.color}, #8B5CF6)` }} transition={{ duration: 0.3 }} />
                  </div>
                </motion.div>
              )}
            </AnimatePresence>

            <div className="flex gap-3">
              <button onClick={generate} disabled={loading || !prompt.trim()}
                className="flex-1 py-4 rounded-2xl font-black text-white text-sm uppercase tracking-widest transition-all disabled:opacity-40 flex items-center justify-center gap-3"
                style={{ background: loading || !prompt.trim() ? "rgba(255,255,255,0.05)" : `linear-gradient(135deg, ${sel.color}, #8B5CF6)`, boxShadow: !loading && prompt.trim() ? `0 8px 30px ${sel.color}40` : "none" }}>
                {loading
                  ? <><span className="h-4 w-4 rounded-full border-2 border-white/30 border-t-white animate-spin" />Generating…</>
                  : `${sel.icon} Generate ${sel.label} Game`}
              </button>
              {loading && (
                <button onClick={cancel} className="px-5 py-4 rounded-2xl font-black text-sm bg-red-500/20 border border-red-500/40 text-red-400 hover:bg-red-500/30 transition-all">
                  ✕ Cancel
                </button>
              )}
            </div>

            <div className="p-4 rounded-2xl bg-white/[0.02] border border-white/[0.05] text-[11px] text-zinc-600 space-y-1">
              <p className="font-bold text-zinc-400 mb-1">💡 Claude generates fully working games in ~15 seconds</p>
              <p>• "Neon space shooter, 3 enemy types, boss at wave 5, shield power-up"</p>
              <p>• "Pixel platformer with gravity, coins, spikes and a lava pit"</p>
              <p>• "Retro snake game with power-ups and increasing speed"</p>
            </div>
          </div>
        </div>

        {/* Output */}
        {htmlCode && (
          <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }}
            className="flex-1 flex flex-col rounded-3xl border border-white/10 overflow-hidden" style={{ minHeight: 520 }}>
            <div className="flex items-center gap-3 px-5 py-3 border-b border-white/[0.06] bg-white/[0.02] shrink-0">
              <div className="flex gap-1 bg-white/[0.04] rounded-xl p-1">
                {(["preview", "code"] as const).map(t => (
                  <button key={t} onClick={() => setTab(t)}
                    className={`px-4 py-1.5 rounded-lg text-[11px] font-black uppercase tracking-widest transition-all ${tab === t ? "bg-white/10 text-white" : "text-zinc-600 hover:text-white"}`}>
                    {t === "preview" ? "🎮 Preview" : "💻 Code"}
                  </button>
                ))}
              </div>
              <span className="text-[10px] text-zinc-600 font-mono">{htmlCode.length.toLocaleString()} chars</span>
              <div className="ml-auto flex gap-2">
                <button onClick={() => { const w = window.open("", "_blank"); if (w) { w.document.write(htmlCode); w.document.close(); } }}
                  className="px-3 py-1.5 rounded-xl text-[11px] font-bold bg-white/5 hover:bg-white/10 text-zinc-400 hover:text-white transition-all">
                  ⛶ Fullscreen
                </button>
                <button onClick={() => navigator.clipboard.writeText(htmlCode)}
                  className="px-3 py-1.5 rounded-xl text-[11px] font-bold bg-white/5 hover:bg-white/10 text-zinc-400 hover:text-white transition-all">
                  📋 Copy
                </button>
                <button onClick={download}
                  className="px-4 py-1.5 rounded-xl text-[11px] font-black text-white transition-all"
                  style={{ background: `linear-gradient(135deg, ${sel.color}, #8B5CF6)` }}>
                  ⬇ Download .html
                </button>
              </div>
            </div>
            <div className="flex-1 relative min-h-0">
              {tab === "preview"
                ? <iframe srcDoc={htmlCode} className="w-full h-full border-0 bg-black" sandbox="allow-scripts allow-same-origin" title="Game Preview" />
                : <div className="w-full h-full overflow-auto p-5 bg-black/60">
                  <pre className="text-[11px] text-emerald-400/80 font-mono whitespace-pre-wrap leading-relaxed">{htmlCode}</pre>
                </div>}
            </div>
          </motion.div>
        )}

        {!htmlCode && !loading && (
          <div className="flex-1 flex flex-col items-center justify-center border border-dashed border-white/[0.06] rounded-3xl text-zinc-700 gap-3 py-16">
            <span className="text-5xl">🎮</span>
            <p className="text-sm font-bold">Powered by Claude — generates working games every time</p>
            <p className="text-xs">Pick a game type, describe it, and hit Generate</p>
          </div>
        )}
      </div>
    </UserShell>
  );
}
