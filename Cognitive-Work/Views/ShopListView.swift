//
//  ShopListView.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 18/09/26.
//

import SwiftUI
import CloudKit

/// Shows the house's shopping list
struct ShopListView: View {

    @State private var viewModel: ShopListViewModel

    @State private var isPresentingAddItem = false
    @State private var editingItem: ShopListItem?

    @State private var sortOption: SortOption = .addedOrder
    @State private var isShowingErrorAlert = false

    init(viewModel: ShopListViewModel = ShopListViewModel()) {
        self._viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 40) {
            header

            if viewModel.isLoading && viewModel.list == nil {
                Spacer()
                ProgressView()
                    .frame(maxWidth: .infinity)
                Spacer()
            } else if viewModel.hasLoaded && viewModel.items.isEmpty {
                emptyState
            } else {
                itemList
            }
        }
        .overlay(alignment: .bottomTrailing) {
            addButton
        }
        .background(Color(.white).ignoresSafeArea())
        .task {
            guard !viewModel.hasLoaded else { return }
            await viewModel.setup()
        }
        .task {
            // updates feel real-time regardless of push timing.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled else { break }
                await viewModel.refresh()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .cloudKitDidChange)) { _ in
            viewModel.requestRefresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            viewModel.requestRefresh()
        }
        .sheet(isPresented: $isPresentingAddItem) {
            ShopListItemFormView(
                mode: .create,
                availableUsers: viewModel.houseUsers,
                currentUser: viewModel.currentUser,
                viewModel: viewModel
            )
        }
        .sheet(item: $editingItem) { item in
            ShopListItemFormView(
                mode: .edit(item),
                availableUsers: viewModel.houseUsers,
                currentUser: viewModel.currentUser,
                viewModel: viewModel
            )
        }
    }

    // MARK: - Subviews

    /// Page title alongside the notice and sort controls.
    private var header: some View {
        HStack {
            Text("Compras")
                .font(.system(size: 34))
                .fontWeight(.bold)
                .padding(.horizontal, 30)
                .padding(.top, 20)

            Spacer()

            Menu {
                Picker("Ordenar por", selection: $sortOption) {
                    ForEach(SortOption.allCases) { option in
                        Text(option.label).tag(option)
                    }
                }
            } label: {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.system(size: 20))
                    .foregroundColor(.black)
                    .glassCircle()
            }
            .accessibilityLabel(Text("Ordenar por"))
            .padding(.top, 20)
            .padding(.trailing, 30)
        }
    }

    /// Pending items, a divider, then bought items
    private var itemList: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 40) {
                ForEach(sortedPending) { item in
                    ShopListItemRow(
                        item: item,
                        relatedUsers: item.relatedUsers(in: viewModel.houseUsers),
                        onToggle: { await viewModel.toggleBought(item) },
                        onTap: { editingItem = item }
                    )
                }

                if !viewModel.boughtItems.isEmpty {
                    Divider()
                        .padding(.horizontal, 24)

                    ForEach(sortedBought) { item in
                        ShopListItemRow(
                            item: item,
                            relatedUsers: item.relatedUsers(in: viewModel.houseUsers),
                            onToggle: { await viewModel.toggleBought(item) },
                            onTap: { editingItem = item }
                        )
                    }
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 120)
        }
    }

    /// Shown instead of ``itemList`` once the list has loaded and has no items yet.
    private var emptyState: some View {
        ContentUnavailableView(
            "Lista de compras vazia",
            systemImage: "cart",
            description: Text("Toque em \"+\" para adicionar o primeiro item.")
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Floating action button that opens the form to add a new item.
    private var addButton: some View {
        Button {
            isPresentingAddItem = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 28))
                .foregroundColor(.white)
                .glassCircle(diameter: GlassCircleSize.floating, tint: .black)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Novo item"))
        .disabled(viewModel.list == nil)
        .padding(.horizontal, 30)
        .padding(.bottom)
    }

    // MARK: - Sorting

    private enum SortOption: String, CaseIterable, Identifiable {
        case addedOrder
        case name

        var id: String { rawValue }

        var label: String {
            switch self {
            case .addedOrder: return L10n.tr("Adicionados recentemente")
            case .name: return L10n.tr("Nome")
            }
        }
    }

    private var sortedPending: [ShopListItem] {
        sorted(viewModel.pendingItems)
    }

    private var sortedBought: [ShopListItem] {
        sorted(viewModel.boughtItems)
    }

    private func sorted(_ items: [ShopListItem]) -> [ShopListItem] {
        switch sortOption {
        case .addedOrder:
            return items
        case .name:
            return items.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }
}

// MARK: - Row

/// One shopping list entry
private struct ShopListItemRow: View {
    var item: ShopListItem

    /// Resolved by the parent from ``ShopListViewModel/houseUsers`` (see
    /// ``ShopListItem/relatedUsers(in:)``) instead of each row firing its own CloudKit request.
    var relatedUsers: [UserModel]

    var onToggle: () async -> Void
    var onTap: () -> Void
    
    /// Blocks double taps while the change is being saved.
    @State private var isToggling = false

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text("\(item.quantity)")
                .font(.system(size: 32, weight: .bold))
                .frame(minWidth: 32, alignment: .leading)

            VStack(alignment: .leading, spacing: 6) {
                Text(item.name)
                    .font(.system(size: 19))
                    .strikethrough(item.isBought)
                    .foregroundColor(item.isBought ? .secondary : .primary)

                if !relatedUsers.isEmpty {
                    UserProfilePictureList(users: relatedUsers, widthMultiplier: 0.07)
                }
            }

            Spacer()

            Button {
                HapticsManager.selection()
                isToggling = true
                Task {
                    await onToggle()
                    isToggling = false
                }
            } label: {
                Circle()
                    .strokeBorder(item.isBought ? Color.clear : Color.black, lineWidth: 1.5)
                    .background(Circle().fill(item.isBought ? Color.black : Color.clear))
                    .frame(width: 26, height: 26)
                    .overlay {
                        if isToggling {
                            ProgressView()
                                .controlSize(.mini)
                                .tint(item.isBought ? .white : .black)
                        }
                    }
            }
            .buttonStyle(.plain)
            .disabled(isToggling)
            .padding(.top, 4)
        }
        .padding(.horizontal, 24)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}

// MARK: - Create/Edit form

/// Which action ``ShopListItemFormView`` performs on confirm.
private enum ShopListItemFormMode {
    case create
    case edit(ShopListItem)
}

/// A form used both to add a new item and to edit an existing one
private struct ShopListItemFormView: View {
    var mode: ShopListItemFormMode
    var availableUsers: [UserModel]
    var currentUser: UserModel?
    var viewModel: ShopListViewModel

    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var quantity: Int = 1
    @State private var unitMeasurement: UnitMeasurement = .unit
    @State private var valueText: String = ""
    @State private var relatedUsers: [UserModel] = []
    @State private var isSaving = false
    @State private var saveErrorMessage: String?

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 25) {
                        VStack(spacing: 2) {
                            TextField(
                                "",
                                text: $name,
                                prompt: Text("Nome do item").foregroundStyle(.black)
                            )
                            .font(.system(size: 28))
                            .bold()
                            .characterLimit(TextLimits.shopItemName, text: $name)
                            .submitLabel(.done)

                            Capsule()
                                .frame(height: 1.5)
                                .foregroundStyle(.gray.opacity(0.3))
                        }

                        HStack {
                            Text("Quantidade")
                                .font(.system(size: 15))
                                .fontWeight(.semibold)
                            Spacer()
                            Stepper(value: $quantity, in: 1...99) {
                                Text("\(quantity)")
                                    .fontWeight(.semibold)
                            }
                            .fixedSize()
                        }

                        HStack {
                            Text("Unidade")
                                .font(.system(size: 15))
                                .fontWeight(.semibold)
                            Spacer()
                            Menu {
                                Picker("Unidade", selection: $unitMeasurement) {
                                    ForEach(UnitMeasurement.allCases) { unit in
                                        Text(unit.getDisplayName(for: Double(quantity))).tag(unit)
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(unitMeasurement.getDisplayName(for: Double(quantity)))
                                    Image(systemName: "chevron.up.chevron.down")
                                        .imageScale(.small)
                                }
                                .foregroundColor(.black)
                            }
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Valor (opcional)")
                                .font(.system(size: 15))
                                .fontWeight(.semibold)
                            TextField(pricePlaceholder, text: $valueText)
                                .keyboardType(.decimalPad)
                                .font(.system(size: 17))
                                .characterLimit(TextLimits.price, text: $valueText)
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Quem vai consumir/pagar")
                                .font(.system(size: 15))
                                .fontWeight(.semibold)
                            ResponsibleUserPicker(availableUsers: availableUsers, selectedUsers: $relatedUsers)
                        }

                        Spacer()
                    }
                    .padding(.vertical)
                    .frame(width: geometry.size.width * 0.9)
                }
                .frame(width: geometry.size.width)
            }
            .navigationTitle(isEditing ? "Editar item" : "Novo item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                        .disabled(isSaving)
                }
            }
            .confirmToolbar(
                isLoading: isSaving,
                isDisabled: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ) {
                Task { await save() }
            }
            .disabled(isSaving)
        }
        .interactiveDismissDisabled(isSaving)
        .task {
            populateFromMode()
        }
        .dismissKeyboardOnTap()
        .alert(
            "Não foi possível salvar",
            isPresented: Binding(
                get: { saveErrorMessage != nil },
                set: { if !$0 { saveErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveErrorMessage ?? "")
        }
    }

    /// Currency placeholder in the app's language/region format (e.g. "R$ 0,00").
    private var pricePlaceholder: String {
        0.0.formatted(.currency(code: "BRL").locale(L10n.locale))
    }

    /// Seeds the form's local state from the item being edited
    private func populateFromMode() {
        guard case .edit(let item) = mode else { return }
        name = item.name
        quantity = item.quantity
        unitMeasurement = item.unitMeasurement
        relatedUsers = item.relatedUsers(in: availableUsers)
        if let value = item.value {
            valueText = value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(value)
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        let existingItem: ShopListItem? = {
            if case .edit(let item) = mode { return item }
            return nil
        }()

        // The sheet used to dismiss even when CloudKit rejected the save, silently losing the
        // item. It now stays open and explains what happened.
        let success = await viewModel.saveItem(
            existingItem,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            valueText: valueText,
            quantity: quantity,
            unitMeasurement: unitMeasurement,
            relatedUsers: relatedUsers,
            addedBy: currentUser
        )

        if success {
            HapticsManager.notify(.success)
            dismiss()
        } else {
            saveErrorMessage = viewModel.errorMessage ?? L10n.tr("Tente novamente.")
        }
    }
}

#Preview {
    // MARK: - users
    func makeUser(_ name: String) -> UserModel {
        let user = UserModel(name: name, tier: .tier1, ownerRecordName: "preview-\(name)")
        user.recordID = CKRecord.ID(recordName: "preview-user-\(name)")
        return user
    }

    let jones = makeUser("Jones")
    let isabela = makeUser("Isabela")
    let carol = makeUser("Carol")
    let anshu = makeUser("Anshu")

    // MARK: - items
    func makeItem(
        _ name: String,
        quantity: Int,
        unit: UnitMeasurement = .unit,
        isBought: Bool = false,
        users: [UserModel]
    ) -> ShopListItem {
        let item = ShopListItem(
            name: name,
            quantity: quantity,
            unitMeasurement: unit,
            isBought: isBought,
            relatedUsers: users.compactMap { user in
                user.recordID.map { CKRecord.Reference(recordID: $0, action: .none) }
            }
        )
        item.recordID = CKRecord.ID(recordName: "preview-item-\(UUID().uuidString)")
        return item
    }

    let items = [
        makeItem("Papel higiênico", quantity: 1, unit: .package, users: [jones, isabela, carol]),
        makeItem("Detergente", quantity: 2, unit: .unit, users: [jones, isabela, carol]),
        makeItem("Vassoura", quantity: 1, unit: .unit, users: [jones, isabela, carol]),
        makeItem("Ovos", quantity: 6, unit: .unit, users: [jones]),
        makeItem("Barra de chocolate", quantity: 1, unit: .unit, users: [anshu]),
        makeItem("Veja multiuso", quantity: 1, unit: .unit, isBought: true, users: [jones, isabela, carol])
    ]

    let viewModel = ShopListViewModel(previewItems: items, houseUsers: [jones, isabela, carol, anshu], currentUser: jones)

    return ShopListView(viewModel: viewModel)
}
