# The Meridian Files — instructions for Claude Code agents

This repo is **The Meridian Files**, a three-book aviation-thriller/romance series, narration-ready prose that teaches the FAA Instrument Rating ACS through the story.

It split off from a larger monorepo (`tylercasey93/IFR`, which also holds an unrelated Instrument Rating study app and its ACS reference wiki) so agents working on the series stop tripping over unrelated files and an old draft. Everything in this repo is the series.

## Before writing anything

Read these three files first, in order — they are the locked canon and nothing you write should contradict them:
1. `SERIES-BIBLE.md` — locked author decisions (numbered, versioned; later numbers override earlier ones on the same topic), craft calibration log at the end.
2. `CHARACTERS.md` — full dossiers: timeline, psychology, voice & mannerisms, series arc, canon anchors. The "Canon anchors" line under each character is the non-negotiable list — don't drop or contradict any of it.
3. `BOOK-1-OUTLINE.md` — the 21-chapter map for Book 1: POV ledger, ACS coverage per chapter, chapter-by-chapter beats, the author-in-the-loop execution protocol, continuity ledger for Books 2–3.

`book-1/` is the current manuscript (`Chapter-01-...md` through however far it's gotten — check what's already there before assuming the next chapter number). `draft-one/` is an earlier, superseded single-book version with a different cast (Wren-as-captain, "Theo" instead of Jack). It's kept as historical record only; do not extend it or treat it as canon for the series.

### Writing conventions

- First person, one POV per chapter, marked at the top: `# Chapter [Word] — [Title]` then a blank line then `*[POV first name]*` then the chapter body.
- Scene breaks are a line containing exactly `---`.
- Numbers, tail numbers, and regulation citations are written phonetically in dialogue and narration (e.g. "November Five Five Zero Mike Alpha", "sixty-one fifty-seven") — this is both the prose style and what makes narration prep easy later; don't write raw digits where a character would actually say something aloud.
- POV rotation and chapter assignment follow the outline's POV ledger — check it before deciding whose chapter is next.
- Follow the craft-calibration log at the end of `SERIES-BIBLE.md` (voice per narrator, how much teaching per chapter, the heat/voice references) rather than reinventing tone from scratch.

### Author-in-the-loop

The default is checkpoints: pre-draft questions (voice/approach choices), then check back in as the draft progresses, rather than writing a full chapter unattended. The author has sometimes said "continue" to skip checkpoints for a stretch, and has other times explicitly asked for a full stepwise rewrite ("ask me questions as you go") — match whichever mode they most recently asked for, and if genuinely unsure, ask rather than assume. After any deviation from checkpoints, say so rather than silently normalizing it as the new default.

### Git

Push only to the branch you were told to develop on for this session — check the current branch and the task instructions, don't assume it's always the same name across sessions. Never push to `main`. Don't open a PR unless asked. If another agent's branch has chapters this branch doesn't, it's fine to fetch and fast-forward/merge rather than rewrite — check `git log` across branches before assuming work is missing.

## Narration (turning a chapter into audio)

Full spec: `narration/PRODUCTION.md` — read it before touching narration. Summary:

- **One ElevenLabs voice for the whole book** (Nathaniel, voice ID in PRODUCTION.md), directed entirely by bracketed `eleven_v3` audio tags — a POV-narrator register tag anchored per chapter (Jack/Cole/Wren/Okafor each read differently), and a per-character dialogue tag sheet for everyone else. This is a deliberate choice (the author asked for single-voice-plus-tags over a multi-voice cast) — don't switch to per-character voice IDs without being asked again.
- **Stage 1 (creative, do this per new chapter):** produce a tagged, markdown-stripped, TTS-ready text file at `narration/tagged/chNN.txt`. PRODUCTION.md has the exact format rules; chapters 1–8 there are worked examples. This is well suited to one subagent per chapter run in parallel.
- **Stage 2 (mechanical):** `cd narration && python3 generate_audio.py` (needs `ffmpeg` and `ELEVENLABS_API_KEY` set, or a local gitignored `.elevenlabs_key` file). Renders every tagged chapter not already in `output/` and skips existing chunk files, so a failed run is safe to re-run.
- Rendered mp3s (`narration/output/Chapter-NN-*.mp3`) **are committed to the repo**, alongside `tagged/*.txt` — also hand new ones to the user as files directly when you finish a batch. Don't commit the per-chunk working files (`output/chNN/`, concat lists, silence pads) — just the final chapter mp3s.
- Generating audio spends real ElevenLabs credits — for a large batch (a full book, not one or two chapters), it's worth flagging the scale to the user before running rather than assuming go-ahead.
