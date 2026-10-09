//
//  ShopListViewModel.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 18/09/26.
//

import Foundation
import CloudKit

// MARK: - Presentation types

/// How the list orders (and groups) its items.
enum ShopListSortOption: String, CaseIterable, Identifiable {
    case category
    case addedOrder
    case name

    var id: String { rawValue }

    var label: String {
        switch self {
        case .category: return L10n.tr("Categoria")
        case .addedOrder: return L10n.tr("Adicionados recentemente")
        case .name: return L10n.tr("Nome")
        }
    }

    var symbol: String {
        switch self {
        case .category: return "square.grid.2x2"
        case .addedOrder: return "clock"
        case .name: return "textformat"
        }
    }
}

/// A field the add/edit form requires before it can be saved.
enum ShopItemField: CaseIterable {
    case name
    case quantity
    case unit
    case category
    case consumers

    /// What the form tells the user to do, in the same wording as the chore form's warnings
    /// ("Escolha um cômodo para confirmar a tarefa.").
    var warning: String {
        switch self {
        case .name: return L10n.tr("Digite o nome para confirmar o item.")
        case .quantity: return L10n.tr("Informe a quantidade para confirmar o item.")
        case .unit: return L10n.tr("Escolha uma unidade para confirmar o item.")
        case .category: return L10n.tr("Escolha uma categoria para confirmar o item.")
        case .consumers: return L10n.tr("Escolha quem vai consumir/pagar para confirmar o item.")
        }
    }
}

/// A titled group of items, shown as one collapsible section.
struct ShopListSection: Identifiable {
    let id: String
    let title: String
    let items: [ShopListItem]
}

/// Owns the house's shopping list, its items, and the house members available to assign items.
@MainActor
@Observable
final class ShopListViewModel {

    private(set) var list: ShopListModel?

    private(set) var items: [ShopListItem] = []

    private(set) var houseUsers: [UserModel] = []

    /// The signed-in user's in-house record, credited as ``ShopListItem/addedByUser`` on items
    /// created here.
    private(set) var currentUser: UserModel?

    private(set) var errorMessage: String?

    var pendingItems: [ShopListItem] {
        items.filter { !$0.isBought }
    }

    var boughtItems: [ShopListItem] {
        items.filter { $0.isBought }
    }

    // MARK: - Presentation

    var sortOption: ShopListSortOption = .category

    /// Identifies the "Comprados" section.
    static let boughtSectionID = "bought"

    /// Sections the user collapsed.
    private(set) var collapsedSectionIDs: Set<String> = []

    /// Whether the "+" button can add items (the list has to be loaded first).
    var canAddItems: Bool { list != nil }

    /// "3 itens para comprar", shown under the title.
    var pendingSummary: String {
        L10n.tr("%lld itens para comprar", pendingItems.count)
    }

    /// Pending items as sections
    var pendingSections: [ShopListSection] {
        let pending = pendingItems

        switch sortOption {
        case .category:
            return ShopItemCategory.allCases.compactMap { category in
                let items = Self.sort(pending.filter { $0.category == category }, by: .addedOrder)
                return items.isEmpty ? nil : ShopListSection(id: category.rawValue, title: category.displayName, items: items)
            }
        case .addedOrder, .name:
            let items = Self.sort(pending, by: sortOption)
            return items.isEmpty ? [] : [ShopListSection(id: "pending", title: L10n.tr("A comprar"), items: items)]
        }
    }

    /// The "Comprados" section, or `nil` when nothing was bought yet.
    var boughtSection: ShopListSection? {
        let items = Self.sort(boughtItems, by: sortOption == .name ? .name : .addedOrder)
        return items.isEmpty ? nil : ShopListSection(id: Self.boughtSectionID, title: L10n.tr("Comprados"), items: items)
    }

    private static func sort(_ items: [ShopListItem], by option: ShopListSortOption) -> [ShopListItem] {
        switch option {
        case .name:
            return items.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .category, .addedOrder:
            return items.sorted { $0.createdAt > $1.createdAt }
        }
    }

    func isCollapsed(_ section: ShopListSection) -> Bool {
        collapsedSectionIDs.contains(section.id)
    }

    func toggleCollapsed(_ section: ShopListSection) {
        if collapsedSectionIDs.contains(section.id) {
            collapsedSectionIDs.remove(section.id)
        } else {
            collapsedSectionIDs.insert(section.id)
        }
    }

    /// The housemates `item` is for, resolved against ``houseUsers`` (no network).
    func relatedUsers(for item: ShopListItem) -> [UserModel] {
        item.relatedUsers(in: houseUsers)
    }

    init() {}

    /// `true` inside Xcode previews. CloudKit can't run there (no iCloud entitlement), and
    /// touching it crashes the preview process, so every method below that would reach the
    /// network works on the in-memory data instead.
    @ObservationIgnored
    private let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"

    init(previewItems: [ShopListItem], houseUsers: [UserModel] = [], currentUser: UserModel? = nil) {
        self.items = previewItems
        self.houseUsers = houseUsers
        self.currentUser = currentUser
        self.hasLoaded = true
    }

    // MARK: - Setup

    /// Whether a snapshot has been applied at least once.
    private(set) var hasLoaded = false

    /// The refresh currently waiting or in flight, if any.
    @ObservationIgnored
    private var refreshTask: Task<Void, Never>?

    /// The snapshot last applied, so the same one is never applied twice.
    @ObservationIgnored
    private var appliedSnapshotID: UUID?

    /// Shows the house data already loaded by ``HouseDataStore`` (a first load if none yet).
    func setup() async {
        guard !isPreview else { hasLoaded = true; return }
        let snapshot = await HouseDataStore.shared.load()
        guard !Task.isCancelled else { return }
        apply(snapshot)
    }

    func refresh() async {
        guard !isPreview else { return }
        let snapshot = await HouseDataStore.shared.load()
        guard !Task.isCancelled else { return }
        apply(snapshot)
    }

    /// Coalesces refresh requests and cancels the previous one.
    ///
    /// - Parameter debounce: How long to wait for further requests before fetching.
    func requestRefresh(debounce: Duration = .milliseconds(250)) {
        guard !isPreview else { return }
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            try? await Task.sleep(for: debounce)
            guard !Task.isCancelled, let self else { return }
            await self.refresh()
        }
    }

    /// Replaces the screen's state with `snapshot`, unless it was already applied.
    private func apply(_ snapshot: HouseSnapshot) {
        defer { hasLoaded = true }
        guard snapshot.id != appliedSnapshotID else { return }
        appliedSnapshotID = snapshot.id

        houseUsers = snapshot.users
        currentUser = snapshot.houseUser

        guard let shopList = snapshot.shopList else {
            list = nil
            items = []
            errorMessage = L10n.tr("Essa casa ainda não tem uma lista de compras.")
            return
        }

        list = shopList
        items = shopList.belonging(to: snapshot.shopItems)
    }

    /// Adds `item`, or replaces the one with the same id — never creates a duplicate row.
    private func upsert(_ item: ShopListItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
        } else {
            items.append(item)
        }
    }

    // MARK: - Gamification

    /// Points a new item is worth: the item itself, its beneficiaries, and a price.
    static func creationScore(beneficiaries: Int, hasPrice: Bool) -> Int {
        var score = ScoreValues.shoppingItemAdded.points
        score += beneficiaries * ScoreValues.shoppingItemBeneficiaryAssigned.points
        if hasPrice { score += ScoreValues.receiptScanned(itemCount: 1).points }
        return score
    }

    // MARK: - Items

    /// Reads a price typed by the user (`,` or `.` as the decimal separator).
    ///
    /// - Returns: The price, or `nil` when the text is empty or isn't a number.
    static func parsePrice(_ text: String) -> Double? {
        Double(text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: "."))
    }

    /// Most digits a price can have (R$ 9.999.999,99).
    static let maxPriceDigits = 9

    /// Bank-style price entry: the user types only digits and they fill in from the cents, so
    /// `1`, `5`, `0` reads "0,01", "0,15", "1,50". Anything that isn't a digit is ignored.
    static func formatPriceInput(_ text: String) -> String {
        let digits = text.filter(\.isNumber).prefix(maxPriceDigits)
        guard let cents = Int(digits), cents > 0 else { return "" }
        return "\(cents / 100),\(String(format: "%02d", cents % 100))"
    }

    /// The text field content for an already known price.
    static func priceInputText(for value: Double) -> String {
        formatPriceInput(String(Int((value * 100).rounded())))
    }

    /// The required fields that are still empty or invalid. The form disables its confirm
    /// button while this isn't empty, and ``saveItem(_:name:valueText:quantity:unitMeasurement:category:relatedUsers:addedBy:)``
    /// refuses to save, so an item can never be created without all of them.
    static func missingFields(
        name: String,
        quantity: Int,
        unitMeasurement: UnitMeasurement,
        category: ShopItemCategory?,
        relatedUsers: [UserModel]
    ) -> [ShopItemField] {
        var missing: [ShopItemField] = []
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { missing.append(.name) }
        if !QuantityStepper.allowedRange.contains(quantity) { missing.append(.quantity) }
        if unitMeasurement == .undefined { missing.append(.unit) }
        if category == nil { missing.append(.category) }
        if relatedUsers.isEmpty { missing.append(.consumers) }
        return missing
    }

    /// Parses the raw price text and saves the item — creating a new one, or applying edits to
    /// `existingItem` when one is passed.
    ///
    /// - Returns: `true` when the save reached CloudKit.
    @discardableResult
    func saveItem(
        _ existingItem: ShopListItem?,
        name: String,
        valueText: String,
        quantity: Int,
        unitMeasurement: UnitMeasurement,
        category: ShopItemCategory,
        relatedUsers: [UserModel],
        addedBy: UserModel?
    ) async -> Bool {
        let missing = Self.missingFields(
            name: name,
            quantity: quantity,
            unitMeasurement: unitMeasurement,
            category: category,
            relatedUsers: relatedUsers
        )
        if let firstMissing = missing.first {
            errorMessage = firstMissing.warning
            return false
        }

        let value = Self.parsePrice(valueText)

        if isPreview {
            previewSave(existingItem, name: name, value: value, quantity: quantity,
                        unitMeasurement: unitMeasurement, category: category,
                        relatedUsers: relatedUsers, addedBy: addedBy)
            return true
        }

        var score = 0
        let hasNewPrice = (value ?? 0) > 0
        let success: Bool

        if let existingItem {
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
                category: category,
                relatedUsers: relatedUsers
            )
        } else {
            score = Self.creationScore(
                beneficiaries: relatedUsers.count,
                hasPrice: hasNewPrice
            )

            success = await addItem(
                name: name,
                value: value,
                quantity: quantity,
                unitMeasurement: unitMeasurement,
                category: category,
                relatedUsers: relatedUsers,
                addedBy: addedBy
            )
        }

        if success && score > 0 {
            await ScoreManager.shared.assignScoreForMyUser(score: score)
        }
        return success
    }

    /// Adds a new item to ``list`` and shows it right away (never duplicating a row).
    @discardableResult
    func addItem(
        name: String,
        value: Double? = nil,
        quantity: Int,
        unitMeasurement: UnitMeasurement,
        category: ShopItemCategory = .default,
        relatedUsers: [UserModel] = [],
        addedBy: UserModel?
    ) async -> Bool {
        guard let list else {
            errorMessage = L10n.tr("Lista de compras ainda não carregada.")
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
            category: category,
            relatedUsers: relatedUsersReferences.isEmpty ? nil : relatedUsersReferences,
            addedByUser: addedByReference
        )

        guard let created = await list.addItem(draft) else {
            errorMessage = CloudKitManager.shared.errorMessage ?? L10n.tr("Erro ao adicionar item.")
            return false
        }

        upsert(created)
        return true
    }

    /// Applies edits made to an existing item and persists them.
    @discardableResult
    func updateItem(
        _ item: ShopListItem,
        name: String,
        value: Double?,
        quantity: Int,
        unitMeasurement: UnitMeasurement,
        category: ShopItemCategory,
        relatedUsers: [UserModel]
    ) async -> Bool {

        guard await item.update(
            name: name,
            value: value,
            quantity: quantity,
            unitMeasurement: unitMeasurement,
            category: category,
            relatedUsers: relatedUsers
        ) else {
            errorMessage = CloudKitManager.shared.errorMessage ?? L10n.tr("Erro ao editar item.")
            return false
        }
        return true
    }

    // MARK: - Buying

    /// An item the user is checking off that has no price yet; the view asks for it first.
    struct PurchasePrompt: Identifiable {
        let item: ShopListItem
        var id: String { item.id }
    }

    /// Set while the "how much was it?" popup should be on screen.
    private(set) var purchasePrompt: PurchasePrompt?

    func dismissPurchasePrompt() {
        purchasePrompt = nil
    }

    /// Whether `text` is a price the popup can confirm.
    static func isValidPrice(_ text: String) -> Bool {
        (parsePrice(text) ?? 0) > 0
    }

    /// Checks an item off, or puts it back on the list.
    func toggleBought(_ item: ShopListItem) async {
        if !item.isBought, !item.hasPrice {
            purchasePrompt = PurchasePrompt(item: item)
            return
        }
        await setBought(item, price: nil)
    }

    /// Finishes a purchase started from the price popup.
    ///
    /// - Parameter valueText: The typed price, or `nil` to buy without informing it.
    func confirmPurchase(of item: ShopListItem, valueText: String?) async {
        purchasePrompt = nil

        let price = valueText.flatMap(Self.parsePrice).flatMap { $0 > 0 ? $0 : nil }
        await setBought(item, price: price)
    }

    private func setBought(_ item: ShopListItem, price: Double?) async {
        if isPreview {
            if let price { item.value = price }
            item.isBought.toggle()
            return
        }

        if item.isBought {
            let buyerID = item.buyerRecordID
            guard await item.toggle() else {
                errorMessage = CloudKitManager.shared.errorMessage ?? L10n.tr("Erro ao editar item.")
                return
            }
            let points = ScoreValues.shoppingItemBought.points
            if let buyerID, let buyer = houseUsers.first(where: { $0.recordID == buyerID }) {
                await ScoreManager.shared.removeScore(score: points, for: buyer)
            }
        } else if let currentUser {
            let didSave = await item.markBought(by: currentUser, value: price)
            guard didSave else {
                errorMessage = CloudKitManager.shared.errorMessage ?? L10n.tr("Erro ao editar item.")
                return
            }

            var points = ScoreValues.shoppingItemBought.points
            if price != nil { points += ScoreValues.receiptScanned(itemCount: 1).points }
            await ScoreManager.shared.assignScoreForMyUser(score: points)
        } else if await item.toggle() == false {
            errorMessage = CloudKitManager.shared.errorMessage ?? L10n.tr("Erro ao editar item.")
        }
    }

    /// Dismisses the error shown by the view.
    func clearError() {
        errorMessage = nil
    }

    /// Removes an item from CloudKit and from ``items``.
    @discardableResult
    func deleteItem(_ item: ShopListItem) async -> Bool {
        guard list != nil || isPreview else { return false }
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return true }

        items.remove(at: index)
        if isPreview { return true }

        guard let list, await list.removeItem(item) else {
            errorMessage = CloudKitManager.shared.errorMessage ?? L10n.tr("Erro ao remover item.")
            if !items.contains(where: { $0.id == item.id }) {
                items.insert(item, at: min(index, items.count))
            }
            return false
        }

        if !item.isBought, let me = currentUser?.recordID, item.addedByRecordID == me {
            await ScoreManager.shared.removeScoreForMyUser(score: ScoreValues.shoppingItemAdded.points)
        }
        return true
    }

    // MARK: - Previews

    /// What saving does in a preview: the same change as CloudKit would make, in memory only.
    private func previewSave(
        _ existingItem: ShopListItem?,
        name: String,
        value: Double?,
        quantity: Int,
        unitMeasurement: UnitMeasurement,
        category: ShopItemCategory,
        relatedUsers: [UserModel],
        addedBy: UserModel?
    ) {
        let references = relatedUsers.compactMap { user in
            user.recordID.map { CKRecord.Reference(recordID: $0, action: .none) }
        }

        if let existingItem {
            existingItem.name = name
            existingItem.value = value
            existingItem.quantity = quantity
            existingItem.unitMeasurement = unitMeasurement
            existingItem.category = category
            existingItem.relatedUsersReference = references
        } else {
            let item = ShopListItem(
                name: name,
                value: value,
                quantity: quantity,
                unitMeasurement: unitMeasurement,
                category: category,
                relatedUsers: references.isEmpty ? nil : references
            )
            item.recordID = CKRecord.ID(recordName: "preview-item-\(UUID().uuidString)")
            upsert(item)
        }
    }
}
