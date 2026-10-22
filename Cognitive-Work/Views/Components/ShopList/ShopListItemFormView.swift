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
    /// edited values back through `onConfirm` and saves nothing.
    case draft(ShopItemSuggestion, onConfirm: (ShopItemSuggestion) -> Void)
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
    /// A pending item that looks like the same product as the new one; asks whether to add to
    /// its quantity instead of creating a second card.
    @State private var duplicate: ShopListItem?
    @FocusState private var isNameFocused: Bool

    // MARK: Apple Intelligence state

    // The AI button next to the name opens a prompt; what the person describes there
    // ("2kg de arroz") fills name, category, quantity and unit in one go.

    /// Fields the form can pre-fill from an AI suggestion.
    private enum SuggestedField {
        case category, quantity, unit, price, consumers
    }

    /// Whether the AI button shows in this form; set once when it appears (create mode only).
    @State private var canSuggest = false
    /// The last suggestion applied; fields still holding its values show the sparkles icon.
    @State private var suggestion: ShopItemSuggestion?
    /// Whether the AI prompt (``AIItemPromptSheet``) is on screen.
    @State private var isShowingAIPrompt = false
    /// What the person types in the AI prompt.
    @State private var aiInput = ""
    /// Whether a request is running; the button shows a spinner meanwhile.
    @State private var isSuggesting = false
    /// Whether the last request returned nothing; shows a hint to fill in by hand.
    @State private var aiDidFail = false
    /// The running request, cancelled if the sheet closes.
    @State private var suggestionTask: Task<Void, Never>?

    /// Editing a suggestion from the AI review: shows like editing, but nothing is saved here.
    private var isDraft: Bool {
        if case .draft = mode { return true }
        return false
    }

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

                    // Sparkles mark values filled in by the AI button.
                    section("Categoria", isSuggested: isSuggested(.category)) {
                        ShopCategoryPicker(selection: $category)
                    }

                    // Same as above for quantity and unit.
                    section("Quantidade", isSuggested: isSuggested(.quantity) || isSuggested(.unit)) {
                        quantityCard
                    }

                    section("Valor (opcional)", isSuggested: isSuggested(.price)) {
                        priceField
                    }

                    section("Quem vai consumir/pagar", isSuggested: isSuggested(.consumers)) {
                        ResponsibleUserPicker(availableUsers: availableUsers, selectedUsers: $relatedUsers)
                        // How much each person pays, computed in code with the same equal split
                        // as the debts screen.
                        if let shareText {
                            Text(shareText)
                                .font(.system(size: 13))
                                .foregroundStyle(.subTitleGray)
                        }
                    }

                    if isEditing {
                        deleteButton
                    }
                }
                .padding(.horizontal, 22)
                .padding(.vertical)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(isEditing || isDraft ? "Editar item" : "Novo item")
            .navigationBarTitleDisplayMode(.inline)
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
                        .voiceOverLabel(isEditing || isDraft ? L10n.tr("Salvar") : L10n.tr("Adicionar item"))
                        .voiceControlNames(isEditing || isDraft
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
        .task {
            populateFromMode()
            if !isEditing && !isDraft { isNameFocused = true }
            // AI button only when creating, and only if the model can run here.
            canSuggest = !isEditing && !isDraft && viewModel.canSuggestItemDetails
        }
        // No request keeps running after the sheet closes.
        .onDisappear {
            suggestionTask?.cancel()
        }
        // The AI prompt: type or speak the item, check the text, then confirm. The housemates'
        // names help the speech recognizer hear them right.
        .sheet(isPresented: $isShowingAIPrompt) {
            ItemIntelligentSheet(
                text: $aiInput,
                contextualStrings: availableUsers.map(\.name),
                onConfirm: requestSuggestion
            )
        }
        .dismissKeyboardOnTap()
        .onChange(of: visibleWarning) { _, warning in
            if let warning { VoiceOver.announce(warning) }
        }
        // Same product already on the list: add to its quantity, or add a separate item anyway.
        .confirmationDialog(
            duplicateTitle,
            isPresented: Binding(
                get: { duplicate != nil },
                set: { if !$0 { duplicate = nil } }
            ),
            titleVisibility: .visible,
            presenting: duplicate
        ) { existing in
            if existing.unitMeasurement == unitMeasurement {
                Button(L10n.tr("Somar à quantidade (%lld → %lld)", existing.quantity, existing.quantity + quantity)) {
                    Task { await addToExisting(existing) }
                }
            }
            Button(L10n.tr("Adicionar mesmo assim")) {
                Task { await save(checkingDuplicates: false) }
            }
            Button("Cancelar", role: .cancel) {}
        } message: { existing in
            Text(duplicateMessage(for: existing))
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
            Image(systemName: category.symbol)
                .resizable()
                .scaledToFit()
                .frame(width: 54, height: 54)
                .fontWeight(.thin)
                .foregroundStyle(category.color)
                .contentTransition(.symbolEffect(.replace))
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

                // Shown when the AI couldn't fill in the item; the form stays as it was.
                if aiDidFail {
                    Text("Não foi possível preencher. Preencha manualmente.")
                        .font(.system(size: 13))
                        .foregroundStyle(.subTitleGray)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            if canSuggest {
                aiButton
            }
        }
        .animation(.snappy, value: category)
        .animation(.snappy, value: aiDidFail)
    }

    /// Opens the AI prompt, pre-filled with the name typed so far.
    private var aiButton: some View {
        Button {
            aiInput = trimmedName
            aiDidFail = false
            isShowingAIPrompt = true
        } label: {
            Group {
                if isSuggesting {
                    ProgressView()
                } else {
                    Image(systemName: "sparkles")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(category.color)
                }
            }
            .frame(width: 44, height: 44)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .disabled(isSuggesting)
        .voiceOverLabel(L10n.tr("Preencher com IA"))
        .voiceControlNames([L10n.tr("Preencher com IA"), L10n.tr("IA")])
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
    ///
    /// Changed: `isSuggested` shows a sparkles icon next to the title while the block holds
    /// values pre-filled by the on-device model.
    private func section<Content: View>(
        _ title: LocalizedStringKey,
        isSuggested: Bool = false,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 15))
                    .fontWeight(.semibold)
                    .accessibilityAddTraits(.isHeader)

                if isSuggested {
                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.subTitleGray)
                        .transition(.opacity)
                        .voiceOverLabel(L10n.tr("Sugerido automaticamente"))
                }
            }
            .animation(.snappy, value: isSuggested)

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

    // MARK: - Apple Intelligence
    // Added: everything in this section pre-fills the form from the on-device model. Nothing is
    // saved until the person taps confirm, and any failure simply leaves the form as it is.

    /// Whether `field` still shows the value the AI filled in. Once the person changes it, the
    /// value differs and the sparkles icon goes away.
    private func isSuggested(_ field: SuggestedField) -> Bool {
        guard let suggestion else { return false }
        switch field {
        case .category: return category == suggestion.category
        case .quantity: return quantity == suggestion.quantity
        case .unit: return unitMeasurement == suggestion.unit
        case .price:
            guard let unitPrice = suggestion.unitPrice else { return false }
            return valueText == ShopListViewModel.priceInputText(for: unitPrice)
        case .consumers:
            guard let consumers = suggestion.consumers else { return false }
            return Set(relatedUsers.map(\.id)) == Set(consumers.map(\.id))
        }
    }

    /// "R$ 12,50 por pessoa": the item's total split equally between the people it's for, rounded
    /// to cents like ``DebtCalculator``. `nil` without a price or without anyone selected.
    private var shareText: String? {
        ShopListViewModel.shareText(
            unitPrice: ShopListViewModel.parsePrice(valueText),
            quantity: quantity,
            consumerCount: relatedUsers.count
        )
    }

    /// Sends what the person typed in the AI prompt to the on-device model.
    private func requestSuggestion() {
        let input = aiInput
        suggestionTask?.cancel()
        suggestionTask = Task {
            isSuggesting = true
            defer { isSuggesting = false }

            let result = await viewModel.suggestItemDetails(
                for: input,
                housemates: availableUsers,
                currentUser: currentUser,
                selectedConsumers: relatedUsers
            )
            guard !Task.isCancelled else { return }

            if let result {
                applySuggestion(result)
            } else {
                aiDidFail = true
                VoiceOver.announce(L10n.tr("Não foi possível preencher. Preencha manualmente."))
            }
        }
    }

    /// Fills name, category, quantity and unit, plus price and people when the person mentioned
    /// them. The person asked for it with the button, so those fields are replaced; they can still
    /// change any of them before saving.
    private func applySuggestion(_ result: ShopItemSuggestion) {
        suggestion = result
        withAnimation(.snappy) {
            if !result.name.isEmpty { name = result.name }
            category = result.category
            quantity = result.quantity
            unitMeasurement = result.unit
            if let unitPrice = result.unitPrice {
                valueText = ShopListViewModel.priceInputText(for: unitPrice)
            }
            if let consumers = result.consumers {
                relatedUsers = consumers
            }
        }
        HapticsManager.notify(.success)
    }

    // MARK: - Actions

    /// Currency placeholder in the app's language/region format (e.g. "R$ 0,00").
    private var pricePlaceholder: String {
        L10n.tr("Preço por unidade (R$ 0,00)")
    }

    /// Seeds the form's local state from the item being edited.
    private func populateFromMode() {
        // A draft from the AI review fills the form with the suggestion's values. People not
        // mentioned show as the whole house, the same default the review uses when saving.
        if case .draft(let suggestion, _) = mode {
            name = suggestion.name
            category = suggestion.category
            quantity = suggestion.quantity
            unitMeasurement = suggestion.unit
            relatedUsers = suggestion.consumers ?? availableUsers
            if let unitPrice = suggestion.unitPrice {
                valueText = ShopListViewModel.priceInputText(for: unitPrice)
            }
            return
        }

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

    /// Saves the form.
    ///
    /// - Parameter checkingDuplicates: When creating, first look for the same product already on
    ///   the list (``ShopListViewModel/duplicateItem(named:)``). `false` after the person chose
    ///   "add anyway".
    private func save(checkingDuplicates: Bool = true) async {
        // A draft goes back to the AI review with the edited values; nothing reaches CloudKit yet.
        if case .draft(let original, let onConfirm) = mode {
            let price = ShopListViewModel.parsePrice(valueText) ?? 0
            onConfirm(ShopItemSuggestion(
                input: original.input,
                name: trimmedName,
                quantity: quantity,
                unit: unitMeasurement,
                category: category,
                unitPrice: price > 0 ? price : nil,
                consumers: relatedUsers
            ))
            HapticsManager.notify(.success)
            dismiss()
            return
        }

        isSaving = true
        defer { isSaving = false }

        // New item: check first whether the same product is already waiting to be bought.
        if checkingDuplicates, case .create = mode,
           let existing = await viewModel.duplicateItem(named: trimmedName) {
            duplicate = existing
            return
        }

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

    /// Adds this form's quantity to the item already on the list instead of creating a new one.
    private func addToExisting(_ existing: ShopListItem) async {
        isSaving = true
        defer { isSaving = false }

        // The people chosen here join the existing item's split if they aren't in it yet.
        if await viewModel.merge(into: existing, adding: quantity, consumers: relatedUsers) {
            HapticsManager.notify(.success)
            VoiceOver.announce(L10n.tr("Quantidade atualizada"))
            dismiss()
        } else {
            saveErrorMessage = viewModel.errorMessage ?? L10n.tr("Tente novamente.")
        }
    }

    /// Explains the choice, and who will join the split when quantities are added.
    private func duplicateMessage(for existing: ShopListItem) -> String {
        guard existing.unitMeasurement == unitMeasurement else {
            return L10n.tr("O item que já está na lista usa outra unidade.")
        }
        let joining = viewModel.newConsumers(relatedUsers, for: existing)
        guard !joining.isEmpty else {
            return L10n.tr("Você pode somar a quantidade ao item que já está na lista.")
        }
        return L10n.tr("Você pode somar a quantidade ao item que já está na lista.")
            + "\n"
            + L10n.tr("Também entram na divisão: %@", joining.map(\.name).joined(separator: ", "))
    }

    /// "“leite” is already on the list".
    private var duplicateTitle: String {
        guard let duplicate else { return "" }
        return L10n.tr("Já tem “%@” na lista", duplicate.name)
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
