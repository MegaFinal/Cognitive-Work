//
//  ShopListViewModel.swift
//  Cognitive-Work
//

import Foundation
import CloudKit

/// Owns the house's shopping list, its items, and the house members available to assign items
@Observable
final class ShopListViewModel {

    /// The house's shopping list.
    private(set) var list: ShopListModel?

    /// ``list``'s items, fetched fresh by ``reloadItems()``.
    private(set) var items: [ShopListItem] = []

    /// Every member of the house, offered as choices in the add/edit form's user picker.
    private(set) var houseUsers: [UserModel] = []

    /// The signed-in user's in-house record, credited as ``ShopListItem/addedByUser`` on items
    /// created here.
    private(set) var currentUser: UserModel?

    /// True while the list, its items, or the house members are being fetched.
    private(set) var isLoading = false

    private(set) var errorMessage: String?

    /// Items still waiting to be bought.
    var pendingItems: [ShopListItem] {
        items.filter { !$0.isBought }
    }

    /// Items already checked off.
    var boughtItems: [ShopListItem] {
        items.filter { $0.isBought }
    }

    init() {}

    init(previewItems: [ShopListItem], houseUsers: [UserModel] = [], currentUser: UserModel? = nil) {
        self.items = previewItems
        self.houseUsers = houseUsers
        self.currentUser = currentUser
        self.hasLoaded = true
    }

    // MARK: - Setup

    /// Whether ``setup()`` has completed at least once.
    private(set) var hasLoaded = false

    /// The refresh currently in flight, if any.
    @ObservationIgnored
    private var refreshTask: Task<Void, Never>?

    /// Loads the house's shopping list, its items, and every house member.
    func setup() async {
        isLoading = true
        defer {
            isLoading = false
            hasLoaded = true
        }

        async let houseTask = CloudKitManager.shared.currentHouse()
        async let usersTask = CloudKitManager.shared.fetchHouseUsers()
        async let currentUserTask = CloudKitManager.shared.currentHouseUser()

        let (house, users, current) = await (houseTask, usersTask, currentUserTask)

        guard !Task.isCancelled else { return }

        houseUsers = users
        currentUser = current

        guard let house else {
            errorMessage = "Casa não encontrada."
            return
        }

        guard let existingList = await house.shopList else {
            errorMessage = "Essa casa ainda não tem uma lista de compras."
            return
        }

        self.list = existingList
        await reloadItems()
    }

    /// Re-fetches ``list``'s items from CloudKit.
    func reloadItems() async {
        guard let list else {
            items = []
            return
        }

        let fetched = await list.items
        guard !Task.isCancelled else { return }
        items = fetched
    }

    /// Re-syncs with CloudKit for a real-time update (push notification / app returning to the
    /// foreground).
    func refresh() async {
        guard list != nil else {
            await setup()
            return
        }
        await reloadItems()
    }

    /// Coalesces refresh requests and cancels the previous one.
    ///
    /// - Parameter debounce: How long to wait for further requests before fetching.
    func requestRefresh(debounce: Duration = .milliseconds(250)) {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            try? await Task.sleep(for: debounce)
            guard !Task.isCancelled, let self else { return }
            await self.refresh()
        }
    }

    // MARK: - Items

    /// Parses the raw price text and saves the item — creating a new one, or applying edits to
    /// `existingItem` when one is passed. Owns the create-vs-update decision and the price
    /// text parsing so the form view only manages its own local `@State`.
    ///
    /// - Parameters:
    ///   - existingItem: The item being edited, or `nil` to create a new one.
    ///   - name: Label shown to the user.
    ///   - valueText: Raw text from the price field (accepts `,` or `.` as the decimal separator).
    ///   - quantity: How many units to buy.
    ///   - unitMeasurement: The unit `quantity` is expressed in.
    ///   - relatedUsers: Other users who will use/share this item.
    ///   - addedBy: Credited as the item's creator. Ignored when `existingItem` is passed.
    /// - Returns: `true` when the save reached CloudKit.
    @discardableResult
    func saveItem(
        _ existingItem: ShopListItem?,
        name: String,
        valueText: String,
        quantity: Int,
        unitMeasurement: UnitMeasurement,
        relatedUsers: [UserModel],
        addedBy: UserModel?
    ) async -> Bool {
        let value = Double(valueText.replacingOccurrences(of: ",", with: "."))

        //MARK: Gamification cognitive points (accumulated, then a single call after a successful save)
        var score = 0
        let hasNewPrice = (value ?? 0) > 0
        let success: Bool

        if let existingItem {
            // Captured before the update, since it changes the item.
            let previousUserIDs = Set(existingItem.relatedUsers(in: houseUsers).compactMap(\.recordID))
            let hadPrice = (existingItem.value ?? 0) > 0

            let addedBeneficiaries = relatedUsers.filter { user in
                guard let id = user.recordID else { return false }
                return !previousUserIDs.contains(id)
            }
            score += addedBeneficiaries.count * ScoreValues.shoppingItemBeneficiaryAssigned.points
            if hasNewPrice && !hadPrice {
                score += ScoreValues.receiptScanned(itemCount: 1).points
            }

            success = await updateItem(
                existingItem,
                name: name,
                value: value,
                quantity: quantity,
                unitMeasurement: unitMeasurement,
                relatedUsers: relatedUsers
            )
        } else {
            score += ScoreValues.shoppingItemAdded.points
            score += relatedUsers.count * ScoreValues.shoppingItemBeneficiaryAssigned.points
            if hasNewPrice {
                score += ScoreValues.receiptScanned(itemCount: 1).points
            }

            success = await addItem(
                name: name,
                value: value,
                quantity: quantity,
                unitMeasurement: unitMeasurement,
                relatedUsers: relatedUsers,
                addedBy: addedBy
            )
        }

        if success && score > 0 {
            await ScoreManager.shared.assignScoreForMyUser(score: score)
        }
        return success
    }

    /// Adds a new item to ``list`` and appends it to ``items``.
    ///
    /// - Parameters:
    ///   - name: Label shown to the user.
    ///   - value: Estimated or actual price, when known.
    ///   - quantity: How many units to buy.
    ///   - unitMeasurement: The unit `quantity` is expressed in.
    ///   - relatedUsers: Other users who will use/share this item.
    ///   - addedBy: The user adding the item, credited for gamification.
    /// - Returns: `true` when the item was saved.
    @discardableResult
    func addItem(
        name: String,
        value: Double? = nil,
        quantity: Int,
        unitMeasurement: UnitMeasurement,
        relatedUsers: [UserModel] = [],
        addedBy: UserModel?
    ) async -> Bool {
        guard let list else {
            errorMessage = "Lista de compras ainda não carregada."
            return false
        }

        let relatedUsersReferences = relatedUsers.compactMap { user -> CKRecord.Reference? in
            guard let recordID = user.recordID else { return nil }
            return CKRecord.Reference(recordID: recordID, action: .none)
        }
        let addedByReference = addedBy?.recordID.map { CKRecord.Reference(recordID: $0, action: .none) }

        let draft = ShopListItem(
            name: name,
            value: value,
            quantity: quantity,
            unitMeasurement: unitMeasurement,
            relatedUsers: relatedUsersReferences.isEmpty ? nil : relatedUsersReferences,
            addedByUser: addedByReference
        )

        guard let created = await list.addItem(draft) else {
            errorMessage = CloudKitManager.shared.errorMessage ?? "Erro ao adicionar item."
            return false
        }

        items.append(created)
        return true
    }

    /// Applies edits made to an existing item and persists them (see
    /// ``ShopListItem/update(name:value:quantity:unitMeasurement:relatedUsers:)``).
    @discardableResult
    func updateItem(
        _ item: ShopListItem,
        name: String,
        value: Double?,
        quantity: Int,
        unitMeasurement: UnitMeasurement,
        relatedUsers: [UserModel]
    ) async -> Bool {

        guard await item.update(
            name: name,
            value: value,
            quantity: quantity,
            unitMeasurement: unitMeasurement,
            relatedUsers: relatedUsers
        ) else {
            errorMessage = CloudKitManager.shared.errorMessage ?? "Erro ao editar item."
            return false
        }
        return true
    }

    /// Flips an item's ``ShopListItem/isBought`` status and persists the change.
    func toggleBought(_ item: ShopListItem) async {
        await item.toggle()
    }

    /// Marks an item bought by `user` (see ``ShopListItem/markBought(by:)``).
    func markBought(_ item: ShopListItem, by user: UserModel) async {
        await item.markBought(by: user)
    }

    /// Removes an item from ``list`` and from ``items``.
    @discardableResult
    func deleteItem(_ item: ShopListItem) async -> Bool {
        guard let list else { return false }

        guard await list.removeItem(item) else {
            errorMessage = CloudKitManager.shared.errorMessage ?? "Erro ao remover item."
            return false
        }

        items.removeAll { $0.id == item.id }
        return true
    }
}
