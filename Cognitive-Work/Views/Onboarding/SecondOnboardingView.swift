//
//  MemojiOnboardingView.swift
//  Cognitive-Work
//
//  Created by Carolina Sun on 19/08/26.
//

import SwiftUI

struct SecondOnboardingView: View {
    @State private var viewModel = MemojiPickerViewModel()
    
    var body: some View {
        VStack(alignment: .center) {
            
            VStack(alignment: .leading, spacing: 16) {
                Text("Para Começarmos...")
                    .font(.title)
                    .bold()
                    .foregroundStyle(.black.opacity(0.7))
                Text("Escolha um Memoji e um nome para utilizar no seu app")
                    .font(.callout)
                    .foregroundStyle(.gray)
                    .lineLimit(nil)
            }
            Spacer()
            
            Group {
                ProfileImage(image: viewModel.profileImage)
                    .padding()
                Text("AA")
                    .bold()
                    .font(.system(size: 43))
            }
            
            Spacer()
            
            OnboardingProgressButton(text: "Continuar")
            
            
        }
        .padding()
    }
}

#Preview {
    SecondOnboardingView()
}
