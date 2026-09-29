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
    var rooms: [RoomModel] = []
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
    
    /// Set when ``delete(chore:targetOccurrences:)`` fails, so a view can surface it in an
    /// alert. Left for the view to clear back to `nil` once shown.
    var errorMessage: String?
    
    /// The last day of the division cycle in progress.
    var currentCycleEnd: Date? {
        let today = Calendar.current.startOfDay(for: Date())
        return dailyAssignments.map(\.day).filter { $0 >= today }.max()
    }
    
    // MARK: - Carousel Geometry State
    
    /// The exact index where the carousel is currently resting.
    var snappedItem: Double = 0
    /// The continuous floating point index used during active swipe gestures.
    var draggingItem: Double = 0
    /// The integer index of the most prominent, centered card.
    var activeIndex: Int = 0
    
    // MARK: - Focus & Flip State
    
    private var focusedIndex: Int? = nil
    /// Stores the recordID of the focused card, to keep it visible regardless of filters
    private var focusedChoreRecordID: CKRecord.ID? = nil
    
    /// Stores a copy of the focused chore to keep it visible even if not present in cardModels due to filtering.
    private var focusedChoreModel: ChoreModel? = nil
    
    /// Stores the assignment of the focused occurrence so it remains visible
    /// even if it no longer matches the active user filter.
    private var focusedAssignmentRecordID: CKRecord.ID? = nil

    private var focusedAssignmentModel: RecurrentAssignmentModel? = nil
    
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
    var filterChoices = ChoreFilters()
    
    /// When `true`, occurrences on the same day are ordered most urgent first.
    ///
    /// The list is always ordered by day (nearest first) regardless — that part isn't a user
    /// choice, since the list layout groups occurrences under one header per day.
    var isSortedByUrgency: Bool = false {
        didSet {
            guard oldValue != isSortedByUrgency else { return }
            rebuildDerivedState()
        }
    }
    
    /// The list of chores rendered by the UI, respecting active filters.
    private(set) var visibleChores: [ChoreModel] = []
    
    /// Occurrences rendered by the list layout — one row per scheduled day.
    private(set) var visibleOccurrences: [ChoreOccurrence] = []
    
    /// How many future occurrences of the same chore the list shows.
    private let occurrencesPerChore = 20
    
    /// Rebuilds the flattened list of occurrences from the currently visible chores.
    ///
    /// Recurring chores contribute one row per future assignment (capped by
    /// `occurrencesPerChore`); one-off chores contribute a single row.
    ///
    /// - Note: This method has been reverted to not enforce forced occurrences from
    ///   focusedChoreAssignments, only from focusedChoreModel and focusedChoreRecordID.
    private func rebuildVisibleOccurrences() {
        let selectedUserIDs = Set(filterChoices.users.compactMap { $0.recordID })
        let today = Calendar.current.startOfDay(for: Date())
        var occurrences: [ChoreOccurrence] = []
        
        for chore in visibleChores {
            let assignments = futureAssignments(for: chore)
            
            if assignments.isEmpty {
                // The list never shows past days: a one-off chore due before today is left
                // out. (Recurring occurrences are already limited to today onward by
                // `futureAssignments(for:)`.)
                if let dueDate = chore.dueDate, dueDate < today { continue }
                
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
        
        // Revert forced showing of focused chore occurrences to previous behavior:
        // Keep focused chore occurrences visible even if filtered out by adding one occurrence
        // for the focused chore from focusedChoreModel (no assignments forced).
        if let focusedAssignment = focusedAssignmentModel,
           
            let focusedAssignmentID = focusedAssignmentRecordID,
            !occurrences.contains(where: {
                $0.assignment?.recordID == focusedAssignmentID
            }),
           
            let focusedChore = focusedChoreModel{
            occurrences.append(
                ChoreOccurrence(
                    chore: focusedChore,
                    assignment: focusedAssignment
                )
            )
        }
        
        visibleOccurrences = occurrences.sorted(by: self.areInIncreasingOrder)
        
        // Only the list layout indexes into `visibleOccurrences`. The grid focuses by index into
        // `visibleChores` (already restored by `rebuildVisibleChores()`), and a chore can have
        // up to `occurrencesPerChore` occurrences, so the two indexes differ: overwriting it here
        // moved the focus to the wrong card, or dropped it, on every refresh in the grid.
        guard layoutMode == .list else { return }

        if let focusedAssignmentID = focusedAssignmentRecordID,
            let index = visibleOccurrences.firstIndex(where: {
                $0.assignment?.recordID == focusedAssignmentID
            }) {
            focusedIndex = index
        }
        else if let focusedChoreID = focusedChoreRecordID,
            let index = visibleOccurrences.firstIndex(where: {
                $0.chore.recordID == focusedChoreID
            }) {
            focusedIndex = index
        }
        else {
            focusedIndex = nil
        }
    }
    
    // MARK: - Sorting
    
    /// Ordering for the list layout.
    ///
    /// Always by calendar day first — nearest first, undated last — since the list groups
    /// occurrences under one header per day.
    private func areInIncreasingOrder(_ a: ChoreOccurrence, _ b: ChoreOccurrence) -> Bool {
        let dayOrder = compareDay(a, b)
        if dayOrder != .orderedSame { return dayOrder == .orderedAscending }
        
        let doneA = a.assignment?.isCompleted ?? a.chore.isDone
        let doneB = b.assignment?.isCompleted ?? b.chore.isDone
        if doneA != doneB { return !doneA }
        
        if isSortedByUrgency {
            let urgencyOrder = compareUrgency(a, b)
            if urgencyOrder != .orderedSame { return urgencyOrder == .orderedAscending }
        }
        
        if let dateA = a.day, let dateB = b.day, dateA != dateB {
            return dateA < dateB
        }
        return a.chore.name.localizedCaseInsensitiveCompare(b.chore.name) == .orderedAscending
    }
    
    /// Nearest calendar day first (ignoring the time of day); undated occurrences go last.
    private func compareDay(_ a: ChoreOccurrence, _ b: ChoreOccurrence) -> ComparisonResult {
        let calendar = Calendar.current
        let dayA = a.day.map { calendar.startOfDay(for: $0) }
        let dayB = b.day.map { calendar.startOfDay(for: $0) }
        
        switch (dayA, dayB) {
        case let (dayA?, dayB?):
            if dayA == dayB { return .orderedSame }
            return dayA < dayB ? .orderedAscending : .orderedDescending
        case (nil, _?): return .orderedDescending
        case (_?, nil): return .orderedAscending
        case (nil, nil): return .orderedSame
        }
    }
    
    /// Most urgent first.
    private func compareUrgency(_ a: ChoreOccurrence, _ b: ChoreOccurrence) -> ComparisonResult {
        let priorityA = a.chore.priorityTag.intValue
        let priorityB = b.chore.priorityTag.intValue
        if priorityA == priorityB { return .orderedSame }
        return priorityA > priorityB ? .orderedAscending : .orderedDescending
    }
    
    /// Recomputes the visible lists after a local change, without hitting CloudKit.
    @MainActor
    func refreshVisible() {
        rebuildDerivedState()
    }
    
    /// Rebuilds every index and every derived collection, in dependency order.
    private func rebuildDerivedState() {
        rebuildIndexes()
        rebuildLoadByDay()
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
    
    // MARK: - Grid Visibility
    ///
    /// > Note: `1` (tomorrow) is intentional while the schedule is being tested, because
    /// > ``TaskSchedulerEngine/schedule(chores:users:)`` seeds its window starting *tomorrow*,
    /// > so "today" is empty right after a division is generated. Set this to `0` for
    /// > production — and flip ``HardwareDailyChoresViewModel/dayOffsetFromToday`` together with
    /// > it, since the e-paper dashboard has to show the same day the app does. The progress
    /// > cards (``DashboardModel``) read this too, so they follow automatically.
    static let gridDayOffsetFromToday = 1
    
    /// The single day the grid layout renders, normalised to the start of that day.
    /// - Parameter reference: The day to count from. Defaults to now; injectable for tests.
    static func gridTargetDay(from reference: Date = Date()) -> Date {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: reference)
        return calendar.date(byAdding: .day, value: gridDayOffsetFromToday, to: startOfToday)
        ?? startOfToday
    }
    
    /// Whether `chore` belongs in the grid layout, which shows exactly one day at a time.
    ///
    /// 1. *the grid shows a single day* — the original date check; and
    /// 2. *hide a chore once that day's occurrence is done* — added later as an early return:
    ///
    /// - Parameter chore: The chore to test.
    /// - Returns: `true` when the chore has open work on ``gridTargetDay(from:)``.
    private func isVisibleInGrid(_ chore: ChoreModel) -> Bool {
        guard !chore.isDone else { return false }
        
        let targetDay = Self.gridTargetDay()
        
        if let refs = chore.dailyAssignmentsReference, !refs.isEmpty {
            return getAssignments(for: chore, on: targetDay).contains { !$0.isCompleted }
        }
        
        guard let dueDate = chore.dueDate else { return false }
        return Calendar.current.isDate(dueDate, inSameDayAs: targetDay)
    }
    
    /// Rebuilds and caches the list of visible chores based on active filters and sorting rules.
    ///
    /// Force add focused card to visibleChores even if it does not match current filters, to keep details open until user closes.
    private func rebuildVisibleChores() {
        // Whether the focused card is showing its details, captured before the lists change
        // and the card possibly moves to another index. See `reconcileFlipState(...)`.
        let previousFocusedIndex = focusedIndex
        let wasFlipped = previousFocusedIndex.map { flippedIndices.contains($0) } ?? false
        let wasShowingBack = previousFocusedIndex.map { backVisibleIndices.contains($0) } ?? false
        
        // Use focusedChoreRecordID to ensure focused chore remains visible regardless of filters
        let base = layoutMode == .grid
        ? cardModels.filter { isVisibleInGrid($0) }
        : (isFilterOn ? applyFilters(to: cardModels) : cardModels)
        
        // If there is a focused chore recordID, ensure its card appears in the visibleChores,
        // even if not matching filters.
        var result = base
        if let recID = focusedChoreRecordID, !base.contains(where: { $0.recordID == recID }) {
            if let forcedChore = cardModels.first(where: { $0.recordID == recID }) {
                result.append(forcedChore)
            } else if let tempChore = focusedChoreModel, tempChore.recordID == recID {
                result.append(tempChore) // Use local copy if not found in cardModels
            }
        }
        
        visibleChores = result.sorted { a, b in
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
        
        // Restore focus index to the currently focused chore's index if still present; otherwise clear focus.
        if let recID = focusedChoreRecordID, let idx = visibleChores.firstIndex(where: { $0.recordID == recID }) {
            focusedIndex = idx
        } else {
            focusedIndex = nil
            focusedChoreRecordID = nil
            focusedChoreModel = nil
        }
        
        rebuildVisibleOccurrences()
        
        reconcileFlipState(wasFlipped: wasFlipped, wasShowingBack: wasShowingBack)
    }
    
    /// Keeps the details face tied to the focused card.
    ///
    /// ## Bug fix: details visual left behind after completing a chore
    /// `flippedIndices`/`backVisibleIndices` are keyed by *index*, but a rebuild — which
    /// completing a chore triggers — can move the focused card to another index or drop the
    /// focus altogether. The flip state stayed on the old index, so the carousel ended up
    /// with a card still drawn as the details card (`CarouselCardFrame` shows it whenever the
    /// index is flipped) but not focused, which must never happen.
    ///
    /// The details face now follows the focus: it moves to the card's new index, and is
    /// dropped entirely when nothing is focused any more.
    private func reconcileFlipState(wasFlipped: Bool, wasShowingBack: Bool) {
        guard let focusedIndex else {
            flippedIndices.removeAll()
            backVisibleIndices.removeAll()
            return
        }
        
        flippedIndices = wasFlipped ? [focusedIndex] : []
        backVisibleIndices = wasShowingBack ? [focusedIndex] : []
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
        
        await RoomModel.migrateStoredColorsIfNeeded(rooms)
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
    
    /// Retrieves the assignment(s) for a chore on the day the *grid* layout currently shows
    /// (``gridTargetDay(from:)``).
    ///
    /// This used to resolve against ``nextDate(for:)`` — the chore's *earliest* future
    /// assignment — which is not always ``gridTargetDay()``: a daily chore, for instance, has
    /// an assignment for today *and* tomorrow, so `nextDate` points at today while
    /// ``isVisibleInGrid(_:)`` (what actually decides whether the card is still shown) checks
    /// tomorrow. Completing the card toggled the wrong day's assignment, so the one gating
    /// visibility never changed and the card stayed in the carousel after being marked done.
    func getAssignmentsForActiveContext(for chore: ChoreModel) -> [RecurrentAssignmentModel] {
        getAssignments(for: chore, on: Self.gridTargetDay())
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
    
    // MARK: - isDone Chore Logic
    
    func isDone(for chore: ChoreModel, assignment: RecurrentAssignmentModel?) -> Bool {
        assignment?.isCompleted ?? chore.isDone
    }
    
    /// Toggles the chore's (or, for a recurring chore, this specific day's) completion state
    /// and persists it, then recomputes ``visibleChores``, ``visibleOccurrences`` and
    /// ``dashboard`` so the change shows up immediately — without this, the card would stay in
    /// the carousel/list and the progress numbers would stay stale until the next full
    /// CloudKit refetch.
    @MainActor
    @discardableResult
    func toggle(chore: ChoreModel) async -> Bool {
        let willBeDone = !chore.isDone   // decidido antes de qualquer await

        async let toggled = chore.toggle()
        async let scored = willBeDone
        ? ScoreManager.shared.assignScoreForMyUser(chore: chore)
        : ScoreManager.shared.removeScore(score: chore.score, for: chore.userThatHaveDone!)

        refreshVisible()

        let (toggledSuccessfully, scoredSuccessfully) = await (toggled, scored)
        return toggledSuccessfully && scoredSuccessfully
    }

    @MainActor
    @discardableResult
    func toggle(assignment: RecurrentAssignmentModel) async -> Bool {
        let willBeDone = !assignment.isCompleted

        async let toggled = assignment.toggle()
        async let scored = willBeDone
            ? ScoreManager.shared.assignScoreForMyUser(assignment: assignment)
        : ScoreManager.shared.removeScoreForMyUser(assignment: assignment)

        refreshVisible()

        let (toggledSuccessfully, scoredSuccessfully) = await (toggled, scored)
        return toggledSuccessfully && scoredSuccessfully
    }
    
    // MARK: - Delete
    
    /// What ``removeOccurrenceLocally(chore:targetOccurrences:)`` took out of the in-memory
    /// state, kept around so a failed CloudKit delete can restore it exactly.
    struct RemovedOccurrenceSnapshot {
        let cardModels: [ChoreModel]
        let assignments: [RecurrentAssignmentModel]
    }
    
    /// Removes the given occurrence(s) from ``cardModels``/``dailyAssignments`` right away,
    /// with no `await` and no network round trip, and refreshes every derived list to match.
    ///
    /// This has to run synchronously, *before* the actual CloudKit delete, because `List`'s
    /// native swipe-to-delete expects its backing data to have already changed by the time
    /// the swipe animation finishes: if the data only changes later (after an `await` on the
    /// network), the row disappears, flashes back once SwiftUI notices nothing really
    /// changed yet, then disappears again once the delete eventually completes.
    ///
    /// See ``ChoreModel/delete(targetOccurrences:)`` for the exact rule this follows: no
    /// occurrences (or a non-recurring chore) removes the whole chore; one or more removes
    /// just those days.
    @MainActor
    @discardableResult
    func removeOccurrenceLocally(chore: ChoreModel, targetOccurrences: [RecurrentAssignmentModel]) -> RemovedOccurrenceSnapshot {
        let deletesWholeChore = chore.frequency == .none || targetOccurrences.isEmpty
        
        var removedCardModels: [ChoreModel] = []
        var removedAssignments: [RecurrentAssignmentModel] = []
        
        if deletesWholeChore {
            removedCardModels = cardModels.filter { $0.recordID == chore.recordID }
            removedAssignments = dailyAssignments.filter { $0.choreReference?.recordID == chore.recordID }
            cardModels.removeAll { $0.recordID == chore.recordID }
            dailyAssignments.removeAll { $0.choreReference?.recordID == chore.recordID }
        } else {
            let deletedIDs = Set(targetOccurrences.compactMap { $0.recordID })
            removedAssignments = dailyAssignments.filter { assignment in
                guard let id = assignment.recordID else { return false }
                return deletedIDs.contains(id)
            }
            dailyAssignments.removeAll { assignment in
                guard let id = assignment.recordID else { return false }
                return deletedIDs.contains(id)
            }
        }
        
        if focusedOccurrence?.chore.recordID == chore.recordID {
            clearFocusedDetails()
        }
        
        refreshVisible()
        
        return RemovedOccurrenceSnapshot(cardModels: removedCardModels, assignments: removedAssignments)
    }
    
    /// Persists a deletion already applied locally by
    /// ``removeOccurrenceLocally(chore:targetOccurrences:)``. On failure, restores exactly
    /// what that call removed and sets ``errorMessage``.
    @MainActor
    @discardableResult
    func persistDelete(
        chore: ChoreModel,
        targetOccurrences: [RecurrentAssignmentModel],
        restoring snapshot: RemovedOccurrenceSnapshot
    ) async -> Bool {
        guard await chore.delete(targetOccurrences: targetOccurrences) else {
            cardModels.append(contentsOf: snapshot.cardModels)
            dailyAssignments.append(contentsOf: snapshot.assignments)
            refreshVisible()
            
            errorMessage = CloudKitManager.shared.errorMessage ?? "Não foi possível excluir a tarefa."
            return false
        }
        
        return true
    }
    
    /// Deletes a chore, or — for a recurring chore — just the given occurrence(s), and
    /// refreshes every derived list immediately.
    ///
    /// Combines ``removeOccurrenceLocally(chore:targetOccurrences:)`` and
    /// ``persistDelete(chore:targetOccurrences:restoring:)`` for callers — like the edit
    /// screen's delete button — that don't need to control the timing between them. The
    /// chores list's swipe-to-delete calls the two halves directly instead, so the local
    /// removal happens synchronously, in step with `List`'s own delete animation, before the
    /// network call runs in the background.
    ///
    /// - Returns: `true` on success. On failure, `errorMessage` is set and `false` is
    ///   returned.
    @discardableResult
    func delete(chore: ChoreModel, targetOccurrences: [RecurrentAssignmentModel] = []) async -> Bool {
        let snapshot = await removeOccurrenceLocally(chore: chore, targetOccurrences: targetOccurrences)
        return await persistDelete(chore: chore, targetOccurrences: targetOccurrences, restoring: snapshot)
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
        
        if !filterChoices.rooms.isEmpty {
            let roomIDs = Set(filterChoices.rooms.compactMap { $0.recordID })
            result = result.filter { chore in
                guard let roomID = chore.roomReference?.recordID else { return false }
                return roomIDs.contains(roomID)
            }
        }
        
        return result
    }
    
    /// Changes the filter option
    func addOrRemoveFilter(user: UserModel? = nil, tag: PriorityTag? = nil, frequency: Recurrence? = nil, room: RoomModel? = nil, state: Bool? = nil) {
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
        
        if let room {
            if !filterChoices.rooms.contains(room) {
                filterChoices.rooms.append(room)
            } else {
                filterChoices.rooms.removeAll { $0 == room }
            }
        }
        
        if let state = state {
            if filterChoices.state != state {
                filterChoices.state = state
            } else {
                filterChoices.state = nil
            }
        }
        
        isFilterOn = !filterChoices.users.isEmpty
        || !filterChoices.tags.isEmpty
        || !filterChoices.frequencies.isEmpty
        || !filterChoices.rooms.isEmpty
        || filterChoices.state != nil
        
        // Rebuild visible chores after changing filters.
        rebuildDerivedState()
    }
    
    func resetFilter() {
        isFilterOn = false
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
            // Store the focused chore's recordID to keep it visible regardless of filtering
            if visibleChores.indices.contains(index) {
                let chore = visibleChores[index]
                focusedChoreRecordID = chore.recordID
                focusedChoreModel = chore // Keep a local copy for visibility
            } else {
                focusedChoreRecordID = nil
                focusedChoreModel = nil
            }
        }
    }
    
    func focus(_ index: Int) {
        guard focusedIndex != index else { return }
        
        if focusedIndex != nil {
            withAnimation(.easeOut(duration: 0.15)) {
                focusedIndex = nil
                focusedChoreRecordID = nil
                focusedChoreModel = nil
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
                if self.visibleChores.indices.contains(index) {
                    let chore = self.visibleChores[index]
                    self.focusedChoreRecordID = chore.recordID
                    self.focusedChoreModel = chore // Keep a local copy
                } else {
                    self.focusedChoreRecordID = nil
                    self.focusedChoreModel = nil
                }
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
            // Store focused chore recordID for visibility during filters
            if visibleChores.indices.contains(index) {
                let chore = visibleChores[index]
                focusedChoreRecordID = chore.recordID
                focusedChoreModel = chore // Keep a local copy
            } else {
                focusedChoreRecordID = nil
                focusedChoreModel = nil
            }
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
                focusedChoreRecordID = nil
                focusedChoreModel = nil
                focusedAssignmentRecordID = nil
                focusedAssignmentModel = nil
            }
        }
    }
    
    func focusDetailsImmediately(_ index: Int) {
        flippedIndices.insert(index)
        backVisibleIndices.insert(index)

        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            focusedIndex = index

            guard visibleOccurrences.indices.contains(index) else {
                focusedChoreRecordID = nil
                focusedChoreModel = nil
                focusedAssignmentRecordID = nil
                focusedAssignmentModel = nil
                return
            }

            let occurrence = visibleOccurrences[index]

            focusedChoreRecordID = occurrence.chore.recordID
            focusedChoreModel = occurrence.chore

            focusedAssignmentRecordID = occurrence.assignment?.recordID
            focusedAssignmentModel = occurrence.assignment
        }
    }
    
    func clearFocusedDetails() {
        if let index = focusedIndex {
            flippedIndices.remove(index)
            backVisibleIndices.remove(index)
        }
        
        withAnimation(.easeOut(duration: 0.2)) {
            focusedIndex = nil
            focusedChoreRecordID = nil
            focusedChoreModel = nil
            focusedAssignmentRecordID = nil
            focusedAssignmentModel = nil
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
                // Skipped when the card lost its flip meanwhile (a refresh moved or cleared it).
                if self.flippedIndices.contains(index) {
                    self.backVisibleIndices.insert(index)
                }
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
        
        /// 领取前需要先让用户选日期：一次性项目且没有任何日期。
        var needsDateSelection: Bool {
            if case .oneOff = choreType, displayDate == nil { return true }
            return false
        }
        
        var isOneOffFresh: Bool {
            if case .oneOff = choreType { return true }
            return false
        }
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
            
            await syncSingleChoreToCalendar(item.chore)
            
            await refreshAfterChoreUpdate()
            
        case .recurring(let assignment):
            assignment.userReference = userRef
            await CloudKitManager.shared.update(assignment)
            
            await syncSingleAssignmentToCalendar(for: assignment, chore: item.chore)
            
            await refreshAfterChoreUpdate()
            
        }
    }
    
    // MARK: - Calendar Synchronization
    
    /// Synchronizes a single, non-recurrent chore to the system calendar.
    ///
    /// This method checks if calendar synchronization is enabled in user defaults, verifies access permissions,
    /// retrieves the current user's CloudKit record ID, and upserts or removes the corresponding calendar event.
    ///
    /// - Parameter chore: The `ChoreModel` instance to be synchronized.
    /// - Returns: An asynchronous task that executes on the main actor.
    @MainActor
    func syncSingleChoreToCalendar(_ chore: ChoreModel) async {
        let isSyncEnabled = UserDefaults.standard.bool(forKey: "isCalendarSyncEnabled")
        guard isSyncEnabled else { return }
        guard await CalendarManager.shared.requestAccess() else { return }
        guard let myUser = await CloudKitManager.shared.fetchMyHouseUser(),
              let myUserID = myUser.recordID else { return }
        
        do {
            try await CalendarManager.shared.upsertOneOffEvent(for: chore, currentUserID: myUserID)
        } catch {
            print("Failed to sync single chore: \(error.localizedDescription)")
        }
    }
    
    /// Accurately synchronizes a single day's recurrent assignment.
    ///
    /// Use this method when a specific day's assignment status or assignee changes without altering the global recurrence rule.
    ///
    /// - Parameters:
    ///   - assignment: The `RecurrentAssignmentModel` representing the specific daily instance.
    ///   - chore: The parent `ChoreModel` associated with the assignment.
    /// - Returns: An asynchronous task that executes on the main actor.
    @MainActor
    func syncSingleAssignmentToCalendar(for assignment: RecurrentAssignmentModel, chore: ChoreModel) async {
        let isSyncEnabled = UserDefaults.standard.bool(forKey: "isCalendarSyncEnabled")
        guard isSyncEnabled else { return }
        guard await CalendarManager.shared.requestAccess() else { return }
        guard let myUser = await CloudKitManager.shared.fetchMyHouseUser(),
              let myUserID = myUser.recordID else { return }
        
        do {
            try await CalendarManager.shared.upsertRecurrentEvent(for: assignment, chore: chore, currentUserID: myUserID)
        } catch {
            print("Failed to sync single assignment: \(error.localizedDescription)")
        }
    }
    
    
    // MARK: Picking an unassigned chore that has no date
    
    var itemAwaitingDate: UnassignedItem?
    
    /// A single slot in the confirmation page: may correspond to an existing assignment or a brand new one to be created.
    struct WeeklyPickSlot: Identifiable {
        let id: UUID = UUID()
        /// nil = The user has not selected yet.
        var date: Date?
        /// An existing assignment (e.g., claiming an empty slot, or another week in a weekly chore). nil = Needs to be created.
        var existingAssignment: RecurrentAssignmentModel?
        /// Whether the date can be edited. Existing slots and "this week" slots are usually locked.
        var isDateEditable: Bool
        /// Whether this slot is checked/included for claiming.
        var included: Bool = true
    }
    
    /// Another assignment within the same weekly chore that is still open (unassigned, incomplete).
    func openSiblingWeeklyAssignment(for chore: ChoreModel, excluding: RecurrentAssignmentModel?) -> RecurrentAssignmentModel? {
        guard chore.frequency == .weekly else { return nil }
        return futureAssignments(for: chore).first { candidate in
            candidate.recordID != excluding?.recordID
            && candidate.userReference == nil
            && !candidate.isCompleted
        }
    }
    
    /// The selectable date range; falls back to "15 days starting today" if no scheduling data is available.
    var pickerWindow: Range<Date> {
        if let selectableWindow { return selectableWindow }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let end = calendar.date(byAdding: .day, value: 15, to: today) ?? today
        return today..<end
    }
    
    /// Calculates which slots should initially be displayed based on the item and its frequency when the confirmation page opens.
    func initialPickSlots(for item: UnassignedItem) -> [WeeklyPickSlot] {
        let chore = item.chore
        let calendar = Calendar.current
        let window = pickerWindow
         
        // Daily: One slot per day within the window, all locked, checked by default
        if chore.frequency == .daily {
            var days: [Date] = []
            var day = window.lowerBound
            while day < window.upperBound {
                days.append(day)
                guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
                day = next
            }
            return days.map { WeeklyPickSlot(date: $0, existingAssignment: nil, isDateEditable: false) }
        }
         
        if case .recurring(let assignment) = item.choreType {
            switch chore.frequency {
            case .weekly, .fortnightly, .monthly:
                return [WeeklyPickSlot(date: assignment.day, existingAssignment: assignment, isDateEditable: true)]
            default: break
            }
        }
         
        return [WeeklyPickSlot(date: nil, existingAssignment: nil, isDateEditable: true)]
    }
    
    /// Tapping an item in the list: items requiring a date selection present a confirmation page.
    @MainActor
    func requestPick(_ item: UnassignedItem) {
        var needsSheet = item.needsDateSelection

        if case .recurring = item.choreType {
            switch item.chore.frequency {
            case .weekly, .fortnightly, .monthly: needsSheet = true
            default: break
            }
        }

        if needsSheet {
            dismissUnassignedList()
            itemAwaitingDate = item
        } else {
            Task { await pickForMyself(item) }
        }
    }
    
    /// Called after tapping "Confirm" on the confirmation page. Only slots where `included && date != nil` will be saved.
    @MainActor
    func confirmPick(_ item: UnassignedItem, slots: [WeeklyPickSlot]) async -> Bool {
        let included = slots.filter { $0.included && $0.date != nil }
        guard !included.isEmpty else { return false }
        
        var myUser = dashboardUser
        if myUser == nil {
            myUser = await CloudKitManager.shared.currentHouseUser()
            dashboardUser = myUser
        }
        guard let myUserID = myUser?.recordID else { return false }
        let userRef = CKRecord.Reference(recordID: myUserID, action: .none)
        let chore = item.chore
        
        // One-off chore: Update due date only
        if chore.frequency == .none {
            let previousDue = chore.dueDate
            let previousCurrent = chore.currentResponsibleReference
            let previousAll = chore.allResponsibleUsersReference
            
            chore.dueDate = included[0].date
            chore.currentResponsibleReference = userRef
            var refs = previousAll ?? []
            if !refs.contains(where: { $0.recordID == myUserID }) { refs.append(userRef) }
            chore.allResponsibleUsersReference = refs
            
            guard await CloudKitManager.shared.update(chore) else {
                chore.dueDate = previousDue
                chore.currentResponsibleReference = previousCurrent
                chore.allResponsibleUsersReference = previousAll
                return false
            }
            await syncSingleChoreToCalendar(chore)
            await refreshAfterChoreUpdate()
            return true
        }
        
        // Recurring chore: Each checked slot corresponds to an assignment (update existing ones, create new ones)
        var toUpdate: [RecurrentAssignmentModel] = []
        var toCreate: [WeeklyPickSlot] = []
        
        for slot in included {
            if let existing = slot.existingAssignment {
                existing.userReference = userRef
                if slot.isDateEditable, let date = slot.date {
                    existing.day = Calendar.current.startOfDay(for: date)
                }
                toUpdate.append(existing)
            } else {
                toCreate.append(slot)
            }
        }
        
        var createdModels: [RecurrentAssignmentModel] = []
        if !toCreate.isEmpty {
            guard let room = chore.room,
                  let houseRef = room.houseReference,
                  let choreID = chore.recordID
            else { return false }
            
            let parent = CKRecord.Reference(recordID: houseRef.recordID, action: .none)
            let choreRef = CKRecord.Reference(recordID: choreID, action: .deleteSelf)
            
            for slot in toCreate {
                guard let date = slot.date else { continue }
                let model = RecurrentAssignmentModel(day: date, user: userRef, chore: choreRef)
                guard let saved = await CloudKitManager.shared.create(model, zoneID: houseRef.recordID.zoneID, parent: parent) else {
                    let ids = createdModels.compactMap { $0.recordID }
                    if !ids.isEmpty { await CloudKitManager.shared.delete(recordIDs: ids, zoneID: houseRef.recordID.zoneID) }
                    return false
                }
                createdModels.append(saved)
            }
        }
        
        if !toUpdate.isEmpty {
            await CloudKitManager.shared.batchUpdate(toUpdate)
        }
        
        chore.currentResponsibleReference = userRef
        var refs = chore.allResponsibleUsersReference ?? []
        if !refs.contains(where: { $0.recordID == myUserID }) { refs.append(userRef) }
        chore.allResponsibleUsersReference = refs
        
        let newRefs = createdModels.compactMap { $0.recordID.map { CKRecord.Reference(recordID: $0, action: .none) } }
        if !newRefs.isEmpty {
            chore.dailyAssignmentsReference = (chore.dailyAssignmentsReference ?? []) + newRefs
        }
        if chore.frequency == .monthly, !createdModels.isEmpty {
            chore.shouldBeIncluded = false
        }
        await CloudKitManager.shared.update(chore)
        
        for assignment in toUpdate + createdModels {
            await syncSingleAssignmentToCalendar(for: assignment, chore: chore)
        }
        
        await refreshAfterChoreUpdate()
        return true
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
    
    // MARK: - Custom Calendar
    
    /// Number of uncompleted tasks per day (recurring assignments + one-off chores with a dueDate)
    private(set) var loadByDay: [Date: Int] = [:]
        
    /// From today until the last day of the algorithm window
    var selectableWindow: Range<Date>? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        guard let lastDay = dailyAssignments.map({ calendar.startOfDay(for: $0.day) }).max(),
              lastDay >= today,
              let end = calendar.date(byAdding: .day, value: 1, to: lastDay)
        else { return nil }
        
        return today..<end
    }
    
    /// The two weeks the engine last generated (starts on the cycle's first day, NOT today).
    /// Derived from the last assignment day: engine window = 15 days, so first day = last day - 14.
    /// Falls back to nil when there is no schedule.
    var cycleWindow: Range<Date>? {
        let calendar = Calendar.current
        guard let cycleEnd = currentCycleEnd else { return nil }
        let lastDay = calendar.startOfDay(for: cycleEnd)
        guard let start = calendar.date(byAdding: .day, value: -14, to: lastDay),
              let end = calendar.date(byAdding: .day, value: 1, to: lastDay)
        else { return nil }
        return start..<end
    }
    
    private func rebuildLoadByDay() {
        let calendar = Calendar.current
        var result: [Date: Int] = [:]
        
        for assignment in dailyAssignments where !assignment.isCompleted {
            result[calendar.startOfDay(for: assignment.day), default: 0] += 1
        }
        
        // One-off chores: no assignment, has a dueDate, and uncompleted
        for chore in cardModels where !chore.isDone && (chore.dailyAssignmentsReference ?? []).isEmpty {
            if let due = chore.dueDate {
                result[calendar.startOfDay(for: due), default: 0] += 1
            }
        }
        
        loadByDay = result
    }
    
    
    /// 0 (no tasks on that day, no background) ... 1.0 (the busiest day within the window)
    func loadOpacity(on day: Date, in window: Range<Date>) -> Double {
        let count = loadByDay[Calendar.current.startOfDay(for: day)] ?? 0
        guard count > 0 else { return 0 }
        
        let peak = max(loadByDay.filter { window.contains($0.key) }.values.max() ?? 0, 1)
        return 0.25 + 0.75 * Double(count) / Double(peak)   // Days with tasks have at least 0.25 opacity
    }
    
    //MARK: - Change frequency
    
    /// When editing a chore whose frequency changed, removes every today-onward occurrence
    /// generated under the OLD frequency, then generates a fresh set for the NEW frequency
    /// covering the rest of the current cycle. Past/completed occurrences are left untouched.
    @MainActor
    func handleFrequencyChange(
        for chore: ChoreModel,
        from oldFrequency: Recurrence,
        responsibleUsers: [UserModel],
        pickedDate: Date?
    ) async {
        guard oldFrequency != chore.frequency else { return }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Delete today-onward occurrences left over from the old frequency.
        if oldFrequency != .none {
            let existing = await chore.dailyAssignments
            let toDelete = existing.filter { $0.day >= today }
            
            if !toDelete.isEmpty {
                let deleteIDs = toDelete.compactMap { $0.recordID }
                if let zoneID = deleteIDs.first?.zoneID {
                    await CloudKitManager.shared.delete(recordIDs: deleteIDs, zoneID: zoneID)
                }
                let deletedSet = Set(deleteIDs)
                
                // Remove deleted references from chore model
                chore.dailyAssignmentsReference = (chore.dailyAssignmentsReference ?? [])
                    .filter { !deletedSet.contains($0.recordID) }
                
                // Remove deleted items from ViewModel's in-memory dailyAssignments array
                self.dailyAssignments.removeAll { assignment in
                    guard let id = assignment.recordID else { return false }
                    return deletedSet.contains(id)
                }
            }
        }
        
        // If changing to one-off (.none)
        if chore.frequency == .none {
            chore.dueDate = pickedDate ?? today
            await CloudKitManager.shared.update(chore)
            return
        }
        
        chore.dueDate = nil // Recurring chores use assignments, not dueDate
        
        guard let cycleEnd = currentCycleEnd, let choreID = chore.recordID else {
            await CloudKitManager.shared.update(chore)
            return
        }
        
        // Determine start date according to target frequency rules:
        // - If changing to .daily: always start from today
        // - If changing to .weekly / .fortnightly / .monthly: start from pickedDate (or today if nil)
        let start: Date
        if chore.frequency == .daily {
            start = today
        } else {
            start = pickedDate ?? today
        }
        
        let days = occurrenceDays(for: chore.frequency, from: start, through: cycleEnd)
        guard !days.isEmpty else {
            await CloudKitManager.shared.update(chore)
            return
        }
        
        let rotation = responsibleUsers.compactMap { $0.recordID }
        let choreRef = CKRecord.Reference(recordID: choreID, action: .deleteSelf)
        let assignments = days.enumerated().map { index, day -> RecurrentAssignmentModel in
            let userRef = rotation.isEmpty
                ? nil
                : CKRecord.Reference(recordID: rotation[index % rotation.count], action: .none)
            return RecurrentAssignmentModel(day: day, isCompleted: false, user: userRef, chore: choreRef)
        }
        
        await commitScheduleResults(
            [ScheduleResult(chore: chore, newAssignments: assignments)],
            users: responsibleUsers,
            houseZoneID: choreID.zoneID
        )
    }
}

