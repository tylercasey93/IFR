// Validates every lesson JSON in content/lessons/ against the schema, plus
// cross-cutting rules the schema can't express (unique ids, scene ordering,
// exactly one sources scene at the end).
import { readFileSync, readdirSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import Ajv from 'ajv';

const root = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const schemaPath = join(root, 'content', 'schema', 'lesson.schema.json');
const lessonsDir = join(root, 'content', 'lessons');

const ajv = new Ajv({ allErrors: true });
const validate = ajv.compile(JSON.parse(readFileSync(schemaPath, 'utf8')));

const files = readdirSync(lessonsDir).filter((f) => f.endsWith('.json')).sort();
if (files.length === 0) {
  console.error('No lesson files found in content/lessons/');
  process.exit(1);
}

let failures = 0;
const seenIds = new Set();

for (const file of files) {
  const problems = [];
  let lesson;
  try {
    lesson = JSON.parse(readFileSync(join(lessonsDir, file), 'utf8'));
  } catch (err) {
    console.error(`✗ ${file}: invalid JSON — ${err.message}`);
    failures++;
    continue;
  }

  if (!validate(lesson)) {
    for (const err of validate.errors) {
      problems.push(`schema: ${err.instancePath || '/'} ${err.message}`);
    }
  } else {
    if (`${lesson.id}.json` !== file) {
      problems.push(`id "${lesson.id}" does not match filename`);
    }
    if (seenIds.has(lesson.id)) problems.push(`duplicate id "${lesson.id}"`);
    seenIds.add(lesson.id);

    lesson.scenes.forEach((scene, i) => {
      const expected = `scene-${String(i + 1).padStart(2, '0')}`;
      if (scene.id !== expected) {
        problems.push(`scene ${i} id "${scene.id}" should be "${expected}"`);
      }
      if (scene.kind === 'diagram' && !scene.diagram) {
        problems.push(`${scene.id} is kind=diagram but has no diagram`);
      }
    });
    const last = lesson.scenes[lesson.scenes.length - 1];
    if (last.kind !== 'sources') {
      problems.push('last scene must be kind=sources (the citations end card)');
    }
    if (lesson.scenes.filter((s) => s.kind === 'sources').length !== 1) {
      problems.push('exactly one sources scene allowed');
    }
    lesson.quiz.forEach((q, i) => {
      if (new Set(q.choices).size !== q.choices.length) {
        problems.push(`quiz ${i}: duplicate choices`);
      }
    });
  }

  if (problems.length) {
    failures++;
    console.error(`✗ ${file}`);
    for (const p of problems) console.error(`    ${p}`);
  } else {
    console.log(`✓ ${file}`);
  }
}

console.log(`\n${files.length - failures}/${files.length} lessons valid`);
process.exit(failures ? 1 : 0);
