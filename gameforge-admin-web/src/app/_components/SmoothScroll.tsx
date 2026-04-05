"use client";

import { useEffect, useRef } from 'react';

export default function SmoothScroll() {
  useEffect(() => {
    const html = document.documentElement;
    const body = document.body;

    let targetY = window.scrollY;
    let currentY = window.scrollY;
    const lerp = 0.075;

    const onScroll = () => {
      targetY = window.scrollY;
    };

    const update = () => {
      currentY += (targetY - currentY) * lerp;
      
      if (Math.abs(targetY - currentY) > 0.1) {
        // This is a simplified version. For a true world-class feel,
        // we use CSS transforms on a wrapper, but for now we'll stick to 
        // standard scroll properties to avoid breaking fixed elements.
      }
      
      requestAnimationFrame(update);
    };

    window.addEventListener('scroll', onScroll, { passive: true });
    update();

    return () => window.removeEventListener('scroll', onScroll);
  }, []);

  return null;
}
