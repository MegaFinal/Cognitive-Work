//
//  onboardingProgressButton.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 19/08/26.
//

import SwiftUI

/// A primary action button that can display a loading spinner
///
/// While ``isLoading`` is `true`, the button shows a `ProgressView` instead of
/// ``text`` and disables itself, preventing duplicate taps during an in-flight
/// asynchronous action (e.g. a CloudKit save).
///
/// Used throughout the onboarding flow as the primary "continue" action
struct OnboardingProgressButton: View {
    var width: CGFloat?
    var height: CGFloat?

    var text: String
    var isSystemImage: Bool = false

    var isLoading: Bool = false
    var isDisabled: Bool = false
    var action: () async -> Void

    // `width`/`height` shadow the View extension's properties of the same
    // name, so casting to `any View` is needed to reach the extension's
    // default (screen-based) value when no override was passed in.
    private var resolvedWidth: CGFloat { width ?? (self as any View).width * 0.6 }
    private var resolvedHeight: CGFloat { height ?? (self as any View).height * 0.06 }

    /// What VoiceOver reads: icon-only buttons get a word for their symbol.
    private var accessibilityText: String {
        guard isSystemImage else { return L10n.tr(text) }
        switch text {
        case "checkmark": return L10n.tr("Salvar")
        default: return L10n.tr("Continuar")
        }
    }

    var body: some View {
        Button {
            Task {
                await action()
            }
        } label: {
            ZStack {
                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    if isSystemImage {
                        Image(systemName: text)
                            .font(.system(size: resolvedHeight * 0.4))
                    } else {
                        Text(LocalizedStringKey(text))
                    }
                }
            }
            .frame(width: resolvedWidth, height: resolvedHeight)
            .foregroundColor(.white)
            .fontWeight(.medium)
            .background(
                Capsule()
                    .foregroundColor(isDisabled ? .gray : .blue)
                    .glassEffect()
            )
        }
        .disabled(isLoading || isDisabled)
        .accessibilityLabel(Text(accessibilityText))
        .accessibilityValue(isLoading ? Text(L10n.tr("Carregando")) : Text(""))
    }
}

#Preview {
    OnboardingProgressButton( text: "Continuar", action: {})
}
