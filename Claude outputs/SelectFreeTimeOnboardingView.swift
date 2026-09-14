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
///
/// ## Onboarding audit — what changed and why
///
/// This screen is the other half of "the admin waits forever for someone who already filled
/// everything in".
///
/// - **It advanced unconditionally.** The button awaited
///   ``OnboardingViewModel/setAvailableTimeToUser(daysOfWeekDTO:)`` and then called
///   `goToNextView()` no matter what happened. When nothing was saved — no public profile
///   resolved, a CloudKit failure, or every capacity silently truncated to zero — the person was
///   moved to the waiting screen convinced they had submitted their availability, while the
///   admin's gate kept them in red with no way to try again. The result is now checked.
/// - **The order of ``weekOrder`` is load-bearing** and is documented as such below:
///   `UserModel.setAvailableTimes(_:forWeeks:)` maps each entry onto a weekday **by its position
///   in the array**, starting from Monday, and discards the `day` value it is handed.
/// - The capacity conversion bug itself (`Int(0.5) * 60 == 0`, which made "Até 30 minutos" mean
///   "no time at all") is fixed in the view model.
struct SelectFreeTimeOnboardingView: View {

    // MARK: - Properties

    /// State shared by every step of the flow.
    @Binding var viewModel: OnboardingViewModel

    /// The seven days rendered as rows, each holding its own free-time choice.
    ///
    /// > Important: **Monday first, and the order matters.**
    /// > ``UserModel/setAvailableTimes(_:forWeeks:)`` derives each slot's weekday from the index
    /// > of the entry in this array (via `Date.weekdayInCurrentWeek(offset:calendar:)`, whose
    /// > calendar is pinned to `firstWeekday = 2`). Reordering these rows silently reassigns
    /// > everyone's availability to the wrong days.
    @State var weekOrder = [
        DayOfWeekDTO(name: "Segunda - Feira", nameAbbreviation: "Seg"),
        DayOfWeekDTO(name: "Terça - Feira", nameAbbreviation:"Ter"),
        DayOfWeekDTO(name: "Quarta - Feira", nameAbbreviation: "Qua"),
        DayOfWeekDTO(name: "Quinta - Feira", nameAbbreviation: "Qui"),
        DayOfWeekDTO(name: "Sexta - Feira", nameAbbreviation:"Sex"),
        DayOfWeekDTO(name: "Sábado ", nameAbbreviation: "Sáb"),
        DayOfWeekDTO(name: "Domingo ",nameAbbreviation: "Dom")
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
                    OnboardingCustomSliderComponent(dayOfWeek: $day, width: width, isLoading: $viewModel.isLoading)
                }

                OnboardingProgressButton(width: 50.0, height: 50.0, text: "chevron.forward", isSystemImage: true, isLoading: viewModel.isLoading,isDisabled: !weekOrder.contains(where: { $0.freeTime != .none })) {
                    // Onboarding fix: advance only when the availability was actually written to
                    // the public profile. `setAvailableTimeToUser(daysOfWeekDTO:)` reports every
                    // failure through `viewModel.errorMessage`, which the alert below surfaces.
                    let didSave = await viewModel.setAvailableTimeToUser(daysOfWeekDTO: weekOrder)

                    guard didSave else { return }

                    viewModel.goToNextView()
                }
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
            .padding(.horizontal, width * 0.0865)
            .navigationBarBackButtonHidden()
        }
        // Onboarding fix: this screen had no error surface at all, so every failure was silent.
        .alert("Não deu para salvar seu tempo livre", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
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

    @Binding var isLoading: Bool

    // MARK: - Body

    var body: some View {
        HStack(spacing: horizontalSpacing) {
            Text(dayOfWeek.nameAbbreviation)
                .font(.system(size: Layout.abbreviationFontSize))
                .fontWeight(.medium)
                .frame(width: abbreviationWidth, alignment: .leading)

            VStack {
                FreeTimeSlider(rating: $selectedFreeTimeLevel, isLoading: $isLoading)

                caption
            }
        }
        .onChange(of: selectedFreeTimeLevel) {
            updateFreeTime()
        }
        .onAppear {
            // Onboarding fix: the slider's local state started at zero even when the model
            // already carried a choice, so a person who went back a step saw their selection
            // reset to "nenhum" while the model still held the old value.
            restoreSelectionFromModel()
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

    /// Restores the slider position from the value already held by the model.
    ///
    /// - Note: **Onboarding fix:** keeps the control and the model in agreement when the view is
    ///   rebuilt (navigating back, or SwiftUI re-creating the row).
    private func restoreSelectionFromModel() {
        guard selectedFreeTimeLevel == 0 else { return }

        let levels: [FreeTimeEnum] = [.none, .thirtyMinutes, .oneHour, .twoHours, .threeHours, .fourHours, .fiveHours]
        if let level = levels.firstIndex(of: dayOfWeek.freeTime) {
            selectedFreeTimeLevel = level
        }
    }
}

#Preview {
    @Previewable @State var viewModel = OnboardingViewModel()
    SelectFreeTimeOnboardingView(viewModel: $viewModel)
}
