//
//  MemojiOnboardingView.swift
//  Cognitive-Work
//
//  Created by Carolina Sun on 19/08/26.
//

import SwiftUI
import PhotosUI

struct SecondOnboardingView: View {
    @State private var viewModel = MemojiPickerViewModel()
    @State private var usernameText: String = ""
    @State private var selectedItem: PhotosPickerItem? = nil
    
    var body: some View {
        VStack(alignment: .center, spacing: 58) {
            OnboardingHeaderText(titleText: "Para começarmos...", descriptionText: "Escolha um Memoji e um nome para utilizar no seu app")
            
            PhotosPicker(selection: $selectedItem, matching: .images) {
                ProfileImage(image: viewModel.profileImage)
            }
            .layoutPriority(1)
            
            TextField("Nome", text: $usernameText)
                .textFieldStyle(.plain)
                .font(.system(size: 43, weight: .bold))
                .foregroundColor(.primary)
                .accentColor(.blue)
                .multilineTextAlignment(.center)
            
            OnboardingProgressButton(text: "Continuar")
            
        }
        .onChange(of: selectedItem) { oldValue, newItem in
            Task {
                if let newItem,
                   let data = try? await newItem.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    await MainActor.run {
                        viewModel.profileImage = uiImage
                    }
                }
            }
        }
        .padding()
    }
}

#Preview {
    SecondOnboardingView()
}
