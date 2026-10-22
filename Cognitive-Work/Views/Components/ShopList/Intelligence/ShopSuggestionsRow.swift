//
//  ShopSuggestionsRow.swift
//  Cognitive-Work
//
//  Created by anshu Li on 20/10/26.
//

import SwiftUI

/// "Pode estar faltando": one-tap chips under the list page's header. Each chip adds its product
/// (see ``ShopListSuggestionsModel``); a long press hides it for now. Hidden when there's
/// nothing to suggest.
struct ShopSuggestionsRow: View {

    var model: ShopListSuggestionViewModel

    @State private var addingID: String?

    var body: some View {
        if !model.suggestions.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Pode estar faltando")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.subTitleGray)
                    .padding(.horizontal, 30)
                    .accessibilityAddTraits(.isHeader)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(model.suggestions) { suggestion in
                            chip(for: suggestion)
                        }
                    }
                    .padding(.horizontal, 30)
                    .padding(.vertical, 2)
                }
            }
            .transition(.opacity)
        }
    }

    private func chip(for suggestion: ShopListSuggestion) -> some View {
        let category = suggestion.category

        return Button {
            Task { await add(suggestion) }
        } label: {
            HStack(spacing: 6) {
                if addingID == suggestion.id {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: icon(for: suggestion.kind))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(category.color)
                }

                Text(suggestion.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.titleGray)

                if case .usual(let days) = suggestion.kind {
                    Text(L10n.tr("~%lld d", days))
                        .font(.system(size: 12))
                        .foregroundStyle(.subTitleGray)
                }

                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.titleGray)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Capsule().fill(category.softColor.opacity(0.45)))
        }
        .buttonStyle(.plain)
        .disabled(addingID != nil)
        .contextMenu {
            Button {
                withAnimation(.snappy) { model.dismiss(suggestion) }
            } label: {
                Label(L10n.tr("Não sugerir agora"), systemImage: "eye.slash")
            }
        }
        .voiceOverLabel(L10n.tr("Adicionar %@", suggestion.name))
        .voiceOverHint(hint(for: suggestion.kind))
        .voiceControlNames([L10n.tr("Adicionar %@", suggestion.name), suggestion.name])
        .accessibilityAction(named: Text(verbatim: L10n.tr("Não sugerir agora"))) {
            withAnimation(.snappy) { model.dismiss(suggestion) }
        }
    }

    private func icon(for kind: ShopListSuggestion.Kind) -> String {
        switch kind {
        case .usual: return "clock.arrow.circlepath"
        case .goesWithList: return "sparkles"
        }
    }

    /// Why it's suggested, for VoiceOver.
    private func hint(for kind: ShopListSuggestion.Kind) -> String {
        switch kind {
        case .usual(let days): return L10n.tr("Costuma entrar na lista a cada %lld dias.", days)
        case .goesWithList: return L10n.tr("Combina com o que está na lista.")
        }
    }

    private func add(_ suggestion: ShopListSuggestion) async {
        addingID = suggestion.id
        defer { addingID = nil }
        if await model.add(suggestion) {
            HapticsManager.notify(.success)
            VoiceOver.announce(L10n.tr("%@ adicionado", suggestion.name))
        } else {
            HapticsManager.notify(.error)
        }
    }
}
