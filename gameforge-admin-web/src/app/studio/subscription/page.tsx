"use client";

import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { motion, AnimatePresence } from "framer-motion";
import UserShell from "@/app/_components/UserShell";
import { apiFetch } from "@/lib/api";
import StripeSubscriptionModal from "@/app/_components/StripeSubscriptionModal";
import { useAuthToken } from "@/lib/stores/authStore";
import {
  Sparkles, Zap, Shield, Building2, Check, ArrowRight,
  Star, Crown, Rocket, Infinity as InfinityIcon,
} from "lucide-react";

type ProfileUser = { subscription?: string; plan?: string };
type ProfilePayload = { user?: ProfileUser; subscription?: string; plan?: string };

function normalizeProfilePayload(value: unknown): ProfilePayload {
  if (!value || typeof value !== "object") return {};
  const record = value as Record<string, unknown>;
  if (record.data && typeof record.data === "object") return record.data as ProfilePayload;
  return record as ProfilePayload;
}

type Plan = {
  id: string;
  name: string;
  price: number;
  interval: string;
  tagline: string;
  features: string[];
  isPopular?: boolean;
  current?: boolean;
  icon: React.ReactNode;
  accentFrom: string;
  accentTo: string;
  glowColor: string;
  textAccent: string;
};

export default function SubscriptionPage() {
  const { token, hydrated } = useAuthToken();
  const [uiError, setUiError] = useState<string | null>(null);
  const [hoveredPlan, setHoveredPlan] = useState<string | null>(null);
  const [checkoutLoadingPlanId, setCheckoutLoadingPlanId] = useState<string | null>(null);
  const [checkoutPlan, setCheckoutPlan] = useState<{ id: "pro" | "studio"; name: string; price: number } | null>(null);
  const [annual, setAnnual] = useState(false);

  const plans: Plan[] = [
    {
      id: "free",
      name: "Free",
      price: 0,
      interval: "month",
      tagline: "Start building today",
      features: [
        "3 Projects",
        "Standard AI Generation",
        "Basic Asset Library",
        "Web Exports",
        "Community Support",
      ],
      icon: <Sparkles size={22} />,
      accentFrom: "from-zinc-600",
      accentTo: "to-zinc-700",
      glowColor: "rgba(161,161,170,0.15)",
      textAccent: "text-zinc-300",
    },
    {
      id: "pro",
      name: "Pro",
      price: annual ? 15 : 19,
      interval: "month",
      tagline: "For serious creators",
      features: [
        "Unlimited Projects",
        "Advanced AI Models",
        "Premium Asset Library",
        "Android & iOS Builds",
        "Priority Support",
        "Analytics Dashboard",
      ],
      isPopular: true,
      icon: <Zap size={22} />,
      accentFrom: "from-blue-500",
      accentTo: "to-sky-600",
      glowColor: "rgba(99,102,241,0.25)",
      textAccent: "text-blue-300",
    },
    {
      id: "studio",
      name: "Studio",
      price: annual ? 39 : 49,
      interval: "month",
      tagline: "For teams & studios",
      features: [
        "Everything in Pro",
        "Team Collaboration",
        "Custom AI Fine-tuning",
        "Dedicated Build Server",
        "White-label Exports",
        "Commercial License",
      ],
      icon: <Crown size={22} />,
      accentFrom: "from-amber-500",
      accentTo: "to-orange-600",
      glowColor: "rgba(245,158,11,0.2)",
      textAccent: "text-amber-300",
    },
  ];

  const profileQuery = useQuery({
    queryKey: ["auth-profile", token],
    enabled: hydrated && !!token,
    queryFn: async () => {
      const res = await apiFetch("/auth/profile", { method: "GET", token: token! });
      const data = normalizeProfilePayload(res);
      const userObj = data.user ?? data;
      const rawPlan = String(userObj?.subscription ?? userObj?.plan ?? "Free");
      return rawPlan.charAt(0).toUpperCase() + rawPlan.slice(1).toLowerCase();
    },
  });

  const loading = !hydrated || profileQuery.isLoading;
  const userPlan = profileQuery.data ?? "Free";
  const error = uiError ?? (profileQuery.error instanceof Error ? profileQuery.error.message : null);

  async function refreshProfile() {
    if (!token) return;
    await profileQuery.refetch();
  }

  return (
    <UserShell title="Subscription" subtitle="Choose the right plan for your creativity">
      {/* Ambient background */}
      <div className="pointer-events-none absolute inset-0 overflow-hidden">
        <div className="absolute top-[-20%] left-[10%] w-[700px] h-[700px] bg-blue-600/8 blur-[160px] rounded-full" />
        <div className="absolute bottom-[-10%] right-[5%] w-[500px] h-[500px] bg-sky-600/6 blur-[140px] rounded-full" />
        <div className="absolute top-[40%] left-[-5%] w-[400px] h-[400px] bg-amber-500/4 blur-[120px] rounded-full" />
      </div>

      <div className="relative z-10 mt-4 space-y-10 pb-20">
        <StripeSubscriptionModal
          isOpen={!!checkoutPlan}
          plan={checkoutPlan}
          onClose={() => { setCheckoutPlan(null); setCheckoutLoadingPlanId(null); }}
          onActivated={async () => { await refreshProfile(); }}
        />

        {error && (
          <div className="mb-6 rounded-2xl border border-red-500/25 bg-red-500/10 p-4 text-sm text-red-200">
            {error}
          </div>
        )}

        {/* Hero */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          className="text-center"
        >
          <div className="inline-flex items-center gap-2 mb-6 px-4 py-2 rounded-full border border-blue-500/30 bg-blue-500/10">
            <Star size={14} className="text-blue-400" />
            <span className="text-[11px] font-black uppercase tracking-[0.3em] text-blue-300">Forge Your Path</span>
          </div>
          <h2 className="text-4xl md:text-5xl font-black tracking-tighter text-[var(--foreground)] leading-none mb-4">
            Choose Your{" "}
            <span className="text-transparent bg-clip-text bg-gradient-to-r from-blue-400 via-sky-400 to-cyan-400">
              GameForge Plan
            </span>
          </h2>
          <p className="text-zinc-400 text-base max-w-md mx-auto leading-relaxed">
            From indie builders to professional studios — find the plan that matches your ambition.
          </p>

          {/* Annual toggle */}
          <div className="mt-8 inline-flex items-center gap-4 bg-[var(--gf-panel-bg-strong)] border border-zinc-200/50 dark:border-white/10 rounded-2xl p-1.5 shadow-sm">
            <button
              onClick={() => setAnnual(false)}
              className={`px-5 py-2.5 rounded-xl text-xs font-black uppercase tracking-[0.2em] transition-all ${!annual ? "bg-white/10 text-white shadow" : "text-zinc-500 hover:text-zinc-300"
                }`}
            >
              Monthly
            </button>
            <button
              onClick={() => setAnnual(true)}
              className={`px-5 py-2.5 rounded-xl text-xs font-black uppercase tracking-[0.2em] transition-all flex items-center gap-2 ${annual ? "bg-blue-500 text-white shadow-lg shadow-blue-500/30" : "text-zinc-500 hover:text-zinc-300"
                }`}
            >
              Annual
              <span className="bg-emerald-500/20 text-emerald-400 border border-emerald-500/30 px-2 py-0.5 rounded-full text-[9px]">
                −20%
              </span>
            </button>
          </div>
        </motion.div>

        {/* Pricing cards */}
        <div className="grid grid-cols-1 gap-6 md:grid-cols-3">
          {plans.map((plan, idx) => {
            const p = userPlan.toLowerCase();
            const isCurrent =
              p === plan.name.toLowerCase() ||
              (plan.id === "studio" && (p.includes("enterprise") || p.includes("studio"))) ||
              (plan.id === "pro" && (p.includes("pro") || p.includes("premium"))) ||
              (plan.id === "free" && p === "free");
            const isPaidPlan = p !== "free" && p !== "";
            const finalIsCurrent =
              isCurrent ||
              (isPaidPlan && plan.id === "pro" && !p.includes("enterprise") && !p.includes("studio"));
            const isCheckoutLoading = checkoutLoadingPlanId === plan.id;
            const isHovered = hoveredPlan === plan.id;

            return (
              <motion.div
                key={plan.id}
                initial={{ opacity: 0, y: 30 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: idx * 0.1 }}
                onMouseEnter={() => setHoveredPlan(plan.id)}
                onMouseLeave={() => setHoveredPlan(null)}
                className={`relative flex flex-col rounded-[32px] p-[1px] transition-all duration-500 ${plan.isPopular
                    ? "shadow-[0_0_60px_rgba(99,102,241,0.2)]"
                    : ""
                  }`}
                style={{
                  background: isHovered || plan.isPopular
                    ? `linear-gradient(135deg, ${plan.id === "free" ? "#3f3f46" : plan.id === "pro" ? "#6366f1" : "#f59e0b"}, transparent 60%)`
                    : "transparent",
                  boxShadow: isHovered ? `0 0 60px ${plan.glowColor}` : plan.isPopular ? `0 0 40px ${plan.glowColor}` : "none",
                }}
              >
                <div className="relative flex flex-col h-full rounded-[31px] bg-[var(--gf-panel-bg-strong)] border border-zinc-200/50 dark:border-white/[0.07] overflow-hidden">
                  {/* Popular badge */}
                  {plan.isPopular && (
                    <div className="absolute top-0 left-0 right-0 h-[2px] bg-gradient-to-r from-transparent via-blue-500 to-transparent" />
                  )}
                  {plan.isPopular && (
                    <div className="absolute top-5 right-5">
                      <div className="flex items-center gap-1.5 bg-blue-500 px-3 py-1.5 rounded-full text-[9px] font-black uppercase tracking-[0.2em] text-white shadow-[0_0_20px_rgba(99,102,241,0.4)]">
                        <Zap size={10} className="fill-white" />
                        Most Popular
                      </div>
                    </div>
                  )}

                  {/* Current badge */}
                  {finalIsCurrent && (
                    <div className="absolute top-5 right-5">
                      <div className="flex items-center gap-1.5 bg-emerald-500/20 border border-emerald-500/30 px-3 py-1.5 rounded-full text-[9px] font-black uppercase tracking-[0.2em] text-emerald-400">
                        <div className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse" />
                        Active
                      </div>
                    </div>
                  )}

                  {/* BG glow */}
                  <div
                    className="absolute inset-0 pointer-events-none transition-opacity duration-500"
                    style={{
                      background: `radial-gradient(ellipse at top left, ${plan.glowColor}, transparent 60%)`,
                      opacity: isHovered ? 1 : 0.4,
                    }}
                  />

                  <div className="relative z-10 p-8 flex flex-col h-full">
                    {/* Icon + plan name */}
                    <div className="mb-6">
                      <div
                        className={`inline-flex items-center justify-center w-12 h-12 rounded-2xl mb-5 bg-gradient-to-br ${plan.accentFrom} ${plan.accentTo} shadow-lg ${plan.textAccent === "text-blue-300" ? "shadow-blue-500/30" : plan.textAccent === "text-amber-300" ? "shadow-amber-500/30" : "shadow-zinc-500/20"}`}
                      >
                        <div className="text-white">{plan.icon}</div>
                      </div>
                      <div className="flex items-baseline gap-1">
                        <span className="text-4xl font-black text-[var(--foreground)] tracking-tighter">
                          ${plan.price}
                        </span>
                        <span className="text-sm text-zinc-500 font-medium">/{plan.interval}</span>
                      </div>
                      <div className="mt-1 text-xl font-black text-[var(--foreground)] tracking-tight">{plan.name}</div>
                      <div className="mt-1 text-xs text-zinc-500 font-medium">{plan.tagline}</div>
                    </div>

                    {/* Features */}
                    <ul className="mb-8 flex-1 space-y-3">
                      {plan.features.map((f, fi) => (
                        <motion.li
                          key={f}
                          initial={{ opacity: 0, x: -10 }}
                          animate={{ opacity: 1, x: 0 }}
                          transition={{ delay: idx * 0.1 + fi * 0.05 }}
                          className="flex items-start gap-3 text-sm"
                        >
                          <div className={`mt-0.5 flex-shrink-0 w-5 h-5 rounded-full flex items-center justify-center bg-gradient-to-br ${plan.accentFrom} ${plan.accentTo} opacity-90`}>
                            <Check size={12} className="text-white" strokeWidth={3} />
                          </div>
                          <span className="text-zinc-600 dark:text-zinc-300 font-bold leading-relaxed">{f}</span>
                        </motion.li>
                      ))}
                    </ul>

                    {/* CTA button */}
                    <button
                      disabled={finalIsCurrent || isCheckoutLoading || loading}
                      onClick={() => {
                        if (finalIsCurrent || loading) return;
                        if (plan.id === "pro") {
                          setUiError(null);
                          setCheckoutLoadingPlanId("pro");
                          setCheckoutPlan({ id: "pro", name: "Pro", price: plan.price });
                        }
                        if (plan.id === "studio") {
                          setUiError(null);
                          setCheckoutLoadingPlanId("studio");
                          setCheckoutPlan({ id: "studio", name: "Studio", price: plan.price });
                        }
                      }}
                      className={`w-full relative overflow-hidden rounded-2xl py-4 text-sm font-black uppercase tracking-[0.15em] transition-all group ${finalIsCurrent
                          ? "bg-white/5 text-zinc-500 cursor-default border border-white/10"
                          : plan.isPopular
                            ? "bg-gradient-to-r from-blue-600 to-sky-600 text-white hover:from-blue-500 hover:to-sky-500 shadow-xl shadow-blue-500/25 hover:scale-[1.02] active:scale-[0.98]"
                            : plan.id === "studio"
                              ? "bg-gradient-to-r from-amber-600 to-orange-600 text-white hover:from-amber-500 hover:to-orange-500 shadow-xl shadow-amber-500/20 hover:scale-[1.02] active:scale-[0.98]"
                              : "border border-white/15 bg-white/5 text-white hover:bg-white/10 hover:scale-[1.02] active:scale-[0.98]"
                        }`}
                    >
                      {/* Shimmer */}
                      {!finalIsCurrent && (
                        <motion.div
                          animate={{ x: ["-100%", "200%"] }}
                          transition={{ duration: 3, repeat: Infinity, ease: "linear", repeatDelay: 2 }}
                          className="absolute inset-0 bg-gradient-to-r from-transparent via-white/15 to-transparent skew-x-12 pointer-events-none"
                        />
                      )}
                      <span className="relative z-10 flex items-center justify-center gap-2">
                        {finalIsCurrent
                          ? "Current Plan"
                          : plan.price === 0
                            ? "Get Started"
                            : isCheckoutLoading
                              ? "Redirecting…"
                              : (
                                <>
                                  Upgrade to {plan.name}
                                  <ArrowRight size={16} className="transition-transform group-hover:translate-x-1" />
                                </>
                              )}
                      </span>
                    </button>
                  </div>
                </div>
              </motion.div>
            );
          })}
        </div>

        {/* Enterprise strip */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.4 }}
          className="relative overflow-hidden rounded-[32px] border border-white/[0.06] bg-gradient-to-r from-[#0c0d1a] to-[#0f1020] p-10"
        >
          <div className="absolute inset-0 bg-gradient-to-r from-blue-500/5 via-transparent to-cyan-500/5 pointer-events-none" />
          <div className="relative z-10 flex flex-col md:flex-row md:items-center justify-between gap-6">
            <div className="flex items-center gap-5">
              <div className="h-14 w-14 rounded-2xl bg-zinc-100 dark:bg-zinc-800 border border-zinc-200 dark:border-white/10 flex items-center justify-center shadow-xl">
                <Building2 size={24} className="text-zinc-900 dark:text-zinc-100" />
              </div>
              <div>
                <div className="text-lg font-black text-[var(--foreground)] tracking-tight">Enterprise & Custom</div>
                <div className="text-sm text-zinc-500 dark:text-zinc-400 mt-1 font-medium">Dedicated infrastructure, custom AI fine-tuning, SLA & more.</div>
              </div>
            </div>
            <button className="group shrink-0 flex items-center gap-3 border border-zinc-200 dark:border-white/10 bg-white dark:bg-white/5 hover:bg-zinc-50 dark:hover:bg-white/10 text-zinc-900 dark:text-white rounded-2xl px-8 py-4 text-sm font-black uppercase tracking-[0.2em] transition-all hover:scale-[1.02] shadow-sm">
              Talk to Sales
              <ArrowRight size={16} className="transition-transform group-hover:translate-x-1" />
            </button>
          </div>
        </motion.div>
      </div>
    </UserShell>
  );
}
