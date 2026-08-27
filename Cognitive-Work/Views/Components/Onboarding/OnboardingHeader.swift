//
//  OnboardingHeader.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 19/08/26.
//

import SwiftUI

/// A full-width title-and-description header used atop onboarding screens
struct OnboardingHeader: View {
    var title: String
    var description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(title)
                .font(.title)
                .bold()
            
            Text(description)
                .foregroundColor(.subTitleGray)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
//        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 20)
        .padding(.horizontal, 30)
    }
}

#Preview {
    OnboardingHeader(title: "title", description: "Lorem Ipsum is simply dummy text of the printing and typesetting industry.")
}
