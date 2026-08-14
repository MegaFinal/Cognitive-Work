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
struct RoomModelTests {

    @Test func createRoomSuccessfullyTest() async throws {
        await CloudKitManager.shared.createZoneIfNeeded()
        
        let user = RoomModel(name: "roomTestName", color: RoomColor.blue)
        
        let itemSaved = await CloudKitManager.shared.create(user)
        CloudKitManager.shared.errorMessage == nil ? print("success") : print("ERRO:", CloudKitManager.shared.errorMessage as Any)
        
        #expect(itemSaved != nil)
        if let itemSaved = itemSaved {
            await CloudKitManager.shared.delete(itemSaved)
        }
    }
    
    @Test func fetchAllUsersSuccessfullyTest() async throws {
        await CloudKitManager.shared.createZoneIfNeeded()
        
        let user = UserModel(name: "AllUser", tier: .tier1)
        let itemSaved = await CloudKitManager.shared.create(user)
        #expect(itemSaved != nil)
        try await Task.sleep(for: .seconds(2))

        let fetchedUser = await CloudKitManager.shared.fetchAll(UserModel.self)
        #expect(!fetchedUser.isEmpty)
        
        if let itemSaved = itemSaved {
            await CloudKitManager.shared.delete(itemSaved)
        }
    }
    
    @Test func fetchSpecificUserSuccessfully() async throws {
        await CloudKitManager.shared.createZoneIfNeeded()
        
        let user = UserModel(name: "SpecificUser", tier: .tier1)
        let itemSaved = await CloudKitManager.shared.create(user)
        
        #expect(itemSaved != nil)
        try await Task.sleep(for: .seconds(2))
        
        let predicate = NSPredicate(format: "name == %@", "SpecificUser")
        let fetchedUsers = await CloudKitManager.shared.fetchAll(UserModel.self, predicate: predicate)
        print(fetchedUsers)
        print("Error:", CloudKitManager.shared.errorMessage as Any)
        
        #expect(fetchedUsers.contains { $0.name == "SpecificUser" })
        
        if let itemSaved = itemSaved {
            await CloudKitManager.shared.delete(itemSaved)
        }
    }

    @Test func updateUserSuccessfullyTest() async throws {
        await CloudKitManager.shared.createZoneIfNeeded()
        
        let user = UserModel(name: "SpecificUser", tier: .tier1)
        var itemSaved = await CloudKitManager.shared.create(user)
        
        #expect(itemSaved != nil)
        try await Task.sleep(for: .seconds(2))
        
        itemSaved?.name = "UpdatedName"
        await CloudKitManager.shared.update(itemSaved!)
        try await Task.sleep(for: .seconds(2))

        let predicate = NSPredicate(format: "name == %@", "UpdatedName")
        let updatedUsers = await CloudKitManager.shared.fetchAll(UserModel.self, predicate: predicate)
        #expect(updatedUsers.contains { $0.name == "UpdatedName"})
        
        await CloudKitManager.shared.delete(itemSaved!)
    }
    
    @Test func deleteItemSuccessfullyTest() async throws {
        await CloudKitManager.shared.createZoneIfNeeded()
        
        let user = UserModel(name: "SpecificUser", tier: .tier1)
        var itemSaved = await CloudKitManager.shared.create(user)
        
        #expect(itemSaved != nil)
        try await Task.sleep(for: .seconds(2))
        
        let isDeleted = await CloudKitManager.shared.delete(itemSaved!)
        #expect(isDeleted)
    }
}
