//
//  ChoresViewButtonsSection.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 31/08/26.
//

import SwiftUI

/// Defines the overlay layout region containing core chore action buttons
struct ChoresViewButtonsSection: View {
    
    @State private var houseUsers: [UserModel] = []
    @State private var showCreateView = false
    
    @Bindable var carouselViewModel: CarouselViewModel
    
    var body: some View {
        HStack {
            Spacer()
            
//            Button {
//                // TODO: - Get task from list of unasigned tasks
//            } label: {
//                Image(systemName: "hand.rays")
//                    .font(.system(size: 28))
//                    .padding(15)
//                    .foregroundColor(.black)
//                    .contentShape(Circle())
//            }
//            .buttonStyle(.plain)
//            .glassEffect(
//                .regular.interactive(),
//                in: .circle
//            )
            
            // MARK: - Navigation to create a new task
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
                    frequency: .daily,
                    duration: 0,
                    isPublic: true,
                    priorityTag: .low
                ),
                availableHouseUsers: houseUsers, carouselViewModel: carouselViewModel
            )
        }
        .task {
            houseUsers = await CloudKitManager.shared.fetchAll(UserModel.self)
        }
    }
}

//#Preview {
//    ChoresViewButtonsSection()
//}
