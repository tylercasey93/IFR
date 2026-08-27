# Backlog

Items deliberately deferred from v1 (`feat/ifr-v1`), recorded at the final whole-branch review so they survive the merge. Grouped by trigger.

## Land with / before the 800-question bank (content workflow)

- **Badge counters:** `awardBadges` does O(history) `ReviewRecord` + `XPRecord` scans per answer. Move to persisted counters/aggregates before review history grows large.
- **`masteryByCategory()` batch API:** ProgressTab calls `mastery(for:)` 8× per render, each a full card-state fetch. The batch-capable private helper already exists in StudyStore — expose it.
- **Actual-count quiz labels:** QuizSetup's "60-question mock exam" wording assumes a full pool; with short pools the quiz is legitimately shorter. Label with actual counts once the bank ships (report screen already uses actual counts).
- **Real quiz-completion counter:** badge quiz counts use a distinct-days heuristic (multi-quiz days undercount). Add a quiz-completion record if `quizzes10/50` badge accuracy matters.
- **`BankValidationError.emptyField` test:** exercise it as part of the content-workflow validation stage.
- **Figures:** testing-supplement images ship with figure-based questions (CardView already renders `question.figure`).

## Spec promises not yet implemented (record-or-lose)

- **Exam-week front-loading:** spec says scheduling front-loads reviews in the final week before the exam date. `StudyQueue.session` has no exam-date awareness yet.
- **Per-category exam-day readiness:** spec says category readiness should use predicted recall *on exam day*; today only the whole-bank `readiness(examDate:)` does — `mastery(for:)` computes at `.now`.
- **Cached leaderboard standings:** spec promised offline leaderboards show cached standings with a "last updated" note; current behavior shows an empty-state message when loads fail.
- **Light theme:** dark cockpit theme is forced (deliberate v1); light theme + toggle later.
- **Review heatmap calendar + retention-rate / cards-learned stats** on Progress.

## Polish / hardening

- Haptic `prepare()` warm-up to cut first-fire latency.
- Streak-freeze UI beyond Today's banked count (earn/spend explanation).
- Scheduler.swift magic-number naming (constants match the FSRS reference; golden pins guard drift).
- XP test matrix gaps (`.hard` grade, difficulty 2); timezone-change streak test.
- First-launch notification permission race (self-heals on first backgrounding; worst case: notification-less first day).
- Cold-start deep-link window: `didReceive` can fire from App.init's delegate before RootView binds `onTab`; a `pendingTab` buffer in NotificationTapRouter would formally close the gap (the main-queue hop makes it very narrow already).
- Post-review-misses XP: a missed quiz question earns XP twice (quiz answer + review-misses flashcard) — deliberate reinforcement per spec, revisit if XP inflation bothers anyone.
- `IFRCore.swift` placeholder file removal (in passing).

## Known design limitations (won't-fix without a server)

- Offline weekly XP flushed after Monday's board reset lands in the new week's board (noted in TESTFLIGHT.md verification).
- Weekly window is device-local Monday midnight vs ASC's fixed reset instant — minor boundary divergence for non-UTC users.
- No cross-device push ("your brother passed you") — requires a push server; out of scope by design.
- FSRS LongTerm-only scheduling: "Again" lands tomorrow, never later today (recorded v1 product decision; spec-consistent).
