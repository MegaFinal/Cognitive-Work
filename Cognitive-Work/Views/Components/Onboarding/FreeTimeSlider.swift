//
//  FreeTimeSlider.swift
//  Cognitive-Work
//
//  Created by Jonas Fernando Nascimento Melo on 25/08/26.
//

import SwiftUI

/// A horizontal slider made of discrete squares, used to select how many
/// free-time blocks the user wants to reserve.
///
/// The component draws `maxRating` squares in a row. Squares up to the current
/// `rating` are painted with `activeColor`, while the remaining ones keep
/// `inactiveColor`. The selection is updated while the user taps or drags
/// anywhere over the row.
///
/// Example:
/// ```swift
/// @State private var freeTimeBlocks = 3
/// FreeTimeSlider(rating: $freeTimeBlocks)
/// ```
struct FreeTimeSlider: View {

    // MARK: - Constants

    /// Layout values shared by the component, kept here to avoid magic numbers.
    private enum Layout {
        /// Corner radius applied to every square of the row.
        static let squareCornerRadius: CGFloat = 4

        /// Extra width added to the mask when every square is selected, so the
        /// last square is fully covered instead of being clipped by rounding.
        static let fullSelectionOverflow: CGFloat = 4

        /// Smallest drag distance required to start tracking.
        /// Zero makes a simple tap update the selection.
        static let minimumDragDistance: CGFloat = 0
    }

    // MARK: - Properties

    /// Number of currently selected squares, ranging from `0` to `maxRating`.
    @Binding var rating: Int

    /// Total amount of squares rendered by the slider.
    var maxRating: Int = 6

    /// Width and height of a single square, in points.
    var squareSize: CGFloat = 38

    /// Color applied to the squares inside the current selection.
    var activeColor: Color = .delimiteTimeSelectedSquareComponent

    /// Color applied to the squares outside the current selection.
    var inactiveColor: Color = .delimiteTimeSquareComponent

    /// Horizontal distance between two adjacent squares, in points.
    var spacing: CGFloat = 12

    /// Width required to lay out every square plus the spacing between them.
    private var totalWidth: CGFloat {
        CGFloat(maxRating) * squareSize + spacing * CGFloat(maxRating - 1)
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                buildSquaresRow(color: inactiveColor)

                buildSquaresRow(color: activeColor)
                    .mask(
                        Rectangle()
                            .size(
                                width: getSelectedWidth(in: geometry.size.width),
                                height: geometry.size.height
                            )
                    )
            }
            .gesture(buildSelectionGesture(in: geometry.size.width))
        }
        .frame(maxWidth: totalWidth, maxHeight: squareSize)
    }

    // MARK: - View Builders

    /// Builds a row of `maxRating` squares painted with a single color.
    /// - Parameter color: Fill color applied to every square of the row.
    /// - Returns: The horizontal row of squares.
    private func buildSquaresRow(color: Color) -> some View {
        HStack(spacing: spacing) {
            ForEach(0 ..< maxRating, id: \.self) { _ in
                RoundedRectangle(cornerRadius: Layout.squareCornerRadius)
                    .frame(width: squareSize, height: squareSize)
                    .foregroundColor(color)
            }
        }
    }

    /// Builds the gesture that updates the selection while the user taps or
    /// drags over the row.
    /// - Parameter rowWidth: Rendered width of the squares row, in points.
    /// - Returns: A drag gesture bound to `updateRating(with:in:)`.
    private func buildSelectionGesture(in rowWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: Layout.minimumDragDistance)
            .onChanged { value in
                updateRating(with: value.location.x, in: rowWidth)
            }
    }

    // MARK: - Helpers

    /// Calculates the width of the highlighted area for the current `rating`.
    /// - Parameter rowWidth: Rendered width of the squares row, in points.
    /// - Returns: The mask width, in points.
    private func getSelectedWidth(in rowWidth: CGFloat) -> CGFloat {
        guard rating > 0 else {
            return 0
        }
        guard rating < maxRating else {
            return rowWidth + Layout.fullSelectionOverflow * 3
        }

        return CGFloat(rating) * squareSize + CGFloat(rating - 1) * spacing
    }

    /// Converts a horizontal gesture position into a discrete rating and stores
    /// the clamped result in the `rating` binding.
    /// - Parameters:
    ///   - xPosition: Horizontal position of the gesture, in the row coordinate space.
    ///   - rowWidth: Rendered width of the squares row, in points.
    private func updateRating(with xPosition: CGFloat, in rowWidth: CGFloat) {
        guard rowWidth > 0 else {
            return
        }

        let percentage = xPosition / rowWidth
        let rawRating = percentage * CGFloat(maxRating)
        let calculatedRating = Int(ceil(rawRating))

        rating = max(0, min(maxRating, calculatedRating))
    }
}
