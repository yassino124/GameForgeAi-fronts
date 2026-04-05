import { NextResponse } from "next/server";

export async function POST(req: Request) {
  try {
    const keyRaw =
      process.env.GEMINI_API_KEY ||
      process.env.GOOGLE_API_KEY ||
      process.env.GOOGLE_GENERATIVE_AI_API_KEY ||
      process.env.GENERATIVE_LANGUAGE_API_KEY;
    const key = (keyRaw || "").trim();
    if (!key) {
      return NextResponse.json(
        {
          success: false,
          message:
            "Missing Gemini API key env var. Set GEMINI_API_KEY (recommended) or GOOGLE_API_KEY / GOOGLE_GENERATIVE_AI_API_KEY in .env.local, then restart next dev.",
        },
        { status: 500 },
      );
    }

    const model = (process.env.GEMINI_MODEL || "gemini-1.5-flash-latest").trim() || "gemini-1.5-flash-latest";

    const body = (await req.json().catch(() => null)) as any;
    const message = String(body?.message || "").trim();
    const context = body?.context ?? {};
    const history = Array.isArray(body?.history) ? body.history : [];

    if (!message) {
      return NextResponse.json({ success: false, message: "Missing message" }, { status: 400 });
    }

    const sys =
      "You are an operations copilot for a gaming platform admin dashboard. " +
      "Answer concisely with actionable steps. When you propose actions, reference the relevant admin page (Dashboard/Builds/Projects/Users/Templates/Billing/System). " +
      "If you need more data, ask a short follow-up question.";

    const ctxText = "Current metrics/context JSON:\n" + JSON.stringify(context, null, 2);

    const contents = [
      { role: "user", parts: [{ text: sys + "\n\n" + ctxText }] },
      ...history
        .map((h: any) => {
          const role = h?.role === "model" || h?.role === "assistant" ? "model" : "user";
          const text = String(h?.text || h?.content || "");
          return { role, parts: [{ text }] };
        })
        .filter((c: any) => c?.parts?.[0]?.text),
      { role: "user", parts: [{ text: message }] },
    ];

    async function callModel(m: string) {
      const url = `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(
        m,
      )}:generateContent?key=${encodeURIComponent(key)}`;
      return fetch(url, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          contents,
          generationConfig: { temperature: 0.35, maxOutputTokens: 500 },
        }),
      });
    }

    async function selectAvailableModel() {
      try {
        const listUrl = `https://generativelanguage.googleapis.com/v1beta/models?key=${encodeURIComponent(key)}`;
        const lr = await fetch(listUrl, { method: "GET" });
        if (!lr.ok) return null;
        const lj = (await lr.json().catch(() => null)) as any;
        const models: any[] = Array.isArray(lj?.models) ? lj.models : [];
        const supports = models.filter(
          (m) => Array.isArray(m?.supportedGenerationMethods) && m.supportedGenerationMethods.includes("generateContent"),
        );
        const preferred = ["models/gemini-1.5-flash", "models/gemini-1.5-pro", "models/gemini-pro", "models/gemini-1.0-pro"];
        for (const p of preferred) {
          const hit = supports.find((m) => String(m?.name) === p);
          if (hit) return String(hit.name).replace(/^models\//, "");
        }
        const first = supports[0];
        if (first?.name) return String(first.name).replace(/^models\//, "");
        return null;
      } catch {
        return null;
      }
    }

    let modelUsed = model;
    let r = await callModel(modelUsed);
    if (!r.ok && (r.status === 404 || r.status === 400)) {
      const fallbacks = ["gemini-1.5-flash", "gemini-1.5-pro", "gemini-pro", "gemini-1.0-pro"];
      for (const fb of fallbacks) {
        if (fb === modelUsed) continue;
        const rr = await callModel(fb);
        if (rr.ok) {
          modelUsed = fb;
          r = rr;
          break;
        }
      }
    }
    if (!r.ok && r.status === 404) {
      const selected = await selectAvailableModel();
      if (selected) {
        const rr = await callModel(selected);
        if (rr.ok) {
          modelUsed = selected;
          r = rr;
        }
      }
    }

    if (!r.ok) {
      const t = await r.text().catch(() => "");
      console.error("Gemini chat error", { status: r.status, model: modelUsed, body: t?.slice?.(0, 1200) || t });
      return NextResponse.json(
        { success: false, message: `Gemini request failed (${r.status})`, error: t },
        { status: 500 },
      );
    }

    const j = (await r.json().catch(() => null)) as any;
    const text =
      j?.candidates?.[0]?.content?.parts?.map((p: any) => p?.text).filter(Boolean).join("\n") || "";

    return NextResponse.json({ success: true, data: { text, modelUsed } }, { status: 200 });
  } catch (e: any) {
    console.error("Gemini chat route failed", e);
    return NextResponse.json({ success: false, message: e?.message || "AI route failed" }, { status: 500 });
  }
}
