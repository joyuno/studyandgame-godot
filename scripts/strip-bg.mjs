// Flood-fills white-ish pixels from the image edges and turns them
// transparent. Interior white (chef hat, wizard beard, ghost body) survives
// because the fill never reaches it through dark outlines.
//
// Pollinations returns JPEG bytes even when the URL extension is .png,
// so sharp is used for format-agnostic decode + true PNG (RGBA) re-encode.
//
// Usage:  node scripts/strip-bg.mjs   # processes every PNG in characters_ai/

import { readFile, writeFile, readdir } from 'node:fs/promises';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import sharp from 'sharp';

const __dirname = dirname(fileURLToPath(import.meta.url));
const SRC_DIRS = [
  join(__dirname, '..', 'assets', 'characters', 'characters'),
  join(__dirname, '..', 'assets', 'characters', 'bosses'),
];

// Pass 1: aggressive white removal (RGB ≥ 235, fully saturated edges).
// Pass 2: drop-shadow cleanup (light-grey low-saturation pixels, but only
// reachable via flood from edges so we never touch character interior).
const WHITE_THRESHOLD = 235;
// Boss shadows sample as ~RGB(170-220, 200-220, 195-215) — light cool greys
// with channel deltas up to ~30. Character body outlines bottom out around
// V=30-50, so V_MIN=145 keeps them safe while still catching shadow falloff.
const SHADOW_VALUE_MIN = 145;
const SHADOW_SATURATION_MAX = 35;

function maxChannelDiff(r, g, b) {
  return Math.max(Math.abs(r - g), Math.abs(g - b), Math.abs(r - b));
}

function isWhiteish(r, g, b) {
  return r >= WHITE_THRESHOLD && g >= WHITE_THRESHOLD && b >= WHITE_THRESHOLD;
}

// Light grey (the AI's drop shadow), but NOT character outline or coloured tone.
function isShadowGrey(r, g, b) {
  if (r < SHADOW_VALUE_MIN || g < SHADOW_VALUE_MIN || b < SHADOW_VALUE_MIN) return false;
  if (r >= WHITE_THRESHOLD && g >= WHITE_THRESHOLD && b >= WHITE_THRESHOLD) return true;
  return maxChannelDiff(r, g, b) <= SHADOW_SATURATION_MAX;
}

function floodFillFromEdges(rgba, width, height, predicate) {
  const visited = new Uint8Array(width * height);
  const queue = [];
  const push = (x, y) => {
    if (x < 0 || y < 0 || x >= width || y >= height) return;
    const idx = y * width + x;
    if (visited[idx]) return;
    const off = idx * 4;
    if (rgba[off + 3] === 0) {
      // Already transparent — mark visited so we walk through it and reach
      // shadow pixels surrounded by transparent neighbours.
      visited[idx] = 1;
      queue.push(idx);
      return;
    }
    if (!predicate(rgba[off], rgba[off + 1], rgba[off + 2])) return;
    visited[idx] = 1;
    queue.push(idx);
  };

  for (let x = 0; x < width; x++) {
    push(x, 0);
    push(x, height - 1);
  }
  for (let y = 0; y < height; y++) {
    push(0, y);
    push(width - 1, y);
  }

  while (queue.length) {
    const idx = queue.pop();
    rgba[idx * 4 + 3] = 0;
    const x = idx % width;
    const y = (idx - x) / width;
    push(x + 1, y);
    push(x - 1, y);
    push(x, y + 1);
    push(x, y - 1);
  }
}

function floodFillToTransparent(rgba, width, height) {
  floodFillFromEdges(rgba, width, height, isWhiteish);
  floodFillFromEdges(rgba, width, height, isShadowGrey);
}

async function processFile(path) {
  const input = await readFile(path);
  const img = sharp(input).ensureAlpha();
  const { data, info } = await img.raw().toBuffer({ resolveWithObject: true });
  floodFillToTransparent(data, info.width, info.height);
  const out = await sharp(data, {
    raw: { width: info.width, height: info.height, channels: 4 },
  })
    .png({ compressionLevel: 9 })
    .toBuffer();
  await writeFile(path, out);
  return out.length;
}

async function main() {
  for (const dir of SRC_DIRS) {
    const files = (await readdir(dir)).filter((f) => f.endsWith('.png'));
    for (const file of files) {
      const path = join(dir, file);
      const size = await processFile(path);
      console.log(`✓ ${file} (${(size / 1024).toFixed(1)} KB)`);
    }
  }
}

main().catch((e) => { console.error(e); process.exit(1); });
