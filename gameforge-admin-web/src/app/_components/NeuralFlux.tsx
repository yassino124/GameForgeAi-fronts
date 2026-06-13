"use client";

import React, { useEffect, useRef } from "react";

const THEME_COLORS: Record<string, { particle: string; line: string; mouse: string }> = {
  dark:  { particle: "rgba(37,99,235,0.35)", line: "rgba(37,99,235,",  mouse: "rgba(34,211,238," },
  light: { particle: "rgba(37,99,235,0.18)", line: "rgba(37,99,235,",  mouse: "rgba(37,99,235," },
  neon:  { particle: "rgba(14,165,233,0.45)",  line: "rgba(34,211,238,",  mouse: "rgba(0,229,255,"  },
};

export default function NeuralFlux() {
  const canvasRef = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext("2d");
    if (!ctx) return;

    let width  = (canvas.width  = window.innerWidth);
    let height = (canvas.height = window.innerHeight);
    let animId = 0;

    const getTheme = () => document.documentElement.getAttribute("data-theme") || "dark";

    const PARTICLE_COUNT   = 55;
    const CONNECTION_DIST  = 145;
    const MOUSE_DIST       = 200;

    const mouse = { x: -2000, y: -2000 };

    interface Particle {
      x: number; y: number;
      vx: number; vy: number;
      size: number;
    }

    const particles: Particle[] = Array.from({ length: PARTICLE_COUNT }, () => ({
      x: Math.random() * width,
      y: Math.random() * height,
      vx: (Math.random() - 0.5) * 0.45,
      vy: (Math.random() - 0.5) * 0.45,
      size: Math.random() * 1.8 + 0.8,
    }));

    const animate = () => {
      ctx.clearRect(0, 0, width, height);

      const theme  = getTheme();
      const colors = THEME_COLORS[theme] || THEME_COLORS.dark;

      for (const p of particles) {
        p.x += p.vx;
        p.y += p.vy;
        if (p.x < 0 || p.x > width)  p.vx *= -1;
        if (p.y < 0 || p.y > height) p.vy *= -1;

        // Draw particle
        ctx.beginPath();
        ctx.arc(p.x, p.y, p.size, 0, Math.PI * 2);
        ctx.fillStyle = colors.particle;
        ctx.fill();
      }

      // Draw connections
      for (let i = 0; i < particles.length; i++) {
        const a = particles[i];
        for (let j = i + 1; j < particles.length; j++) {
          const b   = particles[j];
          const dx  = a.x - b.x;
          const dy  = a.y - b.y;
          const d   = Math.sqrt(dx * dx + dy * dy);
          if (d < CONNECTION_DIST) {
            const alpha = 0.12 * (1 - d / CONNECTION_DIST);
            ctx.beginPath();
            ctx.moveTo(a.x, a.y);
            ctx.lineTo(b.x, b.y);
            ctx.strokeStyle = `${colors.line}${alpha})`;
            ctx.lineWidth   = 1;
            ctx.stroke();
          }
        }

        // Mouse connections
        const mdx = a.x - mouse.x;
        const mdy = a.y - mouse.y;
        const md  = Math.sqrt(mdx * mdx + mdy * mdy);
        if (md < MOUSE_DIST) {
          const alpha = 0.25 * (1 - md / MOUSE_DIST);
          ctx.beginPath();
          ctx.moveTo(a.x, a.y);
          ctx.lineTo(mouse.x, mouse.y);
          ctx.strokeStyle = `${colors.mouse}${alpha})`;
          ctx.lineWidth   = 1.8;
          ctx.stroke();
        }
      }

      animId = requestAnimationFrame(animate);
    };

    animate();

    const onMouseMove = (e: MouseEvent) => { mouse.x = e.clientX; mouse.y = e.clientY; };
    const onResize    = () => {
      width  = canvas.width  = window.innerWidth;
      height = canvas.height = window.innerHeight;
    };

    window.addEventListener("mousemove", onMouseMove);
    window.addEventListener("resize",    onResize);

    return () => {
      cancelAnimationFrame(animId);
      window.removeEventListener("mousemove", onMouseMove);
      window.removeEventListener("resize",    onResize);
    };
  }, []);

  return (
    <canvas
      ref={canvasRef}
      className="fixed inset-0 pointer-events-none z-0 opacity-35"
      aria-hidden
    />
  );
}
