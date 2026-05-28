// One-off generator: hits Pollinations.ai for the sword-enhancement game
// (16 sword tiers + 3 effect sprites). Re-run any time to regenerate
// (bump seed of an individual entry if you don't like the result).
//
// Usage:
//   node scripts/gen-sprites.mjs              # all 19 swords + effects
//   node scripts/gen-sprites.mjs sword_03     # just one
//   node scripts/gen-sprites.mjs --characters # legacy: regenerate the 5+5 idle-RPG cast
//
// No API key. No cost. ~30 seconds per image on Pollinations free tier.

import { writeFile, mkdir } from 'node:fs/promises';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const OUT_SWORDS = join(__dirname, '..', 'assets', 'swords');
const OUT_CHARACTERS = join(__dirname, '..', 'assets', 'characters', 'characters');
const OUT_BOSSES = join(__dirname, '..', 'assets', 'characters', 'bosses');

// Sword sprites share a strict style so all 16 tiers feel like the same
// weapon evolving. "weapon item icon" framing avoids characters/scenes.
const SWORD_STYLE = '16-bit pixel art sword weapon icon, centered, vertical blade pointing up, '
  + 'NES SNES retro RPG inventory style, clean pixel outline, vibrant limited palette, '
  + 'plain white background, no text, no UI, no border, no character, just the sword';

// 16 tiers — iron → steel → mithril → gold → legendary. Each tier covers
// 3 levels: visual energy ramps within the tier (more gem detail, more glow).
const SWORDS = [
  { id: 'sword_00', seed: 1100, desc: 'a plain rusty iron shortsword, simple straight blade, leather wrapped hilt, no decoration' },
  { id: 'sword_01', seed: 1115, desc: 'a basic iron sword, slightly cleaner blade, simple round pommel' },
  { id: 'sword_02', seed: 1130, desc: 'a sharpened iron sword, polished blade, small crossguard' },
  { id: 'sword_03', seed: 1145, desc: 'a steel longsword, bright silver blade, ornate crossguard, blue grip' },
  { id: 'sword_04', seed: 1160, desc: 'a fine steel sword with a small red gem in the pommel, engraved blade' },
  { id: 'sword_05', seed: 1175, desc: 'a knight steel sword glowing faint white aura, decorated guard' },
  { id: 'sword_06', seed: 1190, desc: 'a mithril sword, cool cyan-blue blade, silver fittings, faint magic shimmer' },
  { id: 'sword_07', seed: 1205, desc: 'an enchanted mithril sword with sapphire gem, ice-blue glow surrounding blade' },
  { id: 'sword_08', seed: 1220, desc: 'a runic mithril sword, glowing magic runes etched along the blade, bright cyan aura' },
  { id: 'sword_09', seed: 1235, desc: 'a golden sword, bright gold blade, ornate gold hilt, soft yellow glow' },
  { id: 'sword_10', seed: 1250, desc: 'a royal golden sword with multiple jewels on the hilt, radiant yellow aura, flame licks on blade edge' },
  { id: 'sword_11', seed: 1265, desc: 'a flaming golden sword with orange fire wreathing the entire blade, jewel encrusted guard' },
  { id: 'sword_12', seed: 1280, desc: 'a legendary holy sword, white-gold blade, angel-wing crossguard, bright white halo glow' },
  { id: 'sword_13', seed: 1295, desc: 'a divine sword with rainbow prismatic blade, ornate wing guard, surrounded by glowing white particles' },
  { id: 'sword_14', seed: 1310, desc: 'a god-tier legendary sword with crackling purple lightning along the blade, dragon-shaped golden hilt' },
  { id: 'sword_15', seed: 1325, desc: 'the ultimate cosmic sword, blade made of swirling galaxy stars, lightning and fire intertwining, dragon-wing crossguard, intense radiant aura' },
];

// Effect sprites — square framing, transparent-friendly so flood-fill works.
const EFFECTS = [
  { id: 'fx_success', seed: 2100, desc: 'a bright sparkling white-gold burst effect, radial light rays, magic stardust, success celebration spell impact' },
  { id: 'fx_fail',    seed: 2115, desc: 'a grey crack fracture effect, jagged broken lines, small smoke puffs, weapon damage feedback' },
  { id: 'fx_destroy', seed: 2130, desc: 'a shattered metal explosion effect, broken sword shards flying outward, dark red impact flash, destruction burst' },
];

// Legacy idle-RPG cast — kept so old assets/characters/ doesn't have to be
// regenerated from scratch. Only runs with --characters flag.
const STYLE_CHAR = '16-bit pixel art game sprite, single character centered, '
  + 'NES SNES retro style, clean pixel outline, vibrant limited palette, '
  + 'plain white background, no text, no UI elements, no border, full body view';
const CHARACTERS = [
  { id: 'programmer', seed: 142, desc: 'a friendly programmer with round glasses, brown hair, holding a small laptop' },
  { id: 'wizard',     seed: 271, desc: 'a wise wizard with a tall purple pointed hat, long beard, holding a glowing magic staff' },
  { id: 'ninja',      seed: 308, desc: 'a stealthy ninja in dark navy outfit, face mask, holding a katana sword' },
  { id: 'chef',       seed: 415, desc: 'a cheerful chef with a tall white toque, white apron, holding a wooden spoon and a pot' },
  { id: 'explorer',   seed: 533, desc: 'an adventurous explorer with a tan safari hat, khaki vest, holding a brass compass and a rolled map' },
];
const BOSSES = [
  { id: 'bug_goblin',       seed: 612, desc: 'a small green goblin monster with a computer bug body, antenna ears, glowing red eyes, mischievous grin' },
  { id: 'null_dragon',      seed: 749, desc: 'a fierce red dragon breathing fire, sharp claws, leathery wings, menacing stance' },
  { id: 'race_hydra',       seed: 856, desc: 'a three-headed teal hydra serpent, scaly body, all heads roaring forward' },
  { id: 'tech_debt_giant',  seed: 967, desc: 'a hulking purple stone behemoth made of crumbling code blocks, glowing crack runes, looming pose' },
  { id: 'stack_ghost',      seed: 178, desc: 'a translucent blue spectral ghost with stack-trace symbols floating around, hollow eye sockets' },
];

const POLLINATIONS = 'https://image.pollinations.ai/prompt';

async function fetchSprite({ id, seed, desc }, outDir, stylePrefix) {
  const prompt = `${desc}, ${stylePrefix}`;
  const url = `${POLLINATIONS}/${encodeURIComponent(prompt)}`
    + `?model=flux&width=512&height=512&nologo=true&seed=${seed}&private=true`;
  const out = join(outDir, `${id}.png`);
  console.log(`→ ${id} (seed=${seed})`);
  const res = await fetch(url);
  if (!res.ok) throw new Error(`${id}: HTTP ${res.status}`);
  const buf = Buffer.from(await res.arrayBuffer());
  await writeFile(out, buf);
  console.log(`  ✓ ${out} (${(buf.length / 1024).toFixed(1)} KB)`);
}

async function main() {
  const args = process.argv.slice(2);
  const wantCharacters = args.includes('--characters');
  const filter = args.find((a) => !a.startsWith('--'));

  await mkdir(OUT_SWORDS, { recursive: true });

  // Default: swords + effects. Targets share the sword style prefix.
  const swordTargets = [
    ...SWORDS.map((s) => ({ ...s, outDir: OUT_SWORDS, style: SWORD_STYLE })),
    ...EFFECTS.map((s) => ({ ...s, outDir: OUT_SWORDS, style: SWORD_STYLE })),
  ];

  let targets = swordTargets;
  if (wantCharacters) {
    await mkdir(OUT_CHARACTERS, { recursive: true });
    await mkdir(OUT_BOSSES, { recursive: true });
    targets = [
      ...CHARACTERS.map((s) => ({ ...s, outDir: OUT_CHARACTERS, style: STYLE_CHAR })),
      ...BOSSES.map((s) => ({ ...s, outDir: OUT_BOSSES, style: STYLE_CHAR })),
    ];
  }
  if (filter) {
    targets = targets.filter((s) => s.id === filter);
    if (targets.length === 0) {
      console.error(`No sprite matches "${filter}".`);
      process.exit(1);
    }
  }
  for (const sprite of targets) {
    try {
      await fetchSprite(sprite, sprite.outDir, sprite.style);
    } catch (e) {
      console.error(`  ✗ ${sprite.id}: ${e.message}`);
    }
    await new Promise((r) => setTimeout(r, 1000));
  }
  console.log(`\nDone. ${targets.length} sprite(s).`);
}

main().catch((e) => { console.error(e); process.exit(1); });
