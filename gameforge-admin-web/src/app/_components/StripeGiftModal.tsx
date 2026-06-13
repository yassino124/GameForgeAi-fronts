"use client";

import React, { useState, useEffect } from "react";
import {
  Elements,
  PaymentElement,
  useStripe,
  useElements,
} from "@stripe/react-stripe-js";
import { loadStripe } from "@stripe/stripe-js";
import { X, Loader2, ShieldCheck, Coins } from "lucide-react";
import { motion, AnimatePresence } from "framer-motion";

const STRIPE_PUBLISHABLE_KEY = process.env.NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY || "";
const stripePromise = STRIPE_PUBLISHABLE_KEY ? loadStripe(STRIPE_PUBLISHABLE_KEY) : null;

function CheckoutForm({
  amount,
  giftName,
  onSuccess,
  onCancel,
}: {
  amount: number;
  giftName: string;
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

    const res = await stripe.confirmPayment({
      elements,
      redirect: "if_required",
    });

    if (res.error) {
      setError(res.error.message || "An unexpected error occurred.");
      setProcessing(false);
      return;
    }

    const status = (res as any)?.paymentIntent?.status as string | undefined;
    if (status === "succeeded" || status === "processing" || status === "requires_capture") {
      setProcessing(false);
      onSuccess();
      return;
    }

    setError(
      status
        ? `Payment not completed yet (status: ${status}). Please try again.`
        : "Payment not completed yet. Please try again.",
    );
    setProcessing(false);
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
          {processing ? <Loader2 size={18} className="animate-spin" /> : "Purchase Gift"}
        </button>
      </div>

      <div className="flex items-center justify-center gap-2 text-[10px] text-white/30 pt-2">
        <ShieldCheck size={12} />
        Secure SSL Encrypted Payment
      </div>
    </form>
  );
}

export default function StripeGiftModal({
  isOpen,
  onClose,
  gift,
  onPurchaseSuccess,
}: {
  isOpen: boolean;
  onClose: () => void;
  gift: { id: string; name: string; price: number } | null;
  onPurchaseSuccess: (giftId: string) => void;
}) {
  const [clientSecret, setClientSecret] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (isOpen && gift) {
      if (!STRIPE_PUBLISHABLE_KEY) {
        setError("Missing NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY (Stripe publishable key)");
        setClientSecret(null);
        setLoading(false);
        return;
      }

      setLoading(true);
      setError(null);
      setClientSecret(null);
      
      fetch("/api/gifts/create-intent", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ giftId: gift.id, amount: gift.price }),
      })
        .then((res) => res.json())
        .then((j) => {
          if (j.success && j.clientSecret) {
            setClientSecret(j.clientSecret);
          } else {
            setError(j.message || "Failed to initialize payment");
          }
        })
        .catch((err) => {
          setError(err.message || "Network error");
        })
        .finally(() => {
          setLoading(false);
        });
    }
  }, [isOpen, gift]);

  if (!isOpen || !gift) return null;

  return (
    <AnimatePresence>
      <div className="fixed inset-0 z-[100] flex items-center justify-center p-4">
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          exit={{ opacity: 0 }}
          onClick={onClose}
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
                <h2 className="text-xl font-black text-white">Gift Purchase</h2>
                <p className="text-xs text-white/50">Send {gift.name} to the creator</p>
              </div>
              <button
                onClick={onClose}
                className="h-10 w-10 flex items-center justify-center rounded-full bg-white/5 hover:bg-white/10 text-white/60 transition-colors"
              >
                <X size={20} />
              </button>
            </div>

            {loading ? (
              <div className="py-20 flex flex-col items-center justify-center gap-4">
                <Loader2 size={40} className="text-blue-500 animate-spin" />
                <p className="text-sm text-white/50 font-medium">Securing payment intent...</p>
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
                      fontFamily: "ui-sans-serif, system-ui, -apple-system, Segoe UI, Roboto, Helvetica, Arial",
                    },
                  },
                }}
              >
                <CheckoutForm 
                  amount={gift.price} 
                  giftName={gift.name} 
                  onSuccess={() => onPurchaseSuccess(gift.id)}
                  onCancel={onClose}
                />
              </Elements>
            ) : (
              <div className="py-6 space-y-4">
                <div className="p-4 rounded-2xl bg-red-500/10 border border-red-500/20">
                  <p className="text-sm text-red-200 font-semibold">Payment initialization failed</p>
                  <p className="text-xs text-red-200/70 mt-2 break-words">
                    {error || "No clientSecret returned from /api/gifts/create-intent"}
                  </p>
                </div>
              </div>
            )}
          </div>
        </motion.div>
      </div>
    </AnimatePresence>
  );
}
