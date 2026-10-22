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
    /// Adds a new item.
    case create
    /// Edits (or deletes) this item.
    case edit(ShopListItem)
}

/// The sheet used to add a shopping item or edit an existing one: name, category, quantity and
/// unit, an optional price and who it's for. When editing it can also delete the item.
struct ShopListItemFormView: View {

    /// Whether it creates a new item or edits one.
    var mode: ShopListItemFormMode
    /// The members that can be picked as who the item is for.
    var availableUsers: [UserModel]
    /// The signed-in member, saved as who added the item.
    var currentUser: UserModel?
    /// Saves and deletes the item.
    var viewModel: ShopListViewModel

    /// Closes the sheet.
    @Environment(\.dismiss) private var dismiss

    /// The item's name being typed.
    @State private var name: String = ""
    /// The chosen category.
    @State private var category: ShopItemCategory = .default
    /// How many.
    @State private var quantity: Int = 1
    /// The unit (unit, kg, liter, ...).
    @State private var unitMeasurement: UnitMeasurement = .unit
    /// The price per unit as typed (optional).
    @State private var valueText: String = ""
    /// Who the item is for (they split the cost).
    @State private var relatedUsers: [UserModel] = []
    /// `true` while saving or deleting (locks the form).
    @State private var isSaving = false
    /// Error shown when saving or deleting fails.
    @State private var saveErrorMessage: String?
    /// Shows the "delete item?" dialog.
    @State private var isConfirmingDelete = false
    /// Focuses the name field when adding a new item.
    @FocusState private var isNameFocused: Bool

    /// Whether the sheet edits an existing item.
    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    /// The name without spaces at the ends.
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

    /// Whether a price above zero was typed.
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
                    // MARK: - Form sections
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
            // MARK: - Toolbar: close and confirm
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .disabled(isSaving)
                    .voiceOverLabel(L10n.tr("Cancelar"))
                    .voiceControlNames([L10n.tr("Fechar"), L10n.tr("Cancelar")])
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
                        .voiceOverLabel(isEditing ? L10n.tr("Salvar") : L10n.tr("Adicionar item"))
                        .voiceControlNames(isEditing
                            ? [L10n.tr("Confirmar"), L10n.tr("Salvar"), L10n.tr("OK")]
                            : [L10n.tr("Confirmar"), L10n.tr("Adicionar item"), L10n.tr("OK")])
                        .voiceOverHint(missingFields.first?.warning ?? "")
                    }
                }
            }
            .disabled(isSaving)
        }
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(isSaving)
        // MARK: - Loading, VoiceOver warnings, delete dialog and error alert
        .task {
            populateFromMode()
            if !isEditing { isNameFocused = true }
        }
        .dismissKeyboardOnTap()
        .onChange(of: visibleWarning) { _, warning in
            if let warning { VoiceOver.announce(warning) }
        }
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
            SymbolImage(name: category.symbol)
                .frame(width: 64, height: 64)
                .foregroundStyle(category.color)
                .padding(.leading, 6)
                .accessibilityHidden(true)

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
                .voiceOverLabel(L10n.tr("Nome do item"))
                .voiceControlNames([L10n.tr("Nome do item"), L10n.tr("Nome")])

                Capsule()
                    .frame(height: 1.5)
                    .foregroundStyle(.gray.opacity(0.5))
                    .accessibilityHidden(true)
            }
        }
        .animation(.snappy, value: category)
    }

    /// The warning on screen, if any; VoiceOver announces it whenever it appears or changes.
    private var visibleWarning: String? {
        trimmedName.isEmpty ? nil : missingFields.first?.warning
    }

    /// Explains why the confirm button is disabled, near the top so it shows without scrolling.
    /// Like the chore form, it names one thing at a time and waits for the name first.
    @ViewBuilder
    private var validationWarning: some View {
        if let warning = visibleWarning {
            Text(warning)
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
                .accessibilityAddTraits(.isHeader)

            content()
        }
    }

    /// Stepper and unit menu on one soft card.
    private var quantityCard: some View {
        VStack(spacing: 16) {
            QuantityStepper(
                value: $quantity,
                valueDescription: { ShopListViewModel.accessibilityQuantity($0, unit: unitMeasurement) }
            )
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
                .voiceOverLabel(L10n.tr("Unidade"))
                .voiceOverValue(unitMeasurement.getDisplayName(for: Double(quantity)))
                .voiceControlNames([
                    L10n.tr("Unidade"),
                    unitMeasurement.getDisplayName(for: Double(quantity)).capitalized(with: L10n.locale)
                ])
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            Color(.systemGray6).opacity(0.5),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
    }

    /// The price field.
    private var priceField: some View {
        HStack(spacing: 10) {
            Image(systemName: "tag")
                .foregroundStyle(.subTitleGray)
                .accessibilityHidden(true)

            TextField(pricePlaceholder, text: $valueText)
                .priceInput(text: $valueText)
                .font(.system(size: 17))
                .voiceOverLabel(L10n.tr("Preço por unidade"))
                .voiceOverValue(ShopListViewModel.accessibilityPrice(valueText))
                // Voice Control: "Toque em Preço", then dictate the value.
                .voiceControlNames([L10n.tr("Preço por unidade"), L10n.tr("Preço"), L10n.tr("Valor")])
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            Color(.systemGray6).opacity(0.5),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
    }

    /// The "Excluir item" button (edit mode only).
    private var deleteButton: some View {
        Button(role: .destructive) {
            isConfirmingDelete = true
        } label: {
            Label("Excluir item", systemImage: "trash")
                .fontWeight(.semibold)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .voiceControlNames([L10n.tr("Excluir item"), L10n.tr("Excluir")])
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

    /// Saves the item; closes the sheet on success or shows the error.
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

    /// Deletes the item; closes the sheet on success or shows the error.
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
