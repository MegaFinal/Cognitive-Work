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
    
    var stateMachine = OnboardingStateMachine()
    
    var isOnboardingSkipped: Bool = false
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
    
    var hasSelectedRooms: Bool {
        availableRooms.contains { $0.isSelected && !$0.isAddButton }
    }
    
    var selectedChores: [ChoreDTO] = []
    
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
            self.stateMachine.user = savedUser
            CloudKitManager.shared.setCurrentUser(savedUser)
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
            self.stateMachine.house = savedHouse
            
            guard let houseRecordID = savedHouse.recordID else { return }
            
            if let userRecord = await CloudKitManager.shared.fetchRecord(for: savedUser) {
                userRecord.parent = CKRecord.Reference(recordID: houseRecordID, action: .none)
                userRecord["house"] = CKRecord.Reference(recordID: houseRecordID, action: .none)
                _ = await CloudKitManager.shared.update(record: userRecord)
            }
            
            try? await CloudKitManager.shared.createSharedSubscription()
            
            isLoading = false
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
        guard let house = currentHouse else { return }
        isLoading = true
        
        let selectedDrafts = availableRooms.filter { $0.isSelected && !$0.isAddButton }
        var savedRooms: [RoomModel] = []
        
        for draft in selectedDrafts {
            let roomModel = RoomModel(name: draft.name,
                                      house: house.reference(action: .deleteSelf),
                                      color: draft.color)
            if let savedRoom = await CloudKitManager.shared.create(roomModel,parent: house.reference(action: .none)) {
                savedRooms.append(savedRoom)
            }
        }
        let success = await house.appendRoom(rooms: savedRooms)
        
        if success {
            self.currentHouse = house
        } else {
            errorMessage = "Erro ao atrelar cômodos."
        }
        
        isLoading = false
    }
    
    /// Fetches every user currently linked to ``currentHouse``.
    ///
    /// Used to display the members who have already joined while the house owner
    /// waits on the invite screen.
    @MainActor
    func fetchHouseUsers() async -> [UserModel] {
        guard let houseID = currentHouse?.recordID else { return [] }
        let reference = CKRecord.Reference(recordID: houseID, action: .none)
        let predicate = NSPredicate(format: "house == %@", reference)
        return await CloudKitManager.shared.fetchAll(UserModel.self, predicate: predicate)
    }
    
    @MainActor
    func fetchRooms() async -> [RoomModel] {
        guard let houseID = currentHouse?.recordID else { return [] }
        let reference = CKRecord.Reference(recordID: houseID, action: .deleteSelf)
        let predicate = NSPredicate(format: "house == %@", reference)
        return await CloudKitManager.shared.fetchAll(RoomModel.self, predicate: predicate)
    }
    
    /// Creates a `ChoreModel` for each chore the user selected, skipping any that
    /// another housemate already saved for the same room.
    ///
    /// Every resident walks through ``SelectChoresOnboardingView`` independently and picks
    /// from the same default chore list per room, so without this check the same chore would
    /// be duplicated once per person who selects it.
    func creatDefoultChores() async {
        isLoading = true
        for chore in selectedChores {
            guard let roomReference = chore.roomReference else { continue }
            
            let existing = await CloudKitManager.shared.fetchAll(
                ChoreModel.self,
                predicate: NSPredicate(format: "room == %@ AND name == %@", roomReference, chore.name)
            )
            
            guard existing.isEmpty else { continue }
            
            await CloudKitManager.shared.create(
                ChoreModel(
                    name: chore.name,
                    description: chore.description,
                    frequency: chore.frequency,
                    duration: chore.duration,
                    isPublic: true,
                    priorityTag: chore.priorityTag
                ),
                parent: chore.roomReference
            )
        }
        isLoading = false
    }
    
    func goToNextView() {
        stateMachine.next()
    }
    
    func goToPreviousView() {
        stateMachine.back()
    }
    
    func finishOnboarding() {
        isOnboardingSkipped = true
        stateMachine.resetProgress()
    }
    
    func setAvailableTimeToUser(daysOfWeekDTO: [DayOfWeekDTO]) async {
        isLoading = true
        var availableTime: [AvailableTimeModel] = []
        
        for dayOfWeek in daysOfWeekDTO {
            availableTime.append(
                AvailableTimeModel(
                    capacityMinutes: Int(dayOfWeek.freeTime.timeInHours) * 60,
                    day: Date()
                )
            )
        }
        await currentUser?.setAvailableTimes(availableTime)
        isLoading = false
    }
    
    func fetchHouse() async {
        currentHouse = try? await CloudKitManager.shared.fetchFirst(HouseModel.self)
    }

    /// Publishes the current user's profile into the house that was just joined via a
    /// CloudKit share invite.
    ///
    /// ``createUser()`` saves the profile into this device's own private zone, which is
    /// invisible to anyone else's account. This creates a second `UserModel` record — with
    /// the same profile data — directly inside the house's shared zone, links it to the house
    /// (`house` field) and appends it to the house's `users` list, so housemates (including
    /// the owner) can see this member. ``currentUser`` and the locally persisted "current
    /// user" record are updated to point at this new, house-linked record.
    ///
    /// - Requires ``currentUser`` to already exist (created via ``createUser()``).
    @MainActor
    func joinHouse() async {
        await fetchHouse()

        guard let house = currentHouse, let houseRecordID = house.recordID,
              let profile = currentUser
        else { return }

        isLoading = true
        errorMessage = nil

        let houseReference = CKRecord.Reference(recordID: houseRecordID, action: .none)
        let sharedUser = UserModel(
            name: profile.name,
            profilePicture: profile.profilePicture,
            tier: profile.tier,
            coins: profile.coins,
            points: profile.points,
            house: houseReference,
            couponLimit: profile.couponLimit
        )

        if let savedUser = await CloudKitManager.shared.create(sharedUser, zoneID: houseRecordID.zoneID) {
            await house.appendUsers([savedUser])
            self.currentUser = savedUser
            self.stateMachine.user = savedUser
            CloudKitManager.shared.setCurrentUser(savedUser)
        } else {
            errorMessage = "Erro ao entrar na casa."
        }

        isLoading = false
    }

    /// Fetches the current user's own profile record, used to re-hydrate ``currentUser``
    /// when onboarding resumes on a fresh launch (see ``restoreProgressIfNeeded()``).
    func fetchCurrentUser() async {
        currentUser = await CloudKitManager.shared.fetchMyUser()
    }

    /// Re-hydrates ``currentUser`` and ``currentHouse`` after the app relaunches mid-onboarding.
    ///
    /// ``OnboardingStateMachine`` persists which step the user is on, but ``currentUser`` and
    /// ``currentHouse`` live only in memory and are lost when the process ends. Steps past
    /// profile/house creation read those two properties directly, so without this they'd load
    /// a blank screen after a relaunch. Call once when ``Onboarding`` first appears.
    func restoreProgressIfNeeded() async {
        guard stateMachine.index > 0 else { return }

        if currentUser == nil {
            await fetchCurrentUser()
        }
        if currentHouse == nil {
            await fetchHouse()
        }
    }
}
