// Diagnostic: measure how clean the alpha channel of each generated sword
// actually is. Prints per-file stats so we can tell whether:
//   (a) Gemini gave us a real transparent PNG (alpha:0 dominates the border)
//   (b) Gemini drew a solid-white rectangle (no alpha:0 at all, lots of
//       bright pixels at the border)
//   (c) Gemini gave alpha:0 in the middle of nowhere but the silhouette is
//       surrounded by a ring of bright pixels at alpha:255 (AA fringe).
//
// Usage:  node scripts/diag-alpha.mjs

import { readdir, readFile } from 'node:fs/promises';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import sharp from 'sharp';

const __dirname = dirname(fileURLToPath(import.meta.url));
const DIR = join(__dirname, '..', 'assets', 'swords');

async function analyze(path) {
  const buf = await readFile(path);
  const img = sharp(buf).ensureAlpha();
  const { data, info } = await img.raw().toBuffer({ resolveWithObject: true });
  const { width, height } = info;
  const total = width * height;
  let transparent = 0;
  let opaqueBrightFringe = 0;
  // Border ring stats: outermost 4-pixel band of the canvas.
  const band = 4;
  let borderTotal = 0;
  let borderTransparent = 0;
  let borderBright = 0;
  let borderBrightOpaque = 0;
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const off = (y * width + x) * 4;
      const a = data[off + 3];
      const r = data[off];
      const g = data[off + 1];
      const b = data[off + 2];
      const isBright = r > 230 && g > 230 && b > 230;
      if (a === 0) transparent++;
      const inBorder = x < band || y < band || x >= width - band || y >= height - band;
      if (inBorder) {
        borderTotal++;
        if (a === 0) borderTransparent++;
        if (isBright) borderBright++;
        if (isBright && a > 200) borderBrightOpaque++;
      }
      if (a > 200 && isBright) opaqueBrightFringe++;
    }
  }
  return {
    width, height, total,
    transparentPct: (transparent / total) * 100,
    brightOpaquePct: (opaqueBrightFringe / total) * 100,
    border: {
      transparentPct: (borderTransparent / borderTotal) * 100,
      brightPct: (borderBright / borderTotal) * 100,
      brightOpaquePct: (borderBrightOpaque / borderTotal) * 100,
    },
  };
}

const files = (await readdir(DIR))
  .filter((f) => f.endsWith('.png'))
  .sort();

console.log(
  'file'.padEnd(20),
  'size'.padEnd(11),
  'a=0%'.padStart(7),
  'bright_opaque%'.padStart(15),
  'border_a=0%'.padStart(12),
  'border_bright_opaque%'.padStart(22),
);
console.log('-'.repeat(95));
for (const f of files) {
  const s = await analyze(join(DIR, f));
  console.log(
    f.padEnd(20),
    `${s.width}x${s.height}`.padEnd(11),
    s.transparentPct.toFixed(1).padStart(7),
    s.brightOpaquePct.toFixed(2).padStart(15),
    s.border.transparentPct.toFixed(1).padStart(12),
    s.border.brightOpaquePct.toFixed(2).padStart(22),
  );
}
