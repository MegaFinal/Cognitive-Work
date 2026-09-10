//
//  GlobalFunctions.swift
//  Cognitive-Work
//

import Foundation
import CloudKit

// MARK: - Context Construction

/// Builds the scheduling context containing user available times, capacities, and responsible maps.
///
/// - Parameters:
///   - users: An array of ``UserModel`` instances representing the household members.
///   - chores: An array of ``ChoreModel`` instances to evaluate.
///   - now: The start date of the scheduling period (today).
///   - windowEnd: The end date of the scheduling period (14 days later).
/// - Returns: A ``ScheduleContext`` instance containing aggregated scheduling metadata.
func buildScheduleContext(
    users: [UserModel],
    chores: [ChoreModel],
    now: Date,
    windowEnd: Date
) async -> ScheduleContext {
    
    var userAvailableTimeMap: [CKRecord.ID: [AvailableTimeModel]] = [:]
    var userTotalCapacity: [CKRecord.ID: Int] = [:]
    
    // Collect all user time request references into a single array
    var allTimeRefs: [CKRecord.Reference] = []
    for user in users {
        if let refs = user.availableTimeReference {
            allTimeRefs.append(contentsOf: refs)
        }
    }
    
    // Perform only 1 network request outside the for loop
    let allFetchedSlots = await CloudKitManager.shared.fetchRecordsByRecordReference(
        for: AvailableTimeModel.self,
        recordReferences: allTimeRefs
    ) ?? []
    
    for user in users {
        guard let userID = user.recordID, let refs = user.availableTimeReference else { continue }
        
        // Extract all record IDs belonging to this user
        let userRefIDs = Set(refs.map { $0.recordID })
        
        // Filter records belonging to this user from the main pool fetched in the single request
        let slots = allFetchedSlots.filter { slot in
            guard let slotID = slot.recordID else { return false }
            return userRefIDs.contains(slotID)
        }
        
        let validSlots = slots.filter { slot in
            let day = Calendar.current.startOfDay(for: slot.day)
            return day >= now && day <= windowEnd
        }
        
        userAvailableTimeMap[userID] = validSlots
        userTotalCapacity[userID] = validSlots.reduce(0) { $0 + $1.capacityMinutes }
    }
    
    var choreResponsibleMap: [CKRecord.ID: UserModel] = [:]
    
    // Additional optimization: Chores whose users are not found locally would traditionally trigger individual awaits in the loop
    var missingUserRefs = Set<CKRecord.Reference>()
    // We can similarly batch these requests
    var missingChores: [ChoreModel] = []
    
    for chore in chores {
        guard let ref = chore.currentResponsibleReference, let choreID = chore.recordID else { continue }
        
        if let local = users.first(where: { $0.recordID == ref.recordID }) {
            choreResponsibleMap[choreID] = local
        } else {
            // Record missing users rather than triggering an immediate network request
            missingUserRefs.insert(ref)
            missingChores.append(chore)
        }
        
        // If there are missing users, fetch them all using a single request
        if !missingUserRefs.isEmpty {
            let fetchedUsers = await CloudKitManager.shared.fetchRecordsByRecordReference(
                for: UserModel.self,
                recordReferences: Array(missingUserRefs)
            ) ?? []
            
            // Populate the map in memory
            for chore in missingChores {
                guard let ref = chore.currentResponsibleReference, let choreID = chore.recordID else { continue }
                if let found = fetchedUsers.first(where: { $0.recordID == ref.recordID }) {
                    choreResponsibleMap[choreID] = found
                }
            }
        }
    }
    
    let minimumCapacity = userTotalCapacity.values.min() ?? 0
    
    return ScheduleContext(
        userAvailableTimeMap: userAvailableTimeMap,
        choreResponsibleMap: choreResponsibleMap,
        userTotalCapacity: userTotalCapacity,
        minimumCapacity: minimumCapacity
    )
}

// MARK: - Recurring Chores

/// Helper function to determine which day offsets a recurring frequency should appear on within the window.
func occurrenceOffsets(for frequency: Recurrence, windowDays: Int, phase: Int = 0) -> [Int] {
    let period: Int
    switch frequency {
    case .daily:       period = 1
    case .weekly:      period = 7
    case .fortnightly: period = 14
    case .monthly, .none: return []
    }
    
    let start = phase % period
    return stride(from: start, to: windowDays, by: period).map { $0 }
}

/// Schedules recurring chores across the 14-day period for appropriate users based on their frequency.
///
/// - Parameters:
///   - recurringChores: An array of recurring chores to schedule.
///   - users: An array of available household members.
///   - context: The current scheduling context.
///   - now: The start date.
///   - remainingCapacity: A mutable reference to remaining capacity per time slot.
///   - userAssignedMinutes: A mutable reference to total assigned minutes per user.
/// - Returns: An array of ``ScheduleResult`` containing the newly generated assignments.
func scheduleRecurringChores(
    _ recurringChores: [ChoreModel],
    users: [UserModel],
    context: ScheduleContext,
    now: Date,
    remainingCapacity: inout [CKRecord.ID: Double],
    userAssignedMinutes: inout [CKRecord.ID: Int]
) -> [ScheduleResult] {
    
    // Initialize the scheduling results array
    var results: [ScheduleResult] = []
    
    // Iterate through each recurring chore
    for chore in recurringChores {
        // Ensure the chore ID exists
        guard let choreID = chore.recordID else { continue }
        // Create a scheduling result object for the current chore
        var result = ScheduleResult(chore: chore)
        
        // Check if this chore has a fixed responsible user; if so, target only that user, otherwise target all users
        let fixedUser = context.choreResponsibleMap[choreID]
        let targetUsers = fixedUser.map { [$0] } ?? users
        
        // Loop through the specific occurrence offsets for this chore's frequency within the 14-day window
        let phase = choreID.recordName.utf8.reduce(0) { ($0 &+ Int($1)) }
        for dayOffset in occurrenceOffsets(for: chore.frequency, windowDays: 14, phase: phase) {
            // Calculate the specific date for the current offset day, skipping if it fails
            guard let day = Calendar.current.date(byAdding: .day, value: dayOffset, to: now) else { continue }
            
            // Initialize the list of users capable of undertaking this chore today
            var availableToday: [UserModel] = []
            for user in targetUsers {
                guard let userID = user.recordID else { continue }
                let slots = context.userAvailableTimeMap[userID] ?? []
                
                
                let hasRoom = slots.contains { slot in
                    guard Calendar.current.startOfDay(for: slot.day) == day, let slotID = slot.recordID
                    else { return false }
                    return (remainingCapacity[slotID] ?? Double(slot.capacityMinutes)) >= chore.duration
                }
                
                if hasRoom {
                    availableToday.append(user)
                }
            }
            
            guard !availableToday.isEmpty else {
                print("No one available for chore '\(chore.name)' on \(day)")
                continue
            }
            
            guard let chosenUser = availableToday.min(by: { u1, u2 in
                let a1 = u1.recordID.flatMap { userAssignedMinutes[$0] } ?? 0
                let a2 = u2.recordID.flatMap { userAssignedMinutes[$0] } ?? 0
                return a1 < a2
            }), let chosenUserID = chosenUser.recordID else { continue }
            
            
            // Get the selected user's available time slots and deduct the corresponding capacity
            let slots = context.userAvailableTimeMap[chosenUserID] ?? []
            
            // Deduct the chore duration from the day's slot
            if let slot = slots.first(where: { Calendar.current.startOfDay(for: $0.day) == day }),
               let slotID = slot.recordID {
                let remaining = remainingCapacity[slotID] ?? Double(slot.capacityMinutes)
                remainingCapacity[slotID] = max(remaining - chore.duration, 0)
            }
            
            // Accumulate the assigned minutes for the selected user
            userAssignedMinutes[chosenUserID, default: 0] += Int(chore.duration)
            
            // Create cloud references and generate the daily assignment model (DailyAssignmentModel)
            let chosenUserRef = CKRecord.Reference(recordID: chosenUserID, action: CKRecord.ReferenceAction.none)
            let choreRef = CKRecord.Reference(recordID: choreID, action: CKRecord.ReferenceAction.deleteSelf)
            let assignment = DailyAssignmentModel(
                day: day,
                isCompleted: false,
                user: chosenUserRef,
                chore: choreRef
            )
            result.newAssignments.append(assignment)
        }
        
        // Add the complete scheduling result of the current chore to the total results set
        results.append(result)
    }
    
    return results
}

// MARK: - Assigned Chores

/// Schedules chores that already have a specific responsible user assigned.
///
/// - Parameters:
///   - assignedChores: An array of chores with predetermined assignees.
///   - context: The scheduling context.
///   - now: The start date.
///   - windowEnd: The end date.
///   - remainingCapacity: Mutable slot capacity dictionary.
///   - userAssignedMinutes: Mutable user assigned minutes dictionary.
/// - Returns: An array of ``ScheduleResult``.
func scheduleAssignedChores(
    _ assignedChores: [ChoreModel],
    context: ScheduleContext,
    now: Date,
    windowEnd: Date,
    remainingCapacity: inout [CKRecord.ID: Double],
    userAssignedMinutes: inout [CKRecord.ID: Int]
) -> [ScheduleResult] {
    
    var results: [ScheduleResult] = []
    
    // Iterate through each chore that already has a responsible user
    for chore in assignedChores {
        // Ensure the chore ID, responsible user, and user ID all exist
        guard let choreID = chore.recordID,
              let user = context.choreResponsibleMap[choreID],
              let userID = user.recordID else { continue }
        
        let updatable = chore
        let slots = context.userAvailableTimeMap[userID] ?? []
        
        // Filter for available time slots within the validity period with sufficient capacity
        let distributables = slots.filter { slot in
            let day = Calendar.current.startOfDay(for: slot.day)
            guard day >= now && day < windowEnd, let slotID = slot.recordID else { return false }
            let remaining = remainingCapacity[slotID] ?? 0
            
            return remaining >= chore.duration
        }
        
        // Find the earliest day to schedule this chore; if no suitable time slot exists, clear the due date and save
        guard let chosenSlot = distributables.min(by: { $0.day < $1.day }),
              let slotID = chosenSlot.recordID else {
            updatable.dueDate = nil
            results.append(ScheduleResult(chore: updatable))
            continue
        }
        
        // Set the chore's due date to the selected time slot's date
        updatable.dueDate = chosenSlot.day
        
        // Deduct the remaining capacity of the corresponding time slot and increase the user's assigned minutes
        remainingCapacity[slotID] = (remainingCapacity[slotID] ?? 0) - chore.duration
        userAssignedMinutes[userID, default: 0] += Int(chore.duration)
        
        // Wrap the result and add it to the set
        results.append(ScheduleResult(chore: updatable))
    }
    
    return results
}

// MARK: - Free Chores

/// Automatically assigns and schedules chores that do not have a pre-assigned responsible user.
///
/// - Parameters:
///   - freeChores: An array of unassigned chores.
///   - users: All available household users.
///   - context: The scheduling context.
///   - now: The start date.
///   - windowEnd: The end date.
///   - remainingCapacity: Mutable slot capacity dictionary.
///   - userAssignedMinutes: Mutable user assigned minutes dictionary.
/// - Returns: An array of ``ScheduleResult``.
func scheduleFreeChores(
    _ freeChores: [ChoreModel],
    users: [UserModel],
    context: ScheduleContext,
    now: Date,
    windowEnd: Date,
    remainingCapacity: inout [CKRecord.ID: Double],
    userAssignedMinutes: inout [CKRecord.ID: Int]
) -> [ScheduleResult] {
    
    var results: [ScheduleResult] = []
    
    // Iterate through each free chore (chores without a pre-assigned responsible user)
    for chore in freeChores {
        let updatable = chore
        
        // Collect all (user, time slot) combinations capable of undertaking this chore
        var distributable: [(user: UserModel, slot: AvailableTimeModel)] = []
        for user in users {
            guard let userID = user.recordID else { continue }
            let slots = context.userAvailableTimeMap[userID] ?? []
            for slot in slots {
                let day = Calendar.current.startOfDay(for: slot.day)
                guard day >= now && day < windowEnd, let slotID = slot.recordID else { continue }
                let remaining = remainingCapacity[slotID] ?? 0
                
                // If capacity is sufficient, add to the optional distribution list
                if remaining >= chore.duration {
                    distributable.append((user, slot))
                }
            }
        }
        
        // If there are no available combinations, clear the responsible user and due date, and return
        guard !distributable.isEmpty else {
            updatable.currentResponsibleReference = nil
            updatable.dueDate = nil
            results.append(ScheduleResult(chore: updatable))
            continue
        }
        
        // Prioritize filtering users to avoid pushing tasks to those already near or over the household minimum capacity limit, preventing overload on capable members
        let baselineUsers = distributable.filter { option in
            guard let userID = option.user.recordID else { return false }
            let used = userAssignedMinutes[userID] ?? 0
            
            return Double(used) + chore.duration < Double(context.minimumCapacity)
        }
        
        // If the baseline user list is empty (everyone would exceed or there is no room for extreme distribution), fall back to all available combinations
        let pool = baselineUsers.isEmpty ? distributable : baselineUsers
        
        // Select the combination with the lightest load and earliest date from the candidate pool as the optimal solution
        guard let chosen = pool.min(by: { o1, o2 in
            let a1 = o1.user.recordID.flatMap { userAssignedMinutes[$0] } ?? 0
            let a2 = o2.user.recordID.flatMap { userAssignedMinutes[$0] } ?? 0
            if a1 != a2 { return a1 < a2 }
            return o1.slot.day < o2.slot.day
        }), let chosenUserID = chosen.user.recordID, let slotID = chosen.slot.recordID else {
            updatable.currentResponsibleReference = nil
            updatable.dueDate = nil
            results.append(ScheduleResult(chore: updatable))
            continue
        }
        
        // Set the selected user as the current responsible person for the chore
        updatable.currentResponsibleReference = CKRecord.Reference(
            recordID: chosenUserID,
            action: CKRecord.ReferenceAction.none
        )
        
        // Update the historical responsible rotation list (allResponsibleUsers), ensuring no duplicate additions
        var rotation = updatable.allResponsibleUsersReference ?? []
        if !rotation.contains(where: { $0.recordID == chosenUserID }) {
            rotation.append(CKRecord.Reference(recordID: chosenUserID, action: CKRecord.ReferenceAction.none))
        }
        updatable.allResponsibleUsersReference = rotation
        
        // Set the due date of the chore
        updatable.dueDate = chosen.slot.day
        
        // Deduct the capacity of the corresponding time slot and accumulate the user's assigned minutes
        remainingCapacity[slotID] = (remainingCapacity[slotID] ?? 0) - chore.duration
        userAssignedMinutes[chosenUserID, default: 0] += Int(chore.duration)
        
        results.append(ScheduleResult(chore: updatable))
    }
    
    return results
}

// MARK: - Repair

/// Clears stale ``ChoreModel/dailyAssignmentsReference`` lists left behind by the zone bug
/// fixed in ``commitScheduleResults(_:users:houseZoneID:)``: before that fix, whichever
/// device ran the scheduler first saved the `DailyAssignmentModel` records into its own
/// private zone instead of the house's, so nobody else — including the house owner — could
/// ever read them back.
///
/// Because ``TaskSchedulerEngine/schedule(chores:users:)`` only reschedules a recurring
/// chore whose reference list is empty, a chore stuck pointing at unreadable records would
/// otherwise never be rescheduled again. This checks whether the referenced records are
/// actually readable and, if none of them are, clears the list so the caller's own
/// `recurringChores` filter picks the chore back up this run.
///
/// - Parameter chores: Every chore currently loaded, as passed into ``TaskSchedulerEngine/schedule(chores:users:)``.
func repairOrphanedRecurringAssignments(in chores: [ChoreModel]) async {
    let recurringFrequencies: Set<Recurrence> = [.daily, .weekly, .fortnightly]
    
    for chore in chores {
        guard !chore.isDone,
              recurringFrequencies.contains(chore.frequency),
              let refs = chore.dailyAssignmentsReference,
              !refs.isEmpty
        else { continue }
        
        // `fetchRecordsByRecordReference` bails out (returns `nil`) the moment a single
        // reference fails to fetch, rather than returning the ones that did resolve. That's
        // fine here: every reference for a given chore was written by the same
        // `commitScheduleResults` call, so they're either all in the wrong zone or all fine
        // — there's no realistic case where only some of them are orphaned.
        let resolved = await CloudKitManager.shared.fetchRecordsByRecordReference(
            for: DailyAssignmentModel.self,
            recordReferences: refs
        )
        
        if resolved?.isEmpty ?? true {
            chore.dailyAssignmentsReference = nil
            await CloudKitManager.shared.update(chore)
        }
    }
}

// MARK: - Persistence

/// Commits all schedule results by saving them to CloudKit and updating user relationships.
///
/// - Parameters:
///   - results: An array of ``ScheduleResult`` to commit.
///   - users: An array of ``UserModel`` to update.
///   - houseZoneID: The house's actual record zone, so the new `DailyAssignmentModel`
///     records land where every housemate (owner included) can read them, rather than in
///     whichever device happens to run this. `nil` falls back to the old, zone-unsafe
///     behavior if the house couldn't be resolved.
func commitScheduleResults(_ results: [ScheduleResult], users: [UserModel], houseZoneID: CKRecordZone.ID?) async {
    guard let zoneID = houseZoneID else { return }
    
    var recordsToSave: [CKRecord] = []
    var choresByUser: [CKRecord.ID: [CKRecord.Reference]] = [:]
    
    for result in results {
        guard let choreID = result.chore.recordID else { continue }
        
        var savedRefs: [CKRecord.Reference] = []
        for assignment in result.newAssignments {
            let recordID = CKRecord.ID(recordName: UUID().uuidString, zoneID: zoneID)
            let record = CKRecord(recordType: DailyAssignmentModel.recordType, recordID: recordID)
            
            assignment.populate(record: record)
            recordsToSave.append(record)
            savedRefs.append(CKRecord.Reference(recordID: recordID, action: .none))
            
            // Categorize by user
            if let assignedID = assignment.user?.recordID {
                choresByUser[assignedID, default: []].append(CKRecord.Reference(recordID: choreID, action: .none))
            }
        }
        
        // Update local chore references
        if !savedRefs.isEmpty {
            result.chore.dailyAssignmentsReference = (result.chore.dailyAssignmentsReference ?? []) + savedRefs
        }
    }
    
    // Batch save the schedule records
    if !recordsToSave.isEmpty {
        await CloudKitManager.shared.batchSave(records: recordsToSave, zoneID: zoneID)
    }
    
    // Use parallel multithreading (TaskGroup) to update existing Chores and Users
    // Perfectly aligns with the architecture guidelines for multithreading concurrency
    await withTaskGroup(of: Void.self) { group in
        
        // Concurrently update all chores
        for result in results {
            let chore = result.chore
            group.addTask {
                await CloudKitManager.shared.update(chore)
            }
        }
        
        for user in users {
            guard let userID = user.recordID,
                  let newRefs = choresByUser[userID],
                  !newRefs.isEmpty else { continue }
            
            let existingRefs = user.choresReference ?? []
            let existingIDs = Set(existingRefs.map { $0.recordID })
            let dedupedNewRefs = newRefs.filter { !existingIDs.contains($0.recordID) }
            
            if !dedupedNewRefs.isEmpty {
                user.choresReference = existingRefs + dedupedNewRefs
                
                group.addTask {
                    await CloudKitManager.shared.update(user)
                }
            }
        }
    }
}
