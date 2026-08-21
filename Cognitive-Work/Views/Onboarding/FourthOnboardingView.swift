//
//  FourthOnboardingView.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 19/08/26.
//

import SwiftUI

struct FourthOnboardingView: View {
    @Environment(OnboardingViewModel.self) var viewModel
    
    @State private var isShowingCustomRoomSheet = false
    var columns = [GridItem(), GridItem()]
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                OnboardingHeader(
                    title: "Defina os cômodos",
                    description: "Escolha os ambientes presentes na sua residência, aperte e segure para editar seus nomes e quantidades."
                )
                
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(viewModel.availableRooms) { roomDraft in
                        OnboardingRoomCard(
                            text: roomDraft.name,
                            symbol: roomDraft.symbol,
                            isSelected: roomDraft.isSelected
                        )
                        .onTapGesture {
                            if roomDraft.isAddButton {
                                isShowingCustomRoomSheet = true
                            } else {
                                viewModel.toggleRoomSelection(id: roomDraft.id)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                
                OnboardingProgressButton(text: "Continuar", isLoading: viewModel.isLoading) {
                    Task {
                        await viewModel.saveSelectedRooms()
                    }
                }
            }
        }
        .sheet(isPresented: $isShowingCustomRoomSheet) {
            AddCustomRoomSheet()
        }
        .navigationBarBackButtonHidden(viewModel.isLoading)
    }
}

struct AddCustomRoomSheet: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        
    }
}

#Preview {
    let mockViewModel = OnboardingViewModel()
    
    return FourthOnboardingView()
        .environment(mockViewModel)
}
