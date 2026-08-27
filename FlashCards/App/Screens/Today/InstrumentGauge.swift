// App/Screens/Today/InstrumentGauge.swift
import SwiftUI

/// Cockpit-style daily-goal dial: a 270° arc with graduated tick marks, read
/// like an airspeed indicator sweeping toward the day's card goal.
struct InstrumentGauge: View {
    let value: Int
    let goal: Int

    /// Fraction of the circle the gauge sweeps (270°, gap at the bottom).
    private let sweep = 0.75
    private let tickCount = 21

    private var progress: Double {
        min(1, Double(value) / Double(max(1, goal)))
    }

    var body: some View {
        ZStack {
            ticks
            Circle()
                .trim(from: 0, to: sweep)
                .stroke(.white.opacity(0.10), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(135))
                .padding(12)
            Circle()
                .trim(from: 0, to: sweep * progress)
                .stroke(Theme.accent, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(135))
                .padding(12)
                .animation(.snappy, value: progress)
            VStack(spacing: 2) {
                Text("\(value)")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text(value >= goal ? "GOAL MET" : "OF \(goal)")
                    .font(.caption2.weight(.semibold))
                    .tracking(1.2)
                    .foregroundStyle(value >= goal ? Theme.accent : .secondary)
            }
            Text("DAILY GOAL")
                .placard()
                .offset(y: 66)
        }
        .frame(width: 156, height: 156)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Daily goal: \(value) of \(goal) cards")
    }

    /// Graduations just inside the arc; every fifth tick is a major mark.
    private var ticks: some View {
        ForEach(0..<tickCount, id: \.self) { i in
            let major = i % 5 == 0
            // Ticks span the same 270° as the arc, starting at its 135° origin.
            // The +90 converts to rotationEffect's 12-o'clock reference.
            let angle = 225 + 270 * Double(i) / Double(tickCount - 1)
            Capsule()
                .fill(.white.opacity(major ? 0.45 : 0.18))
                .frame(width: major ? 2.5 : 1.5, height: major ? 12 : 6)
                .offset(y: -54)
                .rotationEffect(.degrees(angle))
        }
    }
}
