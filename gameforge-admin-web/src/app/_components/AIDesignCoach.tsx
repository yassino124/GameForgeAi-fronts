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
      content: "Hello! I'm your Neural Design Coach. How can I help you forge your next masterpiece today?",
      type: "text"
    }
  ]);
  const [input, setInput] = useState("");
  const scrollRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (scrollRef.current) {
      scrollRef.current.scrollTop = scrollRef.current.scrollHeight;
    }
  }, [messages, isOpen]);

  const handleSend = () => {
    if (!input.trim()) return;

    const userMsg: Message = { id: Date.now().toString(), role: "user", content: input };
    setMessages(prev => [...prev, userMsg]);
    setInput("");

    // Mock AI Response based on keywords
    setTimeout(() => {
      let aiResponse: Message = {
        id: (Date.now() + 1).toString(),
        role: "assistant",
        content: "I'm analyzing your request using the Forge-V4 engine...",
        type: "text"
      };

      if (input.toLowerCase().includes("code") || input.toLowerCase().includes("script")) {
        aiResponse = {
          id: (Date.now() + 1).toString(),
          role: "assistant",
          content: "```javascript\n// AI-Generated Physics Controller\nfunction update(dt) {\n  this.velocity.y += global.gravity * dt;\n  this.position.add(this.velocity);\n}\n```",
          type: "code"
        };
      } else if (input.toLowerCase().includes("tip") || input.toLowerCase().includes("help")) {
        aiResponse = {
          id: (Date.now() + 1).toString(),
          role: "assistant",
          content: "Pro Tip: Use 'Spatial Partitioning' to handle thousands of entities without dropping below 60FPS.",
          type: "tip"
        };
      } else {
        aiResponse = {
          id: (Date.now() + 1).toString(),
          role: "assistant",
          content: "That's a great idea! We can implement that using the Neural Weaving module. Should I generate a blueprint?",
          type: "text"
        };
      }

      setMessages(prev => [...prev, aiResponse]);
    }, 1000);
  };

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
            className="fixed bottom-28 right-8 z-[101] w-[400px] h-[600px] gf-panel-strong gf-stroke-gradient rounded-[32px] shadow-2xl overflow-hidden flex flex-col bg-[#0a0b14]/95 backdrop-blur-2xl"
          >
            {/* Header */}
            <div className="p-6 border-b border-white/5 flex items-center justify-between bg-white/[0.02]">
              <div className="flex items-center gap-3">
                <div className="h-10 w-10 rounded-xl bg-indigo-500/20 flex items-center justify-center text-indigo-400">
                  <Bot size={22} />
                </div>
                <div>
                  <div className="text-sm font-black text-white uppercase tracking-tight">Neural Coach</div>
                  <div className="flex items-center gap-1.5">
                    <div className="h-1.5 w-1.5 rounded-full bg-emerald-500 animate-pulse" />
                    <span className="text-[10px] font-bold text-zinc-500 uppercase tracking-widest">Forge-V4 Active</span>
                  </div>
                </div>
              </div>
              <button 
                onClick={() => setIsOpen(false)}
                className="p-2 rounded-full hover:bg-white/5 text-zinc-500 hover:text-white transition-all"
              >
                <X size={20} />
              </button>
            </div>

            {/* Messages */}
            <div 
              ref={scrollRef}
              className="flex-1 overflow-y-auto p-6 space-y-6 gf-scrollbar"
            >
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
            </div>

            {/* Input */}
            <div className="p-6 border-t border-white/5 bg-white/[0.01]">
              <div className="relative flex items-center gap-2">
                <input 
                  value={input}
                  onChange={(e) => setInput(e.target.value)}
                  onKeyDown={(e) => e.key === "Enter" && handleSend()}
                  placeholder="Ask for design tips or logic scripts..."
                  className="w-full bg-white/5 border border-white/10 rounded-2xl px-5 py-4 text-sm text-white placeholder:text-zinc-600 outline-none focus:border-indigo-500/50 transition-all"
                />
                <motion.button
                  whileHover={{ scale: 1.05 }}
                  whileTap={{ scale: 0.95 }}
                  onClick={handleSend}
                  className="h-12 w-12 rounded-xl bg-indigo-500 text-white flex items-center justify-center shadow-lg"
                >
                  <Send size={18} />
                </motion.button>
              </div>
              <div className="mt-4 flex items-center gap-4">
                <div className="flex items-center gap-1.5 text-[9px] font-black text-zinc-600 uppercase tracking-widest">
                  <Zap size={10} className="text-indigo-500" /> Neural Mode
                </div>
                <div className="flex items-center gap-1.5 text-[9px] font-black text-zinc-600 uppercase tracking-widest">
                  <Code size={10} className="text-fuchsia-500" /> Auto-Script
                </div>
              </div>
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </>
  );
}
