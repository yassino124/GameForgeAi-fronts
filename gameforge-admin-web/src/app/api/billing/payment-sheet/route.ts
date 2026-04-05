import { NextResponse } from "next/server";

function getBackendBaseUrl() {
  const raw = (process.env.NEXT_PUBLIC_API_BASE_URL || "").trim();
  if (raw) return raw.replace(/\/$/, "");
  return "http://localhost:3001/api";
}

export async function POST(req: Request) {
  try {
    const auth = req.headers.get("authorization") || "";
    const body = (await req.json().catch(() => null)) as any;

    if (!auth.toLowerCase().startsWith("bearer ")) {
      return NextResponse.json({ success: false, message: "Missing Authorization Bearer token" }, { status: 401 });
    }

    const planId = String(body?.planId || "").trim().toLowerCase();
    const priceId =
      planId === "pro"
        ? String(process.env.STRIPE_PRICE_PRO || "")
        : planId === "enterprise" || planId === "studio"
          ? String(process.env.STRIPE_PRICE_ENTERPRISE || "")
          : "";

    if (!priceId) {
      return NextResponse.json(
        { success: false, message: "Missing or unsupported planId / Stripe priceId (check STRIPE_PRICE_PRO / STRIPE_PRICE_ENTERPRISE)" },
        { status: 400 },
      );
    }

    const backendUrl = `${getBackendBaseUrl()}/billing/setup-intent`;
    const res = await fetch(backendUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: auth,
      },
      body: JSON.stringify({}),
    });

    const json = (await res.json().catch(() => null)) as any;
    if (!res.ok) {
      return NextResponse.json(
        { success: false, message: json?.message || `Backend payment-sheet failed (${res.status})`, error: json },
        { status: res.status },
      );
    }

    return NextResponse.json({ success: true, data: json?.data ?? json });
  } catch (e: any) {
    return NextResponse.json({ success: false, message: e?.message || "Payment sheet error" }, { status: 500 });
  }
}
