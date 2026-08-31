# Audio Production Sheet — The Meridian Files, Book 1

**Narrator voice:** Nathaniel — Deep, Rich and Mature (ElevenLabs voice `7S3KNdLDL7aRgBVRQb1z`), one voice for the entire book
**Model:** `eleven_v3` with audio tags (bracketed stage directions — consumed, not spoken)
**Stability:** Creative (0.0) for dialogue-heavy chunks; Natural (0.5) for narration-heavy chunks
**Output:** mp3_44100_128, one file per chapter, chunks ≤3,800 chars split at scene/paragraph boundaries with `previous_text`/`next_text` conditioning, ~1.3s silence at scene breaks

## Why one voice

Book 1 is first person, one POV per chapter, rotating Jack / Cole / Wren / Okafor. Rather than recasting the narrator per chapter, one voice carries the whole book and is *directed* — via bracket tags — into each POV character's register at the chapter open and re-anchored after any long stretch of unmarked narration, and into every other character's register at each line of dialogue. The prose itself already carries most of the character differentiation (word choice, rhythm); tags are the audio layer on top, not a substitute for it.

## POV narrator registers (apply at chapter open; re-anchor after long unmarked stretches)

| POV | Register tag |
|---|---|
| **Jack** | `[low, unhurried, wry, precise]` |
| **Cole** | `[warm baritone, grounded, unhurried]` |
| **Wren** | `[flat, precise, dry, controlled]` |
| **Adaeze/Okafor** | `[grand, warm, unhurried, strong Nigerian accent, theatrical]` |

## Character dialogue voice sheet (locked tag-sets)

| Character | Default tag | Variants (use at emotional beats) |
|---|---|---|
| **Jack** | `[low, unhurried, wry]` | `[dry]`, `[quiet and precise]` (fear — rare, tell only Cole reads), `[warmer, unguarded]` |
| **Cole** | `[warm baritone, easy]` | `[quiet, total]` (the hard no), `[shorter sentences, same warmth, zero give]` (under load), `[quiet, sideways, sincere]` |
| **Wren** | `[flat, clipped, dry]` | `[deadpan]`, `[quietly, warmer]`, `[testing]` |
| **Okafor/Adaeze** | `[grand, warm, unhurried, strong Nigerian accent]` | `[theatrical, delighted]`, `[still — the executive register]`, `[gracious, absolute]` |
| **Priya** | `[quick, teasing, fond]` | `[quieter, serious]` (real problems) |
| **Griff** | `[gruff, hearty, plain]` | `[sheepish]`, `[quietly proud]` |
| **Elias** | `[easy, warm, low-key]` | `[gently honest]` |
| **Aaron** | `[warm, tired, kind]` | `[gentle, letting go]` |
| **Manny** | `[plain, unhurried, proud]` | — |
| **Ruben Ortega** | `[apologetic, rushed]` | — |
| **Dale Voss** | `[bone-dry, flat, unhurried]` | — |
| **Chidinma** | `[cut-glass precision, pleasant]` | `[amused]` |
| **Farid** | `[warm, quick, competent]` | — |
| **Yelena Sorokina** | `[exact, textbook-formal, grief-dry]` | `[allergic to being handled — clipped]` |
| **Mara** | `[sharp-tongued, teenage, quoting a manual]` | `[scared, hiding it]` |
| **ATC/radio** | `[radio voice, clipped, procedural]` | — |
| Narration (non-POV beats) | *(POV register, untagged unless a beat needs it)* | `[quietly]` for tender closes, `[dry]` for the joke landing |

## Text-prep rules

- Chapter opens spoken as `"Chapter [word]: [title]."` — the `# Chapter N — Title` heading and the `*POV*` marker line are stripped from the read text (the marker instead sets the narrator register for that chapter, per the table above)
- Scene breaks (`---`) become a hard chunk boundary with ~1.3s silence, not an in-line break tag
- Markdown bold/italic markers are stripped; italics become a tag only where the emphasis is load-bearing
- Spoken-number conversions (tail numbers, regs, radio calls) are mostly already written out in the prose; only patch the rare exception
- Tags go immediately before the quoted line they direct; re-tag at every speaker change; tag mid-line register shifts only for big turns

## Pipeline: how to narrate a new chapter

Two stages. Stage 1 is creative (do it yourself or delegate to a subagent); stage 2 is mechanical (run the script).

**Stage 1 — tag it.** For each new `audiobook/book-1/Chapter-NN-*.md`, produce a plain-text, TTS-ready version and save it to `audiobook/narration/tagged/chNN.txt`:
1. First line: the spoken chapter intro — `"Chapter [word]: [title]."` (convert the markdown `# Chapter N — Title` heading; drop the em dash, make it a colon).
2. Blank line, then the narration body as plain paragraphs separated by blank lines. Strip the heading and the `*POV*` marker line — the POV marker instead tells you which narrator register (table above) to anchor at the chapter open and re-anchor after any long unmarked stretch.
3. Preserve every `---` scene break as its own line reading exactly `---` — it becomes a hard chunk boundary with a silence gap, not an inline break tag.
4. Strip all markdown bold/italic formatting to plain text.
5. Insert bracket tags immediately before quoted dialogue lines per the character voice sheet above (default tag normally, a variant at real emotional beats); re-tag at every speaker change. Leave the POV narrator's own prose untagged by default — add a tag like `[dry]` or `[quietly]` only at a genuine emotional beat, not every paragraph. For a character not on the sheet, invent a short, consistent tag pair rather than leaving them untagged, and note the choice.
6. Patch only the rare raw numeral/callsign that would read awkwardly aloud (e.g. "G550" → "G-Five-Fifty", "0630" → "zero six three zero", "Part 135" → "Part one-thirty-five") — most of the prose is already written phonetically and shouldn't be touched.
7. Do not paraphrase, abridge, or drop any content — every paragraph and line of dialogue from the source must appear in the tagged output.

If delegating stage 1 to a subagent, give it: the source chapter path, this file's path, the exact output path, and the format rules above (points 1–7). One chapter per agent keeps the output manageable and reliable; chapters 1–8 were done this way, 8 agents in parallel.

**Stage 2 — render it.**
```
cd audiobook/narration
export ELEVENLABS_API_KEY=...      # or put the key in .elevenlabs_key (gitignored)
python3 generate_audio.py          # renders every tagged/chNN.txt not already in output/
python3 generate_audio.py 09       # or just the chapters you list
```
Requires `ffmpeg` on PATH. Output lands in `audiobook/narration/output/` and **is committed to the repo** (author's call — the finished mp3s live alongside the tagged text they came from). The script chunks each tagged file at scene breaks and the ~3,800-char limit, calls the ElevenLabs API per chunk (`eleven_v3` — note this model does **not** currently accept `previous_text`/`next_text` conditioning; don't add it back), and concatenates with `ffmpeg`, inserting a longer silence at true scene breaks and a short one at length-driven splits. It skips any chunk mp3 that already exists, so a failed run can just be re-run. Per-chunk working files (`output/chNN/chunk_*.mp3`, the concat list, the silence pads) are scratch — fine to `git add` just the final `Chapter-NN-*.mp3` files, or clean the `chNN/` subdirs out before committing.

## QC

- Spot-check each chapter's dialogue chunks (creative stability can hallucinate); re-roll bad takes with the same text
- Keep chunk boundaries at scene breaks where possible so any re-roll is contained
- Confirm Okafor's Nigerian-accent tag and Wren's flat/dry register read as distinct from the Jack/Cole baseline on a single voice — re-roll with a stronger tag if they blur together
