//
//  OnboardingSkipButton.swift
//  Cognitive-Work
//
//  Created by Carolina Sun on 25/08/26.
//

import SwiftUI

struct OnboardingSkipButton: View {
    var width: CGFloat = UIScreen.main.bounds.width * 0.6
    var height: CGFloat = UIScreen.main.bounds.height * 0.06
        
    var isLoading: Bool = false
    var action: () -> Void
    
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
            .frame(width: width, height: height)
            .foregroundColor(.gray)
            .fontWeight(.medium)
        }
        .disabled(isLoading)
    }
}

#Preview {
    OnboardingSkipButton(width: 300, height: 200, action: {})
}
