//
//  CarouselViewModel.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 18/08/26.
//

import SwiftUI
import CloudKit

struct ChoreFilters {
    var users: [UserModel] = []
    var tags: [PriorityTag] = []
    var frequencies: [Recurrence] = []
    var state: Bool? = nil
}

/// Controls the state, data fetching, filtering, and mathematical rendering of the carousel.
@Observable
class CarouselViewModel {
    
    // MARK: - Core Data Models
    
    var cardModels: [ChoreModel] = []
    var roomModels: [RoomModel] = []
    var userModels: [UserModel] = []
    var dailyAssignments: [RecurrentAssignmentModel] = []
    private var assignmentsByChore: [CKRecord.ID: [RecurrentAssignmentModel]] = [:]
    
    // MARK: - UI & Layout State
    
    var layoutMode: CardLayoutMode = .grid
    var isLoading: Bool = false
    private var hasFetchedInitially = false
    
    // MARK: - Carousel Geometry State
    
    /// The exact index where the carousel is currently resting.
    var snappedItem: Double = 0
    /// The continuous floating point index used during active swipe gestures.
    var draggingItem: Double = 0
    /// The integer index of the most prominent, centered card.
    var activeIndex: Int = 0
    
    // MARK: - Focus & Flip State
    private var focusedIndex: Int? = nil
    /// Tracks which cards are currently in the flipped state (180 degrees).
    private var flippedIndices: Set<Int> = []
    /// Tracks which cards should render their back face based on animation timing.
    private var backVisibleIndices: Set<Int> = []
    /// The occurrence backing the details card in the list layout.
    var focusedOccurrence: ChoreOccurrence? {
        guard let focusedIndex, visibleOccurrences.indices.contains(focusedIndex) else { return nil }
        return visibleOccurrences[focusedIndex]
    }
    
    // Constants for animation tuning
    private let flipDuration: Double = 0.6
    private let focusSpringResponse: Double = 0.4
    private let focusSpringDamping: Double = 0.75
    
    // MARK: - Filtering State
    
    var isFilterOn: Bool = false
    var isSelectingFilter = false
    var filterChoices = ChoreFilters()
    
    /// The list of chores rendered by the UI, respecting active filters.
    private(set) var visibleChores: [ChoreModel] = []
    
    /// Occurrences rendered by the list layout — one row per scheduled day.
    private(set) var visibleOccurrences: [ChoreOccurrence] = []
    
    /// How many future occurrences of the same chore the list shows.
    private let occurrencesPerChore = 3
    
    /// Rebuilds the flattened list of occurrences from the currently visible chores.
    ///
    /// Recurring chores contribute one row per future assignment (capped by
    /// `occurrencesPerChore`); one-off chores contribute a single row.
    private func rebuildVisibleOccurrences() {
        let selectedUserIDs = Set(filterChoices.users.compactMap { $0.recordID })
        var occurrences: [ChoreOccurrence] = []
        
        for chore in visibleChores {
            let assignments = futureAssignments(for: chore)
            
            if assignments.isEmpty {
                // One-off chore: filtered by its own responsible and done state
                if isFilterOn {
                    if !selectedUserIDs.isEmpty,
                       let responsibleID = chore.currentResponsibleReference?.recordID,
                       !selectedUserIDs.contains(responsibleID) { continue }
                    
                    if let state = filterChoices.state, chore.isDone != state { continue }
                }
                occurrences.append(ChoreOccurrence(chore: chore, assignment: nil))
            } else {
                let matching = assignments.filter { assignment in
                    guard isFilterOn else { return true }
                    
                    if !selectedUserIDs.isEmpty {
                        guard let userID = assignment.userReference?.recordID,
                              selectedUserIDs.contains(userID) else { return false }
                    }
                    
                    if let state = filterChoices.state, assignment.isCompleted != state {
                        return false
                    }
                    
                    return true
                }
                
                for assignment in matching.prefix(occurrencesPerChore) {
                    occurrences.append(ChoreOccurrence(chore: chore, assignment: assignment))
                }
            }
        }
        
        // Chronological across all chores, so the user reads the list as a schedule
        visibleOccurrences = occurrences.sorted { a, b in
            // Completed occurrences sink to the bottom, whatever their date
            let doneA = a.assignment?.isCompleted ?? a.chore.isDone
            let doneB = b.assignment?.isCompleted ?? b.chore.isDone
            if doneA != doneB { return !doneA }
            
            switch (a.day, b.day) {
            case let (dA?, dB?) where dA != dB: return dA < dB
            case (nil, _?): return false
            case (_?, nil): return true
            default: break
            }
            
            return a.chore.priorityTag.intValue > b.chore.priorityTag.intValue
        }
    }
    
    /// Recomputes the visible lists after a local change, without hitting CloudKit.
    @MainActor
    func refreshVisible() {
        rebuildVisibleChores()
    }
    
    /// Rebuilds and caches the list of visible chores based on active filters and sorting rules.
    ///
    /// This method filters `cardModels` (either applying custom `ChoreFilters` or filtering out completed chores)
    /// and sorts the resulting array by their next scheduled date and priority tag. The outcome is stored in `visibleChores`
    /// to prevent expensive O(n log n) computations during high-frequency animations or gesture frames.
    private func rebuildVisibleChores() {
        
        let base = layoutMode == .grid ? cardModels.filter { chore in
            guard !chore.isDone, let date = nextDate(for: chore) else {return false}
            return Calendar.current.isDateInTomorrow(date)
        } : (isFilterOn ? applyFilters(to: cardModels) : cardModels.filter { !$0.isDone })
        
        visibleChores = base.sorted { a, b in
            let dateA = nextDate(for: a)
            let dateB = nextDate(for: b)
            
            switch (dateA, dateB) {
            case let (dA?, dB?) where dA != dB: return dA < dB
            case (nil, _?): return false
            case (_?, nil): return true
            default: break
            }
            
            return a.priorityTag.intValue > b.priorityTag.intValue
        }
        
        rebuildVisibleOccurrences()
    }
    
    var hasFocusedCard: Bool {
        focusedIndex != nil
    }
    
    var focusedChoreForDetails: ChoreModel? {
        guard let focusedIndex, visibleChores.indices.contains(focusedIndex) else { return nil }
        return visibleChores[focusedIndex]
    }
    
    // MARK: - Initialization & Data Fetching
    
    /// Fetches all chores, users, and rooms in parallel.
    func fetchAllData() async {
        if !hasFetchedInitially {
            await MainActor.run { isLoading = true }
        }
        
        async let fetchC = CloudKitManager.shared.fetchAll(ChoreModel.self)
        async let fetchU = CloudKitManager.shared.fetchHouseUsers()
        async let fetchR = CloudKitManager.shared.fetchAll(RoomModel.self)
        async let fetchA = CloudKitManager.shared.fetchAll(RecurrentAssignmentModel.self)
        
        let (chores, users, rooms, assignments) = await (fetchC, fetchU, fetchR, fetchA)
        
        await MainActor.run {
            self.cardModels = chores
            self.userModels = users
            self.roomModels = rooms
            self.dailyAssignments = assignments
            
            // Rebuild visible chores after fetching initial data.
            self.rebuildVisibleChores()
            
            self.hasFetchedInitially = true
            self.isLoading = false
        }
    }
    
    /// Refreshes the chores and recurrent assignments after a chore or its responsible user has been modified.
    func refreshAfterChoreUpdate() async {
        async let fetchC = CloudKitManager.shared.fetchAll(ChoreModel.self)
        async let fetchA = CloudKitManager.shared.fetchAll(RecurrentAssignmentModel.self)
        
        let (chores, assignments) = await (fetchC, fetchA)
        
        await MainActor.run {
            self.cardModels = chores
            self.dailyAssignments = assignments
            self.rebuildVisibleChores()
        }
    }
    
    /// Retrieves all assignment records corresponding to a specific chore on a given date.
    func getAssignments(for chore: ChoreModel, on date: Date?) -> [RecurrentAssignmentModel] {
        guard let date,
              let refs = chore.dailyAssignmentsReference,
              !refs.isEmpty
        else { return [] }
        
        let ids = Set(refs.map { $0.recordID })
        let target = Calendar.current.startOfDay(for: date)
        
        return dailyAssignments.filter { assignment in
            guard let id = assignment.recordID, ids.contains(id) else { return false }
            return Calendar.current.isDate(assignment.day, inSameDayAs: target)
        }
    }
    
    /// Retrieves all assignment records for a visible chore on its next scheduled date.
    func getAssignmentsForActiveContext(for chore: ChoreModel) -> [RecurrentAssignmentModel] {
        guard let targetDate = nextDate(for: chore) else { return [] }
        return getAssignments(for: chore, on: targetDate)
    }
    
    // MARK: - Synchronous Data Helpers
    
    func getRoom(for chore: ChoreModel) -> RoomModel? {
        guard let refID = chore.roomReference?.recordID else { return nil }
        return roomModels.first { $0.recordID == refID }
    }
    
    func getUsers(for chore: ChoreModel) -> [UserModel] {
        // Recurring: users come from the daily assignments
        if let refs = chore.dailyAssignmentsReference, !refs.isEmpty {
            let ids = Set(refs.map { $0.recordID })
            let userIDs = Set(dailyAssignments.compactMap { assignment -> CKRecord.ID? in
                guard let id = assignment.recordID, ids.contains(id) else { return nil }
                return assignment.userReference?.recordID
            })
            return userModels.filter { $0.recordID.map { userIDs.contains($0) } ?? false }
        }
        
        // One-off: explicit rotation list
        guard let refs = chore.allResponsibleUsersReference else { return [] }
        let ids = Set(refs.compactMap { $0.recordID })
        return userModels.filter { $0.recordID.map { ids.contains($0) } ?? false }
    }
    
    // MARK: - Layout Control
    
    func toggleLayout() {
        layoutMode = layoutMode == .grid ? .list : .grid
        rebuildVisibleChores()
    }
    
    // MARK: - Filtering Logic
    
    /// Applies the active filters to a list of chores.
    private func applyFilters(to chores: [ChoreModel]) -> [ChoreModel] {
        var result = chores
        
        if !filterChoices.tags.isEmpty {
            result = result.filter { filterChoices.tags.contains($0.priorityTag) }
        }
        
        if !filterChoices.frequencies.isEmpty {
            result = result.filter { filterChoices.frequencies.contains($0.frequency) }
        }
        
        return result
    }
    
    /// Changes the filter option
    func addOrRemoveFilter(user: UserModel? = nil, tag: PriorityTag? = nil, frequency: Recurrence? = nil, state: Bool? = nil) {
        if let user {
            if filterChoices.users.contains(user) {
                filterChoices.users.removeAll { $0 == user }
            } else {
                filterChoices.users.append(user)
            }
        }
        
        if let tag = tag {
            if !filterChoices.tags.contains(tag) {
                filterChoices.tags.append(tag)
            } else {
                filterChoices.tags.removeAll { $0 == tag }
            }
        }
        
        if let frequency = frequency {
            if !filterChoices.frequencies.contains(frequency) {
                filterChoices.frequencies.append(frequency)
            } else {
                filterChoices.frequencies.removeAll { $0 == frequency }
            }
        }
        
        if let state = state {
            if filterChoices.state != state {
                filterChoices.state = state
            } else {
                filterChoices.state = nil
            }
        }
        
        isFilterOn = true
        
        // Rebuild visible chores after changing filters.
        rebuildVisibleChores()
    }
    
    func resetFilter() {
        isFilterOn = false
        isSelectingFilter = false
        filterChoices = ChoreFilters()
        
        //Rebuild visible chores after resetting filters.
        rebuildVisibleChores()
    }
    
    /// Every future assignment of a chore, sorted by day.
    /// Returns an empty array for one-off chores, which have no assignments.
    func futureAssignments(for chore: ChoreModel) -> [RecurrentAssignmentModel] {
        guard let refs = chore.dailyAssignmentsReference, !refs.isEmpty else { return [] }
        
        let ids = Set(refs.map { $0.recordID })
        let hoje = Calendar.current.startOfDay(for: Date())
        
        return dailyAssignments
            .filter { assignment in
                guard let id = assignment.recordID, ids.contains(id) else { return false }
                return assignment.day >= hoje
            }
            .sorted { $0.day < $1.day }
    }
    
    /// The next scheduled date for a chore, whether it comes from a daily
    /// assignment (recurring) or from its own due date (one-off).
    func nextDate(for chore: ChoreModel) -> Date? {
        futureAssignments(for: chore).first?.day ?? chore.dueDate
    }
    
    // MARK: - Focus & Flip Interactions
    
    func isFocused(_ index: Int) -> Bool {
        focusedIndex == index
    }
    
    func focusImmediately(_ index: Int) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            focusedIndex = index
        }
    }
    
    func focus(_ index: Int) {
        guard focusedIndex != index else { return }
        
        if focusedIndex != nil {
            withAnimation(.easeOut(duration: 0.15)) {
                focusedIndex = nil
            }
        }
        
        withAnimation(.spring(response: focusSpringResponse, dampingFraction: focusSpringDamping)) {
            snappedItem = Double(index)
            draggingItem = Double(index)
            activeIndex = index
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + focusSpringResponse) { [weak self] in
            guard let self, self.activeIndex == index else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                self.focusedIndex = index
            }
        }
    }
    
    func focusAndFlip(_ index: Int) {
        if let old = focusedIndex, old != index {
            if flippedIndices.contains(old) {
                flip(old)
            }
        }
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            snappedItem = Double(index)
            draggingItem = Double(index)
            activeIndex = index
            focusedIndex = index
        }
        
        flip(index)
    }
    
    func clearFocus() {
        if let old = focusedIndex {
            if flippedIndices.contains(old) {
                flip(old)
            }
            withAnimation(.easeOut(duration: 0.2)) {
                focusedIndex = nil
            }
        }
    }
    
    func focusDetailsImmediately(_ index: Int) {
        flippedIndices.insert(index)
        backVisibleIndices.insert(index)
        
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            focusedIndex = index
        }
    }
    
    func clearFocusedDetails() {
        if let index = focusedIndex {
            flippedIndices.remove(index)
            backVisibleIndices.remove(index)
        }
        
        withAnimation(.easeOut(duration: 0.2)) {
            focusedIndex = nil
        }
    }
    
    func flipRotation(_ index: Int) -> Double {
        flippedIndices.contains(index) ? 180 : 0
    }
    
    func isShowingBack(_ index: Int) -> Bool {
        backVisibleIndices.contains(index)
    }
    
    func flip(_ index: Int) {
        let isFlipping = !flippedIndices.contains(index)
        
        withAnimation(.easeInOut(duration: flipDuration)) {
            if isFlipping {
                flippedIndices.insert(index)
            } else {
                flippedIndices.remove(index)
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + flipDuration / 2) { [weak self] in
            guard let self else { return }
            if isFlipping {
                self.backVisibleIndices.insert(index)
            } else {
                self.backVisibleIndices.remove(index)
            }
        }
    }
    
    // MARK: - Carousel Geometry Math
    
    func isCentered(_ index: Int) -> Bool {
        abs(distance(index)) < 0.5
    }
    
    func distance(_ index: Int) -> Double {
        guard !visibleChores.isEmpty else { return 0 }
        return (draggingItem - Double(index)).remainder(dividingBy: Double(visibleChores.count))
    }
    
    func xOffset(_ index: Int) -> Double {
        let fixedVisualCount: Double = 5.0
        let angle = (Double.pi * 2 / fixedVisualCount) * distance(index)
        let fixedRadius: Double = 130.0
        return sin(angle) * fixedRadius
    }
    
    func yOffset(_ index: Int) -> Double {
        let dist = abs(distance(index))
        let hideThreshold = hideThreshold()
        if dist > hideThreshold { return 1000 }
        return pow(dist * 17, 2) / 10
    }
    
    func scaleEffect(_ index: Int) -> Double {
        let dist = abs(distance(index))
        return max(1 - dist * 0.18, 0.7)
    }
    
    func rotationEffect(_ index: Int) -> Double {
        let dist = distance(index)
        return dist * 22
    }
    
    func zIndex(_ index: Int) -> Double {
        1.0 - abs(distance(index)) * 0.1
    }
    
    func opacity(_ index: Int) -> Double {
        let dist = abs(distance(index))
        return dist > hideThreshold() ? 0.0 : 1.0
    }
    
    private func hideThreshold() -> Double {
        return 1.5
    }
    
    // MARK: - Gesture Handling
    
    private static var dragPointsPerGroup: Double { UIScreen.main.bounds.width * 0.5 }
    
    func onDragChanged(value: DragGesture.Value) {
        clearFocus()
        draggingItem = snappedItem + value.translation.width / Self.dragPointsPerGroup
    }
    
    func onDragEnded(value: DragGesture.Value) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            guard !visibleChores.isEmpty else { return }
            
            let velocity = value.predictedEndTranslation.width - value.translation.width
            let nudge = min(max(velocity / 700, -1), 1)
            
            let count = visibleChores.count
            draggingItem = (draggingItem + nudge)
                .rounded()
                .remainder(dividingBy: Double(count))
            
            snappedItem = draggingItem
            
            let rounded = Int(draggingItem)
            activeIndex = rounded >= 0 ? rounded : count + rounded
        }
    }
    
    // MARK: - UnassignedItem
    
    /// A chore (or a single occurrence of a recurring chore) that currently has nobody responsible for it.
    struct UnassignedItem: Identifiable {
        enum ChoreType {
            /// A one-off chore with no responsible users at all.
            case oneOff
            /// One specific day of a recurring chore that has no user assigned yet.
            case recurring(assignment: RecurrentAssignmentModel)
        }
        
        let id: String
        let chore: ChoreModel
        let choreType: ChoreType
        /// The date to show next to the chore, when there is one.
        let displayDate: Date?
    }
    
    /// Every chore — or single occurrence of a recurring chore — that has nobody responsible for it yet.
    ///
    /// Computed purely from data already in memory (`cardModels`, `dailyAssignments`), so this is safe
    /// to read from the view every time it renders.
    var unassignedItems: [UnassignedItem] {
        let today = Calendar.current.startOfDay(for: Date())
        var items: [UnassignedItem] = []
        
        for chore in cardModels where !chore.isDone {
            if let refs = chore.dailyAssignmentsReference, !refs.isEmpty {
                // Recurring chore: look for occurrences that are today or in the future
                // and still have no one assigned.
                let ids = Set(refs.map { $0.recordID })
                let openSlots = dailyAssignments.filter { assignment in
                    guard let id = assignment.recordID, ids.contains(id) else { return false }
                    return assignment.userReference == nil && assignment.day >= today
                }
                
                for assignment in openSlots {
                    items.append(
                        UnassignedItem(
                            id: assignment.recordID?.recordName ?? UUID().uuidString,
                            chore: chore,
                            choreType: .recurring(assignment: assignment),
                            displayDate: assignment.day
                        )
                    )
                }
            } else {
                // One-off chore: unassigned when it has no one in its rotation.
                let hasResponsible = chore.currentResponsibleReference != nil
                || !(chore.allResponsibleUsersReference?.isEmpty ?? true)
                
                if !hasResponsible {
                    items.append(
                        UnassignedItem(
                            id: chore.recordID?.recordName ?? UUID().uuidString,
                            chore: chore,
                            choreType: .oneOff,
                            displayDate: chore.dueDate
                        )
                    )
                }
            }
        }
        
        // Sort items in ascending order by displayDate, placing items with nil dates at the end
        return items.sorted { ($0.displayDate ?? .distantFuture) < ($1.displayDate ?? .distantFuture) }
    }
    
    /// Assigns the current user to an unassigned chore or occurrence, then refreshes local caches.
    @MainActor
    func pickForMyself(_ item: UnassignedItem) async {
        guard let myUser = await CloudKitManager.shared.fetchMyHouseUser(),
              let myUserID = myUser.recordID
        else { return }
        
        let userRef = CKRecord.Reference(recordID: myUserID, action: .none)
        
        switch item.choreType {
        case .oneOff:
            item.chore.currentResponsibleReference = userRef
            var refs = item.chore.allResponsibleUsersReference ?? []
            if !refs.contains(where: { $0.recordID == myUserID }) {
                refs.append(userRef)
            }
            item.chore.allResponsibleUsersReference = refs
            await CloudKitManager.shared.update(item.chore)
            
        case .recurring(let assignment):
            assignment.userReference = userRef
            await CloudKitManager.shared.update(assignment)
        }
        
        await refreshAfterChoreUpdate()
    }
    
    /// Whether the "unassigned chores" popup is currently visible.
    var isShowingUnassignedList: Bool = false
    
    func toggleUnassignedList() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            isShowingUnassignedList.toggle()
        }
    }
    
    func dismissUnassignedList() {
        withAnimation(.easeOut(duration: 0.2)) {
            isShowingUnassignedList = false
        }
    }
    
}
