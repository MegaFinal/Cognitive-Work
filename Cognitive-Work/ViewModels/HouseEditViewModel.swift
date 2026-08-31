//
//  HouseEditViewModel.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 31/08/26.
//

import Foundation
import CloudKit

/// Owns every house CRUD operation and returns admin state for views to read.
@Observable
final class HouseEditViewModel {
    
    /// The house currently loaded for display/editing.
    private(set) var house: HouseModel?
    
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    var isUserAdmin: Bool = false
    
    init(house: HouseModel? = nil) {
        self.house = house
    }
    
    // MARK: - Authorization
    func checkAdminStatus() async {
        guard let house = house else {
            isUserAdmin = false
            return
        }
        
        let isAdmin = await house.isAdmin()
        
        await MainActor.run {
            self.isUserAdmin = (isAdmin == true)
        }
    }
    
    // MARK: - Fetch
    
    /// Loads a single house by its record ID.
    func fetchHouse(recordID: CKRecord.ID) async {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        let reference = CKRecord.Reference(recordID: recordID, action: .none)
        guard let fetchedHouse = await CloudKitManager.shared
            .fetchRecordsByRecordReference(for: HouseModel.self, recordReferences: [reference])?
            .first
        else {
            errorMessage = "Failed to retrieve the record"
            return
        }
        
        house = fetchedHouse
    }
    
    // MARK: - Delete
    
    /// Deletes the loaded house. Refuses — without ever calling CloudKit — unless the
    /// signed-in user is the one who created it.
    @discardableResult
    func deleteHouse() async -> Bool {
        guard let house else {
            errorMessage = "Failed to retrieve house"
            return false
        }
        
        guard await house.isAdmin() == true else {
            errorMessage = "Failed to delete due to unauthorized credentials"
            return false
        }
        
        isLoading = true
        defer { isLoading = false }
        
        let success = await CloudKitManager.shared.delete(house)
        guard success else {
            errorMessage = "Failed to delete"
            return false
        }
        
        self.house = nil
        return success
    }
}
