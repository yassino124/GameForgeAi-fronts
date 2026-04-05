import { API_BASE_URL } from "@/lib/api";

/**
 * Normalizes a raw media URL from the backend into a fully qualified URL.
 * Returns undefined if the URL is empty or invalid, which prevents React from 
 * throwing an "empty src attribute" warning/error.
 */
export function normalizeImageUrl(url?: string | null): string | undefined {
  const raw = (url ?? "").trim();
  if (!raw) return undefined;
  if (raw.startsWith("http://") || raw.startsWith("https://")) return raw;

  const origin = API_BASE_URL.replace(/\/?api\/?$/i, "");
  if (raw.startsWith("/")) return `${origin}${raw}`;
  return `${origin}/${raw}`;
}

export function resolveMediaUrl(url?: string | null): string | undefined {
  return normalizeImageUrl(url);
}
