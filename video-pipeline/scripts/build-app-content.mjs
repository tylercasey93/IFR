// Packages content for the iOS app: copies rendered MP4s and emits a compact
// lessons.json (only the fields the app needs) into FlashCards/FeedMedia/,
// which the Xcode project bundles as a folder reference.
import { copyFileSync, existsSync, mkdirSync, readFileSync, readdirSync, writeFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const repoRoot = join(here, '..', '..');
const lessonsDir = join(repoRoot, 'content', 'lessons');
const renderedDir = join(repoRoot, 'content', 'rendered');
const mediaDir = join(repoRoot, 'FlashCards', 'FeedMedia');
const videosDir = join(mediaDir, 'Videos');
mkdirSync(videosDir, { recursive: true });

const lessons = readdirSync(lessonsDir)
  .filter((f) => f.endsWith('.json'))
  .sort()
  .map((file) => JSON.parse(readFileSync(join(lessonsDir, file), 'utf8')));

let copied = 0;
const appLessons = lessons.map((lesson) => {
  const mp4 = join(renderedDir, `${lesson.id}.mp4`);
  const hasVideo = existsSync(mp4);
  if (hasVideo) {
    copyFileSync(mp4, join(videosDir, `${lesson.id}.mp4`));
    copied++;
  }
  return {
    id: lesson.id,
    title: lesson.title,
    topicArea: lesson.topicArea,
    hook: lesson.hook,
    hasVideo,
    references: lesson.references,
    quiz: lesson.quiz,
  };
});

writeFileSync(join(mediaDir, 'lessons.json'), JSON.stringify({ version: 1, lessons: appLessons }, null, 2));
console.log(`FeedMedia: ${appLessons.length} lessons, ${copied} videos copied`);
