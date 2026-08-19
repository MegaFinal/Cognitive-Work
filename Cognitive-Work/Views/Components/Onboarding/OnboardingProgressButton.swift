//
//  onboardingProgressButton.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 19/08/26.
//

import SwiftUI

struct OnboardingProgressButton: View {
    var width = UIScreen.main.bounds.width
    var height = UIScreen.main.bounds.height
    var text: String
    
    var body: some View {
        Button {
            //action
        } label: {
            Text(text)
                .frame(width: width * 0.5, height: height * 0.05)
                .foregroundColor(.white)
                .fontWeight(.medium)
                .background(
                    Capsule()
                    .foregroundColor(.blue)
                    .glassEffect()
                )
        }
    }
}

#Preview {
    OnboardingProgressButton(text: "texto")
}
