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

    // Call our actual NestJS backend
    const backendUrl = resolveBackendApiBase();
    
    const targetUrl = `${backendUrl}/ai/game-gen/generate-stream`;
    const res = await fetch(targetUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        ...(authHeader ? { 'Authorization': authHeader } : {}),
      },
      body: JSON.stringify({ prompt }),
    });

    if (!res.ok) {
      const errorData = await res.json().catch(() => ({}));
      return NextResponse.json(
        { error: { message: errorData.message || 'Backend error' } },
        { status: res.status }
      );
    }

    // Proxy the stream back to the client
    return new NextResponse(res.body, {
      headers: {
        'Content-Type': 'text/event-stream',
        'Cache-Control': 'no-cache',
        'Connection': 'keep-alive',
      },
    });
  } catch (error: any) {
    console.error('[GameGen Proxy Error]:', error);
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
