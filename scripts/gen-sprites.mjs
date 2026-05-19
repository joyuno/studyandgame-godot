// One-off generator: hits Pollinations.ai for 5 character + 5 boss pixel art
// sprites and saves them under assets/characters_ai/. Re-run any time to
// regenerate (use a different seed per character to iterate on what you don't like).
//
// Usage:
//   node scripts/gen-sprites.mjs           # generate all 10
//   node scripts/gen-sprites.mjs wizard    # regenerate just one
//
// No API key. No cost. ~30 seconds per image on Pollinations free tier.

import { writeFile, mkdir } from 'node:fs/promises';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const OUT_DIR = join(__dirname, '..', 'assets', 'characters_ai');

// Shared prefix keeps style consistent across all 10 sprites.
const STYLE = '16-bit pixel art game sprite, single character centered, '
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

async function fetchSprite({ id, seed, desc }) {
  const prompt = `${desc}, ${STYLE}`;
  const url = `${POLLINATIONS}/${encodeURIComponent(prompt)}`
    + `?model=flux&width=512&height=512&nologo=true&seed=${seed}&private=true`;
  const out = join(OUT_DIR, `${id}.png`);
  console.log(`→ ${id} (seed=${seed})`);
  const res = await fetch(url);
  if (!res.ok) throw new Error(`${id}: HTTP ${res.status}`);
  const buf = Buffer.from(await res.arrayBuffer());
  await writeFile(out, buf);
  console.log(`  ✓ ${out} (${(buf.length / 1024).toFixed(1)} KB)`);
}

async function main() {
  await mkdir(OUT_DIR, { recursive: true });
  const filter = process.argv[2];
  const all = [...CHARACTERS, ...BOSSES];
  const targets = filter ? all.filter((s) => s.id === filter) : all;
  if (targets.length === 0) {
    console.error(`No sprite matches "${filter}". Available:`);
    for (const s of all) console.error(`  - ${s.id}`);
    process.exit(1);
  }
  for (const sprite of targets) {
    try {
      await fetchSprite(sprite);
    } catch (e) {
      console.error(`  ✗ ${sprite.id}: ${e.message}`);
    }
    // Be polite to the free service.
    await new Promise((r) => setTimeout(r, 1000));
  }
  console.log(`\nDone. Saved to ${OUT_DIR}`);
}

main().catch((e) => { console.error(e); process.exit(1); });
