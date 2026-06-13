"use client";

import { useEffect, useState } from "react";
import Lenis from "lenis";
import { motion, useMotionValue, useSpring } from "framer-motion";
import { ThemeProvider } from "@/app/_components/ThemeProvider";
import SmoothScroll from "@/app/_components/SmoothScroll";
import CommandCenter from "@/app/_components/CommandCenter";
import AIDesignCoach from "@/app/_components/AIDesignCoach";
import ForgeConsole from "@/app/_components/ForgeConsole";
import { ToastProvider } from "@/app/_components/ToastProvider";
import QueryProvider from "@/app/_components/QueryProvider";

export default function ClientLayout({ children }: { children: React.ReactNode }) {
  const cursorX = useMotionValue(-100);
  const cursorY = useMotionValue(-100);
  
  const springConfig = { damping: 30, stiffness: 200, mass: 0.5 };
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

  const [isClicking, setIsClicking] = useState(false);

  useEffect(() => {
    const handleMouseDown = () => setIsClicking(true);
    const handleMouseUp = () => setIsClicking(false);
    window.addEventListener("mousedown", handleMouseDown);
    window.addEventListener("mouseup", handleMouseUp);
    return () => {
      window.removeEventListener("mousedown", handleMouseDown);
      window.removeEventListener("mouseup", handleMouseUp);
    };
  }, []);

  return (
    <>
      <motion.div
        className="fixed top-0 left-0 w-10 h-10 rounded-full border border-cyan-400/40 pointer-events-none z-[9999] hidden lg:flex items-center justify-center bg-cyan-500/5 backdrop-blur-[1px]"
        animate={{ scale: isClicking ? 0.8 : 1, opacity: isClicking ? 0.5 : 1 }}
        style={{
          x: cursorXSpring,
          y: cursorYSpring,
          translateX: "-50%",
          translateY: "-50%",
          boxShadow: isClicking ? "0 0 10px rgba(34,211,238,0.5)" : "0 0 20px rgba(34,211,238,0.2)"
        }}
      >
        <div className="w-full h-full rounded-full border border-cyan-300/20 animate-pulse" />
      </motion.div>
      <motion.div
        className="fixed top-0 left-0 w-2 h-2 bg-white rounded-full pointer-events-none z-[9999] hidden lg:block shadow-[0_0_15px_rgba(255,255,255,0.9)]"
        animate={{ scale: isClicking ? 1.5 : 1 }}
        style={{
          x: cursorX,
          y: cursorY,
          translateX: "-50%",
          translateY: "-50%",
        }}
      />
      <QueryProvider>
        <ThemeProvider>
          <SmoothScroll />
          <CommandCenter />
          <AIDesignCoach />
          <ForgeConsole />
          <ToastProvider>{children}</ToastProvider>
        </ThemeProvider>
      </QueryProvider>
    </>
  );
}
