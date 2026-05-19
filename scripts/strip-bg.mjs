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
const SRC_DIR = join(__dirname, '..', 'assets', 'characters_ai');

const WHITE_THRESHOLD = 235;

function isWhiteish(r, g, b) {
  return r >= WHITE_THRESHOLD && g >= WHITE_THRESHOLD && b >= WHITE_THRESHOLD;
}

function floodFillToTransparent(rgba, width, height) {
  const visited = new Uint8Array(width * height);
  const queue = [];
  const push = (x, y) => {
    if (x < 0 || y < 0 || x >= width || y >= height) return;
    const idx = y * width + x;
    if (visited[idx]) return;
    const off = idx * 4;
    if (!isWhiteish(rgba[off], rgba[off + 1], rgba[off + 2])) return;
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
    rgba[idx * 4 + 3] = 0;  // alpha = 0
    const x = idx % width;
    const y = (idx - x) / width;
    push(x + 1, y);
    push(x - 1, y);
    push(x, y + 1);
    push(x, y - 1);
  }
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
  const files = (await readdir(SRC_DIR)).filter((f) => f.endsWith('.png'));
  for (const file of files) {
    const path = join(SRC_DIR, file);
    const size = await processFile(path);
    console.log(`✓ ${file} (${(size / 1024).toFixed(1)} KB)`);
  }
}

main().catch((e) => { console.error(e); process.exit(1); });
