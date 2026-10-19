//
//  AddMoreShoppingListInteligence.swift
//  Cognitive-Work
//
//  Created by anshu Li on 19/10/26.
//

import SwiftUI

/// Adds several shopping items at once with the on-device model.
///
/// Two steps in one sheet: the person writes or dictates the items (one per line), then reviews
/// the cards the model made and unticks any it got wrong. Nothing is saved until they confirm,
/// and saving goes through ``ShopListViewModel/addSuggestedItems(_:)``, so validation and points
/// are the same as adding by hand.
struct AddMoreItensInteligence: View {

    var viewModel: ShopListViewModel

    @Environment(\.dismiss) private var dismiss

    /// What the person typed or dictated.
    @State private var text = ""
    /// The items the model found; `nil` while still on the writing step.
    @State private var suggestions: [ShopItemSuggestion]?
    /// Positions in ``suggestions`` the person keeps (all of them by default).
    @State private var included: Set<Int> = []
    @State private var isGenerating = false
    @State private var isSaving = false
    /// Shown under the text field (nothing found) or above the button (a save failed).
    @State private var errorText: String?
    @FocusState private var isTextFocused: Bool
    /// Speech for the writing step; each recording adds a line to the list.
    @State private var voice = VoiceInputManager()
    /// The suggestion being edited in ``ShopListItemFormView`` (its position in ``suggestions``).
    @State private var editing: EditingDraft?

    /// Identifies the suggestion opened for editing, for `.sheet(item:)`.
    private struct EditingDraft: Identifiable {
        let id: Int
    }

    private var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Group {
                if let suggestions {
                    review(suggestions)
                } else {
                    writing
                }
            }
            .navigationTitle("Adicionar com IA")
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
            }
        }
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(isSaving)
        .dismissKeyboardOnTap()
        // The arrow on a card opens the usual item form; confirming replaces that suggestion.
        .sheet(item: $editing) { draft in
            if let suggestions, suggestions.indices.contains(draft.id) {
                ShopListItemFormView(
                    mode: .draft(suggestions[draft.id], onConfirm: { edited in
                        self.suggestions?[draft.id] = edited
                        included.insert(draft.id)
                    }),
                    availableUsers: viewModel.houseUsers,
                    currentUser: viewModel.currentUser,
                    viewModel: viewModel
                )
            }
        }
    }

    // MARK: - Step 1: writing

    private var writing: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Escreva um item por linha, com quantidade, preço e para quem é.")
                .font(.system(size: 15))
                .foregroundStyle(.subTitleGray)

            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text("Ex.:\n2kg de arroz, R$ 25, eu e Ana\ndetergente para todos\n1 L de leite")
                        .foregroundStyle(.gray.opacity(0.6))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 8)
                        .accessibilityHidden(true)
                }

                TextEditor(text: $text)
                    .scrollContentBackground(.hidden)
                    .focused($isTextFocused)
                    // Locked while speech is still turning into text.
                    .disabled(voice.isBusy)
                    .voiceOverLabel(L10n.tr("Escreva um item por linha, com quantidade, preço e para quem é."))
            }
            .font(.system(size: 17))
            .frame(minHeight: 180)
            .padding(12)
            .background(
                Color(.systemGray6).opacity(0.5),
                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
            )

            if let errorText {
                Text(errorText)
                    .font(.system(size: 13))
                    .foregroundColor(.red)
            }

            // Say the items instead of typing; each recording becomes a new line, and the text
            // can still be fixed before generating the cards.
            VoiceInputControls(
                text: $text,
                voice: voice,
                contextualStrings: viewModel.houseUsers.map(\.name),
                appendsToText: true,
                onStart: { isTextFocused = false }
            )

            Spacer()

            primaryButton(
                title: L10n.tr("Gerar itens"),
                isLoading: isGenerating,
                isEnabled: trimmedText.count >= 3 && !voice.isBusy
            ) {
                Task { await generate() }
            }
        }
        .padding(22)
        .task { isTextFocused = true }
    }

    // MARK: - Step 2: review

    private func review(_ suggestions: [ShopItemSuggestion]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Revise os itens antes de adicionar.")
                .font(.system(size: 15))
                .foregroundStyle(.subTitleGray)
                .padding(.horizontal, 22)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    ForEach(Array(suggestions.enumerated()), id: \.offset) { index, suggestion in
                        reviewRow(
                            suggestion,
                            isIncluded: included.contains(index),
                            toggle: {
                                HapticsManager.selection()
                                if included.contains(index) {
                                    included.remove(index)
                                } else {
                                    included.insert(index)
                                }
                            },
                            edit: {
                                HapticsManager.selection()
                                editing = EditingDraft(id: index)
                            }
                        )
                    }
                }
                .padding(.horizontal, 22)
            }

            VStack(spacing: 10) {
                if let errorText {
                    Text(errorText)
                        .font(.system(size: 13))
                        .foregroundColor(.red)
                }

                primaryButton(
                    title: L10n.tr("Adicionar itens (%lld)", included.count),
                    isLoading: isSaving,
                    isEnabled: !included.isEmpty
                ) {
                    Task { await save(suggestions) }
                }

                // Back to the text, kept as typed, to fix it and try again.
                Button("Editar texto") {
                    errorText = nil
                    withAnimation(.snappy) { self.suggestions = nil }
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.titleGray)
                .disabled(isSaving)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 22)
        }
        .padding(.top, 22)
    }

    /// One proposed item. The checkbox in front includes or leaves it out; the rest of the card,
    /// with the arrow at the end, opens it in the item form to fix anything before adding.
    private func reviewRow(
        _ suggestion: ShopItemSuggestion,
        isIncluded: Bool,
        toggle: @escaping () -> Void,
        edit: @escaping () -> Void
    ) -> some View {
        // Same default as saving: no one mentioned means the whole house.
        let consumers = suggestion.consumers ?? viewModel.houseUsers
        let category = suggestion.category

        return HStack(spacing: 12) {
            Button(action: toggle) {
                Image(systemName: isIncluded ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundStyle(isIncluded ? category.color : Color.gray.opacity(0.5))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .voiceOverLabel(L10n.tr("Incluir %@", suggestion.name))
            .voiceOverTraits(.isSelected, when: isIncluded)
            .voiceControlNames([L10n.tr("Incluir %@", suggestion.name)])

            Button(action: edit) {
                HStack(spacing: 12) {
                    Image(systemName: category.symbol)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(category.color)
                        .frame(width: 40, height: 40)
                        .background(
                            category.softColor.opacity(0.45),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(suggestion.name)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.titleGray)

                        Text(detailText(for: suggestion))
                            .font(.system(size: 13))
                            .foregroundStyle(.subTitleGray)

                        // Say when the house is only the default, so a misread "para mim" is easy
                        // to spot before saving.
                        if suggestion.consumers == nil {
                            Text("Para: todos (não informado)")
                                .font(.system(size: 13))
                                .foregroundStyle(.orange)
                        } else if !consumers.isEmpty {
                            Text(L10n.tr("Para: %@", consumers.map(\.name).joined(separator: ", ")))
                                .font(.system(size: 13))
                                .foregroundStyle(.subTitleGray)
                        }

                        if let share = ShopListViewModel.shareText(
                            unitPrice: suggestion.unitPrice,
                            quantity: suggestion.quantity,
                            consumerCount: consumers.count
                        ) {
                            Text(share)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.titleGray)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.subTitleGray)
                        .accessibilityHidden(true)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .voiceOverHint(L10n.tr("Toque duas vezes para editar."))
            .voiceControlNames([L10n.tr("Editar %@", suggestion.name)])
        }
        .padding(.vertical, 12)
        .padding(.leading, 6)
        .padding(.trailing, 14)
        .background(
            Color(.systemGray6).opacity(0.5),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .opacity(isIncluded ? 1 : 0.5)
    }

    /// "2 quilogramas · Alimentos · R$ 25,00".
    private func detailText(for suggestion: ShopItemSuggestion) -> String {
        var parts = [
            "\(suggestion.quantity) \(suggestion.unit.getDisplayName(for: Double(suggestion.quantity)))",
            suggestion.category.displayName
        ]
        if let unitPrice = suggestion.unitPrice {
            let format = FloatingPointFormatStyle<Double>.Currency(code: "BRL").locale(L10n.locale)
            parts.append((unitPrice * Double(suggestion.quantity)).formatted(format))
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - Buttons

    private func primaryButton(
        title: String,
        isLoading: Bool,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Group {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(title)
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.glassProminent)
        .tint(.black)
        .disabled(!isEnabled || isLoading)
    }

    // MARK: - Actions

    /// Asks the model for the items; on success moves to the review step with all of them ticked.
    private func generate() async {
        isGenerating = true
        errorText = nil
        isTextFocused = false
        defer { isGenerating = false }

        guard let result = await viewModel.suggestItems(from: trimmedText), !result.isEmpty else {
            let message = L10n.tr("Nenhum item encontrado. Tente escrever de outro jeito.")
            errorText = message
            VoiceOver.announce(message)
            HapticsManager.notify(.error)
            return
        }

        withAnimation(.snappy) {
            included = Set(result.indices)
            suggestions = result
        }
        HapticsManager.notify(.success)
    }

    /// Saves the ticked items. If one fails, the ones already saved leave the list, so trying
    /// again never adds them twice.
    private func save(_ all: [ShopItemSuggestion]) async {
        isSaving = true
        errorText = nil
        defer { isSaving = false }

        let chosenIndices = all.indices.filter { included.contains($0) }
        let chosen = chosenIndices.map { all[$0] }
        let savedCount = await viewModel.addSuggestedItems(chosen)

        if savedCount == chosen.count {
            HapticsManager.notify(.success)
            dismiss()
            return
        }

        // Keep only what wasn't saved: the unticked items and the chosen ones from the failure on.
        let savedIndices = Set(chosenIndices.prefix(savedCount))
        let remaining = all.indices.filter { !savedIndices.contains($0) }
        let stillIncluded = Set(remaining.enumerated().compactMap { newIndex, oldIndex in
            included.contains(oldIndex) ? newIndex : nil
        })
        suggestions = remaining.map { all[$0] }
        included = stillIncluded
        errorText = viewModel.errorMessage ?? L10n.tr("Tente novamente.")
        viewModel.clearError()
        HapticsManager.notify(.error)
    }
}

