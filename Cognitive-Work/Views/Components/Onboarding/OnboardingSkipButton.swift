//
//  OnboardingSkipButton.swift
//  Cognitive-Work
//
//  Created by Carolina Sun on 25/08/26.
//

import SwiftUI

struct OnboardingSkipButton: View {
    var width: CGFloat?
    var height: CGFloat?

    var isLoading: Bool = false
    var action: () -> Void

    // `width`/`height` shadow the View extension's properties of the same
    // name, so casting to `any View` is needed to reach the extension's
    // default (screen-based) value when no override was passed in.
    private var resolvedWidth: CGFloat { width ?? (self as any View).width * 0.6 }
    private var resolvedHeight: CGFloat { height ?? (self as any View).height * 0.06 }

    var body: some View {
        Button {
            action()
        } label: {
            ZStack {
                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text("Pular esta etapa")
                        .font(.system(size: 15, weight:.regular))
                        .underline()
                }
            }
            .frame(width: resolvedWidth, height: resolvedHeight)
            .foregroundColor(.gray)
            .fontWeight(.medium)
        }
        .disabled(isLoading)
        .accessibilityLabel(Text(L10n.tr("Pular esta etapa")))
        .voiceControlNames([L10n.tr("Pular esta etapa"), L10n.tr("Pular")])
        .voiceOverValue(isLoading ? L10n.tr("Carregando") : "")
    }
}

#Preview {
    OnboardingSkipButton(width: 300, height: 200, action: {})
}
