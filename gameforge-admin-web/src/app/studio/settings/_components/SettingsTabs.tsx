"use client";

import { motion } from "framer-motion";
import { LayoutGroup } from "framer-motion";
import {
  User, Shield, Bell, CreditCard, Layout,
  ChevronRight
} from "lucide-react";

export type TabId = "profile" | "account" | "security" | "notifications" | "billing";

interface Tab {
  id: TabId;
  label: string;
  description: string;
  icon: any;
  color: string;
  bg: string;
}

const TABS: Tab[] = [
  { id: "profile",       label: "Profile",       description: "Edit display info",   icon: User,       color: "text-blue-400",  bg: "bg-blue-600/10 border-blue-500/20" },
  { id: "account",       label: "Account",       description: "Identity & plan",     icon: Layout,     color: "text-cyan-400",    bg: "bg-cyan-500/10 border-cyan-500/20" },
  { id: "security",      label: "Security",      description: "2FA & sessions",      icon: Shield,     color: "text-emerald-400", bg: "bg-emerald-500/10 border-emerald-500/20" },
  { id: "notifications", label: "Notifications", description: "Alerts & channels",   icon: Bell,       color: "text-amber-400",   bg: "bg-amber-500/10 border-amber-500/20" },
  { id: "billing",       label: "Billing",       description: "Credits & payments",  icon: CreditCard, color: "text-blue-400", bg: "bg-blue-600/10 border-blue-500/20" },
];

export default function SettingsTabs({
  activeTab,
  onTabChange,
}: {
  activeTab: TabId;
  onTabChange: (id: TabId) => void;
}) {
  return (
    <div className="flex flex-col gap-1 w-full lg:w-56 shrink-0">
      <p className="text-[9px] font-black uppercase tracking-[0.28em] text-zinc-700 px-3 mb-2">
        Settings
      </p>
      <LayoutGroup>
        {TABS.map((tab) => {
          const Icon = tab.icon;
          const isActive = activeTab === tab.id;

          return (
            <button
              key={tab.id}
              onClick={() => onTabChange(tab.id)}
              className={`relative group flex items-center gap-3 px-3 py-2.5 rounded-[14px] text-sm transition-all duration-250 text-left ${
                isActive ? "text-white" : "text-zinc-500 hover:text-zinc-300"
              }`}
            >
              {/* Active animated background */}
              {isActive && (
                <motion.div
                  layoutId="activeSettingsTab"
                  className="absolute inset-0 bg-gradient-to-r from-blue-500/10 via-blue-500/5 to-transparent border border-blue-500/15 rounded-[14px]"
                  initial={false}
                  transition={{ type: "spring", stiffness: 380, damping: 32 }}
                />
              )}

              {/* Active left indicator */}
              {isActive && (
                <motion.div
                  layoutId="activeSettingsIndicator"
                  className="absolute left-0 top-1/2 -translate-y-1/2 w-[3px] h-[18px] rounded-r-full bg-blue-400 shadow-[0_0_8px_rgba(129,140,248,0.8)]"
                  initial={false}
                  transition={{ type: "spring", stiffness: 380, damping: 32 }}
                />
              )}

              {/* Hover bg */}
              {!isActive && (
                <div className="absolute inset-0 rounded-[14px] bg-white/[0.02] opacity-0 group-hover:opacity-100 transition-opacity duration-200" />
              )}

              {/* Icon */}
              <div className={`relative z-10 shrink-0 h-8 w-8 rounded-[10px] border flex items-center justify-center transition-all duration-300 ${
                isActive ? `${tab.bg}` : "bg-white/[0.02] border-white/[0.05]"
              }`}>
                <Icon size={15} className={`transition-colors duration-300 ${isActive ? tab.color : "text-zinc-600 group-hover:text-zinc-400"}`} />
              </div>

              {/* Label + description */}
              <div className="relative z-10 flex-1 min-w-0">
                <p className={`text-[13px] font-semibold leading-tight tracking-[-0.01em] transition-colors ${isActive ? "text-white" : "text-zinc-500 group-hover:text-zinc-300"}`}>
                  {tab.label}
                </p>
                <p className="text-[10px] text-zinc-700 group-hover:text-zinc-600 transition-colors leading-tight mt-0.5 font-medium">
                  {tab.description}
                </p>
              </div>

              {/* Active chevron */}
              {isActive && (
                <ChevronRight size={12} className="relative z-10 shrink-0 text-blue-400/60" />
              )}
            </button>
          );
        })}
      </LayoutGroup>
    </div>
  );
}
