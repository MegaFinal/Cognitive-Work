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
    var recurrentAssignment: RecurrentAssignmentModel?
    let namespace: Namespace.ID
    
    @Bindable var carouselViewModel: CarouselViewModel
    var onTap: () -> Void = {}
    
    var room: RoomModel? { carouselViewModel.getRoom(for: chore) }
    
    var nextDate: Date? { carouselViewModel.nextDate(for: chore) }
    
    var targetAssignments: [RecurrentAssignmentModel] {
        if let recurrentAssignment {
            return [recurrentAssignment]
        }
        return carouselViewModel.getAssignments(for: chore, on: nextDate)
    }
    
    var occurrenceResponsibleUsers: [UserModel] {
        if let target = targetAssignments.first {
            if let refs = target.userReferences {
                let targetIDs = Set(refs.map(\.recordID))
                guard !targetIDs.isEmpty else { return [] }
                
                return carouselViewModel.userModels.filter { user in
                    guard let userID = user.recordID else { return false }
                    return targetIDs.contains(userID)
                }
            }
        }
        
        var targetIDs = Set<CKRecord.ID>()
        if let refs = chore.allResponsibleUsersReference, !refs.isEmpty {
            targetIDs.formUnion(refs.map(\.recordID))
        } else if let currentID = chore.currentResponsibleReference?.recordID {
            targetIDs.insert(currentID)
        }
        
        guard !targetIDs.isEmpty else { return [] }
        
        return carouselViewModel.userModels.filter { user in
            guard let userID = user.recordID else { return false }
            return targetIDs.contains(userID)
        }
    }
    
    var isOccurrenceDone: Bool {
        carouselViewModel.isDone(for: chore, assignment: recurrentAssignment)
    }
    
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
                Image(systemName: room?.symbol ?? chore.symbolName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: width * 0.1, height: height * 0.08)
                    .foregroundColor(.white)
                    .fontWeight(.thin)
                
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 10) {
                        HStack(spacing: -10) {
                            ForEach(occurrenceResponsibleUsers, id: \.recordID) { user in
                                UserProfilePictureTag(user: user, widthMultiplier: 0.07)
                                    .shadow(color: .black.opacity(0.24), radius: 1.83087, x: 1.71644, y: 1.14429)
                            }
                        }
                        .padding(.leading, 4)
                        .padding(.bottom, 8)
                        
                        HStack(spacing: 8) {
                            // MARK: - Tags
                            CapsuleTag(
                                tagName: chore.frequency.displayName,
                                tagColor: chore.frequency.color,
                                textColor: chore.frequency.textColor,
                                horizontalPadding: 7.0,
                                verticalPadding: 1.0
                            )
                            
                            CapsuleTag(
                                tagName: chore.priorityTag.displayName,
                                tagColor: chore.priorityTag.color,
                                horizontalPadding: 7.0,
                                verticalPadding: 1.0
                            )
                            
                            CapsuleTag(
                                tagName: ChoreDurationTier.from(minutes: chore.duration).displayText,
                                tagColor: ChoreDurationTier.from(minutes: chore.duration).color,
                                horizontalPadding: 7.0,
                                verticalPadding: 1.0
                            )
                        }
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    }
                    
                    // MARK: - Room name, chore name and completion button
                    VStack {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(room?.name.localizedDefault ?? L10n.tr("Sem cômodo"))
                                    .font(.system(size: 12))
                                
                                Text(chore.localizedName)
                                    .font(.system(size: 22))
                                    .bold()
                            }
                            .foregroundColor(.white)
                            
                            Spacer()
                            
                            // MARK: Completion button
                            Button {
                                toggleCompletion()
                            } label: {
                                ZStack {
                                    Circle()
                                        .foregroundColor(.white)
                                        .frame(width: width * 0.05)
                                    
                                    Image(systemName: isOccurrenceDone ? "checkmark.circle.fill" : "circle.fill")
                                        .foregroundColor(isOccurrenceDone ? .black : .white)
                                        .font(.system(size: 28))
                                }
                            }
                        }
                        .padding(.bottom, 16)
                    }
                }
            }
            .padding(.horizontal, 28)
        }
        .frame(width: width * 0.92)
        .frame(minHeight: height * 0.14)
        .onTapGesture(perform: onTap)
        .transition(.identity)
        // MARK: - VoiceOver
        // One element; the completion button becomes a named action.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(carouselViewModel.accessibilitySummary(for: chore, assignment: recurrentAssignment))
        .accessibilityHint(L10n.tr("Toque duas vezes para ver os detalhes."))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { onTap() }
        .accessibilityAction(named: Text(isOccurrenceDone ? L10n.tr("Marcar como pendente") : L10n.tr("Marcar como concluída"))) {
            toggleCompletion()
        }
    }
    
    /// Marks this occurrence as done (or not done again), from the circle button or VoiceOver.
    private func toggleCompletion() {
        let willBeDone = !isOccurrenceDone
        HapticsManager.notify(willBeDone ? .success : .warning)
        
        Task {
            recurrentAssignment == nil
            ? await carouselViewModel.toggle(chore: chore)
            : await carouselViewModel.toggle(assignment: recurrentAssignment!)
            VoiceOver.announce(willBeDone ? L10n.tr("Tarefa concluída") : L10n.tr("Tarefa marcada como pendente"))
        }
    }
}

#Preview("Card em lista") {
    @Previewable @Namespace var namespace
    
    let room: RoomModel = {
        var room = RoomModel(name: "Cozinha", symbol: "fork.knife", color: .orange)
        room.recordID = CKRecord.ID(recordName: "preview-room")
        return room
    }()
    
    let chore: ChoreModel = {
        let chore = ChoreModel(
            name: "Lavar a louça",
            description: "Depois do jantar",
            frequency: .daily,
            duration: 20,
            isPublic: true,
            priorityTag: .medium,
            roomReference: CKRecord.Reference(
                recordID: CKRecord.ID(recordName: "preview-room"),
                action: .none
            )
        )
        chore.symbolName = "dishwasher"
        return chore
    }()
    
    let vm: CarouselViewModel = {
        let vm = CarouselViewModel()
        vm.roomModels = [room]
        return vm
    }()
    
    ChoreCardListStyle(chore: chore, namespace: namespace, carouselViewModel: vm) {
        print("Tapped")
    }
}
