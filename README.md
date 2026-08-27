# IFR FlashCards + IFR in 30 Seconds

Two things live in this repo:

- **`FlashCards/`** — the IFR FlashCards iPhone app (SwiftUI, XcodeGen).
  Now includes the **Feed** tab: "IFR in 30 Seconds", a TikTok-style vertical
  feed of ~30-second animated lessons hosted by Duke (a grizzled veteran CFII),
  with quiz cards after every video.
- **`content/` + `video-pipeline/`** — the lesson content bank and the
  Remotion pipeline that renders the feed videos.

## Building the app (on a Mac)

```bash
brew install xcodegen
cd FlashCards
xcodegen generate
open IFRFlashCards.xcodeproj
```

In Xcode: select the `IFRFlashCards` target → Signing & Capabilities → pick
your Team, then Cmd-R to your iPhone. If anything fails to compile, send the
error back to Claude — the Swift was written without a Mac to compile on.

## Rendering lesson videos

Requires Node 20+. All commands run in `video-pipeline/`:

```bash
npm install
npm run music                       # one-time: synthesize the music bed
export OPENAI_API_KEY=sk-...        # or ELEVENLABS_API_KEY (optional)
npm run tts                         # per-scene narration + timing (skips cleanly without a key)
npm run render:all                  # → content/rendered/<id>.mp4
npm run app:content                 # → FlashCards/FeedMedia/ (bundled by the app)
npm run validate                    # schema-check all lesson JSONs
```

Without a TTS key, videos render captions-only with estimated pacing — the
pipeline never fails on a missing key.

## Content

Lessons live in `content/lessons/*.json` (schema:
`content/schema/lesson.schema.json`). Every lesson cites its Instrument
Rating ACS task code(s) **and** a governing FAA source (14 CFR, AIM, AC, or
FAA handbook) — shown as the video's end card and in the app's Sources sheet.
See `docs/ADDING_A_LESSON.md` and `docs/CHARACTER.md`.

All content is a study aid — verify against current FAA publications.

## Licensing note

Remotion is free for individuals and companies of up to 3 people
(remotion.dev/license). The music bed is synthesized from scratch in
`scripts/make-music.mjs` — no third-party audio.
