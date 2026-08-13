//
//  UserModelTests.swift
//  Cognitive-Work
//
//  Created by Jonas Fernando Nascimento Melo on 13/08/26.
//

import Testing
import Foundation
@testable import Cognitive_Work

@MainActor
struct UserModelTests {

    @Test func createUserSuccessfullyTest() async throws {
        await CloudKitManager.shared.createZoneIfNeeded()
        
        let user = UserModel(name: "test user", tier: .tier1)
        
        let itemSaved = await CloudKitManager.shared.create(user)
        CloudKitManager.shared.errorMessage == nil ? print("success") : print("ERRO:", CloudKitManager.shared.errorMessage as Any)
        
        #expect(itemSaved != nil)
    }

}
