"use client";

import { useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { motion, AnimatePresence } from "framer-motion";
import {
  Trophy, ChartLineUp, Pulse,
  Target, Sparkle, Crown, ArrowsClockwise,
  CheckCircle, WarningCircle, Monitor,
  Lightning, Flame, IdentificationCard
} from "@phosphor-icons/react";
import UserShell from "@/app/_components/UserShell";
import { apiFetch, ApiError } from "@/lib/api";
import { useAuthToken } from "@/lib/stores/authStore";
import Tilt from "react-parallax-tilt";
import { NeonChip } from "@/app/_components/Hud";

// Confetti Component for victory
const Confetti = () => (
  <div className="absolute inset-0 pointer-events-none overflow-hidden z-20">
    {Array.from({ length: 40 }).map((_, i) => (
      <motion.div
        key={i}
        initial={{
          top: "-10%",
          left: `${Math.random() * 100}%`,
          scale: Math.random() * 0.5 + 0.5,
          rotate: 0,
          opacity: 1
        }}
        animate={{
          top: "110%",
          rotate: 360 * (Math.random() > 0.5 ? 1 : -1),
          opacity: 0
        }}
        transition={{
          duration: Math.random() * 3 + 2,
          ease: "easeIn",
          delay: Math.random() * 2
        }}
        className={`absolute w-3 h-3 rounded-sm ${["bg-blue-400", "bg-cyan-400", "bg-cyan-400", "bg-yellow-400"][Math.floor(Math.random() * 4)]
          }`}
      />
    ))}
  </div>
);

// Neural Scanning Lines
const ScanningLine = () => (
  <motion.div
    animate={{ top: ["0%", "100%", "0%"] }}
    transition={{ duration: 4, repeat: Infinity, ease: "linear" }}
    className="absolute left-0 right-0 h-10 bg-gradient-to-b from-transparent via-blue-500/10 to-transparent pointer-events-none z-10"
  />
);

export default function GameQuizPage() {
  const router = useRouter();
  const { token } = useAuthToken();

  const [loading, setLoading] = useState(true);
  const [quizStarted, setQuizStarted] = useState(false);
  const [currentQuestion, setCurrentQuestion] = useState(0);
  const [score, setScore] = useState(0);
  const [streak, setStreak] = useState(0);
  const [maxStreak, setMaxStreak] = useState(0);
  const [completed, setCompleted] = useState(false);
  const [feedback, setFeedback] = useState<"correct" | "incorrect" | null>(null);
  const [selectedIdx, setSelectedIdx] = useState<number | null>(null);

  const questions = [
    {
      q: "What is the primary coordinate system used in 2D game development?",
      options: ["Cartesian", "Polar", "Spherical", "Geographic"],
      a: 0,
      icon: "📐"
    },
    {
      q: "Which AI model is best suited for complex game logic generation?",
      options: ["GPT-3.5", "GPT-4", "Claude-3.5", "Gemini 1.5 Pro"],
      a: 2,
      icon: "🤖"
    },
    {
      q: "What does 'Delta Time' represent in game loops?",
      options: ["Total Game Time", "Time between frames", "Frames per minute", "CPU clock speed"],
      a: 1,
      icon: "⏱️"
    }
  ];

  useEffect(() => {
    const t = setTimeout(() => setLoading(false), 1200);
    return () => clearTimeout(t);
  }, []);

  function handleAnswer(index: number) {
    if (feedback) return;

    setSelectedIdx(index);
    const isCorrect = index === questions[currentQuestion].a;

    if (isCorrect) {
      const newScore = score + 1;
      const newStreak = streak + 1;
      setScore(newScore);
      setStreak(newStreak);
      if (newStreak > maxStreak) setMaxStreak(newStreak);
      setFeedback("correct");
    } else {
      setStreak(0);
      setFeedback("incorrect");
    }

    setTimeout(() => {
      setFeedback(null);
      setSelectedIdx(null);
      if (currentQuestion < questions.length - 1) {
        setCurrentQuestion(prev => prev + 1);
      } else {
        setCompleted(true);
      }
    }, 1200);
  }

  const accuracy = Math.round((score / questions.length) * 100);

  return (
    <UserShell title="Neural Challenge" subtitle="Synchronize your knowledge & earn rewards">
      <div className="max-w-4xl mx-auto pb-20 relative px-4">

        <AnimatePresence mode="wait">
          {loading ? (
            <motion.div
              key="loader"
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              className="gf-card rounded-[3rem] p-24 text-center relative overflow-hidden backdrop-blur-3xl border border-white/5"
            >
              <ScanningLine />
              <motion.div
                animate={{ rotate: 360, scale: [1, 1.1, 1] }}
                transition={{
                  rotate: { duration: 3, repeat: Infinity, ease: "linear" },
                  scale: { duration: 2, repeat: Infinity, ease: "easeInOut" }
                }}
                className="h-24 w-24 border-b-4 border-blue-500 rounded-full mx-auto relative shadow-[0_0_40px_rgba(99,102,241,0.4)]"
              >
                <div className="absolute inset-0 flex items-center justify-center">
                  <Monitor size={32} weight="duotone" className="text-blue-400 animate-pulse" />
                </div>
              </motion.div>
              <h2 className="mt-12 text-2xl font-black text-white italic uppercase tracking-[0.3em]">Calibrating Neural Link...</h2>
              <p className="text-zinc-600 mt-4 font-mono text-xs uppercase tracking-widest">establishing secure bridge / mapping knowledge trees</p>
              <div className="absolute inset-0 bg-gradient-to-b from-blue-500/[0.03] to-transparent pointer-events-none" />
            </motion.div>
          ) : !quizStarted ? (
            <motion.div
              key="start"
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -30 }}
              className="relative space-y-6"
            >
              {/* Top hero strip */}
              <Tilt perspective={1500} tiltMaxAngleX={3} tiltMaxAngleY={3}>
                <div className="gf-card rounded-[3rem] p-12 text-center relative overflow-hidden bg-white/[0.02] border border-white/10 group">
                  <div className="absolute inset-0 bg-gradient-to-br from-blue-500/[0.08] via-transparent to-cyan-500/[0.06] pointer-events-none" />
                  <div className="absolute top-0 left-0 right-0 h-[1px] bg-gradient-to-r from-transparent via-blue-500/60 to-transparent" />
                  <ScanningLine />

                  <motion.div initial={{ y: 20, opacity: 0 }} animate={{ y: 0, opacity: 1 }} transition={{ delay: 0.2 }} className="relative z-10">
                    {/* Icon */}
                    <div className="relative w-24 h-24 mx-auto mb-8">
                      <motion.div animate={{ scale: [1, 1.3, 1], opacity: [0.3, 0.7, 0.3] }} transition={{ duration: 3, repeat: Infinity }}
                        className="absolute inset-0 bg-cyan-500/25 blur-[50px] rounded-full" />
                      <div className="relative h-full w-full rounded-[28px] bg-black/40 border border-white/10 flex items-center justify-center shadow-2xl backdrop-blur-3xl group-hover:scale-105 transition-transform duration-500">
                        <Lightning size={48} weight="duotone" className="text-cyan-400" />
                      </div>
                    </div>

                    <div className="inline-flex items-center gap-2 mb-4 px-4 py-1.5 rounded-full border border-cyan-500/30 bg-cyan-500/10">
                      <Sparkle size={12} weight="fill" className="text-cyan-400" />
                      <span className="text-[10px] font-black uppercase tracking-[0.3em] text-cyan-300">Knowledge Protocol</span>
                    </div>
                    <h2 className="text-4xl font-black text-white italic uppercase tracking-tighter mb-4 leading-none">Neural Challenge <span className="text-cyan-400">Active</span></h2>
                    <p className="text-zinc-500 font-medium mb-8 max-w-md mx-auto leading-relaxed">
                      Prove mastery across <span className="text-white font-bold">{questions.length} neural nodes</span> to earn <span className="text-cyan-400 font-black">Studio Credits</span>.
                    </p>

                    {/* Stats row */}
                    <div className="flex items-center justify-center gap-8 mb-8 py-4 border-y border-white/[0.05]">
                      <div className="text-center">
                        <div className="text-2xl font-black text-white italic">{questions.length}</div>
                        <div className="text-[9px] font-black text-zinc-600 uppercase tracking-widest mt-0.5">Questions</div>
                      </div>
                      <div className="h-8 w-[1px] bg-white/10" />
                      <div className="text-center">
                        <div className="text-2xl font-black text-cyan-400 italic">+{questions.length * 15}</div>
                        <div className="text-[9px] font-black text-zinc-600 uppercase tracking-widest mt-0.5">Max Credits</div>
                      </div>
                      <div className="h-8 w-[1px] bg-white/10" />
                      <div className="text-center">
                        <div className="text-2xl font-black text-blue-400 italic">3</div>
                        <div className="text-[9px] font-black text-zinc-600 uppercase tracking-widest mt-0.5">Categories</div>
                      </div>
                    </div>

                    <button
                      className="group relative w-full max-w-xs mx-auto overflow-hidden rounded-[2rem] bg-gradient-to-r from-blue-600 to-cyan-600 text-white py-5 font-black uppercase tracking-[0.2em] transition-all hover:scale-[1.03] active:scale-[0.98] shadow-[0_20px_50px_rgba(99,102,241,0.35)]"
                      onClick={() => setQuizStarted(true)}
                    >
                      <span className="relative z-10 flex items-center justify-center gap-3">
                        Sync Protocol <Lightning size={20} weight="fill" className="animate-pulse" />
                      </span>
                      <motion.div animate={{ x: ["-100%", "200%"] }} transition={{ duration: 3, repeat: Infinity, ease: "linear" }}
                        className="absolute inset-0 bg-gradient-to-r from-transparent via-white/20 to-transparent skew-x-12" />
                    </button>
                  </motion.div>
                </div>
              </Tilt>

              {/* Category cards row */}
              <div className="grid grid-cols-3 gap-4">
                {[
                  { label: "Game Design", icon: "🎮", color: "from-blue-500/20 to-blue-500/5 border-blue-500/25 text-blue-400" },
                  { label: "AI & Neural", icon: "🤖", color: "from-cyan-500/20 to-cyan-500/5 border-cyan-500/25 text-cyan-400" },
                  { label: "Dev Mastery", icon: "⚡", color: "from-cyan-500/20 to-cyan-500/5 border-cyan-500/25 text-cyan-400" },
                ].map((cat, i) => (
                  <motion.div
                    key={cat.label}
                    initial={{ opacity: 0, y: 15 }}
                    animate={{ opacity: 1, y: 0 }}
                    transition={{ delay: 0.3 + i * 0.08 }}
                    className={`group rounded-[24px] p-5 bg-gradient-to-br border text-center cursor-pointer hover:scale-[1.03] transition-all ${cat.color}`}
                  >
                    <div className="text-3xl mb-2">{cat.icon}</div>
                    <div className={`text-[11px] font-black uppercase tracking-[0.2em] ${cat.color.split(' ').at(-1)}`}>{cat.label}</div>
                  </motion.div>
                ))}
              </div>

              {/* Leaderboard teaser */}
              <div className="rounded-[28px] border border-white/[0.06] bg-white/[0.02] overflow-hidden">
                <div className="flex items-center justify-between px-6 py-4 border-b border-white/[0.05]">
                  <div className="flex items-center gap-3">
                    <Trophy size={16} weight="duotone" className="text-amber-400" />
                    <span className="text-xs font-black uppercase tracking-[0.2em] text-white">Top Protocol Syncs</span>
                  </div>
                  <span className="text-[9px] font-black text-zinc-600 uppercase tracking-widest">GLOBAL</span>
                </div>
                {[{ name: "neural_forge", score: 285, rank: 1 }, { name: "xdev_pro", score: 210, rank: 2 }, { name: "arc_builder", score: 180, rank: 3 }].map((leader) => (
                  <div key={leader.rank} className="flex items-center justify-between px-6 py-3 border-b border-white/[0.03] last:border-none">
                    <div className="flex items-center gap-3">
                      <div className={`h-6 w-6 rounded-full flex items-center justify-center text-[10px] font-black ${
                        leader.rank === 1 ? 'bg-amber-500/20 text-amber-400' : leader.rank === 2 ? 'bg-zinc-500/20 text-zinc-300' : 'bg-orange-500/20 text-orange-400'
                      }`}>#{leader.rank}</div>
                      <span className="text-sm font-bold text-zinc-300">{leader.name}</span>
                    </div>
                    <span className="text-sm font-black text-blue-400">{leader.score} pts</span>
                  </div>
                ))}
              </div>
            </motion.div>
          ) : completed ? (
            <motion.div
              key="victory"
              initial={{ opacity: 0, scale: 0.9 }}
              animate={{ opacity: 1, scale: 1 }}
              className="gf-card rounded-[3.5rem] p-16 text-center relative overflow-hidden backdrop-blur-3xl border border-white/10 shadow-[0_40px_120px_rgba(0,0,0,0.8)]"
            >
              <Confetti />
              <div className="absolute inset-0 bg-gradient-to-br from-emerald-500/[0.05] via-transparent to-teal-500/[0.05] pointer-events-none" />

              <motion.div
                initial={{ rotate: -15, scale: 0 }}
                animate={{ rotate: 0, scale: 1.1 }}
                transition={{ type: "spring", stiffness: 100, damping: 10, delay: 0.3 }}
                className="relative w-40 h-40 mx-auto mb-12"
              >
                <motion.div
                  animate={{ scale: [1, 1.3, 1], opacity: [0.4, 0.8, 0.4] }}
                  transition={{ duration: 2, repeat: Infinity }}
                  className="absolute inset-0 bg-emerald-500/30 blur-[80px] rounded-full"
                />
                <div className="relative h-full w-full rounded-[48px] bg-black/40 border border-emerald-500/20 flex items-center justify-center shadow-2xl backdrop-blur-2xl">
                  <Crown size={80} weight="duotone" className="text-emerald-400" />
                </div>
              </motion.div>

              <h2 className="text-5xl font-black text-white italic uppercase tracking-tighter mb-6 leading-tight">Neural Master <span className="text-emerald-500">Verified</span></h2>

              <div className="flex justify-center gap-8 mb-12">
                <div className="bg-white/5 border border-white/10 px-8 py-5 rounded-3xl">
                  <div className="text-[10px] font-black text-zinc-600 uppercase tracking-widest mb-1">Final Accuracy</div>
                  <div className="text-3xl font-black text-white italic">{accuracy}%</div>
                </div>
                <div className="bg-white/5 border border-white/10 px-8 py-5 rounded-3xl">
                  <div className="text-[10px] font-black text-zinc-600 uppercase tracking-widest mb-1">Max Streak</div>
                  <div className="text-3xl font-black text-emerald-400 italic">x{maxStreak}</div>
                </div>
              </div>

              <motion.div
                initial={{ y: 20, opacity: 0 }}
                animate={{ y: 0, opacity: 1 }}
                transition={{ delay: 0.8 }}
                className="p-8 rounded-[3rem] bg-emerald-500/10 border border-emerald-500/20 relative overflow-hidden group mb-10"
              >
                <div className="relative z-10 flex items-center justify-center gap-5 text-emerald-400 text-2xl font-black italic">
                  <ChartLineUp size={32} weight="bold" />
                  +{score * 15} STUDIO CREDITS SECURED
                </div>
                <motion.div
                  animate={{ x: ["-100%", "200%"] }}
                  transition={{ duration: 4, repeat: Infinity, ease: "linear" }}
                  className="absolute inset-0 bg-emerald-500/10 blur-3xl"
                />
              </motion.div>

              <button
                className="w-full max-sm mx-auto gf-btn rounded-[2.5rem] py-6 font-black uppercase tracking-[0.25em] text-white hover:bg-white/10 transition-all border border-white/10 flex items-center justify-center gap-3 group"
                onClick={() => {
                  setQuizStarted(false);
                  setCompleted(false);
                  setCurrentQuestion(0);
                  setScore(0);
                  setStreak(0);
                  setMaxStreak(0);
                }}
              >
                <ArrowsClockwise size={20} weight="bold" className="group-hover:rotate-180 transition-transform duration-700" />
                Resync Experience
              </button>
            </motion.div>
          ) : (
            <motion.div
              key="quiz"
              initial={{ opacity: 0, x: 50 }}
              animate={{ opacity: 1, x: 0 }}
              className="space-y-10"
            >
              <div className="flex flex-col md:flex-row md:items-end justify-between gap-6 border-b border-white/[0.05] pb-8">
                <div className="space-y-4 flex-1">
                  <div className="flex gap-2">
                    <NeonChip tone="cyan">
                      <Pulse size={14} weight="bold" className="animate-pulse" />
                      NODE {currentQuestion + 1} / {questions.length}
                    </NeonChip>
                    {streak > 1 && (
                      <motion.div
                        initial={{ scale: 0.5, opacity: 0 }}
                        animate={{ scale: 1, opacity: 1 }}
                        className="bg-amber-500/20 text-amber-400 px-3 py-1 rounded-full text-[10px] font-black tracking-widest flex items-center gap-1 shadow-[0_0_15px_rgba(245,158,11,0.3)] border border-amber-500/30"
                      >
                        <Flame size={12} weight="fill" />
                        {streak}X STREAK
                      </motion.div>
                    )}
                  </div>
                  <h3 className="text-3xl md:text-4xl font-black text-white italic uppercase tracking-tight leading-[1.1] max-w-2xl drop-shadow-2xl">
                    {questions[currentQuestion].q}
                  </h3>
                </div>
                <div className="flex items-center gap-6 md:text-right">
                  <div>
                    <div className="text-[10px] font-black text-zinc-600 uppercase tracking-[0.2em] mb-1">Precision</div>
                    <div className="text-3xl font-black text-white italic">{accuracy}%</div>
                  </div>
                  <div className="h-10 w-[1px] bg-white/10 hidden md:block" />
                  <div>
                    <div className="text-[10px] font-black text-zinc-600 uppercase tracking-[0.2em] mb-1">Sync Level</div>
                    <div className="text-3xl font-black text-blue-400 italic">+{score * 15}</div>
                  </div>
                </div>
              </div>

              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <AnimatePresence mode="popLayout">
                  {questions[currentQuestion].options.map((opt, i) => (
                    <Tilt
                      key={`${currentQuestion}-${i}`}
                      perspective={1500}
                      tiltMaxAngleX={3}
                      tiltMaxAngleY={3}
                      className="relative"
                    >
                      <motion.button
                        initial={{ opacity: 0, y: 10 }}
                        animate={{ opacity: 1, y: 0 }}
                        transition={{ delay: i * 0.08 }}
                        whileTap={{ scale: 0.98 }}
                        disabled={!!feedback}
                        className={`w-full gf-card group flex items-center justify-between p-7 rounded-[2.5rem] border transition-all duration-500 text-left relative overflow-hidden h-full ${feedback && questions[currentQuestion].a === i
                            ? 'border-emerald-500/50 bg-emerald-500/10'
                            : feedback && selectedIdx === i
                              ? 'border-rose-500/50 bg-rose-500/10'
                              : 'border-white/5 hover:border-blue-500/40 hover:bg-[#13131c]'
                          }`}
                        onClick={() => handleAnswer(i)}
                      >
                        <div className="flex items-center gap-6 relative z-10">
                          <div className="h-14 w-14 rounded-2xl bg-white/5 border border-white/10 flex items-center justify-center text-zinc-500 group-hover:text-blue-400 group-hover:border-blue-500/30 group-hover:bg-blue-500/10 transition-all font-black text-xl italic shadow-inner">
                            {String.fromCharCode(65 + i)}
                          </div>
                          <span className="text-lg font-bold text-zinc-400 group-hover:text-white transition-colors tracking-tight leading-tight">{opt}</span>
                        </div>

                        <div className="h-10 w-10 rounded-full border border-white/10 flex items-center justify-center group-hover:border-blue-500/50 transition-all relative z-10 shrink-0">
                          <div className="h-4 w-4 rounded-full bg-blue-500 opacity-0 group-hover:opacity-100 transition-all scale-50 group-hover:scale-100 shadow-[0_0_20px_rgba(99,102,241,0.8)]" />
                        </div>

                        {/* Background Glow */}
                        <div className={`absolute inset-0 bg-gradient-to-r from-blue-500/10 to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-700`} />
                      </motion.button>
                    </Tilt>
                  ))}
                </AnimatePresence>
              </div>

              <div className="pt-10 flex flex-col gap-4">
                <div className="h-2 w-full bg-white/5 rounded-full overflow-hidden border border-white/5 p-[2px] relative">
                  <div className="absolute inset-0 bg-blue-500/[0.02] blur-sm" />
                  <motion.div
                    className="h-full bg-gradient-to-r from-blue-500 via-cyan-500 to-blue-500 bg-[length:200%_100%] rounded-full shadow-[0_0_30px_rgba(99,102,241,0.5)] relative z-10"
                    initial={{ width: 0 }}
                    animate={{
                      width: `${((currentQuestion) / questions.length) * 100}%`,
                      backgroundPosition: ["0% 50%", "100% 50%", "0% 50%"]
                    }}
                    transition={{
                      width: { duration: 1.2, ease: [0.22, 1, 0.36, 1] },
                      backgroundPosition: { duration: 4, repeat: Infinity, ease: "linear" }
                    }}
                  />
                </div>
              </div>

              {/* Feedback Overlay */}
              <AnimatePresence>
                {feedback && (
                  <motion.div
                    initial={{ opacity: 0, scale: 1.2, y: 20 }}
                    animate={{ opacity: 1, scale: 1, y: 0 }}
                    exit={{ opacity: 0, scale: 0.8 }}
                    className="fixed inset-0 pointer-events-none flex items-center justify-center z-50 px-8"
                  >
                    <div className={`rounded-full px-12 py-6 border backdrop-blur-2xl shadow-[0_30px_100px_rgba(0,0,0,0.8)] flex items-center gap-6 ${feedback === 'correct' ? 'border-emerald-500/50 bg-emerald-500/20 text-emerald-400' : 'border-rose-500/50 bg-rose-500/20 text-rose-400'
                      }`}>
                      {feedback === 'correct' ? (
                        <>
                          <CheckCircle size={64} weight="duotone" className="drop-shadow-[0_0_20px_rgba(16,185,129,0.5)]" />
                          <div className="text-left leading-none">
                            <div className="text-[14px] font-black uppercase tracking-widest mb-1 opacity-60">Recognition Success</div>
                            <div className="text-4xl font-black italic uppercase tracking-tighter">Perfect Sync</div>
                          </div>
                        </>
                      ) : (
                        <>
                          <WarningCircle size={64} weight="duotone" className="drop-shadow-[0_0_20px_rgba(244,63,94,0.5)]" />
                          <div className="text-left leading-none">
                            <div className="text-[14px] font-black uppercase tracking-widest mb-1 opacity-60">System Malfunction</div>
                            <div className="text-4xl font-black italic uppercase tracking-tighter">Drift Detected</div>
                          </div>
                        </>
                      )}
                    </div>
                  </motion.div>
                )}
              </AnimatePresence>
            </motion.div>
          )}
        </AnimatePresence>
      </div>
    </UserShell>
  );
}

