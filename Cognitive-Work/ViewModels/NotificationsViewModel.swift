//
//  NotificationsViewMode.swift
//  Cognitive-Work
//
//  Created by Isabela Hissa Pinto on 30/09/26.
//

import SwiftUI
import CloudKit

struct NotificationModel {
    let id: UUID
    let color: Color
    let symbol: String
    let title: String
    let subtitle: String
    let date: Date
}

@Observable
class NotificationsViewModel {
    
    var choreModels: [ChoreModel] = []
    var assignments: [RecurrentAssignmentModel] = []
    
    var todayUnassignedChores: [ChoreModel] = []
    var userLateChores: [ChoreModel] = []
    var lateUnassignedChores: [ChoreModel] = []
    
    var notifications: [Notifications] = []
    private var localPersistence = UserDefaults.standard
    private var hasFetchedInitially = false
    private var isLoading = false
    
    private(set) var theUser: UserModel?
    
    // MARK: - Initialization & Data Fetching
    
    func setup() async {
        await fetchAllData()
        
        
    }
    
    /// Assignments keyed by their own record ID.
    @ObservationIgnored
    private var assignmentsByID: [CKRecord.ID: RecurrentAssignmentModel] = [:]

    static let gridDayOffsetFromToday = 0
    
    /// The single day the grid layout renders, normalised to the start of that day.
    /// - Parameter reference: The day to count from. Defaults to now; injectable for tests.
    static func gridTargetDay(from reference: Date = Date()) -> Date {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: reference)
        return calendar.date(byAdding: .day, value: gridDayOffsetFromToday, to: startOfToday)
        ?? startOfToday
    }
    
    /// Fetches all chores and assignments in parallel.
    func fetchAllData() async {
        if !hasFetchedInitially {
            await MainActor.run { isLoading = true }
        }
        
        async let fetchChores = CloudKitManager.shared.fetchAll(ChoreModel.self)
        async let fetchAssignments = CloudKitManager.shared.fetchAll(RecurrentAssignmentModel.self)
        
        let (chores, assignments) = await (fetchChores, fetchAssignments)
        
        guard !Task.isCancelled else { return }
        
        await MainActor.run {
//            self.choreModels = chores.filter{
//                $0.dueDate <= gridTargetDay() }
            self.hasFetchedInitially = true
            self.isLoading = false
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
    
    func getAssignmentsForActiveContext(for chore: ChoreModel) -> [RecurrentAssignmentModel] {
        getAssignments(for: chore, on: Self.gridTargetDay())
    }
    
}
