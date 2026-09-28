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
    /// The specific occurrence this card represents, when opened from the list
    /// layout. `nil` in the grid, where the card stands for the chore as a whole.
    var recurrentAssignment: RecurrentAssignmentModel?
    
    @Bindable var carouselViewModel: CarouselViewModel
    
    /// The day being shown: this occurrence's own day, or the chore's next date.
    var occurrenceDate: Date? {
        recurrentAssignment?.day ?? nextDate
    }
    
    var nextDate: Date? { carouselViewModel.nextDate(for: chore) }
    
    var isShowingBack: Bool
    
    @State private var checkList: [CheckItemModel] = []
    
    var room: RoomModel? { carouselViewModel.getRoom(for: chore) }
    var allResponsibleUsers: [UserModel] { carouselViewModel.getUsers(for: chore) }
    
    var targetAssignments: [RecurrentAssignmentModel] {
        // A card opened from a specific occurrence shows only that one
        if let recurrentAssignment { return [recurrentAssignment] }
        return carouselViewModel.getAssignments(for: chore, on: nextDate)
    }
    
    var occurrenceResponsibleUsers: [UserModel] {
        guard chore.dailyAssignmentsReference?.isEmpty == false else {
            guard let refs = chore.allResponsibleUsersReference else { return [] }
            
            let ids = Set(refs.compactMap { $0.recordID })
            
            return carouselViewModel.userModels.filter { user in
                guard let id = user.recordID else { return false }
                return ids.contains(id)
            }
        }

        let userIDs = Set(targetAssignments.compactMap { $0.userReference?.recordID })
        return carouselViewModel.userModels.filter { user in
            guard let id = user.recordID else { return false }
            return userIDs.contains(id)
        }
    }
    
    var isOccurrenceDone: Bool {
        carouselViewModel.isDone(for: chore, assignment: recurrentAssignment)
    }
    
    
    var body: some View {
        let _ = print("details:", chore.name, recurrentAssignment?.recordID?.recordName ?? "NIL")
        ZStack {
            VStack(spacing: 0) {
                header
                
                info
                
                VStack {
                    postponeButtons
                    
                    SwipeToCompleteButton(isDone: isOccurrenceDone, action: {
                        Task {
                            recurrentAssignment == nil
                            ? await carouselViewModel.toggle(chore: chore)
                            : await carouselViewModel.toggle(assignment: recurrentAssignment!)
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
            Image(systemName: room?.symbol ?? chore.symbolName)
                .resizable()
                .scaledToFit()
                .frame(width: width * 0.19, height: height * 0.09)
                .fontWeight(.thin)
            
            Text(chore.name)
                .font(.system(size: 25))
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
                .frame(width: width * 0.7)
            
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
                    .font(.system(size: 14))
                    .frame(width: width * 0.75, alignment: .leading)
                
                HStack {
                    Text("Cômodo")
                        .font(.system(size: 15))
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    CapsuleTag(
                        tagName: room?.name ?? "Unnamed room",
                        tagColor: room?.color.uiColor ?? .gray,
                        horizontalPadding: 10.0,
                        verticalPadding: 1.5
                    )
                }
                
                HStack {
                    Text("Checklist")
                        .font(.system(size: 15))
                        .fontWeight(.semibold)
                    Spacer()
                    Text(occurrenceDate?.formatted(date: .numeric, time: .omitted) ?? "Sem data definida")
                        .font(.system(size: 12))
                }
                
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
                    .font(.system(size: 13))
                    .foregroundColor(.black)
            }
            .padding(.horizontal, 25)
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
                    .font(.system(size: 13))
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
            
            if occurrenceResponsibleUsers.count == 1 {
                UserProfilePictureTag(user: occurrenceResponsibleUsers.first, widthMultiplier: 0.08)
            } else {
                UserProfilePictureList(users: occurrenceResponsibleUsers, widthMultiplier: 0.08)
            }
            
            NavigationLink {
                CreateAndEditChoreView(
                    originalModel: chore,
                    availableHouseUsers: carouselViewModel.userModels,
                    carouselViewModel: carouselViewModel,
                    targetAssignments: targetAssignments
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
                    .font(.system(size: 17, weight: .semibold))
                
                Text(item.name)
                    .strikethrough(item.isDone, color: .gray)
                    .foregroundColor(item.isDone ? .gray : .black)
                    .font(.system(size: 13))
                    .multilineTextAlignment(.leading)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    @Previewable @State var isShowingBack = true
    
    let room: RoomModel = {
        var room = RoomModel(name: "Cozinha", symbol: "fork.knife", color: .orange)
        room.recordID = CKRecord.ID(recordName: "preview-room")
        return room
    }()
    
    let chore: ChoreModel = {
        let chore = ChoreModel(
            name: "Lavar a louça",
            description: "Lavar tudo que estiver na pia, secar e guardar nos armários.",
            frequency: .daily,
            duration: 1200,
            isPublic: true,
            priorityTag: .medium,
            roomReference: CKRecord.Reference(
                recordID: CKRecord.ID(recordName: "preview-room"),
                action: .none
            )
        )
        chore.symbolName = "toilet"
        return chore
    }()
    
    let vm: CarouselViewModel = {
        let vm = CarouselViewModel()
        vm.roomModels = [room]
        return vm
    }()
    
    ChoreDetailsCard(chore: chore, carouselViewModel: vm, isShowingBack: isShowingBack)
}
