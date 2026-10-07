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
    
    var isFromSettings: Bool = false
    
    @Environment(\.dismiss) private var dismiss
    
    /// The seven days rendered as rows, each holding its own free-time choice.
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
    
    /// At least one day needs free time before saving.
    private var canSave: Bool {
        weekOrder.contains(where: { $0.freeTime != .none })
    }
    
    // MARK: - Actions
    
    /// Persists the week and advances (onboarding) or goes back (settings).
    private func save() async {
        viewModel.isLoading = true
        defer { viewModel.isLoading = false }
        
        guard await viewModel.setAvailableTimeToUser(daysOfWeekDTO: weekOrder) else { return }
        HapticsManager.notify(.success)
        if isFromSettings {
            dismiss()
        } else {
            viewModel.advanceAfterFreeTime()
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading) {
            OnboardingHeader(
                title: "Quanto tempo você tem para a casa?",
                description: "Arraste em cada dia para definir seu tempo livre para as tarefas da casa",
                containerInset: width * 0.0565
            )
            .padding(.bottom, 20)
            
            VStack {
                HStack(spacing: width * 0.07) {
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
                .padding(.trailing, 12)
                .padding(.top, height * 0.005)
                
                ForEach($weekOrder, id: \.name) { $day in
                    OnboardingCustomSliderComponent(dayOfWeek: $day, width: width, isLoading: $viewModel.isLoading)
                }
            }
            .padding(.horizontal)
            
            Spacer()
            HStack {
                Spacer()
                OnboardingProgressButton(width: width * 0.12, height: width * 0.12, text: "chevron.right", isSystemImage: true, isLoading: viewModel.isLoading, isDisabled: !canSave) {
                    Task {
                        await save()
                    }
                }
            }
        }
        .padding(.horizontal, width * 0.0565)
        .navigationBarBackButtonHidden(!isFromSettings || viewModel.isLoading)
        .onboardingBackButton(viewModel: viewModel, isHidden: isFromSettings)
        .hidesTabBar()
        .alert("Não deu para salvar seus horários", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .task {
            guard isFromSettings else {
                // Restores a choice already made in onboarding (kept until the house exists).
                if let pending = viewModel.freeTimeToRestore {
                    for (index, minutes) in pending.enumerated() where weekOrder.indices.contains(index) {
                        weekOrder[index].freeTime = FreeTimeEnum(minutes: minutes)
                    }
                }
                return
            }
            
            viewModel.isLoading = true
            let saved = await viewModel.fetchCurrentFreeTime()
            for (index, freeTime) in saved where weekOrder.indices.contains(index) {
                weekOrder[index].freeTime = freeTime
            }
            viewModel.isLoading = false
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
    
    /// Width reserved for the day abbreviation.
    private var abbreviationWidth: CGFloat {
        width * Layout.abbreviationWidthRatio
    }
    
    @Binding var isLoading: Bool
    
    // MARK: - Body
    
    var body: some View {
        HStack(spacing: 10) {
            Text(LocalizedStringKey(dayOfWeek.nameAbbreviation))
                .font(.system(size: Layout.abbreviationFontSize))
                .fontWeight(.medium)
                .frame(width: abbreviationWidth, alignment: .leading)
                .padding(.bottom)
            
            VStack(spacing: 8) {
                FreeTimeSlider(rating: $selectedFreeTimeLevel, isLoading: $isLoading)
                
                caption
            }
        }
        .onChange(of: selectedFreeTimeLevel) { _, newValue in
            withAnimation(.easeInOut(duration: 0.1)) {
                dayOfWeek.freeTime = FreeTimeEnum(newValue)
            }
        }
        .onAppear {
            selectedFreeTimeLevel = dayOfWeek.freeTime.level
        }
        .onChange(of: dayOfWeek.freeTime) { _, newValue in
            if selectedFreeTimeLevel != newValue.level {
                selectedFreeTimeLevel = newValue.level
            }
        }
    }
    
    // MARK: - Subviews
    
    /// The caption shown below the slider, combining the full day name with the
    /// label of the currently selected free time.
    private var caption: some View {
        HStack {
            Text(dayOfWeek.freeTime.displayName)
                .font(.system(size: Layout.captionFontSize))
                .fontWeight(.light)
            
            Spacer()
        }
        .foregroundColor(Color(red: 0.45, green: 0.45, blue: 0.45))
    }
}

#Preview {
    @Previewable @State var viewModel = OnboardingViewModel()
    NavigationStack {
        SelectFreeTimeOnboardingView(viewModel: $viewModel, isFromSettings: true)
    }
}
