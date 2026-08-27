# TestFlight Checklist (manual, requires Apple Developer account)

1. App Store Connect → New App: bundle ID `com.tylercasey.ifrflashcards`, name "IFR FlashCards".
2. App Store Connect → App → Game Center: create leaderboards with EXACT IDs:
   - `ifr.weekly.xp` — Recurring, weekly (starts Monday 00:00), score = best, integer, descending
   - `ifr.alltime.xp` — Classic, integer, descending
   - `ifr.longest.streak` — Classic, integer, descending
3. Xcode → Signing & Capabilities: select your team (automatic signing). Confirm the
   Game Center capability is present (from the entitlements file).
4. Product → Archive → Distribute → TestFlight & App Store → Upload.
5. App Store Connect → TestFlight: add internal testers (you + brother's Apple ID email).
6. Both phones: install TestFlight app → accept invite → install.
7. Verify on device: Game Center sign-in prompt appears, a study session submits a
   weekly XP score, and the leaderboard on Today shows both players.

## Known limitations to verify

- An offline-queued weekly XP score that crosses Monday's board reset is
  DROPPED client-side rather than submitted (PendingScores week-stamps weekly
  entries and purges stale ones), so last week's XP never inflates the new
  week's board — but that XP also never reaches the board for the week it was
  earned in. Verify once during on-device testing (e.g. answer questions
  offline late Sunday, reconnect Monday, confirm the new week's board does NOT
  show the stale score).
- The app's weekly window is device-local Monday midnight, but the App Store
  Connect leaderboard resets at a fixed configured instant (not per-device
  timezone). For non-UTC users this is a minor boundary divergence — scores
  near the Sunday/Monday edge may be attributed to a different week on-device
  than on the leaderboard.
