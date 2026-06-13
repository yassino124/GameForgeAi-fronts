"use client";

import React, { useEffect, useMemo, useState, useCallback } from "react";
import { Elements, PaymentElement, useElements, useStripe } from "@stripe/react-stripe-js";
import { loadStripe } from "@stripe/stripe-js";
import { X, Loader2, ShieldCheck, Coins } from "lucide-react";
import { AnimatePresence, motion } from "framer-motion";
import { useAuthToken } from "@/lib/stores/authStore";

const STRIPE_PUBLISHABLE_KEY = process.env.NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY || "";
const stripePromise = STRIPE_PUBLISHABLE_KEY ? loadStripe(STRIPE_PUBLISHABLE_KEY) : null;

function CheckoutForm({
  amount,
  clientSecret,
  onSuccess,
  onCancel,
}: {
  amount: number;
  clientSecret: string;
  onSuccess: () => void;
  onCancel: () => void;
}) {
  const stripe = useStripe();
  const elements = useElements();
  const [error, setError] = useState<string | null>(null);
  const [processing, setProcessing] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!stripe || !elements) return;

    setProcessing(true);
    setError(null);

    try {
      console.log("Stripe confirmPayment/confirmSetup starting with clientSecret:", clientSecret);
      
      const isSetupIntent = clientSecret?.startsWith('seti_');
      
      let res;
      if (isSetupIntent) {
        console.log("Detected SetupIntent, using confirmSetup");
        res = await stripe.confirmSetup({
          elements,
          redirect: "if_required",
        });
      } else {
        console.log("Detected PaymentIntent, using confirmPayment");
        res = await stripe.confirmPayment({
          elements,
          redirect: "if_required",
        });
      }

      console.log("Stripe result:", res);

      if (res.error) {
        console.error("Stripe error details:", res.error);
        setError(res.error.message || "An unexpected error occurred.");
        setProcessing(false);
        return;
      }

      const status = (res as any).setupIntent?.status || (res as any).paymentIntent?.status;
      console.log("Stripe operation status:", status);

      if (status === 'requires_action' || status === 'requires_confirmation') {
        console.log("Stripe requires further action/confirmation");
      }

      console.log("Stripe operation finished successfully, calling onSuccess...");
      setProcessing(false);
      onSuccess();
    } catch (err) {
      console.error("handleSubmit unexpected error:", err);
      setError("An unexpected error occurred during payment confirmation.");
      setProcessing(false);
    }
  };

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      <div className="gf-panel rounded-xl p-3 bg-white/5 border border-white/10 mb-4">
        <div className="flex justify-between items-center">
          <span className="text-xs text-white/50 uppercase tracking-widest font-bold">Total Payment</span>
          <div className="flex items-center gap-1">
            <Coins size={14} className="text-yellow-400" />
            <span className="text-xl font-black text-white">${amount.toFixed(2)}</span>
          </div>
        </div>
      </div>

      <PaymentElement
        options={{
          layout: { type: "tabs", defaultCollapsed: false },
          paymentMethodOrder: ["link", "card"],
        }}
      />

      {error && (
        <div className="p-3 rounded-xl bg-red-500/10 border border-red-500/20 text-red-400 text-xs">
          {error}
        </div>
      )}

      <div className="flex gap-3 pt-2">
        <button
          type="button"
          onClick={onCancel}
          className="flex-1 gf-btn rounded-xl py-3 text-sm font-bold"
          disabled={processing}
        >
          Cancel
        </button>
        <button
          type="submit"
          disabled={!stripe || processing}
          className="flex-[2] bg-gradient-to-r from-blue-500 to-cyan-500 hover:from-blue-400 hover:to-cyan-400 text-white rounded-xl py-3 text-sm font-black shadow-[0_0_20px_rgba(99,102,241,0.3)] disabled:opacity-50 flex items-center justify-center gap-2"
        >
          {processing ? <Loader2 size={18} className="animate-spin" /> : "Subscribe"}
        </button>
      </div>

      <div className="flex items-center justify-center gap-2 text-[10px] text-white/30 pt-2">
        <ShieldCheck size={12} />
        Secure SSL Encrypted Payment
      </div>
    </form>
  );
}

export default function StripeSubscriptionModal({
  isOpen,
  onClose,
  plan,
  onActivated,
}: {
  isOpen: boolean;
  onClose: () => void;
  plan: { id: "pro" | "studio"; name: string; price: number } | null;
  onActivated: () => void;
}) {
  const { token } = useAuthToken();
  const [clientSecret, setClientSecret] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [syncing, setSyncing] = useState(false);
  const [setupIntentId, setSetupIntentId] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    async function init() {
      if (!isOpen || !plan) return;

      if (!STRIPE_PUBLISHABLE_KEY) {
        setError("Missing NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY (Stripe publishable key)");
        setClientSecret(null);
        setLoading(false);
        return;
      }
      if (!token) {
        setError("You must be signed in to upgrade.");
        setClientSecret(null);
        setLoading(false);
        return;
      }

      setLoading(true);
      setError(null);
      setClientSecret(null);

      try {
        const res = await fetch("/api/billing/payment-sheet", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${token}`,
          },
          body: JSON.stringify({ planId: plan.id }),
        });
        const json = (await res.json().catch(() => null)) as any;
        if (!res.ok || json?.success !== true) {
          throw new Error(json?.message || `Failed to initialize payment (${res.status})`);
        }

        const data = json?.data;
        const cs =
          data?.setupIntentClientSecret ||
          data?.clientSecret ||
          data?.paymentIntentClientSecret;

        if (!cs || typeof cs !== "string") {
          throw new Error("Missing setupIntentClientSecret from /billing/setup-intent");
        }

        const setupId = data?.setupIntentId;

        if (!cancelled) {
          setClientSecret(cs);
          setSetupIntentId(setupId || null);
        }
      } catch (e: any) {
        if (!cancelled) setError(e?.message || "Network error");
      } finally {
        if (!cancelled) setLoading(false);
      }
    }

    init();
    return () => {
      cancelled = true;
    };
  }, [isOpen, plan, token]);

  const handleActivated = useCallback(async () => {
    if (!token || !plan || !setupIntentId) {
      console.error("Missing required data for activation:", { token: !!token, plan: !!plan, setupIntentId: !!setupIntentId });
      return;
    }
    setSyncing(true);
    setError(null);
    try {
      console.log("Starting subscription activation for plan:", plan.id);
      
      const priceId = plan.id === "pro" 
        ? "price_1SxsO7PhTgyf9vGv6y0ECGy8" 
        : "price_1SxsR4PhTgyf9vGv1zCsaB5w";

      console.log("Calling /api/billing/subscribe with priceId:", priceId);
      const subRes = await fetch("/api/billing/subscribe", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({ 
          priceId,
          setupIntentId 
        }),
      });

      const subJson = await subRes.json().catch(() => ({ success: false, message: "Invalid JSON response" }));
      console.log("Subscribe response:", subJson);
      
      if (!subRes.ok || subJson?.success !== true) {
        throw new Error(subJson?.message || `Subscription creation failed (${subRes.status})`);
      }

      // Add a small delay to allow Stripe webhooks/background sync to complete
      console.log("Waiting 2 seconds for backend to process subscription...");
      await new Promise(resolve => setTimeout(resolve, 2000));

      console.log("Syncing subscription status...");
      const syncRes = await fetch("/api/billing/sync", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${token}`,
        },
      });
      const syncJson = await syncRes.json().catch(() => ({}));
      console.log("Sync response:", syncJson);

      console.log("Activation successful! Force refreshing page to update all components.");
      onActivated();
      onClose();
      
      // Force a full page reload to ensure all layout/gating state is reset
      window.location.reload();
    } catch (e: any) {
      console.error("Activation error:", e);
      setError(e?.message || "Activation failed. Please check your connection.");
    } finally {
      setSyncing(false);
    }
  }, [token, plan, setupIntentId, onActivated, onClose]);

  if (!isOpen || !plan) return null;

  return (
    <AnimatePresence>
      <div className="fixed inset-0 z-[110] flex items-center justify-center p-4">
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          exit={{ opacity: 0 }}
          onClick={() => {
            if (syncing) return;
            onClose();
          }}
          className="absolute inset-0 bg-black/80 backdrop-blur-sm"
        />

        <motion.div
          initial={{ opacity: 0, scale: 0.9, y: 20 }}
          animate={{ opacity: 1, scale: 1, y: 0 }}
          exit={{ opacity: 0, scale: 0.9, y: 20 }}
          className="relative w-full max-w-md gf-panel-strong rounded-[32px] overflow-hidden shadow-2xl border border-white/10"
        >
          <div className="p-6">
            <div className="flex items-center justify-between mb-6">
              <div>
                <h2 className="text-xl font-black text-white">Upgrade to {plan.name}</h2>
                <p className="text-xs text-white/50">Unlock premium features instantly</p>
              </div>
              <button
                onClick={() => {
                  if (syncing) return;
                  onClose();
                }}
                className="h-10 w-10 flex items-center justify-center rounded-full bg-white/5 hover:bg-white/10 text-white/60 transition-colors"
              >
                <X size={20} />
              </button>
            </div>

            {loading ? (
              <div className="py-20 flex flex-col items-center justify-center gap-4">
                <Loader2 size={40} className="text-blue-500 animate-spin" />
                <p className="text-sm text-white/50 font-medium">Preparing secure payment…</p>
              </div>
            ) : clientSecret ? (
              <Elements
                stripe={stripePromise as any}
                options={{
                  clientSecret,
                  appearance: {
                    theme: "night",
                    variables: {
                      colorPrimary: "#a855f7",
                      colorBackground: "#0b0b12",
                      colorText: "#ffffff",
                      colorDanger: "#fb7185",
                      fontFamily:
                        "ui-sans-serif, system-ui, -apple-system, Segoe UI, Roboto, Helvetica, Arial",
                    },
                  },
                }}
              >
                <CheckoutForm 
                  amount={plan.price} 
                  clientSecret={clientSecret}
                  onSuccess={handleActivated} 
                  onCancel={onClose} 
                />
              </Elements>
            ) : (
              <div className="py-6 space-y-4">
                <div className="p-4 rounded-2xl bg-red-500/10 border border-red-500/20">
                  <p className="text-sm text-red-200 font-semibold">Payment initialization failed</p>
                  <p className="text-xs text-red-200/70 mt-2 break-words">
                    {error || "No clientSecret returned from /api/billing/payment-sheet"}
                  </p>
                </div>
              </div>
            )}

            {syncing && (
              <div className="mt-4 flex items-center justify-center gap-2 text-xs text-white/50">
                <Loader2 size={14} className="animate-spin" />
                Activating subscription…
              </div>
            )}
          </div>
        </motion.div>
      </div>
    </AnimatePresence>
  );
}
