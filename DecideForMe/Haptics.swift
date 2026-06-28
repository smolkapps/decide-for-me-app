//
//  Haptics.swift
//  DecideForMe
//
//  Thin wrapper around UIKit feedback generators so views stay declarative.
//

import UIKit

enum Haptics {
    /// A light "tick" while the picker is spinning.
    static func tick() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred(intensity: 0.6)
    }

    /// A success notification when a final choice lands.
    static func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    /// A soft selection change as options are toggled.
    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
}
