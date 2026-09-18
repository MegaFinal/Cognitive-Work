//
//  CalendarManager.swift
//  Cognitive-Work
//
//  Created by anshu Li on 18/09/26.
//

import Foundation
import EventKit
import CloudKit

@Observable
class CalendarManager {
    static let shared = CalendarManager()
    
    private let store = EKEventStore()
    private let calendarTitle = "Pipa" // Dedicated calendar name
    
    private init() {}
    
    /// Requests calendar access permission from the user.
    func requestAccess() async -> Bool {
        do {
            return try await store.requestFullAccessToEvents()
        } catch {
            print("Failed to request calendar access: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Finds the dedicated app calendar or creates a new one if it does not exist.
    private func dedicatedCalendar() throws -> EKCalendar {
        let calendars = store.calendars(for: .event)
        if let existing = calendars.first(where: { $0.title == calendarTitle }) {
            return existing
        }
        
        let newCal = EKCalendar(for: .event, eventStore: store)
        newCal.title = calendarTitle
        
        // Match a suitable account source for the new calendar
        if let iCloudSource = store.sources.first(where: { $0.sourceType == .calDAV && $0.title.contains("iCloud") }) {
            newCal.source = iCloudSource
        } else if let localSource = store.sources.first(where: { $0.sourceType == .local }) {
            newCal.source = localSource
        } else if let defaultSource = store.defaultCalendarForNewEvents?.source {
            newCal.source = defaultSource
        } else if let firstSource = store.sources.first {
            newCal.source = firstSource
        }
        
        try store.saveCalendar(newCal, commit: true)
        return newCal
    }
    
    /// Commits all pending calendar write operations.
    func commitBatch() throws {
        try store.commit()
    }
    
    // MARK: - Event Construction & Staging
    
    /// Configures and stages a single one-off chore event.
    private func oneOffEvent(for chore: ChoreModel) throws {
        guard let dueDate = chore.dueDate else { return }
        let calendar = try dedicatedCalendar()
        
        let event = EKEvent(eventStore: store)
        event.title = "\(chore.name)"
        event.notes = chore.description.isEmpty ? "Room Chore - Estimated duration: \(Int(chore.duration)) min" : "\(chore.description)\n\nEstimated duration: \(Int(chore.duration)) min"
        
        event.isAllDay = true
        event.startDate = dueDate
        event.endDate = dueDate
        event.calendar = calendar
        
        try store.save(event, span: .thisEvent, commit: false)
    }
    
    /// Configures and stages a single recurrent chore event instance.
    private func recurrentEvent(for assignment: RecurrentAssignmentModel, chore: ChoreModel) throws {
        let calendar = try dedicatedCalendar()
        
        let event = EKEvent(eventStore: store)
        event.title = "\(chore.name)"
        event.notes = chore.description.isEmpty ? "Room Chore - Estimated duration: \(Int(chore.duration)) min" : "\(chore.description)\n\nEstimated duration: \(Int(chore.duration)) min"
        
        event.isAllDay = true
        event.startDate = assignment.day
        event.endDate = assignment.day
        event.calendar = calendar
        
        try store.save(event, span: .thisEvent, commit: false)
    }
    
    
    // MARK: - Public APIs: Batch Synchronization & Deletion
    
    /// Synchronizes all chores (both recurrent and one-off) for the current user in batch.
    func batchSyncAllChores(
        _ assignments: [RecurrentAssignmentModel],
        allChores: [ChoreModel],
        choresMap: [CKRecord.ID: ChoreModel],
        currentUserID: CKRecord.ID
    ) async {
        guard await requestAccess() else {
            print("User denied calendar access.")
            return
        }
        
        do {
            var syncedCount = 0
            
            // Recurrent chores
            for assignment in assignments {
                guard assignment.userReference?.recordID == currentUserID else { continue }
                guard let choreRef = assignment.choreReference?.recordID,
                      let chore = choresMap[choreRef] else { continue }
                
                try recurrentEvent(for: assignment, chore: chore)
                syncedCount += 1
            }
            
            // One-off chores
            for chore in allChores {
                guard chore.frequency == .none,
                      let responsibleRef = chore.currentResponsibleReference,
                      responsibleRef.recordID == currentUserID,
                      chore.dueDate != nil else { continue }
                
                try oneOffEvent(for: chore)
                syncedCount += 1
            }
            
            // Commit all changes at once
            try commitBatch()
            print("Successfully synced a total of \(syncedCount) chores to Apple Calendar!")
            
        } catch {
            print("Failed to batch sync all chores to calendar: \(error.localizedDescription)")
        }
    }
    
    /// Clears all chore events from the dedicated "Pipa" calendar.
    func clearAllMyCalendarEvents() async {
        guard await requestAccess() else { return }
        
        do {
            let calendarObj = try dedicatedCalendar()
            
            // Search time range: from 1 year ago to 2 years in the future
            let startDate = Calendar.current.date(byAdding: .year, value: -1, to: Date())!
            let endDate = Calendar.current.date(byAdding: .year, value: 2, to: Date())!
            
            let predicate = store.predicateForEvents(withStart: startDate, end: endDate, calendars: [calendarObj])
            let events = store.events(matching: predicate)
            
            for event in events {
                try store.remove(event, span: .thisEvent, commit: false)
            }
            
            try store.commit()
            print("Successfully cleared all events from Pipa calendar instantly!")
        } catch {
            print("Failed to clear calendar events: \(error.localizedDescription)")
        }
    }
}
