import { proxyJson } from "@/app/api/_proxy";

export async function GET(req: Request, ctx: { params: Promise<{ roomId: string }> }) {
  const { roomId } = await ctx.params;
  const url = new URL(req.url);
  const qs = url.search;
  return proxyJson(req, `/multiplayer/rooms/${encodeURIComponent(roomId)}/messages${qs}`);
}
