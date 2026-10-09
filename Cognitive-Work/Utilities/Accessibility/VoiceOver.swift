//
//  VoiceOver.swift
//  Cognitive-Work
//

import SwiftUI
import UIKit

/// Small helpers shared by every screen's VoiceOver support.
enum VoiceOver {

    /// Whether VoiceOver is on right now. Use it only to change *behaviour* (for example, skipping
    /// an auto-dismiss timer); the labels themselves are always set.
    static var isRunning: Bool { UIAccessibility.isVoiceOverRunning }

    /// Speaks `message` without moving the focus, e.g. "Item comprado" after a toggle, or an error
    /// that appears outside the focused element.
    static func announce(_ message: String) {
        guard !message.isEmpty else { return }
        UIAccessibility.post(notification: .announcement, argument: message)
    }

    /// Tells VoiceOver the screen's layout changed a lot (a popup opened, a list was replaced), so
    /// it re-reads the screen.
    static func screenChanged() {
        UIAccessibility.post(notification: .screenChanged, argument: nil)
    }

    /// A Brazilian-real amount written so VoiceOver reads it naturally ("55 reais e 50 centavos").
    static func currency(_ value: Double) -> String {
        value.formatted(.currency(code: "BRL").locale(L10n.locale))
    }
}

extension View {

    /// Marks a purely decorative view (textures, sparkles, divider lines) so VoiceOver skips it.
    func accessibilityDecorative() -> some View {
        accessibilityHidden(true)
    }
}
