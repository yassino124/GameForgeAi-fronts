"use client";

import { useEffect } from "react";
import Lenis from "lenis";
import { motion, useMotionValue, useSpring } from "framer-motion";
import { ThemeProvider } from "@/app/_components/ThemeProvider";
import SmoothScroll from "@/app/_components/SmoothScroll";
import CommandCenter from "@/app/_components/CommandCenter";
import AIDesignCoach from "@/app/_components/AIDesignCoach";
import ForgeConsole from "@/app/_components/ForgeConsole";
import { ToastProvider } from "@/app/_components/ToastProvider";

export default function ClientLayout({ children }: { children: React.ReactNode }) {
  const cursorX = useMotionValue(-100);
  const cursorY = useMotionValue(-100);
  
  const springConfig = { damping: 25, stiffness: 700 };
  const cursorXSpring = useSpring(cursorX, springConfig);
  const cursorYSpring = useSpring(cursorY, springConfig);

  useEffect(() => {
    const lenis = new Lenis({
      duration: 1.2,
      easing: (t: number) => Math.min(1, 1.001 - Math.pow(2, -10 * t)),
      orientation: 'vertical',
      gestureOrientation: 'vertical',
      smoothWheel: true,
      wheelMultiplier: 1,
      touchMultiplier: 2,
      infinite: false,
    });

    function raf(time: number) {
      lenis.raf(time);
      requestAnimationFrame(raf);
    }

    requestAnimationFrame(raf);

    const moveCursor = (e: MouseEvent) => {
      cursorX.set(e.clientX);
      cursorY.set(e.clientY);
      document.documentElement.style.setProperty("--mouse-x", `${e.clientX}px`);
      document.documentElement.style.setProperty("--mouse-y", `${e.clientY}px`);
    };

    window.addEventListener("mousemove", moveCursor);

    return () => {
      lenis.destroy();
      window.removeEventListener("mousemove", moveCursor);
    };
  }, [cursorX, cursorY]);

  return (
    <>
      <motion.div
        className="fixed top-0 left-0 w-8 h-8 rounded-full border border-indigo-500/50 pointer-events-none z-[9999] mix-blend-difference hidden lg:block"
        style={{
          x: cursorXSpring,
          y: cursorYSpring,
          translateX: "-50%",
          translateY: "-50%",
        }}
      />
      <motion.div
        className="fixed top-0 left-0 w-1.5 h-1.5 bg-white rounded-full pointer-events-none z-[9999] hidden lg:block"
        style={{
          x: cursorX,
          y: cursorY,
          translateX: "-50%",
          translateY: "-50%",
        }}
      />
      <ThemeProvider>
        <SmoothScroll />
        <CommandCenter />
        <AIDesignCoach />
        <ForgeConsole />
        <ToastProvider>{children}</ToastProvider>
      </ThemeProvider>
    </>
  );
}
