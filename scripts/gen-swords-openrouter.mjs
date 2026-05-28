// Regenerates the 19 sword + effect sprites via OpenRouter's Gemini 2.5
// Flash Image ("Nano Banana"). The free Pollinations path lives next door in
// gen-sprites.mjs — kept for the character/boss sprites that are not being
// re-rolled.
//
// Why this exists:
//   - Pollinations + sharp flood-fill leaves a fringe of bright pixels around
//     the blade silhouette (AB-style edge halo). Annoying at 1x, ugly at 2x.
//   - Gemini 2.5 Flash Image generates with native alpha, so the silhouette
//     ships clean without a post-process pass.
//   - Higher base fidelity for the legendary tiers (cosmic / lightning).
//
// Cost: roughly $0.04 per image × 19 = ~$0.8 per full regen run (May 2026
// pricing on OpenRouter — $2.5/1M output tokens, image ≈ 1290 tokens).
//
// Usage:
//   node scripts/gen-swords-openrouter.mjs                 # all 19
//   node scripts/gen-swords-openrouter.mjs sword_15        # just one
//   node scripts/gen-swords-openrouter.mjs sword_00 fx_fail  # multiple
//   node scripts/gen-swords-openrouter.mjs --magenta sword_12 fx_success fx_fail
//                                                          # chroma-key mode:
//                                                          # ask Gemini for a
//                                                          # solid #FF00FF
//                                                          # background, then
//                                                          # convert that exact
//                                                          # color to alpha=0
//                                                          # in post-process.
//                                                          # Use this for any
//                                                          # sprite whose
//                                                          # palette overlaps
//                                                          # white (holy
//                                                          # swords, bright
//                                                          # spell FX) — the
//                                                          # default white-bg
//                                                          # path destroys
//                                                          # internal whites
//                                                          # when flood-filled.
//
// Requires OPENROUTER_API_KEY in ../.env (auto-loaded; no dotenv dependency).

import { writeFile, mkdir, readFile } from 'node:fs/promises';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import sharp from 'sharp';

const __dirname = dirname(fileURLToPath(import.meta.url));
const PROJECT_ROOT = join(__dirname, '..');
const ENV_PATH = join(PROJECT_ROOT, '.env');
const OUT_DIR = join(PROJECT_ROOT, 'assets', 'swords');

const MODEL = 'google/gemini-2.5-flash-image';
const ENDPOINT = 'https://openrouter.ai/api/v1/chat/completions';

// Shared style anchor. Every blade tier is the SAME family of weapon
// evolving — not 16 unrelated swords. Native alpha PNG kills the halo
// problem that motivated this script in the first place.
//
// FRAMING RULE: the SWORD itself must fill ~60-70% of the canvas vertically
// (blade tip near the top, pommel near the bottom). Auras/glow/decorations
// stay as small accents around the blade, NEVER as huge surrounding shapes
// (no giant wings, no encircling halos that dwarf the blade).
const SWORD_STYLE = [
  'High-quality RPG inventory weapon-icon illustration, polished 2D game-art',
  'style (Final Fantasy / Octopath / Diablo inventory feel), painterly shading',
  'with crisp outline and vivid limited palette.',
  'The SWORD itself dominates the composition — the blade plus hilt fills',
  'roughly 60-70% of the canvas vertically, centered, blade pointing straight',
  'up, tip near the top edge with a small even margin, pommel near the bottom.',
  'Auras, glow, runes, flames and decorations remain SMALL accents tightly',
  'around the blade — NO large surrounding wings, NO giant encircling halos,',
  'NO background frame, NO floating ornaments larger than the sword.',
  'Square 1024x1024 canvas with FULLY TRANSPARENT background — alpha PNG,',
  'no checkerboard, no white box, no gradient, no drop shadow on the ground.',
  'Isolated weapon icon only: no character, no hand, no scabbard, no text,',
  'no UI frame, no border, no watermark. Clean alpha edges — absolutely no',
  'scattered background pixels or stray halo around the silhouette.',
].join(' ');

const EFFECT_STYLE = [
  'Pixel-art VFX sprite, 16-bit JRPG style, square 1024x1024 canvas, effect',
  'centered with even margin. FULLY TRANSPARENT background — alpha PNG, no',
  'checkerboard, no white box, no gradient, no ground shadow. Effect particles',
  'only: no text, no UI, no character, no weapon, no border. Clean alpha edges.',
].join(' ');

// Magenta-background variants. Gemini 2.5 Flash Image, as measured, does NOT
// actually emit alpha=0 backgrounds — it hides them behind a solid color.
// Demanding a single saturated color (#FF00FF) that does not appear anywhere
// else in the palette lets us strip the background with an exact-color match
// instead of a white-threshold flood-fill that eats internal whites. This is
// the rescue path for holy/divine swords and bright spell FX.
// CRITICAL — every model run we have observed treats "transparent background"
// as a suggestion and outputs a solid color instead. We pin the color to a
// saturated magenta/pink range we can chroma-key out, and over-emphasize the
// "do NOT use pastel/light pink" line because Gemini's default sympathy is to
// soften the request into something pretty.
const SWORD_STYLE_MAGENTA = [
  'High-quality RPG inventory weapon-icon illustration, polished 2D game-art',
  'style (Final Fantasy / Octopath / Diablo inventory feel), painterly shading',
  'with crisp outline and vivid limited palette.',
  'The SWORD itself dominates the composition — the blade plus hilt fills',
  'roughly 60-70% of the canvas vertically, centered, blade pointing straight',
  'up, tip near the top edge with a small even margin, pommel near the bottom.',
  'Auras, glow, runes, flames and decorations remain SMALL accents tightly',
  'around the blade — NO large surrounding wings, NO giant encircling halos,',
  'NO background frame, NO floating ornaments larger than the sword.',
  '*** BACKGROUND COLOR REQUIREMENT — READ CAREFULLY ***',
  'The entire background MUST be a SOLID FLAT FULLY SATURATED MAGENTA in',
  'the EXACT hex color #FF00FF (RGB 255, 0, 255). This is a non-negotiable',
  'chroma-key requirement. The background must be SCREAMING NEON MAGENTA,',
  'eye-burning bright, the most saturated magenta you can produce.',
  'DO NOT use pastel pink. DO NOT use light pink. DO NOT use salmon, rose,',
  'fuchsia-lite, or any softened version. DO NOT use a gradient. DO NOT use',
  'a vignette. DO NOT use any other color in the background. Pure flat',
  '#FF00FF, every background pixel exactly the same.',
  'Do not put any magenta or pink color on the sword itself.',
  'Isolated weapon icon only: no character, no hand, no text, no UI frame,',
  'no border, no watermark.',
].join(' ');

// Luminance-on-black: ask Gemini to draw a bright effect on solid #000000
// and then map luminance → alpha. Works only when the EFFECT is colored
// light-on-dark (white/gold/yellow burst, bright spell impact). Side benefit:
// the radial fall-off becomes a natural alpha gradient instead of a hard
// chroma-key edge — perfect for burst-style FX.
const EFFECT_STYLE_BLACK = [
  'Pixel-art VFX sprite, 16-bit JRPG style, square 1024x1024 canvas, effect',
  'centered with even margin.',
  'The CANVAS background MUST be SOLID FLAT PURE BLACK #000000 (RGB 0,0,0).',
  'No other color in the background, no gradient, no noise — pitch black.',
  'The effect itself is bright (white / gold / yellow / red as described),',
  'with a natural radial fade from a bright center to dark edges. The dark',
  'edges should blend smoothly into the black canvas.',
  'Effect only: no text, no UI, no character, no weapon, no border.',
].join(' ');

// Same idea as the magenta path but using neon green #00FF00. Pick this when
// the effect itself is white/yellow/golden and Gemini keeps tinting the
// particles toward pink under the magenta prompt — green sits opposite gold
// on the wheel, so the spillover is dramatic and easy to chroma-key.
const SWORD_STYLE_GREEN = [
  'High-quality RPG inventory weapon-icon illustration, polished 2D game-art',
  'style (Final Fantasy / Octopath / Diablo inventory feel), painterly shading',
  'with crisp outline and vivid limited palette.',
  'The SWORD itself dominates the composition — the blade plus hilt fills',
  'roughly 60-70% of the canvas vertically, centered, blade pointing straight',
  'up, tip near the top edge with a small even margin, pommel near the bottom.',
  'Auras, glow, runes, flames and decorations remain SMALL accents tightly',
  'around the blade — NO large surrounding wings, NO giant encircling halos,',
  'NO background frame, NO floating ornaments larger than the sword.',
  '*** BACKGROUND COLOR REQUIREMENT — READ CAREFULLY ***',
  'The entire background MUST be SOLID FLAT FULLY SATURATED NEON GREEN in',
  'the EXACT hex color #00FF00 (RGB 0, 255, 0). Screaming chroma-key green,',
  'eye-burning bright. DO NOT use any other shade of green, DO NOT use a',
  'darker green, DO NOT use a gradient, DO NOT use any other color in the',
  'background. Pure flat #00FF00, every background pixel exactly the same.',
  'Do not put any green or chroma-key green on the sword itself — the sword',
  'keeps its described colors (silver, gold, blue, white, etc).',
  'Isolated weapon icon only: no character, no hand, no text, no UI frame,',
  'no border, no watermark.',
].join(' ');

const EFFECT_STYLE_GREEN = [
  'Pixel-art VFX sprite, 16-bit JRPG style, square 1024x1024 canvas, effect',
  'centered with even margin.',
  '*** EFFECT PARTICLES KEEP THE COLORS DESCRIBED ABOVE — NEVER GREEN. ***',
  'The empty CANVAS area around the effect MUST be SOLID FLAT FULLY SATURATED',
  'NEON GREEN, EXACT hex #00FF00 (RGB 0, 255, 0). Chroma-key green only,',
  'no gradient, no other colors in the background.',
  'CRITICAL: the particles themselves stay in their described colors (gold,',
  'white, red, grey, etc) and must NOT shift toward green.',
  'Effect only: no text, no UI, no character, no weapon, no border.',
].join(' ');

const EFFECT_STYLE_MAGENTA = [
  'Pixel-art VFX sprite, 16-bit JRPG style, square 1024x1024 canvas, effect',
  'centered with even margin.',
  '*** EFFECT PARTICLES MUST USE THE COLORS DESCRIBED ABOVE — NEVER PINK, ',
  'NEVER MAGENTA, NEVER FUCHSIA. The magenta requirement below applies ONLY ',
  'to the background canvas, not to the effect particles themselves. ***',
  '*** BACKGROUND COLOR REQUIREMENT — READ CAREFULLY ***',
  'The empty CANVAS area around the effect MUST be a SOLID FLAT FULLY',
  'SATURATED MAGENTA in the EXACT hex color #FF00FF (RGB 255, 0, 255).',
  'SCREAMING NEON MAGENTA, eye-burning bright. DO NOT use pastel pink, light',
  'pink, salmon, rose, or any softened variant on the background. DO NOT use',
  'a gradient on the background. Pure flat #FF00FF on every background pixel.',
  'CRITICAL: the effect particles themselves keep their described colors',
  '(gold, white, red, grey, etc) and must NOT shift toward pink or magenta.',
  'Effect only: no text, no UI, no character, no weapon, no border.',
].join(' ');

// Tier ladder: each sword is the SAME weapon evolving (iron → steel → mithril
// → gold → legendary → cosmic). Visual energy ramps within each material band.
const SWORDS = [
  { id: 'sword_00', desc: 'A plain rusty iron shortsword. Simple straight blade with patches of light rust, leather-wrapped brown hilt, no decoration, beginner tier.' },
  { id: 'sword_01', desc: 'A basic iron sword. Slightly cleaner steel-grey blade than tier 0, simple round iron pommel, plain crossguard.' },
  { id: 'sword_02', desc: 'A sharpened iron sword. Polished light-grey blade with visible bevel, small ornate crossguard, dark leather grip.' },
  { id: 'sword_03', desc: 'A steel longsword. Bright silver blade, ornate forged crossguard, blue-wrapped grip, no glow yet.' },
  { id: 'sword_04', desc: 'A fine steel sword with a small red ruby gem set in the round pommel, light engraving along the blade fuller.' },
  { id: 'sword_05', desc: 'A knight steel sword glowing with a faint white aura at the edge, decorated guard with filigree, blue grip with gold wrap.' },
  { id: 'sword_06', desc: 'A mithril sword with a cool cyan-blue tinted blade, polished silver fittings, faint magical shimmer along the edge.' },
  { id: 'sword_07', desc: 'An enchanted mithril sword with a blue sapphire gem in the crossguard, ice-blue glow surrounding the entire blade, frost particles.' },
  { id: 'sword_08', desc: 'A runic mithril sword. Glowing cyan magic runes etched along the length of the blade, bright cyan aura, mithril crossguard.' },
  { id: 'sword_09', desc: 'A golden sword. Bright polished gold blade, ornate gold hilt with scroll-work, soft warm yellow glow.' },
  { id: 'sword_10', desc: 'A royal golden sword with multiple jewels set on the hilt (red, blue, green), radiant yellow aura, faint flame licks along the blade edge.' },
  { id: 'sword_11', desc: 'A flaming golden sword: orange and yellow fire wreathing the entire blade, jewel-encrusted gold guard, embers rising.' },
  { id: 'sword_12', desc: 'A legendary holy sword. White-gold blade, angel-wing-shaped crossguard, bright white halo glow, holy radiance.' },
  { id: 'sword_13', desc: 'A divine sword with a rainbow prismatic blade catching every color, ornate angel-wing guard, surrounded by glowing white particles.' },
  { id: 'sword_14', desc: 'A god-tier legendary sword. Crackling purple lightning arcs along the blade, dragon-shaped golden hilt with red eye gem, intense purple aura.' },
  { id: 'sword_15', desc: 'The ultimate cosmic sword. Blade made of swirling galaxy stars and nebulae, purple lightning and red fire intertwining, dragon-wing crossguard, intense radiant cosmic aura.' },
];

const EFFECTS = [
  { id: 'fx_success', desc: 'A bright sparkling white-gold radial burst effect: outward light rays, magic stardust, success celebration spell impact, no sword.' },
  { id: 'fx_fail',    desc: 'A grey crack-fracture effect: jagged broken lines forming a star shape, small smoke puffs, weapon damage feedback, no sword.' },
  { id: 'fx_destroy', desc: 'A shattered metal explosion: broken sword shards flying outward in all directions, dark red impact flash at center, destruction burst.' },
];

async function loadEnv() {
  let body;
  try { body = await readFile(ENV_PATH, 'utf8'); }
  catch { throw new Error(`Missing .env at ${ENV_PATH}`); }
  for (const line of body.split(/\r?\n/)) {
    const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.+?)\s*$/);
    if (m && !process.env[m[1]]) process.env[m[1]] = m[2];
  }
  if (!process.env.OPENROUTER_API_KEY) {
    throw new Error('OPENROUTER_API_KEY not found in .env');
  }
}

function dataUrlToBuffer(url) {
  const m = url.match(/^data:image\/\w+;base64,(.+)$/);
  if (!m) throw new Error(`Not a base64 image data URL: ${url.slice(0, 80)}…`);
  return Buffer.from(m[1], 'base64');
}

// Convert magenta/pink-family pixels to alpha=0. Gemini in practice softens
// the requested #FF00FF into a pastel pink (high R, high B, mid G ≈ 140-180).
// "Magenta-ness" = how much R and B exceed G, normalized. Threshold tuned so
// pastel-pink backgrounds (g≈170) still register strongly while red/blue/
// purple sword details (where g is near 0 or where R or B alone dominates)
// stay opaque. The intermediate ramp kills the AA fringe at the silhouette.
// Per-pixel alpha = luminance. Black pixels become fully transparent, white
// pixels stay fully opaque, mid-tones get a smooth alpha. This is NOT a
// chroma-key — it preserves the colors but reweights opacity by brightness.
async function alphaFromLuminance(pngBuf) {
  const { data, info } = await sharp(pngBuf).ensureAlpha().raw()
    .toBuffer({ resolveWithObject: true });
  for (let i = 0; i < data.length; i += 4) {
    const r = data[i], g = data[i + 1], b = data[i + 2];
    const lum = 0.299 * r + 0.587 * g + 0.114 * b;
    // Floor below 12 to 0 — avoids near-black "fog" pixels lighting the bg.
    data[i + 3] = lum < 12 ? 0 : Math.min(255, Math.round(lum));
  }
  return sharp(data, {
    raw: { width: info.width, height: info.height, channels: 4 },
  }).png({ compressionLevel: 9 }).toBuffer();
}

async function chromaKeyGreen(pngBuf) {
  const { data, info } = await sharp(pngBuf).ensureAlpha().raw()
    .toBuffer({ resolveWithObject: true });
  for (let i = 0; i < data.length; i += 4) {
    const r = data[i], g = data[i + 1], b = data[i + 2];
    // Green family = G high, R+B both clearly lower.
    const score = g - Math.max(r, b);
    const gHigh = g > 150;
    if (!gHigh || score <= 20) continue;
    if (score >= 80) {
      data[i + 3] = 0;
    } else {
      const t = (score - 20) / (80 - 20);
      data[i + 3] = Math.round(data[i + 3] * (1 - t));
    }
  }
  return sharp(data, {
    raw: { width: info.width, height: info.height, channels: 4 },
  }).png({ compressionLevel: 9 }).toBuffer();
}

async function chromaKeyMagenta(pngBuf) {
  const { data, info } = await sharp(pngBuf).ensureAlpha().raw()
    .toBuffer({ resolveWithObject: true });
  for (let i = 0; i < data.length; i += 4) {
    const r = data[i], g = data[i + 1], b = data[i + 2];
    // Magenta/pink/salmon family. Gemini routinely softens #FF00FF into a
    // pastel pink (r=255, g=80-160, b=100-200) — we have to catch that whole
    // range without nuking warm sword colors (gold, red, orange-flame).
    //   - r >= 200            : bright reds and pinks
    //   - g <= r - 40         : G clearly below R (rules out white, gold, yellow)
    //   - b >= 60             : has *some* blue (rules out fire-red / orange)
    //   - b <= r + 20         : not a pure blue/purple-blue
    const valid = r >= 200 && g <= r - 40 && b >= 60 && b <= r + 20;
    if (!valid) continue;
    const score = r - g;          // r-g grows from ~40 (light pink) → 255 (pure magenta)
    if (score >= 140) {
      data[i + 3] = 0;
    } else {
      const t = (score - 40) / (140 - 40);
      data[i + 3] = Math.round(data[i + 3] * (1 - Math.max(0, t)));
    }
  }
  return sharp(data, {
    raw: { width: info.width, height: info.height, channels: 4 },
  }).png({ compressionLevel: 9 }).toBuffer();
}

async function generate({ id, desc }, stylePrefix) {
  const prompt = `${desc} ${stylePrefix}`;
  const res = await fetch(ENDPOINT, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${process.env.OPENROUTER_API_KEY}`,
      'Content-Type': 'application/json',
      'HTTP-Referer': 'https://github.com/joyuno/study_game_godot',
      'X-Title': 'study_game_godot sword sprites',
    },
    body: JSON.stringify({
      model: MODEL,
      messages: [{ role: 'user', content: prompt }],
      modalities: ['image', 'text'],
      image_config: { aspect_ratio: '1:1' },
    }),
  });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`HTTP ${res.status}: ${text.slice(0, 400)}`);
  }
  const json = await res.json();
  const image = json?.choices?.[0]?.message?.images?.[0]?.image_url?.url;
  if (!image) {
    const dump = JSON.stringify(json).slice(0, 500);
    throw new Error(`No image in response. Body: ${dump}`);
  }
  return dataUrlToBuffer(image);
}

async function main() {
  await loadEnv();
  await mkdir(OUT_DIR, { recursive: true });

  const args = process.argv.slice(2);
  const magenta = args.includes('--magenta');
  const green = args.includes('--green');
  const luma = args.includes('--luma');
  const modes = [magenta, green, luma].filter(Boolean).length;
  if (modes > 1) {
    console.error('Pick one chroma mode: --magenta OR --green OR --luma.');
    process.exit(2);
  }
  const ids = new Set(args.filter((a) => !a.startsWith('--')));
  const swordStyle = green ? SWORD_STYLE_GREEN
    : magenta ? SWORD_STYLE_MAGENTA : SWORD_STYLE;
  const effectStyle = luma ? EFFECT_STYLE_BLACK
    : green ? EFFECT_STYLE_GREEN
    : magenta ? EFFECT_STYLE_MAGENTA : EFFECT_STYLE;
  const chromaKey = luma ? alphaFromLuminance
    : green ? chromaKeyGreen
    : magenta ? chromaKeyMagenta : null;
  const all = [
    ...SWORDS.map((s) => ({ ...s, style: swordStyle })),
    ...EFFECTS.map((s) => ({ ...s, style: effectStyle })),
  ];
  const targets = ids.size ? all.filter((t) => ids.has(t.id)) : all;
  if (ids.size && targets.length === 0) {
    console.error(`No sprite matches: ${[...ids].join(', ')}`);
    console.error(`Known ids: ${all.map((t) => t.id).join(', ')}`);
    process.exit(1);
  }

  const modeTag = luma ? ' [luminance-as-alpha]'
    : green ? ' [green chroma-key]'
    : magenta ? ' [magenta chroma-key]' : '';
  console.log(`Generating ${targets.length} sprite(s) via ${MODEL}${modeTag}`);
  console.log(`Output dir: ${OUT_DIR}\n`);

  let ok = 0;
  let fail = 0;
  for (const t of targets) {
    process.stdout.write(`→ ${t.id} … `);
    try {
      let buf = await generate(t, t.style);
      if (chromaKey) buf = await chromaKey(buf);
      await writeFile(join(OUT_DIR, `${t.id}.png`), buf);
      console.log(`✓ ${(buf.length / 1024).toFixed(1)} KB`);
      ok++;
    } catch (e) {
      console.log(`✗ ${e.message}`);
      fail++;
    }
    // Polite throttle — image gen is heavy on the provider side.
    await new Promise((r) => setTimeout(r, 500));
  }
  console.log(`\nDone. ok=${ok} fail=${fail}.`);
  if (fail > 0) process.exit(1);
}

main().catch((e) => { console.error(e); process.exit(1); });
