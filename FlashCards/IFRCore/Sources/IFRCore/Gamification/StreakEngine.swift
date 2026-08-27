import Foundation

/// A streak tracks consecutive days of goal achievement, with the ability to survive missed days
/// using "freezes" (banked from 7-day streaks, max 2). Rules:
/// - A goal-met day extends the streak if it's the next calendar day; repeat calls same day are no-ops.
/// - Missing N days consumes min(N, freezes) freezes — if freezes cover every missed day the streak
///   survives, otherwise it resets to 1 on the new goal day.
/// - Every 7 consecutive goal days earns 1 freeze, banked to a max of 2.
/// - `longest` never decreases.
/// - `displayStreak` shows 0 if the streak is already broken beyond freeze coverage as of "now".
public struct StreakState: Codable, Equatable, Sendable {
    public var current: Int
    public var longest: Int
    public var freezes: Int
    public var lastGoalDate: Date?
    public var daysTowardFreeze: Int

    public init(current: Int = 0, longest: Int = 0, freezes: Int = 0,
                lastGoalDate: Date? = nil, daysTowardFreeze: Int = 0) {
        self.current = current
        self.longest = longest
        self.freezes = freezes
        self.lastGoalDate = lastGoalDate
        self.daysTowardFreeze = daysTowardFreeze
    }
}

public struct StreakEngine: Sendable {
    private let calendar: Calendar

    public init(calendar: Calendar) {
        self.calendar = calendar
    }

    public func recordGoalMet(on date: Date, state: StreakState) -> StreakState {
        var s = state
        let today = calendar.startOfDay(for: date)

        guard let last = s.lastGoalDate.map({ calendar.startOfDay(for: $0) }) else {
            s.current = 1
            s.daysTowardFreeze = 1
            s.longest = max(s.longest, 1)
            s.lastGoalDate = today
            return earnFreezeIfDue(s)
        }

        let gap = calendar.dateComponents([.day], from: last, to: today).day ?? 0
        guard gap > 0 else { return s }

        let missed = gap - 1
        let spent = min(missed, s.freezes)
        s.freezes -= spent
        if spent == missed {
            s.current += 1
            s.daysTowardFreeze += 1
        } else {
            s.current = 1
            s.daysTowardFreeze = 1
        }
        s.longest = max(s.longest, s.current)
        s.lastGoalDate = today
        return earnFreezeIfDue(s)
    }

    /// Streak to show in UI: the stored streak if it's still alive (today's
    /// goal can still extend it, counting available freezes), else 0.
    public func displayStreak(asOf date: Date, state: StreakState) -> Int {
        guard let last = state.lastGoalDate.map({ calendar.startOfDay(for: $0) }) else { return 0 }
        let today = calendar.startOfDay(for: date)
        let gap = calendar.dateComponents([.day], from: last, to: today).day ?? 0
        let missedIfMetToday = max(0, gap - 1)
        return missedIfMetToday <= state.freezes ? state.current : 0
    }

    private func earnFreezeIfDue(_ state: StreakState) -> StreakState {
        var s = state
        if s.daysTowardFreeze >= 7 {
            s.freezes = min(2, s.freezes + 1)
            s.daysTowardFreeze = 0
        }
        return s
    }
}
