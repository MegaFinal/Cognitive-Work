//
//  CreateAndEditChoreViewModel.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 29/09/26.
//

import Foundation
import CloudKit

/// Drives ``CreateAndEditChoreView``, the form shared by the create and edit flows.
@MainActor
@Observable
final class CreateAndEditChoreViewModel {
    
    // MARK: - Mode
    
    /// Fixed at init, so it never flips while a new chore is being saved.
    enum Mode: Equatable {
        case create
        case edit
    }
    
    // MARK: - Alert
    
    /// A failure presented to the user while the form stays open.
    struct FormAlert: Identifiable, Equatable {
        enum Kind: Equatable {
            case saveFailed
            case deleteFailed
        }
        
        let id = UUID()
        let kind: Kind
        let message: String
        
        var title: String {
            switch kind {
            case .saveFailed: return "Não foi possível salvar"
            case .deleteFailed: return "Não foi possível excluir"
            }
        }
    }
    
    // MARK: - Dependencies
    
    /// The persisted chore being edited, or an unsaved instance when creating a new one.
    let originalModel: ChoreModel
    
    /// The occurrence(s) of a recurring chore this screen was opened for, if any.
    let targetAssignments: [RecurrentAssignmentModel]
    
    private let carouselViewModel: CarouselViewModel
    
    private let cloudKit: CloudKitManager
    private let scoreManager: ScoreManager
    
    private let now: () -> Date
    
    let mode: Mode
    
    // MARK: - Form state
    
    /// The editable copy of the chore
    var draft: ChoreDTO
    
    var selectedDate: Date?
    
    private(set) var availableRooms: [RoomModel] = []
    
    private(set) var availableHouseUsers: [UserModel]
    
    private(set) var currentHouseUser: UserModel?
    
    private(set) var isLoaded = false
    
    private(set) var isSaving = false
    
    private(set) var isDeleting = false
    
    var alert: FormAlert?
    
    // MARK: - Init
    
    init(
        originalModel: ChoreModel,
        availableHouseUsers: [UserModel],
        carouselViewModel: CarouselViewModel,
        targetAssignments: [RecurrentAssignmentModel] = [],
        cloudKit: CloudKitManager = .shared,
        scoreManager: ScoreManager = .shared,
        now: @escaping () -> Date = { Date() }
    ) {
        self.originalModel = originalModel
        self.targetAssignments = targetAssignments
        self.carouselViewModel = carouselViewModel
        self.cloudKit = cloudKit
        self.scoreManager = scoreManager
        self.now = now
        self.mode = originalModel.recordID == nil ? .create : .edit
        self.availableHouseUsers = Self.uniqueByOwner(availableHouseUsers)
        self.draft = ChoreDTO(from: originalModel, users: [], checklist: [], room: nil)
        Self.replaceUndefinedTags(in: draft)
        fillFromMemory()
    }
    
    // MARK: - Derived state
    
    var showsDeleteButton: Bool {
        mode == .edit
    }
    
    var hasValidName: Bool {
        !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var hasRoom: Bool {
        draft.room != nil
    }
    
    var hasDate: Bool {
        mode == .edit || draft.frequency == .daily || selectedDate != nil
    }
    
    var canConfirm: Bool {
        isLoaded && hasValidName && hasRoom && hasDate && !isSaving && !isDeleting
    }
    
    var showsMissingRoomWarning: Bool {
        isLoaded && hasValidName && !hasRoom
    }
    
    var showsMissingDateWarning: Bool {
        isLoaded && hasValidName && hasRoom && !hasDate
    }
    
    var showsDateSection: Bool {
        draft.frequency != .daily
    }
    
    var earliestSelectableDay: Date {
        Calendar.current.startOfDay(for: now())
    }
    
    var visibilityDescription: String {
        draft.isPublic
        ? "Caso essa tarefa seja para a sua casa ela aparecerá publica para todos os moradores."
        : "Tarefa privada: só aparece para você e é atribuída somente a você."
    }
    
    var selectableResponsibleUsers: [UserModel] {
        guard !draft.isPublic else { return availableHouseUsers }
        return currentHouseUserInList.map { [$0] } ?? []
    }
    
    /// Days the calendar shows
    var dateWindow: Range<Date> {
        let calendar = Calendar.current
        
        if draft.frequency == .weekly {
            if let anchor = targetAssignments.first?.day {
                return Self.weekRange(containing: anchor, calendar: calendar)
            }
            if mode == .create {
                return Self.weekRange(containing: now(), calendar: calendar)
            }
        }
        
        return carouselViewModel.cycleWindow ?? carouselViewModel.pickerWindow
    }
    
    /// How busy `day` is, used to shade the calendar.
    func loadOpacity(on day: Date) -> Double {
        carouselViewModel.loadOpacity(on: day, in: dateWindow)
    }
    
    private var currentHouseUserInList: UserModel? {
        guard let myID = currentHouseUser?.recordID else { return nil }
        return availableHouseUsers.first { $0.recordID == myID } ?? currentHouseUser
    }
    
    /// Who takes the occurrences generated for a new recurring chore.
    private var responsibleUsersForScheduling: [UserModel] {
        draft.isPublic ? draft.responsibleUsers : (currentHouseUserInList.map { [$0] } ?? [])
    }
    
    // MARK: - Loading
    
    /// Rebuilds the draft from what is persisted and loads everything the form needs.
    func load() async {
        isLoaded = false
        draft = ChoreDTO(from: originalModel, users: [], checklist: [], room: nil)
        Self.replaceUndefinedTags(in: draft)
        fillFromMemory()
        
        // CloudKit only for what the chores screen didn't have in memory.
        if availableRooms.isEmpty {
            availableRooms = await cloudKit.fetchAll(RoomModel.self)
                .filter { $0.name != "Casa" }
        }
        if currentHouseUser == nil {
            currentHouseUser = await cloudKit.currentHouseUser()
            applyResponsibleUsers()
        }
        if draft.room == nil, originalModel.roomReference != nil {
            draft.room = await originalModel.room
        }
        
        let checklistModels = await originalModel.checkList
        draft.checklist = checklistModels.map(CheckItemDTO.init(from:))
        draft.hasChecklist = !draft.checklist.isEmpty
        
        isLoaded = true
    }
    
    /// Fills the room, the rooms list, the current resident, the responsible users and the date
    /// from what ``CarouselViewModel`` already holds, so they show up together with the rest of
    /// the form instead of after a round of CloudKit requests.
    private func fillFromMemory() {
        availableRooms = carouselViewModel.roomModels.filter { $0.name != "Casa" }
        currentHouseUser = carouselViewModel.dashboardUser
        draft.room = carouselViewModel.getRoom(for: originalModel)
        selectedDate = targetAssignments.first?.day ?? originalModel.dueDate
        applyResponsibleUsers()
    }
    
    /// The persisted responsible users, or only the current resident for a private chore.
    private func applyResponsibleUsers() {
        draft.responsibleUsers = draft.isPublic
        ? persistedResponsibleUsers()
        : (currentHouseUserInList.map { [$0] } ?? [])
    }
    
    /// The responsible users stored on the occurrence(s) being edited, or on the chore.
    private func persistedResponsibleUsers() -> [UserModel] {
        let userIDs: Set<CKRecord.ID>
        
        if !targetAssignments.isEmpty {
            userIDs = Set(targetAssignments.compactMap { $0.userReference?.recordID })
        } else if let refs = originalModel.allResponsibleUsersReference {
            userIDs = Set(refs.map(\.recordID))
        } else {
            return []
        }
        
        return availableHouseUsers.filter { user in
            guard let id = user.recordID else { return false }
            return userIDs.contains(id)
        }
    }
    
    // MARK: - Form events
    
    /// The calendar window changes with the frequency; reset selection rule per target frequency.
    func frequencyDidChange() {
        if draft.frequency == .daily {
            // Changing to .daily always starts from today
            selectedDate = Calendar.current.startOfDay(for: now())
        } else if let date = selectedDate {
            let day = Calendar.current.startOfDay(for: date)
            if !dateWindow.contains(day) || day < earliestSelectableDay {
                selectedDate = nil
            }
        }
    }
    
    /// Turning a chore private hands it to the current resident alone.
    func visibilityDidChange(isPublic: Bool) {
        guard isLoaded, !isPublic else { return }
        draft.responsibleUsers = currentHouseUserInList.map { [$0] } ?? []
    }
    
    /// Turning the checklist on starts it with one empty row to type into.
    func checklistToggleDidChange(isOn: Bool) {
        if isOn && draft.checklist.isEmpty {
            draft.checklist.append(CheckItemDTO(name: "", isDone: false))
        }
    }
    
    // MARK: - Confirm
    
    /// Saves the draft and runs everything a save implies.
    ///
    /// - Returns: `true` when the chore was saved and the screen can close. On failure the
    ///   chore is left untouched, ``alert`` explains why and the draft stays on screen.
    func confirm() async -> Bool {
        guard canConfirm else { return false }
        isSaving = true
        defer { isSaving = false }
        
        let isNewChore = mode == .create
        let cycleEnd = carouselViewModel.currentCycleEnd
        let previousFrequency = originalModel.frequency
        let frequencyChanged = !isNewChore && previousFrequency != draft.frequency
        
        // When frequency changes, targetAssignments are outdated/deleted, so pass empty targetAssignments
        let assignmentsToUpdate = frequencyChanged ? [] : targetAssignments
        
        do {
            try await originalModel.save(
                from: draft,
                pickedDate: selectedDate,
                targetAssignments: assignmentsToUpdate
            )
        } catch {
            alert = FormAlert(kind: .saveFailed, message: error.localizedDescription)
            return false
        }
        
        // MARK: - Schedule Generation & Frequency Handling
        if isNewChore {
            await scheduleNewRecurringChore(
                originalModel,
                responsibleUsers: responsibleUsersForScheduling,
                cycleEnd: cycleEnd,
                pickedDate: selectedDate
            )
            await awardCreationScore()
        } else if frequencyChanged {
            // Purge old occurrences and generate new series based on new frequency
            await carouselViewModel.handleFrequencyChange(
                for: originalModel,
                from: previousFrequency,
                responsibleUsers: responsibleUsersForScheduling,
                pickedDate: selectedDate
            )
        } else {
            await applyPickedDateToOccurrence(isNewChore: isNewChore)
        }
        
        // MARK: - Local & Remote Sync
        let newOccurrenceIDs: Set<CKRecord.ID> = (isNewChore || frequencyChanged)
        ? Set((originalModel.dailyAssignmentsReference ?? []).map(\.recordID))
        : []
        
        await carouselViewModel.refreshAfterChoreUpdate()
        await syncCalendar(newOccurrenceIDs: newOccurrenceIDs, frequencyChanged: frequencyChanged)
        carouselViewModel.refreshVisible()
        
        return true
    }
    
    private func awardCreationScore() async {
        let score = draft.hasFullDetails
        ? ScoreValues.choreAdded.points + ScoreValues.choreCreatedWithFullDetails.points
        : ScoreValues.choreAdded.points
        _ = await scoreManager.assignScoreForMyUser(score: score)
    }
    
    private func applyPickedDateToOccurrence(isNewChore: Bool) async {
        switch draft.frequency {
        case .weekly, .fortnightly, .monthly: break
        default: return
        }
        
        guard let selectedDate else { return }
        let calendar = Calendar.current
        let picked = calendar.startOfDay(for: selectedDate)
        
        if let target = targetAssignments.first {
            guard !calendar.isDate(target.day, inSameDayAs: picked) else { return }
            
            target.day = picked
            await cloudKit.update(target)
            
        } else if isNewChore {
            let created = await originalModel.dailyAssignments
            
            guard let closest = created.min(by: {
                abs($0.day.timeIntervalSince(picked)) < abs($1.day.timeIntervalSince(picked))
            }) else { return }
            
            closest.day = picked
            await cloudKit.update(closest)
        }
    }
    
    /// Mirrors the saved chore (or the occurrences it touched) into the user's calendar.
    private func syncCalendar(newOccurrenceIDs: Set<CKRecord.ID>, frequencyChanged: Bool) async {
        let chore = originalModel
        
        guard chore.frequency != .none else {
            await carouselViewModel.syncSingleChoreToCalendar(chore)
            return
        }
        
        let freshAssignments = await cloudKit.fetchAll(RecurrentAssignmentModel.self)
        carouselViewModel.dailyAssignments = freshAssignments
        
        // When frequency changed, targetAssignments were wiped — use newOccurrenceIDs instead
        let targetIDs = frequencyChanged
        ? newOccurrenceIDs
        : Set(targetAssignments.compactMap(\.recordID)).union(newOccurrenceIDs)
        
        let updatedTargets = freshAssignments.filter { assignment in
            guard let id = assignment.recordID else { return false }
            return targetIDs.contains(id)
        }
        
        for assignment in updatedTargets {
            await carouselViewModel.syncSingleAssignmentToCalendar(for: assignment, chore: chore)
        }
    }
    
    // MARK: - Delete
    
    /// Deletes the chore — or, when it's recurring, just the occurrence(s) this screen was
    /// opened for.
    ///
    /// - Returns: `true` when the screen can close. On failure ``alert`` explains why.
    func delete() async -> Bool {
        guard mode == .edit, !isSaving, !isDeleting else { return false }
        isDeleting = true
        defer { isDeleting = false }
        
        let success = await carouselViewModel.delete(chore: originalModel, targetOccurrences: targetAssignments)
        
        if !success {
            alert = FormAlert(
                kind: .deleteFailed,
                message: carouselViewModel.errorMessage ?? "Não foi possível excluir a tarefa."
            )
            carouselViewModel.errorMessage = nil
        }
        
        return success
    }
    
    // MARK: - Helpers
    
    /// `undefined` is never shown: tags not chosen yet start at the first option of each picker.
    static func replaceUndefinedTags(in draft: ChoreDTO) {
        if draft.priorityTag == .undefined {
            draft.priorityTag = PriorityTag.allCases.first { $0 != .undefined } ?? .low
        }
        if draft.frequency == .undefined {
            draft.frequency = Recurrence.allCases.first { $0 != .undefined } ?? Recurrence.none
        }
        if draft.duration <= 0 {
            draft.duration = ChoreDurationTier.quick.minutes
        }
    }
    
    /// Keeps one `UserModel` per person.
    ///
    /// Onboarding can leave two records for the same owner (the profile created before a house
    /// existed, plus its in-house copy); the in-house one wins.
    static func uniqueByOwner(_ users: [UserModel]) -> [UserModel] {
        var bestByOwner: [String: UserModel] = [:]
        var order: [String] = []
        
        for user in users {
            let key = user.ownerRecordName
            if let existing = bestByOwner[key] {
                if existing.houseReference == nil && user.houseReference != nil {
                    bestByOwner[key] = user
                }
            } else {
                bestByOwner[key] = user
                order.append(key)
            }
        }
        
        // Keeps the incoming order, so avatars don't shuffle between openings.
        return order.compactMap { bestByOwner[$0] }
    }
    
    /// The calendar week (per `calendar`'s first weekday) that contains `date`.
    static func weekRange(containing date: Date, calendar: Calendar) -> Range<Date> {
        let startOfWeek = calendar.date(
            from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        ) ?? calendar.startOfDay(for: date)
        let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfWeek) ?? startOfWeek
        return startOfWeek..<endOfWeek
    }
}
