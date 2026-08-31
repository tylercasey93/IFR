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

## QC

- Spot-check each chapter's dialogue chunks (creative stability can hallucinate); re-roll bad takes with the same text
- Keep chunk boundaries at scene breaks where possible so any re-roll is contained
- Confirm Okafor's Nigerian-accent tag and Wren's flat/dry register read as distinct from the Jack/Cole baseline on a single voice — re-roll with a stronger tag if they blur together
