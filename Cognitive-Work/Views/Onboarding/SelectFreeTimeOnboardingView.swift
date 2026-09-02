//
//  OnboardingDelimiteTime.swift
//  Cognitive-Work
//
//  Created by Jonas Fernando Nascimento Melo on 20/08/26.
//

import SwiftUI

/// Onboarding step where the user sets how much free time they have on each
/// day of the week.
///
/// Each row is an ``OnboardingCustomSliderComponent``; the selection is written
/// to the user record before advancing.
struct SelectFreeTimeOnboardingView: View {

    // MARK: - Properties

    /// State shared by every step of the flow.
    @Binding var viewModel: OnboardingViewModel

    /// The seven days rendered as rows, each holding its own free-time choice.
    @State var weekOrder = [
        DayOfWeekDTO(name: "Segunda - Feira", nameAbbreviation: "Seg"),
        DayOfWeekDTO(name: "Terça - Feira", nameAbbreviation:"Ter"),
        DayOfWeekDTO(name: "Quarta - Feira", nameAbbreviation: "Qua"),
        DayOfWeekDTO(name: "Quinta - Feira", nameAbbreviation: "Qui"),
        DayOfWeekDTO(name: "Sexta - Feira", nameAbbreviation:"Sex"),
        DayOfWeekDTO(name: "Sabado -", nameAbbreviation: "Sab"),
        DayOfWeekDTO(name: "Domingo -",nameAbbreviation: "Dom")
    ]
    @State var showAllert: Bool = false

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            
            VStack(alignment: .leading) {
                Text("Delimite seu tempo")
                    .bold()
                    .font(.system(size: 32))
                    .foregroundStyle(.titleGray)
                    .padding(.top, height * 0.034)
                    .padding(.bottom, 10)
                
                Text("Defina seu tempo disponível para realizar tarefas domésticas durante a semana")
                    .bold()
                    .font(.system(size: 16))
                    .foregroundStyle(.subTitleGray)
                
                HStack(spacing: width * 0.073) {
                    Spacer()
                    Text("30’")
                    Text("1h")
                    Text("2h")
                    Text("3h")
                    Text("4h")
                    Text("5h")
                }
                .font(.system(size: 16))
                .fontWeight(.medium)
                .padding(.trailing, 10)
                .padding(.top, height * 0.023)
                
                ForEach($weekOrder, id: \.name) { $day in
                    OnboardingCustomSliderComponent(dayOfWeek: $day, width: width)
                }
                
                OnboardingProgressButton(width: 50.0, height: 50.0, text: "chevron.forward", isSystemImage: true, isDisabled: !weekOrder.contains(where: { $0.freeTime != .none })) {
                    await viewModel.setAvailableTimeToUser(daysOfWeekDTO: weekOrder)
                    viewModel.goToNextView()
                }
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
            .padding(.horizontal, width * 0.0865)
            .navigationBarBackButtonHidden()
        }
    }
}

// MARK: - Private subviews

/// A single onboarding row that lets the user define how much free time is
/// available on a given day of the week.
///
/// The row shows the abbreviated day name on the leading edge, a
/// ``FreeTimeSlider`` on the trailing side and, right below it, the full day
/// name followed by the currently selected free-time label. Every selection
/// change is written back to the `dayOfWeek` binding.
private struct OnboardingCustomSliderComponent: View {

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

                caption
            }
        }
        .onChange(of: selectedFreeTimeLevel) {
            updateFreeTime()
        }
    }

    // MARK: - Subviews

    /// The caption shown below the slider, combining the full day name with the
    /// label of the currently selected free time.
    private var caption: some View {
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

#Preview {
    @Previewable @State var viewModel = OnboardingViewModel()
    SelectFreeTimeOnboardingView(viewModel: $viewModel)
}
