import { proxyJson } from "@/app/api/_proxy";

export async function GET(req: Request, ctx: { params: Promise<{ roomId: string }> }) {
  const { roomId } = await ctx.params;
  return proxyJson(req, `/multiplayer/rooms/${encodeURIComponent(roomId)}`);
}

export async function PATCH(req: Request, ctx: { params: Promise<{ roomId: string }> }) {
  const { roomId } = await ctx.params;
  return proxyJson(req, `/multiplayer/rooms/${encodeURIComponent(roomId)}`);
}

export async function DELETE(req: Request, ctx: { params: Promise<{ roomId: string }> }) {
  const { roomId } = await ctx.params;
  return proxyJson(req, `/multiplayer/rooms/${encodeURIComponent(roomId)}`);
}
