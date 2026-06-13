function resolveApiBaseUrl() {
  const raw = (process.env.NEXT_PUBLIC_API_BASE_URL || "").trim();

  // Only accept absolute URLs for safety. Relative values like "/api" would hit Next.js
  // routes (and cause 404s like Cannot GET /api/multiplayer/*).
  if (/^https?:\/\//i.test(raw)) return raw.replace(/\/$/, "");

  if (typeof window !== "undefined") {
    return `${window.location.origin}/api`;
  }
  return "http://localhost:3000/api";
}

export const API_BASE_URL = resolveApiBaseUrl();

type ApiOk<T> = { success: true; data?: T; message?: string };
type ApiErr = { success?: false; message?: string; error?: any };

export class ApiError extends Error {
  status?: number;
  constructor(message: string, status?: number) {
    super(message);
    this.name = "ApiError";
    this.status = status;
  }
}

function tryParseJsonLoose(raw: string): any | null {
  const txt = String(raw || "").trim();
  if (!txt) return null;
  try {
    return JSON.parse(txt);
  } catch {
    const firstObj = txt.indexOf("{");
    const lastObj = txt.lastIndexOf("}");
    if (firstObj >= 0 && lastObj > firstObj) {
      const slice = txt.slice(firstObj, lastObj + 1);
      try {
        return JSON.parse(slice);
      } catch {
        return null;
      }
    }

    const firstArr = txt.indexOf("[");
    const lastArr = txt.lastIndexOf("]");
    if (firstArr >= 0 && lastArr > firstArr) {
      const slice = txt.slice(firstArr, lastArr + 1);
      try {
        return JSON.parse(slice);
      } catch {
        return null;
      }
    }

    return null;
  }
}

export async function apiFetch<T>(
  path: string,
  opts?: {
    method?: "GET" | "POST" | "PUT" | "PATCH" | "DELETE";
    token?: string | null;
    body?: unknown;
    signal?: AbortSignal;
  },
): Promise<T> {
  const url = `${API_BASE_URL}${path.startsWith("/") ? path : `/${path}`}`;
  const res = await fetch(url, {
    method: opts?.method || (opts?.body ? "POST" : "GET"),
    headers: {
      "Content-Type": "application/json",
      ...(opts?.token ? { Authorization: `Bearer ${opts.token}` } : {}),
    },
    body: opts?.body != null ? JSON.stringify(opts.body) : undefined,
    signal: opts?.signal,
  });

  let json: ApiOk<T> | ApiErr | null = null;
  let rawText: string | null = null;
  try {
    rawText = await res.text();
    json = tryParseJsonLoose(rawText) as any;
  } catch {
    json = null;
    rawText = null;
  }

  if (!res.ok) {
    const msg =
      (json as any)?.message ||
      (typeof (json as any)?.error === "string" ? (json as any).error : null) ||
      (rawText && rawText.trim() ? rawText.slice(0, 280) : null) ||
      `Request failed (${res.status})`;
    throw new ApiError(msg, res.status);
  }

  if (!json && rawText && rawText.trim()) {
    throw new ApiError(`Invalid JSON response from server. Snippet: ${rawText.slice(0, 280)}`, res.status);
  }

  // Most endpoints return {success,data,message}
  if (json && typeof json === "object" && "success" in json) {
    const s = (json as any).success;
    if (s !== true) {
      throw new ApiError((json as any).message || "Request failed", res.status);
    }
    return ((json as any).data ?? json) as T;
  }

  return json as T;
}

export async function apiFetchForm<T>(
  path: string,
  opts: {
    method?: "POST" | "PUT" | "PATCH" | "DELETE";
    token?: string | null;
    form: FormData;
    signal?: AbortSignal;
  },
): Promise<T> {
  const url = `${API_BASE_URL}${path.startsWith("/") ? path : `/${path}`}`;
  const res = await fetch(url, {
    method: opts?.method || "POST",
    headers: {
      ...(opts?.token ? { Authorization: `Bearer ${opts.token}` } : {}),
    },
    body: opts.form,
    signal: opts?.signal,
  });

  let json: ApiOk<T> | ApiErr | null = null;
  let rawText: string | null = null;
  try {
    rawText = await res.text();
    json = tryParseJsonLoose(rawText) as any;
  } catch {
    json = null;
    rawText = null;
  }

  if (!res.ok) {
    const msg =
      (json as any)?.message ||
      (typeof (json as any)?.error === "string" ? (json as any).error : null) ||
      (rawText && rawText.trim() ? rawText.slice(0, 280) : null) ||
      `Request failed (${res.status})`;
    throw new ApiError(msg, res.status);
  }

  if (!json && rawText && rawText.trim()) {
    throw new ApiError(`Invalid JSON response from server. Snippet: ${rawText.slice(0, 280)}`, res.status);
  }

  if (json && typeof json === "object" && "success" in json) {
    const s = (json as any).success;
    if (s !== true) {
      throw new ApiError((json as any).message || "Request failed", res.status);
    }
    return ((json as any).data ?? json) as T;
  }

  return json as T;
}
