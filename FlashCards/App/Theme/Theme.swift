// App/Theme/Theme.swift
import SwiftUI

enum Theme {
    /// Instrument-panel accent: the green of a vintage attitude indicator.
    static let accent = Color(red: 0.36, green: 0.78, blue: 0.55)
    /// Cockpit caution-light amber, for streak and warning accents.
    static let amber = Color(red: 0.96, green: 0.73, blue: 0.23)
    /// Instrument-panel face: near-black with a slight green cast.
    /// Safe as a fixed color — the app forces dark mode.
    static let panel = Color(red: 0.10, green: 0.12, blue: 0.11)
    /// Bezel stroke around panel cards.
    static let bezel = Color.white.opacity(0.08)
}

extension View {
    /// Panel-card chrome shared by the Today screen's cards.
    func instrumentPanel() -> some View {
        self
            .padding(16)
            .background(Theme.panel, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Theme.bezel, lineWidth: 1))
    }
}

extension Text {
    /// Cockpit placard: tracked-out uppercase microtype used for labels.
    func placard() -> some View {
        self
            .font(.caption2.weight(.semibold))
            .tracking(1.2)
            .foregroundStyle(.secondary)
    }
}
