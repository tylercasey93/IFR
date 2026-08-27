// App/Theme/Haptics.swift
import UIKit

@MainActor
enum Haptics {
    static func correct() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func incorrect() { UINotificationFeedbackGenerator().notificationOccurred(.error) }
    static func flip() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
}
