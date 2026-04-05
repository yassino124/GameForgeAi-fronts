import { NextResponse } from "next/server";
import { AccessToken } from "livekit-server-sdk";

type Role = "creator" | "viewer";

export async function POST(req: Request) {
  try {
    const body = (await req.json().catch(() => null)) as any;
    const roomName = String(body?.roomName || "").trim();
    const identity = String(body?.identity || "").trim();
    const name = String(body?.name || "").trim();
    const role = (String(body?.role || "viewer").trim() as Role) || "viewer";

    if (!roomName || !identity) {
      return NextResponse.json(
        { success: false, message: "Missing roomName or identity" },
        { status: 400 },
      );
    }

    const apiKey = String(process.env.LIVEKIT_API_KEY || "").trim();
    const apiSecret = String(process.env.LIVEKIT_API_SECRET || "").trim();
    const livekitUrl = String(process.env.LIVEKIT_URL || "").trim();

    if (!apiKey || !apiSecret || !livekitUrl) {
      return NextResponse.json(
        {
          success: false,
          message:
            "Missing LiveKit env vars. Set LIVEKIT_URL, LIVEKIT_API_KEY, LIVEKIT_API_SECRET in gameforge-admin-web/.env.local and restart next dev.",
        },
        { status: 500 },
      );
    }

    const at = new AccessToken(apiKey, apiSecret, {
      identity,
      name: name || identity,
      ttl: 60 * 60,
    });

    at.addGrant({
      room: roomName,
      roomJoin: true,
      canSubscribe: true,
      canPublish: role === "creator",
      canPublishData: true,
    });

    const token = await at.toJwt();
    return NextResponse.json({ success: true, token, livekitUrl, roomName, identity, role });
  } catch (e: any) {
    return NextResponse.json(
      { success: false, message: "Token generation failed", error: String(e?.message || e) },
      { status: 500 },
    );
  }
}
