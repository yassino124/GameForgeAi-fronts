export const USER_TOKEN_KEY = "gf_user_access_token";

export function getUserToken(): string | null {
  if (typeof window === "undefined") return null;
  try {
    return window.localStorage.getItem(USER_TOKEN_KEY);
  } catch {
    return null;
  }
}

export function setUserToken(token: string) {
  if (typeof window === "undefined") return;
  try {
    window.localStorage.setItem(USER_TOKEN_KEY, token);
  } catch {
    // ignore
  }
}

export function clearUserToken() {
  if (typeof window === "undefined") return;
  try {
    window.localStorage.removeItem(USER_TOKEN_KEY);
  } catch {
    // ignore
  }
}
