"use client";

import { useRouter } from "next/navigation";
import UserShell from "@/app/_components/UserShell";
import { ShieldCheck, FlaskConical, CalendarClock, BrainCircuit, Link2, ArrowRight, WandSparkles, Trophy } from "lucide-react";
import { buildModuleHref, useLabsContext } from "./_lib/useLabsContext";
import { ContextMediaCard, WowHero } from "./_components/WowVisual";

const MODULES = [
  {
    title: "Smart Match v2",
    subtitle: "Intent classifier + hard rerank + explanation chips",
    href: "/studio/wow-labs/smart-match",
    icon: BrainCircuit,
    tone: "from-blue-500/20 to-blue-500/5 border-blue-400/30",
  },
  {
    title: "AI Playtest Bot",
    subtitle: "Simulated QA runs + fix suggestions before release",
    href: "/studio/wow-labs/playtest",
    icon: FlaskConical,
    tone: "from-emerald-500/20 to-emerald-500/5 border-emerald-400/30",
  },
  {
    title: "Arcade Tournaments",
    subtitle: "Real-time leaderboards, prize pools, and arcade play",
    href: "/studio/wow-labs/tournaments",
    icon: Trophy,
    tone: "from-yellow-500/20 to-yellow-500/5 border-yellow-400/30",
  },
  {
    title: "Live Ops Engine",
    subtitle: "Daily/weekly missions, seasonal events, battle pass lite",
    href: "/studio/wow-labs/live-ops",
    icon: CalendarClock,
    tone: "from-cyan-500/20 to-cyan-500/5 border-cyan-400/30",
  },
  {
    title: "UGC Moderation AI",
    subtitle: "Trust score + quarantine + appeal workflow",
    href: "/studio/wow-labs/ugc-moderation",
    icon: ShieldCheck,
    tone: "from-cyan-500/20 to-cyan-500/5 border-cyan-400/30",
  },
];

export default function WowLabsHubPage() {
  const router = useRouter();
  const {
    loading,
    templates,
    selectedTemplateId,
    selectedTemplate,
    setSelectedTemplateId,
  } = useLabsContext({ withProjects: false, withTemplates: true });

  return (
    <UserShell title="Wow Labs Modules" subtitle="Template-first flow, all modules connected">
      <WowHero
        badge="Unified Context Dock"
        title="Choose Real Template"
        subtitle="Everything here is connected to your real template catalog. Pick once, then launch any lab module with synchronized context and rich visuals."
        tone="blue"
        mediaUrl={selectedTemplate?.previewImageUrl}
      >
        <div className="grid grid-cols-1 gap-3">
          <div className="rounded-2xl border border-white/10 bg-black/25 p-3">
            <div className="flex items-center gap-2 text-[10px] uppercase tracking-[0.2em] text-zinc-300 font-black">
              <WandSparkles size={12} /> Selected Template
            </div>
            <select
              value={selectedTemplateId}
              onChange={(e) => setSelectedTemplateId(e.target.value)}
              className="gf-input mt-2 w-full rounded-xl p-2.5 text-sm"
              disabled={loading}
            >
              {templates.length === 0 ? <option value="">No templates found</option> : null}
              {templates.map((t) => (
                <option key={t.id} value={t.id}>
                  {t.name}
                </option>
              ))}
            </select>
            <div className="mt-2 text-xs text-zinc-300">
              {selectedTemplate?.category
                ? `${selectedTemplate.category} • ${selectedTemplate.tags.slice(0, 3).join(" / ")}`
                : "Pick a real template to feed smart-match with your live catalog."}
            </div>
          </div>
        </div>
      </WowHero>

      <div className="mt-5 grid grid-cols-1 gap-4">
        <ContextMediaCard
          label="Active Template"
          name={selectedTemplate?.name || "No template selected"}
          description={selectedTemplate?.description}
          meta={selectedTemplate?.category ? `${selectedTemplate.category} • ${(selectedTemplate.tags || []).slice(0, 3).join(" • ")}` : "Used by Smart Match v2"}
          mediaUrl={selectedTemplate?.previewImageUrl}
        />
      </div>

      <div className="mt-6 grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-5">
        {MODULES.map((m) => {
          const Icon = m.icon;
          const cardMedia = selectedTemplate?.previewImageUrl;
          return (
            <button
              key={m.title}
              onClick={() => router.push(buildModuleHref(m.href, undefined, selectedTemplateId || undefined))}
              className={`group relative overflow-hidden text-left rounded-3xl border bg-gradient-to-br ${m.tone} p-5 transition-all hover:-translate-y-1 hover:shadow-[0_20px_45px_rgba(0,0,0,0.45)]`}
            >
              {cardMedia ? (
                <div className="pointer-events-none absolute inset-0 opacity-0 transition-opacity duration-300 group-hover:opacity-100">
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  <img src={cardMedia} alt="" className="h-full w-full object-cover" />
                  <div className="absolute inset-0 bg-black/65" />
                </div>
              ) : null}
              <div className="h-10 w-10 rounded-xl border border-white/15 bg-white/10 flex items-center justify-center text-white">
                <Icon size={18} />
              </div>
              <div className="relative mt-4 text-lg font-black text-white uppercase italic tracking-tight">{m.title}</div>
              <div className="relative mt-2 text-sm text-zinc-300">{m.subtitle}</div>
              <div className="relative mt-4 flex items-center justify-between text-[10px] uppercase tracking-[0.24em] text-zinc-400 font-black">
                <span className="flex items-center gap-1"><Link2 size={12} /> Connected</span>
                <span className="flex items-center gap-1 text-blue-200">Launch <ArrowRight size={12} /></span>
              </div>
            </button>
          );
        })}
      </div>
    </UserShell>
  );
}
