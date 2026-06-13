"use client";

import { motion } from "framer-motion";
import AdminShell from "@/app/_components/AdminShell";
import {
  Handshake,
  Lightbulb,
  Target,
  Users,
  ArrowSquareOut,
  CurrencyDollar,
  Scales,
  Package,
  Broadcast,
  Robot,
  GameController,
  Star,
  Code,
  Trophy,
  Buildings,
  ArrowDown,
  ArrowRight,
  Download,
} from "@phosphor-icons/react";

// ─────────────────────────────────────────────────────────────
//  BMC DATA — Corrected & Complete for GameForge AI
// ─────────────────────────────────────────────────────────────

const BMC_META = {
  designedFor: "Startups, Studios Indépendants, Créateurs Gaming",
  designedBy: "Équipe GameForge AI",
  date: "Avril 2026",
  version: "v2.0",
};

const PARTNERS = {
  title: "Partenaires Stratégiques",
  icon: Handshake,
  color: "#8b5cf6",
  groups: [
    {
      label: "🤖 Fournisseurs IA",
      items: [
        "Anthropic (Claude) — Génération de code jeu",
        "OpenAI — Assets visuels & sprites",
        "ElevenLabs — Voix-off & audio IA",
      ],
    },
    {
      label: "🎮 Moteurs & Frameworks",
      items: [
        "Unity / WebGL — Runtime jeux",
        "Phaser.js — Jeux 2D browser",
        "Three.js — Jeux 3D web",
      ],
    },
    {
      label: "☁️ Infrastructure",
      items: [
        "AWS S3 — Stockage builds & assets",
        "Cloudinary — CDN médias & transformations",
        "Firebase — Push notifications & analytics",
      ],
    },
    {
      label: "💳 Monétisation",
      items: [
        "Stripe — Paiements & abonnements",
        "Polygon/Amoy — NFTs ERC1155 (récompenses)",
        "LiveKit — Streaming WebRTC live",
      ],
    },
    {
      label: "🤝 Écosystème",
      items: [
        "Créateurs tiers — Templates marketplace",
        "Bootcamps & Écoles — Partenariats academy",
        "App Store / Google Play — Distribution mobile",
      ],
    },
  ],
};

const KEY_ACTIVITIES = {
  title: "Activités Clés",
  icon: Target,
  color: "#0ea5e9",
  items: [
    {
      icon: "🤖",
      label: "Orchestration IA multi-moteurs",
      desc: "Claude, Phaser, Three.js, Scratch generators",
    },
    {
      icon: "🎮",
      label: "Développement & évolution produit",
      desc: "App Flutter + Backend NestJS + Admin Web Next.js",
    },
    {
      icon: "🏪",
      label: "Gestion de l'écosystème marketplace",
      desc: "Templates, assets, monétisation créateurs",
    },
    {
      icon: "🎯",
      label: "Acquisition utilisateurs & marketing",
      desc: "TikTok, Discord, YouTube, LinkedIn",
    },
    {
      icon: "🌐",
      label: "Opérations multijoueur & live",
      desc: "Rooms Socket.io, WebRTC streaming, tournois",
    },
    {
      icon: "🛡️",
      label: "Support client & communauté",
      desc: "24/7 AI coach, onboarding guidé, forum",
    },
  ],
};

const VALUE_PROPS = {
  title: "Propositions de Valeur",
  icon: Star,
  color: "#f59e0b",
  items: [
    {
      icon: "⚡",
      label: "Jeu jouable en < 3 minutes",
      desc: "De l'idée au WebGL build, sans coder",
    },
    {
      icon: "🎭",
      label: "Plateforme tout-en-un",
      desc: "IA + no-code + marketplace + monétisation",
    },
    {
      icon: "📱",
      label: "Export multi-plateforme",
      desc: "WebGL, Android, iOS, Windows, macOS",
    },
    {
      icon: "💰",
      label: "Monétiser son jeu facilement",
      desc: "Ads in-game, NFT rewards, creator revenue share",
    },
    {
      icon: "🏆",
      label: "Compétition & tournois",
      desc: "Engagement via classements, challenges, events globaux",
    },
    {
      icon: "🎓",
      label: "Apprendre en créant",
      desc: "AI coach, parcours guidés, certifications",
    },
  ],
};

const CUSTOMER_RELATIONS = {
  title: "Relation Clients",
  icon: Users,
  color: "#ec4899",
  items: [
    "🚀 Onboarding guidé & self-service",
    "🤖 AI Coach 24/7 (assistance in-app)",
    "💬 Communauté Discord / Forum actif",
    "⭐ Support Freemium → Premium (SLA)",
    "📊 Analytics créateur personnalisés",
    "🎁 Daily rewards & système de fidélité",
    "📧 Email marketing contextualisé",
  ],
};

const CHANNELS = {
  title: "Canaux de Distribution",
  icon: Broadcast,
  color: "#10b981",
  items: [
    { icon: "📱", label: "App Store / Google Play", desc: "App mobile Flutter" },
    { icon: "🌐", label: "Web Studio", desc: "gameforge.studio (Next.js)" },
    { icon: "🎵", label: "TikTok / YouTube", desc: "Jeux générés viraux" },
    { icon: "💬", label: "Discord / Reddit", desc: "Communauté gaming" },
    { icon: "🎓", label: "LinkedIn & Bootcamps", desc: "Segment pro & éducation" },
    { icon: "🔗", label: "Referral program", desc: "Créateurs qui invitent" },
  ],
};

const SEGMENTS = {
  title: "Segments de Clientèle",
  icon: Package,
  color: "#6366f1",
  groups: [
    {
      label: "🎮 Créateurs Indépendants (18–35 ans)",
      desc: "Passionnés de gaming, veulent créer sans coder",
      need: "Rapidité, no-code, publication facile",
    },
    {
      label: "🎓 Étudiants & Débutants (16–25 ans)",
      desc: "Apprennent le dev jeu, budget limité",
      need: "Apprentissage par la pratique, certification",
    },
    {
      label: "🏢 Petits Studios & Bootcamps",
      desc: "Prototypage rapide, R&D agile",
      need: "Collaboration, API, branding custom",
    },
    {
      label: "📹 Streamers & Créateurs de Contenu",
      desc: "Monétisent leur audience gaming",
      need: "Intégration streaming, clips viraux, NFTs",
    },
  ],
};

const KEY_RESOURCES = {
  title: "Ressources Clés",
  icon: Robot,
  color: "#f97316",
  groups: [
    {
      label: "🧠 Intellectuelles",
      items: [
        "Algorithmes IA propriétaires (orchestration)",
        "Bibliothèque de 300+ templates de jeux",
        "Données utilisateurs — amélioration IA continue",
      ],
    },
    {
      label: "💻 Technologiques",
      items: [
        "Backend NestJS (34 modules)",
        "App Flutter multi-plateforme",
        "Smart contracts ERC1155 (Polygon)",
      ],
    },
    {
      label: "👥 Humaines",
      items: [
        "Équipe ingénierie (Flutter, NestJS, IA)",
        "Créateurs de templates tiers (marketplace)",
        "Community managers & support",
      ],
    },
    {
      label: "☁️ Physiques",
      items: [
        "Infrastructure cloud AWS / Cloudinary",
        "Serveurs LiveKit (streaming WebRTC)",
        "Nœuds blockchain (Polygon Amoy)",
      ],
    },
  ],
};

const COST_STRUCTURE = {
  title: "Structure des Coûts",
  icon: Scales,
  color: "#ef4444",
  fixed: [
    "💼 Équipe ingénierie (Flutter/NestJS/IA) — salaires",
    "🌐 Hébergement cloud (AWS, Cloudinary) — abonnement",
    "🔑 Licences APIs (Anthropic, LiveKit, Stripe)",
    "📣 Marketing & acquisition utilisateurs",
    "🛡️ Conformité légale & sécurité (RGPD, audits)",
  ],
  variable: [
    "🤖 Inférence IA (tokens Claude — scale avec usage)",
    "☁️ Cloud compute + stockage (builds WebGL)",
    "📶 Bande passante (streaming live, CDN)",
    "💳 Commissions App Store / Google Play (15–30%)",
    "🔗 Frais gas blockchain (mint NFTs ERC1155)",
  ],
};

const REVENUE_STREAMS = {
  title: "Sources de Revenus",
  icon: CurrencyDollar,
  color: "#22c55e",
  recurring: [
    { label: "🆓 Starter — Free", desc: "3 projets, 10 builds/mois, WebGL only" },
    { label: "⚡ Creator — $19/mois", desc: "Projets illimités, 100 builds, 5 plateformes" },
    { label: "🏢 Studio — $49/mois", desc: "Team workspace, API, branding custom, SLA" },
    { label: "🎓 Academy — $29/mois", desc: "Formations + certifications NFT (prévu)" },
  ],
  transactional: [
    { label: "🎨 Templates Premium", desc: "Achat one-shot marketplace ($3–$29/template)" },
    { label: "🤖 Crédits IA Supplémentaires", desc: "Pack 500 crédits / génération ($9–$49)" },
    { label: "🎬 Export Trailers IA", desc: "Génération bande-annonce vidéo ($4.99)" },
    { label: "💎 NFT Cosmetics", desc: "Commission 15% sur NFTs publiés par créateurs" },
    { label: "📺 Ads in-game", desc: "Revenue share 70/30 avec créateurs (prévu)" },
  ],
};

// ─────────────────────────────────────────────────────────────
//  COMPONENTS
// ─────────────────────────────────────────────────────────────

function BMCCard({
  title,
  icon: Icon,
  color,
  children,
  className = "",
  delay = 0,
}: {
  title: string;
  icon: any;
  color: string;
  children: React.ReactNode;
  className?: string;
  delay?: number;
}) {
  return (
    <motion.div
      initial={{ opacity: 0, y: 16 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ delay, duration: 0.4, ease: [0.16, 1, 0.3, 1] }}
      className={`relative rounded-2xl border border-white/[0.08] bg-white/[0.03] backdrop-blur-sm overflow-hidden flex flex-col ${className}`}
      style={{ boxShadow: `0 0 0 1px ${color}15, inset 0 1px 0 rgba(255,255,255,0.04)` }}
    >
      {/* Top accent */}
      <div className="h-0.5 w-full" style={{ background: `linear-gradient(90deg, ${color}80, transparent)` }} />

      {/* Header */}
      <div className="flex items-center gap-2.5 px-4 pt-3.5 pb-3 border-b border-white/[0.05]">
        <div
          className="h-7 w-7 rounded-lg flex items-center justify-center shrink-0"
          style={{ backgroundColor: `${color}18`, border: `1px solid ${color}30` }}
        >
          <Icon size={14} weight="duotone" style={{ color }} />
        </div>
        <span className="text-[11px] font-black uppercase tracking-[0.2em]" style={{ color }}>
          {title}
        </span>
      </div>

      {/* Content */}
      <div className="flex-1 px-4 py-3 overflow-y-auto gf-scrollbar">
        {children}
      </div>
    </motion.div>
  );
}

function Pill({ text, color }: { text: string; color: string }) {
  return (
    <span
      className="inline-block px-2 py-0.5 rounded-md text-[10px] font-bold mr-1 mb-1"
      style={{ backgroundColor: `${color}15`, color, border: `1px solid ${color}25` }}
    >
      {text}
    </span>
  );
}

function BulletList({ items, color }: { items: string[]; color: string }) {
  return (
    <ul className="space-y-1.5">
      {items.map((item, i) => (
        <li key={i} className="flex items-start gap-2 text-[12px] text-zinc-300 leading-snug">
          <span className="mt-0.5 h-1.5 w-1.5 rounded-full shrink-0 mt-1.5" style={{ backgroundColor: color }} />
          {item}
        </li>
      ))}
    </ul>
  );
}

// ─────────────────────────────────────────────────────────────
//  PAGE
// ─────────────────────────────────────────────────────────────

export default function BusinessModelPage() {
  return (
    <AdminShell
      title="Business Model Canvas"
      subtitle="Strategic Overview"
      right={
        <button
          onClick={() => window.print()}
          className="flex items-center gap-2 px-4 py-2 rounded-xl bg-white/[0.05] border border-white/[0.08] text-sm font-bold text-zinc-300 hover:bg-white/[0.08] transition-all"
        >
          <Download size={14} weight="bold" />
          Exporter PDF
        </button>
      }
    >
      <div className="space-y-4">
        {/* Meta header */}
        <motion.div
          initial={{ opacity: 0, y: -8 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.4 }}
          className="flex flex-wrap items-center justify-between gap-3 p-4 rounded-2xl bg-white/[0.03] border border-white/[0.08]"
        >
          <div className="flex items-center gap-3">
            <div className="h-9 w-9 rounded-xl bg-gradient-to-br from-violet-600/30 to-blue-600/30 border border-violet-500/30 flex items-center justify-center">
              <GameController size={18} weight="duotone" className="text-violet-400" />
            </div>
            <div>
              <p className="text-white font-black text-sm tracking-tight">Le Business Model Canvas</p>
              <p className="text-zinc-500 text-[11px]">GameForge AI — Plateforme de Création de Jeux</p>
            </div>
          </div>
          <div className="flex flex-wrap gap-6 text-[11px]">
            {[
              { label: "Conçu pour", value: BMC_META.designedFor },
              { label: "Conçu par", value: BMC_META.designedBy },
              { label: "Date", value: BMC_META.date },
              { label: "Version", value: BMC_META.version },
            ].map((m) => (
              <div key={m.label}>
                <p className="text-zinc-600 font-bold uppercase tracking-widest text-[9px]">{m.label}</p>
                <p className="text-zinc-300 font-semibold mt-0.5">{m.value}</p>
              </div>
            ))}
          </div>
        </motion.div>

        {/* ── MAIN GRID ── */}
        {/* Row 1: Partners | Activities | Value Props | Customer Relations | Segments */}
        <div className="grid grid-cols-5 gap-3" style={{ height: "320px" }}>
          {/* PARTNERS */}
          <BMCCard title={PARTNERS.title} icon={PARTNERS.icon} color={PARTNERS.color} delay={0.05}>
            <div className="space-y-3">
              {PARTNERS.groups.map((g, i) => (
                <div key={i}>
                  <p className="text-[10px] font-black text-zinc-500 uppercase tracking-widest mb-1.5">{g.label}</p>
                  <ul className="space-y-1">
                    {g.items.map((item, j) => (
                      <li key={j} className="text-[11px] text-zinc-400 flex items-start gap-1.5">
                        <span className="text-violet-500 mt-0.5">›</span> {item}
                      </li>
                    ))}
                  </ul>
                </div>
              ))}
            </div>
          </BMCCard>

          {/* ACTIVITIES + RESOURCES stacked */}
          <div className="flex flex-col gap-3">
            <BMCCard title={KEY_ACTIVITIES.title} icon={KEY_ACTIVITIES.icon} color={KEY_ACTIVITIES.color} delay={0.08} className="flex-1">
              <ul className="space-y-2">
                {KEY_ACTIVITIES.items.map((item, i) => (
                  <li key={i} className="flex items-start gap-2">
                    <span className="text-base leading-none">{item.icon}</span>
                    <div>
                      <p className="text-[11px] font-bold text-zinc-300 leading-tight">{item.label}</p>
                      <p className="text-[10px] text-zinc-600 leading-tight">{item.desc}</p>
                    </div>
                  </li>
                ))}
              </ul>
            </BMCCard>
          </div>

          {/* VALUE PROPS — Center & wider */}
          <BMCCard title={VALUE_PROPS.title} icon={VALUE_PROPS.icon} color={VALUE_PROPS.color} delay={0.1}>
            <ul className="space-y-2.5">
              {VALUE_PROPS.items.map((item, i) => (
                <li key={i} className="flex items-start gap-2.5 p-2.5 rounded-xl bg-amber-500/[0.06] border border-amber-500/15">
                  <span className="text-base leading-none shrink-0">{item.icon}</span>
                  <div>
                    <p className="text-[12px] font-bold text-white leading-tight">{item.label}</p>
                    <p className="text-[10px] text-zinc-500 leading-tight mt-0.5">{item.desc}</p>
                  </div>
                </li>
              ))}
            </ul>
          </BMCCard>

          {/* RELATIONS + CHANNELS stacked */}
          <div className="flex flex-col gap-3">
            <BMCCard title={CUSTOMER_RELATIONS.title} icon={CUSTOMER_RELATIONS.icon} color={CUSTOMER_RELATIONS.color} delay={0.12} className="flex-1">
              <BulletList items={CUSTOMER_RELATIONS.items} color={CUSTOMER_RELATIONS.color} />
            </BMCCard>
          </div>

          {/* SEGMENTS */}
          <BMCCard title={SEGMENTS.title} icon={SEGMENTS.icon} color={SEGMENTS.color} delay={0.14}>
            <div className="space-y-2.5">
              {SEGMENTS.groups.map((g, i) => (
                <div key={i} className="p-2.5 rounded-xl bg-indigo-500/[0.06] border border-indigo-500/15">
                  <p className="text-[11px] font-bold text-zinc-300 leading-tight">{g.label}</p>
                  <p className="text-[10px] text-zinc-500 mt-0.5">{g.desc}</p>
                  <div className="mt-1.5">
                    <Pill text={`Besoin: ${g.need}`} color="#6366f1" />
                  </div>
                </div>
              ))}
            </div>
          </BMCCard>
        </div>

        {/* Row 1b: Key Resources (below Partners/Activities) + Channels (below Relations) */}
        <div className="grid grid-cols-5 gap-3" style={{ height: "240px" }}>
          {/* KEY RESOURCES spans 2 cols */}
          <div className="col-span-2">
            <BMCCard title={KEY_RESOURCES.title} icon={KEY_RESOURCES.icon} color={KEY_RESOURCES.color} delay={0.16} className="h-full">
              <div className="grid grid-cols-2 gap-3">
                {KEY_RESOURCES.groups.map((g, i) => (
                  <div key={i}>
                    <p className="text-[10px] font-black text-zinc-500 uppercase tracking-widest mb-1.5">{g.label}</p>
                    <ul className="space-y-1">
                      {g.items.map((item, j) => (
                        <li key={j} className="text-[11px] text-zinc-400 flex items-start gap-1.5">
                          <span className="text-orange-500 mt-0.5">›</span> {item}
                        </li>
                      ))}
                    </ul>
                  </div>
                ))}
              </div>
            </BMCCard>
          </div>

          {/* Empty center (value props bridge) */}
          <div className="flex items-center justify-center">
            <div className="flex flex-col items-center gap-2 text-zinc-700">
              <ArrowRight size={20} weight="bold" className="rotate-0" />
              <span className="text-[9px] font-black uppercase tracking-widest text-center">valeur<br />livrée</span>
              <ArrowRight size={20} weight="bold" />
            </div>
          </div>

          {/* CHANNELS spans 2 cols */}
          <div className="col-span-2">
            <BMCCard title={CHANNELS.title} icon={CHANNELS.icon} color={CHANNELS.color} delay={0.18} className="h-full">
              <div className="grid grid-cols-2 gap-2">
                {CHANNELS.items.map((item, i) => (
                  <div key={i} className="flex items-start gap-2 p-2 rounded-xl bg-emerald-500/[0.05] border border-emerald-500/10">
                    <span className="text-base leading-none shrink-0">{item.icon}</span>
                    <div>
                      <p className="text-[11px] font-bold text-zinc-300 leading-tight">{item.label}</p>
                      <p className="text-[10px] text-zinc-600 leading-tight">{item.desc}</p>
                    </div>
                  </div>
                ))}
              </div>
            </BMCCard>
          </div>
        </div>

        {/* Divider */}
        <div className="relative flex items-center gap-3">
          <div className="flex-1 h-px bg-gradient-to-r from-transparent via-white/[0.1] to-transparent" />
          <div className="flex items-center gap-2 px-3 py-1.5 rounded-full bg-white/[0.03] border border-white/[0.07]">
            <ArrowDown size={12} weight="bold" className="text-zinc-600" />
            <span className="text-[9px] font-black uppercase tracking-[0.25em] text-zinc-600">
              Finances
            </span>
            <ArrowDown size={12} weight="bold" className="text-zinc-600" />
          </div>
          <div className="flex-1 h-px bg-gradient-to-r from-transparent via-white/[0.1] to-transparent" />
        </div>

        {/* Row 2: Costs | Revenue */}
        <div className="grid grid-cols-2 gap-3" style={{ minHeight: "200px" }}>
          {/* COST STRUCTURE */}
          <BMCCard title={COST_STRUCTURE.title} icon={COST_STRUCTURE.icon} color={COST_STRUCTURE.color} delay={0.2}>
            <div className="grid grid-cols-2 gap-4">
              <div>
                <p className="text-[10px] font-black text-red-400 uppercase tracking-widest mb-2">📌 Coûts Fixes</p>
                <BulletList items={COST_STRUCTURE.fixed} color="#ef4444" />
              </div>
              <div>
                <p className="text-[10px] font-black text-orange-400 uppercase tracking-widest mb-2">⚖️ Coûts Variables</p>
                <BulletList items={COST_STRUCTURE.variable} color="#f97316" />
              </div>
            </div>
          </BMCCard>

          {/* REVENUE STREAMS */}
          <BMCCard title={REVENUE_STREAMS.title} icon={REVENUE_STREAMS.icon} color={REVENUE_STREAMS.color} delay={0.22}>
            <div className="grid grid-cols-2 gap-4">
              <div>
                <p className="text-[10px] font-black text-emerald-400 uppercase tracking-widest mb-2">🔄 Récurrents (SaaS)</p>
                <ul className="space-y-1.5">
                  {REVENUE_STREAMS.recurring.map((r, i) => (
                    <li key={i} className="p-2 rounded-xl bg-emerald-500/[0.06] border border-emerald-500/15">
                      <p className="text-[11px] font-bold text-zinc-300">{r.label}</p>
                      <p className="text-[10px] text-zinc-600">{r.desc}</p>
                    </li>
                  ))}
                </ul>
              </div>
              <div>
                <p className="text-[10px] font-black text-cyan-400 uppercase tracking-widest mb-2">💳 Transactionnel</p>
                <ul className="space-y-1.5">
                  {REVENUE_STREAMS.transactional.map((r, i) => (
                    <li key={i} className="p-2 rounded-xl bg-cyan-500/[0.05] border border-cyan-500/10">
                      <p className="text-[11px] font-bold text-zinc-300">{r.label}</p>
                      <p className="text-[10px] text-zinc-600">{r.desc}</p>
                    </li>
                  ))}
                </ul>
              </div>
            </div>
          </BMCCard>
        </div>

        {/* Footer note */}
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ delay: 0.4 }}
          className="flex items-center justify-between px-4 py-3 rounded-xl bg-white/[0.02] border border-white/[0.05] text-[10px] text-zinc-600"
        >
          <span>© 2026 GameForge AI — Business Model Canvas v2.0</span>
          <span className="flex items-center gap-2">
            <Code size={12} weight="duotone" className="text-blue-500" />
            Built with GameForge Studio
          </span>
        </motion.div>
      </div>
    </AdminShell>
  );
}
