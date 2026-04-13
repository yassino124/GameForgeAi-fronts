import { NextResponse } from "next/server";

export async function POST(req: Request) {
  try {
    const body = (await req.json().catch(() => null)) as any;
    const message = String(body?.message || "").trim();
    const history = Array.isArray(body?.history) ? body.history : [];
    const context = body?.context ?? {};

    if (!message) {
      return NextResponse.json({ success: false, message: "Missing message" }, { status: 400 });
    }

    const baseUrl = (process.env.OLLAMA_BASE_URL || "http://localhost:11434").trim().replace(/\/$/, "");
    const model = (process.env.OLLAMA_MODEL || "llama3.1:8b").trim() || "llama3.1:8b";

    const sys =
      "You are GameForge AI Support Coach for the GameForge AI mobile app and web platform. " +
      "Your job is to help users resolve issues inside the app (login, feed, playing games, builds, templates, payments, bugs). " +
      "Answer in short, clear steps. If you need info, ask a single direct follow-up question. " +
      "If a user reports a bug, request exact screen name, steps to reproduce, and any error text.";

    const ctxText = "Context JSON (admin dashboard):\n" + JSON.stringify(context, null, 2);

    const messages = [
      { role: "system", content: sys + "\n\n" + ctxText },
      ...history
        .map((h: any) => {
          const role = h?.role === "assistant" ? "assistant" : "user";
          const content = String(h?.content || h?.text || "");
          return { role, content };
        })
        .filter((m: any) => m?.content?.trim?.()),
      { role: "user", content: message },
    ];

    const prompt = messages
      .map((m) => {
        const r = m.role === "assistant" ? "Assistant" : m.role === "system" ? "System" : "User";
        return `${r}: ${m.content}`;
      })
      .join("\n\n");

    let r: Response;
    try {
      r = await fetch(`${baseUrl}/api/chat`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          model,
          messages,
          stream: false,
          options: {
            temperature: 0.3,
          },
        }),
      });
    } catch (e: any) {
      const msg = String(e?.message || e || "Network error");
      return NextResponse.json(
        {
          success: false,
          message:
            `Failed to reach Ollama at ${baseUrl}. ` +
            `Make sure Ollama is running and accessible from this machine. (${msg})`,
          debug: { baseUrl, model },
        },
        { status: 500 },
      );
    }

    if (r.status === 404) {
      // Some installations expose only /api/generate.
      try {
        r = await fetch(`${baseUrl}/api/generate`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            model,
            prompt,
            stream: false,
            options: {
              temperature: 0.3,
            },
          }),
        });
      } catch (e: any) {
        const msg = String(e?.message || e || "Network error");
        return NextResponse.json(
          {
            success: false,
            message:
              `Failed to reach Ollama at ${baseUrl}. ` +
              `Make sure OLLAMA_BASE_URL points to the Ollama server (default http://localhost:11434). (${msg})`,
            debug: { baseUrl, model },
          },
          { status: 500 },
        );
      }
    }

    if (!r.ok) {
      const t = await r.text().catch(() => "");
      return NextResponse.json(
        {
          success: false,
          message: `Ollama request failed (${r.status})`,
          error: t?.slice?.(0, 2000) || t,
          debug: { baseUrl, model },
        },
        { status: 500 },
      );
    }

    const j = (await r.json().catch(() => null)) as any;

    const text = String(j?.message?.content || j?.response || "").trim();

    return NextResponse.json({ success: true, data: { text, modelUsed: model } }, { status: 200 });
  } catch (e: any) {
    return NextResponse.json({ success: false, message: e?.message || "AI route failed" }, { status: 500 });
  }
}
