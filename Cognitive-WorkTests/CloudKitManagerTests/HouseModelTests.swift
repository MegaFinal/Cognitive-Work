//
//  HouseModelTests.swift
//  Cognitive-WorkTests
//
//  Created by Carolina Sun on 13/08/26.
//

import Foundation
import Testing
import Foundation
import CloudKit
@testable import Cognitive_Work

@MainActor
struct HouseModelTests {
    @Test func createHouseSuccessfullyTest() async throws {
        await CloudKitManager.shared.createZoneIfNeeded()
        
        let chore = HouseModel(name: "houseNameTest", description: "houseDescriptionTest")
        
        let itemSaved = await CloudKitManager.shared.create(chore)
        
        print("ERRO:", CloudKitManager.shared.errorMessage as Any)
        
        #expect(itemSaved != nil)
    }
}

