//
//  OnboardingCustomSliderComponent.swift
//  Cognitive-Work
//
//  Created by Jonas Fernando Nascimento Melo on 25/08/26.
//

import SwiftUI

/// A single onboarding row that lets the user define how much free time is
/// available on a given day of the week.
///
/// The row shows the abbreviated day name on the leading edge, a
/// ``FreeTimeSlider`` on the trailing side and, right below it, the full day
/// name followed by the currently selected free-time label. Every selection
/// change is written back to the `dayOfWeek` binding.
///
/// Example:
/// ```swift
/// @State private var monday = DayOfWeekDTO.monday
/// OnboardingCustomSliderComponent(dayOfWeek: $monday, width: geometry.size.width)
/// ```
struct OnboardingCustomSliderComponent: View {

    // MARK: - Constants

    /// Layout values shared by the component, kept here to avoid magic numbers.
    private enum Layout {
        /// Horizontal spacing between the day abbreviation and the slider,
        /// expressed as a fraction of the available width.
        static let horizontalSpacingRatio: CGFloat = 0.03

        /// Width reserved for the day abbreviation, expressed as a fraction of
        /// the available width.
        static let abbreviationWidthRatio: CGFloat = 0.091

        /// Font size of the abbreviated day name.
        static let abbreviationFontSize: CGFloat = 16

        /// Font size of the caption line shown below the slider.
        static let captionFontSize: CGFloat = 14
    }

    // MARK: - Properties

    /// Day being configured. The selected free time is written back to it.
    @Binding var dayOfWeek: DayOfWeekDTO

    /// Total width available to the component, used to size its children
    /// proportionally.
    let width: CGFloat

    /// Amount of free-time blocks currently selected on the slider.
    @State private var selectedFreeTimeLevel: Int = 0

    /// Horizontal spacing between the day abbreviation and the slider.
    private var horizontalSpacing: CGFloat {
        width * Layout.horizontalSpacingRatio
    }

    /// Width reserved for the day abbreviation.
    private var abbreviationWidth: CGFloat {
        width * Layout.abbreviationWidthRatio
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: horizontalSpacing) {
            Text(dayOfWeek.nameAbbreviation)
                .font(.system(size: Layout.abbreviationFontSize))
                .fontWeight(.medium)
                .frame(width: abbreviationWidth, alignment: .leading)

            VStack {
                FreeTimeSlider(rating: $selectedFreeTimeLevel)

                buildCaption()
            }
        }
        .onChange(of: selectedFreeTimeLevel) {
            updateFreeTime()
        }
    }

    // MARK: - View Builders

    /// Builds the caption shown below the slider, combining the full day name
    /// with the label of the currently selected free time.
    /// - Returns: The caption row.
    private func buildCaption() -> some View {
        HStack {
            Text(dayOfWeek.name)
                .font(.system(size: Layout.captionFontSize))
                .fontWeight(.medium)

            Text(dayOfWeek.freeTime.rawValue)
                .font(.system(size: Layout.captionFontSize))
                .fontWeight(.light)

            Spacer()
        }
        .foregroundStyle(.delimiteTimeTextComponent)
    }

    // MARK: - Helpers

    /// Converts the current slider selection into a ``FreeTimeEnum`` value and
    /// stores it in the `dayOfWeek` binding.
    private func updateFreeTime() {
        dayOfWeek.freeTime = FreeTimeEnum(selectedFreeTimeLevel)
    }
}
