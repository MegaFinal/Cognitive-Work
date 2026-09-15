//
//  OnboardingViewModel.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 19/08/26.
//

import SwiftUI
import CloudKit

/// State and CloudKit work shared by every screen of the onboarding flow.
///
/// ## Onboarding audit — what changed and why
///
/// - ``createUser()`` no longer requires a profile picture. The whole body used to sit inside
///   `if let imageData = userProfilePicture?.jpegData(...)`, so a person who skipped the photo
///   (the button only requires a name) created **no record at all** and got **no error** —
///   "Continuar" simply did nothing. It also now calls `CloudKitManager.setCurrentUser(_:)`, so
///   the profile survives a relaunch without depending on a CloudKit query index.
/// - ``createHouseAndLinkUser()`` repairs its own precondition instead of dead-ending. It used
///   to `guard let user = currentUser` and, on failure, show an alert on a screen with no back
///   button — the "I tap create house and it does not work" report.
/// - ``saveSelectedRooms()`` saves rooms serially. The previous `withTaskGroup` captured the
///   non-`Sendable`, `@Observable` `HouseModel` in several concurrent child tasks and let them
///   all write `CloudKitManager.errorMessage`, which SwiftUI observes — a data race on the
///   observation registrar and the most plausible code-visible cause of the crash reported right
///   after house creation.
/// - ``setAvailableTimeToUser(daysOfWeekDTO:)`` fixes an integer truncation that silently
///   discarded availability: `Int(0.5) * 60 == 0`, so "Até 30 minutos" produced **zero**
///   capacity, `UserModel.setAvailableTimes(_:forWeeks:)` skipped every slot, and the member was
///   counted as *pending* by the admin's gate forever. It now reports success so the UI can
///   refuse to advance when nothing was saved.
/// - ``joinHouse()`` derives the public profile from the **private** record and is idempotent,
///   fixing the `"…-house-house"` record name described on
///   ``CloudKitManager/houseUserRecordID(for:inHouseZone:)``.
/// - ``checkExistingAccount()`` and ``restoreProgressIfNeeded()`` keep `stateMachine.user` and
///   `stateMachine.house` in sync. `restoreProgressIfNeeded()` used to populate only the view
///   model, leaving `stateMachine.house` `nil` — which made `stateMachine.isOwner` return `nil`,
///   which made `Onboarding.swift` pass `shouldGenerate: false`, which meant **the admin reached
///   the schedule screen and never generated the division**.
/// - Readiness and membership reads have index-free fallbacks, so a missing *Queryable* index in
///   the CloudKit schema can no longer masquerade as "nothing exists yet".
@Observable
class OnboardingViewModel {
    var userName: String = ""
    var userProfilePicture: UIImage?
    var houseName: String = "Minha Casa"
    var houseDescription: String = "Organização Doméstica"

    var isLoading: Bool = false
    var isCheckingAccount: Bool = true
    var errorMessage: String? = nil

    var stateMachine = OnboardingStateMachine()

    var isOnboardingSkipped: Bool = false
    var currentUser: UserModel?
    var currentHouse: HouseModel?

    /// The device's private profile, kept separately from ``currentUser``.
    ///
    /// - Note: **Onboarding fix:** ``currentUser`` legitimately switches between the private
    ///   profile and the in-house copy depending on how far the flow got, but
    ///   ``CloudKitManager/houseUserRecordID(for:inHouseZone:)`` must always be fed the *private*
    ///   record. Holding both removes the ambiguity that produced double-suffixed record names.
    var privateUser: UserModel?

    /// Whether this device ever created a profile, even if it cannot be read right now.
    ///
    /// - Note: **Onboarding fix:** lets `CreateOrEnterHouseOnboardingView` tell "no profile yet"
    ///   (send the person back to create one) apart from "a profile exists but iCloud is
    ///   unreachable" (ask them to retry), instead of dead-ending on both.
    var hasStoredProfile: Bool {
        CloudKitManager.shared.storedCurrentUserRecordName != nil
    }

    var availableRooms: [RoomDTO] = [
        RoomDTO(name: "Quarto", symbol: "bed.double", color: .green),
        RoomDTO(name: "Sala de Estar", symbol: "sofa", color: .yellow),
        RoomDTO(name: "Área de Serviço", symbol: "washer", color: .purple),
        RoomDTO(name: "Cozinha", symbol: "cooktop", color: .orange),
        RoomDTO(name: "Banheiro", symbol: "toilet", color: .blue),
        RoomDTO(name: "Outro", symbol: "plus", isAddButton: true, color: .red)
    ]

    var hasSelectedRooms: Bool {
        availableRooms.contains { $0.isSelected && !$0.isAddButton }
    }

    var selectedChores: [ChoreDTO] = []
    var isScheduleReady: Bool = false

    // MARK: - CloudKit

    /// Creates the device's private profile and remembers it locally.
    ///
    /// - Note: **Onboarding fix:** the picture is optional again, the failure path now sets
    ///   ``errorMessage`` for every branch, and the saved record is handed to
    ///   ``CloudKitManager/setCurrentUser(_:)`` so a relaunch can find it by ID.
    @MainActor
    func createUser() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        guard let ownerRecordName = await CloudKitManager.shared.fetchCurrentUserRecordID()?.recordName else {
            errorMessage = "Não conseguimos acessar sua conta do iCloud. Verifique se você está conectado nos Ajustes do iPhone."
            return
        }

        // The picture is optional: `jpegData` returning nil must not stop the profile from
        // being created.
        let imageCKAsset = userProfilePicture
            .flatMap { $0.jpegData(compressionQuality: 0.8) }
            .flatMap { CloudKitManager.shared.createAsset(from: $0) }

        let newUser = UserModel(
            name: userName.isEmpty ? "Novo Morador" : userName,
            profilePicture: imageCKAsset,
            tier: .tier1,
            ownerRecordName: ownerRecordName
        )

        guard let savedUser = await CloudKitManager.shared.create(newUser) else {
            errorMessage = CloudKitManager.shared.errorMessage ?? "Erro ao criar usuário."
            return
        }

        // Persisting the record name is what makes the profile survive a relaunch without
        // relying on the `ownerRecordName` query index being configured in CloudKit.
        CloudKitManager.shared.setCurrentUser(savedUser)

        self.privateUser = savedUser
        self.currentUser = savedUser
        self.stateMachine.user = savedUser
    }

    func updateProfileImage(_ image: UIImage) {
        userProfilePicture = image
    }

    /// Creates the house and saves the owner's public copy inside it.
    ///
    /// - Note: **Onboarding fix:** when ``currentUser`` is missing the method now tries to
    ///   recover the profile from CloudKit before giving up, and the error it reports
    ///   distinguishes "you never created a profile" from "we could not reach iCloud". It also
    ///   returns early (successfully) when a house already exists, so tapping the button twice —
    ///   or resuming onto this screen after the house was already created — cannot produce a
    ///   second house.
    @MainActor
    func createHouseAndLinkUser() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        // Resuming onto this screen with a house already created must not create another one.
        if currentHouse == nil {
            await fetchHouse()
        }

        if let existingHouse = currentHouse {
            await adoptHouse(existingHouse)
            return
        }

        // Self-healing precondition: the profile may simply not be loaded into memory yet.
        if privateUser == nil {
            privateUser = await CloudKitManager.shared.fetchMyUser()
        }

        guard let user = privateUser ?? currentUser, let userRecordID = user.recordID else {
            errorMessage = hasStoredProfile
            ? "Não conseguimos carregar seu perfil do iCloud agora. Verifique sua conexão e tente novamente."
            : "Seu perfil ainda não foi salvo. Volte e crie o perfil antes de criar a casa."
            return
        }

        let userReference = CKRecord.Reference(recordID: userRecordID, action: .none)
        let newHouse = HouseModel(name: houseName, description: houseDescription, users: [userReference])

        if let savedHouse = await CloudKitManager.shared.create(newHouse) {
            self.currentHouse = savedHouse
            self.stateMachine.house = savedHouse

            guard let houseRecordID = savedHouse.recordID else {
                errorMessage = "A casa foi criada, mas o CloudKit não devolveu o identificador dela."
                return
            }

            // 🚀 CRITICAL: The parent hierarchy MUST use .deleteSelf to be recognized by CKShare
            let houseCascadeRef = CKRecord.Reference(recordID: houseRecordID, action: .deleteSelf)
            let assetCopy = user.profilePicture.flatMap { try? duplicateCKAsset($0) }
            let ownerRecordName = await CloudKitManager.shared.fetchCurrentUserRecordID()?.recordName ?? "error fetch user's ID"

            let userCopy = UserModel(
                name: user.name ,
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
                inHouseZone: houseRecordID.zoneID
            )

            let savedUserCopy = await CloudKitManager.shared.create(
                userCopy,
                id: copyRecordID,
                parent: houseCascadeRef
            )

            if let savedUserCopy {
                self.currentUser = savedUserCopy
                self.stateMachine.user = savedUserCopy
            } else {
                // Without the public copy the owner is invisible to the scheduler and to the
                // free-time gate, so this must not pass silently.
                errorMessage = CloudKitManager.shared.errorMessage
                ?? "A casa foi criada, mas não conseguimos salvar seu perfil dentro dela."
            }

            try? await CloudKitManager.shared.createSharedSubscription()

        } else {
            errorMessage = CloudKitManager.shared.errorMessage ?? "Erro ao criar a casa."
        }
    }

    /// Adopts an already existing house as the current one, loading the public copy with it.
    ///
    /// - Note: **Onboarding fix:** keeps ``currentHouse``, ``currentUser`` and the state machine's
    ///   mirrors of both in agreement. `stateMachine.house` being `nil` is what silently turned
    ///   the admin into a non-owner on resumed sessions.
    @MainActor
    private func adoptHouse(_ house: HouseModel) async {
        self.currentHouse = house
        self.stateMachine.house = house

        if let houseUser = await CloudKitManager.shared.fetchMyHouseUser(in: house) {
            self.currentUser = houseUser
            self.stateMachine.user = houseUser
        }
    }

    // MARK: - Fourth View
    func toggleRoomSelection(id: UUID) {
        if let index = availableRooms.firstIndex(where: { $0.id == id }) {
            availableRooms[index].isSelected.toggle()
        }
    }

    func addCustomRoom(name: String, color: RoomColor) {
        let newRoom = RoomDTO(name: name, symbol: "door.left.hand.closed", isSelected: true, color: color)
        let otherButtonIndex = availableRooms.count - 1
        availableRooms.insert(newRoom, at: otherButtonIndex)
    }

    /// Persists the rooms the user selected and links them to the house.
    ///
    /// - Note: **Onboarding fix:** the rooms are saved one after another instead of inside a
    ///   `withTaskGroup`. The concurrent version captured `house` — a non-`Sendable`,
    ///   `@Observable` class — in every child task and let all of them write
    ///   `CloudKitManager.errorMessage` while SwiftUI was observing it. Room creation is a handful
    ///   of records on a screen that already shows a spinner, so the parallelism bought very
    ///   little and cost determinism.
    @MainActor
    func saveSelectedRooms() async {
        guard let house = currentHouse else {
            errorMessage = "Não encontramos sua casa para salvar os cômodos."
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let selectedDrafts = availableRooms.filter { $0.isSelected && !$0.isAddButton }

        let roomToRepresentChoresToAllHome = RoomModel(name: "Casa",
                                                       house: house.reference(action: .deleteSelf),
                                                       color: .orange)

        var savedRooms: [RoomModel] = []

        for draft in selectedDrafts {
            let roomModel = RoomModel(name: draft.name,
                                      house: house.reference(action: .deleteSelf),
                                      color: draft.color)

            // 🚀 CRITICAL: Parent action must be .deleteSelf
            if let savedRoom = await CloudKitManager.shared.create(
                roomModel,
                parent: house.reference(action: .deleteSelf)
            ) {
                savedRooms.append(savedRoom)
            }
        }

        if let savedDefault = await CloudKitManager.shared.create(roomToRepresentChoresToAllHome, parent: house.reference(action: .deleteSelf)) {
            savedRooms.append(savedDefault)
        }

        guard !savedRooms.isEmpty else {
            errorMessage = CloudKitManager.shared.errorMessage ?? "Erro ao criar os cômodos."
            return
        }

        let success = await house.appendRoom(rooms: savedRooms)

        if success {
            self.currentHouse = house
        } else {
            errorMessage = CloudKitManager.shared.errorMessage ?? "Erro ao atrelar cômodos."
        }
    }

    @MainActor
    func fetchHouseUsers() async -> [UserModel] {
        await fetchHouseMembers()
    }

    /// Every member of the current house, with an index-free fallback.
    ///
    /// - Note: **Onboarding fix:** `CloudKitManager.fetchHouseUsers(of:)` runs a `CKQuery`
    ///   filtered on the `house` reference field. If that field is not marked *Queryable* in the
    ///   CloudKit schema the query throws, the error is swallowed, and the caller gets `[]` — the
    ///   admin's waiting screen then shows no members at all, or treats everyone as pending. The
    ///   zone scan below answers the same question without any schema requirement.
    @MainActor
    func fetchHouseMembers() async -> [UserModel] {
        if currentHouse == nil {
            await fetchHouse()
        }

        guard let house = currentHouse, let houseRecordID = house.recordID else { return [] }

        let queried = await CloudKitManager.shared.fetchHouseUsers(of: house)
        if !queried.isEmpty { return queried }

        return await CloudKitManager.shared
            .fetchHouseRecords(UserModel.self, of: house)
            .filter { $0.houseReference?.recordID == houseRecordID }
    }

    @MainActor
    func fetchRooms() async -> [RoomModel] {
        guard let houseID = currentHouse?.recordID else { return [] }
        let reference = CKRecord.Reference(recordID: houseID, action: .deleteSelf)
        let predicate = NSPredicate(format: "house == %@", reference)
        let queried = await CloudKitManager.shared.fetchAll(RoomModel.self, predicate: predicate)

        if !queried.isEmpty { return queried }

        // Onboarding fix: same index-free fallback as `fetchHouseMembers()`.
        guard let house = currentHouse else { return [] }
        return await CloudKitManager.shared
            .fetchHouseRecords(RoomModel.self, of: house)
            .filter { $0.houseReference?.recordID == houseID }
    }

    func createDefaultChores() async {
        isLoading = true
        defer { isLoading = false }

        if let rooms = await currentHouse?.room {
            for choreDTO in selectedChores {
                guard let choreRoom = rooms.first(where: { $0.name == choreDTO.roomDTO.name }) else { continue }

                if let recordID = choreRoom.recordID {
                    // 🚀 CRITICAL: Parent action must be .deleteSelf
                    let roomReference = CKRecord.Reference(recordID: recordID, action: .deleteSelf)

                    let existing = await CloudKitManager.shared.fetchAll(
                        ChoreModel.self,
                        predicate: NSPredicate(format: "room == %@ AND name == %@", roomReference, choreDTO.name)
                    )
                    guard existing.isEmpty else { continue }

                    await CloudKitManager.shared.create(
                        ChoreModel(
                            name: choreDTO.name,
                            description: choreDTO.description,
                            frequency: choreDTO.frequency,
                            duration: choreDTO.duration,
                            isPublic: true,
                            priorityTag: choreDTO.priorityTag,
                            roomReference: roomReference
                        ),
                        zoneID: recordID.zoneID,
                        parent: roomReference // Passes the correct .deleteSelf reference
                    )
                }
            }
        }
    }

    func goToNextView() { stateMachine.next() }
    func goToPreviousView() { stateMachine.back() }

    func finishOnboarding() {
        isOnboardingSkipped = true
        stateMachine.resetProgress()
    }

    /// Binds the user's selected free time securely to their public shared profile.
    ///
    /// > Important: It explicitly targets `fetchMyHouseUser()` to guarantee the schedule capacities
    /// > are uploaded to the shared database so the Admin's algorithm can read them.
    ///
    /// - Note: **Onboarding fix — this is the deterministic cause of "the admin waits forever".**
    ///   The capacity used to be computed as `Int(freeTime.timeInHours) * 60`, which truncates
    ///   *before* multiplying: `Int(0.5) * 60 == 0`. Anyone who picked "Até 30 minutos" produced a
    ///   capacity of zero, `UserModel.setAvailableTimes(_:forWeeks:)` skips every slot whose
    ///   capacity is not greater than zero, and the member's `availableTimeReference` was written
    ///   as an **empty array** — which the admin's gate reads as "still filling in", forever. The
    ///   multiplication now happens in `Double` before the conversion.
    ///
    /// - Parameter daysOfWeekDTO: One entry per weekday, **in Monday-first order** — the position
    ///   in this array is what `UserModel.setAvailableTimes(_:forWeeks:)` maps onto a weekday.
    /// - Returns: `true` when capacities were actually written to the public profile.
    @MainActor
    @discardableResult
    func setAvailableTimeToUser(daysOfWeekDTO: [DayOfWeekDTO]) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        var availableTime: [AvailableTimeModel] = []

        for dayOfWeek in daysOfWeekDTO {
            availableTime.append(
                AvailableTimeModel(
                    // Multiply first, convert second: half an hour is 30 minutes, not 0.
                    capacityMinutes: Int((dayOfWeek.freeTime.timeInHours * 60).rounded()),
                    day: Date()
                )
            )
        }

        guard availableTime.contains(where: { $0.capacityMinutes > 0 }) else {
            errorMessage = "Selecione pelo menos um dia com tempo livre para continuar."
            return false
        }

        if currentHouse == nil {
            await fetchHouse()
        }

        // 🚀 Isolation logic: Always fetch the House User directly
        guard let publicUser = await CloudKitManager.shared.fetchMyHouseUser(in: currentHouse) else {
            errorMessage = "Não encontramos seu perfil dentro da casa. Verifique se o convite foi aceito e tente novamente."
            return false
        }

        // Onboarding fix: the result is no longer discarded. The screen used to advance even
        // when nothing had been written, so the person believed they had submitted their free
        // time while the admin's gate kept counting them as pending.
        guard await publicUser.setAvailableTimes(availableTime) else {
            errorMessage = CloudKitManager.shared.errorMessage ?? "Não conseguimos salvar seu tempo livre. Tente novamente."
            return false
        }

        self.currentUser = publicUser
        self.stateMachine.user = publicUser

        return true
    }

    func fetchHouse() async {
        let house = try? await CloudKitManager.shared.fetchFirst(HouseModel.self)
        currentHouse = house

        // Onboarding fix: keep the state machine's mirror in sync, otherwise `isOwner` stays nil.
        stateMachine.house = house
    }

    /// Creates this device's public profile inside the house it was invited to.
    ///
    /// - Note: **Onboarding fix:** the derived record ID is now built from the **private**
    ///   profile. Building it from ``currentUser`` produced `"…-house-house"` whenever
    ///   `currentUser` already held the public copy — which is the normal state on any resumed
    ///   session — and every later `fetchMyHouseUser()` then looked for a record that did not
    ///   exist. The method is also idempotent: rejoining reuses the existing copy instead of
    ///   appending a duplicate reference to the house.
    ///
    /// - Returns: `true` when the device has a usable public profile in the house afterwards.
    @MainActor
    @discardableResult
    func joinHouse() async -> Bool {
        await fetchHouse()

        guard let house = currentHouse, let houseRecordID = house.recordID else {
            errorMessage = "Ainda não conseguimos encontrar a casa do convite. Abra o link do convite e tente de novo."
            return false
        }

        if privateUser == nil {
            privateUser = await CloudKitManager.shared.fetchMyUser()
        }

        guard let profile = privateUser, let profileRecordID = profile.recordID else {
            errorMessage = "Seu perfil ainda não foi salvo. Crie o perfil antes de entrar na casa."
            return false
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        // Already a member: adopt the existing copy instead of creating a second one.
        if let existingCopy = await CloudKitManager.shared.fetchMyHouseUser(in: house) {
            self.currentUser = existingCopy
            self.stateMachine.user = existingCopy
            self.stateMachine.house = house
            try? await CloudKitManager.shared.createSharedSubscription()
            return true
        }

        // 🚀 CRITICAL: Parent action must be .deleteSelf
        let houseReference = CKRecord.Reference(recordID: houseRecordID, action: .deleteSelf)

        let assetCopy = profile.profilePicture.flatMap { try? duplicateCKAsset($0) }
        let ownerRecordName = await CloudKitManager.shared.fetchCurrentUserRecordID()?.recordName ?? "error fetch user's ID"

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

        if let savedUser = await CloudKitManager.shared.create(sharedUser, id: sharedUserID, parent: house.reference(action: .none)) {
            await house.appendUsers([savedUser])
            self.currentUser = savedUser
            self.stateMachine.user = savedUser
            self.stateMachine.house = house
            try? await CloudKitManager.shared.createSharedSubscription()
            return true
        } else {
            errorMessage = CloudKitManager.shared.errorMessage ?? "Erro ao entrar na casa."
            return false
        }
    }

    func fetchCurrentUser() async {
        let user = await CloudKitManager.shared.fetchMyUser()
        privateUser = user

        if currentUser == nil {
            currentUser = user
            stateMachine.user = user
        }
    }

    /// Reloads whatever the resumed step needs from CloudKit.
    ///
    /// - Note: **Onboarding fix:** it now also resolves the *public* profile and mirrors both
    ///   records onto the state machine. Leaving `stateMachine.house` nil made
    ///   `OnboardingStateMachine.isOwner` return nil, which `Onboarding.swift` passes to
    ///   `FortnightlyScheduleView` as `shouldGenerate: false` — the admin reached the final
    ///   screen and the division was never generated.
    func restoreProgressIfNeeded() async {
        if privateUser == nil { await fetchCurrentUser() }
        if currentHouse == nil { await fetchHouse() }

        if let house = currentHouse {
            await adoptHouse(house)
        }
    }

    private func duplicateCKAsset(_ asset: CKAsset) throws -> CKAsset? {
        guard let origem = asset.fileURL else { return nil }
        let destino = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.copyItem(at: origem, to: destino)
        return CKAsset(fileURL: destino)
    }

    // MARK: - Authorization

    /// Whether this device owns the current house, asked of CloudKit rather than of local state.
    ///
    /// - Note: **Onboarding fix:** `OnboardingStateMachine.isOwner` silently answers `nil` — which
    ///   every call site coerces to "not the admin" — whenever `stateMachine.house` was not
    ///   populated. Resolving the house first makes the answer trustworthy on resumed sessions.
    @MainActor
    func isCurrentUserAdmin() async -> Bool {
        if currentHouse == nil {
            await fetchHouse()
        }

        guard let recordID = currentHouse?.recordID else { return false }
        return CloudKitManager.shared.isOwner(HouseModel.self, recordID: recordID)
    }

    // MARK: - Free time gate

    /// Splits the house members into those who already declared usable free time and those who
    /// have not.
    ///
    /// - Note: **Onboarding fix:** completeness is no longer "the reference array is not empty".
    ///   An empty array was written by the truncation bug described on
    ///   ``setAvailableTimeToUser(daysOfWeekDTO:)``, and a *stale* array (slots that have all
    ///   fallen out of the scheduling window) would have counted as complete while giving the
    ///   scheduler nothing to work with. The slots themselves are read once, in one batch.
    ///
    /// - Returns: The members who are ready, and the members still missing.
    @MainActor
    func houseMembersFreeTimeStatus() async -> (completed: [UserModel], pending: [UserModel]) {
        let members = await fetchHouseMembers()
        guard !members.isEmpty else { return ([], []) }

        // One batch fetch for every slot referenced by every member.
        let allReferences = members.flatMap { $0.availableTimeReference ?? [] }
        let slots = await CloudKitManager.shared.fetchRecordsByRecordReference(
            for: AvailableTimeModel.self,
            recordReferences: allReferences
        ) ?? []

        let usableSlotIDs = Set(
            slots
                .filter { $0.capacityMinutes > 0 && $0.day >= Calendar.current.startOfDay(for: Date()) }
                .compactMap { $0.recordID }
        )

        var completed: [UserModel] = []
        var pending: [UserModel] = []

        for member in members {
            let references = member.availableTimeReference ?? []
            let hasUsableTime = references.contains { usableSlotIDs.contains($0.recordID) }

            if hasUsableTime {
                completed.append(member)
            } else {
                pending.append(member)
            }
        }

        return (completed, pending)
    }

    // MARK: - Algorithm

    /// Advances the guest past the waiting screen once the admin's division is readable.
    ///
    /// - Note: **Onboarding fix — this is the "guest waits forever" bug.** Three things kept the
    ///   screen from ever advancing:
    ///   1. `fetchAll(DailyAssignmentModel.self)` runs a `CKQuery`, which returns an empty array
    ///      indistinguishable from "not ready" whenever the record type lacks a *Queryable*
    ///      index. The house zone is now scanned directly instead.
    ///   2. The check only ran from `.task` (once) and from `.cloudKitDidChange`, which is posted
    ///      exclusively by `AppDelegate.application(_:didReceiveRemoteNotification:)` — and iOS
    ///      never delivers those silent pushes, because the target does not declare the
    ///      `remote-notification` background mode. The view now polls; see
    ///      `WaitHouseCreatorSheduleView`.
    ///   3. Readiness is also inferred from this device's own public profile having chores, so a
    ///      guest whose assignments are readable through either route gets through.
    @MainActor
    func checkAndAdvanceIfScheduleReady() async {
        guard await isScheduleAvailable() else { return }

        isScheduleReady = true
        guard stateMachine.current == .waitAdminScheduling else { return }
        goToNextView()
    }

    /// Whether a division produced by the admin is readable from this device.
    @MainActor
    func isScheduleAvailable() async -> Bool {
        if currentHouse == nil {
            await fetchHouse()
        }

        guard let house = currentHouse else { return false }

        // Index-free read of the house zone: no CloudKit schema configuration required.
        let assignments = await CloudKitManager.shared.fetchHouseRecords(DailyAssignmentModel.self, of: house)
        if !assignments.isEmpty { return true }

        // Secondary signal: my own public profile was given chores by the scheduler.
        if let houseUser = await CloudKitManager.shared.fetchMyHouseUser(in: house),
           !(houseUser.choresReference ?? []).isEmpty {
            return true
        }

        // Last resort, in case the zone scan is unavailable but queries work.
        return !(await CloudKitManager.shared.fetchAll(DailyAssignmentModel.self)).isEmpty
    }

    // MARK: - Auto Login / Initial Validation

    /// Checks if the current iCloud user already possesses an account within the application.
    ///
    /// This method queries CloudKit for an existing `UserModel`. If a profile is found, it restores
    /// the local session and updates the `OnboardingStateMachine`. Then, it checks for an existing `HouseModel`.
    ///
    /// - Note: **Onboarding fix:** resume targets are now expressed as steps rather than indices
    ///   (see ``OnboardingStateMachine/jump(to:)``), the private and public profiles are tracked
    ///   separately, and a guest who has not declared free time yet is resumed at `.chooseFreeTime`
    ///   instead of being parked on the waiting screen with nothing to wait for.
    @MainActor
    func checkExistingAccount() async {
        isCheckingAccount = true
        isLoading = true

        defer {
            isCheckingAccount = false
            isLoading = false
        }

        guard let existingPrivateUser = await CloudKitManager.shared.fetchMyUser() else { return }

        CloudKitManager.shared.setCurrentUser(existingPrivateUser)
        self.privateUser = existingPrivateUser
        self.currentUser = existingPrivateUser
        self.stateMachine.user = existingPrivateUser

        guard let existingHouse = try? await CloudKitManager.shared.fetchFirst(HouseModel.self) else {
            self.currentHouse = nil
            self.stateMachine.house = nil
            self.stateMachine.flow = .notDefined
            self.stateMachine.jump(to: .createOrEnterHome)
            return
        }

        await adoptHouse(existingHouse)

        if await isScheduleAvailable() {
            self.finishOnboarding()
            return
        }

        // 🚀 SECURE FIX: Safely unwrap the recordID to prevent Fatal Errors on app restart
        guard let houseID = existingHouse.recordID else { return }

        let isOwner = CloudKitManager.shared.isOwner(HouseModel.self, recordID: houseID)
        let hasDeclaredFreeTime = !((self.currentUser?.availableTimeReference ?? []).isEmpty)

        if isOwner {
            self.stateMachine.flow = .houseCreator
            self.stateMachine.jump(to: hasDeclaredFreeTime ? .waitGuestsFreeTime : .chooseFreeTime)
        } else {
            self.stateMachine.flow = .invitedWithProfile
            // Onboarding fix: a guest who never managed to submit their free time (the
            // truncation bug wrote an empty list) used to be parked on the waiting screen with
            // no way to supply it — and the admin's gate blocked on them indefinitely.
            self.stateMachine.jump(to: hasDeclaredFreeTime ? .waitAdminScheduling : .chooseFreeTime)
        }
    }
}
