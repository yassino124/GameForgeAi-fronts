"use client";

import { useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { BrainCircuit, ChevronRight, Wand2, Layout, Gamepad2, Layers, Plus } from "lucide-react";

type Node = {
  id: string;
  title: string;
  desc: string;
  type: "objective" | "mechanic" | "narrative";
};

const INITIAL_NODES: Node[] = [
  { id: "1", title: "The Awakening", desc: "Player wakes up in a zero-gravity void.", type: "narrative" },
  { id: "2", title: "Core Mechanic", desc: "Dash-based movement with energy cost.", type: "mechanic" },
  { id: "3", title: "Primary Goal", desc: "Collect 3 neural fragments to restore power.", type: "objective" },
];

export default function AIStoryboard() {
  const [nodes, setNodes] = useState<Node[]>(INITIAL_NODES);
  const [isGenerating, setIsGenerating] = useState(false);

  const generateNewNode = () => {
    setIsGenerating(true);
    setTimeout(() => {
      const ideas: Omit<Node, "id">[] = [
        { title: "Neural Link", desc: "Establish connection with a rogue AI entity.", type: "narrative" },
        { title: "Gravity Flip", desc: "Environment rotates 180 degrees on command.", type: "mechanic" },
        { title: "Vault Breach", desc: "Infiltrate the high-security asset storage.", type: "objective" },
      ];
      const randomIdea = ideas[Math.floor(Math.random() * ideas.length)];
      setNodes(prev => [...prev, { ...randomIdea, id: Date.now().toString() } as Node]);
      setIsGenerating(false);
    }, 1500);
  };

  return (
    <div className="gf-holographic rounded-[40px] p-8 relative overflow-hidden">
      <div className="flex items-center justify-between mb-10 relative z-10">
        <div className="flex items-center gap-4">
          <div className="h-12 w-12 rounded-2xl bg-indigo-500/20 flex items-center justify-center text-indigo-400">
            <BrainCircuit size={24} />
          </div>
          <div>
            <h3 className="text-xl font-bold text-white tracking-tight uppercase italic">Neural Storyboard</h3>
            <p className="text-[10px] text-zinc-500 font-bold uppercase tracking-widest mt-1">AI-Generated Mission Architecture</p>
          </div>
        </div>
        <button 
          onClick={generateNewNode}
          disabled={isGenerating}
          className="flex items-center gap-2 px-6 py-3 rounded-2xl bg-white text-black text-[10px] font-black uppercase tracking-widest hover:scale-105 active:scale-95 transition-all disabled:opacity-50"
        >
          {isGenerating ? (
            <div className="h-3 w-3 border-2 border-black/30 border-t-black animate-spin rounded-full" />
          ) : (
            <><Plus size={14} strokeWidth={3} /> Expand Blueprint</>
          )}
        </button>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-6 relative z-10">
        <AnimatePresence>
          {nodes.map((node, i) => (
            <motion.div
              key={node.id}
              initial={{ opacity: 0, scale: 0.9, y: 20 }}
              animate={{ opacity: 1, scale: 1, y: 0 }}
              transition={{ delay: i * 0.1 }}
              className="p-6 rounded-3xl bg-white/[0.02] border border-white/5 relative group hover:bg-white/[0.04] transition-all"
            >
              <div className="flex items-center gap-2 mb-4">
                <div className={`h-1.5 w-1.5 rounded-full ${
                  node.type === "narrative" ? "bg-fuchsia-500" : 
                  node.type === "mechanic" ? "bg-cyan-500" : "bg-amber-500"
                }`} />
                <span className="text-[8px] font-black uppercase tracking-[0.2em] text-zinc-500">{node.type}</span>
              </div>
              <h4 className="text-sm font-bold text-white uppercase tracking-tight mb-2">{node.title}</h4>
              <p className="text-xs text-zinc-500 leading-relaxed">{node.desc}</p>
              
              <div className="mt-6 flex items-center justify-between pt-4 border-t border-white/5 opacity-0 group-hover:opacity-100 transition-opacity">
                <span className="text-[9px] font-bold text-indigo-400 uppercase">Neural Link Established</span>
                <ChevronRight size={14} className="text-zinc-600" />
              </div>
            </motion.div>
          ))}
        </AnimatePresence>
      </div>

      {/* Connection Lines Background */}
      <div className="absolute inset-0 pointer-events-none opacity-[0.03]">
        <svg className="w-full h-full">
          <pattern id="grid" width="40" height="40" patternUnits="userSpaceOnUse">
            <path d="M 40 0 L 0 0 0 40" fill="none" stroke="white" strokeWidth="1" />
          </pattern>
          <rect width="100%" height="100%" fill="url(#grid)" />
        </svg>
      </div>
    </div>
  );
}
