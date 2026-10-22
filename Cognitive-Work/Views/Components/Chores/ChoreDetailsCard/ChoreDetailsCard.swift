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
    /// The chore shown.
    @Bindable var chore: ChoreModel
    
    /// The specific occurrence this card represents, when opened from the list
    /// layout. `nil` in the grid, where the card stands for the chore as a whole.
    var recurrentAssignment: RecurrentAssignmentModel?
    
    /// Gives the room, members, dates and assignments, and saves completion and postponing.
    @Bindable var carouselViewModel: CarouselViewModel
    
    /// The day being shown: this occurrence's own day, or the chore's next date.
    var occurrenceDate: Date? {
        recurrentAssignment?.day ?? nextDate
    }
    
    /// The next day the chore is due.
    var nextDate: Date? { carouselViewModel.nextDate(for: chore) }
    
    /// Whether the card is flipped to this side (the checklist loads only then).
    var isShowingBack: Bool
    
    /// The chore's checklist items.
    @State private var checkList: [CheckItemModel] = []
    
    /// `true` while the checklist items are fetched the first time the card is flipped.
    @State private var isLoadingChecklist = false
    
    /// Which postpone action is being saved, to show its spinner and block double taps.
    @State private var postponingDays: Int?
    
    /// Shown when the new date couldn't be saved.
    @State private var didFailToPostpone = false
    
    /// The chore's room (icon, color and name).
    var room: RoomModel? { carouselViewModel.getRoom(for: chore) }
    /// Every member responsible for the chore.
    var allResponsibleUsers: [UserModel] { carouselViewModel.getUsers(for: chore) }
    
    /// The occurrence(s) this card is about.
    var targetAssignments: [RecurrentAssignmentModel] {
        // A card opened from a specific occurrence shows only that one
        if let recurrentAssignment { return [recurrentAssignment] }
        return carouselViewModel.getAssignments(for: chore, on: nextDate)
    }
    
    /// Collects all responsible users for this chore and occurrence to display in the header action bar.
    ///
    /// Prioritizes individual occurrence's multi-user assignment list (`userReferences`),
    /// falling back to the chore's global rotation list (`allResponsibleUsersReference`).
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
    
    /// Whether this occurrence is already done.
    var isOccurrenceDone: Bool {
        carouselViewModel.isDone(for: chore, assignment: recurrentAssignment)
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // MARK: - Icon, name and tags
                header
                
                // MARK: - Description, room and checklist
                info
                
                // MARK: - Postpone buttons and swipe to complete
                VStack {
                    // Daily chores can't be postponed: tomorrow already has its own occurrence.
                    if chore.frequency != .daily {
                        postponeButtons
                        
                        SwipeToCompleteButton(isDone: isOccurrenceDone, action: {
                            Task {
                                recurrentAssignment == nil
                                ? await carouselViewModel.toggle(chore: chore)
                                : await carouselViewModel.toggle(assignment: recurrentAssignment!)
                            }
                        }, color: room?.color.uiColor ?? .gray)
                        .padding(.horizontal, 30)
                    } else {
                        SwipeToCompleteButton(isDone: isOccurrenceDone, action: {
                            Task {
                                recurrentAssignment == nil
                                ? await carouselViewModel.toggle(chore: chore)
                                : await carouselViewModel.toggle(assignment: recurrentAssignment!)
                            }
                        }, color: room?.color.uiColor ?? .gray)
                        .padding(.horizontal, 30)
                        .padding(.top, height * 0.06)
                    }
                }
            }
            .padding(.top, 8)
            
            // MARK: - Close, avatars and edit (top bar)
            actionBar
                // Drawn on top but read first: close, people, edit.
                .accessibilitySortPriority(1)
        }
        // MARK: - Loads the checklist and shows the postpone error
        .task(id: isShowingBack) {
            if isShowingBack && checkList.isEmpty && !(chore.checkListReference ?? []).isEmpty {
                isLoadingChecklist = true
                checkList = await chore.checkList
                isLoadingChecklist = false
            }
        }
        .alert("Não foi possível adiar", isPresented: $didFailToPostpone) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Verifique sua conexão e tente novamente.")
        }
        .frame(width: width * 0.88, height: height * 0.599)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 31))
        .shadow(color: .black.opacity(0.14), radius: 20.39595, x: 0, y: 5.80668)
        .accessibilityElement(children: .contain)
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
                .accessibilityDecorative()
            
            Text(chore.localizedName)
                .font(.custom("Alan Sans", size: 28))
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
                .frame(width: width * 0.7)
                .accessibilityAddTraits(.isHeader)
            
            ChoreTagsRow(chore: chore, spacing: 12, horizontalPadding: 10.0, verticalPadding: 1.5)
                .accessibilityElement(children: .ignore)
                .voiceOverLabel(carouselViewModel.accessibilityTagsText(for: chore))
        }
        .foregroundColor(.black)
    }
    
    /// The central information scroll view: description, room tag, and the interactive checklist.
    private var info: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                Text(chore.localizedDescription)
                    .font(.system(size: 14))
                    .frame(width: width * 0.75, alignment: .leading)
                
                HStack {
                    Text("Cômodo")
                        .font(.system(size: 15))
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    CapsuleTag(
                        tagName: room?.name.localizedDefault ?? L10n.tr("Sem cômodo"),
                        tagColor: room?.color.uiColor ?? .gray,
                        horizontalPadding: 10.0,
                        verticalPadding: 1.5
                    )
                }
                .accessibilityElement(children: .ignore)
                .voiceOverLabel(L10n.tr("Cômodo: %@", carouselViewModel.accessibilityRoomName(for: chore)))
                
                HStack {
                    Text("Checklist")
                        .font(.system(size: 15))
                        .fontWeight(.semibold)
                    Spacer()
                    Text(occurrenceDate?.formatted(.dateTime.day().month(.twoDigits).year().locale(L10n.locale)) ?? L10n.tr("Sem data definida"))
                        .font(.system(size: 12))
                }
                .accessibilityElement(children: .ignore)
                .voiceOverLabel(checklistHeaderAccessibilityLabel)
                .accessibilityAddTraits(.isHeader)
                
                VStack(alignment: .leading, spacing: 5) {
                    if isLoadingChecklist {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .voiceOverLabel(L10n.tr("Carregando checklist"))
                    }
                    ForEach($checkList, id: \.id) {$item in
                        ChecklistItemButton(item: $item)
                    }
                }
            }
        }
        .frame(width: width * 0.75, height: height * 0.24)
        .padding(.top)
    }
    
    /// Spoken checklist header: "Checklist, sexta-feira, 25 de setembro, 2 de 5 itens concluídos".
    private var checklistHeaderAccessibilityLabel: String {
        var parts = [L10n.tr("Checklist")]
        parts.append(occurrenceDate.map(CarouselViewModel.accessibilityDateText) ?? L10n.tr("Sem data definida"))
        if !checkList.isEmpty {
            let done = checkList.filter(\.isDone).count
            parts.append(L10n.tr("%lld de %lld itens concluídos", done, checkList.count))
        }
        return parts.joined(separator: ", ")
    }
    
    /// Shorter English labels need less horizontal padding.
    private var isEnglish: Bool { LanguageManager.shared.current == .english }
    
    /// Quick actions to delay the chore's deadline directly from the details card.
    private var postponeButtons: some View {
        HStack {
            Button {
                postpone(byDays: 7)
            } label: {
                postponeLabel("Adiar 1 semana", days: 7)
            }
            .disabled(postponingDays != nil)
            .padding(.horizontal, isEnglish ? 18 : 25)
            .padding(.vertical, 10)
            .background(.gray.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 22))
            
            Spacer()
            
            Button {
                postpone(byDays: 1)
            } label: {
                postponeLabel("Adiar 1 dia", days: 1)
            }
            .disabled(postponingDays != nil)
            .padding(.horizontal, isEnglish ? 18 : 32)
            .padding(.vertical, 10)
            .background(.gray.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 22))
        }
        .padding(.top, 10)
        .frame(width: width * 0.72)
    }
    
    /// The postpone text, swapped for a spinner (keeping its size) while that action saves.
    private func postponeLabel(_ title: LocalizedStringKey, days: Int) -> some View {
        Text(title)
            .font(.system(size: 13))
            .foregroundColor(.black)
            .opacity(postponingDays == days ? 0 : 1)
            .overlay {
                if postponingDays == days {
                    ProgressView()
                        .controlSize(.small)
                }
            }
    }
    
    /// Saves the new date and refreshes the carousel so the card reflects it.
    private func postpone(byDays days: Int) {
        postponingDays = days
        Task {
            let success = await carouselViewModel.postpone(
                chore: chore,
                assignment: recurrentAssignment ?? targetAssignments.first,
                byDays: days
            )
            postponingDays = nil
            
            guard success else {
                HapticsManager.notify(.error)
                didFailToPostpone = true
                return
            }
            
            HapticsManager.notify(.success)
            VoiceOver.announce(days == 1 ? L10n.tr("Tarefa adiada em 1 dia") : L10n.tr("Tarefa adiada em 1 semana"))
            // The occurrence moved to another day: close the card so it leaves today's list.
            if carouselViewModel.layoutMode == .grid {
                carouselViewModel.clearFocus()
            } else {
                carouselViewModel.clearFocusedDetails()
            }
        }
    }
    
    /// Floating top bar with dismiss button, responsible user avatars, and the edit shortcut.
    private var actionBar: some View {
        HStack {
            Button {
                carouselViewModel.clearFocus()
            } label: {
                Image(systemName: "xmark")
                    .foregroundColor(.black)
            }
            .voiceOverLabel(L10n.tr("Fechar"))
            .voiceControlNames([L10n.tr("Fechar"), L10n.tr("Cancelar"), L10n.tr("Voltar")])
            .padding(12)
            .clipShape(Circle())
            .glassEffect()
            
            Spacer()
            
            // Renders single avatar view if only 1 responsible user is assigned, or avatar list view when >= 2
            if occurrenceResponsibleUsers.count == 1 {
                UserProfilePictureTag(user: occurrenceResponsibleUsers.first, widthMultiplier: 0.08)
                    .accessibilityElement(children: .ignore)
                    .voiceOverLabel(carouselViewModel.accessibilityResponsibleText(for: occurrenceResponsibleUsers))
            } else {
                UserProfilePictureList(users: occurrenceResponsibleUsers, widthMultiplier: 0.08)
                    .accessibilityElement(children: .ignore)
                    .voiceOverLabel(carouselViewModel.accessibilityResponsibleText(for: occurrenceResponsibleUsers))
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
            .voiceOverLabel(L10n.tr("Editar tarefa"))
            .voiceControlNames([L10n.tr("Editar"), L10n.tr("Editar tarefa"), L10n.tr("Lápis")])
            .voiceOverHint(isOccurrenceDone ? L10n.tr("Tarefas concluídas não podem ser editadas.") : "")
            .disabled(isOccurrenceDone)
            .padding(12)
            .background(isOccurrenceDone ? Color.gray : Color.blue)
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
            HapticsManager.selection()
            Task {
                await item.toggle()
                VoiceOver.announce(item.isDone ? L10n.tr("Concluído") : L10n.tr("Pendente"))
            }
        } label: {
            HStack {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(item.isDone ? .black : .gray)
                    .font(.system(size: 17, weight: .semibold))
                
                Text(item.name.localizedDefault)
                    .strikethrough(item.isDone, color: .gray)
                    .foregroundColor(item.isDone ? .gray : .black)
                    .font(.system(size: 13))
                    .multilineTextAlignment(.leading)
            }
        }
        .buttonStyle(.plain)
        .voiceOverLabel(item.name.localizedDefault)
        .voiceOverValue(item.isDone ? L10n.tr("Concluído") : L10n.tr("Pendente"))
        .voiceOverHint(L10n.tr("Toque duas vezes para alternar."))
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
            frequency: .weekly,
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
