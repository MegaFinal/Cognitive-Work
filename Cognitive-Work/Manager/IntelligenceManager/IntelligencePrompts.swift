//
//  IntelligencePrompts.swift
//  Cognitive-Work
//
//  Created by anshu Li on 16/10/26.
//

import Foundation

/// Every prompt the app sends to the on-device model, in one place.
///
/// Prompts are written in English: the model accepts prompts, instructions and output in
/// different languages, and ``IntelligenceManager/instructions(task:output:)`` sets the output
/// language from the app's current language.
///
/// Versioning: the on-device model changes with OS updates, so each prompt has an id such as
/// `shop-item-parse-v1`. When a new OS needs a different prompt, add a `v2` next to `v1` and
/// choose between them with `#available`, keeping `v1` for older systems. Re-run the prompt
/// tests after every OS update.
enum IntelligencePrompts {

    /// Turns one shopping-list entry ("2kg de arroz, R$ 25, eu e Ana") into name, quantity, unit,
    /// category, price and who splits it.
    enum ShopItemParse {

        static let id = "shop-item-parse-v1"

        /// The unit, category, priceKind and sharing names match the cases of the `Generated…`
        /// enums in ShopItemSuggestion.swift; keep them in sync.
        /// Rules for every field of one item. Shared with ``ShopListParse`` so both read prices,
        /// units and people the same way.
        static let fieldRules = """
        name: the product only, without amount or unit, short (at most 18 characters).
        quantity and unit: the amount the person wrote. If they wrote no amount, use quantity 1 and unit.
        Convert fractions to gram or milliliter, for example "meio quilo" is 500 gram.
        Use package for packs, boxes, bags and bundles.
        category is the supermarket section:
        food: groceries and packaged food, including meat, dairy and bread.
        produce: fresh fruits, vegetables and herbs.
        drinks: water, juice, soda, coffee, tea, beer and wine.
        cleaning: products to clean the house, dishes and clothes.
        hygiene: personal care products and toilet paper.
        home: household items such as light bulbs, batteries and kitchen tools.
        pets: pet food and pet supplies.
        other: anything else.
        price: the price the person wrote, as a number ("R$ 12,50" is 12.5). If there is no price, use price 0 and priceKind none.
        A price written without "cada", "a unidade", "o quilo", "por pessoa" or "each" is the total for the whole amount: "6 bananas, 5 reais" is 5 for all six bananas.
        priceKind: perPerson when the price is what each person pays ("por pessoa", "cada um paga", "para cada um", "per person", "each pays"); perUnit only when the price names the product or the unit ("5 reais cada banana", "5 reais a unidade", "5 reais o quilo", "each one costs"); otherwise total. When "cada um" comes right after a price and no product or unit is named, it means each person: use perPerson.
        sharing: everyone when the item is for the whole house ("para todos", "para todas", "para a casa", "for everyone"); specificPeople when the person says who it is for, even if it is only themselves ("para mim", "só eu", "for me"); otherwise notSaid.
        people: names from the housemates list, written exactly as in the list. Leave it empty unless sharing is specificPeople.
        includesSelf: true when the person typing includes themselves ("eu", "para mim", "me", "I").
        """

        /// Worked examples, one item per line. Shared with ``ShopListParse``: the small model
        /// follows examples more than rules.
        static let examples = """
        "2kg de arroz" -> name "arroz", quantity 2, unit kilogram, category food, priceKind none, price 0, sharing notSaid
        "detergente R$ 8 para todos" -> name "detergente", quantity 1, unit unit, category cleaning, priceKind total, price 8, sharing everyone
        "6 bananas 1 real cada, eu e Ana" -> name "bananas", quantity 6, unit unit, category produce, priceKind perUnit, price 1, sharing specificPeople, people ["Ana"], includesSelf true
        "2 pacotes de papel higiênico" -> name "papel higiênico", quantity 2, unit package, category hygiene, priceKind none, price 0, sharing notSaid
        "6 bananas, 1 real por pessoa, eu e Ana" -> name "bananas", quantity 6, unit unit, category produce, priceKind perPerson, price 1, sharing specificPeople, people ["Ana"], includesSelf true
        "6 bananas, 8 reais para cada um" -> name "bananas", quantity 6, unit unit, category produce, priceKind perPerson, price 8, sharing notSaid
        "dog food $30 for Ana" -> name "dog food", quantity 1, unit unit, category pets, priceKind total, price 30, sharing specificPeople, people ["Ana"], includesSelf false
        "6 bananas, 5 reais para mim" -> name "bananas", quantity 6, unit unit, category produce, priceKind total, price 5, sharing specificPeople, people [], includesSelf true
        """

        static let task = """
        You fill in one item of a household shopping list from what the person typed.
        \(fieldRules)
        Examples:
        \(examples)
        """

        /// The person's text and the housemates' names go here, never in the instructions.
        static func prompt(for entry: String, housemates: [String], currentUserName: String?) -> String {
            var lines: [String] = []
            if !housemates.isEmpty {
                lines.append("Housemates: \(housemates.joined(separator: ", "))")
            }
            if let currentUserName {
                lines.append("The person typing is: \(currentUserName)")
            }
            lines.append("Shopping list entry: \(entry)")
            return lines.joined(separator: "\n")
        }
    }

    /// Turns a text with several products, one per line, into a list of items. Used by the AI
    /// button on the shopping list page.
    enum ShopListParse {

        static let id = "shop-list-parse-v1"

        static let task = """
        You turn what the person typed into household shopping list items, one item per product, in the order written.
        Each line is usually one product. Products can also be separated by ";".
        A price or names that follow a product belong to that product. "eu e Ana" names people, not two products.
        Fill in each item with these rules:
        \(ShopItemParse.fieldRules)
        Examples of single items:
        \(ShopItemParse.examples)
        Example of a list:
        "2kg de arroz, R$ 25, eu e Ana
        detergente para todos
        1 L de leite" -> three items:
        name "arroz", quantity 2, unit kilogram, category food, priceKind total, price 25, sharing specificPeople, people ["Ana"], includesSelf true
        name "detergente", quantity 1, unit unit, category cleaning, priceKind none, price 0, sharing everyone
        name "leite", quantity 1, unit liter, category food, priceKind none, price 0, sharing notSaid
        """

        /// The person's text and the housemates' names go here, never in the instructions.
        static func prompt(for text: String, housemates: [String], currentUserName: String?) -> String {
            var lines: [String] = []
            if !housemates.isEmpty {
                lines.append("Housemates: \(housemates.joined(separator: ", "))")
            }
            if let currentUserName {
                lines.append("The person typing is: \(currentUserName)")
            }
            lines.append("Shopping list text:")
            lines.append(text)
            return lines.joined(separator: "\n")
        }
    }
}

