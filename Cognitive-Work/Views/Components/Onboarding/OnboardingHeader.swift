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
                .font(.system(size: 30))
                .bold()
                .fixedSize(horizontal: false, vertical: true)
            
            Text(description)
                .foregroundColor(.subTitleGray)
        }
        .padding(.top, 20)
        .padding(.horizontal, width * 0.08)
        .frame(maxWidth: .infinity, alignment: .leading)  
    }
}

#Preview {
    OnboardingHeader(title: "title", description: "Lorem Ipsum is simply dummy text of the printing and typesetting industry.")
}
