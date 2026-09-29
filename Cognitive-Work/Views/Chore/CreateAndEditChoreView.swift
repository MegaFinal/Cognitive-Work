//
//  CreateAndEditChoreView.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 28/08/26.
//

import SwiftUI
import CloudKit

/// A form view utilized to create a new chore or edit an existing one.
///
/// This view isolates the user's edits in a `ChoreDTO`. The underlying `originalModel`
/// is only modified and persisted to CloudKit when the user explicitly confirms the changes.
struct CreateAndEditChoreView: View {
    
    init(originalModel: ChoreModel,
         availableHouseUsers: [UserModel],
         carouselViewModel: CarouselViewModel,
         targetAssignments: [RecurrentAssignmentModel] = []) {
        self.originalModel = originalModel
        self.carouselViewModel = carouselViewModel
        self.targetAssignments = targetAssignments
        
        var bestByOwner: [String: UserModel] = [:]
        for user in availableHouseUsers {
            let key = user.ownerRecordName
            if let existing = bestByOwner[key] {
                if existing.houseReference == nil && user.houseReference != nil {
                    bestByOwner[key] = user
                }
            } else {
                bestByOwner[key] = user
            }
        }
        
        self._availableHouseUsers = State(initialValue: Array(bestByOwner.values))
        self._choreDTO = State(initialValue: ChoreDTO(from: originalModel, users: [], checklist: [], room: nil))
        
        self._availableRooms = State(initialValue: [])
        self._isSaving = State(initialValue: false)
    }
    
    /// The persisted chore being edited, or an unsaved chore instance when creating a new one.
    var originalModel: ChoreModel
    
    var targetAssignments: [RecurrentAssignmentModel]
    
    @State private var availableHouseUsers: [UserModel]
    @State private var availableRooms: [RoomModel] = []
    
    /// A local copy of the chore's editable fields to prevent wrong modifications.
    @State private var choreDTO: ChoreDTO
    
    /// Indicates whether an asynchronous save operation is currently in progress.
    @State private var isSaving = false
    
    /// The date picked in the calendar (nil = not chosen; the engine schedules it as before).
    @State private var selectedDate: Date?
    
    /// Indicates whether the delete operation triggered by ``deleteButton`` is in progress.
    @State private var isDeleting = false
    @State private var showDeleteConfirmation = false
    
    /// Responsible users the chore already had when this screen opened.
    /// Only users added on top of these earn points on save.
    @State private var initialResponsibleIDs: Set<CKRecord.ID> = []
    
    @Bindable var carouselViewModel: CarouselViewModel
    
    @Environment(\.dismiss) private var dismiss
    
    /// Whether this screen is editing a chore that already exists in CloudKit, as opposed to
    /// the creation flow (`ChoresViewButtonsSection` passes in a fresh, unsaved `ChoreModel`).
    /// ``deleteButton`` only ever appears on the edit side of this shared screen.
    private var isEditingExistingChore: Bool {
        originalModel.recordID != nil
    }
    
    /// Days the calendar shows. Same rules as the claim sheet:
    /// weekly (editing an occurrence):  that occurrence's week;
    /// everything else: the two weeks the engine generated.
    private var dateWindow: Range<Date> {
        let calendar = Calendar.current

        if choreDTO.frequency == .weekly {
            if let anchor = targetAssignments.first?.day {
                // Editing an occurrence: that occurrence's week.
                return weekRange(containing: anchor, calendar: calendar)
            }
            if !isEditingExistingChore {
                // Creating a new chore: the current week.
                return weekRange(containing: Date(), calendar: calendar)
            }
        }

        // Everything else (including editing without an occurrence): the engine's two weeks.
        return carouselViewModel.cycleWindow ?? carouselViewModel.pickerWindow
    }

    private func weekRange(containing date: Date, calendar: Calendar) -> Range<Date> {
        let startOfWeek = calendar.date(
            from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        ) ?? calendar.startOfDay(for: date)
        let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfWeek) ?? startOfWeek
        return startOfWeek..<endOfWeek
    }
    
    
    // MARK: - Main Body
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 25) {
                header
                
                // MARK: - Pickers
                VStack(spacing: 10) {
                    HStack {
                        Text("Prioridade")
                        Spacer()
                        ChoreTagPicker(chore: $choreDTO, type: .priority)
                    }
                    
                    HStack {
                        Text("Duração")
                        Spacer()
                        ChoreTagPicker(chore: $choreDTO, type: .duration)
                    }
                    
                    HStack {
                        Text("Frequência")
                        Spacer()
                        ChoreTagPicker(chore: $choreDTO, type: .frequency)
                    }
                    
                    if choreDTO.frequency != .daily {
                        dateSection
                    }
                    
                }
                .font(.system(size: 15))
                .fontWeight(.semibold)
                
                // MARK: - Description
                VStack(alignment: .leading, spacing: 10) {
                    Text("Descrição")
                        .font(.system(size: 15))
                        .fontWeight(.semibold)
                    
                    TextField("Descrição da Tarefa", text: $choreDTO.description, axis: .vertical)
                        .font(.system(size: 17))
                        .foregroundColor(.gray)
                        .characterLimit(250, text: $choreDTO.description)
                }
                
                // MARK: - Checklist
                checklistSection
                
                // MARK: - Responsible Users
                VStack(alignment: .leading, spacing: 10) {
                    Text("Responsáveis")
                        .font(.system(size: 15))
                        .fontWeight(.semibold)
                    
                    ResponsibleUserPicker(availableUsers: availableHouseUsers, selectedUsers: $choreDTO.responsibleUsers)
                }
                
                // MARK: - Visibility Toggle
                publicToggleSection
                
                Spacer()
                
                // MARK: - Confirmation Button
                confirmButton
                
                // MARK: - Delete Button
                if isEditingExistingChore {
                    deleteButton
                }
            }
            .padding(.vertical)
            .frame(width: width * 0.9)
        }
        .task {
            availableRooms = await CloudKitManager.shared.fetchAll(RoomModel.self)
                .filter { $0.name != "Casa" }
            choreDTO.room = await originalModel.room
            
            let checklistModels = await originalModel.checkList
            choreDTO.checklist = checklistModels.map(CheckItemDTO.init(from:))
            choreDTO.hasChecklist = !choreDTO.checklist.isEmpty
            
            if !targetAssignments.isEmpty {
                let userIDs = Set(targetAssignments.compactMap { $0.userReference?.recordID })
                choreDTO.responsibleUsers = availableHouseUsers.filter { user in
                    guard let id = user.recordID else { return false }
                    return userIDs.contains(id)
                }
            } else if let refs = originalModel.allResponsibleUsersReference {
                let userIDs = Set(refs.map { $0.recordID })
                choreDTO.responsibleUsers = availableHouseUsers.filter { userIDs.contains($0.recordID ?? CKRecord.ID(recordName: "")) }
            }
            
            if let occurrence = targetAssignments.first {
                selectedDate = occurrence.day
            } else {
                selectedDate = originalModel.dueDate
            }
            
            initialResponsibleIDs = Set(choreDTO.responsibleUsers.compactMap(\.recordID))
        }
        .onChange(of: choreDTO.frequency) { _, _ in
            // The window changes with the frequency; drop a date that no longer fits.
            if let date = selectedDate,
               !dateWindow.contains(date.startOfDay) || date.startOfDay < Calendar.current.startOfDay(for: Date()) {
                selectedDate = nil
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .dismissKeyboardOnTap()
        .alert("Excluir Tarefa?", isPresented: $showDeleteConfirmation) {
            Button("Cancelar", role: .cancel) {}
            Button("Excluir", role: .destructive) {
                Task {
                    await deleteChore()
                }
            }
        } message: {
            Text("Se esta tarefa for recorrente, apenas esta ocorrência será excluída — as demais continuam como estão. Essa ação é permanente.")
        }
        .alert(
            "Não foi possível excluir",
            isPresented: Binding(
                get: { carouselViewModel.errorMessage != nil },
                set: { if !$0 { carouselViewModel.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(carouselViewModel.errorMessage ?? "")
        }
        .blockingOperation(isPresented: $isDeleting, message: "Excluindo tarefa...")
    }
    
    // MARK: - Subviews
    
    /// The uppermost structural section of the form: iconography, chore name field and room selection.
    private var header: some View {
        HStack {
            Image(systemName: choreDTO.room?.symbol ?? choreDTO.symbolName)
                .resizable()
                .scaledToFit()
                .frame(width: width * 0.15)
                .fontWeight(.thin)
                .padding(.leading, 8)
            
            Spacer()
            
            VStack(spacing: 25) {
                VStack(spacing: 2) {
                    TextField(
                        "",
                        text: $choreDTO.name,
                        prompt: Text("Nome da Tarefa")
                            .foregroundStyle(.black)
                    )
                    .font(.system(size: 28))
                    .bold()
                    .characterLimit(18, text: $choreDTO.name)
                    
                    Capsule()
                        .frame(height: height * 0.0015)
                }
                
                HStack {
                    Text("Cômodo")
                        .bold()
                    
                    Spacer()
                    
                    Menu {
                        Picker("Cômodo", selection: $choreDTO.room) {
                            ForEach(availableRooms, id: \.self) { room in
                                ColorIconTagLabel(title: room.name.capitalized, color: room.color.uiColor)
                                    .tag(RoomModel?(room))
                            }
                        }
                    }
                    label: {
                        HStack {
                            CapsuleTag(
                                tagName: choreDTO.room?.name.capitalized ?? "Sem Cômodo",
                                tagColor: choreDTO.room?.color.uiColor ?? .gray,
                                horizontalPadding: 10.0,
                                verticalPadding: 1.5
                            )
                            
                            Image(systemName: "chevron.up.chevron.down")
                                .foregroundColor(.black)
                                .imageScale(.small)
                        }
                    }
                }
            }
            .frame(width: width * 0.65)
        }
        
    }
    
    /// Calendar shown below the pickers for every frequency except daily.
    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Data")
                .font(.system(size: 15))
                .fontWeight(.semibold)
            
            CustomCalendar(
                selectedDate: $selectedDate,
                window: dateWindow,
                opacityForDay: { carouselViewModel.loadOpacity(on: $0, in: dateWindow) },
                earliestSelectable: Calendar.current.startOfDay(for: Date())
            )
        }
    }
    
    /// Encapsulates the toggle and the inline editor for the chore's checklist.
    private var checklistSection: some View {
        VStack {
            HStack {
                Text("Checklist")
                    .font(.system(size: 15))
                    .fontWeight(.semibold)
                
                Spacer()
                
                Toggle("", isOn: $choreDTO.hasChecklist)
                    .toggleStyle(.switch)
                    .onChange(of: choreDTO.hasChecklist) { _, isOn in
                        if isOn && choreDTO.checklist.isEmpty {
                            choreDTO.checklist.append(CheckItemDTO(name: "", isDone: false))
                        }
                    }
                    .padding(.trailing, 3)
            }
            .frame(width: width * 0.9)
            
            if choreDTO.hasChecklist {
                CheckListCreateAndEdit(hasChecklist: $choreDTO.hasChecklist, localChecklist: $choreDTO.checklist)
            }
        }
    }
    
    /// Contains the switch for deciding whether the chore should be public to the household.
    private var publicToggleSection: some View {
        VStack {
            HStack {
                Text("Essa tarefa é para a casa?")
                    .font(.system(size: 15))
                    .fontWeight(.semibold)
                
                Spacer()
                
                Toggle("", isOn: $choreDTO.isPublic)
                    .toggleStyle(.switch)
                    .padding(.trailing, 7)
                    .frame(width: width * 0.37)
            }
            .frame(width: width * 0.9)
            
            Text("Caso essa tarefa seja para a sua casa ela aparecerá publica para todos os moradores.")
                .font(.system(size: 15))
                .italic()
                .foregroundColor(.gray)
        }
    }
    
    /// Bottom-anchored confirmation button, featuring an embedded loading state.
    private var confirmButton: some View {
        HStack {
            Spacer()
            
            Button {
                Task {
                    await confirmAndSave()
                    carouselViewModel.refreshVisible()
                }
            } label: {
                Group {
                    if isSaving {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Confirmar")
                            .foregroundColor(.white)
                            .fontWeight(.bold)
                    }
                }
                .frame(width: width * 0.8, height: height * 0.06)
                .background(Color.blue)
                .clipShape(Capsule())
            }
            .disabled(choreDTO.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving || isDeleting)
            
            Spacer()
        }
    }
    
    /// Bottom-anchored destructive action that deletes the chore being edited
    private var deleteButton: some View {
        Button {
            showDeleteConfirmation = true
        } label: {
            Group {
                if isDeleting {
                    ProgressView()
                        .tint(.red)
                } else {
                    Text("Excluir Tarefa")
                        .fontWeight(.semibold)
                }
            }
            .frame(height: height * 0.03)
        }
        .foregroundColor(.red)
        .disabled(isSaving || isDeleting)
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }
    
    // MARK: - Methods
    
    /// Persists the modifications from the local copy onto `originalModel` and dismisses the view.
    @MainActor
    private func confirmAndSave() async {
        isSaving = true
        
        let isNewChore = !isEditingExistingChore
        let cycleEnd = carouselViewModel.currentCycleEnd
        
        if choreDTO.frequency == .none {
                originalModel.dueDate = selectedDate
            }
        
        await originalModel.save(from: choreDTO, targetAssignments: targetAssignments)
        
        // A recurring chore created mid-cycle gets its occurrences for the rest of the cycle
        if isNewChore {
            await scheduleNewRecurringChore(
                originalModel,
                responsibleUsers: choreDTO.responsibleUsers,
                cycleEnd: cycleEnd,
                pickedDate: selectedDate
            )
        }
        
        //MARK: Gamification score system
        var score = 0
        
        if isNewChore {
            score += choreDTO.hasFullDetails
            ? ScoreValues.choreAdded.points + ScoreValues.choreCreatedWithFullDetails.points
            : ScoreValues.choreAdded.points
        }
        
        score += await responsibleAssignmentScore()
        
        if score > 0 {
            await ScoreManager.shared.assignScoreForMyUser(score: score)
        }
        
        
        await applyPickedDateToOccurrence(isNewChore: isNewChore)
        
        let newOccurrenceIDs: Set<CKRecord.ID> = isNewChore
            ? Set((originalModel.dailyAssignmentsReference ?? []).map { $0.recordID })
            : []
        
        await carouselViewModel.refreshAfterChoreUpdate()
        
        let updatedChore = originalModel
        
        if updatedChore.frequency == .none {
            await carouselViewModel.syncSingleChoreToCalendar(updatedChore)
        } else {
            let freshAssignments = await CloudKitManager.shared.fetchAll(RecurrentAssignmentModel.self)
            carouselViewModel.dailyAssignments = freshAssignments
            
            // The occurrences just created for a new chore are synced too.
            let targetIDs = Set(targetAssignments.compactMap { $0.recordID }).union(newOccurrenceIDs)
            let updatedTargets = freshAssignments.filter { targetIDs.contains($0.recordID ?? CKRecord.ID(recordName: "")) }
            
            for assignment in updatedTargets {
                await carouselViewModel.syncSingleAssignmentToCalendar(for: assignment, chore: updatedChore)
            }
        }
        
        isSaving = false
        dismiss()
    }
    
    /// Points for the responsible users added during this edit (users already assigned when
    /// the screen opened don't count). Assigning yourself is worth more than assigning others.
    @MainActor
    private func responsibleAssignmentScore() async -> Int {
        let addedUsers = choreDTO.responsibleUsers.filter { user in
            guard let id = user.recordID else { return false }
            return !initialResponsibleIDs.contains(id)
        }
        guard !addedUsers.isEmpty else { return 0 }
        
        let myOwnerRecordName = await CloudKitManager.shared.fetchMyHouseUser()?.ownerRecordName
        
        return addedUsers.reduce(0) { total, user in
            let isSelf = user.ownerRecordName == myOwnerRecordName
            return total + ScoreValues.responsibleAssigned(isSelf: isSelf).points
        }
    }
    
    /// Writes the date picked in the calendar onto the recurring chore's assignment.
    @MainActor
    private func applyPickedDateToOccurrence(isNewChore: Bool) async {
        switch choreDTO.frequency {
        case .weekly, .fortnightly, .monthly: break
        default: return
        }
        
        guard let selectedDate else { return }
        let calendar = Calendar.current
        let picked = calendar.startOfDay(for: selectedDate)
        
        if let target = targetAssignments.first {
            guard !calendar.isDate(target.day, inSameDayAs: picked) else { return }
            target.day = picked
            await CloudKitManager.shared.update(target)
        } else if isNewChore {
            // Find the just-generated assignment closest to the picked date and move it to that date
            let created = await originalModel.dailyAssignments
            guard let closest = created.min(by: {
                abs($0.day.timeIntervalSince(picked)) < abs($1.day.timeIntervalSince(picked))
            }) else { return }
            closest.day = picked
            await CloudKitManager.shared.update(closest)
        }
    }
    
    /// Deletes the chore being edited — or, when it's recurring, just the occurrence(s) this
    /// screen was opened for (``targetAssignments``) — then dismisses on success.
    @MainActor
    private func deleteChore() async {
        isDeleting = true
        
        let success = await carouselViewModel.delete(chore: originalModel, targetOccurrences: targetAssignments)
        
        isDeleting = false
        
        if success {
            dismiss()
        }
    }
    
    private struct ColorIconTagLabel: View {
        
        /// The string to be displayed next to the icon.
        let title: String
        
        /// The background color for the circular icon shape.
        let color: Color
        
        var body: some View {
            Label {
                Text(title)
            } icon: {
                Image(uiImage: .coloredCircle(color: color))
                    .renderingMode(.original)
            }
        }
    }
}

extension ChoreDTO {
    var hasFullDetails: Bool {
        self.room != nil
        && self.priorityTag != .undefined
        && self.frequency != .undefined
        && self.duration > 0
        && !self.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !self.responsibleUsers.isEmpty
    }
}
