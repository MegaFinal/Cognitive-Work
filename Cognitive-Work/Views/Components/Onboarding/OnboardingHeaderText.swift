//
//  OnboardingHeaderText.swift
//  Cognitive-Work
//
//  Created by Carolina Sun on 20/08/26.
//

import SwiftUI

struct OnboardingHeaderText: View {
    var titleText: String
    var descriptionText: String
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(titleText)
                .font(.system(size: 32,weight: .bold))
                .foregroundStyle(.black.opacity(0.7))
            Text(descriptionText)
                .font(.callout)
                .foregroundStyle(.gray)
                .lineLimit(nil)
        }
        
    }
}

#Preview {
    OnboardingHeaderText(titleText: "Para começarmos...", descriptionText: "Escolha um Memoji e um nome para utilizar no seu app")
}
