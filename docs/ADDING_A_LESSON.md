# Adding a lesson

## The v5 lesson template (research-grounded)

Every lesson follows this scene arc (see any file in `content/lessons/`):

1. **title** — one concrete flight scenario, real numbers, second person
   ("You're level at eight thousand over the ridge…") — anchored instruction
2. **challenge** (`pauseSec: 3`) — pretest question BEFORE any teaching,
   aligned with `quiz[0]` so the app's pre-flight card measures the same
   thing — the pretesting effect
3.–5. **teaching scenes** — the concrete case first, the rule second;
   exactly ONE "why is the rule this way" beat per lesson; on-screen text is
   keywords, never narration verbatim; number the items when content is a
   sequence
6. **challenge** (`pauseSec: 4`) — "Eyes off the screen" retrieval prompt,
   answered by the recap — the testing effect
7. **recap** — checklist that resolves the recall challenge
8. **challenge** (`pauseSec: 3`, lessons 02+) — spaced callback to ONE
   earlier lesson's core fact — the spacing effect
9. **sources** — ACS + FAA end card (always last)

Word budget ~180–270 per lesson (~70–95s at Duke's pace).

1. **Write the JSON** — copy an existing file in `content/lessons/`, keep the
   `NN-kebab-id.json` naming (the numeric prefix is feed order). Follow
   `content/schema/lesson.schema.json` and `docs/CHARACTER.md`. Requirements:
   - ≥1 Instrument Rating ACS task code in `references.acs`
   - exactly one governing FAA source in `references.faa` (verify the citation)
   - scenes end with a `sources` scene; 2–3 quiz questions
2. **Validate**: `cd video-pipeline && npm run validate`
3. **Narrate** (optional): `npm run tts -- --lesson <id>` with
   `OPENAI_API_KEY` (or `ELEVENLABS_API_KEY`) set.
4. **Render**: `npm run render -- --lesson <id>` → `content/rendered/<id>.mp4`
5. **Package for the app**: `npm run app:content`, then re-run
   `xcodegen generate` is NOT needed (FeedMedia is a folder reference) — just
   rebuild the app.

New diagram types: add a component in `video-pipeline/src/graphics/`, register
it in `graphics/registry.ts`, and add its name to the `diagram.type` enum in
the schema.
