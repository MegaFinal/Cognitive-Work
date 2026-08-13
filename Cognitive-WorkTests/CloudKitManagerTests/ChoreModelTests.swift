//
//  ChoreModelTests.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 13/08/26.
//

import Testing
import Foundation
@testable import Cognitive_Work

@MainActor
struct ChoreModelTests {

    @Test func createChoreSuccessfullyTest() async throws {
        await CloudKitManager.shared.createZoneIfNeeded()
        
        let chore = ChoreModel(
            name: "choreTest",
            description: "testDescription",
            frequency: .daily,
            duration: 30.0,
            isPublic: true,
            priorityTag: .urgent,)
        
        let itemSaved = await CloudKitManager.shared.create(chore)
        
        print("ERRO:", CloudKitManager.shared.errorMessage as Any)
        
        #expect(itemSaved != nil)
    }

}
