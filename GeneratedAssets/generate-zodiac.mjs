#!/usr/bin/env node
/**
 * Regenerate 12 zodiac emblems with gpt-image-2.
 * Style: celestial line-art like the sun reference — neutral, no cute faces.
 * Model has no transparent bg support → generate on pure white, then
 * strip near-white pixels to alpha via Python/Pillow.
 *
 * Usage:
 *   OPENAI_API_KEY=sk-... node GeneratedAssets/generate-zodiac.mjs
 */

import { mkdir, writeFile, access } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const OUT_DIR = path.join(__dirname, "Zodiac");
const RAW_DIR = path.join(__dirname, "ZodiacRaw");

const STYLE = [
  "Single centered zodiac emblem icon for a mobile astrology app.",
  "Art style reference: mystical celestial sun illustration — bold dark outlines,",
  "wavy flame-like radiating curves, fine parallel hatch / flow lines inside shapes,",
  "small four-pointed spark stars and tiny dots around the emblem,",
  "subtle grain texture on the emblem only, graphic sticker look, high contrast.",
  "Mood: elegant, calm, symbolic, adult-friendly — NOT cute kawaii, NOT baby face,",
  "NOT long eyelashes, NOT blush cheeks, NOT cartoon mascot.",
  "Prefer symbolic animal / glyph forms over adorable human faces.",
  "A face is optional and only if it stays minimal and neutral (no cute expression).",
  "CRITICAL: background must be a flat pure solid white (#FFFFFF) with zero texture,",
  "no vignette, no gradient, no shadows under the emblem — clean cutout-ready plate.",
  "No text, no letters, no watermark, no frame, no border.",
  "Square composition, emblem fills most of the canvas.",
].join(" ");

const SIGNS = [
  {
    id: "aries",
    name: "Aries ram emblem",
    colors: "coral red, scarlet, muted rose outlines",
    subject: "stylized ram with bold curved horns as the main graphic, flowing hatch lines in the horns",
  },
  {
    id: "taurus",
    name: "Taurus bull emblem",
    colors: "sage green, soft olive, cream accents",
    subject: "stylized bull head with elegant curved horns, botanical-flow line texture",
  },
  {
    id: "gemini",
    name: "Gemini twins emblem",
    colors: "periwinkle blue, pale lavender, cool silver accents",
    subject: "two mirrored abstract twin silhouettes or dual pillars linked by airy flowing lines",
  },
  {
    id: "cancer",
    name: "Cancer crab emblem",
    colors: "pearl silver-blue, soft moon white, gentle teal",
    subject: "stylized crab with crescent-shell curves and soft claw arcs, lunar spark accents",
  },
  {
    id: "leo",
    name: "Leo lion emblem",
    colors: "rich gold, amber, soft orange — warmer than lemon yellow",
    subject: "stylized lion head with a radiant wavy mane like soft sun rays, regal and calm",
  },
  {
    id: "virgo",
    name: "Virgo maiden emblem",
    colors: "soft wheat gold, muted sage, ivory accents",
    subject: "abstract maiden silhouette with wheat / botanical flowing hair lines, refined and quiet",
  },
  {
    id: "libra",
    name: "Libra scales emblem",
    colors: "dusty rose, soft blush pink, pale champagne gold",
    subject: "elegant balanced scales as the main symbol, floating celestial spark accents",
  },
  {
    id: "scorpio",
    name: "Scorpio scorpion emblem",
    colors: "deep burgundy, wine red, soft mauve",
    subject: "stylized scorpion with a curved elegant tail, sharp but refined linework",
  },
  {
    id: "sagittarius",
    name: "Sagittarius archer emblem",
    colors: "burnt orange, copper amber, soft terracotta",
    subject: "stylized bow and arrow with dynamic flowing curves, centaur optional as abstract silhouette",
  },
  {
    id: "capricorn",
    name: "Capricorn sea-goat emblem",
    colors: "slate teal, charcoal blue-green, soft frost accents",
    subject: "stylized sea-goat: goat head with horn and a fish-tail swirl, composed and grounded",
  },
  {
    id: "aquarius",
    name: "Aquarius water-bearer emblem",
    colors: "electric cyan, cool aqua, soft ice blue",
    subject: "abstract water-bearer vessel pouring wavy flowing water lines, airy celestial accents",
  },
  {
    id: "pisces",
    name: "Pisces fish emblem",
    colors: "seafoam green, aqua violet, soft lilac",
    subject: "two stylized fish in a circular yin composition, dreamy flowing water lines",
  },
];

async function generateOne(apiKey, sign) {
  const prompt = [
    STYLE,
    `Subject: ${sign.name}.`,
    `Visual focus: ${sign.subject}.`,
    `Color palette: ${sign.colors}. Keep outlines darker than the fill.`,
  ].join(" ");

  const response = await fetch("https://api.openai.com/v1/images/generations", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: "gpt-image-2",
      prompt,
      size: "1024x1024",
      quality: "high",
      output_format: "png",
    }),
  });

  if (!response.ok) {
    const detail = await response.text();
    throw new Error(`${sign.id}: ${response.status} ${detail}`);
  }

  const json = await response.json();
  const b64 = json.data?.[0]?.b64_json;
  if (!b64) throw new Error(`${sign.id}: empty image payload`);

  const rawFile = path.join(RAW_DIR, `${sign.id}.png`);
  const outFile = path.join(OUT_DIR, `${sign.id}.png`);
  await writeFile(rawFile, Buffer.from(b64, "base64"));
  stripWhiteBackground(rawFile, outFile);
  return outFile;
}

function stripWhiteBackground(inputPath, outputPath) {
  const script = `
from PIL import Image
import sys
src, dst = sys.argv[1], sys.argv[2]
im = Image.open(src).convert("RGBA")
pixels = im.load()
w, h = im.size
# Near-white → transparent. Soft edge for anti-alias fringing.
for y in range(h):
    for x in range(w):
        r, g, b, a = pixels[x, y]
        # How "white" is this pixel?
        darkness = (255 - r) + (255 - g) + (255 - b)
        if darkness < 28:
            pixels[x, y] = (r, g, b, 0)
        elif darkness < 70:
            # fade fringe
            alpha = int(255 * (darkness - 28) / (70 - 28))
            pixels[x, y] = (r, g, b, alpha)
im.save(dst, "PNG")
`;
  const result = spawnSync("python3", ["-c", script, inputPath, outputPath], {
    encoding: "utf8",
  });
  if (result.status !== 0) {
    throw new Error(`bg strip failed: ${result.stderr || result.stdout}`);
  }
}

async function ensurePillow() {
  const check = spawnSync("python3", ["-c", "from PIL import Image"], { encoding: "utf8" });
  if (check.status === 0) return;
  console.log("Installing Pillow…");
  const install = spawnSync("python3", ["-m", "pip", "install", "--user", "Pillow"], {
    encoding: "utf8",
  });
  if (install.status !== 0) {
    throw new Error(`Pillow install failed: ${install.stderr || install.stdout}`);
  }
}

async function main() {
  const apiKey = process.env.OPENAI_API_KEY?.trim();
  if (!apiKey) {
    console.error("Missing OPENAI_API_KEY");
    process.exit(1);
  }

  await ensurePillow();
  await mkdir(OUT_DIR, { recursive: true });
  await mkdir(RAW_DIR, { recursive: true });
  console.log(`Raw → ${RAW_DIR}`);
  console.log(`Transparent → ${OUT_DIR}`);
  console.log(`Model: gpt-image-2 | signs: ${SIGNS.length}`);

  for (const sign of SIGNS) {
    process.stdout.write(`→ ${sign.id} ... `);
    try {
      const file = await generateOne(apiKey, sign);
      console.log(`ok (${path.basename(file)})`);
    } catch (error) {
      console.log("FAIL");
      console.error(String(error.message || error));
      process.exitCode = 1;
    }
  }
}

main();
