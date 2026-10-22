//
//  ShopComplements.swift
//  Cognitive-Work
//
//  Created by anshu Li on 20/10/26.
//

import Foundation
import FoundationModels

// MARK: - "Goes with your list" (on-device model)

/// One product the model suggests adding.
@Generable
nonisolated struct GeneratedComplement {
    @Guide(description: "Short product name")
    var name: String

    var category: GeneratedShopCategory
}

/// Up to three products usually bought together with the ones on the list.
@Generable
nonisolated struct GeneratedComplementList {
    @Guide(description: "Products usually bought together with the ones on the list and missing from it. Empty when nothing clearly fits.", .maximumCount(3))
    var items: [GeneratedComplement]
}

extension IntelligenceManager {

    /// Products that usually go with the ones on the list ("macarrão" -> "molho de tomate").
    ///
    /// - Parameter names: What's still to buy.
    /// - Returns: `nil` when AI is unavailable or the request fails. Names come in the app's
    ///   language, since they're new text shown to the person.
    func suggestComplements(for names: [String]) async -> [(name: String, category: ShopItemCategory)]? {
        let prompt = IntelligencePrompts.ShopComplements.self
        guard let generated = await generate(
            GeneratedComplementList.self,
            prompt: prompt.prompt(for: names),
            instructions: instructions(task: prompt.task, output: .appLanguage),
            promptID: prompt.id
        ) else { return nil }

        return generated.items.compactMap { item in
            let name = String(
                item.name
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .prefix(TextLimits.shopItemName)
            )
            guard !name.isEmpty else { return nil }
            return (name, ShopItemCategory(rawValue: item.category.rawValue) ?? .other)
        }
    }
}
