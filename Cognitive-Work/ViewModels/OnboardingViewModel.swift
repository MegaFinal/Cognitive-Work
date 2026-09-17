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
    var isCheckingAccount: Bool = true
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
        RoomDTO(name: "Quarto", symbol: "bed.double", color: .green),
        RoomDTO(name: "Sala de Estar", symbol: "sofa", color: .yellow),
        RoomDTO(name: "Área de Serviço", symbol: "washer", color: .purple),
        RoomDTO(name: "Cozinha", symbol: "cooktop", color: .orange),
        RoomDTO(name: "Banheiro", symbol: "toilet", color: .blue),
        RoomDTO(name: "Outro", symbol: "plus", isAddButton: true, color: .white)
    ]
    
    var hasSelectedRooms: Bool {
        availableRooms.contains { $0.isSelected && !$0.isAddButton }
    }
    
    var selectedChores: [ChoreDTO] = []
    
    var isScheduleReady: Bool = false
    
    /// Sync fix: re-entrancy guard for ``joinHouse()``, which can be triggered by the share
    /// notification and by the accept-link screen at the same time.
    private var isJoiningHouse = false
    
    /// Sync fix: re-entrancy guard for ``checkAndAdvanceIfScheduleReady()``, which is now
    /// driven by the initial load, CloudKit pushes, foreground events and a polling fallback.
    private var isCheckingSchedule = false
    
    /// Session-restore fix: `true` while `Onboarding` reloads the user and house after a
    /// relaunch. Screens are held back until it is `false`, so no step runs with empty state.
    var isRestoringSession: Bool = true
    
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
        
        // Session-restore fix: the photo is optional in the UI (the button only requires a
        // name), but the whole body used to be nested inside `if let imageData`, so a profile
        // without a photo was never created and no error was shown.
        let imageCKAsset = userProfilePicture?
            .jpegData(compressionQuality: 0.8)
            .flatMap { CloudKitManager.shared.createAsset(from: $0) }
        
        if let ownerRecordName = await CloudKitManager.shared.fetchCurrentUserRecordID()?.recordName {
            let newUser = UserModel(name: userName.isEmpty ? "Novo Morador" : userName, profilePicture: imageCKAsset, tier: .tier1, ownerRecordName: ownerRecordName)
            
            if let savedUser = await CloudKitManager.shared.create(newUser) {
                self.currentUser = savedUser
                self.stateMachine.user = savedUser
                // Session-restore fix: remember the profile so it can be read back directly
                // after the app is closed, without depending on a CloudKit query index.
                CloudKitManager.shared.setCurrentUser(savedUser)
            } else {
                errorMessage = CloudKitManager.shared.errorMessage ?? "Erro ao criar usuário."
            }
        } else {
            errorMessage = "Não foi possível acessar sua conta do iCloud. Verifique se você está conectado e tente novamente."
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
        // Session-restore fix: after a relaunch `currentUser` may not be loaded yet (or the
        // initial load failed). Try once more before reporting a missing profile.
        if currentUser == nil {
            await fetchCurrentUser()
        }
        
        guard let user = currentUser, let userRecordID = user.recordID else {
            errorMessage = "Seu perfil ainda não foi salvo. Volte e crie o perfil antes de criar a casa."
            return
        }
         
        isLoading = true
        errorMessage = nil
         
        // Clears the spinner on *every* exit, including the early returns below. Without it,
        // any of those returns leaves the button spinning forever with no way out.
        defer { isLoading = false }
         
        // Pre-compute the house's recordID and zoneID locally to avoid a sequential network round-trip.
        let zoneID = CloudKitManager.shared.houseZoneID
        let houseRecordID = CKRecord.ID(recordName: UUID().uuidString, zoneID: zoneID)
        let houseCascadeRef = CKRecord.Reference(recordID: houseRecordID, action: .none)
        
        // Construct the HouseModel and its underlying CKRecord.
        let userReference = CKRecord.Reference(recordID: userRecordID, action: .none)
        let newHouse = HouseModel(name: houseName, description: houseDescription, users: [userReference])
        let houseRecord = CKRecord(recordType: HouseModel.recordType, recordID: houseRecordID)
        newHouse.populate(record: houseRecord)
         
        // Prepare the user copy record and map all properties.
        let assetCopy = user.profilePicture.flatMap { try? duplicateCKAsset($0) }
        let ownerRecordName = await CloudKitManager.shared.fetchCurrentUserRecordID()?.recordName ?? "error to fetch users id"
         
        let userCopy = UserModel(
            name: user.name,
            profilePicture: assetCopy,
            tier: user.tier,
            coins: user.coins,
            points: user.points,
            badges: user.badgesReference,
            tasks: user.choresReference,
            availableTime: user.availableTimeReference,
            house: houseCascadeRef,
            coupons: user.couponsReference,
            couponLimit: user.couponLimit,
            ownerRecordName: ownerRecordName
        )
         
        let copyRecordID = CloudKitManager.shared.houseUserRecordID(
            for: userRecordID,
            inHouseZone: zoneID
        )
        let userCopyRecord = CKRecord(recordType: UserModel.recordType, recordID: copyRecordID)
        userCopy.populate(record: userCopyRecord)
        userCopyRecord.parent = houseCascadeRef
         
        // Use batchSave to upload both the house and the user copy in a single network request.
        let success = await CloudKitManager.shared.batchSave(
            records: [houseRecord, userCopyRecord],
            zoneID: zoneID
        )
         
        if success {
            let savedHouse = HouseModel(record: houseRecord)
            self.currentHouse = savedHouse
            self.stateMachine.house = savedHouse
             
            let savedUserCopy = UserModel(record: userCopyRecord)
            self.currentUser = savedUserCopy
            self.stateMachine.user = savedUserCopy
             
            try? await CloudKitManager.shared.createSharedSubscription()
        } else {
            errorMessage = CloudKitManager.shared.errorMessage ?? "Erro ao criar a casa."
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
        let newRoom = RoomDTO(name: name, symbol: "lamp.table", isSelected: true, color: color)
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
        guard let house = currentHouse,
              let zoneID = house.recordID?.zoneID else { return }
        isLoading = true
        
        let selectedDrafts = availableRooms.filter { $0.isSelected && !$0.isAddButton }
        let houseReference = house.reference(action: .deleteSelf)
        let parentReference = house.reference(action: .none)
        
        var roomModels = selectedDrafts.map { draft in
            RoomModel(name: draft.name,symbol: draft.symbol, house: houseReference, color: draft.color)
        }
        
        let roomToRepresentChoresToAllHome = RoomModel(
            name: "Casa",
            symbol: "house",
            house: houseReference,
            color: .orange
        )
        roomModels.append(roomToRepresentChoresToAllHome)
        
        var recordsToSave: [CKRecord] = []
        for roomModel in roomModels {
            let record = CKRecord(recordType: RoomModel.recordType, zoneID: zoneID)
            roomModel.populate(record: record)
            
            record.parent = parentReference
            
            recordsToSave.append(record)
        }
        
        let successBatch = await CloudKitManager.shared.batchSave(records: recordsToSave, zoneID: zoneID)
        
        if successBatch {
            for (index, record) in recordsToSave.enumerated() {
                roomModels[index].recordID = record.recordID
            }
            
            let successAppend = await house.appendRoom(rooms: roomModels)
            if successAppend {
                self.currentHouse = house
            } else {
                errorMessage = CloudKitManager.shared.errorMessage ?? "Erro ao atrelar cômodos."
            }
        } else {
            errorMessage = CloudKitManager.shared.errorMessage ?? "Erro ao salvar cômodos."
        }
        
        isLoading = false
    }
    
    /// Fetches every user currently linked to ``currentHouse``.
    ///
    /// Used to display the members who have already joined while the house owner
    /// waits on the invite screen.
    @MainActor
    func fetchHouseUsers() async -> [UserModel] {
        await CloudKitManager.shared.fetchHouseUsers(of: currentHouse)
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
    func createDefaultChores() async {
        isLoading = true
        
        guard let rooms = currentHouse?.room,
              let houseRecordID = currentHouse?.recordID else {
            isLoading = false
            return
        }
        
        let zoneID = houseRecordID.zoneID
        let parentReference = CKRecord.Reference(recordID: houseRecordID, action: .none)
        
        let existingChores = await CloudKitManager.shared.fetchAll(
            ChoreModel.self,
            predicate: NSPredicate(format: "room != nil")
        )
        
        let existingSet = Set(existingChores.map {
            "\($0.roomReference?.recordID.recordName ?? "")_\($0.name)"
        })
        
        var recordsToCreate: [CKRecord] = []
        
        for choreDTO in selectedChores {
            guard let choreRoom = rooms.first(where: { $0.name == choreDTO.roomDTO.name }),
                  let roomRecordID = choreRoom.recordID else {
                continue
            }
            
            let roomReference = CKRecord.Reference(recordID: roomRecordID, action: .none)
            let uniqueKey = "\(roomRecordID.recordName)_\(choreDTO.name)"
            
            if existingSet.contains(uniqueKey) {
                continue
            }
            
            let choreModel = ChoreModel(
                name: choreDTO.name,
                description: choreDTO.description,
                frequency: choreDTO.frequency,
                duration: choreDTO.duration,
                isPublic: true,
                priorityTag: choreDTO.priorityTag,
                roomReference: roomReference
            )
            
            let record = CKRecord(recordType: ChoreModel.recordType, zoneID: zoneID)
            choreModel.populate(record: record)
            record.parent = parentReference
            
            recordsToCreate.append(record)
        }
        
        if !recordsToCreate.isEmpty {
            let success = await CloudKitManager.shared.batchSave(records: recordsToCreate, zoneID: zoneID)
            if !success {
                errorMessage = CloudKitManager.shared.errorMessage ?? "Erro ao criar tarefas padrão."
            }
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
    
    /// Saves the free time chosen during onboarding on the current user's in-house record.
    ///
    /// ## Sync fix
    /// - Returns whether the write reached CloudKit, so the screen only advances when the
    ///   admin can actually see the data (it used to advance even when nothing was saved).
    /// - `Int(timeInHours) * 60` truncated *before* multiplying, so "Até 30 minutos" became
    ///   `Int(0.5) * 60 == 0`. `setAvailableTimes` skips zero-capacity slots, which left the
    ///   guest with no availability at all and the admin's screen showing them as pending.
    /// - After a relaunch, ``currentUser`` could be the *private* profile (invisible to the
    ///   admin). The in-house record is resolved first so the write lands where the admin reads.
    @MainActor
    @discardableResult
    func setAvailableTimeToUser(daysOfWeekDTO: [DayOfWeekDTO]) async -> Bool {
        isLoading = true
        defer { isLoading = false }
        
        let availableTimes = daysOfWeekDTO.map { dayOfWeek in
            AvailableTimeModel(
                // Sync fix: multiply first, then round (30 min -> 30, not 0).
                capacityMinutes: Int((dayOfWeek.freeTime.timeInHours * 60).rounded()),
                day: Date()
            )
        }
        
        // Session-restore fix: reload the session if it was lost when the app was closed.
        await reloadSessionIfNeeded()
        
        // Sync fix: make sure we write to the record housemates can read.
        if let user = currentUser, !CloudKitManager.shared.isHouseUser(user),
           let houseUser = await CloudKitManager.shared.fetchMyHouseUser() {
            currentUser = houseUser
            stateMachine.user = houseUser
        }
        
        guard let user = currentUser,
              await user.setAvailableTimes(availableTimes) else {
            errorMessage = CloudKitManager.shared.errorMessage ?? "Não foi possível salvar seus horários. Tente novamente."
            return false
        }
        return true
    }
    
    /// Loads the free time currently saved for the user, keyed by the row index used in
    /// `SelectFreeTimeOnboardingView.weekOrder` (0 = Monday … 6 = Sunday).
    ///
    /// Used when the screen is opened from the profile to edit existing values.
    @MainActor
    func fetchCurrentFreeTime() async -> [Int: FreeTimeEnum] {
        await reloadSessionIfNeeded()
        guard let user = currentUser else { return [:] }
        
        let calendar = Calendar.current
        var minutesByIndex: [Int: Int] = [:]
        
        for slot in await user.availableTime {
            let index = (calendar.component(.weekday, from: slot.day) + 5) % 7
            minutesByIndex[index] = max(minutesByIndex[index] ?? 0, slot.capacityMinutes)
        }
        
        return minutesByIndex.mapValues { FreeTimeEnum(minutes: $0) }
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
    /// the owner) can see this member. ``currentUser`` is updated to point at this new,
    /// house-linked record; the *persisted* current-user record keeps pointing at the private
    /// profile, which is the anchor ``CloudKitManager/fetchMyHouseUser()`` derives this copy's
    /// `recordID` from.
    ///
    /// - Requires ``currentUser`` to already exist (created via ``createUser()``).
    ///
    /// ## Sync fix
    /// - Returns `true` only when the in-house record exists, so callers stop advancing the
    ///   flow for a guest that was never actually published to the house (the admin could
    ///   never see their free time).
    /// - Right after `CKAcceptSharesOperation` finishes, the shared zone is not always listed
    ///   yet (eventual consistency), so `fetchFirst(HouseModel.self)` could return `nil` and the
    ///   method bailed out silently. The house lookup is now retried briefly.
    /// - The profile picture is no longer a hard requirement: a guest without a photo used to
    ///   hit the `guard` and return with no record and no error (the owner path in
    ///   `createHouseAndLinkUser()` already treats the photo as optional).
    /// - `Onboarding`'s `.didAcceptShare` handler and `WaitAcceptLinkOnboardingView.task` can
    ///   both call this at the same time. A re-entrancy guard and an "already published" check
    ///   make the call idempotent instead of racing two saves of the same record ID.
    @MainActor
    func joinHouse() async -> Bool {
        // Sync fix: ignore overlapping calls; the one already running will finish the join.
        guard !isJoiningHouse else { return false }
        isJoiningHouse = true
        defer { isJoiningHouse = false }
        
        async let houseTask = resolveJoinedHouse()
        async let ownerIDTask = CloudKitManager.shared.fetchCurrentUserRecordID()
        
        currentHouse = await houseTask
        let ownerRecordName = (await ownerIDTask)?.recordName ?? "error fetch user's ID"
        
        guard let house = currentHouse, let houseRecordID = house.recordID,
              let profile = currentUser, let profileRecordID = profile.recordID
        else {
            errorMessage = "Não foi possível encontrar a casa do convite. Tente abrir o link novamente."
            isLoading = false
            return false
        }
        
        isLoading = true
        errorMessage = nil
        
        let houseReference = CKRecord.Reference(recordID: houseRecordID, action: .none)
        // Sync fix: the photo is optional, mirroring `createHouseAndLinkUser()`.
        let assetCopy = profile.profilePicture.flatMap { try? duplicateCKAsset($0) }
        
        let sharedUser = UserModel(
            name: profile.name,
            profilePicture: assetCopy,
            tier: profile.tier,
            coins: profile.coins,
            points: profile.points,
            house: houseReference,
            couponLimit: profile.couponLimit,
            ownerRecordName: ownerRecordName
        )
        
        let sharedUserID = CloudKitManager.shared.houseUserRecordID(
            for: profileRecordID,
            inHouseZone: houseRecordID.zoneID
        )
        
        async let subTask = CloudKitManager.shared.createSharedSubscription()
        
        // Sync fix: if this device already published its in-house record (resumed session,
        // or a concurrent call that finished first), reuse it instead of failing on a
        // duplicate record ID.
        let existingUser = await CloudKitManager.shared.fetchRecordsByRecordReference(
            for: UserModel.self,
            recordReferences: [CKRecord.Reference(recordID: sharedUserID, action: .none)]
        )?.first
        
        var savedUser = existingUser
        if savedUser == nil {
            savedUser = await CloudKitManager.shared.create(sharedUser, id: sharedUserID, parent: house.reference(action: .none))
            if let savedUser {
                await house.appendUsers([savedUser])
            }
        }
        
        // Sync fix: always wait for the subscription, so the guest is listening for the
        // admin's division before it moves on to the waiting screen.
        _ = try? await subTask
        
        isLoading = false
        
        if let savedUser {
            self.currentUser = savedUser
            self.stateMachine.user = savedUser
            return true
        } else {
            errorMessage = CloudKitManager.shared.errorMessage ?? "Erro ao entrar na casa."
            return false
        }
    }
    
    /// Resolves the house that was just joined through a share.
    ///
    /// Sync fix helper for ``joinHouse()``: the shared zone may take a moment to become visible
    /// after the share is accepted, so an empty result is retried a few times before giving up.
    private func resolveJoinedHouse() async -> HouseModel? {
        let attempts = 4
        for attempt in 0..<attempts {
            if let house = try? await CloudKitManager.shared.fetchFirst(HouseModel.self) {
                return house
            }
            // 1s, 2s, 3s back-off between attempts (no wait after the last one).
            if attempt < attempts - 1 {
                try? await Task.sleep(for: .seconds(attempt + 1))
            }
        }
        return nil
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
    @MainActor
    func restoreProgressIfNeeded() async {
        guard stateMachine.index > 0 else { return }
        await reloadSessionIfNeeded()
    }
    
    /// Loads ``currentUser`` and ``currentHouse`` (and mirrors them into ``stateMachine``)
    /// whenever either is missing.
    ///
    /// ## Session-restore fix
    /// Extracted from ``restoreProgressIfNeeded()`` so screens that write data can call it
    /// right before writing. Two gaps were also closed:
    /// - `stateMachine.house` was never restored, so `stateMachine.isOwner` was `nil` after a
    ///   relaunch — the admin's texts changed and `FortnightlyScheduleView` received
    ///   `shouldGenerate: false`, never generating the division.
    /// - `stateMachine.user` was never restored either.
    @MainActor
    func reloadSessionIfNeeded() async {
        if currentUser == nil {
            await fetchCurrentUser()
        }
        if currentHouse == nil {
            await fetchHouse()
        }
        
        // Sync fix: `fetchCurrentUser()` returns the *private* profile. Once a house exists,
        // every later step (free time, waiting screens) must work with the in-house copy,
        // otherwise a relaunch in the middle of onboarding made the guest's free time land on a
        // record the admin can't see.
        if currentHouse != nil,
           let user = currentUser, !CloudKitManager.shared.isHouseUser(user),
           let houseUser = await CloudKitManager.shared.fetchMyHouseUser() {
            currentUser = houseUser
            stateMachine.user = houseUser
        }
        
        // Session-restore fix: keep the state machine in step with the restored records.
        if let currentUser { stateMachine.user = currentUser }
        if let currentHouse { stateMachine.house = currentHouse }
    }
    
    private func duplicateCKAsset(_ asset: CKAsset) throws -> CKAsset? {
        guard let origem = asset.fileURL else { return nil }
        
        let destino = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        
        try FileManager.default.copyItem(at: origem, to: destino)
        return CKAsset(fileURL: destino)
    }
    
    // MARK: - Algorithm

    /// Advances the guest past the waiting screen once the admin's division exists.
    ///
    /// ## Sync fix
    /// This is now called from several triggers (initial load, CloudKit push, app returning
    /// to the foreground, polling fallback). The re-entrancy guard keeps overlapping calls from
    /// running concurrent queries, and the step is re-checked *after* the network call because
    /// the flow may have moved on while it was in flight — so the guest can never advance twice.
    @MainActor
    func checkAndAdvanceIfScheduleReady() async {
        guard !isCheckingSchedule else { return }
        isCheckingSchedule = true
        defer { isCheckingSchedule = false }
        
        let assignments = await CloudKitManager.shared.fetchAll(RecurrentAssignmentModel.self)
        let scheduleIsReady = !assignments.isEmpty
        guard scheduleIsReady else { return }

        isScheduleReady = true
        guard stateMachine.current == .waitAdminScheduling else { return }
        goToNextView()
    }
    
    // MARK: - Auto Login / Initial Validation
    
    /// Checks if the current iCloud user already possesses an account within the application.
    ///
    /// - If only the profile exists: resets the state machine flow to `.notDefined` and jumps
    ///   directly to the home creation/entry step (`.createOrEnterHome`), bypassing welcome and
    ///   profile creation. The flow is corrected to `.houseCreator`/`.invitedWithProfile` once the
    ///   user picks "Criar" or "Entrar" on that screen.
    @MainActor
    func checkExistingAccount() async {
        
        guard !isLoading else { return }
        
        isCheckingAccount = true
        isLoading = true
        
        defer {
            isCheckingAccount = false
            isLoading = false
        }
        
        async let fetchedUser = CloudKitManager.shared.fetchMyUser()
        async let fetchedHouse = try? await CloudKitManager.shared.fetchFirst(HouseModel.self)
        
        let user = await fetchedUser
        let house = await fetchedHouse
        
        // Session-restore fix: if onboarding was interrupted mid-flow, resume it instead of
        // treating the person as a returning user. Before this, an admin who closed the app
        // after creating the house was sent straight to the main app (rooms, chores and
        // free time never configured), and a guest whose house fetch briefly failed was thrown
        // back to "create or enter a house". `restoreProgressIfNeeded()` takes it from here.
        let hasOnboardingInProgress = stateMachine.flow != .notDefined && stateMachine.index > 0
        if hasOnboardingInProgress {
            if let user { currentUser = user; stateMachine.user = user }
            if let house { currentHouse = house; stateMachine.house = house }
            return
        }
        
        if let existingUser = user {
            self.currentUser = existingUser
            self.stateMachine.user = existingUser
            
            if let existingHouse = house {
                self.currentHouse = existingHouse
                self.stateMachine.house = existingHouse
                self.finishOnboarding()
            } else {
                stateMachine.flow = .notDefined
                if let targetIndex = stateMachine.steps.firstIndex(of: .createOrEnterHome) {
                    stateMachine.jumpToStep(index: targetIndex)
                }
            }
        }
    }
}
