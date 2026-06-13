import { proxyJson } from "@/app/api/_proxy";

function joinSlug(slug: string[] | undefined) {
  if (!slug || !slug.length) return "";
  return "/" + slug.map((s) => encodeURIComponent(s)).join("/");
}

async function forward(req: Request, ctx: { params: Promise<{ slug?: string[] }> }) {
  const { slug } = await ctx.params;
  const url = new URL(req.url);
  return proxyJson(req, `/platform-labs${joinSlug(slug)}${url.search}`);
}

export async function GET(req: Request, ctx: { params: Promise<{ slug?: string[] }> }) {
  return forward(req, ctx);
}

export async function POST(req: Request, ctx: { params: Promise<{ slug?: string[] }> }) {
  return forward(req, ctx);
}

export async function PUT(req: Request, ctx: { params: Promise<{ slug?: string[] }> }) {
  return forward(req, ctx);
}

export async function PATCH(req: Request, ctx: { params: Promise<{ slug?: string[] }> }) {
  return forward(req, ctx);
}

export async function DELETE(req: Request, ctx: { params: Promise<{ slug?: string[] }> }) {
  return forward(req, ctx);
}
