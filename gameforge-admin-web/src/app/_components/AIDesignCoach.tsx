"use client";

import { useState, useRef, useEffect } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { MessageSquare, X, Send, Bot, User, Zap, Code, Lightbulb } from "lucide-react";

type Message = {
  id: string;
  role: "assistant" | "user";
  content: string;
  type?: "text" | "code" | "tip";
};

export default function AIDesignCoach() {
  const [isOpen, setIsOpen] = useState(false);
  const [messages, setMessages] = useState<Message[]>([
    { 
      id: "1", 
      role: "assistant", 
      content: "Hello! I'm your GameForge AI Support Coach. How can I help you with the app today?",
      type: "text"
    }
  ]);
  const [input, setInput] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const scrollRef = useRef<HTMLDivElement>(null);

  const QUICK_PROMPTS = [
    "Can't login / verify",
    "Feed not loading",
    "Game crashes on play",
    "Build stuck in queue",
    "Payment / subscription",
  ];

  useEffect(() => {
    if (scrollRef.current) {
      scrollRef.current.scrollTop = scrollRef.current.scrollHeight;
    }
  }, [messages, isOpen]);

  function resetChat() {
    setMessages([
      {
        id: "1",
        role: "assistant",
        content: "Hello! I'm your GameForge AI Support Coach. How can I help you with the app today?",
        type: "text",
      },
    ]);
    setError(null);
    setInput("");
  }

  async function handleSend() {
    const txt = input.trim();
    if (!txt || loading) return;

    setError(null);
    const userMsg: Message = { id: Date.now().toString(), role: "user", content: txt };
    setMessages((prev) => [...prev, userMsg]);
    setInput("");
    setLoading(true);

    try {
      const history = messages.slice(0).map((m) => ({
        role: m.role,
        content: m.content,
      }));

      const r = await fetch("/api/ollama/chat", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          message: txt,
          history,
          context: {
            page: typeof window !== "undefined" ? window.location.pathname : "",
          },
        }),
      });

      const j = (await r.json().catch(() => null)) as any;
      if (!r.ok || !j?.success) {
        throw new Error(j?.message || `Request failed (${r.status})`);
      }

      const out = String(j?.data?.text || "");
      const aiResponse: Message = {
        id: (Date.now() + 1).toString(),
        role: "assistant",
        content: out || "I couldn't generate a response. Try rephrasing your question.",
        type: "text",
      };
      setMessages((prev) => [...prev, aiResponse]);
    } catch (e: any) {
      setError(e?.message || "Failed to reach Ollama");
      setMessages((prev) => [
        ...prev,
        {
          id: (Date.now() + 2).toString(),
          role: "assistant",
          content:
            "I couldn't connect to the AI engine. Make sure Ollama is running and OLLAMA_BASE_URL is reachable from this app.",
          type: "text",
        },
      ]);
    } finally {
      setLoading(false);
    }
  }

  return (
    <>
      {/* Trigger Button - S-Tier Glassmorphism */}
      <motion.button
        whileHover={{ scale: 1.05 }}
        whileTap={{ scale: 0.95 }}
        onClick={() => setIsOpen(true)}
        className="fixed bottom-10 right-10 z-[100] h-16 w-16 rounded-full bg-[var(--gf-shell-bg)]/90 backdrop-blur-xl border border-[var(--gf-border-accent)] text-cyan-500/80 shadow-[0_20px_40px_var(--gf-glow-primary),inset_0_0_20px_rgba(34,211,238,0.1)] flex items-center justify-center group overflow-hidden"
      >
        <div className="absolute inset-0 bg-gradient-to-br from-cyan-500/20 to-blue-500/20 opacity-0 group-hover:opacity-100 transition-opacity duration-300" />
        <div className="absolute inset-0 rounded-full border-[1.5px] border-cyan-400 opacity-20 animate-ping shadow-[0_0_15px_rgba(34,211,238,0.8)]" style={{ animationDuration: '3s' }} />
  <MessageSquare className="relative z-10 group-hover:scale-110 group-hover:drop-shadow-[0_0_12px_rgba(34,211,238,0.8)] transition-all" size={28} />
      </motion.button>

      {/* Chat Window */}
      <AnimatePresence>
        {isOpen && (
          <motion.div
            initial={{ opacity: 0, scale: 0.9, y: 20, x: 20 }}
            animate={{ opacity: 1, scale: 1, y: 0, x: 0 }}
            exit={{ opacity: 0, scale: 0.9, y: 20, x: 20 }}
            className="fixed bottom-32 right-10 z-[101] w-[min(420px,92vw)] h-[min(640px,78vh)] rounded-[32px] shadow-[0_30px_80px_rgba(0,0,0,0.8),inset_0_0_30px_rgba(34,211,238,0.05)] overflow-hidden flex flex-col bg-[var(--gf-shell-bg)]/90 backdrop-blur-[60px] border border-[var(--gf-border-accent)]"
          >
            {/* Header */}
            <div className="p-6 border-b border-[var(--gf-border)] flex items-center justify-between bg-gradient-to-r from-cyan-500/5 via-blue-500/5 to-transparent relative">
              <div className="absolute top-0 inset-x-0 h-px bg-gradient-to-r from-transparent via-[var(--gf-border-accent)] to-transparent" />
              <div className="flex items-center gap-4 relative z-10">
                <div className="h-10 w-10 rounded-[14px] bg-[var(--gf-panel-bg)] border border-[var(--gf-border-accent)] flex items-center justify-center text-cyan-500/80 shadow-[0_0_15px_var(--gf-glow-primary)]">
                  <MessageSquare size={22} />
                </div>
                <div>
                  <div className="text-sm font-black text-[var(--foreground)] tracking-widest uppercase">System Assist</div>
                  <div className="flex items-center gap-1.5 mt-0.5">
                    <div className="h-1.5 w-1.5 rounded-full bg-cyan-400 shadow-[0_0_8px_rgba(34,211,238,0.9)] animate-pulse" />
                    <span className="text-[9px] font-black text-cyan-500/80 uppercase tracking-[0.2em]">Neural Engine Online</span>
                  </div>
                </div>
              </div>
              <div className="flex items-center gap-2">
                <button
                  onClick={resetChat}
                  className="h-9 rounded-xl border border-white/10 bg-white/[0.03] px-3 text-[11px] font-black uppercase tracking-widest text-zinc-300 hover:text-white hover:border-white/20 transition-all"
                  type="button"
                >
                  Clear
                </button>
                <button
                  onClick={() => setIsOpen(false)}
                  className="p-2 rounded-full hover:bg-white/5 text-zinc-500 hover:text-white transition-all"
                  type="button"
                >
                  <X size={20} />
                </button>
              </div>
            </div>

            {/* Messages */}
            <div 
              ref={scrollRef}
              className="flex-1 overflow-y-auto p-6 space-y-6 gf-scrollbar"
            >
              {error ? (
                <div className="rounded-2xl border border-rose-400/20 bg-rose-500/10 px-4 py-3 text-xs text-rose-100">
                  {error}
                </div>
              ) : null}

              {messages.length <= 1 ? (
                <div className="space-y-3">
                  <div className="text-xs font-bold text-zinc-500 uppercase tracking-widest">Quick help</div>
                  <div className="flex flex-wrap gap-2">
                    {QUICK_PROMPTS.map((p) => (
                      <button
                        key={p}
                        type="button"
                        onClick={() => {
                          setIsOpen(true);
                          setInput(p);
                        }}
                        className="rounded-full border border-white/10 bg-white/[0.03] px-3 py-1.5 text-[12px] text-zinc-300 hover:text-white hover:border-white/20 transition"
                      >
                        {p}
                      </button>
                    ))}
                  </div>
                </div>
              ) : null}

              {messages.map((m) => (
                <motion.div
                  key={m.id}
                  initial={{ opacity: 0, y: 10 }}
                  animate={{ opacity: 1, y: 0 }}
                  className={`flex ${m.role === "user" ? "justify-end" : "justify-start"}`}
                >
                  <div className={`max-w-[85%] flex gap-3 ${m.role === "user" ? "flex-row-reverse" : "flex-row"}`}>
                    <div className={`h-8 w-8 rounded-lg flex items-center justify-center shrink-0 ${
                      m.role === "assistant" ? "bg-blue-500/10 text-blue-400" : "bg-white/5 text-zinc-400"
                    }`}>
                      {m.role === "assistant" ? <Bot size={16} /> : <User size={16} />}
                    </div>
                    <div className={`p-4 rounded-2xl text-sm leading-relaxed ${
                      m.role === "user" 
                        ? "bg-blue-500 text-white font-medium" 
                        : "bg-white/[0.03] border border-white/5 text-zinc-300"
                    }`}>
                      {m.type === "code" ? (
                        <div className="space-y-3">
                          <div className="flex items-center gap-2 text-[10px] font-black uppercase tracking-widest text-blue-400">
                            <Code size={12} /> Generated Snippet
                          </div>
                          <pre className="p-3 rounded-xl bg-black/40 border border-white/5 font-mono text-xs text-blue-300 overflow-x-auto">
                            {m.content.replace(/```javascript\n|```/g, '')}
                          </pre>
                        </div>
                      ) : m.type === "tip" ? (
                        <div className="flex gap-3">
                          <Lightbulb className="text-amber-400 shrink-0" size={18} />
                          <p className="italic font-medium text-amber-200/80">{m.content}</p>
                        </div>
                      ) : (
                        <p>{m.content}</p>
                      )}
                    </div>
                  </div>
                </motion.div>
              ))}
              {loading ? (
                <div className="flex justify-start">
                  <div className="max-w-[85%] flex gap-3">
                    <div className="h-8 w-8 rounded-lg flex items-center justify-center shrink-0 bg-blue-500/10 text-blue-400">
                      <Bot size={16} />
                    </div>
                    <div className="p-4 rounded-2xl text-sm leading-relaxed bg-white/[0.03] border border-white/5 text-zinc-300">
                      Thinking…
                    </div>
                  </div>
                </div>
              ) : null}
            </div>

            {/* Input */}
            <div className="p-6 border-t border-white/5 bg-white/[0.01]">
              <div className="relative flex items-center gap-2">
                <textarea
                  value={input}
                  onChange={(e) => setInput(e.target.value)}
                  onKeyDown={(e) => {
                    if (e.key === "Enter" && !e.shiftKey) {
                      e.preventDefault();
                      handleSend();
                    }
                  }}
                  rows={2}
                  placeholder="Ask about anything in the GameForge AI app… (Enter to send, Shift+Enter new line)"
                  className="w-full resize-none bg-white/5 border border-white/10 rounded-2xl px-5 py-4 text-sm text-white placeholder:text-zinc-600 outline-none focus:border-blue-500/50 transition-all"
                />
                <motion.button
                  whileHover={{ scale: 1.05 }}
                  whileTap={{ scale: 0.95 }}
                  onClick={handleSend}
                  className="h-12 w-12 rounded-xl bg-blue-500 text-white flex items-center justify-center shadow-lg disabled:opacity-50"
                  disabled={loading || !input.trim()}
                >
                  <Send size={18} />
                </motion.button>
              </div>
              <div className="mt-4 flex items-center gap-4">
                <div className="flex items-center gap-1.5 text-[9px] font-black text-zinc-600 uppercase tracking-widest">
                  <Zap size={10} className="text-blue-500" /> Support Mode
                </div>
                <div className="flex items-center gap-1.5 text-[9px] font-black text-zinc-600 uppercase tracking-widest">
                  <Code size={10} className="text-cyan-500" /> Troubleshoot
                </div>
              </div>
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </>
  );
}
