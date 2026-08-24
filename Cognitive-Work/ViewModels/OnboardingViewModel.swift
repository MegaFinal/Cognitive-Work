//
//  OnboardingViewModel.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 19/08/26.
//

import SwiftUI
import CloudKit

struct RoomDraft: Identifiable {
    let id = UUID()
    var name: String
    var symbol: String
    var isSelected: Bool = false
    var isAddButton: Bool = false
    var color: RoomColor = .blue
}

@Observable
class OnboardingViewModel {
    var userName: String = ""
    var userProfilePicture: UIImage?
    var houseName: String = "Minha Casa"
    var houseDescription: String = "Organização Doméstica"
    
    var isLoading: Bool = false
    var errorMessage: String? = nil
    
    var navigateToSecond: Bool = false
    var navigateToThird: Bool = false
    var navigateToFourth: Bool = false
    var onboardingFinished: Bool = false
    
    var currentUser: UserModel?
    var currentHouse: HouseModel?
    
    var availableRooms: [RoomDraft] = [
        RoomDraft(name: "Quarto", symbol: "bed.double"),
        RoomDraft(name: "Sala de Estar", symbol: "sofa"),
        RoomDraft(name: "Área de Serviço", symbol: "washer"),
        RoomDraft(name: "Cozinha", symbol: "cooktop"),
        RoomDraft(name: "Banheiro", symbol: "toilet"),
        RoomDraft(name: "Outro", symbol: "plus", isAddButton: true)
    ]
    
    // MARK: - CloudKit
    @MainActor
    func createUser() async {
        isLoading = true
        errorMessage = nil
        
        let imageData = userProfilePicture?.jpegData(compressionQuality: 0.8)
        
        let newUser = UserModel(name: userName.isEmpty ? "Novo Morador" : userName, profilePicture: imageData, tier: .tier1)
        
        if let savedUser = await CloudKitManager.shared.create(newUser) {
            self.currentUser = savedUser
            navigateToThird = true
        } else {
            errorMessage = "Erro ao criar usuário."
        }
        isLoading = false
    }
    
    /// Updates the profile image with the image received from the keyboard.
    /// - Parameter image: The image selected by the user.
    func updateProfileImage(_ image: UIImage) {
        userProfilePicture = image
    }
    
    @MainActor
    func createHouseAndLinkUser() async {
        guard let savedUser = currentUser, let userRecordID = savedUser.recordID else { return }
        
        isLoading = true
        errorMessage = nil
        
        let userReference = CKRecord.Reference(recordID: userRecordID, action: .none)
        let newHouse = HouseModel(name: houseName, description: houseDescription, users: [userReference])
        
        if let savedHouse = await CloudKitManager.shared.create(newHouse) {
            self.currentHouse = savedHouse
 
            guard let houseRecordID = savedHouse.recordID else { return }

            if let userRecord = await CloudKitManager.shared.fetchRecord(for: savedUser) {
                userRecord.parent = CKRecord.Reference(recordID: houseRecordID, action: .none)
                userRecord["house"] = CKRecord.Reference(recordID: houseRecordID, action: .none)
                _ = await CloudKitManager.shared.update(record: userRecord)
            }
            
            isLoading = false
            navigateToFourth = true
        } else {
            errorMessage = "Erro ao criar a casa."
            isLoading = false
        }
    }
    
    // MARK: - Fourth View
    func toggleRoomSelection(id: UUID) {
        if let index = availableRooms.firstIndex(where: { $0.id == id }) {
            availableRooms[index].isSelected.toggle()
        }
    }
    
    func addCustomRoom(name: String, color: RoomColor) {
        let newRoom = RoomDraft(name: name, symbol: "door.left.hand.closed", isSelected: true, color: color)
        let otherButtonIndex = availableRooms.count - 1
        availableRooms.insert(newRoom, at: otherButtonIndex)
    }
    
    @MainActor
    func saveSelectedRooms() async {
        guard let house = currentHouse, let houseID = house.recordID else { return }
        isLoading = true
        
        let selectedDrafts = availableRooms.filter { $0.isSelected && !$0.isAddButton }
        var savedRoomReferences: [CKRecord.Reference] = []
        let houseReference = CKRecord.Reference(recordID: houseID, action: .deleteSelf)
        
        for draft in selectedDrafts {
            let roomModel = RoomModel(name: draft.name, house: houseReference, color: draft.color)
            if let savedRoom = await CloudKitManager.shared.create(roomModel, parent: houseReference),
               let roomID = savedRoom.recordID {
                savedRoomReferences.append(CKRecord.Reference(recordID: roomID, action: .none))
            }
        }
        
        var updatedHouse = house
        updatedHouse.rooms = (updatedHouse.rooms ?? []) + savedRoomReferences
        let success = await CloudKitManager.shared.update(updatedHouse)
        
        if success {
            self.currentHouse = updatedHouse
            self.onboardingFinished = true 
        } else {
            errorMessage = "Erro ao atrelar cômodos."
        }
        
        isLoading = false
    }
}
