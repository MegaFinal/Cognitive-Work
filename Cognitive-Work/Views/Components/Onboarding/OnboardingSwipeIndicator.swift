//
//  OnboardingSwipeIndicator.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 19/08/26.
//

import SwiftUI

struct OnboardingSwipeIndicator: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "chevron.up")
                .font(.largeTitle)
            
            Text("Deslize para cima para continuar")
        }
        .foregroundColor(.gray)
        .opacity(0.7)
        .transition(.opacity)
        .frame(maxHeight: .infinity, alignment: .bottom)
        .padding(.bottom, 50)
    }
}

#Preview {
    OnboardingSwipeIndicator()
}
