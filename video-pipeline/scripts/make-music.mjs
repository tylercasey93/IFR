// Synthesizes the original audio kit sample-by-sample in Node — no samples,
// no licensing:
//   public/audio/music-loop.wav  — ~92 BPM lo-fi beat: kick/snare/hats,
//                                  bassline, warm chord stabs, sidechain pump
//   public/audio/sfx-whoosh.wav  — scene-transition whoosh (filtered noise sweep)
//   public/audio/sfx-ding.wav    — checklist ding (bell partials)
import { writeFileSync, mkdirSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const outDir = join(here, '..', 'public', 'audio');
mkdirSync(outDir, { recursive: true });

const SR = 44100;

// Deterministic noise so files are reproducible.
let seed = 424242;
const rand = () => {
  seed = (seed * 1103515245 + 12345) & 0x7fffffff;
  return seed / 0x7fffffff - 0.5;
};

function writeWav(path, left, right) {
  const n = left.length;
  let peak = 0;
  for (let i = 0; i < n; i++) peak = Math.max(peak, Math.abs(left[i]), Math.abs(right[i]));
  const gain = 0.72 / (peak || 1);
  const buffer = Buffer.alloc(44 + n * 4);
  buffer.write('RIFF', 0);
  buffer.writeUInt32LE(36 + n * 4, 4);
  buffer.write('WAVE', 8);
  buffer.write('fmt ', 12);
  buffer.writeUInt32LE(16, 16);
  buffer.writeUInt16LE(1, 20);
  buffer.writeUInt16LE(2, 22);
  buffer.writeUInt32LE(SR, 24);
  buffer.writeUInt32LE(SR * 4, 28);
  buffer.writeUInt16LE(4, 32);
  buffer.writeUInt16LE(16, 34);
  buffer.write('data', 36);
  buffer.writeUInt32LE(n * 4, 40);
  for (let i = 0; i < n; i++) {
    buffer.writeInt16LE(Math.round(left[i] * gain * 32767), 44 + i * 4);
    buffer.writeInt16LE(Math.round(right[i] * gain * 32767), 46 + i * 4);
  }
  writeFileSync(path, buffer);
  return buffer.length;
}

// ---------------- music loop ----------------
const BPM = 92;
const BEAT = 60 / BPM;               // 0.652s
const BAR = BEAT * 4;
const BARS = 8;                      // exact 8-bar loop ≈ 20.9s
const N = Math.round(SR * BAR * BARS);

// Two-bar chord cycle: Am7, Fmaj7, Cmaj7, G6 — one chord per bar, roots for bass.
const chords = [
  { notes: [220.0, 261.63, 329.63, 392.0], root: 110.0 },
  { notes: [174.61, 220.0, 261.63, 329.63], root: 87.31 },
  { notes: [196.0, 246.94, 293.66, 329.63], root: 98.0 },
  { notes: [164.81, 196.0, 246.94, 293.66], root: 82.41 },
];

const left = new Float64Array(N);
const right = new Float64Array(N);
let noiseLP = 0;

for (let i = 0; i < N; i++) {
  const t = i / SR;
  const beatPos = (t / BEAT) % 4;          // position within the bar, in beats
  const bar = Math.floor(t / BAR);
  const chord = chords[bar % chords.length];

  // --- kick on 1 and 3 (with a lazy extra on the 3.5 every other bar) ---
  let kickEnv = 0;
  const kickTimes = bar % 2 === 0 ? [0, 2] : [0, 2, 3.5];
  for (const kt of kickTimes) {
    const dt = (beatPos - kt) * BEAT;
    if (dt >= 0 && dt < 0.18) {
      const env = Math.exp(-dt * 26);
      kickEnv = Math.max(kickEnv, env);
      left[i] += Math.sin(2 * Math.PI * (52 + 60 * Math.exp(-dt * 40)) * dt) * env * 0.9;
      right[i] += Math.sin(2 * Math.PI * (52 + 60 * Math.exp(-dt * 40)) * dt) * env * 0.9;
    }
  }

  // --- snare on 2 and 4 (filtered noise + body tone) ---
  for (const st of [1, 3]) {
    const dt = (beatPos - st) * BEAT;
    if (dt >= 0 && dt < 0.16) {
      const env = Math.exp(-dt * 30);
      const snap = rand() * env * 0.5;
      const body = Math.sin(2 * Math.PI * 190 * dt) * env * 0.25;
      left[i] += snap * 0.9 + body;
      right[i] += snap * 1.1 + body;
    }
  }

  // --- closed hats on 8ths with swing + velocity ---
  const eighth = Math.floor(beatPos * 2);
  const swing = eighth % 2 === 1 ? 0.06 : 0;
  const hatTime = eighth / 2 + swing;
  const hdt = (beatPos - hatTime) * BEAT;
  if (hdt >= 0 && hdt < 0.05) {
    const vel = eighth % 2 === 0 ? 0.16 : 0.1;
    const hp = rand() - noiseLP; // crude high-pass
    left[i] += hp * Math.exp(-hdt * 90) * vel;
    right[i] += hp * Math.exp(-hdt * 90) * vel * 1.15;
  }

  // --- bass: root notes, pushing 8ths on beats 1 and the "and" of 2 ---
  const bassPattern = [
    [0, 1.0], [1.5, 0.6], [2, 0.9], [3.5, 0.5],
  ];
  for (const [bt, vel] of bassPattern) {
    const dt = (beatPos - bt) * BEAT;
    if (dt >= 0 && dt < BEAT * 0.9) {
      const env = Math.min(1, dt / 0.01) * Math.exp(-dt * 5);
      const s = Math.sin(2 * Math.PI * chord.root * t) + 0.4 * Math.sin(2 * Math.PI * chord.root * 2 * t);
      left[i] += s * env * vel * 0.34;
      right[i] += s * env * vel * 0.34;
    }
  }

  // --- chord stabs on the off-beats (the "and" of each beat) ---
  const stabIdx = Math.floor(beatPos - 0.5);
  const sdt = (beatPos - (stabIdx + 0.5)) * BEAT;
  if (sdt >= 0 && sdt < 0.4 && stabIdx >= 0) {
    const env = Math.min(1, sdt / 0.015) * Math.exp(-sdt * 7);
    let s = 0;
    for (const f of chord.notes) {
      s += Math.sin(2 * Math.PI * f * t) * 0.11;
      s += Math.sin(2 * Math.PI * f * 1.004 * t) * 0.05;
    }
    left[i] += s * env * (stabIdx % 2 === 0 ? 1 : 0.7);
    right[i] += s * env * (stabIdx % 2 === 0 ? 0.8 : 1);
  }

  // --- vinyl hiss, low-passed ---
  noiseLP += 0.02 * (rand() - noiseLP);
  left[i] += noiseLP * 0.35;
  right[i] += noiseLP * 0.35;

  // --- sidechain pump keyed to the kick ---
  const duck = 1 - kickEnv * 0.35;
  left[i] *= duck;
  right[i] *= duck;
}

const musicBytes = writeWav(join(outDir, 'music-loop.wav'), left, right);
console.log(`music bed: ${(BAR * BARS).toFixed(1)}s @ ${BPM} BPM, ${(musicBytes / 1e6).toFixed(1)} MB`);

// ---------------- whoosh (scene transition) ----------------
{
  const dur = 0.38;
  const n = Math.round(SR * dur);
  const l = new Float64Array(n);
  const r = new Float64Array(n);
  let lp = 0;
  for (let i = 0; i < n; i++) {
    const t = i / n; // 0..1
    // band swept upward, envelope rises then snaps off
    const cutoff = 0.04 + t * 0.5;
    lp += cutoff * (rand() - lp);
    const env = Math.sin(Math.PI * Math.min(1, t * 1.15)) ** 2;
    const pan = (t - 0.5) * 1.4; // sweeps left → right
    l[i] = lp * env * (1 - pan) * 2.2;
    r[i] = lp * env * (1 + pan) * 2.2;
  }
  writeWav(join(outDir, 'sfx-whoosh.wav'), l, r);
  console.log('sfx-whoosh: 0.38s');
}

// ---------------- ding (checklist tick) ----------------
{
  const dur = 0.5;
  const n = Math.round(SR * dur);
  const l = new Float64Array(n);
  const r = new Float64Array(n);
  for (let i = 0; i < n; i++) {
    const t = i / SR;
    const env = Math.exp(-t * 9);
    const s =
      Math.sin(2 * Math.PI * 1318.5 * t) * 0.5 + // E6
      Math.sin(2 * Math.PI * 1975.5 * t) * 0.25 + // B6 partial
      Math.sin(2 * Math.PI * 2637 * t) * 0.12;
    l[i] = s * env;
    r[i] = s * env * 0.9;
  }
  writeWav(join(outDir, 'sfx-ding.wav'), l, r);
  console.log('sfx-ding: 0.5s');
}
