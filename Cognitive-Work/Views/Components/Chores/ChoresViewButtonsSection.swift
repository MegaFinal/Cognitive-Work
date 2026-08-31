//
//  ChoresViewButtonsSection.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 31/08/26.
//

import SwiftUI

struct ChoresViewButtonsSection: View {
    @State private var houseUsers: [UserModel] = []
    
    var body: some View {
        HStack {
            Spacer()
            
            Button {
            } label: {
                Image(systemName: "hand.rays")
                    .font(.title)
                    .padding(15)
                    .foregroundColor(.black)
            }
            .buttonStyle(.plain)
            .glassEffect(
                .regular.interactive(),
                in: .circle
            )
            
            NavigationLink {
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
                    availableHouseUsers: houseUsers
                )
            } label: {
                Image(systemName: "plus")
                    .font(.title)
                    .foregroundColor(.white)
                    .padding(20)
            }
            .buttonStyle(.plain)
            .glassEffect(
                .regular.interactive().tint(.black),
                in: .circle
            )
        }
        .padding(.horizontal, 30)
        .padding(.bottom)
        .task {
            houseUsers = await CloudKitManager.shared.fetchAll(UserModel.self)
        }
    }
}

#Preview {
    ChoresViewButtonsSection()
}
