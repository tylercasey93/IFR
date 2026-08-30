# Audio Production Sheet — Cleared as Filed

**Narrator voice:** Nathaniel — Deep, Rich and Mature (ElevenLabs shared voice `7S3KNdLDL7aRgBVRQb1z`, added to library)
**Model:** `eleven_v3` with audio tags (stage directions in square brackets — consumed, not spoken)
**Stability:** Creative (0.0) for dialogue-heavy chunks; Natural (0.5) for narration-heavy chunks
**Output:** mp3_44100_128, one file per chapter, chunks ≤4,200 chars split at scene/paragraph boundaries with `previous_text`/`next_text` conditioning

## Character voice sheet (locked tag-sets)

| Character | Default tag | Variants (use sparingly, at emotional beats) |
|---|---|---|
| Narrator | *(untagged)* | `[dry]` for jokes, `[quietly]` for tender closes |
| **Wren** | `[flat, clipped, controlled]` | `[icy]`, `[through gritted teeth]`, `[quietly, softening]`, `[deadpan]` |
| **Theo** | `[easy, charming, amused]` | `[mock-serious]`, `[gentle, sincere]`, `[grinning]` |
| **Okafor** | `[regal, warm, theatrical, strong Nigerian accent]` | `[conspiratorial whisper]`, `[triumphant]`, `[gasps in delight]` |
| **Priya** | `[quick, teasing]` | `[gentle]` |
| **Griff** | `[gruff, hearty]` | `[panicked, talking too fast]`, `[sheepish]` |
| **Sam** | `[gruff, warm, fond]` | `[voice cracking slightly]` |
| **Voss** | `[bone-dry, flat, unhurried]` | — |
| **Chidinma** | `[precise, pleasant, cut-glass London accent]` | `[amused]` |
| **Jax** | `[smooth, self-satisfied]` | — |
| ATC/radio | `[radio voice, clipped, procedural]` | — |

## Text-prep rules

- Scene breaks (`---`) → `<break time="1.2s" />`
- POV marker line dropped; chapter opens "Cleared as Filed. Chapter N: Title."
- Spoken-number conversions: "King Air 350" → "King Air three-fifty"; "M&Ms" → "M and Ems"; regs already spelled out in dialogue
- Italic markers stripped; italics for emphasis may become a tag (`[emphasizing]`) only where the emphasis is load-bearing
- Tags go immediately before the quoted line they direct; re-tag at every speaker change; tag mid-line register shifts only for big turns

## QC

- Spot-check each chapter's dialogue chunks (creative stability can hallucinate); re-roll bad takes with the same text
- Keep chunk boundaries at scene breaks where possible so any re-roll is contained
