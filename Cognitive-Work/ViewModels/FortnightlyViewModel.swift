//
//  FortnightlyViewModel.swift
//  Cognitive-Work
//
//  Created by anshu Li on 24/08/26.
//
import SwiftUI
import CloudKit

@Observable
class FortnightlyViewModel {
    var users: [UserModel] = []
    var isLoading = false
    var errorMessage: String?

    func loadUsers(houseReference: CKRecord.Reference) async {
        isLoading = true
        defer { isLoading = false }

        let predicate = NSPredicate(format: "house == %@", houseReference)
        let fetched = await CloudKitManager.shared.fetchAll(UserModel.self, predicate: predicate)

        guard !fetched.isEmpty else {
            errorMessage = "No users found"
            return
        }
        users = fetched
    }
}
