"use client";

import { motion, AnimatePresence } from "framer-motion";
import { 
  Zap, 
  Rocket, 
  Layers, 
  Trophy, 
  Users, 
  CheckCircle2, 
  Activity
} from "lucide-react";
import { useEffect, useState } from "react";

type ActivityItem = {
  id: string;
  user: string;
  action: string;
  target: string;
  time: string;
  icon: any;
  color: string;
};

const INITIAL_ACTIVITIES: ActivityItem[] = [
  { id: "1", user: "CyberNeon", action: "deployed", target: "Space Runner v2", time: "Just now", icon: Rocket, color: "text-indigo-400" },
  { id: "2", user: "MarioDev", action: "published", target: "Retro World", time: "2m ago", icon: Layers, color: "text-fuchsia-400" },
  { id: "3", user: "PixelWiz", action: "achieved", target: "Neural Master", time: "5m ago", icon: Trophy, color: "text-amber-400" },
  { id: "4", user: "BuildBot", action: "compiled", target: "Multiplayer Engine", time: "8m ago", icon: Zap, color: "text-cyan-400" },
];

export default function GlobalActivityFeed() {
  const [activities, setActivities] = useState<ActivityItem[]>(INITIAL_ACTIVITIES);

  useEffect(() => {
    const interval = setInterval(() => {
      const users = ["TechnoVibe", "GameSmith", "AI_Gen", "CloudWalker", "BitCrafter"];
      const actions = ["forged", "synced", "rendered", "optimized", "integrated"];
      const targets = ["Physics Core", "Voxel Shader", "Network Layer", "UI Preset", "Sound API"];
      const icons = [Activity, CheckCircle2, Zap, Rocket, Layers];
      const colors = ["text-indigo-400", "text-fuchsia-400", "text-cyan-400", "text-emerald-400", "text-rose-400"];

      const newItem: ActivityItem = {
        id: Math.random().toString(),
        user: users[Math.floor(Math.random() * users.length)],
        action: actions[Math.floor(Math.random() * actions.length)],
        target: targets[Math.floor(Math.random() * targets.length)],
        time: "Just now",
        icon: icons[Math.floor(Math.random() * icons.length)],
        color: colors[Math.floor(Math.random() * colors.length)],
      };

      setActivities(prev => [newItem, ...prev].slice(0, 6));
    }, 4000);

    return () => clearInterval(interval);
  }, []);

  return (
    <div className="space-y-3">
      <AnimatePresence initial={false}>
        {activities.map((a) => (
          <motion.div
            key={a.id}
            initial={{ opacity: 0, x: -20, height: 0 }}
            animate={{ opacity: 1, x: 0, height: "auto" }}
            exit={{ opacity: 0, x: 20, height: 0 }}
            transition={{ type: "spring", stiffness: 300, damping: 30 }}
            className="gf-panel flex items-center gap-4 p-4 rounded-2xl border border-white/5 bg-white/[0.01] hover:bg-white/[0.03] transition-colors overflow-hidden"
          >
            <div className={`p-2 rounded-xl bg-white/5 ${a.color}`}>
              <a.icon size={16} />
            </div>
            <div className="flex-1 min-w-0">
              <div className="text-xs font-medium text-white truncate">
                <span className="font-black text-indigo-400">{a.user}</span> {a.action}{" "}
                <span className="text-zinc-300 font-bold">{a.target}</span>
              </div>
              <div className="text-[10px] text-zinc-600 font-bold uppercase tracking-widest mt-0.5">{a.time}</div>
            </div>
            <div className="flex -space-x-2">
              <div className="h-6 w-6 rounded-full border-2 border-[#05060a] bg-zinc-800" />
            </div>
          </motion.div>
        ))}
      </AnimatePresence>
    </div>
  );
}
