//
//  ChoreCardListStyle.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 26/08/26.
//

import Foundation
import SwiftUI
import UIKit
import CloudKit

/// A compact row representation of a chore, utilized in the vertical list layout mode.
struct ChoreCardListStyle: View {
    var chore: ChoreModel
    let namespace: Namespace.ID
    
    @Bindable var carouselViewModel: CarouselViewModel
    var onTap: () -> Void = {}
    
    var room: RoomModel? { carouselViewModel.getRoom(for: chore) }
    
    var nextDate: Date? { carouselViewModel.nextDate(for: chore) }
    
    var targetAssignments: [RecurrentAssignmentModel] {
        carouselViewModel.getAssignments(for: chore, on: nextDate)
    }
    
    var occurrenceResponsibleUsers: [UserModel] {
        let userIDs = Set(targetAssignments.compactMap { $0.userReference?.recordID })
        return carouselViewModel.userModels.filter { user in
            guard let id = user.recordID else { return false }
            return userIDs.contains(id)
        }
    }
    
    var width = UIScreen.main.bounds.width
    var height = UIScreen.main.bounds.height
    
    var body: some View {
        ZStack {
            FolderShape(
                cornerRadius: 25,
                tabWidth: 95,
                topCutoutHeight: 38
            )
            .fill(room?.color.uiColor ?? .gray)
            .shadow(color: .black.opacity(0.21), radius: 3.35, x: 0, y: 5)
            
            HStack(spacing: 30) {
                Image(systemName: chore.symbolName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: width * 0.1, height: height * 0.08)
                    .foregroundColor(.white)
                    .fontWeight(.thin)
                
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 10) {
                        HStack(spacing: -5) {
                            ForEach(occurrenceResponsibleUsers, id: \.recordID) { user in
                                UserProfilePictureTag(user: user, widthMultiplier: 0.07)
                                    .shadow(color: .black.opacity(0.24), radius: 1.83087, x: 1.71644, y: 1.14429)
                            }
                        }
                        .padding(.leading, 4)
                        .padding(.bottom, 8)
                        
                        // MARK: - Tags
                        CapsuleTag(
                            tagName: chore.priorityTag.rawValue,
                            tagColor: chore.priorityTag.color,
                            horizontalPadding: 7.0,
                            verticalPadding: 1.0
                        )
                        
                        CapsuleTag(
                            tagName: chore.frequency.rawValue,
                            tagColor: chore.frequency.color,
                            horizontalPadding: 7.0,
                            verticalPadding: 1.0
                        )
                    }
                    
                    // MARK: - Room name, chore name and completion button
                    VStack {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(room?.name ?? "Room not found")
                                    .font(.caption)
                                
                                Text(chore.name)
                                    .font(.title2)
                                    .bold()
                            }
                            .foregroundColor(.white)
                            
                            Spacer()
                            
                            // Completion button
                            Button {
                                Task {
                                    await chore.toggle()
                                }
                            } label: {
                                ZStack {
                                    Circle()
                                        .foregroundColor(.white)
                                        .frame(width: width * 0.05)
                                    
                                    Image(systemName: chore.isDone ? "checkmark.circle.fill" : "circle.fill")
                                        .foregroundColor(chore.isDone ? .black : .white)
                                        .font(.title)
                                }
                            }
                        }
                    }
                }
                .padding(.bottom, 12)
            }
            .padding(.horizontal, 28)
        }
        .frame(width: width * 0.92)
        .frame(minHeight: height * 0.14)
        .onTapGesture(perform: onTap)
        .transition(.identity)
    }
}
