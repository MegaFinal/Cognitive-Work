////
////  FortnightlyViewModel.swift
////  Cognitive-Work
////
////  Created by anshu Li on 24/08/26.
////

import SwiftUI
import CloudKit

/// A data model representing a single daily usage or chore entry for a user,
/// typically utilized for charting and e-paper display formatting.
struct DailyUsageEntry {
    let day: Date
    let userID: CKRecord.ID
    let choreID: CKRecord.ID
    let minutes: Double
    let choreName: String
    var tier: ChoreDurationTier { ChoreDurationTier.from(minutes: minutes) }
}

/// A view model that coordinates fortnightly chore tracking, assignments, and data aggregation.
///
/// `FortnightlyViewModel` manages users, chores, and daily assignments fetched from CloudKit.
/// It automatically computes the starting date of the fortnightly cycle and transforms raw assignment
/// data into structured usage entries for rendering charts.
@Observable
class FortnightlyViewModel {
    
    // MARK: - Properties
    
    /// A list of all users participating in the system.
    var users: [UserModel] = []
    
    /// A list of all available chores.
    var chores: [ChoreModel] = []
    
    /// A collection of raw recurrent assignment records fetched from CloudKit.
    var recurrentAssignments: [RecurrentAssignmentModel] = []
    
    /// The starting date of the current fortnightly cycle (typically adjusted to start on a specific weekday).
    var startDate: Date = Date()
    
    /// A boolean flag indicating whether the view model is currently loading initial data.
    var isLoading: Bool = true
    
    /// An optional error message capturing any failure states during data synchronization.
    var errorMessage: String?
    
    /// Stored property for usage entries to allow synchronous access in SwiftUI Views.
    var usageEntries: [DailyUsageEntry] = []
    
    // MARK: - Setup Methods
    
    /// Configures the view model with pre-fetched users and chores, then fetches daily assignments
    /// and calculates the fortnightly start date.
    ///
    /// - Parameters:
    ///   - users: An array of already loaded `UserModel` instances.
    ///   - chores: An array of already loaded `ChoreModel` instances.
    func setup(users: [UserModel], chores: [ChoreModel]) async {
        self.users = users
        self.chores = chores
        
        await finishSetup()
    }
    
    /// Fetches all users, chores, and daily assignments directly from CloudKit,
    /// and initializes the fortnightly time frame.
    func setupWithFetch() async {
        // 1. 并行获取用户和任务
        async let fetchU = CloudKitManager.shared.fetchHouseUsers()
        async let fetchC = CloudKitManager.shared.fetchAll(ChoreModel.self)
        
        let (fetchedUsers, fetchedChores) = await (fetchU, fetchC)
        
        self.users = fetchedUsers
        self.chores = fetchedChores
        
        await finishSetup()
    }
    
    /// Handles common post-fetch initialization tasks like loading assignments and calculating the date window.
    private func finishSetup() async {
        recurrentAssignments = await CloudKitManager.shared.fetchAll(RecurrentAssignmentModel.self)
        
        let calendar = Calendar.current
        let today = Date()
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: today)) {
            self.startDate = tomorrow
        }
        
        recurrentAssignments = await CloudKitManager.shared.fetchAll(RecurrentAssignmentModel.self)
        
        await loadUsageEntries()
        
        isLoading = false
    }
    
    // MARK: - Data Processing
    /// Processes raw chores and assignments into a clean array of `DailyUsageEntry` objects.
    func loadUsageEntries() async {
        var entries: [DailyUsageEntry] = []
        
        var assignmentDict: [CKRecord.ID: RecurrentAssignmentModel] = [:]
        for assignment in recurrentAssignments {
            if let id = assignment.recordID {
                assignmentDict[id] = assignment
            }
        }
        
        let userIDs = Set(users.compactMap { $0.recordID })
        
        for chore in chores {
            guard let choreID = chore.recordID else { continue }
            
            if let refs = chore.dailyAssignmentsReference, !refs.isEmpty {
                for ref in refs {
                    let assignmentID = ref.recordID
                    
                    guard let assignment = assignmentDict[assignmentID] else { continue }
                    
                    let userID: CKRecord.ID?
                    if let userRef = assignment.userReference {
                        userID = userRef.recordID
                    } else if let userObj = await assignment.user {
                        userID = userObj.recordID
                    } else {
                        userID = nil
                    }
                    
                    guard let finalUserID = userID, userIDs.contains(finalUserID) else { continue }
                    
                    entries.append(DailyUsageEntry(
                        day: assignment.day,
                        userID: finalUserID,
                        choreID: choreID,
                        minutes: chore.duration,
                        choreName: chore.name
                    ))
                }
            } else {
                guard let dueDate = chore.dueDate,
                      let responsibleRef = chore.currentResponsibleReference
                else { continue }
                
                let responsibleID = responsibleRef.recordID
                
                guard userIDs.contains(responsibleID) else { continue }
                
                entries.append(DailyUsageEntry(
                    day: dueDate,
                    userID: responsibleID,
                    choreID: choreID,
                    minutes: chore.duration,
                    choreName: chore.name
                ))
            }
        }
        
        await MainActor.run {
            self.usageEntries = entries
        }
    }
}
