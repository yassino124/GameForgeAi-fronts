"use client";

import { ReactNode, useEffect, useRef, useState } from "react";
import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { useAuthStore } from "@/lib/stores/authStore";
import { useTheme } from "./ThemeProvider";
import {
  Moon,
  Sun,
  House,
  Sparkle,
  Brain,
  PlusCircle,
  Folders,
  GameController,
  Users,
  Waveform,
  Radio,
  Storefront,
  Hammer,
  Bell,
  Wallet,
  Question,
  CreditCard,
  Gear,
  SignOut,
  List,
  X,
  Trophy,
  CaretRight,
  GlobeHemisphereWest,
  MusicNote,
  Planet,
  ImageSquare,
  Code,
} from "@phosphor-icons/react";
import {
  motion,
  AnimatePresence,
  LayoutGroup,
  useMotionValue,
  useSpring,
} from "framer-motion";
import NeuralFlux from "./NeuralFlux";
import ForgeLogo from "./ForgeLogo";

function CustomCursor() {
  const cursorX = useMotionValue(-100);
  const cursorY = useMotionValue(-100);

  // Very snappy and performant spring configuration
  const springConfig = { damping: 30, stiffness: 450, mass: 0.1 };
  const cursorXSpring = useSpring(cursorX, springConfig);
  const cursorYSpring = useSpring(cursorY, springConfig);

  const [isHovering, setIsHovering] = useState(false);
  const [isVisible, setIsVisible] = useState(false);

  useEffect(() => {
    // Only updates MotionValue directly (no React state re-renders = 0 lag)
    const moveCursor = (e: MouseEvent) => {
      cursorX.set(e.clientX);
      cursorY.set(e.clientY);
    };

    // Smart hover detection only when hovering over interactables
    const handleMouseOver = (e: MouseEvent) => {
      const target = e.target as HTMLElement;
      if (
        target.closest('button, a, input, [role="button"], .cursor-pointer')
      ) {
        setIsHovering(true);
      }
    };

    const handleMouseOut = (e: MouseEvent) => {
      const target = e.target as HTMLElement;
      if (
        target.closest('button, a, input, [role="button"], .cursor-pointer')
      ) {
        setIsHovering(false);
      }
    };

    const handleMouseEnter = () => setIsVisible(true);
    const handleMouseLeave = () => setIsVisible(false);

    window.addEventListener("mousemove", moveCursor, { passive: true });
    window.addEventListener("mouseover", handleMouseOver, { passive: true });
    window.addEventListener("mouseout", handleMouseOut, { passive: true });
    document.addEventListener("mouseenter", handleMouseEnter);
    document.addEventListener("mouseleave", handleMouseLeave);

    setIsVisible(true);

    return () => {
      window.removeEventListener("mousemove", moveCursor);
      window.removeEventListener("mouseover", handleMouseOver);
      window.removeEventListener("mouseout", handleMouseOut);
      document.removeEventListener("mouseenter", handleMouseEnter);
      document.removeEventListener("mouseleave", handleMouseLeave);
    };
  }, [cursorX, cursorY]);

  if (!isVisible) return null;

  return (
    <>
      <motion.div
        className="fixed top-0 left-0 w-3 h-3 bg-cyan-400 rounded-full pointer-events-none z-[99999] mix-blend-screen shadow-[0_0_20px_rgba(34,211,238,1)] hidden lg:block"
        style={{
          x: cursorXSpring,
          y: cursorYSpring,
          translateX: "-50%",
          translateY: "-50%",
        }}
        animate={{
          scale: isHovering ? 0 : 1,
        }}
        transition={{ type: "tween", ease: "backOut", duration: 0.15 }}
      />
      <motion.div
        className="fixed top-0 left-0 w-10 h-10 border-[1.5px] border-cyan-400/50 rounded-full pointer-events-none z-[99998] hidden lg:block"
        style={{
          x: cursorXSpring,
          y: cursorYSpring,
          translateX: "-50%",
          translateY: "-50%",
        }}
        animate={{
          scale: isHovering ? 1.4 : 1,
          borderColor: isHovering
            ? "rgba(34,211,238,0.8)"
            : "rgba(34,211,238,0.3)",
          backgroundColor: isHovering ? "rgba(34,211,238,0.15)" : "transparent",
        }}
        transition={{ type: "spring", stiffness: 250, damping: 25, mass: 0.5 }}
      />
    </>
  );
}
import { apiFetch } from "@/lib/api";

function cx(...parts: Array<string | false | null | undefined>) {
  return parts.filter(Boolean).join(" ");
}

const NAV_GROUPS = [
  {
    label: "Studio",
    items: [
      {
        href: "/studio",
        label: "Home",
        icon: House,
        color: "text-cyan-400",
        glowColor: "var(--gf-glow-primary)",
        bgHover: "group-hover:bg-[var(--gf-border)]",
        bgActive: "bg-[var(--gf-border-accent)] border-[var(--gf-border-accent)]",
        glowBase: "bg-cyan-500",
        match: (p: string) => p === "/studio",
      },
      {
        href: "/studio/ai/create",
        label: "AI Studio",
        icon: Sparkle,
        color: "text-cyan-400",
        glowColor: "var(--gf-glow-primary)",
        bgHover: "group-hover:bg-[var(--gf-border)]",
        bgActive: "bg-[var(--gf-border-accent)] border-[var(--gf-border-accent)]",
        glowBase: "bg-cyan-500",
        match: (p: string) => p?.startsWith("/studio/ai") && p !== "/studio/ai/coach" && p !== "/studio/ai/audio" && p !== "/studio/ai/assets",
      },
      {
        href: "/studio/ai/coach",
        label: "AI Coach",
        icon: Brain,
        color: "text-pink-400",
        glowColor: "rgba(244,114,182,0.8)",
        bgHover: "group-hover:bg-pink-500/10 group-hover:border-pink-500/20",
        bgActive: "bg-pink-500/20 border-pink-500/40",
        glowBase: "bg-pink-500",
        match: (p: string) => p === "/studio/ai/coach",
      },
      {
        href: "/studio/ai/audio",
        label: "SoundForge",
        badge: "NEW",
        icon: MusicNote,
        color: "text-purple-400",
        glowColor: "rgba(192,132,252,0.8)",
        bgHover: "group-hover:bg-purple-500/10 group-hover:border-purple-500/20",
        bgActive: "bg-purple-500/20 border-purple-500/40",
        glowBase: "bg-purple-500",
        match: (p: string) => p === "/studio/ai/audio",
      },
      {
        href: "/studio/ai/assets",
        label: "AssetForge",
        badge: "AI",
        icon: ImageSquare,
        color: "text-orange-400",
        glowColor: "rgba(251,146,60,0.8)",
        bgHover: "group-hover:bg-orange-500/10 group-hover:border-orange-500/20",
        bgActive: "bg-orange-500/20 border-orange-500/40",
        glowBase: "bg-orange-500",
        match: (p: string) => p === "/studio/ai/assets",
      },
      {
        href: "/studio/ai/game-gen",
        label: "GameGen AI",
        badge: "HOT",
        icon: Code,
        color: "text-emerald-400",
        glowColor: "rgba(52,211,153,0.8)",
        bgHover: "group-hover:bg-emerald-500/10 group-hover:border-emerald-500/20",
        bgActive: "bg-emerald-500/20 border-emerald-500/40",
        glowBase: "bg-emerald-500",
        match: (p: string) => p === "/studio/ai/game-gen",
      },
      {
        href: "/studio/worlds",
        label: "GF Worlds",
        badge: "NEW",
        icon: Planet,
        color: "text-indigo-400",
        glowColor: "rgba(129,140,248,0.8)",
        bgHover: "group-hover:bg-indigo-500/10 group-hover:border-indigo-500/20",
        bgActive: "bg-indigo-500/20 border-indigo-500/40",
        glowBase: "bg-indigo-500",
        match: (p: string) => p === "/studio/worlds",
      },
    ],
  },
  {
    label: "Projects",
    items: [
      {
        href: "/studio/projects/new",
        label: "New Project",
        icon: PlusCircle,
        color: "text-blue-400",
        glowColor: "var(--gf-glow-primary)",
        bgHover: "group-hover:bg-[var(--gf-border)]",
        bgActive:
          "bg-[var(--gf-border-accent)] border-[var(--gf-border-accent)]",
        glowBase: "bg-blue-500",
        match: (p: string) => p === "/studio/projects/new",
      },
      {
        href: "/studio/projects",
        label: "Projects",
        icon: Folders,
        color: "text-blue-400",
        glowColor: "var(--gf-glow-primary)",
        bgHover: "group-hover:bg-[var(--gf-border)]",
        bgActive:
          "bg-[var(--gf-border-accent)] border-[var(--gf-border-accent)]",
        glowBase: "bg-blue-500",
        match: (p: string) =>
          p?.startsWith("/studio/projects") && p !== "/studio/projects/new",
      },
      {
        href: "/studio/builds/progress",
        label: "Builds",
        icon: Hammer,
        color: "text-blue-400",
        glowColor: "var(--gf-glow-primary)",
        bgHover: "group-hover:bg-[var(--gf-border)]",
        bgActive:
          "bg-[var(--gf-border-accent)] border-[var(--gf-border-accent)]",
        glowBase: "bg-blue-500",
        match: (p: string) => p?.startsWith("/studio/builds"),
      },
    ],
  },
  {
    label: "Community",
    items: [
      {
        href: "/studio/arcade",
        label: "Arcade",
        icon: GameController,
        color: "text-sky-400",
        glowColor: "var(--gf-glow-primary)",
        bgHover: "group-hover:bg-[var(--gf-border)]",
        bgActive:
          "bg-[var(--gf-border-accent)] border-[var(--gf-border-accent)]",
        glowBase: "bg-sky-500",
        match: (p: string) => p === "/studio/arcade",
      },
      {
        href: "/studio/multiplayer",
        label: "Multiplayer",
        icon: Users,
        badge: "BETA",
        color: "text-blue-400",
        glowColor: "var(--gf-glow-primary)",
        bgHover: "group-hover:bg-[var(--gf-border)]",
        bgActive:
          "bg-[var(--gf-border-accent)] border-[var(--gf-border-accent)]",
        glowBase: "bg-blue-500",
        match: (p: string) => p?.startsWith("/studio/multiplayer"),
      },
      {
        href: "/studio/live-feed",
        label: "Live Feed",
        icon: Waveform,
        color: "text-rose-400",
        glowColor: "rgba(251,113,133,0.8)",
        bgHover: "group-hover:bg-rose-500/10 group-hover:border-rose-500/20",
        bgActive: "bg-rose-500/20 border-rose-500/40",
        glowBase: "bg-rose-500",
        match: (p: string) => p === "/studio/live-feed",
      },
      {
        href: "/studio/live-map",
        label: "Live Radar",
        badge: "HOT",
        icon: GlobeHemisphereWest,
        color: "text-green-400",
        glowColor: "rgba(74,222,128,0.8)",
        bgHover: "group-hover:bg-green-500/10 group-hover:border-green-500/20",
        bgActive: "bg-green-500/20 border-green-500/40",
        glowBase: "bg-green-500",
        match: (p: string) => p === "/studio/live-map",
      },
      {
        href: "/studio/live",
        label: "Live",
        icon: Radio,
        badge: "BETA",
        color: "text-red-400",
        glowColor: "rgba(248,113,113,0.8)",
        bgHover: "group-hover:bg-red-500/10 group-hover:border-red-500/20",
        bgActive: "bg-red-500/20 border-red-500/40",
        glowBase: "bg-red-500",
        match: (p: string) => p === "/studio/live",
      },
      {
        href: "/studio/marketplace",
        label: "Marketplace",
        icon: Storefront,
        color: "text-amber-400",
        glowColor: "rgba(251,191,36,0.8)",
        bgHover: "group-hover:bg-amber-500/10 group-hover:border-amber-500/20",
        bgActive: "bg-amber-500/20 border-amber-500/40",
        glowBase: "bg-amber-500",
        match: (p: string) => p?.startsWith("/studio/marketplace"),
      },
      {
        href: "/studio/tournaments",
        label: "Tournaments",
        icon: Trophy,
        color: "text-yellow-300",
        glowColor: "rgba(253,224,71,0.8)",
        bgHover:
          "group-hover:bg-yellow-500/10 group-hover:border-yellow-500/20",
        bgActive: "bg-yellow-500/20 border-yellow-500/40",
        glowBase: "bg-yellow-500",
        match: (p: string) => p?.startsWith("/studio/tournaments"),
      },
    ],
  },
  {
    label: "Account",
    items: [
      {
        href: "/studio/wallet",
        label: "Wallet",
        icon: Wallet,
        color: "text-blue-400",
        glowColor: "var(--gf-glow-primary)",
        bgHover: "group-hover:bg-[var(--gf-border)]",
        bgActive:
          "bg-[var(--gf-border-accent)] border-[var(--gf-border-accent)]",
        glowBase: "bg-blue-500",
        match: (p: string) => p === "/studio/wallet",
      },
      {
        href: "/studio/quiz",
        label: "Game Quiz",
        icon: Question,
        color: "text-blue-400",
        glowColor: "var(--gf-glow-primary)",
        bgHover: "group-hover:bg-[var(--gf-border)]",
        bgActive:
          "bg-[var(--gf-border-accent)] border-[var(--gf-border-accent)]",
        glowBase: "bg-blue-500",
        match: (p: string) => p === "/studio/quiz",
      },
      {
        href: "/studio/subscription",
        label: "Subscription",
        icon: CreditCard,
        color: "text-blue-400",
        glowColor: "var(--gf-glow-primary)",
        bgHover: "group-hover:bg-[var(--gf-border)]",
        bgActive:
          "bg-[var(--gf-border-accent)] border-[var(--gf-border-accent)]",
        glowBase: "bg-blue-500",
        match: (p: string) => p === "/studio/subscription",
      },
      {
        href: "/studio/notifications",
        label: "Notifications",
        icon: Bell,
        color: "text-blue-400",
        glowColor: "var(--gf-glow-primary)",
        bgHover: "group-hover:bg-[var(--gf-border)]",
        bgActive:
          "bg-[var(--gf-border-accent)] border-[var(--gf-border-accent)]",
        glowBase: "bg-blue-500",
        match: (p: string) => p === "/studio/notifications",
      },
      {
        href: "/studio/settings",
        label: "Settings",
        icon: Gear,
        color: "text-blue-400",
        glowColor: "var(--gf-glow-primary)",
        bgHover: "group-hover:bg-[var(--gf-border)]",
        bgActive:
          "bg-[var(--gf-border-accent)] border-[var(--gf-border-accent)]",
        glowBase: "bg-blue-500",
        match: (p: string) => p?.startsWith("/studio/settings"),
      },
    ],
  },
];

function NavItem({ item, pathname, isExpanded, onClick }: any) {
  const active = item.match(pathname);
  const Icon = item.icon;

  return (
    <Link
      href={item.href}
      onClick={onClick}
      className={cx(
        "relative group flex items-center rounded-[14px] p-2.5 text-sm transition-all duration-300",
        active
          ? "text-[var(--foreground)]"
          : "text-[var(--gf-text-muted)] hover:text-[var(--foreground)]",
        isExpanded ? "justify-start px-3" : "justify-center",
      )}
      title={!isExpanded ? item.label : undefined}
    >
      {/* Active animated background */}
      {active && (
        <motion.div
          layoutId="activeNavBackground"
          className="absolute inset-0 rounded-[14px] bg-gradient-to-r from-blue-500/10 via-[var(--gf-panel-bg)] to-transparent border border-blue-500/20 shadow-[inset_0_0_15px_var(--gf-glow-primary)]"
          initial={false}
          transition={{ type: "spring", stiffness: 380, damping: 32 }}
        />
      )}

      {/* Active left indicator pill */}
      {active && (
        <motion.div
          layoutId="activeLeftIndicator"
          className="absolute left-[2px] top-1/2 -translate-y-1/2 w-[4px] h-[20px] rounded-r-full bg-blue-500 shadow-[0_0_15px_rgba(37,99,235,0.8)]"
          initial={false}
          transition={{ type: "spring", stiffness: 380, damping: 32 }}
        />
      )}

      {/* Hover glow for inactive */}
      {!active && (
        <div className="absolute inset-0 rounded-[14px] bg-[var(--gf-panel-bg)] border border-transparent opacity-0 group-hover:opacity-100 group-hover:border-[var(--gf-border)] transition-all duration-250" />
      )}

      {/* Icon container */}
      <div
        className={cx(
          "relative z-10 flex items-center justify-center shrink-0 w-[34px] h-[34px] rounded-[10px] transition-all duration-400 ease-out",
          active
            ? `${item.bgActive} shadow-[inset_0_1px_3px_rgba(255,255,255,0.08)]`
            : `bg-white/[0.02] border border-white/[0.05] ${item.bgHover}`,
          !active && "group-hover:-translate-y-[1px] group-hover:scale-105",
        )}
      >
        {active && (
          <motion.div
            layoutId="activeIconGlow"
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
              : `text-zinc-500 group-hover:${item.color}`,
          )}
        />
      </div>

      {/* Label + badge */}
      <div
        className={cx(
          "flex items-center justify-between overflow-hidden transition-all duration-400 ease-[cubic-bezier(0.2,1,0.4,1)] whitespace-nowrap",
          isExpanded
            ? "w-full opacity-100 ml-2.5 translate-x-0"
            : "w-0 opacity-0 ml-0 -translate-x-3",
          "pointer-events-none",
        )}
      >
        <span
          className={cx(
            "font-semibold text-[13px] transition-colors duration-300 pointer-events-auto tracking-[-0.01em]",
            active
              ? "text-[var(--foreground)]"
              : "text-[var(--gf-text-muted)] group-hover:text-[var(--foreground)]",
          )}
        >
          {item.label}
        </span>
        {item.badge && (
          <span className="shrink-0 ml-2 rounded-[4px] border border-blue-500/25 bg-blue-600/8 px-1.5 py-[1px] text-[8px] font-black text-blue-400 tracking-[0.18em] uppercase">
            {item.badge}
          </span>
        )}
      </div>
    </Link>
  );
}

function NavGroup({
  group,
  pathname,
  isExpanded,
  onClick,
}: {
  group: (typeof NAV_GROUPS)[number];
  pathname: string;
  isExpanded: boolean;
  onClick: () => void;
}) {
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

export default function UserShell(props: {
  title?: string;
  subtitle?: string;
  right?: ReactNode;
  children: ReactNode;
  hideHeader?: boolean;
}) {
  const router = useRouter();
  const pathname = usePathname();
  const token = useAuthStore((s) => s.token);
  const hydrated = useAuthStore((s) => s.hydrated);
  const hydrateToken = useAuthStore((s) => s.hydrateToken);
  const clearToken = useAuthStore((s) => s.clearToken);
  const { theme, toggleTheme } = useTheme();
  const [mounted, setMounted] = useState(false);
  const [isMobileOpen, setIsMobileOpen] = useState(false);
  const [isSidebarHidden, setIsSidebarHidden] = useState<boolean>(false);
  const [isSidebarPinned, setIsSidebarPinned] = useState(true);
  const [user, setUser] = useState<any>(null);

  // Load user profile for avatar/name display
  useEffect(() => {
    if (!token) return;
    apiFetch<any>("/auth/profile", { method: "GET", token })
      .then((res) => {
        const d =
          res && typeof res === "object" && "data" in res
            ? (res as any).data
            : res;
        setUser(d?.user || d);
      })
      .catch(() => {});
  }, [token]);

  useEffect(() => {
    const saved = localStorage.getItem("gf_studio_sidebar_hidden");
    if (saved !== null) setIsSidebarHidden(saved === "true");
  }, []);

  const toggleSidebar = () => {
    const next = !isSidebarHidden;
    setIsSidebarHidden(next);
    localStorage.setItem("gf_studio_sidebar_hidden", String(next));
  };

  const isExpanded = isMobileOpen || isSidebarPinned;

  useEffect(() => {
    setMounted(true);
  }, []);
  useEffect(() => {
    hydrateToken();
  }, [hydrateToken]);
  useEffect(() => {
    if (!mounted || !hydrated) return;
    if (!token) router.replace("/signin");
  }, [hydrated, mounted, router, token]);

  if (!mounted || !hydrated) return null;

  const userInitial = (user?.username || user?.email || "U")
    .charAt(0)
    .toUpperCase();
  const userLabel = user?.username || user?.email || "Creator";
  const planLabel = user?.subscription || "Free";
  const isPro = !["free", "", "standard free"].includes(
    String(planLabel).toLowerCase(),
  );

  return (
    <div className="gf-app min-h-screen w-full flex flex-col font-sans transition-colors duration-500 cursor-none">
      <CustomCursor />
      <NeuralFlux />

      {/* Background layers */}
      <div className="pointer-events-none fixed inset-0 z-0">
        <div className="gf-grid absolute inset-0 opacity-[0.22]" />
        <div className="gf-noise absolute inset-0 opacity-[0.20]" />
        <div className="absolute top-0 left-1/4 w-1/2 h-[320px] bg-blue-600/8 blur-[160px] rounded-full" />
        <div className="absolute top-[25%] right-[8%] w-[28%] h-[260px] bg-sky-500/5 blur-[130px] rounded-full" />
        <div className="absolute bottom-[10%] left-[5%] w-[30%] h-[200px] bg-cyan-500/4 blur-[120px] rounded-full" />
      </div>

      {/* ── Mobile Header ── */}
      <div className="lg:hidden relative z-30 flex items-center justify-between px-4 py-3 border-b border-white/[0.06] bg-black/55 backdrop-blur-2xl">
        <div className="flex items-center gap-3">
          <button
            onClick={() => setIsMobileOpen(true)}
            className="p-2 -ml-2 text-zinc-400 hover:text-white transition-colors"
          >
            <List size={22} weight="bold" />
          </button>
          <ForgeLogo
            iconOnly
            size={28}
            className="drop-shadow-[0_0_10px_rgba(37,99,235,0.5)]"
          />
          <span className="font-black text-sm bg-clip-text text-transparent bg-gradient-to-r from-white to-zinc-400 tracking-tight">
            GameForge Studio
          </span>
        </div>
        <button
          className="h-8 w-8 rounded-xl border border-white/10 bg-white/5 flex items-center justify-center"
          onClick={toggleTheme}
        >
          {theme === "dark" ? (
            <Sun weight="duotone" size={14} className="text-amber-400" />
          ) : theme === "light" ? (
            <Moon weight="duotone" size={14} className="text-blue-400" />
          ) : (
            <Sparkle weight="duotone" size={14} className="text-cyan-400" />
          )}
        </button>
      </div>

      <div
        className={cx(
          "relative z-10 mx-auto w-full max-w-[1680px] flex-1 flex p-3 sm:p-4 min-h-0 gap-4",
          isSidebarHidden ? "gap-0" : "gap-4",
        )}
      >
        {/* ── Mobile overlay ── */}
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
            width: isSidebarHidden ? 0 : isExpanded ? 256 : 68,
            opacity: isSidebarHidden ? 0 : 1,
            x: isMobileOpen
              ? 0
              : typeof window !== "undefined" && window.innerWidth < 1024
                ? -100
                : isSidebarHidden
                  ? -40
                  : 0,
          }}
          transition={{ type: "spring", stiffness: 280, damping: 30 }}
          className={cx(
            "fixed lg:sticky lg:top-4 z-50 flex flex-col h-[100dvh] lg:h-[calc(100vh-32px)] overflow-hidden shrink-0 self-start",
            "border-r border-[var(--gf-border-accent)] lg:border lg:rounded-[32px]",
            "bg-[var(--gf-shell-bg)]/95 lg:bg-[var(--gf-shell-bg)]/80 backdrop-blur-[60px]",
            isExpanded
              ? "lg:shadow-[0_20px_60px_-8px_var(--gf-glow-primary),inset_0_1px_0_var(--gf-border)]"
              : "lg:shadow-[0_4px_30px_rgba(0,0,0,0.1),inset_0_1px_0_var(--gf-border)]",
            isMobileOpen
              ? "translate-x-0 w-[256px]"
              : "max-lg:-translate-x-full",
            isExpanded ? "p-3" : "p-2.5 pb-3 items-center",
          )}
          style={{ willChange: "width, transform" }}
        >
          {/* Ambient glow in sidebar */}
          <div className="absolute inset-x-0 bottom-0 h-1/3 bg-gradient-to-t from-[var(--gf-glow-primary)] to-transparent pointer-events-none mix-blend-overlay opacity-50" />
          {/* Mobile close */}
          <button
            onClick={() => setIsMobileOpen(false)}
            className="lg:hidden absolute top-3.5 right-3.5 text-[var(--gf-text-muted)] hover:text-[var(--foreground)] transition-colors z-20 p-1 rounded-lg hover:bg-[var(--gf-border)]"
          >
            <X size={18} weight="bold" />
          </button>

          {/* ── Logo / Brand area ── */}
          <div
            className={cx(
              "flex items-center shrink-0 pt-1",
              isExpanded ? "gap-2.5 px-1" : "justify-center",
            )}
          >
            <div className="shrink-0">
              <ForgeLogo
                iconOnly
                size={isExpanded ? 36 : 40}
                className="hover:scale-105 transition-transform duration-300 shadow-[0_0_14px_var(--gf-glow-primary)] rounded-full"
              />
            </div>

            <div
              className={cx(
                "flex-1 overflow-hidden transition-all duration-400 ease-[cubic-bezier(0.2,1,0.4,1)]",
                isExpanded
                  ? "opacity-100 translate-x-0"
                  : "w-0 opacity-0 -translate-x-2",
              )}
            >
              <p className="text-[9px] uppercase tracking-[0.28em] text-cyan-500 font-black opacity-85 whitespace-nowrap">
                GameForge
              </p>
              <p className="text-[18px] font-black tracking-[-0.04em] text-[var(--foreground)] whitespace-nowrap leading-tight">
                Studio
              </p>
            </div>

            {/* Theme toggle */}
            <motion.button
              whileHover={{ scale: 1.08 }}
              whileTap={{ scale: 0.92 }}
              onClick={toggleTheme}
              className={cx(
                "shrink-0 flex h-8 w-8 rounded-xl border border-white/8 bg-white/4 items-center justify-center hover:bg-white/8 transition-all",
                !isExpanded && "hidden",
              )}
              title={`Switch theme`}
            >
              <AnimatePresence mode="wait">
                <motion.div
                  key={theme}
                  initial={{ opacity: 0, rotate: -90, scale: 0.5 }}
                  animate={{ opacity: 1, rotate: 0, scale: 1 }}
                  exit={{ opacity: 0, rotate: 90, scale: 0.5 }}
                  transition={{ duration: 0.18, ease: "backOut" }}
                >
                  {theme === "dark" ? (
                    <Moon
                      size={15}
                      weight="duotone"
                      className="text-blue-400"
                    />
                  ) : theme === "light" ? (
                    <Sun
                      size={15}
                      weight="duotone"
                      className="text-amber-400"
                    />
                  ) : (
                    <Sparkle
                      size={15}
                      weight="duotone"
                      className="text-cyan-400"
                    />
                  )}
                </motion.div>
              </AnimatePresence>
            </motion.button>
          </div>

          {/* Divider */}
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
            </LayoutGroup>
          </div>

          {/* ── User section ── */}
          <div className="shrink-0 mt-2">
            <div className="h-px bg-white/[0.05] mx-1 mb-2" />

            {/* Avatar + info row */}
            <div
              className={cx(
                "flex items-center rounded-[14px] p-2 transition-all duration-300",
                isExpanded
                  ? "gap-2.5 bg-white/[0.02] border border-white/[0.04] hover:bg-white/[0.04]"
                  : "justify-center",
              )}
            >
              {/* Avatar */}
              <div className="shrink-0 h-8 w-8 rounded-[10px] border border-white/10 overflow-hidden bg-gradient-to-br from-blue-500/30 to-sky-500/20 flex items-center justify-center">
                {user?.avatar ? (
                  <img
                    src={user.avatar}
                    alt=""
                    className="h-full w-full object-cover"
                  />
                ) : (
                  <span className="text-[12px] font-black text-sky-300">
                    {userInitial}
                  </span>
                )}
              </div>

              {/* Name / plan */}
              <div
                className={cx(
                  "flex-1 min-w-0 overflow-hidden transition-all duration-400 ease-[cubic-bezier(0.2,1,0.4,1)]",
                  isExpanded ? "opacity-100 translate-x-0" : "w-0 opacity-0",
                )}
              >
                <p className="text-[12px] font-bold text-white truncate leading-tight">
                  {userLabel}
                </p>
                <p
                  className={cx(
                    "text-[9px] font-black uppercase tracking-widest leading-tight mt-0.5",
                    isPro ? "text-blue-400" : "text-zinc-600",
                  )}
                >
                  {isPro ? planLabel : "Free plan"}
                </p>
              </div>

              {/* Sign out */}
              {isExpanded && (
                <button
                  onClick={() => {
                    clearToken();
                    router.replace("/signin");
                  }}
                  className="shrink-0 h-7 w-7 rounded-lg flex items-center justify-center text-zinc-600 hover:text-red-400 hover:bg-red-500/8 transition-all"
                  title="Sign out"
                >
                  <SignOut size={14} weight="duotone" />
                </button>
              )}
            </div>

            {!isExpanded && (
              <button
                onClick={() => {
                  clearToken();
                  router.replace("/signin");
                }}
                className="mt-1.5 w-full flex items-center justify-center p-2.5 rounded-[14px] text-zinc-600 hover:text-red-400 hover:bg-red-500/8 transition-all"
                title="Sign out"
              >
                <SignOut size={16} weight="duotone" />
              </button>
            )}
          </div>
        </motion.aside>

        {/* ── Main content ── */}
        <main
          className={cx(
            "gf-panel rounded-[32px] flex-1 flex flex-col min-w-0 relative z-10",
            "bg-[var(--gf-shell-bg)]/80 lg:backdrop-blur-[40px] border border-[var(--gf-border-accent)] lg:shadow-[0_20px_80px_var(--gf-glow-primary)]",
            "transition-all duration-500",
          )}
        >
          {!props.hideHeader && (
            <header className="px-6 py-5 lg:px-8 lg:py-6 border-b border-cyan-500/10 bg-white/[0.01] rounded-t-[32px] flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between shrink-0">
              <div className="flex items-center gap-4">
                {/* Toggle sidebar on desktop */}
                <button
                  onClick={toggleSidebar}
                  className="lg:flex hidden items-center justify-center h-10 w-10 rounded-[14px] border border-[var(--gf-border-accent)] bg-[var(--gf-panel-bg-strong)] backdrop-blur-md shadow-[0_0_15px_var(--gf-glow-primary)] text-cyan-500/70 hover:text-cyan-400 hover:bg-cyan-500/10 hover:border-[var(--gf-border-accent)] transition-all group shrink-0"
                  title="Toggle Sidebar"
                >
                  <motion.div
                    animate={{ rotate: isSidebarHidden ? 0 : 180 }}
                    transition={{ duration: 0.3 }}
                  >
                    <CaretRight
                      size={18}
                      weight="bold"
                      className="group-hover:drop-shadow-[0_0_10px_rgba(34,211,238,0.8)] transition-all"
                    />
                  </motion.div>
                </button>
                <div>
                  {props.subtitle && (
                    <p className="text-[10px] font-black text-blue-400/70 uppercase tracking-[0.3em] mb-1">
                      {props.subtitle}
                    </p>
                  )}
                  {props.title && (
                    <h1 className="text-2xl lg:text-3xl font-black tracking-tight bg-clip-text text-transparent bg-gradient-to-br from-[var(--foreground)] via-[var(--foreground)]/85 to-[var(--gf-text-muted)]">
                      {props.title}
                    </h1>
                  )}
                </div>
              </div>
              {props.right && (
                <div className="flex flex-wrap items-center gap-2.5 sm:justify-end">
                  {props.right}
                </div>
              )}
            </header>
          )}

          <div className="p-5 lg:p-8 flex-1 min-h-0">{props.children}</div>
        </main>
      </div>
    </div>
  );
}
