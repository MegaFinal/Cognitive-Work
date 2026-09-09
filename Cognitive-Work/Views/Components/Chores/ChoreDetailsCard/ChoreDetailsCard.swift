//
//  ChoreDetailsCard.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 18/08/26.
//

import SwiftUI
import UIKit
import CloudKit

/// Represents the detailed back-face view of a chore card.
///
/// This view is revealed when the user flips or taps a card, providing full details, checklist progress,
/// postponement actions, and a completion swipe toggle.
struct ChoreDetailsCard: View {
    @Bindable var chore: ChoreModel
    @Bindable var carouselViewModel: CarouselViewModel
    
    var isShowingBack: Bool
    
    @State private var checkList: [CheckItemModel] = []
    
    var room: RoomModel? { carouselViewModel.getRoom(for: chore) }
    var allResponsibleUsers: [UserModel] { carouselViewModel.getUsers(for: chore) }
    
    var width = UIScreen.main.bounds.width
    var height = UIScreen.main.bounds.height
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                header
                
                info
                
                VStack {
                    postponeButtons
                    
                    SwipeToCompleteButton(action:  {
                        Task {
                            await chore.toggle()
                        }
                    }, color: room?.color.uiColor ?? .gray)
                    .padding(.horizontal, 30)
                }
            }
            .padding(.top, 8)
            
            actionBar
        }
        .task(id: isShowingBack) {
            if isShowingBack && checkList.isEmpty {
                checkList = await chore.checkList
            }
        }
        .frame(width: width * 0.88, height: height * 0.599)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 31))
        .shadow(color: .black.opacity(0.14), radius: 20.39595, x: 0, y: 5.80668)
    }
    
    // MARK: - Subviews
    
    /// The upper header section: the chore's primary icon, name, and status tags.
    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: chore.symbolName)
                .resizable()
                .scaledToFit()
                .frame(width: width * 0.19, height: height * 0.09)
                .fontWeight(.thin)
            
            Text(chore.name)
                .font(.title)
                .fontWeight(.semibold)
            
            HStack(spacing: 12) {
                CapsuleTag(
                    tagName: chore.priorityTag.rawValue,
                    tagColor: chore.priorityTag.color,
                    horizontalPadding: 10.0,
                    verticalPadding: 1.5
                )
                
                CapsuleTag(
                    tagName: ChoreDurationTier.from(minutes: chore.duration / 60).displayText,
                    tagColor: ChoreDurationTier.from(minutes: chore.duration / 60).color,
                    horizontalPadding: 10.0,
                    verticalPadding: 1.5
                )
                
                CapsuleTag(
                    tagName: chore.frequency.rawValue,
                    tagColor: chore.frequency.color,
                    horizontalPadding: 10.0,
                    verticalPadding: 1.5
                )
            }
        }
        .foregroundColor(.black)
    }
    
    /// The central information scroll view: description, room tag and the interactive checklist.
    private var info: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                Text(chore.description)
                    .font(.footnote)
                    .frame(width: width * 0.75, alignment: .leading)
                
                HStack {
                    Text("Cômodo")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    CapsuleTag(
                        tagName: room?.name ?? "Unnamed room",
                        tagColor: room?.color.uiColor ?? .gray,
                        horizontalPadding: 10.0,
                        verticalPadding: 1.5
                    )
                }
                
                Text("Checklist")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                VStack(alignment: .leading, spacing: 5) {
                    ForEach($checkList, id: \.id) { $item in
                        ChecklistItemButton(item: $item)
                    }
                }
            }
        }
        .frame(width: width * 0.75, height: height * 0.24)
        .padding(.top)
    }
    
    /// Quick actions to delay the chore's deadline directly from the details card.
    private var postponeButtons: some View {
        HStack {
            Button {
                Task {
                    await chore.postpone(byDays: 7)
                }
            } label: {
                Text("Adiar 1 semana")
                    .font(.footnote)
                    .foregroundColor(.black)
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 10)
            .background(.gray.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 22))
            
            Spacer()
            
            Button {
                Task {
                    await chore.postpone(byDays: 1)
                }
            } label: {
                Text("Adiar 1 dia")
                    .font(.footnote)
                    .foregroundColor(.black)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 10)
            .background(.gray.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 22))
        }
        .padding(.top, 10)
        .frame(width: width * 0.72)
    }
    
    /// Floating top bar with dismiss, responsible avatars and the edit shortcut.
    private var actionBar: some View {
        HStack {
            Button {
                carouselViewModel.clearFocus()
            } label: {
                Image(systemName: "xmark")
                    .foregroundColor(.black)
            }
            .padding(12)
            .clipShape(Circle())
            .glassEffect()
            
            Spacer()
            
            if allResponsibleUsers.count == 1 {
                UserProfilePictureTag(user: allResponsibleUsers.first, widthMultiplier: 0.1)
            } else {
                UserProfilePictureList(users: allResponsibleUsers, widthMultiplier: 0.1)
            }
            
            NavigationLink {
                CreateAndEditChoreView(
                    originalModel: chore,
                    availableHouseUsers: allResponsibleUsers
                )
            } label: {
                Image(systemName: "pencil")
                    .foregroundColor(.white)
            }
            .padding(12)
            .background(.blue)
            .clipShape(Circle())
            .glassEffect()
        }
        .padding(.horizontal)
        .padding(.top)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

// MARK: - Private subviews

/// A button representing a single, actionable checklist item.
///
/// Tap interactions directly instruct the `CheckItemModel` to asynchronously toggle its completion state.
private struct ChecklistItemButton: View {
    
    /// The checklist item model corresponding to this entry.
    @Binding var item: CheckItemModel
    
    var body: some View {
        Button {
            Task {
                await item.toggle()
            }
        } label: {
            HStack {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(item.isDone ? .black : .gray)
                    .font(.headline)
                
                Text(item.name)
                    .strikethrough(item.isDone, color: .gray)
                    .foregroundColor(item.isDone ? .gray : .black)
                    .font(.footnote)
                    .multilineTextAlignment(.leading)
            }
        }
        .buttonStyle(.plain)
    }
}
