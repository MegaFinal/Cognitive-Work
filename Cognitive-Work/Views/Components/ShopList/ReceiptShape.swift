//
//  ReceiptShape.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 08/10/26.
//

import SwiftUI

/// A rounded card with a half-circle bite out of each side at `notchY`, like a torn receipt.
struct ReceiptShape: Shape {

    /// How round the card's corners are.
    var cornerRadius: CGFloat = 22
    /// Size of each side bite.
    var notchRadius: CGFloat = 12

    /// Distance from the top edge to the center of the bites.
    var notchY: CGFloat

    /// Lets SwiftUI animate ``notchY``.
    var animatableData: CGFloat {
        get { notchY }
        set { notchY = newValue }
    }

    /// The card's outline with the two bites cut out.
    func path(in rect: CGRect) -> Path {
        let card = Path(roundedRect: rect, cornerRadius: cornerRadius, style: .continuous)

        let y = rect.minY + notchY
        var bites = Path()
        for x in [rect.minX, rect.maxX] {
            bites.addEllipse(in: CGRect(
                x: x - notchRadius,
                y: y - notchRadius,
                width: notchRadius * 2,
                height: notchRadius * 2
            ))
        }

        return card.subtracting(bites)
    }
}
