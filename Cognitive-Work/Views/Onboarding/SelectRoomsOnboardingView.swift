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
struct SelectRoomsOnboardingView: View {

    // MARK: - Properties

    /// The shared onboarding view model, read from the environment
    @Binding var viewModel: OnboardingViewModel
    
    /// Whether the sheet for creating a custom room is currently presented
    @State private var isShowingCustomRoomSheet = false
    
    /// The two-column grid layout used to display room cards
    let columns = [GridItem(), GridItem()]

    // MARK: - Body

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                OnboardingHeader(
                    title: "Defina os cômodos",
                    description: "Escolha os ambientes presentes na sua residência."
                )
                
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(viewModel.availableRooms) { roomDraft in
                        OnboardingRoomCard(
                            text: roomDraft.name,
                            symbol: roomDraft.symbol,
                            isSelected: roomDraft.isSelected
                        )
                        .onTapGesture {
                            if !viewModel.isLoading {
                                if roomDraft.isAddButton {
                                    isShowingCustomRoomSheet = true
                                } else {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        viewModel.toggleRoomSelection(id: roomDraft.id)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
                
                OnboardingProgressButton(text: "Continuar", isLoading: viewModel.isLoading, isDisabled: !viewModel.hasSelectedRooms) {
                    Task {
                        await viewModel.saveSelectedRooms()
                        if !viewModel.isLoading {
                            viewModel.goToNextView()
                        }
                  }
                }
            }
            Spacer()
        }
        .sheet(isPresented: $isShowingCustomRoomSheet) {
            NewRoomSheet()
                .environment(viewModel)
                .presentationDetents([.medium])
        }
        .navigationBarBackButtonHidden()
    }
}

// MARK: - Private subviews

/// A selectable card representing a single room.
///
/// The card displays an SF Symbol icon and a label. Its appearance flips between
/// an unselected (white background, black content) and selected (blue
/// background, white content) state depending on ``isSelected``.
///
/// Selection handling is applied by the parent view via a tap gesture.
private struct OnboardingRoomCard: View {
    var width = UIScreen.main.bounds.width
    var height = UIScreen.main.bounds.height
    
    var text: String
    var symbol: String
    var isSelected: Bool = false
    
    var body: some View {
        ZStack {
            Image(systemName: symbol)
                .resizable()
                .scaledToFit()
                .frame(width: width * 0.2, height: height * 0.1)
                .padding(.bottom, 20)
                .foregroundColor(isSelected ? .white : .black)
            
            Text(text)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 20)
                .foregroundColor(isSelected ? .white : .black)
        }
        .frame(width: width * 0.42, height: height * 0.2)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .foregroundColor(isSelected ? .blue : .white)
                .shadow(color: .black.opacity(0.25), radius: 6.85, x: 0, y: 4)
        )
    }
}

#Preview {
    @Previewable @State var viewModel = OnboardingViewModel()
    return SelectRoomsOnboardingView(viewModel: $viewModel)
}
