//
//  CheckItemModelTests.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 13/08/26.
//

import Testing
import Foundation
@testable import Cognitive_Work

@MainActor
struct CheckItemModelTests {

    @Test func createCheckItemSuccessfullyTest() async throws {
        await CloudKitManager.shared.createZoneIfNeeded()
        
        let checkItem = CheckItemModel(checkItemName: "checkItemTest", isDone: false)
        let itemSaved = await CloudKitManager.shared.create(checkItem)
        
        print("ERRO:", CloudKitManager.shared.errorMessage as Any)
        
        #expect(itemSaved != nil)
    }

}
