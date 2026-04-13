import { proxyJson } from "@/app/api/_proxy";

export async function GET(req: Request) {
  const url = new URL(req.url);
  const qs = url.search;
  return proxyJson(req, `/live/feed${qs}`);
}
