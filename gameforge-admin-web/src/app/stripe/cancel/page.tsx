"use client";

import { useRouter } from "next/navigation";
import UserShell from "@/app/_components/UserShell";

export default function StripeCancelPage() {
  const router = useRouter();
  return (
    <UserShell title="Subscription" subtitle="Payment canceled">
      <div className="mt-6 gf-panel-strong rounded-3xl p-6 border border-white/10">
        <div className="text-sm text-zinc-300">Your payment was canceled. You can try again anytime.</div>
        <div className="mt-4 flex gap-2">
          <button className="gf-btn rounded-xl px-4 py-2 text-sm" onClick={() => router.push("/studio/subscription")}
          >
            Back to plans
          </button>
          <button className="rounded-xl bg-indigo-500 px-4 py-2 text-sm font-black text-white" onClick={() => router.push("/studio/subscription")}
          >
            Try again
          </button>
        </div>
      </div>
    </UserShell>
  );
}
