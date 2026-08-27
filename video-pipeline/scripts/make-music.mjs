// Synthesizes an original ~24s ambient lo-fi music bed as a WAV, written
// sample-by-sample in Node — no samples, no external audio, no licensing.
// Output: public/audio/music-loop.wav (looped by the composition).
import { writeFileSync, mkdirSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const outDir = join(here, '..', 'public', 'audio');
mkdirSync(outDir, { recursive: true });

const SR = 44100;
const SECONDS = 24;
const N = SR * SECONDS;

// Four mellow chords, 6s each (Am7 → Fmaj7 → Cmaj7 → G6), voiced low.
const chords = [
  [220.0, 261.63, 329.63, 392.0],
  [174.61, 220.0, 261.63, 329.63],
  [130.81, 164.81, 196.0, 246.94],
  [196.0, 246.94, 293.66, 329.63],
];
const CHORD_SEC = SECONDS / chords.length;

// Deterministic pseudo-noise so the file is reproducible.
let seed = 424242;
const rand = () => {
  seed = (seed * 1103515245 + 12345) & 0x7fffffff;
  return seed / 0x7fffffff - 0.5;
};

const left = new Float64Array(N);
const right = new Float64Array(N);
let noiseLP = 0;

for (let i = 0; i < N; i++) {
  const t = i / SR;
  const chordIdx = Math.min(chords.length - 1, Math.floor(t / CHORD_SEC));
  const tin = t - chordIdx * CHORD_SEC;

  // Per-chord envelope: slow swell in/out so chord changes never click.
  const env =
    Math.min(1, tin / 1.2) * Math.min(1, (CHORD_SEC - tin) / 1.4) * 0.9 + 0.1;

  // Warm pad: fundamental + soft detuned double + faint octave.
  let s = 0;
  for (const f of chords[chordIdx]) {
    s += Math.sin(2 * Math.PI * f * t) * 0.20;
    s += Math.sin(2 * Math.PI * (f * 1.003) * t) * 0.10;
    s += Math.sin(2 * Math.PI * (f / 2) * t) * 0.08;
  }
  s *= env;

  // Slow breathing LFO over the whole bed.
  s *= 0.75 + 0.25 * Math.sin(2 * Math.PI * t * 0.08);

  // Vinyl-ish hiss, heavily low-passed.
  noiseLP += 0.02 * (rand() - noiseLP);
  s += noiseLP * 0.6;

  // Gentle stereo width via phase-offset tremolo.
  const width = 0.06 * Math.sin(2 * Math.PI * t * 0.11);
  left[i] = s * (1 + width);
  right[i] = s * (1 - width);
}

// Normalize to a quiet bed level (the composition ducks it further).
let peak = 0;
for (let i = 0; i < N; i++) peak = Math.max(peak, Math.abs(left[i]), Math.abs(right[i]));
const gain = 0.5 / peak;

const buffer = Buffer.alloc(44 + N * 4);
buffer.write('RIFF', 0);
buffer.writeUInt32LE(36 + N * 4, 4);
buffer.write('WAVE', 8);
buffer.write('fmt ', 12);
buffer.writeUInt32LE(16, 16);
buffer.writeUInt16LE(1, 20); // PCM
buffer.writeUInt16LE(2, 22); // stereo
buffer.writeUInt32LE(SR, 24);
buffer.writeUInt32LE(SR * 4, 28);
buffer.writeUInt16LE(4, 32);
buffer.writeUInt16LE(16, 34);
buffer.write('data', 36);
buffer.writeUInt32LE(N * 4, 40);
for (let i = 0; i < N; i++) {
  buffer.writeInt16LE(Math.round(left[i] * gain * 32767), 44 + i * 4);
  buffer.writeInt16LE(Math.round(right[i] * gain * 32767), 46 + i * 4);
}

const outPath = join(outDir, 'music-loop.wav');
writeFileSync(outPath, buffer);
console.log(`music bed written: ${outPath} (${SECONDS}s, ${(buffer.length / 1e6).toFixed(1)} MB)`);
