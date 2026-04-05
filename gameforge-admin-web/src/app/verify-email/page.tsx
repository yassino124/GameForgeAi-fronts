"use client";

import { useEffect, useState, useRef, Suspense } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import Link from "next/link";
import { apiFetch, ApiError } from "@/lib/api";
import { setUserToken } from "@/lib/userAuth";
import { motion, AnimatePresence } from "framer-motion";
import { 
  Mail, 
  ArrowRight, 
  Loader2, 
  CheckCircle2, 
  AlertCircle,
  Sparkles,
  ShieldCheck
} from "lucide-react";

function VerifyEmailContent() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const email = searchParams.get("email") || "";
  const [code, setCode] = useState(["", "", "", "", "", ""]);
  const inputRefs = [
    useRef<HTMLInputElement>(null),
    useRef<HTMLInputElement>(null),
    useRef<HTMLInputElement>(null),
    useRef<HTMLInputElement>(null),
    useRef<HTMLInputElement>(null),
    useRef<HTMLInputElement>(null),
  ];
  
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [resending, setResending] = useState(false);
  const [success, setSuccess] = useState(false);

  const fullCode = code.join("");
  const canVerify = fullCode.length === 6 && !loading;

  const handleKeyDown = (index: number, e: React.KeyboardEvent<HTMLInputElement>) => {
    if (e.key === "Backspace" && !code[index] && index > 0) {
      inputRefs[index - 1].current?.focus();
    }
  };

  const handleChange = (index: number, value: string) => {
    if (!/^\d*$/.test(value)) return;
    
    const newCode = [...code];
    // Handle paste
    if (value.length > 1) {
      const pastedCode = value.slice(0, 6).split("");
      for (let i = 0; i < 6; i++) {
        if (pastedCode[i]) newCode[i] = pastedCode[i];
      }
      setCode(newCode);
      const focusIndex = Math.min(5, pastedCode.length);
      inputRefs[focusIndex].current?.focus();
      return;
    }

    newCode[index] = value;
    setCode(newCode);

    if (value && index < 5) {
      inputRefs[index + 1].current?.focus();
    }
  };

  async function onSubmit(e?: React.FormEvent) {
    if (e) e.preventDefault();
    if (fullCode.length !== 6 || loading) return;

    setLoading(true);
    setError(null);
    try {
      const res = (await apiFetch("/auth/verify-email-code", {
        method: "POST",
        body: { 
          email: email.trim(),
          code: fullCode.trim() 
        },
      })) as any;
      
      const token = res?.access_token || res?.data?.access_token;
      if (!token) {
        throw new Error(res?.message || "Verification succeeded but no token was returned");
      }

      setUserToken(token);
      
      setSuccess(true);
      setTimeout(() => {
        router.push("/studio");
      }, 1500);
    } catch (err: any) {
      setError(err?.message || "Verification failed");
    } finally {
      setLoading(false);
    }
  }

  async function onResend() {
    if (!email) return;
    setResending(true);
    setError(null);
    try {
      await apiFetch("/auth/resend-verification", { 
        method: "POST",
        body: { email: email.trim() }
      });
    } catch (err: any) {
      setError(err?.message || "Failed to resend code");
    } finally {
      setResending(false);
    }
  }

  useEffect(() => {
    if (fullCode.length === 6) {
      onSubmit();
    }
  }, [fullCode]);

  return (
    <div className="gf-panel-strong w-full rounded-[2.5rem] p-8 sm:p-10 border border-white/10 backdrop-blur-3xl bg-white/[0.03] shadow-[0_0_80px_rgba(0,0,0,0.5)] relative overflow-hidden">
      {/* Card Internal Glow */}
      <div className="absolute top-0 right-0 w-32 h-32 bg-indigo-500/5 blur-3xl -mr-16 -mt-16" />

      <AnimatePresence mode="wait">
        {success ? (
          <motion.div
            key="success"
            initial={{ opacity: 0, scale: 0.9 }}
            animate={{ opacity: 1, scale: 1 }}
            className="py-12 text-center"
          >
            <div className="relative inline-flex mb-8">
              <div className="h-20 w-20 rounded-full bg-green-500/10 flex items-center justify-center border border-green-500/20 shadow-[0_0_40px_rgba(34,197,94,0.15)]">
                <CheckCircle2 size={40} className="text-green-400" />
              </div>
            </div>
            <h2 className="text-2xl font-bold text-white mb-2 italic">Email Verified</h2>
            <p className="text-zinc-400 text-sm">Accessing your creative terminal...</p>
          </motion.div>
        ) : (
          <div className="relative z-10">
            <div className="text-center mb-10">
              <div className="inline-flex items-center gap-2 rounded-full border border-white/10 bg-white/5 px-3 py-1 text-[10px] font-bold uppercase tracking-widest text-zinc-200 mb-6">
                <Mail size={10} className="text-indigo-400 animate-pulse" />
                Identity Security
              </div>
              <h1 className="text-3xl font-black tracking-tight text-white italic mb-3">Check your <span className="text-transparent bg-clip-text bg-gradient-to-r from-indigo-400 to-fuchsia-400">email</span></h1>
              <p className="text-sm text-zinc-400 font-medium max-w-xs mx-auto leading-relaxed">
                Enter the 6-digit terminal code sent to<br/>
                <span className="text-white font-bold">{email}</span>
              </p>
            </div>

            <form onSubmit={onSubmit} className="space-y-8">
              <div className="flex justify-between gap-2 sm:gap-3">
                {code.map((digit, idx) => (
                  <input
                    key={idx}
                    ref={inputRefs[idx]}
                    type="text"
                    maxLength={1}
                    value={digit}
                    onChange={(e) => handleChange(idx, e.target.value)}
                    onKeyDown={(e) => handleKeyDown(idx, e)}
                    className="w-full h-14 sm:h-16 bg-zinc-950/40 border border-white/10 rounded-xl text-center text-2xl font-black text-white focus:outline-none focus:border-indigo-500/50 focus:bg-zinc-950/60 transition-all duration-300 shadow-inner"
                  />
                ))}
              </div>

              {error && (
                <motion.div initial={{ opacity: 0, y: -10 }} animate={{ opacity: 1, y: 0 }} className="flex items-center gap-2 px-4 py-3 rounded-xl bg-red-500/10 border border-red-500/20 text-red-400 text-xs font-medium">
                  <AlertCircle size={14} />
                  {error}
                </motion.div>
              )}

              <button
                type="submit"
                disabled={!canVerify}
                className="relative h-12 w-full group overflow-hidden rounded-xl transition-all duration-500 disabled:opacity-30 disabled:grayscale"
              >
                <div className="absolute inset-0 bg-gradient-to-r from-indigo-600 via-fuchsia-600 to-cyan-500 group-hover:scale-105 transition-transform duration-500" />
                <div className="relative flex items-center justify-center gap-2 text-xs font-black text-white uppercase tracking-[0.2em]">
                  {loading ? <Loader2 size={16} className="animate-spin" /> : <>Complete Verification <ArrowRight size={16} className="group-hover:translate-x-1 transition-transform" /></>}
                </div>
              </button>

              <div className="text-center">
                <button
                  type="button"
                  onClick={onResend}
                  disabled={resending || !email}
                  className="text-[10px] font-black text-zinc-500 hover:text-white uppercase tracking-widest transition-colors"
                >
                  {resending ? "Transmitting..." : "Didn't receive a code? Resend"}
                </button>
              </div>
            </form>
          </div>
        )}
      </AnimatePresence>
    </div>
  );
}

export default function EmailVerificationPage() {
  return (
    <div className="min-h-screen bg-zinc-950 font-sans selection:bg-indigo-500/30 overflow-hidden relative">
      {/* Background - Stabilized matching Admin Login style */}
      <div className="absolute inset-0 overflow-hidden pointer-events-none">
        <div className="absolute -top-24 left-1/2 h-[600px] w-[1000px] -translate-x-1/2 rounded-full bg-gradient-to-r from-indigo-600/30 via-fuchsia-600/20 to-cyan-500/20 blur-[120px] opacity-50" />
      </div>

      <div className="relative mx-auto flex min-h-screen max-w-7xl items-center justify-center px-6 py-16 z-10">
        <div className="w-full max-w-md">
          <Suspense fallback={
            <div className="rounded-[2rem] border border-white/10 bg-white/[0.03] p-12 text-center backdrop-blur-3xl">
              <div className="h-10 w-10 border-2 border-indigo-500/30 border-t-indigo-500 rounded-full animate-spin mx-auto" />
            </div>
          }>
            <VerifyEmailContent />
          </Suspense>

          <motion.div 
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ delay: 0.6 }}
            className="mt-8 text-center space-y-6"
          >
            <div className="flex items-center justify-center gap-6">
              <Link href="/signin" className="text-[10px] font-black text-zinc-500 hover:text-white uppercase tracking-widest transition-all group relative">
                Back to Identity
                <span className="absolute -bottom-1 left-0 w-0 h-[1px] bg-indigo-500 group-hover:w-full transition-all duration-300" />
              </Link>
              <div className="w-1 h-1 rounded-full bg-zinc-800" />
              <Link href="/" className="text-[10px] font-black text-zinc-500 hover:text-white uppercase tracking-widest transition-all group relative">
                Main Terminal
                <span className="absolute -bottom-1 left-0 w-0 h-[1px] bg-cyan-500 group-hover:w-full transition-all duration-300" />
              </Link>
            </div>
            
            <div className="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-white/[0.02] border border-white/5 text-[9px] text-zinc-600 font-bold uppercase tracking-[0.2em]">
              <ShieldCheck size={10} className="text-emerald-500/50" />
              Secure Validation Channel
            </div>
          </motion.div>
        </div>
      </div>
    </div>
  );
}
