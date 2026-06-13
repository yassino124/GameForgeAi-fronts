import { NextRequest, NextResponse } from 'next/server';

function resolveBackendApiBase(): string {
  const raw =
    process.env.API_URL ||
    process.env.NEXT_PUBLIC_API_URL ||
    'http://localhost:3000';
  const base = raw.replace(/\/+$/g, '');
  return base.endsWith('/api') ? base : `${base}/api`;
}

export async function POST(req: NextRequest) {
  try {
    const { prompt } = await req.json();
    const authHeader = req.headers.get('authorization');

    const backendUrl = resolveBackendApiBase();
    
    const res = await fetch(`${backendUrl}/ai/game-gen/refine-prompt`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        ...(authHeader ? { 'Authorization': authHeader } : {}),
      },
      body: JSON.stringify({ prompt }),
    });

    const data = await res.json();
    return NextResponse.json(data, { status: res.status });
  } catch (error: any) {
    console.error('[Refine Prompt Proxy Error]:', error);
    return NextResponse.json(
      {
        error: {
          message:
            (error?.message ? String(error.message) : 'Internal server error') +
            ` (backend=${resolveBackendApiBase()})`,
        },
      },
      { status: 500 }
    );
  }
}
