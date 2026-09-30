//
//  OnboardingHeader.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 19/08/26.
//

import SwiftUI

/// A full-width title-and-description header used atop onboarding screens
struct OnboardingHeader: View {
    var title: LocalizedStringKey
    var description: LocalizedStringKey
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(title)
                .font(.system(size: 28))
                .bold()
            
            Text(description)
                .foregroundColor(.subTitleGray)
        }
        .padding(.top, 20)
        .padding(.horizontal, 30)
    }
}

#Preview {
    OnboardingHeader(title: "title", description: "Lorem Ipsum is simply dummy text of the printing and typesetting industry.")
}
