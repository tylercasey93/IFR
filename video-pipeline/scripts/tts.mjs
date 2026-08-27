// Generates per-scene narration audio with OpenAI TTS (or ElevenLabs) and a
// timing.json used by gen-manifest.mjs. Degrades gracefully: with no API key
// it prints a notice and exits 0 — renders then use captions-only timing.
//
// Usage: node scripts/tts.mjs [--lesson <id>] [--force]
import { readFileSync, readdirSync, writeFileSync, mkdirSync, existsSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { parseFile } from 'music-metadata';

const here = dirname(fileURLToPath(import.meta.url));
const pipelineRoot = join(here, '..');
const repoRoot = join(pipelineRoot, '..');
const lessonsDir = join(repoRoot, 'content', 'lessons');
const timingRoot = join(repoRoot, 'content', 'audio');
const audioRoot = join(pipelineRoot, 'public', 'audio');

const args = process.argv.slice(2);
const lessonFilter = args.includes('--lesson') ? args[args.indexOf('--lesson') + 1] : null;
const force = args.includes('--force');

const OPENAI_KEY = process.env.OPENAI_API_KEY;
const ELEVEN_KEY = process.env.ELEVENLABS_API_KEY;

const DUKE_VOICE_INSTRUCTIONS =
  'You are Duke, a grizzled veteran flight instructor in his 60s: gravelly, warm, ' +
  'unhurried, dry as the desert. Speak at a measured instructor pace with deadpan ' +
  'delivery on the jokes — never laugh at them yourself. Slight gruffness, like a ' +
  'man who has briefed a thousand student pilots and buried none of them.';

async function openaiTTS(text) {
  const res = await fetch('https://api.openai.com/v1/audio/speech', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${OPENAI_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: 'gpt-4o-mini-tts',
      voice: 'onyx',
      input: text,
      instructions: DUKE_VOICE_INSTRUCTIONS,
      response_format: 'mp3',
    }),
  });
  if (!res.ok) throw new Error(`OpenAI TTS ${res.status}: ${await res.text()}`);
  return Buffer.from(await res.arrayBuffer());
}

async function elevenTTS(text) {
  // "Old radio hand" style voice; George is a reasonable stock gravelly pick.
  const voiceId = process.env.ELEVENLABS_VOICE_ID ?? 'JBFqnCBsd6RMkjVDRZzb';
  const res = await fetch(`https://api.elevenlabs.io/v1/text-to-speech/${voiceId}`, {
    method: 'POST',
    headers: { 'xi-api-key': ELEVEN_KEY, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      text,
      model_id: 'eleven_multilingual_v2',
      voice_settings: { stability: 0.55, similarity_boost: 0.7, style: 0.35 },
    }),
  });
  if (!res.ok) throw new Error(`ElevenLabs ${res.status}: ${await res.text()}`);
  return Buffer.from(await res.arrayBuffer());
}

if (!OPENAI_KEY && !ELEVEN_KEY) {
  console.log(
    'No OPENAI_API_KEY or ELEVENLABS_API_KEY set — skipping narration. ' +
      'Videos will render captions-only with estimated timing.'
  );
  process.exit(0);
}
const synth = OPENAI_KEY ? openaiTTS : elevenTTS;
console.log(`TTS provider: ${OPENAI_KEY ? 'OpenAI (gpt-4o-mini-tts, onyx)' : 'ElevenLabs'}`);

const files = readdirSync(lessonsDir)
  .filter((f) => f.endsWith('.json'))
  .filter((f) => !lessonFilter || f === `${lessonFilter}.json`)
  .sort();
if (files.length === 0) {
  console.error(`No lessons matched${lessonFilter ? ` --lesson ${lessonFilter}` : ''}`);
  process.exit(1);
}

for (const file of files) {
  const lesson = JSON.parse(readFileSync(join(lessonsDir, file), 'utf8'));
  const audioDir = join(audioRoot, lesson.id);
  const timingDir = join(timingRoot, lesson.id);
  mkdirSync(audioDir, { recursive: true });
  mkdirSync(timingDir, { recursive: true });

  const scenes = [];
  for (const scene of lesson.scenes) {
    const mp3Path = join(audioDir, `${scene.id}.mp3`);
    if (force || !existsSync(mp3Path)) {
      process.stdout.write(`  ${lesson.id}/${scene.id} … `);
      const audio = await synth(scene.narration);
      writeFileSync(mp3Path, audio);
      console.log(`${(audio.length / 1024).toFixed(0)} KB`);
      // simple pacing to stay well under rate limits
      await new Promise((r) => setTimeout(r, 250));
    }
    const meta = await parseFile(mp3Path);
    scenes.push({ sceneId: scene.id, durationSec: meta.format.duration ?? 3 });
  }

  writeFileSync(
    join(timingDir, 'timing.json'),
    JSON.stringify({ lessonId: lesson.id, scenes }, null, 2)
  );
  const total = scenes.reduce((n, s) => n + s.durationSec, 0);
  console.log(`✓ ${lesson.id}: ${scenes.length} scenes, ${total.toFixed(1)}s narration`);
}
