function resolveBackendApiBaseUrl() {
  const raw = (process.env.BACKEND_API_BASE_URL || process.env.NEXT_PUBLIC_BACKEND_API_BASE_URL || "").trim();
  if (/^https?:\/\//i.test(raw)) return raw.replace(/\/$/, "");
  return "http://localhost:3000";
}

export type ProxyResult = {
  status: number;
  headers?: Record<string, string>;
  json?: any;
  text?: string;
};

export async function proxyJson(req: Request, targetPath: string): Promise<Response> {
  const base = resolveBackendApiBaseUrl();
  const path = targetPath.startsWith("/") ? targetPath : `/${targetPath}`;
  const url = `${base}${path}`;

  const auth = req.headers.get("authorization") || req.headers.get("Authorization") || "";
  const contentType = req.headers.get("content-type") || req.headers.get("Content-Type") || "";

  let body: any = undefined;
  if (req.method !== "GET" && req.method !== "HEAD") {
    if (contentType.includes("application/json")) {
      body = await req.json().catch(() => undefined);
    } else {
      body = await req.text().catch(() => undefined);
    }
  }

  const fetchOnce = (u: string) =>
    fetch(u, {
      method: req.method,
      headers: {
        ...(auth ? { Authorization: auth } : {}),
        ...(contentType ? { "Content-Type": contentType } : {}),
        Accept: "application/json",
      },
      body: body == null ? undefined : (typeof body === "string" ? body : JSON.stringify(body)),
      cache: "no-store",
    });

  let upstream = await fetchOnce(url);
  if (upstream.status === 404 && !path.startsWith("/api/")) {
    upstream = await fetchOnce(`${base}/api${path}`);
  }

  const resCt = upstream.headers.get("content-type") || "";
  let payload: any = null;
  try {
    payload = resCt.includes("application/json") ? await upstream.json() : await upstream.text();
  } catch {
    payload = null;
  }

  return new Response(
    payload == null ? null : (typeof payload === "string" ? payload : JSON.stringify(payload)),
    {
      status: upstream.status,
      headers: {
        "Content-Type": resCt.includes("application/json") ? "application/json" : "text/plain",
      },
    },
  );
}
