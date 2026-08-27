# Adding a lesson

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
