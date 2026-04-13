import { proxyJson } from "@/app/api/_proxy";

export async function GET(req: Request) {
  const url = new URL(req.url);
  return proxyJson(req, `/game-feed${url.search}`);
}

export async function POST(req: Request) {
  const url = new URL(req.url);
  return proxyJson(req, `/game-feed${url.search}`);
}
