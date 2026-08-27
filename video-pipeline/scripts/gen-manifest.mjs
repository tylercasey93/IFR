// Builds src/generated/manifest.json from content/lessons/*.json plus any
// TTS timing data in content/audio/<lesson>/timing.json. Scene durations and
// caption chunk timings are baked here so the Remotion compositions are
// deterministic. Run automatically by render.mjs; safe to run standalone.
import { readFileSync, readdirSync, writeFileSync, mkdirSync, existsSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const pipelineRoot = join(here, '..');
const repoRoot = join(pipelineRoot, '..');
const lessonsDir = join(repoRoot, 'content', 'lessons');
const audioDir = join(repoRoot, 'content', 'audio');
const publicDir = join(pipelineRoot, 'public');

const FPS = 30;
const WORDS_PER_MINUTE = 150; // captions-only fallback reading speed
const AUDIO_TAIL_SEC = 0.5;   // breathing room after narration ends
const MAX_CHUNK_WORDS = 6;

// Split narration into caption chunks of <= MAX_CHUNK_WORDS words, preferring
// to break at punctuation so chunks read naturally.
function chunkNarration(narration) {
  const words = narration.split(/\s+/).filter(Boolean);
  const chunks = [];
  let current = [];
  for (const word of words) {
    current.push(word);
    const endsClause = /[.!?;:,—]$/.test(word);
    if (current.length >= MAX_CHUNK_WORDS || (endsClause && current.length >= 3)) {
      chunks.push(current.join(' '));
      current = [];
    }
  }
  if (current.length) chunks.push(current.join(' '));
  return chunks;
}

function sceneDurationSec(scene, timing) {
  const min = scene.minDurationSec ?? 3;
  if (timing) return Math.max(min, timing.durationSec + AUDIO_TAIL_SEC);
  const words = scene.narration.split(/\s+/).filter(Boolean).length;
  return Math.max(min, (words / WORDS_PER_MINUTE) * 60 + 0.8);
}

function buildCaptions(scene, durationInFrames) {
  const chunks = chunkNarration(scene.narration);
  const totalChars = chunks.reduce((n, c) => n + c.length, 0) || 1;
  // Captions occupy the narrated portion: leave a short head and the tail.
  const head = Math.round(0.15 * FPS);
  const usable = durationInFrames - head - Math.round(AUDIO_TAIL_SEC * FPS);
  let cursor = head;
  return chunks.map((text, i) => {
    const share = Math.round((text.length / totalChars) * usable);
    const startFrame = cursor;
    const endFrame = i === chunks.length - 1 ? head + usable : cursor + share;
    cursor = endFrame;
    return { text, startFrame, endFrame: Math.max(endFrame, startFrame + 4) };
  });
}

const files = readdirSync(lessonsDir).filter((f) => f.endsWith('.json')).sort();
const lessons = files.map((file, index) => {
  const lesson = JSON.parse(readFileSync(join(lessonsDir, file), 'utf8'));

  let timingById = null;
  const timingPath = join(audioDir, lesson.id, 'timing.json');
  if (existsSync(timingPath)) {
    const parsed = JSON.parse(readFileSync(timingPath, 'utf8'));
    timingById = Object.fromEntries(parsed.scenes.map((s) => [s.sceneId, s]));
  }

  const scenes = lesson.scenes.map((scene) => {
    const timing = timingById?.[scene.id] ?? null;
    const audioRel = `audio/${lesson.id}/${scene.id}.mp3`;
    const hasAudio = timing && existsSync(join(publicDir, audioRel));
    const durationInFrames = Math.round(sceneDurationSec(scene, timing) * FPS);
    return {
      id: scene.id,
      kind: scene.kind,
      narration: scene.narration,
      onScreenText: scene.onScreenText,
      diagram: scene.diagram,
      duke: scene.duke,
      durationInFrames,
      audioSrc: hasAudio ? audioRel : null,
      captions: buildCaptions(scene, durationInFrames),
    };
  });

  return {
    id: lesson.id,
    index,
    title: lesson.title,
    topicArea: lesson.topicArea,
    hook: lesson.hook,
    references: lesson.references,
    scenes,
    durationInFrames: scenes.reduce((n, s) => n + s.durationInFrames, 0),
  };
});

const musicRel = 'audio/music-loop.wav';
const manifest = {
  fps: FPS,
  width: 1080,
  height: 1920,
  musicSrc: existsSync(join(publicDir, musicRel)) ? musicRel : null,
  lessons,
};

const outDir = join(pipelineRoot, 'src', 'generated');
mkdirSync(outDir, { recursive: true });
writeFileSync(join(outDir, 'manifest.json'), JSON.stringify(manifest, null, 2));

const narrated = lessons.filter((l) => l.scenes.every((s) => s.audioSrc)).length;
console.log(
  `manifest: ${lessons.length} lessons (${narrated} fully narrated, ` +
    `${lessons.length - narrated} captions-only), music: ${manifest.musicSrc ? 'yes' : 'no'}`
);
