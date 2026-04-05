import { NextResponse } from "next/server";
import { listLiveSessions, upsertLiveSession, removeLiveSession } from "@/lib/liveSessions";

export async function GET() {
  return NextResponse.json({ success: true, data: listLiveSessions() });
}

export async function POST(req: Request) {
  const body = (await req.json().catch(() => null)) as any;

  const roomName = String(body?.roomName || "").trim();
  const creatorIdentity = String(body?.creatorIdentity || "").trim();
  const creatorName = String(body?.creatorName || "").trim();
  const creatorAvatarUrl = String(body?.creatorAvatarUrl || "").trim();
  const gameTitle = String(body?.gameTitle || "").trim();
  const thumbUrl = String(body?.thumbUrl || "").trim();
  const tags = Array.isArray(body?.tags) ? body.tags.map((t: any) => String(t)).slice(0, 12) : undefined;

  if (!roomName || !creatorIdentity || !creatorName) {
    return NextResponse.json({ success: false, message: "Missing roomName/creatorIdentity/creatorName" }, { status: 400 });
  }

  upsertLiveSession({
    roomName,
    creatorIdentity,
    creatorName,
    creatorAvatarUrl: creatorAvatarUrl || undefined,
    gameTitle: gameTitle || undefined,
    thumbUrl: thumbUrl || undefined,
    startedAt: Date.now(),
    tags,
  });

  return NextResponse.json({ success: true });
}

export async function DELETE(req: Request) {
  const body = (await req.json().catch(() => null)) as any;
  const roomName = String(body?.roomName || "").trim();
  if (!roomName) {
    return NextResponse.json({ success: false, message: "Missing roomName" }, { status: 400 });
  }
  removeLiveSession(roomName);
  return NextResponse.json({ success: true });
}
