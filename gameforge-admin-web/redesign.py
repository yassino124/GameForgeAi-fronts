import os
import re

files = [
    "/Users/mohamedyassineouertani/Downloads/GameForge/gamefrogai/gameforge-admin-web/src/app/studio/tournaments/list/page.tsx",
    "/Users/mohamedyassineouertani/Downloads/GameForge/gamefrogai/gameforge-admin-web/src/app/studio/tournaments/create/page.tsx",
    "/Users/mohamedyassineouertani/Downloads/GameForge/gamefrogai/gameforge-admin-web/src/app/studio/tournaments/[id]/page.tsx"
]

replacements = [
    (r'bg-black/25', r'bg-[#07080f]'),
    (r'bg-black/30', r'bg-[#07080f]'),
    (r'bg-black/35', r'bg-[#07080f]'),
    (r'bg-black/20', r'bg-[#07080f]/50'),
    (r'border-white/10', r'border-white/[0.05]'),
    (r'hover:border-white/15', r'hover:border-white/[0.08]'),
    (r'hover:bg-black/30', r'hover:bg-[#0c0d14]'),
    (r'bg-white/5', r'bg-white/[0.02]'),
    (r'font-black', r'font-semibold'),
    (r'shadow-\[0_[0-9]+px_[0-9]+px_rgba\(0,0,0,0\.[0-9]+\)\]', r'shadow-sm'),
    (r'bg-\[radial-gradient\([^\]]+\)\]', r''), # Remove neon radial gradients
    # Buttons
    (r'bg-emerald-500/80 px-[0-9] py-[0-9] text-xs font-semibold uppercase tracking-widest text-white', r'bg-white px-4 py-2 text-xs font-medium text-black hover:bg-zinc-200'),
    (r'border-blue-400/30 bg-blue-500/15 px-[0-9] py-[0-9] text-xs font-semibold uppercase tracking-widest text-blue-100', r'border-white/[0.05] bg-white/[0.02] px-4 py-2 text-xs font-medium text-white hover:bg-white/[0.05]'),
    (r'border border-cyan-400/30 bg-cyan-500/15', r'border border-white/[0.05] bg-white/[0.02]'),
    (r'text-cyan-100', r'text-white'),
    (r'bg-gradient-to-r from-cyan-500/20 to-blue-500/20', r'bg-white/[0.05] hover:bg-white/[0.08]'),
    (r'border-cyan-300/30', r'border-white/[0.05]'),
    (r'border-cyan-400/25 bg-cyan-500/10', r'border-white/[0.05] bg-white/[0.02]'),
    (r'border-amber-400/25 bg-amber-500/10', r'border-amber-500/20 bg-amber-500/10'),
    (r'rounded-2xl', r'rounded-xl'),
    (r'rounded-\[28px\]', r'rounded-2xl'),
    (r'rounded-\[32px\]', r'rounded-2xl'),
    (r'uppercase tracking-widest', r'tracking-wide'),
    (r'uppercase tracking-\[0\.[0-9]+em\]', r'tracking-wider'),
]

for file_path in files:
    if os.path.exists(file_path):
        with open(file_path, 'r') as f:
            content = f.read()
        
        for old, new in replacements:
            content = re.sub(old, new, content)
            
        with open(file_path, 'w') as f:
            f.write(content)
        print(f"Updated {file_path}")
    else:
        print(f"File not found: {file_path}")

