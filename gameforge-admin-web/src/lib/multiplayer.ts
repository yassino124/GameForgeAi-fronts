"use client";

import { useEffect, useState } from "react";
import { io, Socket } from "socket.io-client";
import { API_BASE_URL } from "@/lib/api";

function resolveSocketUrl() {
  const env = (process.env.NEXT_PUBLIC_SOCKET_URL || "").trim();
  if (env) return env;

  // Prefer deriving from backend API base url to avoid accidentally connecting
  // to the Next.js dev server port.
  try {
    if (typeof window !== "undefined") {
      const u = new URL(API_BASE_URL);
      return `${u.origin}/mp`;
    }
  } catch {
    // ignore
  }

  if (typeof window !== "undefined") return `http://${window.location.hostname}:3001/mp`;
  return "http://localhost:3001/mp";
}

export function useMultiplayerSocket(token: string | null) {
  const [socket, setSocket] = useState<Socket | null>(null);
  const [connected, setConnected] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!token) {
      setSocket(null);
      setConnected(false);
      setError(null);
      return;
    }

    const url = resolveSocketUrl();

    const s = io(url, {
      auth: { token },
      transports: ["websocket", "polling"],
      reconnection: true,
      reconnectionAttempts: 8,
      reconnectionDelay: 500,
    });

    s.on("connect", () => {
      setConnected(true);
      setError(null);
    });
    s.on("disconnect", () => setConnected(false));
    s.on("connect_error", (e: any) => {
      setConnected(false);
      setError(e?.message ? String(e.message) : "Socket connection failed");
    });

    setSocket(s);

    return () => {
      s.disconnect();
    };
  }, [token]);

  return { socket, connected, error };
}
