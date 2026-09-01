//
//  MemojiOnboardingView.swift
//  Cognitive-Work
//
//  Created by Carolina Sun on 19/08/26.
//

import SwiftUI
import PhotosUI

struct CreateProfileOnboardingView: View {
    @Binding var viewModel: OnboardingViewModel
    
    @State private var usernameText: String = ""
    @State private var selectedItem: PhotosPickerItem? = nil
    
    var body: some View {
        VStack(alignment: .center, spacing: 58) {
            OnboardingHeaderText(titleText: "Para começarmos...", descriptionText: "Escolha um Memoji e um nome para utilizar no seu app")
            
            PhotosPicker(selection: $selectedItem, matching: .images) {
                ProfileImage(image: viewModel.userProfilePicture)
            }
            .layoutPriority(1)
            
            TextField("Nome", text: $viewModel.userName)
                .textFieldStyle(.plain)
                .font(.system(size: 43, weight: .bold))
                .foregroundColor(.primary)
                .accentColor(.blue)
                .multilineTextAlignment(.center)
            
            OnboardingProgressButton(text: "Continuar",isLoading: viewModel.isLoading,isDisabled: viewModel.userName.trimmingCharacters(in: .whitespaces).isEmpty,  action: {
                Task {
                    await viewModel.createUser()
                    viewModel.goToNextView()
                }
            })
            
        }
        .navigationBarBackButtonHidden()
        .padding()
        .onChange(of: selectedItem) { _, newItem in
            Task {
                if let newItem,
                   let data = try? await newItem.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    
                    await MainActor.run {
                        viewModel.updateProfileImage(uiImage)
                    }
                }
            }
        }
    }
}

#Preview {
    @Previewable @State var viewModel = OnboardingViewModel()
    CreateProfileOnboardingView(viewModel: $viewModel)
        .environment(OnboardingViewModel())
}
 
