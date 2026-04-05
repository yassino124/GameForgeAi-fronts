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

    if (!auth.toLowerCase().startsWith("bearer ")) {
      return NextResponse.json({ success: false, message: "Missing Authorization Bearer token" }, { status: 401 });
    }

    const backendUrl = `${getBackendBaseUrl()}/billing/checkout`;
    const res = await fetch(backendUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: auth,
      },
      body: JSON.stringify({ priceId }),
    });

    const json = (await res.json().catch(() => null)) as any;
    if (!res.ok) {
      return NextResponse.json(
        { success: false, message: json?.message || `Backend checkout failed (${res.status})`, error: json },
        { status: res.status },
      );
    }

    // Backend typically returns {success:true,data:{url}}
    const url = json?.data?.url || json?.url;
    if (!url || typeof url !== "string") {
      return NextResponse.json(
        { success: false, message: "Backend did not return checkout url", error: json },
        { status: 502 },
      );
    }

    return NextResponse.json({ success: true, data: { url } });
  } catch (e: any) {
    return NextResponse.json({ success: false, message: e?.message || "Checkout error" }, { status: 500 });
  }
}
