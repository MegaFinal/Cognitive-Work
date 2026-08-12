//
//  HouseExtencion.swift
//  Cognitive-Work
//
//  Created by Jonas Fernando Nascimento Melo on 11/08/26.
//

import CloudKit

// MARK: - User extension (CRUD)
extension CloudKitManager {
    
    func createUser(name: String, profilePicture: Data, coins: Int = 0,
                    points: Int = 0, couponsLimit: Int = 0) async -> CKRecord? {
        guard let cloudKitUserID = try? await CKContainer.default().userRecordID()
        else {return nil}
        let userID = CKRecord.ID(recordName: cloudKitUserID.recordName, zoneID: houseZoneID)
        
        let user = CKRecord(recordType: "User", recordID: userID)
        user["name"] = name
        user["profilePicture"]  = profilePicture
        user["coins"] = coins
        user["points"] = points
        user["couponsLimit"] = couponsLimit
        
        do {
            try await privateDB.save(user)
        }
        catch {
            print("Fail to save user in private database \(error.localizedDescription)")
        }
        
        return user
    }
    
    func fetchAllUsers(house: CKRecord) async -> [CKRecord] {
        let predicate = NSPredicate(format: "house == %@",
                                    CKRecord.Reference(record: house, action: .none))
        let query = CKQuery(recordType: "User", predicate: predicate)
        
        do {
            let zoneID = house.recordID.zoneID
            let db = zoneID.ownerName == CKCurrentUserDefaultName ? privateDB : sharedDB
            let (results, _) = try await db.records(matching: query, inZoneWith: zoneID)
            return results.compactMap { try? $0.1.get() }
        } catch {
            errorMessage = "Fail to fetch user: \(error.localizedDescription)"
            return []
        }
    }
    
    func updateUserAttributes(user: CKRecord, name: String? = nil,
                              profilePicture: Data? = nil, coins: Int? = nil, points: Int? = nil,
                              couponLimit: Int? = nil) async -> Bool {
        if let name = name { user["name"] = name }
        if let profilePicture = profilePicture { user["profilePicture"] = profilePicture }
        if let coins = coins { user["coins"] = coins }
        if let points = points { user["points"] = points }
        if let couponLimit = couponLimit { user["couponLimit"] = couponLimit }
        
        do {
            let db = user.recordID.zoneID.ownerName == CKCurrentUserDefaultName ? privateDB : sharedDB
            _ = try await db.save(user)
            return true
        } catch {
            errorMessage = "Fail to update user: \(error.localizedDescription)"
            return false
        }
    }
    
    func addHouseToUser(user: CKRecord, house: CKRecord) async -> Bool {
        do {
            let db = house.recordID.zoneID.ownerName == CKCurrentUserDefaultName ? privateDB : sharedDB
            let houseReference = CKRecord.Reference(record: house, action: .none)
            
            if db === privateDB {
                user["house"] = houseReference
                user.parent = houseReference
                try await db.save(user)
            }
            else {
                let userCopy = CKRecord(
                    recordType: user.recordType,
                    recordID: CKRecord.ID(
                        recordName: user.recordID.recordName,
                        zoneID: house.recordID.zoneID
                    )
                )

                userCopy["name"] = user["name"]
                userCopy["house"] = houseReference
                userCopy.parent = houseReference

                try await db.save(userCopy)
            }
            return true
        } catch {
            print("Fail to attribute user a house: \(error.localizedDescription)")
            return false
        }
    }
    
    func removeUserHouse(user: CKRecord) async -> Bool{
        do {
            user.parent = nil
            user["house"] = nil
            let db = user.recordID.zoneID.ownerName == CKCurrentUserDefaultName ? privateDB : sharedDB
            _ = try await db.save(user)
            return true
        }
        catch {
            print("Fail to remove users's house:  \(error.localizedDescription)")
            return false
        }
    }
    
    func deleteUser(_ user: CKRecord) async -> Bool {
        do {
            let db = user.recordID.zoneID.ownerName == CKCurrentUserDefaultName ? privateDB : sharedDB
            try await db.deleteRecord(withID: user.recordID)
            return true
        } catch {
            errorMessage = "Fail to delete user: \(error.localizedDescription)"
            return false
        }
    }
}
