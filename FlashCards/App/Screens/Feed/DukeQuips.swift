// App/Screens/Feed/DukeQuips.swift
import Foundation

/// Duke's quiz-feedback one-liners. Deterministic selection (seeded index,
/// no randomElement) so the same card always shows the same line and tests
/// can assert exact output.
enum DukeQuips {
    static let correct = [
        "Checkride answer. Don't get cocky.",
        "Correct. Somewhere, an examiner just frowned.",
        "That's the one. Coffee's on me. Figuratively.",
        "Affirmative. You've been reading the AIM, haven't you.",
        "Right answer, kid. The clouds respect preparation.",
        "Correct. My mustache is mildly impressed.",
        "Cleared as filed. Nicely done.",
        "That'll hold up in the oral. Next.",
    ]

    static let incorrect = [
        "Negative. The FAA disagrees, and they wrote the test.",
        "Not that one, kid. Read the explanation — twice.",
        "That answer works right up until it doesn't.",
        "Missed it. Good news: this is the cheap place to miss it.",
        "Negative. The granite doesn't grade on a curve.",
        "Wrong hold, kid. Fly the explanation below.",
        "Not quite. Even I got one wrong once. In 1987.",
        "Unable. Check the explanation and come back around.",
    ]

    static let streak3 = [
        "Three in a row. Approach-plate energy.",
        "Three straight. Someone's been studying.",
    ]

    static let streak5 = [
        "Five in a row. You're making this look easy, kid.",
        "Five straight. The examiner would call that 'consistent'.",
    ]

    static let streak8 = [
        "Eight in a row. Alright kid, now I'M taking notes.",
        "Eight straight. Go file IFR — mentally, at least.",
    ]

    /// Picks the line for an answer. `streak` is the correct-answer streak
    /// AFTER this answer; `seed` keeps the pick stable per card.
    static func line(correct: Bool, streak: Int, seed: Int) -> String {
        let pool: [String]
        if correct && streak >= 8 {
            pool = streak8
        } else if correct && streak >= 5 {
            pool = streak5
        } else if correct && streak >= 3 {
            pool = streak3
        } else {
            pool = correct ? Self.correct : incorrect
        }
        // Euclidean modulo, not abs(): abs(Int.min) traps.
        let index = ((seed % pool.count) + pool.count) % pool.count
        return pool[index]
    }
}
