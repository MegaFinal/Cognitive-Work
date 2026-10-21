//
//  ChoreTagsRow.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 16/10/26.
//

import SwiftUI

/// The chore's frequency, priority and duration tags, always in this order.
struct ChoreTagsRow: View {
    let chore: ChoreModel
    var spacing: CGFloat = 8
    var horizontalPadding: Double = 7
    var verticalPadding: Double = 1.5

    private var durationTier: ChoreDurationTier {
        ChoreDurationTier.from(minutes: chore.duration)
    }

    var body: some View {
        HStack(spacing: spacing) {
            CapsuleTag(
                tagName: chore.frequency.displayName,
                tagColor: chore.frequency.color,
                textColor: chore.frequency.textColor,
                horizontalPadding: horizontalPadding,
                verticalPadding: verticalPadding
            )

            CapsuleTag(
                tagName: chore.priorityTag.displayName,
                tagColor: chore.priorityTag.color,
                horizontalPadding: horizontalPadding,
                verticalPadding: verticalPadding
            )

            CapsuleTag(
                tagName: durationTier.displayText,
                tagColor: durationTier.color,
                horizontalPadding: horizontalPadding,
                verticalPadding: verticalPadding
            )
        }
    }
}
