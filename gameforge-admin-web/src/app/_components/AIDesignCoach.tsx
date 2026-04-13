"use client";

import { useState, useRef, useEffect } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { MessageSquare, Sparkles, X, Send, Bot, User, Zap, Code, Lightbulb } from "lucide-react";

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
      {/* Trigger Button */}
      <motion.button
        whileHover={{ scale: 1.05 }}
        whileTap={{ scale: 0.95 }}
        onClick={() => setIsOpen(true)}
        className="fixed bottom-8 right-8 z-[100] h-16 w-16 rounded-full bg-indigo-500 text-white shadow-[0_0_30px_rgba(99,102,241,0.5)] flex items-center justify-center group"
      >
        <div className="absolute inset-0 rounded-full bg-indigo-400 animate-ping opacity-20" />
        <Sparkles className="group-hover:rotate-12 transition-transform" size={28} />
      </motion.button>

      {/* Chat Window */}
      <AnimatePresence>
        {isOpen && (
          <motion.div
            initial={{ opacity: 0, scale: 0.9, y: 20, x: 20 }}
            animate={{ opacity: 1, scale: 1, y: 0, x: 0 }}
            exit={{ opacity: 0, scale: 0.9, y: 20, x: 20 }}
            className="fixed bottom-28 right-8 z-[101] w-[min(420px,92vw)] h-[min(640px,78vh)] gf-panel-strong gf-stroke-gradient rounded-[32px] shadow-2xl overflow-hidden flex flex-col bg-[#0a0b14]/95 backdrop-blur-2xl"
          >
            {/* Header */}
            <div className="p-6 border-b border-white/5 flex items-center justify-between bg-white/[0.02]">
              <div className="flex items-center gap-3">
                <div className="h-10 w-10 rounded-xl bg-indigo-500/20 flex items-center justify-center text-indigo-400">
                  <Bot size={22} />
                </div>
                <div>
                  <div className="text-sm font-black text-white uppercase tracking-tight">Support Coach</div>
                  <div className="flex items-center gap-1.5">
                    <div className="h-1.5 w-1.5 rounded-full bg-emerald-500 animate-pulse" />
                    <span className="text-[10px] font-bold text-zinc-500 uppercase tracking-widest">Ollama Active</span>
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
                      m.role === "assistant" ? "bg-indigo-500/10 text-indigo-400" : "bg-white/5 text-zinc-400"
                    }`}>
                      {m.role === "assistant" ? <Bot size={16} /> : <User size={16} />}
                    </div>
                    <div className={`p-4 rounded-2xl text-sm leading-relaxed ${
                      m.role === "user" 
                        ? "bg-indigo-500 text-white font-medium" 
                        : "bg-white/[0.03] border border-white/5 text-zinc-300"
                    }`}>
                      {m.type === "code" ? (
                        <div className="space-y-3">
                          <div className="flex items-center gap-2 text-[10px] font-black uppercase tracking-widest text-indigo-400">
                            <Code size={12} /> Generated Snippet
                          </div>
                          <pre className="p-3 rounded-xl bg-black/40 border border-white/5 font-mono text-xs text-indigo-300 overflow-x-auto">
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
                    <div className="h-8 w-8 rounded-lg flex items-center justify-center shrink-0 bg-indigo-500/10 text-indigo-400">
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
                  className="w-full resize-none bg-white/5 border border-white/10 rounded-2xl px-5 py-4 text-sm text-white placeholder:text-zinc-600 outline-none focus:border-indigo-500/50 transition-all"
                />
                <motion.button
                  whileHover={{ scale: 1.05 }}
                  whileTap={{ scale: 0.95 }}
                  onClick={handleSend}
                  className="h-12 w-12 rounded-xl bg-indigo-500 text-white flex items-center justify-center shadow-lg disabled:opacity-50"
                  disabled={loading || !input.trim()}
                >
                  <Send size={18} />
                </motion.button>
              </div>
              <div className="mt-4 flex items-center gap-4">
                <div className="flex items-center gap-1.5 text-[9px] font-black text-zinc-600 uppercase tracking-widest">
                  <Zap size={10} className="text-indigo-500" /> Support Mode
                </div>
                <div className="flex items-center gap-1.5 text-[9px] font-black text-zinc-600 uppercase tracking-widest">
                  <Code size={10} className="text-fuchsia-500" /> Troubleshoot
                </div>
              </div>
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </>
  );
}
