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

    const body = await req.json().catch(() => ({} as any));
    const metrics = body?.metrics ?? body;

    const model = (process.env.GEMINI_MODEL || "gemini-1.5-flash-latest").trim() || "gemini-1.5-flash-latest";

    const prompt =
      "You are an ops copilot for a gaming platform admin dashboard. " +
      "Given JSON metrics, produce: " +
      "(1) a 3-5 bullet executive brief, " +
      "(2) a list of 3 recommended actions with a short rationale each. " +
      "Be concise, numeric, and avoid generic advice. " +
      "Return STRICT JSON ONLY (no markdown, no code fences, no extra keys) " +
      "with shape: {brief: string[], actions: {title: string, why: string}[]}. " +
      "Metrics JSON:\n" +
      JSON.stringify(metrics, null, 2);

    async function callModel(m: string) {
      const url = `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(
        m,
      )}:generateContent?key=${encodeURIComponent(key)}`;
      return fetch(url, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          contents: [{ role: "user", parts: [{ text: prompt }] }],
          generationConfig: {
            temperature: 0.25,
            maxOutputTokens: 450,
            responseMimeType: "application/json",
          },
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
        const supports = models.filter((m) => Array.isArray(m?.supportedGenerationMethods) && m.supportedGenerationMethods.includes("generateContent"));
        const preferred = [
          "models/gemini-1.5-flash",
          "models/gemini-1.5-pro",
          "models/gemini-pro",
          "models/gemini-1.0-pro",
        ];
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
      // Some keys/projects don't have the same model aliases. Try a few known ones.
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
      console.error("Gemini ops-brief error", {
        status: r.status,
        model: modelUsed,
        body: t?.slice?.(0, 1200) || t,
      });
      return NextResponse.json(
        {
          success: false,
          message: `Gemini request failed (${r.status})`,
          error: t,
        },
        { status: 500 },
      );
    }

    const j = (await r.json().catch(() => null)) as any;
    const text =
      j?.candidates?.[0]?.content?.parts?.map((p: any) => p?.text).filter(Boolean).join("\n") || "";

    let parsed: any = null;
    try {
      parsed = JSON.parse(text);
    } catch {
      const cleaned = text
        .replace(/^```(json)?\s*/i, "")
        .replace(/```\s*$/i, "")
        .trim();
      try {
        parsed = JSON.parse(cleaned);
      } catch {
        parsed = null;
      }

      const m = (parsed ? null : cleaned).match(/\{[\s\S]*\}/);
      if (m) {
        try {
          parsed = JSON.parse(m[0]);
        } catch {
          parsed = null;
        }
      }
    }

    if (!parsed || !Array.isArray(parsed?.brief) || !Array.isArray(parsed?.actions)) {
      // Repair pass: sometimes models still return prose even with responseMimeType.
      const repairPrompt =
        "Convert the following content into STRICT JSON ONLY (no markdown, no code fences). " +
        "Output must match exactly: {brief: string[], actions: {title: string, why: string}[]}. " +
        "If information is missing, use empty arrays. Content:\n" +
        text;

      try {
        const rr = await callModel(modelUsed);
        // If the previous callModel doesn't include our new prompt, call directly here.
        // NOTE: We keep the same modelUsed and key.
        void rr;
      } catch {
        // ignore
      }

      try {
        const repairUrl = `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(
          modelUsed,
        )}:generateContent?key=${encodeURIComponent(key)}`;
        const rr = await fetch(repairUrl, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            contents: [{ role: "user", parts: [{ text: repairPrompt }] }],
            generationConfig: {
              temperature: 0.1,
              maxOutputTokens: 450,
              responseMimeType: "application/json",
            },
          }),
        });
        if (rr.ok) {
          const rj = (await rr.json().catch(() => null)) as any;
          const rtext =
            rj?.candidates?.[0]?.content?.parts?.map((p: any) => p?.text).filter(Boolean).join("\n") || "";
          try {
            const fixed = JSON.parse(rtext);
            if (Array.isArray(fixed?.brief) && Array.isArray(fixed?.actions)) {
              return NextResponse.json(
                {
                  success: true,
                  data: {
                    brief: fixed.brief,
                    actions: fixed.actions,
                    modelUsed,
                  },
                },
                { status: 200 },
              );
            }
          } catch {
            // fallthrough
          }
        }
      } catch {
        // fallthrough
      }

      return NextResponse.json(
        {
          success: true,
          data: {
            brief: ["AI response was not valid JSON. See raw."],
            actions: [],
            raw: text,
            modelUsed,
          },
        },
        { status: 200 },
      );
    }

    return NextResponse.json(
      {
        success: true,
        data: {
          brief: parsed.brief,
          actions: parsed.actions,
          modelUsed,
        },
      },
      { status: 200 },
    );
  } catch (e: any) {
    console.error("Gemini ops-brief route failed", e);
    return NextResponse.json(
      {
        success: false,
        message: e?.message || "AI route failed",
      },
      { status: 500 },
    );
  }
}
