"use client";

import { Suspense, useEffect, useMemo, useRef, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { motion, AnimatePresence } from "framer-motion";
import {
  Lightning, ArrowRight, Microphone, MicrophoneSlash,
  SpeakerHigh, SpeakerSlash, Brain, Pulse, Sparkle,
  WarningCircle, CheckCircle, Robot, Terminal,
  Cpu, Waves
} from "@phosphor-icons/react";
import { io, Socket } from "socket.io-client";
import UserShell from "@/app/_components/UserShell";
import { API_BASE_URL } from "@/lib/api";
import { getUserToken } from "@/lib/userAuth";

type ChatMsg = {
  role: "user" | "assistant" | "system";
  text: string;
};

// --- CSS Effects ---
const CHROMATIC_TEXT = "relative inline-block before:content-[attr(data-text)] before:absolute before:inset-0 before:text-fuchsia-500/50 before:animate-[chromatic-1_2s_infinite] after:content-[attr(data-text)] after:absolute after:inset-0 after:text-cyan-500/50 after:animate-[chromatic-2_2s_infinite]";

const MessageBubble = ({ m }: { m: ChatMsg }) => (
  <motion.div
    initial={{ opacity: 0, y: 20, scale: 0.95 }}
    animate={{ opacity: 1, y: 0, scale: 1 }}
    transition={{ type: "spring", stiffness: 300, damping: 25 }}
    className={`flex ${m.role === "user" ? "justify-end" : "justify-start"} mb-6 relative group`}
  >
    <div className={`max-w-[85%] rounded-[32px] p-6 shadow-2xl relative border overflow-hidden ${m.role === "user"
        ? "bg-indigo-500 text-white font-bold rounded-tr-none border-indigo-400/30"
        : "gf-panel-strong text-zinc-100 border-white/10 rounded-tl-none bg-black/40 backdrop-blur-3xl"
      }`}>
      {/* Scanline Overlay */}
      <div className="absolute inset-x-0 h-10 bg-white/[0.03] blur-xl -translate-y-full animate-[scanline_4s_linear_infinite] pointer-events-none" />

      {m.role === "assistant" && (
        <div className="absolute -left-12 top-0 h-10 w-10 rounded-2xl bg-gradient-to-br from-indigo-500 to-fuchsia-500 flex items-center justify-center text-white shadow-[0_0_20px_rgba(99,102,241,0.4)] border border-white/10">
          <Robot size={20} weight="duotone" />
        </div>
      )}
      <p className="text-[15px] leading-relaxed whitespace-pre-wrap relative z-10">{m.text}</p>

      {m.role === "assistant" && (
        <div className="absolute -bottom-1 -right-1 h-3 w-3 bg-emerald-500 rounded-full border-2 border-black animate-pulse" />
      )}
    </div>
  </motion.div>
);

// --- Neural Vortex Background ---
const NeuralVortex = ({ active, thinking }: { active: boolean, thinking: boolean }) => {
  const canvasRef = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext("2d");
    if (!ctx) return;

    let width = (canvas.width = 400);
    let height = (canvas.height = 400);
    const particles: any[] = [];
    const particleCount = 100;

    class Particle {
      angle: number;
      radius: number;
      speed: number;
      size: number;
      color: string;

      constructor() {
        this.angle = Math.random() * Math.PI * 2;
        this.radius = Math.random() * (width / 2);
        this.speed = (Math.random() * 0.02 + 0.01) * (thinking ? 2.5 : 1);
        this.size = Math.random() * 2 + 0.5;
        this.color = Math.random() > 0.5 ? "rgba(99, 102, 241, 0.4)" : "rgba(232, 121, 249, 0.4)";
      }

      update() {
        this.angle += this.speed;
        if (active) this.radius *= 0.995;
        if (this.radius < 5) this.radius = width / 2;
      }

      draw() {
        if (!ctx) return;
        const x = width / 2 + Math.cos(this.angle) * this.radius;
        const y = height / 2 + Math.sin(this.angle) * this.radius;
        ctx.beginPath();
        ctx.arc(x, y, this.size, 0, Math.PI * 2);
        ctx.fillStyle = this.color;
        ctx.fill();

        if (thinking && Math.random() > 0.9) {
          ctx.beginPath();
          ctx.moveTo(width / 2, height / 2);
          ctx.lineTo(x, y);
          ctx.strokeStyle = "rgba(99, 102, 241, 0.05)";
          ctx.stroke();
        }
      }
    }

    for (let i = 0; i < particleCount; i++) particles.push(new Particle());

    const animate = () => {
      ctx.clearRect(0, 0, width, height);
      particles.forEach(p => {
        p.update();
        p.draw();
      });
      requestAnimationFrame(animate);
    };

    animate();
  }, [active, thinking]);

  return (
    <canvas
      ref={canvasRef}
      className="absolute inset-0 z-0 pointer-events-none opacity-60 scale-150 blur-sm"
    />
  );
};

// --- Holographic Satellite Ring ---
const NeuralRing = ({ rotate, active, thinking }: { rotate: number, active: boolean, thinking: boolean }) => (
  <div
    className="absolute h-64 w-64 border-2 border-dashed border-indigo-500/20 rounded-full transition-transform duration-700 ease-[cubic-bezier(0.2,1,0.4,1)]"
    style={{
      transform: `perspective(1000px) rotateX(60deg) rotateZ(${rotate}deg) scale(${active ? 1.1 : 1})`,
      borderWidth: thinking ? '4px' : '2px',
      opacity: active ? 0.6 : 0.2
    }}
  >
    <motion.div
      animate={{ scale: [1, 1.2, 1], opacity: [0.5, 1, 0.5] }}
      transition={{ duration: 2, repeat: Infinity }}
      className="absolute top-0 left-1/2 -translate-x-1/2 -ml-2 -mt-2 h-4 w-4 bg-indigo-500 rounded-full shadow-[0_0_20px_rgba(99,102,241,0.8)]"
    />
  </div>
);

// Siri-like Animated Orb (Enhanced)
const NeuralCore = ({ active, thinking, speaking }: { active: boolean, thinking: boolean, speaking: boolean }) => {
  const [rotation, setRotation] = useState(0);

  useEffect(() => {
    let frame: number;
    const animate = () => {
      setRotation(prev => prev + (thinking ? 2 : (active ? 0.8 : 0.3)));
      frame = requestAnimationFrame(animate);
    };
    animate();
    return () => cancelAnimationFrame(frame);
  }, [active, thinking]);

  return (
    <div className="relative h-48 w-48 mx-auto flex items-center justify-center">
      <NeuralVortex active={active} thinking={thinking} />

      <div className="relative z-10 flex items-center justify-center">
        {/* Satellites */}
        <NeuralRing rotate={rotation} active={active} thinking={thinking} />
        <NeuralRing rotate={-rotation * 0.7} active={active} thinking={thinking} />

        {/* Outer Auras */}
        <motion.div
          animate={{
            scale: active ? [1.1, 1.3, 1.1] : 1,
            opacity: active ? [0.3, 0.5, 0.3] : 0.1
          }}
          transition={{ duration: 3, repeat: Infinity }}
          className="absolute inset-0 bg-indigo-500/30 rounded-full blur-[100px]"
        />

        {/* The Core Orb */}
        <motion.div
          animate={{
            rotateZ: active ? [0, 5, -5, 0] : 0,
            scale: thinking ? [1.1, 1.2, 1.1] : (speaking ? [1, 1.15, 1] : 1),
            boxShadow: active ? [
              "0 0 50px rgba(99,102,241,0.4)",
              "0 0 100px rgba(99,102,241,0.6)",
              "0 0 50px rgba(99,102,241,0.4)"
            ] : "0 0 0px rgba(0,0,0,0)"
          }}
          transition={{
            rotateZ: { duration: 4, repeat: Infinity, ease: "linear" },
            scale: { duration: 1.5, repeat: Infinity, ease: "easeInOut" },
            boxShadow: { duration: 2, repeat: Infinity }
          }}
          className={`relative h-24 w-24 rounded-[36px] flex items-center justify-center border transition-all duration-700 z-20 overflow-hidden backdrop-blur-2xl
              ${active ? 'border-white/40 bg-black/40 scale-110' : 'border-white/5 bg-white/[0.02]'}
            `}
        >
          <div className={`absolute inset-0 bg-gradient-to-br transition-opacity duration-700
              ${active ? 'from-indigo-500/40 via-fuchsia-500/30 to-cyan-500/40 opacity-100' : 'from-white/5 to-transparent opacity-50'}
            `} />

          <div className="relative z-10 drop-shadow-[0_0_15px_rgba(255,255,255,0.4)]">
            <AnimatePresence mode="wait">
              {thinking ? (
                <motion.div key="think" initial={{ opacity: 0, scale: 0.5 }} animate={{ opacity: 1, scale: 1 }} exit={{ opacity: 0 }}>
                  <Brain size={48} weight="duotone" className="text-fuchsia-400 animate-pulse" />
                </motion.div>
              ) : active ? (
                <motion.div key="active" initial={{ opacity: 0, scale: 0.5 }} animate={{ opacity: 1, scale: 1 }} exit={{ opacity: 0 }}>
                  <Lightning size={48} weight="fill" className="text-white drop-shadow-[0_0_20px_rgba(255,255,255,1)]" />
                </motion.div>
              ) : (
                <motion.div key="idle" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}>
                  <Robot size={48} weight="duotone" className="text-zinc-700" />
                </motion.div>
              )}
            </AnimatePresence>
          </div>
        </motion.div>

        {/* Pulse Waves (Expanding circles) */}
        {active && (
          <>
            <motion.div
              initial={{ scale: 0.8, opacity: 1 }}
              animate={{ scale: 2.5, opacity: 0 }}
              transition={{ duration: 2, repeat: Infinity, ease: "easeOut" }}
              className="absolute inset-0 border-2 border-indigo-500/20 rounded-full"
            />
            <motion.div
              initial={{ scale: 0.8, opacity: 1 }}
              animate={{ scale: 2.2, opacity: 0 }}
              transition={{ duration: 2, repeat: Infinity, ease: "easeOut", delay: 0.5 }}
              className="absolute inset-0 border border-fuchsia-500/10 rounded-full"
            />
          </>
        )}
      </div>

      {/* Spectral Waves (Voice reactive) - More vibrant */}
      {active && !thinking && (
        <div className="absolute -bottom-16 left-1/2 -translate-x-1/2 flex items-end gap-2 h-20">
          {Array.from({ length: 12 }).map((_, i) => (
            <motion.div
              key={i}
              animate={{ height: speaking ? [20, 64, 20] : [10, 32, 10] }}
              transition={{ duration: 0.4 + i * 0.05, repeat: Infinity, ease: "easeInOut" }}
              className="w-2 bg-gradient-to-t from-indigo-500 via-purple-500 to-fuchsia-400 rounded-full shadow-[0_0_10px_rgba(99,102,241,0.5)]"
            />
          ))}
        </div>
      )}
    </div>
  );
};

export default function AiCoachPage() {
  return (
    <Suspense fallback={null}>
      <AiCoachPageInner />
    </Suspense>
  );
}

function AiCoachPageInner() {
  const router = useRouter();
  const sp = useSearchParams();
  const token = useMemo(() => getUserToken(), []);
  const projectId = sp?.get("projectId");

  const [connected, setConnected] = useState(false);
  const [messages, setMessages] = useState<ChatMsg[]>([]);
  const [input, setInput] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [streamedText, setStreamedText] = useState("");

  // Voice State
  const [isListening, setIsListening] = useState(false);
  const [autoSpeak, setAutoSpeak] = useState(true);
  const [isSpeaking, setIsSpeaking] = useState(false);

  const socketRef = useRef<Socket | null>(null);
  const scrollRef = useRef<HTMLDivElement>(null);
  const recognitionRef = useRef<any>(null);

  const socketUrl = useMemo(() => {
    try {
      const url = new URL(API_BASE_URL);
      return `${url.protocol}//${url.host}`;
    } catch {
      return "";
    }
  }, []);

  // ─── Voice Recognition (STT) ───────────────────────────────────────────
  useEffect(() => {
    const SpeechRecognition = (window as any).SpeechRecognition || (window as any).webkitSpeechRecognition;
    if (SpeechRecognition) {
      const rec = new SpeechRecognition();
      rec.continuous = false;
      rec.interimResults = false;
      rec.lang = "en-US";

      rec.onstart = () => setIsListening(true);
      rec.onend = () => setIsListening(false);
      rec.onresult = (e: any) => {
        const text = e.results[0][0].transcript;
        setInput(text);
        setTimeout(() => handleSendMessage(text), 200);
      };
      rec.onerror = () => setIsListening(false);
      recognitionRef.current = rec;
    }
  }, []);

  const toggleListening = () => {
    if (isListening) recognitionRef.current?.stop();
    else recognitionRef.current?.start();
  };

  const speak = (text: string) => {
    if (!autoSpeak) return;
    window.speechSynthesis.cancel();
    const utterance = new SpeechSynthesisUtterance(text);
    utterance.onstart = () => setIsSpeaking(true);
    utterance.onend = () => setIsSpeaking(false);
    const voices = window.speechSynthesis.getVoices();
    const siri = voices.find(v => v.name.includes("Siri") || v.name.includes("Samantha") || v.name.includes("Daniel"));
    if (siri) utterance.voice = siri;
    window.speechSynthesis.speak(utterance);
  };

  useEffect(() => {
    if (!token || !socketUrl) return;
    const socket = io(`${socketUrl}/coach`, {
      transports: ["websocket"],
      path: "/socket.io",
      auth: { token },
    });
    socket.on("connect", () => {
      setConnected(true);
      setError(null);
    });
    socket.on("disconnect", () => setConnected(false));
    socket.on("connect_error", (err) => {
      setError("Sync failed: " + err.message);
      setConnected(false);
    });
    socket.on("coach:started", () => {
      setLoading(true);
      setStreamedText("");
    });
    socket.on("coach:token", (data: { t: string }) => {
      setStreamedText((prev) => prev + data.t);
    });
    socket.on("coach:done", () => {
      setLoading(false);
      setMessages((prev) => {
        const lastMsg = streamedText || "...";
        speak(lastMsg);
        return [...prev, { role: "assistant", text: lastMsg }];
      });
      setStreamedText("");
    });
    socket.on("coach:error", (data: { message: string }) => {
      setError(data.message);
      setLoading(false);
    });
    socketRef.current = socket;
    return () => { socket.disconnect(); };
  }, [token, socketUrl, autoSpeak]);

  useEffect(() => {
    if (scrollRef.current) {
      scrollRef.current.scrollTo({ top: scrollRef.current.scrollHeight, behavior: "smooth" });
    }
  }, [messages, streamedText]);

  function handleSendMessage(overrideText?: string) {
    const txt = (overrideText || input).trim();
    if (!txt || !socketRef.current || !connected) return;
    setMessages((prev) => [...prev, { role: "user", text: txt }]);
    socketRef.current.emit("coach:start", {
      token,
      text: txt,
      projectId: projectId || undefined,
    });
    setInput("");
    setError(null);
  }

  return (
    <UserShell
      title="Neural Command"
      subtitle="AI CO-PILOT SYSTEM v4.2"
      right={
        <div className="flex items-center gap-3">
          <button
            onClick={() => setAutoSpeak(!autoSpeak)}
            className={`h-10 w-10 rounded-xl flex items-center justify-center transition-all border ${autoSpeak ? 'bg-indigo-500/20 border-indigo-500/40 text-indigo-400 shadow-[0_0_15px_rgba(99,102,241,0.2)]' : 'bg-white/5 border-white/10 text-zinc-500'
              }`}
            title="Auto-Voice Protocol"
          >
            {autoSpeak ? <SpeakerHigh size={20} weight="bold" /> : <SpeakerSlash size={20} weight="bold" />}
          </button>

          <div className="flex items-center gap-4 bg-white/5 rounded-2xl px-4 py-2 border border-white/5 backdrop-blur-md">
            <div className="flex flex-col items-end">
              <span className="text-[9px] font-black uppercase tracking-[0.2em] text-zinc-500">Neural Link</span>
              <span className={`text-[10px] font-bold ${connected ? "text-cyan-400" : "text-rose-400"}`}>
                {connected ? "SYNCED" : "OFFLINE"}
              </span>
            </div>
            <div className={`h-2.5 w-2.5 rounded-full ${connected ? "bg-cyan-500 shadow-[0_0_12px_rgba(34,211,238,0.6)] animate-pulse" : "bg-rose-500"}`} />
          </div>
        </div>
      }
    >
      <style>{`
        @keyframes scanline {
          0% { transform: translateY(-100%); }
          100% { transform: translateY(400%); }
        }
        @keyframes chromatic-1 {
          0%, 100% { transform: translate(0); }
          33% { transform: translate(-2px, 1px); }
          66% { transform: translate(1px, -1px); }
        }
        @keyframes chromatic-2 {
          0%, 100% { transform: translate(0); }
          33% { transform: translate(2px, -1px); }
          66% { transform: translate(-1px, 1px); }
        }
      `}</style>

      <div className="flex flex-col h-[calc(100vh-160px)] max-w-5xl mx-auto px-4 relative">
        <div
          ref={scrollRef}
          className={`flex-1 ${messages.length > 0 ? "overflow-y-auto" : "overflow-hidden"} gf-scrollbar space-y-4 px-2 pb-24`}
        >
          {messages.length === 0 && !streamedText && (
            <div className="flex flex-col items-center justify-start h-full text-center pt-4 relative">
              <div className="absolute top-[20%] left-1/2 -translate-x-1/2 w-[600px] h-[600px] bg-indigo-500/5 blur-[120px] rounded-full pointer-events-none" />

              <NeuralCore
                active={isListening || loading || isSpeaking}
                thinking={loading}
                speaking={isSpeaking}
              />

              <div className="mt-8">
                <motion.div
                  initial={{ opacity: 0, scale: 0.9 }}
                  animate={{ opacity: 1, scale: 1 }}
                  className="inline-block relative"
                >
                  <div className="absolute -inset-10 bg-indigo-500/10 blur-[50px] opacity-20" />
                  <h3
                    data-text="NEURAL COMMAND READY"
                    className={`text-3xl lg:text-4xl font-black tracking-tighter text-white uppercase italic leading-none ${CHROMATIC_TEXT}`}
                  >
                    NEURAL COMMAND <span className="text-indigo-500">READY</span>
                  </h3>
                </motion.div>

                <p className="mt-4 text-zinc-500 max-w-sm mx-auto font-medium text-base leading-relaxed drop-shadow-lg">
                  Protocol established. Synchronize with your core or engage terminal modules.
                </p>

                <div className="mt-6 grid grid-cols-1 sm:grid-cols-2 gap-3 w-full max-w-xl mx-auto">
                  {[
                    { label: "Forge Core Movement", icon: Cpu },
                    { label: "Synthesize Logic Modules", icon: Sparkle },
                    { label: "Neural Collision Mapping", icon: Waves },
                    { label: "Performance Analytics", icon: Terminal }
                  ].map(hint => (
                    <button
                      key={hint.label}
                      onClick={() => handleSendMessage(hint.label)}
                      className="gf-panel group hover:bg-indigo-500/10 hover:border-indigo-500/30 transition-all text-[10px] font-black uppercase tracking-widest text-zinc-500 hover:text-indigo-400 py-3 px-5 rounded-2xl border border-white/5 flex items-center justify-between backdrop-blur-xl"
                    >
                      <div className="flex items-center gap-4">
                        <div className="h-8 w-8 rounded-lg bg-white/5 flex items-center justify-center group-hover:bg-indigo-500/20 group-hover:text-indigo-400 transition-all">
                          <hint.icon size={18} weight="duotone" />
                        </div>
                        {hint.label}
                      </div>
                      <ArrowRight size={14} className="opacity-0 group-hover:opacity-100 -translate-x-2 group-hover:translate-x-0 transition-all" />
                    </button>
                  ))}
                </div>
              </div>
            </div>
          )}

          <div className="space-y-4 max-w-4xl mx-auto w-full">
            <AnimatePresence mode="popLayout">
              {messages.map((m, i) => (
                <MessageBubble key={i} m={m} />
              ))}

              {streamedText && (
                <div className="flex justify-start mb-6">
                  <div className="max-w-[85%] rounded-[32px] rounded-tl-none p-6 gf-panel-strong text-zinc-100 border border-white/10 relative bg-black/40 backdrop-blur-3xl overflow-hidden shadow-[0_0_40px_rgba(99,102,241,0.2)]">
                    <div className="absolute inset-x-0 h-10 bg-white/[0.03] blur-xl -translate-y-full animate-[scanline_3s_linear_infinite]" />
                    <div className="absolute -left-12 top-0 h-10 w-10 rounded-2xl bg-indigo-500 flex items-center justify-center text-white border border-white/10 shadow-[0_0_20px_rgba(99,102,241,0.4)] animate-pulse">
                      <Terminal size={20} weight="bold" />
                    </div>
                    <p className="text-[15px] leading-relaxed whitespace-pre-wrap relative z-10">{streamedText}</p>
                    <div className="mt-4 flex gap-1.5">
                      <div className="h-1.5 w-1.5 rounded-full bg-indigo-500 animate-bounce" />
                      <div className="h-1.5 w-1.5 rounded-full bg-indigo-500 animate-bounce [animation-delay:0.2s]" />
                      <div className="h-1.5 w-1.5 rounded-full bg-indigo-500 animate-bounce [animation-delay:0.4s]" />
                    </div>
                  </div>
                </div>
              )}
            </AnimatePresence>
          </div>

          {error && (
            <motion.div initial={{ opacity: 0, scale: 0.9 }} animate={{ opacity: 1, scale: 1 }} className="flex justify-center pb-10">
              <div className="rounded-2xl border border-rose-500/30 bg-rose-500/10 px-8 py-4 flex items-center gap-3 backdrop-blur-2xl">
                <WarningCircle size={20} className="text-rose-500" />
                <span className="text-xs font-black uppercase tracking-widest text-rose-400">{error}</span>
              </div>
            </motion.div>
          )}
        </div>

        {/* Floating Controls (Enhanced) */}
        <div className="absolute bottom-4 left-0 right-0 px-4">
          <div className="relative max-w-4xl mx-auto">
            <div className="gf-panel-strong rounded-[40px] p-2 border border-white/10 focus-within:border-indigo-500/50 transition-all shadow-2xl bg-[#08090f]/80 backdrop-blur-[40px] group relative overflow-hidden">
              <div className="absolute inset-0 bg-gradient-to-r from-indigo-500/5 via-transparent to-fuchsia-500/5 opacity-0 group-focus-within:opacity-100 transition-opacity" />
              <div className="flex items-center gap-2 relative z-10">
                <button
                  onClick={toggleListening}
                  className={`h-14 w-14 rounded-[28px] flex items-center justify-center transition-all shrink-0 ${isListening
                      ? 'bg-rose-500 text-white shadow-[0_0_30px_rgba(244,63,94,0.6)] animate-pulse'
                      : 'bg-white/5 text-zinc-500 hover:bg-white/10 hover:text-white'
                    }`}
                >
                  {isListening ? <MicrophoneSlash size={24} weight="fill" /> : <Microphone size={24} weight="duotone" />}
                </button>

                <input
                  className="flex-1 bg-transparent border-none outline-none px-4 text-lg text-white placeholder:text-zinc-800 font-bold tracking-tight"
                  placeholder={isListening ? "Listening to neural stream..." : (connected ? "Initialize terminal command..." : "Syncing neural link...")}
                  value={input}
                  onChange={(e) => setInput(e.target.value)}
                  onKeyDown={(e) => e.key === "Enter" && handleSendMessage()}
                  disabled={!connected || loading}
                />

                <button
                  className="h-14 w-14 rounded-[28px] bg-indigo-500 flex items-center justify-center text-white disabled:opacity-50 transition-all hover:scale-105 active:scale-95 shadow-[0_10px_30px_rgba(99,102,241,0.4)]"
                  onClick={() => handleSendMessage()}
                  disabled={!input.trim() || !connected || loading}
                >
                  <ArrowRight size={24} weight="bold" />
                </button>
              </div>
            </div>
            <div className="mt-3 text-center">
              <span className="text-[10px] font-black uppercase tracking-[0.4em] text-zinc-700 flex items-center justify-center gap-2 animate-pulse">
                <Terminal size={12} className="text-indigo-500" />
                NEURAL PROTOCOL v4.28.1 // SECURE_SYNC: ENABLED
              </span>
            </div>
          </div>
        </div>
      </div>
    </UserShell>
  );
}
