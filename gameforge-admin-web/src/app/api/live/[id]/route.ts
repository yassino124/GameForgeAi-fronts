import { proxyJson } from "@/app/api/_proxy";

export async function GET(req: Request, ctx: { params: Promise<{ id: string }> }) {
  const { id } = await ctx.params;
  return proxyJson(req, `/live/${encodeURIComponent(id)}`);
}

export async function PATCH(req: Request, ctx: { params: Promise<{ id: string }> }) {
  const { id } = await ctx.params;
  return proxyJson(req, `/live/${encodeURIComponent(id)}`);
}
