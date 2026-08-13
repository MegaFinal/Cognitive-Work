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
        
        let house = HouseModel(
            name: "choreTest",
            description: "testDescription",
            chores:[] ,
            users:[],
            shopListItem:[] ,
           )
        
        let savedItem = await CloudKitManager.shared.create(chore)
        
        print("ERRO:", CloudKitManager.shared.errorMessage as Any)
        
        #expect(savedItem != nil)
        
        if let savedItem {
            await CloudKitManager.shared.delete(savedItem)
        }
    }
}
