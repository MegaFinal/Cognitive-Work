//
//  PageIndicator.swift
//  Cognitive-Work
//
//  Created by Jonas Fernando Nascimento Melo on 29/09/26.
//

import SwiftUI

struct PageIndicator: View {
    let count: Int
    @Binding var current: Int
    /// VoiceOver pages with the adjustable action; everyone else (Voice Control) gets
    /// the invisible "Anterior" / "Próxima" elements next to the dots.
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i == current ? Color.primary : Color.secondary.opacity(0.3))
                    .frame(width: 8, height: 8)
                    .onTapGesture { current = i }
            }
        }
        .animation(.spring(duration: 0.3), value: current)
        // One adjustable element: swipe up/down to change page.
        .accessibilityElement(children: .ignore)
        .voiceOverLabel(L10n.tr("Página"))
        .voiceOverValue(L10n.tr("%lld de %lld", current + 1, count))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                if current < count - 1 { current += 1 }
            case .decrement:
                if current > 0 { current -= 1 }
            @unknown default:
                break
            }
        }
        .voiceControlNames([L10n.tr("Página")])
        .accessibilityActions {
            Button(L10n.tr("Próxima")) { if current < count - 1 { current += 1 } }
            Button(L10n.tr("Anterior")) { if current > 0 { current -= 1 } }
        }
        // Voice Control can't use adjustable actions: "Toque em Próxima" / "Toque em Anterior".
        .overlay(alignment: .leading) {
            if !voiceOverEnabled && current > 0 {
                DashboardVoiceControlButton(
                    labels: [L10n.tr("Anterior"), L10n.tr("Voltar")],
                    action: { current -= 1 }
                )
                .offset(x: -32)
            }
        }
        .overlay(alignment: .trailing) {
            if !voiceOverEnabled && current < count - 1 {
                DashboardVoiceControlButton(
                    labels: [L10n.tr("Próxima"), L10n.tr("Avançar")],
                    action: { current += 1 }
                )
                .offset(x: 32)
            }
        }
    }
}

/// An invisible element that only exists for Voice Control (and VoiceOver) to activate by
/// name. It draws nothing and lets touches through, so the visual design is unchanged.
struct DashboardVoiceControlButton: View {
    /// Spoken names; the first is also the accessibility label.
    let labels: [String]
    let action: () -> Void

    var body: some View {
        Color.clear
            .frame(width: 28, height: 28)
            .allowsHitTesting(false)
            .accessibilityElement()
            .voiceOverLabel(labels.first ?? "")
            .voiceControlNames(labels)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { action() }
    }
}


#Preview {
    @Previewable @State var current = 1
    PageIndicator(count: 4, current: $current)
}
