"use client";

import { useEffect, useMemo, useState } from "react";
import UserShell from "@/app/_components/UserShell";
import { apiFetch } from "@/lib/api";
import { getUserToken } from "@/lib/userAuth";
import StripeSubscriptionModal from "@/app/_components/StripeSubscriptionModal";

type Plan = {
  id: string;
  name: string;
  price: number;
  interval: string;
  features: string[];
  isPopular?: boolean;
  current?: boolean;
};

export default function SubscriptionPage() {
  const token = useMemo(() => getUserToken(), []);
  const [loading, setLoading] = useState(true);
  const [userPlan, setUserPlan] = useState<string>("Free");
  const [error, setError] = useState<string | null>(null);
  const [checkoutLoadingPlanId, setCheckoutLoadingPlanId] = useState<string | null>(null);
  const [checkoutPlan, setCheckoutPlan] = useState<{ id: "pro" | "studio"; name: string; price: number } | null>(null);

  const plans: Plan[] = [
    {
      id: "free",
      name: "Free",
      price: 0,
      interval: "month",
      features: ["3 Projects", "Standard AI Generation", "Basic Assets", "Web Exports"],
    },
    {
      id: "pro",
      name: "Pro",
      price: 19,
      interval: "month",
      features: ["Unlimited Projects", "Advanced AI Models", "Premium Asset Library", "Android & iOS Builds", "Priority Support"],
      isPopular: true,
    },
    {
      id: "studio",
      name: "Studio",
      price: 49,
      interval: "month",
      features: ["Team Collaboration", "Custom AI Fine-tuning", "Dedicated Build Server", "White-label Exports", "Commercial License"],
    },
  ];

  useEffect(() => {
    let cancelled = false;
    async function load() {
      if (!token) return;
      setLoading(true);
      setError(null);
      try {
        const res = await apiFetch<any>("/auth/profile", { method: "GET", token });
        const data = (res && typeof res === "object" && "data" in res) ? (res as any).data : res;
        const userObj = data?.user || data;
        console.log("Subscription page profile data:", data);
        if (!cancelled) {
          const rawPlan = (userObj?.subscription ?? userObj?.plan ?? "Free") as string;
          setUserPlan(rawPlan.charAt(0).toUpperCase() + rawPlan.slice(1).toLowerCase());
        }
      } catch (e: any) {
        if (!cancelled) setError(e?.message || "Failed to load subscription");
      } finally {
        if (!cancelled) setLoading(false);
      }
    }
    load();
    return () => {
      cancelled = true;
    };
  }, [token]);

  async function refreshProfile() {
    if (!token) return;
    try {
      const res = await apiFetch<any>("/auth/profile", { method: "GET", token });
      const data = (res && typeof res === "object" && "data" in res) ? (res as any).data : res;
      const userObj = data?.user || data;
      setUserPlan((userObj?.subscription ?? userObj?.plan ?? "Free") as string);
    } catch {
      // ignore
    }
  }

  return (
    <UserShell title="Subscription" subtitle="Choose the right plan for your creativity">
      <div className="mt-4">
        <StripeSubscriptionModal
          isOpen={!!checkoutPlan}
          plan={checkoutPlan}
          onClose={() => {
            setCheckoutPlan(null);
            setCheckoutLoadingPlanId(null);
          }}
          onActivated={async () => {
            await refreshProfile();
          }}
        />

        {error && (
          <div className="mb-6 rounded-2xl border border-red-500/25 bg-red-500/10 p-4 text-sm text-red-200">
            {error}
          </div>
        )}

        <div className="grid grid-cols-1 gap-6 md:grid-cols-3">
          {plans.map((plan) => {
            const p = userPlan.toLowerCase();
            const isCurrent = (p === plan.name.toLowerCase()) || 
                             (plan.id === "studio" && (p.includes("enterprise") || p.includes("studio"))) ||
                             (plan.id === "pro" && (p.includes("pro") || p.includes("premium"))) ||
                             (plan.id === "free" && p === "free");
            
            // If user has a plan that isn't free, and we are looking at pro/studio, check if it's a match
            const isPaidPlan = p !== "free" && p !== "";
            const finalIsCurrent = isCurrent || (isPaidPlan && plan.id === "pro" && !p.includes("enterprise") && !p.includes("studio"));

            const isCheckoutLoading = checkoutLoadingPlanId === plan.id;
            return (
              <div 
                key={plan.id}
                className={`gf-panel-strong relative flex flex-col rounded-3xl p-6 transition-all hover:-translate-y-1 ${
                  plan.isPopular ? "border-indigo-500/50 shadow-[0_0_30px_rgba(99,102,241,0.15)]" : "border-white/10"
                }`}
              >
                {plan.isPopular && (
                  <div className="absolute -top-3 left-1/2 -translate-x-1/2 rounded-full bg-indigo-500 px-3 py-1 text-[10px] font-bold uppercase tracking-wider text-white">
                    Most Popular
                  </div>
                )}

                <div className="mb-6">
                  <h3 className="text-xl font-bold text-white">{plan.name}</h3>
                  <div className="mt-4 flex items-baseline">
                    <span className="text-4xl font-bold tracking-tight text-white">${plan.price}</span>
                    <span className="ml-1 text-sm text-zinc-400">/{plan.interval}</span>
                  </div>
                </div>

                <ul className="mb-8 flex-1 space-y-3">
                  {plan.features.map((f) => (
                    <li key={f} className="flex items-start gap-3 text-sm text-zinc-300">
                      <svg className="mt-0.5 h-4 w-4 shrink-0 text-emerald-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                      </svg>
                      {f}
                    </li>
                  ))}
                </ul>

                <button
                  disabled={finalIsCurrent || isCheckoutLoading || loading}
                  onClick={() => {
                    if (finalIsCurrent || loading) return;
                    if (plan.id === "pro") {
                      setError(null);
                      setCheckoutLoadingPlanId("pro");
                      setCheckoutPlan({ id: "pro", name: "Pro", price: plan.price });
                    }
                    if (plan.id === "studio") {
                      setError(null);
                      setCheckoutLoadingPlanId("studio");
                      setCheckoutPlan({ id: "studio", name: "Studio", price: plan.price });
                    }
                  }}
                  className={`w-full rounded-xl py-3 text-sm font-semibold transition-all ${
                    finalIsCurrent 
                      ? "bg-white/5 text-zinc-400 cursor-default" 
                      : plan.isPopular
                        ? "bg-indigo-500 text-white hover:bg-indigo-600 shadow-lg shadow-indigo-500/20"
                        : "gf-btn text-white"
                  }`}
                >
                  {finalIsCurrent
                    ? "Current Plan"
                    : plan.price === 0
                      ? "Get Started"
                      : isCheckoutLoading
                        ? "Redirecting…"
                        : "Upgrade Now"}
                </button>
              </div>
            );
          })}
        </div>

        <div className="mt-10 rounded-3xl border border-white/5 bg-white/2 bg-black/20 p-8 text-center">
          <h4 className="text-lg font-semibold text-white">Need a custom solution?</h4>
          <p className="mt-2 text-sm text-zinc-400">Contact us for custom enterprise plans and dedicated support.</p>
          <button className="mt-6 text-sm font-semibold text-indigo-400 hover:text-indigo-300">Talk to Sales →</button>
        </div>
      </div>
    </UserShell>
  );
}
