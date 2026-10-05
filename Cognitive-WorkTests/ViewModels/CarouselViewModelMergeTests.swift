//
//  CarouselViewModelMergeTests.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 05/10/26.
//

import Testing
import Foundation
import CloudKit
@testable import Cognitive_Work

/// ``CarouselViewModel/merging(_:preserving:)``: records just saved on this device must win over
/// a `CKQuery` result that can still be stale right after the save.
struct CarouselViewModelMergeTests {
    
    private func makeAssignment(_ recordName: String, user: String?) -> RecurrentAssignmentModel {
        let assignment = RecurrentAssignmentModel(
            day: Date(),
            user: user.map { CKRecord.Reference(recordID: CKRecord.ID(recordName: $0), action: .none) }
        )
        assignment.recordID = CKRecord.ID(recordName: recordName)
        return assignment
    }
    
    @Test("A saved record replaces its stale fetched copy")
    func savedReplacesStale() {
        let stale = makeAssignment("a1", user: "old")
        let other = makeAssignment("a2", user: "someone")
        let saved = makeAssignment("a1", user: "new")
        
        let result = CarouselViewModel.merging([stale, other], preserving: [saved])
        
        #expect(result.count == 2)
        #expect(result.first { $0.recordID?.recordName == "a1" } === saved)
        #expect(result.first { $0.recordID?.recordName == "a2" } === other)
    }
    
    @Test("A saved record the query left out is added back")
    func savedMissingFromQueryIsKept() {
        let other = makeAssignment("a2", user: "someone")
        let saved = makeAssignment("a1", user: "new")
        
        let result = CarouselViewModel.merging([other], preserving: [saved])
        
        #expect(result.count == 2)
        #expect(result.contains { $0 === saved })
    }
    
    @Test("Nothing saved keeps the fetched list untouched")
    func emptySavedIsNoOp() {
        let fetched = [makeAssignment("a1", user: "x"), makeAssignment("a2", user: "y")]
        
        let result = CarouselViewModel.merging(fetched, preserving: [])
        
        #expect(result.map(\.recordID) == fetched.map(\.recordID))
    }
}
