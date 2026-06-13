"use client";

import { useEffect } from "react";
import { create } from "zustand";

const USER_TOKEN_KEY = "gf_user_access_token";

function readTokenFromStorage(): string | null {
  if (typeof window === "undefined") return null;
  try {
    return window.localStorage.getItem(USER_TOKEN_KEY);
  } catch {
    return null;
  }
}

function writeTokenToStorage(token: string | null) {
  if (typeof window === "undefined") return;
  try {
    if (!token) {
      window.localStorage.removeItem(USER_TOKEN_KEY);
      return;
    }
    window.localStorage.setItem(USER_TOKEN_KEY, token);
  } catch {
    // ignore storage errors
  }
}

type AuthStore = {
  token: string | null;
  hydrated: boolean;
  hydrateToken: () => void;
  setToken: (token: string) => void;
  clearToken: () => void;
};

export const useAuthStore = create<AuthStore>((set) => ({
  token: null,
  hydrated: false,
  hydrateToken: () => {
    set({ token: readTokenFromStorage(), hydrated: true });
  },
  setToken: (token: string) => {
    writeTokenToStorage(token);
    set({ token, hydrated: true });
  },
  clearToken: () => {
    writeTokenToStorage(null);
    set({ token: null, hydrated: true });
  },
}));

export function readAuthToken() {
  const state = useAuthStore.getState();
  return state.token ?? readTokenFromStorage();
}

export function useAuthToken() {
  const token = useAuthStore((s) => s.token);
  const hydrated = useAuthStore((s) => s.hydrated);
  const hydrateToken = useAuthStore((s) => s.hydrateToken);

  useEffect(() => {
    if (!hydrated) hydrateToken();
  }, [hydrateToken, hydrated]);

  return { token, hydrated };
}
