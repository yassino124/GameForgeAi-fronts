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
  SignOut, List, X, Sparkle, GameController, CaretRight,
  ChartPieSlice
} from "@phosphor-icons/react";
import { motion, AnimatePresence, LayoutGroup } from "framer-motion";
import NeuralFlux from "./NeuralFlux";
import ForgeLogo from "./ForgeLogo";
import { useTheme } from "./ThemeProvider";

function cx(...parts: Array<string | false | null | undefined>) {
  return parts.filter(Boolean).join(" ");
}

const NAV_GROUPS = [
  {
    label: "Overview",
    items: [
      { href: "/dashboard", label: "Dashboard", icon: SquaresFour, color: "text-cyan-400", glowColor: "rgba(34,211,238,0.8)", bgHover: "group-hover:bg-cyan-500/10 group-hover:border-cyan-500/20", bgActive: "bg-cyan-500/20 border-cyan-500/40", glowBase: "bg-cyan-500", match: (p: string) => p === "/dashboard" },
      { href: "/builds", label: "Builds / Queue", icon: Hammer, color: "text-orange-400", glowColor: "rgba(251,146,60,0.8)", bgHover: "group-hover:bg-orange-500/10 group-hover:border-orange-500/20", bgActive: "bg-orange-500/20 border-orange-500/40", glowBase: "bg-orange-500", match: (p: string) => p === "/builds" },
      { href: "/projects", label: "Projects", icon: Folders, color: "text-teal-400", glowColor: "rgba(45,212,191,0.8)", bgHover: "group-hover:bg-teal-500/10 group-hover:border-teal-500/20", bgActive: "bg-teal-500/20 border-teal-500/40", glowBase: "bg-teal-500", match: (p: string) => p === "/projects" },
      { href: "/feed", label: "Game Feed", icon: GameController, color: "text-emerald-400", glowColor: "rgba(52,211,153,0.8)", bgHover: "group-hover:bg-emerald-500/10 group-hover:border-emerald-500/20", bgActive: "bg-emerald-500/20 border-emerald-500/40", glowBase: "bg-emerald-500", match: (p: string) => p?.startsWith("/feed") },
    ]
  },
  {
    label: "Platform",
    items: [
      { href: "/multiplayer", label: "Multiplayer", icon: Users, color: "text-blue-400", glowColor: "rgba(96,165,250,0.8)", bgHover: "group-hover:bg-blue-500/10 group-hover:border-blue-500/20", bgActive: "bg-blue-500/20 border-blue-500/40", glowBase: "bg-blue-500", match: (p: string) => p?.startsWith("/multiplayer") },
      { href: "/live", label: "Live Sessions", icon: Radio, color: "text-red-400", glowColor: "rgba(248,113,113,0.8)", bgHover: "group-hover:bg-red-500/10 group-hover:border-red-500/20", bgActive: "bg-red-500/20 border-red-500/40", glowBase: "bg-red-500", match: (p: string) => p?.startsWith("/live") },
      { href: "/users", label: "Users", icon: User, color: "text-cyan-400", glowColor: "rgba(232,121,249,0.8)", bgHover: "group-hover:bg-cyan-500/10 group-hover:border-cyan-500/20", bgActive: "bg-cyan-500/20 border-cyan-500/40", glowBase: "bg-cyan-500", match: (p: string) => p === "/users" },
      { href: "/templates", label: "Templates", icon: Package, color: "text-amber-400", glowColor: "rgba(251,191,36,0.8)", bgHover: "group-hover:bg-amber-500/10 group-hover:border-amber-500/20", bgActive: "bg-amber-500/20 border-amber-500/40", glowBase: "bg-amber-500", match: (p: string) => p === "/templates" },
    ]
  },
  {
    label: "Management",
    items: [
      { href: "/messages", label: "Support Inbox", icon: List, color: "text-sky-400", glowColor: "rgba(167,139,250,0.8)", bgHover: "group-hover:bg-sky-500/10 group-hover:border-sky-500/20", bgActive: "bg-sky-500/20 border-sky-500/40", glowBase: "bg-sky-500", match: (p: string) => p === "/messages" },
      { href: "/notifications", label: "Notifications", icon: Bell, color: "text-pink-400", glowColor: "rgba(244,114,182,0.8)", bgHover: "group-hover:bg-pink-500/10 group-hover:border-pink-500/20", bgActive: "bg-pink-500/20 border-pink-500/40", glowBase: "bg-pink-500", match: (p: string) => p === "/notifications" },
      { href: "/billing", label: "Billing", icon: CreditCard, color: "text-emerald-400", glowColor: "rgba(52,211,153,0.8)", bgHover: "group-hover:bg-emerald-500/10 group-hover:border-emerald-500/20", bgActive: "bg-emerald-500/20 border-emerald-500/40", glowBase: "bg-emerald-500", match: (p: string) => p === "/billing" },
      { href: "/studio/business-model", label: "Business Model", icon: ChartPieSlice, color: "text-violet-400", glowColor: "rgba(167,139,250,0.8)", bgHover: "group-hover:bg-violet-500/10 group-hover:border-violet-500/20", bgActive: "bg-violet-500/20 border-violet-500/40", glowBase: "bg-violet-500", match: (p: string) => p === "/studio/business-model" },
      { href: "/system", label: "System", icon: Gear, color: "text-slate-300", glowColor: "rgba(203,213,225,0.8)", bgHover: "group-hover:bg-slate-500/10 group-hover:border-slate-500/20", bgActive: "bg-slate-500/20 border-slate-500/40", glowBase: "bg-slate-500", match: (p: string) => p === "/system" },
    ]
  },
];

const QUICK_LINKS = [
  { href: "http://localhost:3000/api/docs", label: "API Docs", icon: TerminalWindow, color: "text-sky-400", glowColor: "rgba(167,139,250,0.8)", bgHover: "group-hover:bg-sky-500/10 group-hover:border-sky-500/20", bgActive: "bg-sky-500/20 border-sky-500/40", glowBase: "bg-sky-500", match: () => false, external: true },
  { href: "http://localhost:3000/api/health", label: "Health", icon: Heartbeat, color: "text-rose-400", glowColor: "rgba(251,113,133,0.8)", bgHover: "group-hover:bg-rose-500/10 group-hover:border-rose-500/20", bgActive: "bg-rose-500/20 border-rose-500/40", glowBase: "bg-rose-500", match: () => false, external: true },
];

function NavItem({ item, pathname, isExpanded, onClick }: any) {
  const active = item.match(pathname);
  const Icon = item.icon;

  const inner = (
    <>
      {active && (
        <motion.div
          layoutId="activeNavBackgroundAdmin"
          className="absolute inset-0 bg-gradient-to-r from-blue-500/12 via-sky-500/6 to-transparent border border-blue-500/20 rounded-[14px]"
          initial={false}
          transition={{ type: "spring", stiffness: 380, damping: 32 }}
        />
      )}
      {active && (
        <motion.div
          layoutId="activeLeftIndicatorAdmin"
          className="absolute left-[2px] top-1/2 -translate-y-1/2 w-[3px] h-[18px] rounded-r-full bg-blue-400 shadow-[0_0_10px_rgba(129,140,248,0.9)]"
          initial={false}
          transition={{ type: "spring", stiffness: 380, damping: 32 }}
        />
      )}
      {!active && (
        <div className="absolute inset-0 rounded-[14px] bg-white/[0.02] border border-transparent opacity-0 group-hover:opacity-100 group-hover:border-white/[0.05] transition-all duration-250" />
      )}

      <div className={cx(
        "relative z-10 flex items-center justify-center shrink-0 w-[34px] h-[34px] rounded-[10px] transition-all duration-400",
        active
          ? `${item.bgActive} shadow-[inset_0_1px_3px_rgba(255,255,255,0.08)]`
          : `bg-white/[0.02] border border-white/[0.05] ${item.bgHover}`,
        !active && "group-hover:-translate-y-[1px] group-hover:scale-105"
      )}>
        {active && (
          <motion.div
            layoutId="activeIconGlowAdmin"
            className={`absolute inset-0 ${item.glowBase}/25 blur-md rounded-[10px]`}
            transition={{ type: "spring", stiffness: 380, damping: 32 }}
          />
        )}
        <Icon
          size={17}
          weight="duotone"
          className={cx(
            "relative z-10 transition-all duration-400",
            active
              ? `${item.color} drop-shadow-[0_0_8px_${item.glowColor}]`
              : `text-zinc-500 group-hover:${item.color}`
          )}
        />
      </div>

      <div className={cx(
        "flex items-center justify-between overflow-hidden transition-all duration-400 ease-[cubic-bezier(0.2,1,0.4,1)] whitespace-nowrap",
        isExpanded ? "w-full opacity-100 ml-2.5 translate-x-0" : "w-0 opacity-0 ml-0 -translate-x-3",
        "pointer-events-none"
      )}>
        <span className={cx(
          "font-semibold text-[13px] transition-colors duration-300 pointer-events-auto tracking-[-0.01em]",
          active ? "text-white" : "text-zinc-400 group-hover:text-white"
        )}>
          {item.label}
        </span>
        {item.badge && (
          <span className="shrink-0 ml-2 rounded-[4px] border border-blue-500/25 bg-blue-500/8 px-1.5 py-[1px] text-[8px] font-black text-blue-400 tracking-[0.18em] uppercase">
            {item.badge}
          </span>
        )}
      </div>
    </>
  );

  const cls = cx(
    "relative group flex items-center rounded-[14px] p-2.5 text-sm transition-all duration-300",
    active ? "text-white" : "text-zinc-400 hover:text-white",
    isExpanded ? "justify-start px-3" : "justify-center"
  );

  if (item.external) {
    return (
      <a href={item.href} target="_blank" rel="noreferrer" onClick={onClick} className={cls} title={!isExpanded ? item.label : undefined}>
        {inner}
      </a>
    );
  }

  return (
    <Link href={item.href} onClick={onClick} className={cls} title={!isExpanded ? item.label : undefined}>
      {inner}
    </Link>
  );
}

function NavGroup({ group, pathname, isExpanded, onClick }: { group: typeof NAV_GROUPS[number]; pathname: string; isExpanded: boolean; onClick: () => void }) {
  return (
    <div className="space-y-[2px]">
      <AnimatePresence>
        {isExpanded && (
          <motion.div
            initial={{ opacity: 0, height: 0 }}
            animate={{ opacity: 1, height: "auto" }}
            exit={{ opacity: 0, height: 0 }}
            transition={{ duration: 0.2 }}
            className="px-3 pt-4 pb-1"
          >
            <span className="text-[9px] font-black uppercase tracking-[0.28em] text-zinc-600">
              {group.label}
            </span>
          </motion.div>
        )}
      </AnimatePresence>
      {!isExpanded && <div className="my-2 h-px w-full bg-white/[0.04]" />}
      {group.items.map((item) => (
        <NavItem
          key={item.href}
          item={item}
          pathname={pathname}
          isExpanded={isExpanded}
          onClick={onClick}
        />
      ))}
    </div>
  );
}

export default function AdminShell(props: { title: string; subtitle?: string; right?: ReactNode; children: ReactNode }) {
  const router = useRouter();
  const pathname = usePathname();
  const token = useMemo(() => getToken(), []);
  const { theme, toggleTheme } = useTheme();
  const [mounted, setMounted] = useState(false);
  const [isMobileOpen, setIsMobileOpen] = useState(false);
  const [isSidebarHidden, setIsSidebarHidden] = useState<boolean>(false);
  const [paletteOpen, setPaletteOpen] = useState(false);
  const [isSidebarPinned] = useState(true);
  const [user, setUser] = useState<any>(null);

  useEffect(() => {
    if (!token) return;
    apiFetch<any>("/auth/profile", { method: "GET", token })
      .then((res) => {
        const d = res && typeof res === "object" && "data" in res ? (res as any).data : res;
        setUser(d?.user || d);
      })
      .catch(() => {});
  }, [token]);

  useEffect(() => {
    const saved = localStorage.getItem("gf_admin_sidebar_hidden");
    if (saved !== null) setIsSidebarHidden(saved === "true");
  }, []);

  const toggleSidebar = () => {
    const next = !isSidebarHidden;
    setIsSidebarHidden(next);
    localStorage.setItem("gf_admin_sidebar_hidden", String(next));
  };

  const isExpanded = isMobileOpen || isSidebarPinned;

  useEffect(() => { setMounted(true); }, []);
  useEffect(() => {
    if (!mounted) return;
    if (!token) router.replace("/login");
  }, [mounted, router, token]);

  useEffect(() => {
    if (!mounted) return;
    const onKey = (e: KeyboardEvent) => {
      if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === "k") {
        e.preventDefault();
        setPaletteOpen(true);
      }
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [mounted]);

  if (!mounted) return null;

  const userInitial = (user?.username || user?.email || "A").charAt(0).toUpperCase();
  const userLabel = user?.username || user?.email || "Admin";

  return (
    <div className="gf-app min-h-screen w-full flex flex-col font-sans transition-colors duration-500">
      <NeuralFlux />

      {/* Background layers */}
      <div className="pointer-events-none fixed inset-0 z-0">
        <div className="gf-grid absolute inset-0 opacity-[0.22]" />
        <div className="gf-noise absolute inset-0 opacity-[0.20]" />
        <div className="absolute top-0 left-1/4 w-1/2 h-[320px] bg-blue-500/8 blur-[160px] rounded-full" />
        <div className="absolute top-[25%] right-[8%] w-[28%] h-[260px] bg-sky-500/5 blur-[130px] rounded-full" />
      </div>

      {/* ── Mobile Header ── */}
      <div className="lg:hidden relative z-30 flex items-center justify-between px-4 py-3 border-b border-white/[0.06] bg-black/55 backdrop-blur-2xl">
        <div className="flex items-center gap-3">
          <button onClick={() => setIsMobileOpen(true)} className="p-2 -ml-2 text-zinc-400 hover:text-white transition-colors">
            <List size={22} weight="bold" />
          </button>
          <ForgeLogo iconOnly size={28} className="drop-shadow-[0_0_10px_rgba(99,102,241,0.5)]" />
          <span className="font-black text-sm bg-clip-text text-transparent bg-gradient-to-r from-white to-zinc-400 tracking-tight">
            GameForge Admin
          </span>
        </div>
        <button className="h-8 w-8 rounded-xl border border-white/10 bg-white/5 flex items-center justify-center" onClick={toggleTheme}>
          {theme === "dark" ? <Sun size={14} weight="duotone" className="text-amber-400" /> : theme === "light" ? <Moon size={14} weight="duotone" className="text-blue-400" /> : <Sparkle size={14} weight="duotone" className="text-cyan-400" />}
        </button>
      </div>

      <div className={cx("relative z-10 mx-auto w-full max-w-[1680px] flex-1 flex p-3 sm:p-4 min-h-0", isSidebarHidden ? "gap-0" : "gap-4")}>

        {/* Mobile overlay */}
        <AnimatePresence>
          {isMobileOpen && (
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              onClick={() => setIsMobileOpen(false)}
              className="fixed inset-0 bg-black/75 backdrop-blur-sm z-40 lg:hidden"
            />
          )}
        </AnimatePresence>

        {/* ── Sidebar ── */}
        <motion.aside
          initial={false}
          animate={{
            width: isSidebarHidden ? 0 : (isExpanded ? 256 : 68),
            opacity: isSidebarHidden ? 0 : 1,
            x: isMobileOpen ? 0 : (typeof window !== "undefined" && window.innerWidth < 1024 ? -100 : (isSidebarHidden ? -40 : 0)),
          }}
          transition={{ type: "spring", stiffness: 280, damping: 30 }}
          className={cx(
            "fixed lg:sticky lg:top-4 z-50 flex flex-col h-[100dvh] lg:h-[calc(100vh-32px)] overflow-hidden shrink-0 self-start",
            "border-r border-white/[0.05] lg:border lg:rounded-[24px]",
            "bg-[#08080c]/96 lg:bg-gradient-to-b lg:from-[#111118]/80 lg:to-[#07070a]/90 lg:backdrop-blur-[70px]",
            isExpanded
              ? "lg:shadow-[0_0_60px_-8px_rgba(99,102,241,0.18),inset_0_1px_0_rgba(255,255,255,0.04)]"
              : "lg:shadow-[0_4px_24px_rgba(0,0,0,0.4),inset_0_1px_0_rgba(255,255,255,0.04)]",
            isMobileOpen ? "translate-x-0 w-[256px]" : "max-lg:-translate-x-full",
            isExpanded ? "p-3" : "p-2.5 pb-3 items-center"
          )}
          style={{ willChange: "width, transform" }}
        >
          {/* Mobile close */}
          <button
            onClick={() => setIsMobileOpen(false)}
            className="lg:hidden absolute top-3.5 right-3.5 text-zinc-500 hover:text-white transition-colors z-20 p-1 rounded-lg hover:bg-white/5"
          >
            <X size={18} weight="bold" />
          </button>

          {/* ── Logo area ── */}
          <div className={cx("flex items-center shrink-0 pt-1", isExpanded ? "gap-2.5 px-1" : "justify-center")}>
            <div className="shrink-0">
              <ForgeLogo
                iconOnly
                size={isExpanded ? 36 : 40}
                className="hover:scale-105 transition-transform duration-300 drop-shadow-[0_0_14px_rgba(99,102,241,0.55)]"
              />
            </div>
            <div className={cx(
              "flex-1 overflow-hidden transition-all duration-400 ease-[cubic-bezier(0.2,1,0.4,1)]",
              isExpanded ? "opacity-100 translate-x-0" : "w-0 opacity-0 -translate-x-2"
            )}>
              <p className="text-[9px] uppercase tracking-[0.28em] text-emerald-400 font-black opacity-85 whitespace-nowrap">
                Master Architect
              </p>
              <p className="text-[18px] font-black tracking-[-0.04em] text-white whitespace-nowrap leading-tight">
                {user?.role === "admin" ? "System Admin" : (user?.role || "Admin")}
              </p>
            </div>
            <motion.button
              whileHover={{ scale: 1.08 }}
              whileTap={{ scale: 0.92 }}
              onClick={toggleTheme}
              className={cx(
                "shrink-0 flex h-8 w-8 rounded-xl border border-white/8 bg-white/4 items-center justify-center hover:bg-white/8 transition-all",
                !isExpanded && "hidden"
              )}
            >
              <AnimatePresence mode="wait">
                <motion.div
                  key={theme}
                  initial={{ opacity: 0, rotate: -90, scale: 0.5 }}
                  animate={{ opacity: 1, rotate: 0, scale: 1 }}
                  exit={{ opacity: 0, rotate: 90, scale: 0.5 }}
                  transition={{ duration: 0.18, ease: "backOut" }}
                >
                  {theme === "dark" ? <Moon size={15} weight="duotone" className="text-blue-400" /> : theme === "light" ? <Sun size={15} weight="duotone" className="text-amber-400" /> : <Sparkle size={15} weight="duotone" className="text-cyan-400" />}
                </motion.div>
              </AnimatePresence>
            </motion.button>
          </div>

          <div className="mx-1 my-3 h-px bg-white/[0.05]" />

          {/* ── Nav ── */}
          <div className="flex-1 overflow-y-auto overflow-x-hidden hide-scroll-drawer -mx-1 px-1 pb-3 gf-scrollbar">
            <LayoutGroup>
              {NAV_GROUPS.map((group) => (
                <NavGroup
                  key={group.label}
                  group={group}
                  pathname={pathname}
                  isExpanded={isExpanded}
                  onClick={() => setIsMobileOpen(false)}
                />
              ))}

              {/* Quick Links */}
              <div className="space-y-[2px]">
                <AnimatePresence>
                  {isExpanded && (
                    <motion.div
                      initial={{ opacity: 0, height: 0 }}
                      animate={{ opacity: 1, height: "auto" }}
                      exit={{ opacity: 0, height: 0 }}
                      transition={{ duration: 0.2 }}
                      className="px-3 pt-4 pb-1"
                    >
                      <span className="text-[9px] font-black uppercase tracking-[0.28em] text-zinc-600">Quick Links</span>
                    </motion.div>
                  )}
                </AnimatePresence>
                {!isExpanded && <div className="my-2 h-px w-full bg-white/[0.04]" />}
                {QUICK_LINKS.map((item) => (
                  <NavItem key={item.href} item={item} pathname={pathname} isExpanded={isExpanded} onClick={() => setIsMobileOpen(false)} />
                ))}
              </div>
            </LayoutGroup>
          </div>

          {/* ── Admin user section ── */}
          <div className="shrink-0 mt-2">
            <div className="h-px bg-white/[0.05] mx-1 mb-2" />
            <div className={cx(
              "flex items-center rounded-[14px] p-2 transition-all duration-300",
              isExpanded ? "gap-2.5 bg-white/[0.02] border border-white/[0.04] hover:bg-white/[0.04]" : "justify-center"
            )}>
              <div className="shrink-0 h-8 w-8 rounded-[10px] border border-emerald-500/20 overflow-hidden bg-gradient-to-br from-emerald-500/20 to-blue-500/15 flex items-center justify-center">
                {user?.avatar ? (
                  <img src={user.avatar} alt="" className="h-full w-full object-cover" />
                ) : (
                  <span className="text-[12px] font-black text-emerald-400">{userInitial}</span>
                )}
              </div>
              <div className={cx(
                "flex-1 min-w-0 overflow-hidden transition-all duration-400 ease-[cubic-bezier(0.2,1,0.4,1)]",
                isExpanded ? "opacity-100 translate-x-0" : "w-0 opacity-0"
              )}>
                <p className="text-[12px] font-bold text-white truncate leading-tight">{userLabel}</p>
                <p className="text-[9px] font-black uppercase tracking-widest leading-tight mt-0.5 text-emerald-400">
                  {user?.role || "Admin"}
                </p>
              </div>
              {isExpanded && (
                <button
                  onClick={() => { clearToken(); router.replace("/login"); }}
                  className="shrink-0 h-7 w-7 rounded-lg flex items-center justify-center text-zinc-600 hover:text-red-400 hover:bg-red-500/8 transition-all"
                  title="Sign out"
                >
                  <SignOut size={14} weight="duotone" />
                </button>
              )}
            </div>
            {!isExpanded && (
              <button
                onClick={() => { clearToken(); router.replace("/login"); }}
                className="mt-1.5 w-full flex items-center justify-center p-2.5 rounded-[14px] text-zinc-600 hover:text-red-400 hover:bg-red-500/8 transition-all"
                title="Sign out"
              >
                <SignOut size={16} weight="duotone" />
              </button>
            )}
          </div>
        </motion.aside>

        {/* ── Main ── */}
        <main className="gf-panel rounded-[22px] flex-1 flex flex-col min-w-0 bg-[var(--gf-shell-bg)]/50 backdrop-blur-3xl border border-[var(--gf-border)] shadow-[var(--gf-shell-shadow)] relative z-10 transition-all duration-500">
          <header className="px-6 py-5 lg:px-8 lg:py-6 border-b border-[var(--gf-border)] flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between shrink-0">
            <div className="flex items-center gap-4">
              <button
                onClick={toggleSidebar}
                className="lg:flex hidden items-center justify-center h-9 w-9 rounded-xl border border-[var(--gf-border)] bg-[var(--gf-panel-bg)] text-[var(--gf-text-muted)] hover:text-[var(--foreground)] hover:border-[var(--gf-border-2)] transition-all group shrink-0"
                title="Toggle Sidebar"
              >
                <motion.div animate={{ rotate: isSidebarHidden ? 0 : 180 }} transition={{ duration: 0.3 }}>
                  <CaretRight size={16} weight="bold" className="group-hover:text-blue-400 transition-colors" />
                </motion.div>
              </button>
              <div>
                {props.subtitle && (
                  <p className="text-[10px] font-black text-blue-400/70 uppercase tracking-[0.3em] mb-1">
                    {props.subtitle}
                  </p>
                )}
                <h1 className="text-2xl lg:text-3xl font-black tracking-tight bg-clip-text text-transparent bg-gradient-to-br from-[var(--foreground)] via-[var(--foreground)]/85 to-[var(--gf-text-muted)]">
                  {props.title}
                </h1>
              </div>
            </div>
            <div className="flex flex-wrap items-center gap-2.5 sm:justify-end">
              <button
                onClick={() => setPaletteOpen(true)}
                className="gf-btn hidden h-9 items-center gap-2 rounded-xl px-3 text-sm sm:flex"
              >
                Search
                <span className="rounded-lg border border-[var(--gf-border)] bg-[var(--gf-panel-bg)] px-2 py-0.5 text-[10px] text-[var(--gf-text-muted)] font-mono">⌘K</span>
              </button>
              {props.right}
            </div>
          </header>
          <div className="p-5 lg:p-8 flex-1 min-h-0">
            {props.children}
          </div>
        </main>
      </div>

      <CommandPalette open={paletteOpen} onOpenChange={setPaletteOpen} />
    </div>
  );
}
