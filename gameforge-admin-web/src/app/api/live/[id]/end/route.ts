import { proxyJson } from "@/app/api/_proxy";

export async function POST(req: Request, ctx: { params: Promise<{ id: string }> }) {
  const { id } = await ctx.params;
  const url = new URL(req.url);
  const qs = url.search;
  return proxyJson(req, `/live/${encodeURIComponent(id)}/end${qs}`);
}
