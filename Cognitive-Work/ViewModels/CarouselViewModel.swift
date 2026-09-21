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
    
    // MARK: - Derived State
    
    /// Today's statistics for ``dashboardUser``, recomputed only when the data changes.
    private(set) var dashboard: DashboardModel?
    
    /// The in-house profile the dashboard is computed for.
    private(set) var dashboardUser: UserModel?
    
    /// Chores and occurrences nobody is responsible for, recomputed only when the data changes.
    private(set) var unassignedItems: [UnassignedItem] = []
    
    /// Bumped on every rebuild, so views can react to "the data changed" with a single
    /// `.task(id:)`
    private(set) var dataVersion: Int = 0
    
    // MARK: - Lookup Indexes
    
    /// Assignments keyed by their own record ID.
    @ObservationIgnored
    private var assignmentsByID: [CKRecord.ID: RecurrentAssignmentModel] = [:]
    
    /// Future assignments per chore, sorted by day, precomputed once per rebuild.
    @ObservationIgnored
    private var futureAssignmentsByChore: [CKRecord.ID: [RecurrentAssignmentModel]] = [:]
    
    /// Next scheduled date per chore, precomputed once per rebuild.
    @ObservationIgnored
    private var nextDateByChore: [CKRecord.ID: Date] = [:]
    
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
        rebuildDerivedState()
    }
    
    /// Rebuilds every index and every derived collection, in dependency order.
    private func rebuildDerivedState() {
        rebuildIndexes()
        rebuildVisibleChores()
        rebuildUnassignedItems()
        rebuildDashboard()
        dataVersion &+= 1
    }
    
    /// Rebuilds ``assignmentsByID``, ``futureAssignmentsByChore`` and ``nextDateByChore``.
    private func rebuildIndexes() {
        assignmentsByID = Dictionary(
            dailyAssignments.compactMap { assignment in
                assignment.recordID.map { ($0, assignment) }
            },
            uniquingKeysWith: { _, latest in latest }
        )
        
        let today = Calendar.current.startOfDay(for: Date())
        
        futureAssignmentsByChore.removeAll(keepingCapacity: true)
        nextDateByChore.removeAll(keepingCapacity: true)
        
        for chore in cardModels {
            guard let choreID = chore.recordID else { continue }
            
            let future = (chore.dailyAssignmentsReference ?? [])
                .compactMap { assignmentsByID[$0.recordID] }
                .filter { $0.day >= today }
                .sorted { $0.day < $1.day }
            
            futureAssignmentsByChore[choreID] = future
            
            if let next = future.first?.day ?? chore.dueDate {
                nextDateByChore[choreID] = next
            }
        }
    }
    
    /// Recomputes ``dashboard`` from the chores and assignments already in memory.
    private func rebuildDashboard() {
        guard let dashboardUser else {
            dashboard = nil
            return
        }
        
        let model = dashboard ?? DashboardModel(user: dashboardUser)
        model.user = dashboardUser
        model.setup(chores: cardModels, assignments: dailyAssignments)
        dashboard = model
    }
    
    /// Rebuilds and caches the list of visible chores based on active filters and sorting rules.
    ///
    /// This method filters `cardModels` (either applying custom `ChoreFilters` or filtering out completed chores)
    /// and sorts the resulting array by their next scheduled date and priority tag. The outcome is stored in `visibleChores`
    /// to prevent expensive O(n log n) computations during high-frequency animations or gesture frames.
    private func rebuildVisibleChores() {
        
        let base = layoutMode == .grid ? cardModels.filter { chore in
            guard !chore.isDone, let date = nextDate(for: chore) else {return false}
            #if DEBUG
            return Calendar.current.isDateInTomorrow(date)
            #endif
            return Calendar.current.isDateInToday(date)
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
    
    /// The refresh currently in flight, if any. See ``requestRefresh(debounce:)``.
    @ObservationIgnored
    private var refreshTask: Task<Void, Never>?
    
    /// Coalesces refresh requests and cancels the previous one.
    /// - Parameter debounce: How long to wait for further requests before fetching.
    func requestRefresh(debounce: Duration = .milliseconds(250)) {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            try? await Task.sleep(for: debounce)
            guard !Task.isCancelled, let self else { return }
            await self.fetchAllData()
        }
    }
    
    /// Fetches all chores, users, rooms and assignments in parallel.
    func fetchAllData() async {
        if !hasFetchedInitially {
            await MainActor.run { isLoading = true }
        }
        
        async let fetchChores = CloudKitManager.shared.fetchAll(ChoreModel.self)
        async let fetchUsers = CloudKitManager.shared.fetchHouseUsers()
        async let fetchRooms = CloudKitManager.shared.fetchAll(RoomModel.self)
        async let fetchAssignments = CloudKitManager.shared.fetchAll(RecurrentAssignmentModel.self)
        async let fetchCurrentHouseUser = CloudKitManager.shared.currentHouseUser()
        
        let (chores, users, rooms, assignments, currentHouseUser) = await (fetchChores, fetchUsers, fetchRooms, fetchAssignments, fetchCurrentHouseUser)
        
        guard !Task.isCancelled else { return }
        
        await MainActor.run {
            self.cardModels = chores
            self.userModels = users
            self.roomModels = rooms
            self.dailyAssignments = assignments
            self.dashboardUser = currentHouseUser
            
            self.rebuildDerivedState()
            
            self.hasFetchedInitially = true
            self.isLoading = false
        }
    }
    
    /// Refreshes the chores and recurrent assignments after a chore or its responsible user has been modified.
    func refreshAfterChoreUpdate() async {
        async let fetchC = CloudKitManager.shared.fetchAll(ChoreModel.self)
        async let fetchA = CloudKitManager.shared.fetchAll(RecurrentAssignmentModel.self)
        
        let (chores, assignments) = await (fetchC, fetchA)
        
        guard !Task.isCancelled else { return }
        
        await MainActor.run {
            self.cardModels = chores
            self.dailyAssignments = assignments
            self.rebuildDerivedState()
        }
    }
    
    /// Retrieves all assignment records corresponding to a specific chore on a given date.
    func getAssignments(for chore: ChoreModel, on date: Date?) -> [RecurrentAssignmentModel] {
        guard let date,
              let refs = chore.dailyAssignmentsReference,
              !refs.isEmpty
        else { return [] }
        
        let calendar = Calendar.current
        let target = calendar.startOfDay(for: date)
        
        return refs
            .compactMap { assignmentsByID[$0.recordID] }
            .filter { calendar.isDate($0.day, inSameDayAs: target) }
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
            let userIDs = Set(refs.compactMap { assignmentsByID[$0.recordID]?.userReference?.recordID })
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
        rebuildDerivedState()
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
        rebuildDerivedState()
    }
    
    func resetFilter() {
        isFilterOn = false
        isSelectingFilter = false
        filterChoices = ChoreFilters()
        
        //Rebuild visible chores after resetting filters.
        rebuildDerivedState()
    }
    
    /// Every future assignment of a chore, sorted by day.
    /// Returns an empty array for one-off chores, which have no assignments.
    func futureAssignments(for chore: ChoreModel) -> [RecurrentAssignmentModel] {
        guard let choreID = chore.recordID else { return [] }
        return futureAssignmentsByChore[choreID] ?? []
    }
    
    /// The next scheduled date for a chore, whether it comes from a daily
    /// assignment (recurring) or from its own due date (one-off).
    func nextDate(for chore: ChoreModel) -> Date? {
        guard let choreID = chore.recordID else { return chore.dueDate }
        return nextDateByChore[choreID] ?? chore.dueDate
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
    
    /// Recomputes ``unassignedItems``.
    private func rebuildUnassignedItems() {
        let today = Calendar.current.startOfDay(for: Date())
        var items: [UnassignedItem] = []
        
        for chore in cardModels where !chore.isDone {
            if let refs = chore.dailyAssignmentsReference, !refs.isEmpty {
                // Recurring chore: look for occurrences that are today or in the future
                // and still have no one assigned.
                let openSlots = refs.compactMap { assignmentsByID[$0.recordID] }.filter { assignment in
                    assignment.userReference == nil && assignment.day >= today
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
        unassignedItems = items.sorted {
            ($0.displayDate ?? .distantFuture) < ($1.displayDate ?? .distantFuture)
        }
    }
    
    /// Assigns the current user to an unassigned chore or occurrence, then refreshes local caches.
    @MainActor
    func pickForMyself(_ item: UnassignedItem) async {
        var myUser = dashboardUser
        if myUser == nil {
            myUser = await CloudKitManager.shared.currentHouseUser()
            dashboardUser = myUser
        }
        
        guard let myUserID = myUser?.recordID else { return }
        
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
