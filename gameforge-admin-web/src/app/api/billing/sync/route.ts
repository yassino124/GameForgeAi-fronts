import { NextResponse } from "next/server";

function getBackendBaseUrl() {
  const raw = (process.env.NEXT_PUBLIC_API_BASE_URL || "").trim();
  if (raw) return raw.replace(/\/$/, "");
  return "http://localhost:3001/api";
}

export async function POST(req: Request) {
  try {
    const auth = req.headers.get("authorization") || "";

    if (!auth.toLowerCase().startsWith("bearer ")) {
      return NextResponse.json({ success: false, message: "Missing Authorization Bearer token" }, { status: 401 });
    }

    const backendUrl = `${getBackendBaseUrl()}/billing/sync`;
    const res = await fetch(backendUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: auth,
      },
    });

    const json = (await res.json().catch(() => null)) as any;
    if (!res.ok) {
      return NextResponse.json(
        { success: false, message: json?.message || `Backend sync failed (${res.status})`, error: json },
        { status: res.status },
      );
    }

    return NextResponse.json({ success: true, data: json?.data ?? json });
  } catch (e: any) {
    return NextResponse.json({ success: false, message: e?.message || "Sync error" }, { status: 500 });
  }
}
