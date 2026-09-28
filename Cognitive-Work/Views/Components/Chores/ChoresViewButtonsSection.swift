//
//  ChoresViewButtonsSection.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 31/08/26.
//

import SwiftUI

/// Defines the overlay layout region containing core chore action buttons
struct ChoresViewButtonsSection: View {
    
    @State private var showCreateView = false
    
    @Bindable var carouselViewModel: CarouselViewModel

    /// The house members offered in the new-chore form.
    private var houseUsers: [UserModel] {
        carouselViewModel.userModels
    }
    
    var body: some View {
        HStack {
            Spacer()
            
            Button {
                carouselViewModel.toggleUnassignedList()
            } label: {
                Image(systemName: "hand.rays")
                    .font(.system(size: 28))
                    .padding(15)
                    .foregroundColor(.black)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .glassEffect(
                .regular.interactive(),
                in: .circle
            )
            
            
            Button {
                showCreateView = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 28))
                    .foregroundColor(.white)
                    .padding(20)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .glassEffect(
                .regular.interactive().tint(.black),
                in: .circle
            )
        }
        .padding(.horizontal, 30)
        .padding(.bottom)
        .navigationDestination(isPresented: $showCreateView) {
            CreateAndEditChoreView(
                originalModel: ChoreModel(
                    name: "",
                    description: "",
                    isDone: false,
                    frequency: .undefined,
                    duration: 0,
                    isPublic: true,
                    priorityTag: .undefined
                ),
                availableHouseUsers: houseUsers, carouselViewModel: carouselViewModel
            )
        }
    }
}

#Preview {
    NavigationStack {
        ChoresViewButtonsSection(carouselViewModel: CarouselViewModel())
    }
}
