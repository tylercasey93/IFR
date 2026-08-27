// Renders lesson compositions to content/rendered/<id>.mp4.
//
// Usage: node scripts/render.mjs --all
//        node scripts/render.mjs --lesson 03-holding-entries [--lesson ...]
import { execFileSync } from 'node:child_process';
import { existsSync, mkdirSync, readdirSync, statSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { bundle } from '@remotion/bundler';
import { renderMedia, selectComposition } from '@remotion/renderer';

const here = dirname(fileURLToPath(import.meta.url));
const pipelineRoot = join(here, '..');
const repoRoot = join(pipelineRoot, '..');
const outDir = join(repoRoot, 'content', 'rendered');
mkdirSync(outDir, { recursive: true });

// Rebuild the manifest so durations/captions reflect current content + audio.
execFileSync('node', [join(here, 'gen-manifest.mjs')], { stdio: 'inherit' });

const args = process.argv.slice(2);
const wanted = [];
for (let i = 0; i < args.length; i++) {
  if (args[i] === '--lesson') wanted.push(args[i + 1]);
}
const all = args.includes('--all');
if (!all && wanted.length === 0) {
  console.error('Usage: render.mjs --all | --lesson <id> [--lesson <id> ...]');
  process.exit(1);
}

// Prefer the preinstalled Playwright Chromium; Remotion downloads its own
// headless shell otherwise.
function findChromium() {
  // The full chrome binary has removed old-headless mode, which Remotion
  // uses — so only the standalone headless shell works here.
  const root = process.env.PLAYWRIGHT_BROWSERS_PATH ?? '/opt/pw-browsers';
  if (!existsSync(root)) return null;
  for (const dir of readdirSync(root)) {
    if (!dir.startsWith('chromium')) continue;
    const candidate = join(root, dir, 'chrome-linux', 'headless_shell');
    if (existsSync(candidate)) return candidate;
  }
  return null;
}
const browserExecutable = findChromium();
console.log(`chromium: ${browserExecutable ?? 'remotion-managed download'}`);

console.log('bundling composition…');
const serveUrl = await bundle({
  entryPoint: join(pipelineRoot, 'src', 'index.ts'),
  publicDir: join(pipelineRoot, 'public'),
});

const manifest = JSON.parse(
  (await import('node:fs')).readFileSync(
    join(pipelineRoot, 'src', 'generated', 'manifest.json'),
    'utf8'
  )
);
const ids = all ? manifest.lessons.map((l) => l.id) : wanted;

for (const id of ids) {
  const lesson = manifest.lessons.find((l) => l.id === id);
  if (!lesson) {
    console.error(`✗ unknown lesson id: ${id}`);
    process.exitCode = 1;
    continue;
  }
  const started = Date.now();
  const composition = await selectComposition({
    serveUrl,
    id,
    browserExecutable: browserExecutable ?? undefined,
  });
  const outputLocation = join(outDir, `${id}.mp4`);
  await renderMedia({
    serveUrl,
    composition,
    codec: 'h264',
    crf: 26,
    audioCodec: 'aac',
    outputLocation,
    browserExecutable: browserExecutable ?? undefined,
    chromiumOptions: { gl: 'angle-egl' },
    onProgress: ({ progress }) => {
      process.stdout.write(`\r  ${id}: ${(progress * 100).toFixed(0)}%   `);
    },
  });
  const mb = statSync(outputLocation).size / 1e6;
  const secs = (lesson.durationInFrames / manifest.fps).toFixed(1);
  console.log(
    `\r✓ ${id}: ${secs}s video, ${mb.toFixed(1)} MB, rendered in ${((Date.now() - started) / 1000).toFixed(0)}s`
  );
}
