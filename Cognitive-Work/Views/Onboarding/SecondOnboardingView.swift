//
//  MemojiOnboardingView.swift
//  Cognitive-Work
//
//  Created by Carolina Sun on 19/08/26.
//

import SwiftUI
import PhotosUI

struct SecondOnboardingView: View {
    @Environment(OnboardingViewModel.self) var vm
    
    @State private var usernameText: String = ""
    @State private var selectedItem: PhotosPickerItem? = nil
    
    var body: some View {
        @Bindable var bindableViewModel = vm
        
        VStack(alignment: .center, spacing: 58) {
            OnboardingHeaderText(titleText: "Para começarmos...", descriptionText: "Escolha um Memoji e um nome para utilizar no seu app")
            
            PhotosPicker(selection: $selectedItem, matching: .images) {
                ProfileImage(image: vm.userProfilePicture)
            }
            .layoutPriority(1)
            
            TextField("Nome", text: $bindableViewModel.userName)
                .textFieldStyle(.plain)
                .font(.system(size: 43, weight: .bold))
                .foregroundColor(.primary)
                .accentColor(.blue)
                .multilineTextAlignment(.center)
            
            OnboardingProgressButton(text: "Continuar",isLoading: vm.isLoading,isDisabled: vm.userName.trimmingCharacters(in: .whitespaces).isEmpty,  action: {
                Task {
                    await vm.createUser()
                    vm.navigateToThird = true
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
                        vm.updateProfileImage(uiImage)
                    }
                }
            }
        }
    }
}

#Preview {
    SecondOnboardingView()
        .environment(OnboardingViewModel())
}
 
