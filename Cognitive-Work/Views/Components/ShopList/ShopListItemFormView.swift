//
//  ShopListItemFormView.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 08/10/26.
//

import SwiftUI
import CloudKit

/// Which action ``ShopListItemFormView`` performs on confirm.
enum ShopListItemFormMode {
    case create
    case edit(ShopListItem)
}

/// The sheet used to add a shopping item or edit an existing one.
struct ShopListItemFormView: View {

    var mode: ShopListItemFormMode
    var availableUsers: [UserModel]
    var currentUser: UserModel?
    var viewModel: ShopListViewModel

    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var category: ShopItemCategory = .default
    @State private var quantity: Int = 1
    @State private var unitMeasurement: UnitMeasurement = .unit
    @State private var valueText: String = ""
    @State private var relatedUsers: [UserModel] = []
    @State private var isSaving = false
    @State private var saveErrorMessage: String?
    @State private var isConfirmingDelete = false
    @FocusState private var isNameFocused: Bool

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Required fields still empty or invalid; the confirm button stays disabled until none is.
    private var missingFields: [ShopItemField] {
        ShopListViewModel.missingFields(
            name: name,
            quantity: quantity,
            unitMeasurement: unitMeasurement,
            category: category,
            relatedUsers: relatedUsers
        )
    }

    private var hasPrice: Bool {
        (Double(valueText.replacingOccurrences(of: ",", with: ".")) ?? 0) > 0
    }

    /// Points saving a new item will earn (the same figure ``ShopListViewModel`` awards).
    private var previewPoints: Int {
        ShopListViewModel.creationScore(
            beneficiaries: relatedUsers.count,
            hasPrice: hasPrice
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 26) {
                    header

                    validationWarning

                    section("Categoria") {
                        ShopCategoryPicker(selection: $category)
                    }

                    section("Quantidade") {
                        quantityCard
                    }

                    section("Valor (opcional)") {
                        priceField
                    }

                    section("Quem vai consumir/pagar") {
                        ResponsibleUserPicker(availableUsers: availableUsers, selectedUsers: $relatedUsers)
                    }

                    if isEditing {
                        deleteButton
                    }
                }
                .padding(.horizontal, 22)
                .padding(.vertical)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(isEditing ? "Editar item" : "Novo item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .disabled(isSaving)
                }

                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button {
                            Task { await save() }
                        } label: {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12))
                                .bold()
                                .foregroundColor(.white)
                        }
                        .tint(.blue)
                        .buttonStyle(.glassProminent)
                        .disabled(!missingFields.isEmpty)
                    }
                }
            }
            .disabled(isSaving)
        }
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(isSaving)
        .task {
            populateFromMode()
            if !isEditing { isNameFocused = true }
        }
        .dismissKeyboardOnTap()
        .confirmationDialog("Excluir item?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("Excluir item", role: .destructive) {
                Task { await deleteItem() }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Essa ação não pode ser desfeita.")
        }
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

    // MARK: - Sections

    /// The category's icon beside the name field, like the chore editor's header.
    private var header: some View {
        HStack(spacing: 18) {
            Image(systemName: category.symbol)
                .resizable()
                .scaledToFit()
                .frame(width: 54, height: 54)
                .fontWeight(.thin)
                .foregroundStyle(category.color)
                .contentTransition(.symbolEffect(.replace))
                .padding(.leading, 6)

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
                .focused($isNameFocused)

                Capsule()
                    .frame(height: 1.5)
                    .foregroundStyle(.gray.opacity(0.5))
            }
        }
        .animation(.snappy, value: category)
    }

    /// Explains why the confirm button is disabled, near the top so it shows without scrolling.
    /// Like the chore form, it names one thing at a time and waits for the name first.
    @ViewBuilder
    private var validationWarning: some View {
        if !trimmedName.isEmpty, let next = missingFields.first {
            Text(next.warning)
                .font(.system(size: 13))
                .foregroundColor(.red)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    /// A titled block of the form.
    private func section<Content: View>(
        _ title: LocalizedStringKey,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 15))
                .fontWeight(.semibold)

            content()
        }
    }

    /// Stepper and unit menu on one soft card.
    private var quantityCard: some View {
        VStack(spacing: 16) {
            QuantityStepper(value: $quantity)
                .frame(maxWidth: .infinity)

            Divider()

            HStack {
                (Text("Unidade"))
                    .font(.system(size: 15))
                    .fontWeight(.semibold)

                Spacer()

                Menu {
                    Picker("Unidade", selection: $unitMeasurement) {
                        ForEach(UnitMeasurement.allCases.filter { $0 != .undefined }) { unit in
                            Text(unit.getDisplayName(for: Double(quantity))).tag(unit)
                        }
                    }
                } label: {
                    HStack {
                        CapsuleTag(
                            tagName: unitMeasurement.getDisplayName(for: Double(quantity)).capitalized(with: L10n.locale),
                            tagColor: category.color,
                            horizontalPadding: 10,
                            verticalPadding: 1.5
                        )

                        Image(systemName: "chevron.up.chevron.down")
                            .foregroundColor(.black)
                            .imageScale(.small)
                    }
                    .fixedSize()
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            Color(.systemGray6).opacity(0.5),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
    }

    private var priceField: some View {
        HStack(spacing: 10) {
            Image(systemName: "tag")
                .foregroundStyle(.subTitleGray)

            TextField(pricePlaceholder, text: $valueText)
                .priceInput(text: $valueText)
                .font(.system(size: 17))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            Color(.systemGray6).opacity(0.5),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            isConfirmingDelete = true
        } label: {
            Label("Excluir item", systemImage: "trash")
                .fontWeight(.semibold)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .disabled(isSaving)
    }

    // MARK: - Actions

    /// Currency placeholder in the app's language/region format (e.g. "R$ 0,00").
    private var pricePlaceholder: String {
        L10n.tr("Preço por unidade (R$ 0,00)")
    }

    /// Seeds the form's local state from the item being edited.
    private func populateFromMode() {
        guard case .edit(let item) = mode else { return }
        name = item.name
        category = item.category
        quantity = item.quantity
        unitMeasurement = item.unitMeasurement == .undefined ? .unit : item.unitMeasurement
        relatedUsers = item.relatedUsers(in: availableUsers)
        if let value = item.value {
            valueText = ShopListViewModel.priceInputText(for: value)
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        let existingItem: ShopListItem? = {
            if case .edit(let item) = mode { return item }
            return nil
        }()

        let success = await viewModel.saveItem(
            existingItem,
            name: trimmedName,
            valueText: valueText,
            quantity: quantity,
            unitMeasurement: unitMeasurement,
            category: category,
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

    private func deleteItem() async {
        guard case .edit(let item) = mode else { return }
        isSaving = true
        defer { isSaving = false }

        if await viewModel.deleteItem(item) {
            HapticsManager.notify(.warning)
            dismiss()
        } else {
            saveErrorMessage = viewModel.errorMessage ?? L10n.tr("Tente novamente.")
        }
    }
}

// MARK: - Previews

#Preview("Novo item") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            ShopListItemFormView(
                mode: .create,
                availableUsers: ShopListPreviewData.users,
                currentUser: ShopListPreviewData.jones,
                viewModel: ShopListPreviewData.populatedViewModel
            )
        }
}
