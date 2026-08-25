//
//  FourthOnboardingView.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 19/08/26.
//

import SwiftUI

/// The step where the user selects which rooms exist in their house
///
/// `FourthOnboardingView` renders the list of available rooms (from
/// ``OnboardingViewModel/availableRooms``) as a two-column grid of
/// ``OnboardingRoomCard`` items
///
/// Tapping a card toggles its selection state, tapping the dedicated "add" card
/// presents ``NewRoomSheet`` so the user can define a custom room
///
///  Confirming the selection persists the chosen rooms via
/// ``OnboardingViewModel/saveSelectedRooms()``.
struct FourthOnboardingView: View {
    /// The shared onboarding view model, read from the environment
    @Environment(OnboardingViewModel.self) var viewModel
    
    /// Whether the sheet for creating a custom room is currently presented
    @State private var isShowingCustomRoomSheet = false
    
    /// The two-column grid layout used to display room cards
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
            NewRoomSheet()
             .presentationDetents([.medium])
        }
        .navigationBarBackButtonHidden(viewModel.isLoading)
    }
}

#Preview {
    let mockViewModel = OnboardingViewModel()
    
    return FourthOnboardingView()
        .environment(mockViewModel)
}
