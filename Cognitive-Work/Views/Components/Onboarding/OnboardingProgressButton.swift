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
    var width: CGFloat = UIScreen.main.bounds.width * 0.6
    var height: CGFloat = UIScreen.main.bounds.height * 0.06
   
    var text: String
    var isSystemImage: Bool = false

    var isLoading: Bool = false
    var isDisabled: Bool = false
    var action: () -> Void
    
    var body: some View {
        Button {
            action()
        } label: {
            ZStack {
                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    if isSystemImage {
                        Image(systemName: text)
                            .font(.system(size: height * 0.4))
                    } else {
                        Text(text)
                    }
                }
            }
            .frame(width: width, height: height)
            .foregroundColor(.white)
            .fontWeight(.medium)
            .background(
                Capsule()
                    .foregroundColor(isDisabled ? .gray : .blue)
                    .glassEffect()
            )
        }
        .disabled(isLoading || isDisabled)
    }
}

#Preview {
    OnboardingProgressButton( text: "Continuar", action: {})
}
