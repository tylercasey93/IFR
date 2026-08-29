# Duke — series style guide

Duke is the teacher character of "IFR in 30 Seconds": a grizzled veteran CFII
in his 60s. Gray mustache, headset around the neck, aviators pushed up on his
forehead, coffee mug that never empties, 20,000-hour energy.

## Voice & humor

- **Dry instructor wit.** Deadpan, understatement, never laughs at his own
  jokes. ("The FAA, in its infinite mercy, gives you three options.")
- **Aviation puns & dad jokes**, sparingly — one or two per lesson.
- **Running gags:** his coffee; "my examiner in eighty-seven"; calling the
  viewer **"kid"**; "the punishment is what the clouds had planned."
- Openers riff on: *"Alright kid, thirty seconds on the clock."*
- Every joke serves the teaching point. Never joke about dying pilots,
  crashes with fatalities, or real accidents.

## Writing narration (v5)

- Anchor every lesson in ONE concrete flight Duke narrates in second person,
  present tense. Invent plausible generic fixes/fields (DONNA, Mercer Field,
  Baxter VOR) — never real-chart numbers that could be mistaken for current
  procedures.
- Duke asks and WAITS: pretest up front, eyes-off recall near the end,
  one callback to an earlier lesson. He talks to the pilot flying, not to
  an audience.

## Writing narration

- Per-scene narration, ~10–35 words a scene, ~100–130 words a lesson
  (~30–45s spoken).
- Spell out spoken numbers/regs the way Duke would say them
  ("ninety-one one eighty-five"), but keep on-screen text in written form
  ("14 CFR 91.185").
- Facts first, jokes second: every lesson must carry its ACS task code(s) and
  one governing FAA source, and end with the Sources card.

## The rig (video-pipeline/src/character/Duke.tsx)

- Poses: `stand`, `point`, `coffeeSip`, `armsCrossed`
- Expressions: `neutral`, `deadpan`, `eyebrowRaise`, `grin`, `squint`
- Positions: `center`, `left`, `right`, `corner`, `hidden`
- Automatic: mouth-flap while the scene narration plays, blink loop, idle bob,
  coffee steam.

TTS voice: ElevenLabs "Bill" (`pqHfZKP75CvOlQylNhV4`) — wise, older,
American (Tyler-approved). Narration is shaped for ElevenLabs prosody before
synthesis (terminal punctuation, `<break/>` beats at ellipses, scene-to-scene
`previous_text`/`next_text` continuity) — see `scripts/tts.mjs`. OpenAI
`gpt-4o-mini-tts` (`onyx`) remains the fallback provider.
