//
//  OnboardingHeader.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 19/08/26.
//

import SwiftUI

/// A full-width title-and-description header used atop onboarding screens.
///
/// It's the single source of the onboarding title style (size, color, spacing and side margin),
/// so every step looks the same. It adds no top padding: the navigation bar (with the back
/// button) already separates it from the top of the screen.
struct OnboardingHeader: View {
    var title: LocalizedStringKey
    var description: LocalizedStringKey
    
    /// Optional second paragraph, shown under ``description``.
    var detail: LocalizedStringKey? = nil
    
    /// Horizontal padding the parent already applies around this header. It's subtracted from
    /// the header's own side margin so the text starts at the same x on every screen.
    var containerInset: CGFloat = 0
    
    private var sideMargin: CGFloat { width * 0.08 }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(title)
                .font(.custom("Alan Sans", size: 32, relativeTo: .largeTitle))
                .bold()
                .foregroundStyle(.titleGray)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            
            VStack(alignment: .leading, spacing: 10) {
                Text(description)
                
                if let detail {
                    Text(detail)
                }
            }
            .foregroundStyle(.subTitleGray)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, max(sideMargin - containerInset, 0))
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    OnboardingHeader(title: "title", description: "Lorem Ipsum is simply dummy text of the printing and typesetting industry.")
}
