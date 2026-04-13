"use client";

import { ReactNode, useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { clearToken, getToken } from "@/lib/auth";
import { apiFetch } from "@/lib/api";
import CommandPalette from "@/app/_components/CommandPalette";
import {
  Moon, Sun, SquaresFour, Folders,
  Users, Radio, Package, TerminalWindow, Heartbeat,
  Hammer, Bell, CreditCard, Gear, User,
  SignOut, List, X, Sparkle, GameController
} from "@phosphor-icons/react";
import { motion, AnimatePresence, LayoutGroup } from "framer-motion";
import NeuralFlux from "./NeuralFlux";
import ForgeLogo from "./ForgeLogo";
import { useTheme } from "./ThemeProvider";

function cx(...parts: Array<string | false | null | undefined>) {
  return parts.filter(Boolean).join(" ");
}

const NAV_ITEMS = [
  { href: "/dashboard", label: "Dashboard", icon: SquaresFour, color: "text-cyan-400", shadow: "drop-shadow-[0_0_10px_rgba(34,211,238,0.8)]", bgHover: "group-hover:bg-cyan-500/10 group-hover:border-cyan-500/20", bgActive: "bg-cyan-500/20 border-cyan-500/40", glowBase: "bg-cyan-500", match: (p: string) => p === "/dashboard" },
  { href: "/builds", label: "Builds / Queue", icon: Hammer, color: "text-orange-400", shadow: "drop-shadow-[0_0_10px_rgba(251,146,60,0.8)]", bgHover: "group-hover:bg-orange-500/10 group-hover:border-orange-500/20", bgActive: "bg-orange-500/20 border-orange-500/40", glowBase: "bg-orange-500", match: (p: string) => p === "/builds" },
  { href: "/projects", label: "Projects", icon: Folders, color: "text-teal-400", shadow: "drop-shadow-[0_0_10px_rgba(45,212,191,0.8)]", bgHover: "group-hover:bg-teal-500/10 group-hover:border-teal-500/20", bgActive: "bg-teal-500/20 border-teal-500/40", glowBase: "bg-teal-500", match: (p: string) => p === "/projects" },
  { href: "/feed", label: "Game Feed", icon: GameController, color: "text-emerald-400", shadow: "drop-shadow-[0_0_10px_rgba(52,211,153,0.8)]", bgHover: "group-hover:bg-emerald-500/10 group-hover:border-emerald-500/20", bgActive: "bg-emerald-500/20 border-emerald-500/40", glowBase: "bg-emerald-500", match: (p: string) => p?.startsWith("/feed") },
  { href: "/multiplayer", label: "Multiplayer", icon: Users, color: "text-blue-400", shadow: "drop-shadow-[0_0_10px_rgba(96,165,250,0.8)]", bgHover: "group-hover:bg-blue-500/10 group-hover:border-blue-500/20", bgActive: "bg-blue-500/20 border-blue-500/40", glowBase: "bg-blue-500", match: (p: string) => p?.startsWith("/multiplayer") },
  { href: "/live", label: "Live Sessions", icon: Radio, color: "text-red-400", shadow: "drop-shadow-[0_0_10px_rgba(248,113,113,0.8)]", bgHover: "group-hover:bg-red-500/10 group-hover:border-red-500/20", bgActive: "bg-red-500/20 border-red-500/40", glowBase: "bg-red-500", match: (p: string) => p?.startsWith("/live") },
  { href: "/users", label: "Users", icon: User, color: "text-fuchsia-400", shadow: "drop-shadow-[0_0_10px_rgba(232,121,249,0.8)]", bgHover: "group-hover:bg-fuchsia-500/10 group-hover:border-fuchsia-500/20", bgActive: "bg-fuchsia-500/20 border-fuchsia-500/40", glowBase: "bg-fuchsia-500", match: (p: string) => p === "/users" },
  { href: "/templates", label: "Templates", icon: Package, color: "text-amber-400", shadow: "drop-shadow-[0_0_10px_rgba(251,191,36,0.8)]", bgHover: "group-hover:bg-amber-500/10 group-hover:border-amber-500/20", bgActive: "bg-amber-500/20 border-amber-500/40", glowBase: "bg-amber-500", match: (p: string) => p === "/templates" },
  { href: "/messages", label: "Support Inbox", icon: List, color: "text-violet-400", shadow: "drop-shadow-[0_0_10px_rgba(167,139,250,0.8)]", bgHover: "group-hover:bg-violet-500/10 group-hover:border-violet-500/20", bgActive: "bg-violet-500/20 border-violet-500/40", glowBase: "bg-violet-500", match: (p: string) => p === "/messages" },
  { href: "/notifications", label: "Notifications", icon: Bell, color: "text-pink-400", shadow: "drop-shadow-[0_0_10px_rgba(244,114,182,0.8)]", bgHover: "group-hover:bg-pink-500/10 group-hover:border-pink-500/20", bgActive: "bg-pink-500/20 border-pink-500/40", glowBase: "bg-pink-500", match: (p: string) => p === "/notifications" },
  { href: "/billing", label: "Billing", icon: CreditCard, color: "text-emerald-400", shadow: "drop-shadow-[0_0_10px_rgba(52,211,153,0.8)]", bgHover: "group-hover:bg-emerald-500/10 group-hover:border-emerald-500/20", bgActive: "bg-emerald-500/20 border-emerald-500/40", glowBase: "bg-emerald-500", match: (p: string) => p === "/billing" },
  { href: "/system", label: "System", icon: Gear, color: "text-slate-300", shadow: "drop-shadow-[0_0_10px_rgba(203,213,225,0.8)]", bgHover: "group-hover:bg-slate-500/10 group-hover:border-slate-500/20", bgActive: "bg-slate-500/20 border-slate-500/40", glowBase: "bg-slate-500", match: (p: string) => p === "/system" },
];

const QUICK_LINKS = [
  { href: "http://localhost:3000/api/docs", label: "API Docs", icon: TerminalWindow, color: "text-violet-400", shadow: "drop-shadow-[0_0_10px_rgba(167,139,250,0.8)]", bgHover: "group-hover:bg-violet-500/10 group-hover:border-violet-500/20", bgActive: "bg-violet-500/20 border-violet-500/40", glowBase: "bg-violet-500", match: () => false, external: true },
  { href: "http://localhost:3000/api/health", label: "Health", icon: Heartbeat, color: "text-rose-400", shadow: "drop-shadow-[0_0_10px_rgba(251,113,133,0.8)]", bgHover: "group-hover:bg-rose-500/10 group-hover:border-rose-500/20", bgActive: "bg-rose-500/20 border-rose-500/40", glowBase: "bg-rose-500", match: () => false, external: true },
];

function NavItem({ item, pathname, isExpanded, onClick }: any) {
  const active = item.match(pathname);
  const Icon = item.icon;

  const inner = (
    <>
      {/* Active Background Glow */}
      {active && (
        <motion.div
          layoutId="activeNavBackgroundAdmin"
          className="absolute inset-0 bg-gradient-to-r from-indigo-500/15 via-purple-500/5 to-transparent border border-indigo-500/20 rounded-2xl"
          initial={false}
          transition={{ type: "spring", stiffness: 350, damping: 30 }}
        />
      )}

      {/* Active Left Pill Indicator */}
      {active && (
        <motion.div
          layoutId="activeLeftIndicatorAdmin"
          className="absolute left-[2px] top-1/2 -translate-y-1/2 w-[3px] h-5 rounded-r-md bg-indigo-400 shadow-[0_0_12px_rgba(129,140,248,0.9)]"
          initial={false}
          transition={{ type: "spring", stiffness: 350, damping: 30 }}
        />
      )}

      {/* Hover Background for inactive links */}
      {!active && (
        <div className="absolute inset-0 rounded-2xl bg-white/[0.02] border border-white/0 opacity-0 group-hover:opacity-100 group-hover:border-white/[0.05] transition-all duration-300" />
      )}

      <div className={cx(
        "relative z-10 flex items-center justify-center shrink-0 w-8 h-8 rounded-[10px] transition-all duration-500 ease-[cubic-bezier(0.2,1,0.4,1)]",
        active
          ? `${item.bgActive} shadow-[inset_0_1px_4px_rgba(255,255,255,0.1),0_0_15px_rgba(0,0,0,0.3)]`
          : `bg-white/[0.02] border border-white/5 ${item.bgHover} group-hover:shadow-[0_4px_12px_rgba(0,0,0,0.5)]`,
        !active && "group-hover:-translate-y-[2px] group-hover:scale-105"
      )}>
        {active && (
          <motion.div
            layoutId="activeIconGlowAdmin"
            className={`absolute inset-0 ${item.glowBase}/30 blur-md rounded-[10px]`}
            transition={{ type: "spring", stiffness: 350, damping: 30 }}
          />
        )}
        <Icon
          size={18}
          weight="duotone"
          className={cx(
            "relative z-10 transition-all duration-500",
            active ? `${item.color} ${item.shadow}` : `text-zinc-500 group-hover:${item.color} group-hover:${item.shadow}`
          )}
        />
      </div>

      <div className={cx(
        "flex items-center justify-between overflow-hidden transition-all duration-500 ease-[cubic-bezier(0.2,1,0.4,1)] whitespace-nowrap",
        isExpanded ? "w-full opacity-100 ml-3 translate-x-0" : "w-0 opacity-0 ml-0 -translate-x-4",
        "pointer-events-none"
      )}>
        <span className={cx(
          "font-bold tracking-wide text-[13px] transition-colors duration-300 pointer-events-auto",
          active ? "text-white" : "text-zinc-400 group-hover:text-white"
        )}>
          {item.label}
        </span>
        {item.badge && (
          <span className="shrink-0 ml-3 rounded-[5px] border border-indigo-500/30 bg-indigo-500/10 px-1.5 py-[2px] text-[8px] font-black text-indigo-300 tracking-[0.15em] uppercase shadow-[0_0_10px_rgba(99,102,241,0.15)]">
            {item.badge}
          </span>
        )}
      </div>
    </>
  );

  const classNameStr = cx(
    "relative group flex items-center rounded-2xl p-3 text-sm transition-all duration-300",
    active ? "text-white" : "text-zinc-400 hover:text-white",
    isExpanded ? "justify-start px-3" : "justify-center"
  );

  if (item.external) {
    return (
      <a href={item.href} target="_blank" rel="noreferrer" onClick={onClick} className={classNameStr} title={!isExpanded ? item.label : undefined}>
        {inner}
      </a>
    );
  }

  return (
    <Link href={item.href} onClick={onClick} className={classNameStr} title={!isExpanded ? item.label : undefined}>
      {inner}
    </Link>
  );
}

export default function AdminShell(props: { title: string; subtitle?: string; right?: ReactNode; children: ReactNode }) {
  const router = useRouter();
  const pathname = usePathname();
  const token = useMemo(() => getToken(), []);
  const { theme, toggleTheme } = useTheme();
  const [mounted, setMounted] = useState(false);
  const [isHovered, setIsHovered] = useState(false);
  const [isMobileOpen, setIsMobileOpen] = useState(false);
  const [isSidebarHidden, setIsSidebarHidden] = useState<boolean>(true);
  const [paletteOpen, setPaletteOpen] = useState(false);
  const [isSidebarPinned, setIsSidebarPinned] = useState(true);
  const [user, setUser] = useState<any>(null);

  useEffect(() => {
    async function loadMe() {
      if (!token) return;
      try {
        const res = await apiFetch<any>("/auth/profile", { method: "GET", token });
        const data = res?.data || res;
        setUser(data?.user || data);
      } catch (e) { }
    }
    loadMe();
  }, [token]);

  // Load persistence from localStorage on mount
  useEffect(() => {
    const saved = localStorage.getItem("gf_admin_sidebar_hidden");
    if (saved !== null) {
      setIsSidebarHidden(saved === "true");
    }
  }, []);

  // Save changes to localStorage
  const toggleSidebar = () => {
    const newState = !isSidebarHidden;
    setIsSidebarHidden(newState);
    localStorage.setItem("gf_admin_sidebar_hidden", String(newState));
  };

  const isExpanded = isMobileOpen || isSidebarPinned;

  useEffect(() => {
    setMounted(true);
  }, []);

  useEffect(() => {
    if (!mounted) return;
    if (!token) router.replace("/login");
  }, [mounted, router, token]);

  useEffect(() => {
    if (!mounted) return;
    const onKey = (e: KeyboardEvent) => {
      const isK = (e.key || "").toLowerCase() === "k";
      const mod = e.metaKey || e.ctrlKey;
      if (mod && isK) {
        e.preventDefault();
        setPaletteOpen(true);
      }
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [mounted]);

  if (!mounted) return null;

  return (
    <div className="gf-app min-h-screen w-full flex flex-col font-sans transition-colors duration-500">
      <NeuralFlux />
      <div className="pointer-events-none fixed inset-0 z-0">
        <div className="gf-grid absolute inset-0 opacity-[0.25]" />
        <div className="gf-noise absolute inset-0 opacity-[0.25]" />
        <div className="absolute top-0 left-1/4 w-1/2 h-[350px] bg-indigo-500/10 blur-[150px] rounded-full mix-blend-screen" />
        <div className="absolute top-[20%] right-[10%] w-[30%] h-[300px] bg-purple-500/5 blur-[120px] rounded-full mix-blend-screen" />
      </div>

      {/* Mobile Header */}
      <div className="lg:hidden relative z-30 flex items-center justify-between p-4 border-b border-white/5 bg-black/60 backdrop-blur-2xl">
        <div className="flex items-center gap-3">
          <button onClick={() => setIsMobileOpen(true)} className="p-2 -ml-2 text-zinc-400 hover:text-white transition-colors flex items-center justify-center">
            <List size={24} weight="bold" />
          </button>
          <div className="w-8 h-8 rounded-lg bg-gradient-to-br from-indigo-500 via-purple-500 to-cyan-500 flex items-center justify-center shadow-[0_0_15px_rgba(99,102,241,0.5)] overflow-hidden">
            <ForgeLogo size={20} className="text-white scale-[1.5] -ml-1" />
          </div>
          <span className="font-extrabold text-sm bg-clip-text text-transparent bg-gradient-to-r from-white to-zinc-400 tracking-tight">GameForge Admin</span>
        </div>
        <button className="h-8 w-8 rounded-lg border border-white/10 bg-white/5 flex items-center justify-center shadow-lg" onClick={toggleTheme}>
          {theme === "dark" ? <Sun size={14} weight="duotone" className="text-amber-400" /> : <Moon size={14} weight="duotone" className="text-indigo-400" />}
        </button>
      </div>

      <div className={cx("relative z-10 mx-auto w-full max-w-[1600px] flex-1 flex p-4 sm:p-5 min-h-0", isSidebarHidden ? "gap-0" : "gap-5")}>

        {/* Mobile Overlay */}
        <AnimatePresence>
          {isMobileOpen && (
            <motion.div
              initial={{ opacity: 0, backdropFilter: "blur(0px)" }}
              animate={{ opacity: 1, backdropFilter: "blur(12px)" }}
              exit={{ opacity: 0, backdropFilter: "blur(0px)" }}
              onClick={() => setIsMobileOpen(false)}
              className="fixed inset-0 bg-black/70 z-40 lg:hidden"
            />
          )}
        </AnimatePresence>

        {/* Sidebar Drawer */}
        <motion.aside
          onMouseEnter={() => setIsHovered(true)}
          onMouseLeave={() => setIsHovered(false)}
          initial={false}
          animate={{
            width: isSidebarHidden ? 0 : (isExpanded ? 280 : 76),
            x: isMobileOpen ? 0 : (typeof window !== 'undefined' && window.innerWidth < 1024 ? -100 : (isSidebarHidden ? -100 : 0)),
            opacity: isSidebarHidden ? 0 : 1
          }}
          className={cx(
            "fixed lg:sticky lg:top-5 z-50 flex flex-col transition-[width] duration-500 ease-[cubic-bezier(0.2,1,0.4,1)] h-[100dvh] lg:h-[calc(100vh-40px)] overflow-hidden shrink-0 self-start",
            "border-r border-white/5 lg:border lg:border-white/[0.08] lg:rounded-[2rem] bg-[#08080b]/95 lg:bg-gradient-to-br lg:from-[#13141f]/70 lg:to-[#07070a]/80 lg:backdrop-blur-[60px]",
            isExpanded ? "lg:shadow-[0_0_80px_-10px_rgba(99,102,241,0.15),inset_0_1px_0_0_rgba(255,255,255,0.05)]" : "lg:shadow-[0_4px_30px_rgba(0,0,0,0.4),inset_0_1px_0_0_rgba(255,255,255,0.05)]",
            isMobileOpen ? "translate-x-0 w-[280px]" : "max-lg:-translate-x-full",
            isExpanded ? "p-4" : "p-3 pb-4 items-center"
          )}
          style={{ willChange: "width, transform" }}
        >
          {/* Mobile Close Button */}
          <button
            onClick={() => setIsMobileOpen(false)}
            className="lg:hidden absolute top-4 right-4 text-zinc-400 hover:text-white transition-colors z-20"
          >
            <X size={20} weight="bold" />
          </button>

          <div className={cx("flex items-center relative z-10", isExpanded ? "justify-between" : "justify-center mt-2")}>
            <div className={cx("group flex items-center gap-3 overflow-hidden transition-all duration-500", isExpanded ? "w-full" : "w-0 opacity-0")}>
              <div className="shrink-0 flex items-center justify-center -ml-1">
                <ForgeLogo iconOnly size={40} className="hover:scale-105 transition-transform duration-300 drop-shadow-[0_4px_15px_rgba(99,102,241,0.6)]" />
              </div>
              <div className="flex flex-col whitespace-nowrap ml-1 -mt-0.5 cursor-default">
                <p className="text-[10px] uppercase tracking-[0.25em] text-emerald-400 font-extrabold h-3 opacity-90 drop-shadow-[0_0_8px_rgba(52,211,153,0.4)]">Master Architect</p>
                <p className="text-[20px] mt-[1px] font-black tracking-[-0.04em] bg-clip-text text-transparent bg-gradient-to-br from-white via-zinc-100 to-zinc-400 drop-shadow-[0_2px_15px_rgba(255,255,255,0.15)] select-none">
                  {user?.role === "admin" ? "System Admin" : (user?.role || "Admin")}
                </p>
              </div>
            </div>

            {!isExpanded && (
              <div className="shrink-0 mb-4 cursor-pointer hover:scale-110 transition-transform duration-500 drop-shadow-[0_4px_20px_rgba(99,102,241,0.8)] xl:animate-[pulse_4s_ease-in-out_infinite]">
                <ForgeLogo iconOnly size={44} />
              </div>
            )}

            <div className="flex items-center gap-2">
              <motion.button
                whileHover={{ scale: 1.05 }}
                whileTap={{ scale: 0.95 }}
                onClick={toggleTheme}
                className="flex h-10 w-10 rounded-xl border border-white/10 bg-white/5 items-center justify-center hover:bg-white/10 hover:border-white/20 transition-all shadow-lg shrink-0 text-zinc-400 hover:text-white group relative overflow-hidden backdrop-blur-md"
                title={`Switch to ${theme === "dark" ? "Light" : theme === "light" ? "Neon" : "Dark"} Mode`}
              >
                <div className="absolute inset-0 bg-gradient-to-br from-transparent via-white/5 to-transparent opacity-0 group-hover:opacity-100 transition-opacity" />
                <AnimatePresence mode="wait">
                  <motion.div
                    key={theme}
                    initial={{ opacity: 0, rotate: -90, scale: 0.5 }}
                    animate={{ opacity: 1, rotate: 0, scale: 1 }}
                    exit={{ opacity: 0, rotate: 90, scale: 0.5 }}
                    transition={{ duration: 0.2, ease: "backOut" }}
                  >
                    {theme === "dark" ? (
                      <Moon size={18} weight="duotone" className="text-blue-400 group-hover:scale-110 group-hover:rotate-45 transition-transform duration-500" />
                    ) : theme === "light" ? (
                      <Sun size={18} weight="duotone" className="text-amber-400 group-hover:scale-110 group-hover:rotate-45 transition-transform duration-500" />
                    ) : (
                      <Sparkle size={18} weight="duotone" className="text-fuchsia-400 animate-pulse" />
                    )}
                  </motion.div>
                </AnimatePresence>
              </motion.button>
            </div>
          </div>

          <style>{`
            .hide-scroll-drawer::-webkit-scrollbar {
              width: 5px;
            }
            .hide-scroll-drawer::-webkit-scrollbar-track {
              background: transparent;
            }
            .hide-scroll-drawer::-webkit-scrollbar-thumb {
              background: rgba(255, 255, 255, 0.1);
              border-radius: 10px;
            }
            .hide-scroll-drawer::-webkit-scrollbar-thumb:hover {
              background: rgba(255, 255, 255, 0.25);
            }
          `}</style>

          <div className="mt-8 flex-1 overflow-y-auto overflow-x-hidden hide-scroll-drawer -mx-2 px-2 pb-4">
            <LayoutGroup>
              <div className="space-y-[4px]">
                {NAV_ITEMS.map((item) => (
                  <NavItem
                    key={item.href}
                    item={item}
                    pathname={pathname}
                    isExpanded={isExpanded}
                    onClick={() => setIsMobileOpen(false)}
                  />
                ))}
              </div>

              {/* Quick Links Group */}
              <div className="mt-6 mb-2 flex items-center gap-4">
                <div className="h-px bg-white/5 flex-1" />
                <span className={cx(
                  "text-[10px] font-bold text-zinc-500 uppercase tracking-widest transition-opacity duration-300 whitespace-nowrap",
                  isExpanded ? "opacity-100" : "opacity-0 invisible w-0"
                )}>Quick Links</span>
                <div className="h-px bg-white/5 flex-1" />
              </div>

              <div className="space-y-[4px]">
                {QUICK_LINKS.map((item) => (
                  <NavItem
                    key={item.href}
                    item={item}
                    pathname={pathname}
                    isExpanded={isExpanded}
                    onClick={() => setIsMobileOpen(false)}
                  />
                ))}
              </div>
            </LayoutGroup>
          </div>

          <button
            onClick={() => {
              clearToken();
              router.replace("/login");
            }}
            className={cx(
              "group mt-4 relative flex items-center justify-center rounded-2xl p-3 text-sm transition-all duration-300 w-full overflow-hidden shrink-0",
              "border border-white/5 bg-white/[0.02] hover:bg-red-500/10 hover:border-red-500/20 hover:text-red-400 text-zinc-400 hover:shadow-[0_0_20px_rgba(239,68,68,0.15)]",
              isExpanded ? "px-3" : "px-0"
            )}
            title={!isExpanded ? "Sign out" : undefined}
          >
            <div className="relative z-10 flex items-center gap-3">
              <SignOut size={18} weight="duotone" className="transition-transform group-hover:scale-110 duration-300" />
              <div className={cx(
                "overflow-hidden transition-all duration-500 ease-[cubic-bezier(0.2,1,0.4,1)] whitespace-nowrap",
                isExpanded ? "w-full opacity-100 translate-x-0" : "w-0 opacity-0 -translate-x-4 hidden"
              )}>
                <span className="font-semibold tracking-wide">Sign out</span>
              </div>
            </div>
          </button>
        </motion.aside>


        <main className="gf-panel rounded-[2rem] flex-1 flex flex-col min-w-0 bg-[var(--gf-shell-bg)] backdrop-blur-3xl border border-[var(--gf-border)] shadow-[var(--gf-shell-shadow)] relative z-10 transition-[margin,background-color,border-color,box-shadow] duration-500">
          <header className="p-6 lg:p-8 border-b border-[var(--gf-border)] flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between shrink-0 bg-transparent">
            <div className="flex items-center gap-4">
              <button
                onClick={toggleSidebar}
                className="lg:flex hidden items-center justify-center h-10 w-10 rounded-xl border border-[var(--gf-border)] bg-[var(--gf-panel-bg)] text-[var(--gf-text-muted)] hover:text-[var(--foreground)] hover:bg-[var(--gf-panel-2)] transition-all shadow-sm group"
                title="Toggle Sidebar"
              >
                <List size={20} weight="bold" className={cx("transition-transform duration-500", !isSidebarHidden && "rotate-90 text-indigo-400")} />
              </button>
              <div>
                <p className="text-[11px] font-bold text-indigo-400/80 uppercase tracking-widest mb-1">{props.subtitle || "Control center"}</p>
                <h1 className="text-3xl lg:text-4xl font-extrabold tracking-tight bg-clip-text text-transparent bg-gradient-to-br from-[var(--foreground)] via-[var(--foreground)]/80 to-[var(--gf-text-muted)]">{props.title}</h1>
              </div>
            </div>
            <div className="flex flex-wrap items-center justify-start gap-3 sm:justify-end">
              <button
                onClick={() => setPaletteOpen(true)}
                className="gf-btn hidden h-9 items-center gap-2 rounded-xl px-3 text-sm sm:flex shadow-lg"
              >
                Search
                <span className="rounded-lg border border-[var(--gf-border)] bg-[var(--gf-panel-bg)] px-2 py-1 text-[11px] text-[var(--gf-text-muted)]">⌘K</span>
              </button>
              {props.right}
            </div>
          </header>

          <div className="p-6 lg:p-8 flex-1 min-h-0">
            {props.children}
          </div>
        </main>
      </div>

      <CommandPalette open={paletteOpen} onOpenChange={setPaletteOpen} />
    </div>
  );
}
