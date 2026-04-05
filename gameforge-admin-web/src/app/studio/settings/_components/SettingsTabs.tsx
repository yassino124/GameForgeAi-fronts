"use client";

import { motion } from "framer-motion";
import { User, Shield, Bell, CreditCard, Layout } from "lucide-react";

export type TabId = "profile" | "account" | "security" | "notifications" | "billing";

interface Tab {
  id: TabId;
  label: string;
  icon: any;
}

const TABS: Tab[] = [
  { id: "profile", label: "Profile", icon: User },
  { id: "account", label: "Account", icon: Layout },
  { id: "security", label: "Security", icon: Shield },
  { id: "notifications", label: "Notifications", icon: Bell },
  { id: "billing", label: "Billing", icon: CreditCard },
];

export default function SettingsTabs({ activeTab, onTabChange }: { activeTab: TabId; onTabChange: (id: TabId) => void }) {
  return (
    <div className="flex flex-col gap-1 w-full lg:w-64 shrink-0">
      <div className="px-4 mb-4">
        <h2 className="text-xs font-bold text-zinc-500 uppercase tracking-widest">Settings</h2>
      </div>
      {TABS.map((tab) => {
        const Icon = tab.icon;
        const isActive = activeTab === tab.id;
        
        return (
          <button
            key={tab.id}
            onClick={() => onTabChange(tab.id)}
            className={`
              relative group flex items-center gap-3 px-4 py-3 rounded-2xl text-sm transition-all duration-300
              ${isActive ? "text-white" : "text-zinc-400 hover:text-white hover:bg-white/5"}
            `}
          >
            {isActive && (
              <motion.div
                layoutId="activeTabBackground"
                className="absolute inset-0 bg-gradient-to-r from-indigo-500/10 via-indigo-500/5 to-transparent border border-indigo-500/20 rounded-2xl"
                initial={false}
                transition={{ type: "spring", stiffness: 350, damping: 30 }}
              />
            )}
            {isActive && (
              <motion.div
                layoutId="activeTabIndicator"
                className="absolute left-0 top-1/2 -translate-y-1/2 w-1 h-5 rounded-r-full bg-indigo-500 shadow-[0_0_12px_rgba(99,102,241,0.8)]"
                initial={false}
              />
            )}
            
            <Icon size={18} className={`relative z-10 ${isActive ? "text-indigo-400" : "text-zinc-500 group-hover:text-zinc-300"}`} />
            <span className="relative z-10 font-medium">{tab.label}</span>
          </button>
        );
      })}
    </div>
  );
}
