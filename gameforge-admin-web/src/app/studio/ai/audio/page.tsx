"use client";
import { useState, useCallback, useEffect, useRef } from "react";
import { motion, AnimatePresence } from "framer-motion";
import UserShell from "@/app/_components/UserShell";
import { apiFetch, API_BASE_URL } from "@/lib/api";
import { useAuthToken } from "@/lib/stores/authStore";

const GENRES = [
  { id: "epic",      label: "Epic",      icon: "⚔️",  color: "#f59e0b" },
  { id: "chill",     label: "Chill",     icon: "🌊",  color: "#0ea5e9" },
  { id: "horror",    label: "Horror",    icon: "👻",  color: "#ef4444" },
  { id: "action",    label: "Action",    icon: "🔥",  color: "#f97316" },
  { id: "adventure", label: "Adventure", icon: "🗺️", color: "#10b981" },
  { id: "puzzle",    label: "Puzzle",    icon: "🧩",  color: "#8b5cf6" },
  { id: "retro",     label: "Retro",     icon: "👾",  color: "#6366f1" },
];
const SFX_TYPES = [
  { id: "explosion",   label: "Explosion",   icon: "💥" },
  { id: "laser",       label: "Laser",       icon: "🔫" },
  { id: "collectible", label: "Collect",     icon: "⭐" },
  { id: "jump",        label: "Jump",        icon: "🦘" },
  { id: "powerup",     label: "Power Up",    icon: "⚡" },
  { id: "hit",         label: "Hit",         icon: "💢" },
];

type Track = {
  _id?: string; id?: string; title: string; type: string; genre: string;
  duration: number; waveform?: number[]; waveformData?: number[];
  favorite?: boolean; isFavorite?: boolean;
  prompt?: string; fileUrl?: string; status?: string;
};

/* ── Web Audio API — Real procedural audio per genre ── */
function createAudioContext(): AudioContext {
  return new (window.AudioContext || (window as any).webkitAudioContext)();
}

function playGenreAudio(genre: string, ctx: AudioContext): AudioNode[] {
  const nodes: AudioNode[] = [];
  const now = ctx.currentTime;

  const addOsc = (freq: number, type: OscillatorType, gainVal: number, start: number, end: number, detune = 0) => {
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    const filter = ctx.createBiquadFilter();
    osc.type = type;
    osc.frequency.setValueAtTime(freq, now + start);
    osc.detune.setValueAtTime(detune, now + start);
    gain.gain.setValueAtTime(0, now + start);
    gain.gain.linearRampToValueAtTime(gainVal, now + start + 0.05);
    gain.gain.setValueAtTime(gainVal, now + end - 0.1);
    gain.gain.linearRampToValueAtTime(0, now + end);
    filter.connect(ctx.destination);
    gain.connect(filter);
    osc.connect(gain);
    osc.start(now + start);
    osc.stop(now + end);
    nodes.push(osc, gain);
  };

  const addNoise = (gainVal: number, cutoff: number, start: number, duration: number) => {
    const bufSize = ctx.sampleRate * duration;
    const buf = ctx.createBuffer(1, bufSize, ctx.sampleRate);
    const data = buf.getChannelData(0);
    for (let i = 0; i < bufSize; i++) data[i] = Math.random() * 2 - 1;
    const src = ctx.createBufferSource();
    const gain = ctx.createGain();
    const filter = ctx.createBiquadFilter();
    src.buffer = buf;
    filter.type = "lowpass";
    filter.frequency.value = cutoff;
    gain.gain.setValueAtTime(gainVal, now + start);
    gain.gain.linearRampToValueAtTime(0, now + start + duration);
    src.connect(filter);
    filter.connect(gain);
    gain.connect(ctx.destination);
    src.start(now + start);
    nodes.push(src, gain);
  };

  if (genre === "epic") {
    // Powerful brass + percussion
    [0, 0.5, 1.0, 1.5].forEach(t => {
      addOsc(80, "sawtooth", 0.25, t, t + 0.4, -10);
      addNoise(0.3, 600, t, 0.15);
    });
    addOsc(130.81, "sawtooth", 0.18, 0.0, 2.0);
    addOsc(164.81, "sawtooth", 0.15, 0.5, 2.0);
    addOsc(196.00, "sawtooth", 0.12, 1.0, 2.0);
    addOsc(261.63, "sawtooth", 0.10, 0.0, 2.0, 5);

  } else if (genre === "chill") {
    // Soft lo-fi: sine chords + slow attack
    [[261.63, 0], [329.63, 0.3], [392.00, 0.6], [493.88, 1.0]].forEach(([f, t]) => {
      addOsc(f as number, "sine", 0.10, t as number, 3.0);
    });
    addOsc(130.81, "sine", 0.08, 0, 3.0);
    addOsc(196.00, "triangle", 0.06, 0.5, 3.0);

  } else if (genre === "horror") {
    // Dissonant + eerie
    addOsc(55, "sawtooth", 0.15, 0, 3.0, -30);
    addOsc(58.27, "sawtooth", 0.12, 0.1, 3.0, 30);
    addOsc(110, "sine", 0.08, 0.5, 3.0);
    addNoise(0.04, 300, 0, 3.0);
    [0, 0.7, 1.4, 2.1].forEach(t => addOsc(220, "square", 0.04, t, t + 0.5));

  } else if (genre === "action") {
    // Fast beats + driving rhythm
    [0, 0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75].forEach(t => {
      addNoise(0.4, 200, t, 0.12);
      addOsc(60, "sine", 0.3, t, t + 0.1);
    });
    addOsc(220, "square", 0.12, 0, 2.0);
    addOsc(440, "sawtooth", 0.08, 0.5, 2.0);
    addOsc(330, "sawtooth", 0.08, 1.0, 2.0);

  } else if (genre === "adventure") {
    // Folk melody — ascending notes
    const notes = [261.63, 293.66, 329.63, 349.23, 392.00, 440.00, 493.88, 523.25];
    notes.forEach((f, i) => addOsc(f, "triangle", 0.15, i * 0.22, i * 0.22 + 0.4));
    addOsc(130.81, "sine", 0.08, 0, 2.0);

  } else if (genre === "puzzle") {
    // Xylophone-like bright pings
    const melody = [523.25, 659.25, 783.99, 880.00, 783.99, 659.25, 523.25, 440.00];
    melody.forEach((f, i) => addOsc(f, "triangle", 0.20, i * 0.2, i * 0.2 + 0.18));
    addOsc(261.63, "sine", 0.06, 0, 2.0);

  } else if (genre === "retro") {
    // 8-bit chiptune — square wave melody
    const chip = [440, 494, 523, 587, 523, 494, 440, 392];
    chip.forEach((f, i) => addOsc(f, "square", 0.18, i * 0.2, i * 0.2 + 0.18));
    [0, 0.4, 0.8, 1.2, 1.6].forEach(t => {
      addOsc(110, "square", 0.15, t, t + 0.15);
      addNoise(0.25, 100, t, 0.06);
    });
  }

  return nodes;
}

function playSFX(sfx: string, ctx: AudioContext) {
  const now = ctx.currentTime;

  if (sfx === "explosion") {
    const buf = ctx.createBuffer(1, ctx.sampleRate * 1.2, ctx.sampleRate);
    const d = buf.getChannelData(0);
    for (let i = 0; i < d.length; i++) d[i] = (Math.random() * 2 - 1) * Math.exp(-i / (ctx.sampleRate * 0.4));
    const src = ctx.createBufferSource();
    const gain = ctx.createGain();
    const filter = ctx.createBiquadFilter();
    filter.type = "lowpass"; filter.frequency.value = 400;
    gain.gain.setValueAtTime(1.5, now);
    src.buffer = buf; src.connect(filter); filter.connect(gain); gain.connect(ctx.destination); src.start(now);
  } else if (sfx === "jump") {
    const osc = ctx.createOscillator(); const gain = ctx.createGain();
    osc.type = "sine"; osc.frequency.setValueAtTime(200, now); osc.frequency.exponentialRampToValueAtTime(600, now + 0.2);
    gain.gain.setValueAtTime(0.5, now); gain.gain.linearRampToValueAtTime(0, now + 0.25);
    osc.connect(gain); gain.connect(ctx.destination); osc.start(now); osc.stop(now + 0.3);
  } else if (sfx === "collectible") {
    [0, 0.07, 0.14].forEach((t, i) => {
      const osc = ctx.createOscillator(); const gain = ctx.createGain();
      osc.type = "sine"; osc.frequency.value = [1046, 1318, 1568][i];
      gain.gain.setValueAtTime(0.3, now + t); gain.gain.linearRampToValueAtTime(0, now + t + 0.15);
      osc.connect(gain); gain.connect(ctx.destination); osc.start(now + t); osc.stop(now + t + 0.2);
    });
  } else if (sfx === "laser") {
    const osc = ctx.createOscillator(); const gain = ctx.createGain();
    osc.type = "sawtooth"; osc.frequency.setValueAtTime(1200, now); osc.frequency.exponentialRampToValueAtTime(200, now + 0.3);
    gain.gain.setValueAtTime(0.4, now); gain.gain.linearRampToValueAtTime(0, now + 0.3);
    osc.connect(gain); gain.connect(ctx.destination); osc.start(now); osc.stop(now + 0.35);
  } else if (sfx === "powerup") {
    [261, 329, 392, 523, 659, 784, 1046].forEach((f, i) => {
      const osc = ctx.createOscillator(); const gain = ctx.createGain();
      osc.type = "triangle"; osc.frequency.value = f;
      gain.gain.setValueAtTime(0.25, now + i * 0.07); gain.gain.linearRampToValueAtTime(0, now + i * 0.07 + 0.12);
      osc.connect(gain); gain.connect(ctx.destination); osc.start(now + i * 0.07); osc.stop(now + i * 0.07 + 0.15);
    });
  } else if (sfx === "hit") {
    const buf = ctx.createBuffer(1, ctx.sampleRate * 0.2, ctx.sampleRate);
    const d = buf.getChannelData(0);
    for (let i = 0; i < d.length; i++) d[i] = (Math.random() * 2 - 1) * Math.exp(-i / (ctx.sampleRate * 0.05));
    const src = ctx.createBufferSource(); const gain = ctx.createGain(); const filter = ctx.createBiquadFilter();
    filter.type = "bandpass"; filter.frequency.value = 800;
    gain.gain.setValueAtTime(0.8, now);
    src.buffer = buf; src.connect(filter); filter.connect(gain); gain.connect(ctx.destination); src.start(now);
  }
}

/* ── WaveBar ── */
function WaveBar({ h, color, active }: { h: number; color: string; active: boolean }) {
  return (
    <div className="flex-1 flex items-center justify-center" style={{ minWidth: 0 }}>
      <motion.div
        animate={active ? { scaleY: [1, 1.4, 0.8, 1.2, 1] } : { scaleY: 1 }}
        transition={{ duration: 0.6, repeat: active ? Infinity : 0, delay: Math.random() * 0.3 }}
        style={{ height: `${h * 36}px`, backgroundColor: active ? color : `${color}55`, borderRadius: 2, width: "60%" }}
      />
    </div>
  );
}

export default function SoundForgePage() {
  const { token } = useAuthToken();
  const [type, setType]             = useState<"music" | "sfx">("music");
  const [genre, setGenre]           = useState("epic");
  const [sfxKind, setSfxKind]       = useState("explosion");
  const [prompt, setPrompt]         = useState("");
  const [generating, setGenerating] = useState(false);
  const [playingId, setPlayingId]   = useState<string | null>(null);
  const [library, setLibrary]       = useState<Track[]>([]);
  const [loadingLib, setLoadingLib] = useState(false);
  const [error, setError]           = useState<string | null>(null);
  const [newId, setNewId]           = useState<string | null>(null);
  const [dlLoading, setDlLoading]   = useState<Record<string,boolean>>({});
  const audioNodes = useRef<AudioNode[]>([]);
  const audioCtx   = useRef<AudioContext | null>(null);
  const audioEl    = useRef<HTMLAudioElement | null>(null);

  const normalizeUrl = (url: string) => url.startsWith("http") ? url : `${API_BASE_URL.replace("/api", "")}${url}`;

  const tid = (t: Track) => String(t._id ?? t.id ?? "");
  const waveOf = (t: Track) => t.waveform ?? t.waveformData ?? [];

  useEffect(() => { loadLibrary(); }, [token]);

  const loadLibrary = async () => {
    if (!token) return;
    setLoadingLib(true);
    try {
      const res = await apiFetch<any>("/audio/library", { token });
      const list = Array.isArray(res) ? res : (Array.isArray(res?.data) ? res.data : []);
      setLibrary(list);
    } catch { setLibrary([]); } finally { setLoadingLib(false); }
  };

  const stopAudio = () => {
    audioNodes.current.forEach(n => { try { (n as any).stop?.(); n.disconnect(); } catch {} });
    audioNodes.current = [];
    if (audioEl.current) {
      audioEl.current.pause();
      audioEl.current = null;
    }
  };

  const togglePlay = (track: Track) => {
    const id = tid(track);
    if (playingId === id) { stopAudio(); setPlayingId(null); return; }
    stopAudio();
    
    if (track.fileUrl) {
      const audio = new Audio(normalizeUrl(track.fileUrl));
      audioEl.current = audio;
      audio.play().catch(e => console.error("Playback failed", e));
      setPlayingId(id);
      audio.onended = () => { setPlayingId(null); audioEl.current = null; };
      return;
    }

    if (!audioCtx.current || audioCtx.current.state === "closed") audioCtx.current = createAudioContext();
    const ctx = audioCtx.current;
    if (ctx.state === "suspended") ctx.resume();
    // Use keyword-based synth: check prompt+title for SFX keywords
    const text = (track.title + " " + (track.prompt ?? "")).toLowerCase();
    const has = (...w: string[]) => w.some(x => text.includes(x));
    let nodes: AudioNode[] = [];
    if (track.type === "sfx" || has("sfx","effect")) {
      const sfxId = has("explosion","boom","bomb") ? "explosion"
        : has("jump","bounce","hop") ? "jump"
        : has("coin","collect","ding","ping","chime") ? "collectible"
        : has("laser","shoot","gun","shot") ? "laser"
        : has("powerup","level up","victory","win") ? "powerup"
        : has("hit","damage","impact","punch") ? "hit"
        : track.genre;
      playSFX(sfxId, ctx);
    } else {
      nodes = playGenreAudio(track.genre, ctx);
    }
    audioNodes.current = nodes;
    setPlayingId(id);
    setTimeout(() => { stopAudio(); setPlayingId(null); }, 3500);
  };

  const downloadWav = async (track: Track) => {
    const id = tid(track);
    if (track.fileUrl) {
      setDlLoading(p => ({...p,[id]:true}));
      try {
        const r = await fetch(normalizeUrl(track.fileUrl));
        const blob = await r.blob();
        const url = URL.createObjectURL(blob);
        const a = document.createElement("a"); a.href=url; a.download=track.title.replace(/\W/g,"_")+(track.fileUrl.includes(".mp3") ? ".mp3" : ".wav"); a.click();
        URL.revokeObjectURL(url);
      } finally { setDlLoading(p => ({...p,[id]:false})); }
      return;
    }
    // Render synth to WAV
    setDlLoading(p => ({...p,[id]:true}));
    try {
      const sr=44100, dur=track.type==="sfx"?1.5:4;
      const off = new OfflineAudioContext(1, sr*dur, sr);
      const master = off.createGain(); master.gain.value=0.7; master.connect(off.destination);
      const t=off.currentTime;
      const mkO=(f:number,tp:OscillatorType,g:number,s:number,e:number)=>{
        const o=off.createOscillator(),gn=off.createGain();
        o.type=tp;o.frequency.setValueAtTime(f,t+s);
        gn.gain.setValueAtTime(0,t+s);gn.gain.linearRampToValueAtTime(g,t+s+0.01);gn.gain.linearRampToValueAtTime(0,t+e);
        o.connect(gn);gn.connect(master);o.start(t+s);o.stop(t+e);
      };
      const mkN=(g:number,s:number,e:number,lp=3000)=>{
        const buf=off.createBuffer(1,sr*(e-s),sr);const d=buf.getChannelData(0);
        for(let i=0;i<d.length;i++)d[i]=Math.random()*2-1;
        const src=off.createBufferSource();src.buffer=buf;
        const f=off.createBiquadFilter();f.type="lowpass";f.frequency.value=lp;
        const gn=off.createGain();gn.gain.setValueAtTime(g,t+s);gn.gain.exponentialRampToValueAtTime(0.001,t+e);
        src.connect(f);f.connect(gn);gn.connect(master);src.start(t+s);src.stop(t+e);
      };
      const text2=(track.title+" "+(track.prompt??"")).toLowerCase();
      const has2=(...w:string[])=>w.some(x=>text2.includes(x));
      if(track.type==="sfx"||has2("sfx","effect")){
        if(has2("shoot","gun","laser")){mkN(0.8,0,0.05,8000);mkN(0.4,0,0.4,1200);mkO(80,"sine",0.6,0,0.15);}
        else if(has2("explosion","boom")){mkN(1,0,1.4,600);mkN(0.5,0,1,200);mkO(40,"sine",0.8,0,0.8);}
        else if(has2("jump","bounce")){const o=off.createOscillator();const g=off.createGain();o.type="sine";o.frequency.setValueAtTime(200,t);o.frequency.exponentialRampToValueAtTime(800,t+0.25);g.gain.setValueAtTime(0.5,t);g.gain.linearRampToValueAtTime(0,t+0.3);o.connect(g);g.connect(master);o.start(t);o.stop(t+0.3);}
        else if(has2("coin","collect","ding","ping")){mkO(1046,"sine",0.6,0,0.35);mkO(1318,"sine",0.4,0.07,0.45);mkO(1568,"sine",0.3,0.14,0.55);}
        else if(has2("powerup","victory","win")){[[0,523],[0.12,659],[0.24,784],[0.36,1046]].forEach(([s,f])=>mkO(f,"sine",0.4,s,s+0.25));}
        else if(has2("hit","impact","damage")){mkN(0.7,0,0.1,3000);mkO(120,"sine",0.7,0,0.12);}
        else{mkN(0.5,0,0.3,3000);mkO(440,"sine",0.3,0,0.5);}
      } else {
        const g=track.genre;
        if(g==="epic"||has2("epic","boss","battle")){[130,165,196,247,294].forEach((f,i)=>{mkO(f,"sawtooth",0.1,i*0.5,i*0.5+1.5);});mkN(0.1,0,3.5,200);}
        else if(g==="chill"||has2("chill","calm","ambient")){[[261,329,392],[220,277,330],[293,370,440]].forEach((c,i)=>c.forEach(f=>mkO(f,"sine",0.07,i*1.2,i*1.2+2)));}
        else if(g==="horror"||has2("horror","dark","eerie")){[55,58,65,73].forEach((f,i)=>{mkO(f,"sawtooth",0.09,i*0.3,4);mkO(f*2.01,"square",0.05,i*0.3,4);});mkN(0.06,0,4,300);}
        else if(g==="action"||has2("action","fast","intense")){[220,277,330,440,554,440,330,277].forEach((f,i)=>mkO(f,"sawtooth",0.13,i*0.25,i*0.25+0.28));[0,0.5,1,1.5,2,2.5].forEach(s=>mkN(0.13,s,s+0.05,800));}
        else if(g==="puzzle"||has2("puzzle","quirky")){[523,659,784,659,523,784,880,784].forEach((f,i)=>mkO(f,"triangle",0.25,i*0.3,i*0.3+0.22));}
        else if(g==="retro"||has2("retro","8-bit","chiptune")){[262,294,330,349,392,440,494,523].forEach((f,i)=>mkO(f,"square",0.18,i*0.25,i*0.25+0.22));}
        else{[293,329,369,440,369,329,261,293].forEach((f,i)=>mkO(f,"triangle",0.18,i*0.4,i*0.4+0.4));}
      }
      const rendered=await off.startRendering();
      const n=rendered.length;
      const wav=new ArrayBuffer(44+n*2);const v=new DataView(wav);
      const ws=(o:number,s:string)=>{for(let i=0;i<s.length;i++)v.setUint8(o+i,s.charCodeAt(i));};
      ws(0,"RIFF");v.setUint32(4,36+n*2,true);ws(8,"WAVE");ws(12,"fmt ");
      v.setUint32(16,16,true);v.setUint16(20,1,true);v.setUint16(22,1,true);
      v.setUint32(24,sr,true);v.setUint32(28,sr*2,true);v.setUint16(32,2,true);v.setUint16(34,16,true);
      ws(36,"data");v.setUint32(40,n*2,true);
      const ch=rendered.getChannelData(0);
      for(let i=0;i<n;i++){const s=Math.max(-1,Math.min(1,ch[i]));v.setInt16(44+i*2,s<0?s*0x8000:s*0x7FFF,true);}
      const blob=new Blob([wav],{type:"audio/wav"});const url=URL.createObjectURL(blob);
      const a=document.createElement("a");a.href=url;a.download=track.title.replace(/\W/g,"_")+".wav";a.click();
      URL.revokeObjectURL(url);
    } finally { setDlLoading(p=>({...p,[id]:false})); }
  };

  const generate = useCallback(async () => {
    if (!prompt.trim()) return;
    setGenerating(true); setError(null); setNewId(null);
    try {
      if (token) {
        const safeGenre = type === "sfx" ? "action" : genre;
        const safePrompt =
          type === "sfx" ? `${sfxKind}: ${prompt.trim()}` : prompt.trim();
        const res = await apiFetch<any>("/audio/generate", {
          method:"POST", token,
          body:{ type, genre: safeGenre, prompt: safePrompt, projectId:"library" },
        });
        const id = String(res?._id??res?.id??res?.data?._id??res?.data?.id??"");
        await loadLibrary();
        if(id){setNewId(id);setTimeout(()=>setNewId(null),8000);}
      } else {
        const id = Date.now().toString();
        setLibrary(prev=>[{
          id,
          title: `${(type === "sfx" ? sfxKind : genre).toUpperCase()} — ${prompt.slice(0,35)}`,
          type,
          genre: type === "sfx" ? "action" : genre,
          duration:30,
          waveform:Array.from({length:50},()=>Math.random()*0.8+0.1),
          prompt: prompt.trim(), favorite:false,
        },...prev]);
        setNewId(id);setTimeout(()=>setNewId(null),8000);
      }
      setPrompt("");
    } catch(e:any){setError(e.message);}
    finally{setGenerating(false);}
  }, [prompt, type, genre, sfxKind, token]);

  const gColor = (id:string)=>GENRES.find(g=>g.id===id)?.color??"#8b5cf6";
  const gIcon  = (id:string)=>GENRES.find(g=>g.id===id)?.icon??"🎵";

  return (
    <UserShell title="SoundForge" subtitle="Studio Audio IA · Claude (AgentRouter)">
      <div className="grid lg:grid-cols-[1fr_400px] gap-6 h-full">

        {/* ── LEFT ── */}
        <div className="space-y-5 overflow-y-auto gf-scrollbar pr-1">

          {/* Claude status */}
          <div className="flex items-center gap-3 flex-wrap">
            <div className="flex items-center gap-2 px-3 py-2 rounded-xl bg-violet-500/[0.05] border border-violet-500/[0.2]">
              <div className="h-2 w-2 rounded-full bg-violet-500 shadow-[0_0_8px_rgba(139,92,246,0.6)] animate-pulse" />
              <span className="text-[11px] font-bold text-violet-300">
                Claude Online
              </span>
            </div>
          </div>

          {/* Type toggle */}
          <div className="flex gap-3">
            {(["music", "sfx"] as const).map(t => (
              <button key={t} onClick={() => setType(t)}
                className={`flex-1 py-2.5 rounded-xl text-sm font-bold border transition-all ${type === t ? "bg-violet-500/20 border-violet-500/50 text-violet-300" : "bg-white/[0.03] border-white/[0.08] text-zinc-500 hover:text-white"}`}>
                {t === "music" ? "🎵 Music" : "🔊 SFX"}
              </button>
            ))}
          </div>

          {/* Genre/SFX */}
          <div>
            <p className="text-[11px] font-black uppercase tracking-widest text-zinc-500 mb-3">{type === "music" ? "Genre" : "Sound Type"}</p>
            <div className="flex flex-wrap gap-2">
              {(type === "music" ? GENRES : SFX_TYPES.map(s => ({ ...s, color: "#8b5cf6" }))).map(g => (
                <button key={g.id}
                  onClick={() => {
                    if (type === "music") {
                      setGenre(g.id);
                    } else {
                      setSfxKind(g.id);
                      setPrompt((prev) => {
                        const t = (prev || '').trim();
                        return t ? prev : g.id;
                      });
                    }
                  }}
                  className="px-3 py-1.5 rounded-full text-[12px] font-bold border transition-all"
                  style={(type === "music" ? genre === g.id : sfxKind === g.id)
                    ? { backgroundColor: `${(g as any).color}20`, borderColor: `${(g as any).color}60`, color: (g as any).color }
                    : { backgroundColor: "rgba(255,255,255,0.03)", borderColor: "rgba(255,255,255,0.08)", color: "#71717a" }}>
                  {g.icon} {g.label}
                </button>
              ))}
            </div>
          </div>

          {/* Prompt */}
          <div>
            <p className="text-[11px] font-black uppercase tracking-widest text-zinc-500 mb-2">Décris le son</p>
            <textarea value={prompt} onChange={e => setPrompt(e.target.value)} rows={3}
              placeholder={type === "music" ? '"Boss fight épique, orchestre sombre avec percussions"' : '"Explosion métallique quand le joueur prend des dégâts"'}
              className="w-full rounded-xl bg-white/[0.04] border border-white/[0.08] text-white placeholder:text-zinc-600 text-sm p-4 outline-none focus:border-violet-500/40 resize-none" />
          </div>

          {error && <div className="p-3 rounded-xl bg-red-500/10 border border-red-500/30 text-[11px] text-red-300">⚠️ {error}</div>}

          <button onClick={generate} disabled={generating || !prompt.trim()}
            className="w-full py-3.5 rounded-xl font-black text-white transition-all disabled:opacity-40"
            style={{ background: "linear-gradient(135deg, #8b5cf6, #6366f1)", boxShadow: "0 8px 24px rgba(139,92,246,0.3)" }}>
            {generating
              ? <span className="flex items-center justify-center gap-2"><span className="h-4 w-4 rounded-full border-2 border-white/30 border-t-white animate-spin" />Claude génère…</span>
              : "🎵 Générer"}
          </button>

          <div className="p-4 rounded-xl bg-violet-500/[0.07] border border-violet-500/20 text-[12px] space-y-1">
            <p className="font-bold text-violet-300">🤖 Claude → AI Prompt → Audio Generation</p>
            <p className="text-violet-400/70">• With SUNO_API_KEY: generates & plays real MP3</p>
            <p className="text-violet-400/70">• Without key: plays & downloads mock generated WAV</p>
            <p className="text-violet-400/70">• Tap ▶ to play or ⬇ to download</p>
          </div>
        </div>

        {/* ── RIGHT: Library ── */}
        <div className="flex flex-col gap-3">
          <div className="flex items-center justify-between">
            <p className="text-[11px] font-black uppercase tracking-widest text-zinc-500">Bibliothèque ({library.length})</p>
            {library.length > 0 && <button onClick={() => { stopAudio(); setPlayingId(null); setLibrary([]); }} className="text-[11px] text-zinc-700 hover:text-red-400 transition-colors">Effacer</button>}
          </div>

          {library.length === 0 ? (
            <div className="flex-1 flex flex-col items-center justify-center rounded-2xl bg-white/[0.02] border border-white/[0.06] text-zinc-700 p-8">
              <span className="text-5xl mb-3 opacity-30">🎵</span>
              <p className="text-sm text-center">Génère ton premier track</p>
              <p className="text-[11px] text-center mt-1 opacity-60">Appuie ▶ pour écouter le son</p>
            </div>
          ) : (
            <div className="flex-1 overflow-y-auto gf-scrollbar space-y-3 pr-1">
              <AnimatePresence>
                {library.map(track => {
                  const id = tid(track);
                  const c = gColor(track.genre);
                  const playing = playingId === id;
                  const isNew = newId === id;
                  const wave = waveOf(track);
                  return (
                    <motion.div key={id} initial={{ opacity: 0, y: 12 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0, y: -8 }}
                      className="p-4 rounded-2xl border transition-all"
                      style={{ backgroundColor: isNew ? `${c}15` : "rgba(255,255,255,0.03)", borderColor: isNew ? `${c}80` : playing ? `${c}60` : "rgba(255,255,255,0.07)", boxShadow: isNew ? `0 0 20px ${c}25` : playing ? `0 0 20px ${c}20` : "none" }}>
                      <div className="flex items-center gap-3 mb-3">
                        <div className="h-9 w-9 rounded-xl flex items-center justify-center text-lg shrink-0" style={{ backgroundColor: `${c}15` }}>
                          {gIcon(track.genre)}
                        </div>
                        <div className="flex-1 min-w-0">
                          <div className="flex items-center gap-2 flex-wrap">
                            <p className="text-[13px] font-bold text-white truncate">{track.title}</p>
                            {isNew && <span className="text-[8px] font-black bg-emerald-500 text-white px-2 py-0.5 rounded-full">NEW ✨</span>}
                          </div>
                          <p className="text-[10px] text-zinc-600">{track.type.toUpperCase()} · Claude · {track.fileUrl ? "MP3 ✓" : "Web Audio"}</p>
                        </div>
                        {/* ▶ Play */}
                        <button onClick={() => togglePlay(track)}
                          className="h-9 w-9 rounded-xl flex items-center justify-center transition-all"
                          style={{ backgroundColor: playing ? c : `${c}25`, color: playing ? "#000" : c }}>
                          {playing ? "⏸" : "▶"}
                        </button>
                        {/* ⬇ Download */}
                        <button onClick={() => downloadWav(track)} title={track.fileUrl ? "Download MP3" : "Export WAV"}
                          className="h-8 w-8 rounded-xl flex items-center justify-center transition-all text-sm"
                          style={{ backgroundColor: "rgba(255,255,255,0.05)", color: dlLoading[id] ? c : "#52525b" }}>
                          {dlLoading[id] ? "⏳" : "⬇"}
                        </button>
                        <button onClick={() => setLibrary(prev => prev.map(t => tid(t) === id ? { ...t, favorite: !t.favorite, isFavorite: !t.isFavorite } : t))}
                          className={`text-base ${(track.favorite||track.isFavorite) ? "text-pink-500" : "text-zinc-700 hover:text-zinc-400"} transition-colors`}>
                          {(track.favorite||track.isFavorite) ? "♥" : "♡"}
                        </button>
                      </div>
                      {/* Waveform */}
                      {wave.length > 0 && (
                        <div className="flex items-end gap-px h-9">
                          {wave.map((h, i) => <WaveBar key={i} h={h} color={c} active={playing} />)}
                        </div>
                      )}
                      {track.prompt && (
                        <p className="mt-2 text-[10px] text-zinc-600 italic line-clamp-2">{track.prompt}</p>
                      )}
                    </motion.div>
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
