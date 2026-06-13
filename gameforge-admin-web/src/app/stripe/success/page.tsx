"use client";

import { useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import UserShell from "@/app/_components/UserShell";
import { useAuthToken } from "@/lib/stores/authStore";

export default function StripeSuccessPage() {
  const router = useRouter();
  const { token } = useAuthToken();
  const [status, setStatus] = useState<string>("Syncing your subscription…");

  useEffect(() => {
    let cancelled = false;
    async function run() {
      if (!token) {
        setStatus("You must be signed in to sync your subscription.");
        return;
      }
      try {
        const res = await fetch("/api/billing/sync", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${token}`,
          },
        });
        const json = (await res.json().catch(() => null)) as any;
        if (!res.ok || json?.success !== true) {
          throw new Error(json?.message || `Sync failed (${res.status})`);
        }
        if (!cancelled) setStatus("Subscription activated. Redirecting…");
        setTimeout(() => {
          try {
            router.replace("/studio/subscription?synced=1");
          } catch {}
        }, 700);
      } catch (e: any) {
        if (!cancelled) setStatus(e?.message || "Sync failed");
      }
    }
    run();
    return () => {
      cancelled = true;
    };
  }, [router, token]);

  return (
    <UserShell title="Subscription" subtitle="Finalizing your upgrade">
      <div className="mt-6 gf-panel-strong rounded-3xl p-6 border border-white/10">
        <div className="text-sm text-zinc-300">{status}</div>
        <div className="mt-4">
          <button className="gf-btn rounded-xl px-4 py-2 text-sm" onClick={() => router.push("/studio/subscription")}
          >
            Back
          </button>
        </div>
      </div>
    </UserShell>
  );
}
