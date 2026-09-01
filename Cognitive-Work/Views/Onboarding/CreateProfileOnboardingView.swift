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
            headerText
            
                EditableProfileImage(image: viewModel.userProfilePicture, isEditing: true, selection: $selectedItem)
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
    
    // MARK: - Subviews
    
    /// Title and supporting copy for this onboarding step.
    private var headerText: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Para começarmos...")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.black.opacity(0.7))
            
            Text("Escolha um Memoji e um nome para utilizar no seu app")
                .font(.callout)
                .foregroundStyle(.gray)
                .lineLimit(nil)
        }
    }
}

#Preview {
    @Previewable @State var viewModel = OnboardingViewModel()
    CreateProfileOnboardingView(viewModel: $viewModel)
        .environment(OnboardingViewModel())
}

