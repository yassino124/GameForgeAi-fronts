export const USER_TOKEN_KEY = "gf_user_access_token";

function getAuthStoreApi() {
  if (typeof window === "undefined") return null;
  try {
    // Lazy require to avoid module cycles at load-time.
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    const mod = require("@/lib/stores/authStore") as {
      useAuthStore?: {
        getState: () => {
          token: string | null;
          hydrated: boolean;
          hydrateToken: () => void;
          setToken: (token: string) => void;
          clearToken: () => void;
        };
      };
    };
    return mod?.useAuthStore?.getState ? mod.useAuthStore : null;
  } catch {
    return null;
  }
}

export function getUserToken(): string | null {
  if (typeof window === "undefined") return null;

  const storeApi = getAuthStoreApi();
  if (storeApi) {
    const st = storeApi.getState();
    if (!st.hydrated) st.hydrateToken();
    if (st.token) return st.token;
  }

  try {
    return window.localStorage.getItem(USER_TOKEN_KEY);
  } catch {
    return null;
  }
}

export function setUserToken(token: string) {
  if (typeof window === "undefined") return;

  const storeApi = getAuthStoreApi();
  if (storeApi) {
    storeApi.getState().setToken(token);
    return;
  }

  try {
    window.localStorage.setItem(USER_TOKEN_KEY, token);
  } catch {
    // ignore
  }
}

export function clearUserToken() {
  if (typeof window === "undefined") return;

  const storeApi = getAuthStoreApi();
  if (storeApi) {
    storeApi.getState().clearToken();
    return;
  }

  try {
    window.localStorage.removeItem(USER_TOKEN_KEY);
  } catch {
    // ignore
  }
}
