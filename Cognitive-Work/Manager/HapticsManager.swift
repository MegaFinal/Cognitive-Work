//
//  HapticsManager.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 30/09/26.
//

import UIKit

/// Single entry point for haptic feedback, so the "Haptics" switch in
/// ``GeneralProfileSettingsView`` is honored everywhere, in real time.
///
/// The setting is read from `UserDefaults` on every call (the same key the settings screen binds
/// with `@AppStorage`), so flipping the switch takes effect on the very next vibration without
/// relaunching or re-rendering anything.
enum HapticsManager {

    /// `@AppStorage` key of the "Haptics" switch. Defaults to on.
    static let storageKey = "hapticsEnabled"

    /// `@AppStorage` key of the "Microinterações" switch. Defaults to on.
    static let microInteractionsKey = "microInteractionsEnabled"

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: storageKey) as? Bool ?? true
    }

    static var areMicroInteractionsEnabled: Bool {
        UserDefaults.standard.object(forKey: microInteractionsKey) as? Bool ?? true
    }

    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium, intensity: CGFloat = 1.0) {
        guard isEnabled else { return }
        UIImpactFeedbackGenerator(style: style).impactOccurred(intensity: intensity)
    }

    static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard isEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }

    static func selection() {
        guard isEnabled else { return }
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
