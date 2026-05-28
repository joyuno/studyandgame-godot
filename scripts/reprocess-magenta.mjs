// Re-runs the (updated) magenta chroma-key on PNGs that were already produced
// against a magenta-ish background. No API call — pure local post-process.
// Use when you tightened chromaKeyMagenta thresholds and want to apply the
// new logic without burning more OpenRouter credits.
//
// Usage:  node scripts/reprocess-magenta.mjs sword_05 sword_09 sword_10 sword_11

import { readFile, writeFile } from 'node:fs/promises';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import sharp from 'sharp';

const __dirname = dirname(fileURLToPath(import.meta.url));
const OUT_DIR = join(__dirname, '..', 'assets', 'swords');

// Inline copy of the chromaKeyMagenta logic from gen-swords-openrouter.mjs.
// Kept in sync manually — they're tiny.
async function chromaKeyMagenta(pngBuf) {
  const { data, info } = await sharp(pngBuf).ensureAlpha().raw()
    .toBuffer({ resolveWithObject: true });
  for (let i = 0; i < data.length; i += 4) {
    const r = data[i], g = data[i + 1], b = data[i + 2];
    const valid = r >= 200 && g <= r - 40 && b >= 60 && b <= r + 20;
    if (!valid) continue;
    const score = r - g;
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

const ids = process.argv.slice(2);
if (ids.length === 0) {
  console.error('Usage: node scripts/reprocess-magenta.mjs <id> [<id>...]');
  process.exit(1);
}

for (const id of ids) {
  const path = join(OUT_DIR, `${id}.png`);
  process.stdout.write(`→ ${id} … `);
  try {
    const buf = await readFile(path);
    const out = await chromaKeyMagenta(buf);
    await writeFile(path, out);
    console.log(`✓ ${(out.length / 1024).toFixed(1)} KB`);
  } catch (e) {
    console.log(`✗ ${e.message}`);
  }
}
