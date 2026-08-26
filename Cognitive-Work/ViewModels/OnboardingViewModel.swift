//
//  OnboardingViewModel.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 19/08/26.
//

import SwiftUI
import CloudKit

/// The shared state and business logic for the entire onboarding flow.
///
/// `OnboardingViewModel` is created once by ``FirstOnboardingView`` and injected into
/// the SwiftUI environment, so every subsequent onboarding screen reads and mutates the same instance.
///
/// It owns:
/// - Navigation flags that drive `navigationDestination` pushes between steps
/// - The in-progress ``currentUser`` and ``currentHouse`` CloudKit records
/// - The list of candidate rooms (``availableRooms``) offered during room selection
/// - Loading/error state surfaced by the various onboarding screens
@Observable
class OnboardingViewModel {
    /// The name entered by the user for their profile
    var userName: String = ""
    
    var userProfilePicture: UIImage?
    /// The name of the house being created
    var houseName: String = "Minha Casa"
    /// A short description of the house being created
    var houseDescription: String = "Organização Doméstica"
    
    /// Whether an asynchronous CloudKit operation is currently in progress
    var isLoading: Bool = false
    /// A message describing the most recent error, if any
    var errorMessage: String? = nil

    var navigateToSecond: Bool = false
    var navigateToThird: Bool = false
    var navigateToFourth: Bool = false
    var onboardingFinished: Bool = false
    
    /// The CloudKit user record created during onboarding
    var currentUser: UserModel?
    /// The CloudKit house record created during onboarding
    var currentHouse: HouseModel?
    
    /// The default set of room choices offered to the user, including the trailing "add custom room" entry
    var availableRooms: [RoomDTO] = [
        RoomDTO(name: "Quarto", symbol: "bed.double"),
        RoomDTO(name: "Sala de Estar", symbol: "sofa"),
        RoomDTO(name: "Área de Serviço", symbol: "washer"),
        RoomDTO(name: "Cozinha", symbol: "cooktop"),
        RoomDTO(name: "Banheiro", symbol: "toilet"),
        RoomDTO(name: "Outro", symbol: "plus", isAddButton: true)
    ]
    
    // MARK: - CloudKit
    /// Creates the user's profile record in CloudKit and advances to the "join or create a house" step
    ///
    /// Uses ``userName`` (falling back to a default name if empty) to build a new
    /// `UserModel`. On success, stores the saved record in ``currentUser`` and sets
    /// ``navigateToThird`` to `true`. On failure, populates ``errorMessage``.
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
    
    /// Creates a new house record and links the current user to it, then advances to room selection
    ///
    /// - Requires ``currentUser`` to already be set (created via ``createUser()``)
    /// - Creates a new `HouseModel` referencing the user, saves it, sets it as the
    /// user record's CloudKit parent, and updates the user record
    /// - On success, stores the saved house in ``currentHouse`` and sets ``navigateToFourth`` to `true`
    /// - On failure, populates ``errorMessage``
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
    /// Toggles the selection state of the room dto with the given identifier
    ///
    /// - Parameter id: The `RoomDTO.id` of the room to toggle
    func toggleRoomSelection(id: UUID) {
        if let index = availableRooms.firstIndex(where: { $0.id == id }) {
            availableRooms[index].isSelected.toggle()
        }
    }
    
    /// Inserts a new, pre-selected custom room dto just before the "add room" entry
    ///
    /// - Parameters:
    ///   - name: The display name for the new room
    ///   - color: The accent color chosen for the new room
    func addCustomRoom(name: String, color: RoomColor) {
        let newRoom = RoomDTO(name: name, symbol: "door.left.hand.closed", isSelected: true, color: color)
        let otherButtonIndex = availableRooms.count - 1
        availableRooms.insert(newRoom, at: otherButtonIndex)
    }
    
    /// Persists all selected rooms to CloudKit as children of the current house
    ///
    /// Filters ``availableRooms`` down to selected, non-add-button drafts, creates a
    /// `RoomModel` for each under the current house, and appends the resulting
    /// references to the house's `rooms` list before saving the updated house.
    ///
    /// - On success, sets ``onboardingFinished`` to `true`.
    /// - Requires ``currentHouse`` to already be set.
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
