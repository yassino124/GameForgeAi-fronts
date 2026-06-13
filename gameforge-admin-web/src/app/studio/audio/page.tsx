"use client";

import { useEffect, useRef, useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import {
  Music, Zap, Heart, Trash2, Copy, RefreshCw,
  Loader2, AlertCircle, CheckCircle2, Headphones,
  Play, Pause, Download,
} from "lucide-react";
import UserShell from "@/app/_components/UserShell";
import { API_BASE_URL, apiFetch } from "@/lib/api";
import { useAuthToken } from "@/lib/stores/authStore";

const GENRES = [
  { id: "epic",      label: "Epic",      icon: "⚔️",  color: "#EF4444" },
  { id: "chill",     label: "Chill",     icon: "🌊",  color: "#0EA5E9" },
  { id: "horror",    label: "Horror",    icon: "👻",  color: "#8B5CF6" },
  { id: "action",    label: "Action",    icon: "🔥",  color: "#F97316" },
  { id: "adventure", label: "Adventure", icon: "🗺️",  color: "#10B981" },
  { id: "puzzle",    label: "Puzzle",    icon: "🧩",  color: "#6366F1" },
  { id: "retro",     label: "Retro",     icon: "👾",  color: "#F59E0B" },
];

const GENRE_SYNTH: Record<string, { wave: OscillatorType; freq: number; dur: number; harmony?: number }> = {
  epic:      { wave: "sawtooth", freq: 110,  dur: 4, harmony: 1.5  },
  chill:     { wave: "sine",     freq: 220,  dur: 5, harmony: 1.25 },
  horror:    { wave: "square",   freq: 55,   dur: 4, harmony: 1.5  },
  action:    { wave: "sawtooth", freq: 165,  dur: 3, harmony: 2    },
  adventure: { wave: "triangle", freq: 196,  dur: 4, harmony: 1.5  },
  puzzle:    { wave: "sine",     freq: 330,  dur: 4, harmony: 1.25 },
  retro:     { wave: "square",   freq: 262,  dur: 3, harmony: 2    },
};

type Track = {
  _id?: string; id?: string; title: string; type: string; genre: string;
  prompt: string; status: string; isFavorite: boolean; duration?: number;
  waveformData?: number[]; fileUrl?: string;
};

function WaveformBar({ data, color, playing }: { data: number[]; color: string; playing: boolean }) {
  return (
    <div className="flex items-center gap-[2px] h-8">
      {data.slice(0, 40).map((v, i) => (
        <div key={i} className="flex-1 rounded-sm"
          style={{
            height: `${Math.max(8, v * 100)}%`,
            backgroundColor: color + (playing ? "cc" : "55"),
            transition: `height 0.3s ease ${i * 20}ms, background-color 0.3s ease`,
          }}
        />
      ))}
    </div>
  );
}

export default function SoundForgePage() {
  const { token } = useAuthToken();

  const [library,    setLibrary]    = useState<Track[]>([]);
  const [loadingLib, setLoadingLib] = useState(false);
  const [type,       setType]       = useState<"music" | "sfx">("music");
  const [genre,      setGenre]      = useState("epic");
  const [prompt,     setPrompt]     = useState("");
  const [generating, setGenerating] = useState(false);
  const [genError,   setGenError]   = useState<string | null>(null);
  const [genSuccess, setGenSuccess] = useState(false);
  const [newId,      setNewId]      = useState<string | null>(null);
  const [ollamaOk,   setOllamaOk]  = useState<boolean | null>(null);
  const [playingId,  setPlayingId]  = useState<string | null>(null);
  const [isPlaying,  setIsPlaying]  = useState(false);
  const [dlLoading,  setDlLoading]  = useState<Record<string, boolean>>({});

  const audioRef      = useRef<HTMLAudioElement | null>(null);
  const audioCtxRef   = useRef<AudioContext | null>(null);
  const synthRef      = useRef<AudioNode[]>([]);

  const selGenre = GENRES.find(g => g.id === genre) ?? GENRES[0];

  useEffect(() => { loadLibrary(); checkOllama(); }, [token]);
  useEffect(() => () => stopAll(), []);

  async function checkOllama() {
    try {
      // Claude availability proxy (AgentRouter key present server-side)
      const res = await apiFetch<any>("/ai/assets/health", { token });
      setOllamaOk(res?.online === true);
    } catch { setOllamaOk(false); }
  }

  function resolveMediaUrl(raw?: string) {
    const s = String(raw || "").trim();
    if (!s) return "";
    if (/^https?:\/\//i.test(s)) return s;
    // Backend often returns relative paths. API_BASE_URL ends with /api.
    const origin = API_BASE_URL.replace(/\/api\/?$/i, "");
    return s.startsWith("/") ? `${origin}${s}` : `${origin}/${s}`;
  }

  function authHeadersForUrl(url: string) {
    if (!token) return undefined;
    try {
      const u = new URL(url);
      const apiOrigin = new URL(API_BASE_URL).origin;
      if (u.origin === apiOrigin) {
        return { Authorization: `Bearer ${token}` };
      }
    } catch {
      // ignore
    }
    return undefined;
  }

  async function fetchAuthedBlobUrl(rawUrl: string) {
    const url = resolveMediaUrl(rawUrl);
    const headers = authHeadersForUrl(url);
    const resp = await fetch(url, { headers });
    if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
    const blob = await resp.blob();
    return URL.createObjectURL(blob);
  }

  async function loadLibrary() {
    if (!token) return;
    setLoadingLib(true);
    try {
      const res = await apiFetch<any>("/audio/library", { token });
      setLibrary(Array.isArray(res) ? res : (Array.isArray(res?.data) ? res.data : []));
    } catch { setLibrary([]); } finally { setLoadingLib(false); }
  }

  async function generate() {
    if (!prompt.trim() || !token) return;
    setGenerating(true); setGenError(null); setGenSuccess(false); setNewId(null);
    try {
      const res = await apiFetch<any>("/audio/generate", {
        method: "POST", token,
        body: { type, genre, prompt: prompt.trim(), projectId: "library" },
      });
      const id = String(res?._id ?? res?.id ?? res?.data?._id ?? res?.data?.id ?? "");
      setPrompt(""); setGenSuccess(true);
      await loadLibrary();
      if (id) { setNewId(id); setTimeout(() => setNewId(null), 8000); }
      setTimeout(() => setGenSuccess(false), 3000);
    } catch (e: any) {
      setGenError(e.message ?? "Generation failed");
    } finally { setGenerating(false); }
  }

  function stopAll() {
    if (audioRef.current) { audioRef.current.pause(); audioRef.current = null; }
    synthRef.current.forEach(n => { try { (n as any).stop?.(); } catch {} });
    synthRef.current = [];
    setIsPlaying(false); setPlayingId(null);
  }

  async function playTrack(track: Track) {
    const id = String(track._id ?? track.id ?? "");
    if (playingId === id && isPlaying) { stopAll(); return; }
    stopAll(); setPlayingId(id);

    if (track.fileUrl) {
      try {
        const blobUrl = await fetchAuthedBlobUrl(track.fileUrl);
        const audio = new Audio(blobUrl);
        audioRef.current = audio;
        audio.onended = () => {
          try { URL.revokeObjectURL(blobUrl); } catch {}
          setIsPlaying(false); setPlayingId(null);
        };
        audio.onerror = () => {
          try { URL.revokeObjectURL(blobUrl); } catch {}
          setIsPlaying(false); setPlayingId(null);
        };
        await audio.play().catch(() => {
          try { URL.revokeObjectURL(blobUrl); } catch {}
          setIsPlaying(false); setPlayingId(null);
        });
        setIsPlaying(true);
      } catch {
        setIsPlaying(false);
        setPlayingId(null);
      }
    } else {
      // ── Smart Web Audio Synthesis ──
      // Reads keywords from prompt + title to generate a contextual sound
      const ctx = new ((window as any).AudioContext || (window as any).webkitAudioContext)();
      audioCtxRef.current = ctx;
      const t = ctx.currentTime;
      const text = (track.title + " " + track.prompt).toLowerCase();
      const nodes: AudioNode[] = [];
      let dur = 2;

      const masterGain = ctx.createGain();
      masterGain.gain.setValueAtTime(0.4, t);
      masterGain.connect(ctx.destination);

      // ── Helper: make oscillator ──
      const osc = (freq: number, type: OscillatorType, gainVal: number, start: number, end: number) => {
        const o = ctx.createOscillator();
        const g = ctx.createGain();
        o.type = type;
        o.frequency.setValueAtTime(freq, t + start);
        g.gain.setValueAtTime(0, t + start);
        g.gain.linearRampToValueAtTime(gainVal, t + start + 0.01);
        g.gain.linearRampToValueAtTime(0, t + end);
        o.connect(g); g.connect(masterGain);
        o.start(t + start); o.stop(t + end);
        nodes.push(o);
      };

      // ── Helper: noise burst (SFX) ──
      const noise = (gainVal: number, start: number, end: number, lpFreq = 4000) => {
        const buf = ctx.createBuffer(1, ctx.sampleRate * (end - start), ctx.sampleRate);
        const data = buf.getChannelData(0);
        for (let i = 0; i < data.length; i++) data[i] = Math.random() * 2 - 1;
        const src = ctx.createBufferSource();
        src.buffer = buf;
        const lp = ctx.createBiquadFilter();
        lp.type = "lowpass"; lp.frequency.setValueAtTime(lpFreq, t);
        const g = ctx.createGain();
        g.gain.setValueAtTime(gainVal, t + start);
        g.gain.exponentialRampToValueAtTime(0.001, t + end);
        src.connect(lp); lp.connect(g); g.connect(masterGain);
        src.start(t + start); src.stop(t + end);
        nodes.push(src as any);
      };

      // ── Classify sound type from keywords ──
      const has = (...words: string[]) => words.some(w => text.includes(w));

      if (track.type === "sfx" || has("sfx", "sound effect", "effect")) {
        // SFX synthesis based on keyword detection
        if (has("shoot", "gun", "shot", "bullet", "laser", "fire", "blast")) {
          // Gunshot / laser: sharp transient + decay
          dur = 0.8;
          noise(0.8, 0, 0.05, 8000);           // sharp crack
          noise(0.4, 0, 0.3, 1200);            // body rumble
          osc(80, "sine", 0.6, 0, 0.15);       // low thump
          osc(2400, "sawtooth", 0.3, 0, 0.08); // zap

        } else if (has("explosion", "boom", "bomb", "blast", "nuke")) {
          // Explosion: low rumble + noise
          dur = 2.5;
          noise(1.0, 0, 2, 800);
          noise(0.6, 0, 1.5, 200);
          osc(40, "sine", 0.8, 0, 0.8);
          osc(60, "sine", 0.5, 0.1, 1.5);

        } else if (has("jump", "bounce", "hop", "spring")) {
          // Jump: upward sweep
          dur = 0.5;
          const o = ctx.createOscillator();
          const g = ctx.createGain();
          o.type = "sine";
          o.frequency.setValueAtTime(300, t);
          o.frequency.linearRampToValueAtTime(900, t + 0.3);
          g.gain.setValueAtTime(0.5, t);
          g.gain.linearRampToValueAtTime(0, t + 0.5);
          o.connect(g); g.connect(masterGain);
          o.start(t); o.stop(t + 0.5);
          nodes.push(o);

        } else if (has("coin", "pick", "collect", "reward", "ding", "chime", "ping")) {
          // Coin pickup: bright chime
          dur = 0.8;
          osc(1046, "sine", 0.6, 0, 0.4);
          osc(1318, "sine", 0.4, 0.05, 0.5);
          osc(1568, "sine", 0.3, 0.1, 0.7);

        } else if (has("hit", "damage", "impact", "punch", "slap", "thud")) {
          // Impact
          dur = 0.5;
          noise(0.7, 0, 0.1, 3000);
          osc(120, "sine", 0.8, 0, 0.15);
          osc(60, "sine", 0.5, 0, 0.3);

        } else if (has("death", "die", "game over", "fail", "lose")) {
          // Game over: descending
          dur = 1.5;
          const o = ctx.createOscillator();
          const g = ctx.createGain();
          o.type = "sawtooth";
          o.frequency.setValueAtTime(440, t);
          o.frequency.linearRampToValueAtTime(110, t + 1.2);
          g.gain.setValueAtTime(0.4, t);
          g.gain.linearRampToValueAtTime(0, t + 1.5);
          o.connect(g); g.connect(masterGain);
          o.start(t); o.stop(t + 1.5);
          nodes.push(o);

        } else if (has("powerup", "level up", "upgrade", "win", "victory", "success")) {
          // Power-up: ascending fanfare
          dur = 1.2;
          [[0, 523], [0.15, 659], [0.3, 784], [0.45, 1046]].forEach(([s, f]) =>
            osc(f as number, "sine", 0.5, s as number, (s as number) + 0.3));

        } else if (has("step", "footstep", "walk", "run", "move")) {
          // Footstep: percussive thud
          dur = 0.3;
          noise(0.6, 0, 0.08, 500);
          osc(80, "sine", 0.7, 0, 0.1);

        } else {
          // Generic SFX: short noise + tone
          dur = 0.6;
          noise(0.5, 0, 0.2, 3000);
          osc(440, "sine", 0.3, 0, 0.4);
        }

      } else {
        // MUSIC synthesis — melodic pattern based on genre
        const genre = track.genre;

        if (genre === "epic" || has("epic", "heroic", "boss", "battle", "war", "fight")) {
          // Epic: brass chord progression
          dur = 5;
          const notes = [130, 165, 196, 247, 294];
          notes.forEach((f, i) => {
            osc(f, "sawtooth", 0.12, i * 0.5, i * 0.5 + 1.5);
            osc(f * 2, "square", 0.05, i * 0.5, i * 0.5 + 1.5);
          });
          noise(0.15, 0, 4, 200); // timpani rumble

        } else if (genre === "chill" || has("chill", "ambient", "calm", "relax", "lo-fi", "soft")) {
          // Chill: soft pad chords
          dur = 6;
          const chords = [[261, 329, 392], [220, 277, 330], [293, 370, 440]];
          chords.forEach((chord, i) =>
            chord.forEach(f => osc(f, "sine", 0.08, i * 1.8, i * 1.8 + 2.5)));

        } else if (genre === "horror" || has("horror", "scary", "dark", "eerie", "creep")) {
          // Horror: dissonant cluster
          dur = 5;
          [55, 58, 65, 73].forEach((f, i) => {
            osc(f, "sawtooth", 0.1, i * 0.3, 5);
            osc(f * 2.01, "square", 0.06, i * 0.3, 5); // slight detune = dissonance
          });
          noise(0.08, 0, 5, 300);

        } else if (genre === "action" || has("action", "fast", "intense", "driving")) {
          // Action: fast arpeggios
          dur = 4;
          const arp = [220, 277, 330, 440, 554, 440, 330, 277];
          arp.forEach((f, i) => osc(f, "sawtooth", 0.15, i * 0.25, i * 0.25 + 0.3));
          noise(0.2, 0, 0.1, 800); // kick
          [0, 0.5, 1, 1.5, 2, 2.5, 3, 3.5].forEach(s => noise(0.15, s, s + 0.05, 800));

        } else if (genre === "puzzle" || has("puzzle", "quirky", "playful")) {
          // Puzzle: xylophone-like bells
          dur = 4;
          const melody = [523, 659, 784, 659, 523, 784, 880, 784];
          melody.forEach((f, i) => osc(f, "sine", 0.3, i * 0.35, i * 0.35 + 0.25));

        } else if (genre === "retro" || has("retro", "8-bit", "chiptune", "pixel", "nes")) {
          // Retro: chip tune square wave melody
          dur = 4;
          const chip = [262, 294, 330, 349, 392, 440, 494, 523];
          chip.forEach((f, i) => osc(f, "square", 0.2, i * 0.25, i * 0.25 + 0.22));

        } else {
          // Adventure / default: folk melody
          dur = 5;
          const folk = [293, 329, 369, 440, 369, 329, 261, 293];
          folk.forEach((f, i) => osc(f, "triangle", 0.2, i * 0.4, i * 0.4 + 0.45));
        }
      }

      synthRef.current = nodes;
      setIsPlaying(true);
      setTimeout(() => { setIsPlaying(false); setPlayingId(null); }, dur * 1000);
    }
  }


  async function downloadTrack(track: Track) {
    const id = String(track._id ?? track.id ?? "");
    if (track.fileUrl) {
      setDlLoading(p => ({ ...p, [id]: true }));
      try {
        const url = resolveMediaUrl(track.fileUrl);
        const headers = authHeadersForUrl(url);
        const resp = await fetch(url, { headers });
        if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
        const blob = await resp.blob();
        const ext  = url.endsWith(".wav") ? "wav" : "mp3";
        const objUrl  = URL.createObjectURL(blob);
        const a    = document.createElement("a");
        a.href = objUrl;
        a.download = `${track.title.replace(/[^a-z0-9]/gi, "_")}.${ext}`;
        a.click();
        URL.revokeObjectURL(objUrl);
      } finally { setDlLoading(p => ({ ...p, [id]: false })); }
    } else {
      // ── Render synth to WAV using OfflineAudioContext ──
      setDlLoading(p => ({ ...p, [id]: true }));
      try {
        const text    = (track.title + " " + track.prompt).toLowerCase();
        const has     = (...w: string[]) => w.some(x => text.includes(x));
        const isSFX   = track.type === "sfx" || has("sfx", "effect");
        const durSec  = isSFX ? 1.5 : 5;
        const sr      = 44100;
        const offline = new OfflineAudioContext(2, sr * durSec, sr);
        const t       = offline.currentTime;

        const master = offline.createGain();
        master.gain.setValueAtTime(0.6, t);
        master.connect(offline.destination);

        const mkO = (freq: number, type: OscillatorType, g: number, s: number, e: number) => {
          const o  = offline.createOscillator();
          const gn = offline.createGain();
          o.type = type; o.frequency.setValueAtTime(freq, t + s);
          gn.gain.setValueAtTime(0, t + s);
          gn.gain.linearRampToValueAtTime(g, t + s + 0.01);
          gn.gain.linearRampToValueAtTime(0, t + e);
          o.connect(gn); gn.connect(master);
          o.start(t + s); o.stop(t + e);
        };
        const mkN = (g: number, s: number, e: number, lp = 3000) => {
          const buf  = offline.createBuffer(1, sr * (e - s), sr);
          const data = buf.getChannelData(0);
          for (let i = 0; i < data.length; i++) data[i] = Math.random() * 2 - 1;
          const src = offline.createBufferSource();
          src.buffer = buf;
          const f  = offline.createBiquadFilter();
          f.type = "lowpass"; f.frequency.setValueAtTime(lp, t);
          const gn = offline.createGain();
          gn.gain.setValueAtTime(g, t + s);
          gn.gain.exponentialRampToValueAtTime(0.001, t + e);
          src.connect(f); f.connect(gn); gn.connect(master);
          src.start(t + s); src.stop(t + e);
        };

        if (isSFX) {
          if (has("shoot","gun","shot","laser","fire")) { mkN(0.8,0,0.05,8000); mkN(0.4,0,0.4,1200); mkO(80,"sine",0.6,0,0.15); mkO(2400,"sawtooth",0.3,0,0.08); }
          else if (has("explosion","boom","bomb")) { mkN(1,0,1.5,600); mkN(0.5,0,1,200); mkO(40,"sine",0.8,0,0.8); }
          else if (has("jump","bounce","hop")) { const o=offline.createOscillator(); const g=offline.createGain(); o.type="sine"; o.frequency.setValueAtTime(300,t); o.frequency.linearRampToValueAtTime(900,t+0.3); g.gain.setValueAtTime(0.5,t); g.gain.linearRampToValueAtTime(0,t+0.5); o.connect(g); g.connect(master); o.start(t); o.stop(t+0.5); }
          else if (has("coin","collect","ding","chime","ping")) { mkO(1046,"sine",0.6,0,0.4); mkO(1318,"sine",0.4,0.05,0.5); mkO(1568,"sine",0.3,0.1,0.7); }
          else if (has("hit","damage","impact","punch")) { mkN(0.7,0,0.1,3000); mkO(120,"sine",0.8,0,0.15); }
          else if (has("powerup","level up","win","victory")) { [[0,523],[0.15,659],[0.3,784],[0.45,1046]].forEach(([s,f])=>mkO(f,"sine",0.5,s,s+0.3)); }
          else { mkN(0.5,0,0.3,3000); mkO(440,"sine",0.3,0,0.5); }
        } else {
          const g = track.genre;
          if (g==="epic"||has("epic","boss","battle")) { [130,165,196,247,294].forEach((f,i)=>{mkO(f,"sawtooth",0.1,i*0.6,i*0.6+2); mkO(f*2,"square",0.05,i*0.6,i*0.6+2);}); mkN(0.1,0,4,200); }
          else if (g==="chill"||has("chill","calm","ambient")) { [[261,329,392],[220,277,330],[293,370,440]].forEach((c,i)=>c.forEach(f=>mkO(f,"sine",0.07,i*1.5,i*1.5+2.5))); }
          else if (g==="horror"||has("horror","dark","eerie")) { [55,58,65,73].forEach((f,i)=>{mkO(f,"sawtooth",0.09,i*0.3,5); mkO(f*2.01,"square",0.05,i*0.3,5);}); mkN(0.06,0,5,300); }
          else if (g==="action"||has("action","fast","intense")) { [220,277,330,440,554,440,330,277].forEach((f,i)=>mkO(f,"sawtooth",0.15,i*0.25,i*0.25+0.3)); [0,0.5,1,1.5,2,2.5].forEach(s=>mkN(0.15,s,s+0.05,800)); }
          else if (g==="puzzle"||has("puzzle","quirky","playful")) { [523,659,784,659,523,784,880,784].forEach((f,i)=>mkO(f,"sine",0.3,i*0.35,i*0.35+0.25)); }
          else if (g==="retro"||has("retro","8-bit","chiptune")) { [262,294,330,349,392,440,494,523].forEach((f,i)=>mkO(f,"square",0.2,i*0.25,i*0.25+0.22)); }
          else { [293,329,369,440,369,329,261,293].forEach((f,i)=>mkO(f,"triangle",0.2,i*0.4,i*0.4+0.45)); }
        }

        const rendered = await offline.startRendering();

        // Encode to WAV
        const numCh = rendered.numberOfChannels;
        const numSamples = rendered.length;
        const wavBuf = new ArrayBuffer(44 + numSamples * numCh * 2);
        const view = new DataView(wavBuf);
        const writeStr = (off: number, s: string) => { for (let i=0;i<s.length;i++) view.setUint8(off+i, s.charCodeAt(i)); };
        writeStr(0, "RIFF"); view.setUint32(4, 36+numSamples*numCh*2, true); writeStr(8,"WAVE");
        writeStr(12,"fmt "); view.setUint32(16,16,true); view.setUint16(20,1,true);
        view.setUint16(22,numCh,true); view.setUint32(24,sr,true);
        view.setUint32(28,sr*numCh*2,true); view.setUint16(32,numCh*2,true);
        view.setUint16(34,16,true); writeStr(36,"data"); view.setUint32(40,numSamples*numCh*2,true);
        let offset = 44;
        for (let i=0;i<numSamples;i++) {
          for (let ch=0;ch<numCh;ch++) {
            const sample = Math.max(-1,Math.min(1,rendered.getChannelData(ch)[i]));
            view.setInt16(offset, sample<0?sample*0x8000:sample*0x7FFF, true);
            offset += 2;
          }
        }
        const blob = new Blob([wavBuf], { type: "audio/wav" });
        const url  = URL.createObjectURL(blob);
        const a    = document.createElement("a");
        a.href = url;
        a.download = `${track.title.replace(/[^a-z0-9]/gi, "_")}.wav`;
        a.click();
        URL.revokeObjectURL(url);
      } finally { setDlLoading(p => ({ ...p, [id]: false })); }
    }
  }


  async function toggleFav(track: Track) {
    const id = track._id ?? track.id;
    if (!id || !token) return;
    await apiFetch(`/audio/${id}/favorite`, { method: "PATCH", token }).catch(() => {});
    loadLibrary();
  }

  async function del(track: Track) {
    const id = track._id ?? track.id;
    if (!id || !token || !confirm(`Delete "${track.title}"?`)) return;
    await apiFetch(`/audio/${id}`, { method: "DELETE", token }).catch(() => {});
    loadLibrary();
  }

  return (
    <UserShell title="SoundForge" subtitle="AI-powered game audio — Claude (AgentRouter)">
      <div className="grid grid-cols-1 xl:grid-cols-5 gap-8 pb-20">

        {/* ── Generator ── */}
        <div className="xl:col-span-2 space-y-5">

          {/* Claude status */}
          <div className="flex items-center gap-3 px-4 py-3 rounded-2xl bg-white/[0.03] border border-white/5">
            <div className={`h-2 w-2 rounded-full ${ollamaOk === true ? "bg-emerald-400 animate-pulse" : ollamaOk === false ? "bg-red-400" : "bg-zinc-500"}`} />
            <span className="text-[11px] font-black uppercase tracking-widest text-zinc-400">
              Claude {ollamaOk === true ? "Online" : ollamaOk === false ? "Offline" : "Checking…"}
            </span>
            <button onClick={checkOllama} className="ml-auto text-zinc-600 hover:text-white transition-colors">
              <RefreshCw size={13} />
            </button>
          </div>

          {/* Type */}
          <div>
            <p className="text-[10px] font-black uppercase tracking-widest text-zinc-500 mb-3">Type</p>
            <div className="grid grid-cols-2 gap-3">
              {[
                { id: "music", label: "Background Music", icon: <Music size={18} /> },
                { id: "sfx",   label: "Sound Effect",     icon: <Zap size={18} /> },
              ].map(t => (
                <button key={t.id} onClick={() => setType(t.id as any)}
                  className={`flex flex-col items-center gap-2 py-4 rounded-2xl border transition-all ${
                    type === t.id
                      ? "bg-emerald-500/20 border-emerald-500/50 text-emerald-400"
                      : "bg-white/[0.03] border-white/5 text-zinc-500 hover:text-white"
                  }`}>
                  {t.icon}
                  <span className="text-[10px] font-black uppercase tracking-widest">{t.label}</span>
                </button>
              ))}
            </div>
          </div>

          {/* Genre */}
          <div>
            <p className="text-[10px] font-black uppercase tracking-widest text-zinc-500 mb-3">Genre</p>
            <div className="grid grid-cols-4 gap-2">
              {GENRES.map(g => (
                <button key={g.id} onClick={() => setGenre(g.id)}
                  style={{
                    borderColor: genre === g.id ? g.color + "80" : undefined,
                    backgroundColor: genre === g.id ? g.color + "18" : undefined,
                  }}
                  className={`flex flex-col items-center gap-1 py-3 rounded-xl border transition-all text-[11px] font-black ${
                    genre === g.id ? "text-white" : "border-white/5 text-zinc-500 hover:text-white bg-white/[0.02]"
                  }`}>
                  <span className="text-lg">{g.icon}</span>
                  {g.label}
                </button>
              ))}
            </div>
          </div>

          {/* Prompt */}
          <div>
            <p className="text-[10px] font-black uppercase tracking-widest text-zinc-500 mb-3">Describe Your Sound</p>
            <textarea rows={4} value={prompt} onChange={e => setPrompt(e.target.value)}
              placeholder={`e.g. "Boss fight with heavy ${selGenre.label.toLowerCase()} brass and pounding drums"`}
              className="w-full bg-white/[0.03] border border-white/5 rounded-2xl px-5 py-4 text-sm text-white placeholder:text-zinc-600 resize-none focus:outline-none focus:border-emerald-500/40 transition-colors"
            />
          </div>

          {/* Feedback */}
          <AnimatePresence>
            {genError && (
              <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}
                className="flex items-start gap-3 p-4 rounded-2xl bg-red-500/10 border border-red-500/20 text-red-400 text-sm">
                <AlertCircle size={16} className="mt-0.5 shrink-0" />{genError}
              </motion.div>
            )}
            {genSuccess && (
              <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}
                className="flex items-center gap-3 p-4 rounded-2xl bg-emerald-500/10 border border-emerald-500/20 text-emerald-400 text-sm">
                <CheckCircle2 size={16} /> Track added — look for <strong>NEW ✨</strong> in the library
              </motion.div>
            )}
          </AnimatePresence>

          {/* Generate button */}
          <button onClick={generate} disabled={generating || !prompt.trim()}
            className="w-full py-4 rounded-2xl font-black text-sm uppercase tracking-widest transition-all disabled:opacity-40 disabled:cursor-not-allowed flex items-center justify-center gap-3"
            style={{ background: generating || !prompt.trim() ? "rgba(255,255,255,0.05)" : "linear-gradient(135deg,#10B981,#0EA5E9)" }}>
            {generating ? <><Loader2 size={18} className="animate-spin" /> Claude composing…</> : <><Music size={18} /> Generate Audio</>}
          </button>

          {/* Info box */}
          <div className="p-4 rounded-2xl bg-emerald-500/5 border border-emerald-500/10 space-y-2">
            <p className="text-[10px] font-black uppercase tracking-widest text-emerald-500">Claude-First · AgentRouter</p>
            <p className="text-xs text-zinc-500 leading-relaxed">
              Claude rewrites your description into a Suno-style prompt.
              If <code className="text-zinc-400 bg-white/5 px-1 rounded">SUNO_API_KEY</code> is set → real MP3.
              Otherwise → ▶ plays a synth preview, ⬇ copies prompt and opens suno.ai.
            </p>
            <code className="text-[10px] text-zinc-600 block pt-1">Requires Claude CLI + ANTHROPIC_AUTH_TOKEN</code>
          </div>
        </div>

        {/* ── Library ── */}
        <div className="xl:col-span-3 space-y-4">
          <div className="flex items-center justify-between">
            <span className="text-[10px] font-black uppercase tracking-widest text-zinc-500 flex items-center gap-2">
              <Headphones size={13} /> Library · {library.length} tracks
            </span>
            <button onClick={loadLibrary} className="text-zinc-600 hover:text-white transition-colors">
              <RefreshCw size={14} />
            </button>
          </div>

          {loadingLib ? (
            <div className="flex items-center justify-center h-48 text-zinc-600">
              <Loader2 size={24} className="animate-spin" />
            </div>
          ) : library.length === 0 ? (
            <div className="flex flex-col items-center justify-center h-48 text-zinc-600 gap-3 border border-dashed border-white/5 rounded-3xl">
              <span className="text-4xl">🎧</span>
              <p className="text-sm">No tracks yet — generate your first!</p>
            </div>
          ) : (
            <div className="space-y-3">
              {library.map((track, i) => {
                const id      = String(track._id ?? track.id ?? i);
                const g       = GENRES.find(x => x.id === track.genre) ?? GENRES[0];
                const isNew   = newId === id;
                const playing = playingId === id && isPlaying;
                const isDl    = dlLoading[id] === true;
                const hasFile = !!track.fileUrl;

                return (
                  <motion.div key={id}
                    initial={{ opacity: 0, y: 10 }}
                    animate={{ opacity: 1, y: 0 }}
                    transition={{ delay: Math.min(i * 0.03, 0.25) }}
                    className={`group p-5 rounded-2xl border transition-all duration-300 ${
                      isNew
                        ? "bg-emerald-500/10 border-emerald-500/40 shadow-[0_0_24px_rgba(16,185,129,0.18)]"
                        : playing
                          ? "bg-white/[0.04] border-white/15"
                          : "bg-white/[0.02] border-white/5 hover:border-white/10"
                    }`}>
                    <div className="flex items-start gap-4">

                      {/* Icon */}
                      <div className="h-11 w-11 rounded-xl flex items-center justify-center text-xl shrink-0 relative"
                        style={{ background: g.color + "22" }}>
                        {g.icon}
                        {playing && (
                          <span className="absolute -bottom-1 -right-1 h-3 w-3 rounded-full bg-emerald-400 border-2 border-[#070810] animate-pulse" />
                        )}
                      </div>

                      {/* Text */}
                      <div className="flex-1 min-w-0">
                        <div className="flex items-center gap-2 mb-1 flex-wrap">
                          <span className="text-sm font-bold text-white truncate">{track.title}</span>
                          {isNew && (
                            <span className="text-[8px] font-black uppercase tracking-wider text-white bg-emerald-500 px-2 py-0.5 rounded-full">
                              NEW ✨
                            </span>
                          )}
                          {track.status === "ready" && !isNew && (
                            <span className="text-[9px] font-black text-emerald-400 bg-emerald-500/10 px-2 py-0.5 rounded-full">Ready</span>
                          )}
                          {track.status === "generating" && (
                            <span className="text-[9px] font-black text-amber-400 bg-amber-500/10 px-2 py-0.5 rounded-full flex items-center gap-1">
                              <Loader2 size={8} className="animate-spin" /> Generating
                            </span>
                          )}
                          {track.status === "error" && (
                            <span className="text-[9px] font-black text-red-400 bg-red-500/10 px-2 py-0.5 rounded-full">Error</span>
                          )}
                        </div>

                        <div className="text-[10px] text-zinc-500 mb-2">
                          {track.type.toUpperCase()} · {g.label} · {track.duration ?? 30}s
                          {hasFile && <span className="ml-2 text-emerald-500/60">· MP3 ✓</span>}
                        </div>

                        {/* Waveform */}
                        {track.waveformData && track.waveformData.length > 0 && (
                          <WaveformBar data={track.waveformData} color={g.color} playing={playing} />
                        )}

                        {/* Prompt */}
                        {track.prompt && (
                          <p className="text-[10px] text-zinc-600 mt-2 line-clamp-2 italic">"{track.prompt}"</p>
                        )}

                        {/* No file hint */}
                        {!hasFile && (
                          <button onClick={() => downloadTrack(track)}
                            className="mt-2 flex items-center gap-1.5 text-[10px] font-bold px-3 py-1.5 rounded-xl"
                            style={{ color: g.color, background: g.color + "18", border: `1px solid ${g.color}44` }}>
                            <Download size={10} /> Copy prompt → paste in suno.ai to get real audio
                          </button>
                        )}
                      </div>

                      {/* Buttons — visible on hover */}
                      <div className="flex flex-col gap-1.5 opacity-0 group-hover:opacity-100 transition-opacity shrink-0">
                        {/* Play */}
                        <button onClick={() => playTrack(track)}
                          title={hasFile ? "Play MP3" : "Play synth genre preview"}
                          className={`p-2 rounded-xl transition-all hover:bg-white/5 ${playing ? "text-emerald-400" : "text-zinc-400 hover:text-white"}`}>
                          {playing ? <Pause size={15} /> : <Play size={15} />}
                        </button>

                        {/* Download */}
                        <button onClick={() => downloadTrack(track)}
                          title={hasFile ? "Download MP3" : "Copy prompt → suno.ai"}
                          disabled={isDl}
                          className="p-2 rounded-xl text-zinc-500 hover:text-white hover:bg-white/5 transition-all disabled:opacity-40">
                          {isDl ? <Loader2 size={15} className="animate-spin" /> : <Download size={15} />}
                        </button>

                        {/* Copy prompt */}
                        <button onClick={() => navigator.clipboard.writeText(track.prompt)}
                          title="Copy Suno prompt"
                          className="p-2 rounded-xl text-zinc-500 hover:text-white hover:bg-white/5 transition-all">
                          <Copy size={15} />
                        </button>

                        {/* Favorite */}
                        <button onClick={() => toggleFav(track)}
                          className={`p-2 rounded-xl hover:bg-white/5 transition-all ${track.isFavorite ? "text-red-400" : "text-zinc-500 hover:text-red-400"}`}>
                          <Heart size={15} fill={track.isFavorite ? "currentColor" : "none"} />
                        </button>

                        {/* Delete */}
                        <button onClick={() => del(track)}
                          className="p-2 rounded-xl text-zinc-500 hover:text-red-400 hover:bg-red-500/5 transition-all">
                          <Trash2 size={15} />
                        </button>
                      </div>
                    </div>
                  </motion.div>
                );
              })}
            </div>
          )}
        </div>
      </div>
    </UserShell>
  );
}
