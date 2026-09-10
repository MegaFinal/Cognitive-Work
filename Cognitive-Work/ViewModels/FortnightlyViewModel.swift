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
    /// The specific date when the chore is scheduled or due.
    let day: Date
    
    /// The unique CloudKit record identifier of the user assigned to the chore.
    let userID: CKRecord.ID
    
    /// The unique CloudKit record identifier of the chore itself.
    let choreID: CKRecord.ID
    
    /// The estimated duration of the chore in minutes.
    let minutes: Double
    
    /// The display name of the chore.
    let choreName: String
    
    /// The calculated duration tier (e.g., short, medium, long) derived from the chore's minutes.
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
    
    /// A collection of raw daily assignment records fetched from CloudKit.
    var dailyAssignments: [DailyAssignmentModel] = []
    
    /// The starting date of the current fortnightly cycle (typically adjusted to start on a specific weekday).
    var startDate: Date = Date()
    
    /// A boolean flag indicating whether the view model is currently loading initial data.
    var isLoading: Bool = true
    
    /// An optional error message capturing any failure states during data synchronization.
    var errorMessage: String?
    
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
        let fetchedUsers = await CloudKitManager.shared.fetchHouseUsers()
        let fetchedChores = await CloudKitManager.shared.fetchAll(ChoreModel.self)
        
        await setup(users: fetchedUsers, chores: fetchedChores)
        
        print("---------------------------------------------------------------------------")
        for chore in fetchedChores {
            if chore.frequency == .monthly {
                print(chore.name)
            }
        }
    }
    
    /// Handles common post-fetch initialization tasks like loading assignments and calculating the date window.
    private func finishSetup() async {
        dailyAssignments = await CloudKitManager.shared.fetchAll(DailyAssignmentModel.self)
        
        let calendar = Calendar.current
        let today = Date()
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: today)) else { return }
        
        self.startDate = tomorrow
        
        isLoading = false
    }
    
    // MARK: - Data Processing
    
    /// An asynchronous computed property that transforms raw chores and assignments into a clean array of `DailyUsageEntry` objects.
    ///
    /// ### Complex Logic Breakdown:
    /// 1. **Chore Validation:** Skips any chore that hasn't been saved to CloudKit yet (i.e., lacks a `recordID`).
    /// 2. **Branching Strategy (Assignments vs. Fallback):**
    ///   - **With Daily Assignments (`dailyAssignmentsReference`):** Cross-references the chore's linked references with the globally loaded `dailyAssignments`. For each matched assignment, it looks up the associated user asynchronously and builds a dedicated usage entry.
    ///   - **Fallback (No Daily Assignments):** If a chore has no rigid daily schedule, it falls back to a single deadline-based assignment by reading the chore's `dueDate` and `currentResponsible` user.
    var usageEntries: [DailyUsageEntry] {
        var entries: [DailyUsageEntry] = []
        
        for chore in chores {
            guard let choreID = chore.recordID else { continue }
            
            if let refs = chore.dailyAssignmentsReference, !refs.isEmpty {
                let relatedAssignments = dailyAssignments.filter { assignment in
                    refs.contains { $0.recordID == assignment.recordID }
                }
                
                for assignment in relatedAssignments {
                    guard let userID = assignment.userReference?.recordID else { continue }
                    entries.append(DailyUsageEntry(
                        day: assignment.day,
                        userID: userID,
                        choreID: choreID,
                        minutes: chore.duration,
                        choreName: chore.name
                    ))
                }
            } else {
                guard let dueDate = chore.dueDate,
                      let userID = chore.currentResponsibleReference?.recordID
                else { continue }
                
                entries.append(DailyUsageEntry(
                    day: dueDate,
                    userID: userID,
                    choreID: choreID,
                    minutes: chore.duration,
                    choreName: chore.name
                ))
            }
        }
        
        return entries
    }
}
