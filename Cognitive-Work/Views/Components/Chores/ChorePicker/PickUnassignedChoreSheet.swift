//
//  PickUnassignedChoreSheet.swift
//  Cognitive-Work
//
//  Created by anshu Li on 25/09/26.
//

import SwiftUI

/// Confirmation sheet when claiming an unassigned chore with no date, or a weekly empty slot.
struct PickUnassignedChoreSheet: View {
    let item: CarouselViewModel.UnassignedItem
    @Bindable var carouselViewModel: CarouselViewModel
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var slots: [CarouselViewModel.WeeklyPickSlot] = []
    @State private var activeSlot = 0
    @State private var isSaving = false
    @State private var didFail = false
    
    private var chore: ChoreModel { item.chore }
    private var window: Range<Date> { carouselViewModel.pickerWindow }
    private var isDaily: Bool { chore.frequency == .daily }
    private var isWeekly: Bool { chore.frequency == .weekly }
    private var roomColor: Color {
        carouselViewModel.getRoom(for: chore)?.color.uiColor ?? .gray
    }
    
    /// The day of the assignment the user tapped (nil for undated one-offs).
    private var originalDay: Date? {
        if case .recurring(let assignment) = item.choreType { return assignment.day }
        return nil
    }

    private var effectiveWindow: Range<Date> {
        let calendar = Calendar.current

        // weekly: only the 7 days of the assignment's week
        if isWeekly {
            let base = originalDay
                ?? slots.first(where: { $0.date != nil })?.date
                ?? window.lowerBound
            let startOfWeek = calendar.date(
                from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: base)
            ) ?? base
            if let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfWeek) {
                return startOfWeek..<endOfWeek
            }
        }

        // daily: keep today, end of cycle
        if isDaily { return window }

        // fortnightly / monthly / one-off: the two weeks the engine generated
        return carouselViewModel.cycleWindow ?? window
    }
    
    private var ruleText: LocalizedStringKey {
        switch chore.frequency {
        case .daily:
            "Você ficará responsável por todos os dias do período."
        case .weekly:
            "Escolha a data desta tarefa dentro da semana. Dias que já passaram não podem ser escolhidos."
        case .fortnightly:
            "Escolha um dia dentro do período. Dias que já passaram não podem ser escolhidos."
        case .monthly:
            "Escolha um dia. Como você pegou esta tarefa neste ciclo, ela não será atribuída no próximo."
        default:
            "Escolha o dia da tarefa."
        }
    }
    
    private var includedDates: [Date] {
        slots.compactMap { $0.included ? $0.date : nil }
    }
    
    private var canConfirm: Bool { !includedDates.isEmpty }
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                header
                
                HStack {
                    Text("Frequência").font(.system(size: 15, weight: .semibold))
                    Spacer()
                    CapsuleTag(tagName: chore.frequency.displayName, tagColor: chore.frequency.color,
                               textColor: chore.frequency.textColor,
                               horizontalPadding: 10, verticalPadding: 1.5)
                }
                
                if !chore.description.isEmpty {
                    Text(chore.description).font(.system(size: 15)).foregroundStyle(.gray)
                }
                
                Text(ruleText).font(.system(size: 15)).italic().foregroundStyle(.gray)
                
                CustomCalendar(
                    selectedDate: activeDateBinding,
                    window: effectiveWindow,
                    opacityForDay: { carouselViewModel.loadOpacity(on: $0, in: window) },
                    highlightedDays: includedDates,
                    showsSelectionLabel: !isDaily,
                    earliestSelectable: Calendar.current.startOfDay(for: Date())
                )
                .allowsHitTesting(!isDaily)
                
                if didFail {
                    Text("Não foi possível salvar. Tente novamente.")
                        .font(.system(size: 14))
                        .foregroundStyle(.red)
                }
                
                confirmButton
            }
            .padding()
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .task {
            slots = carouselViewModel.initialPickSlots(for: item)
            activeSlot = slots.firstIndex { $0.isDateEditable } ?? 0
        }
    }
    
    // MARK: - Calendar binding
    
    private var activeDateBinding: Binding<Date?> {
        Binding(
            get: { slots.indices.contains(activeSlot) ? slots[activeSlot].date : nil },
            set: { newValue in
                guard slots.indices.contains(activeSlot) else { return }
                slots[activeSlot].date = newValue
                slots[activeSlot].included = newValue != nil
            }
        )
    }
    
    // MARK: - Header & confirm
    
    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: carouselViewModel.getRoom(for: chore)?.symbol ?? chore.symbolName)
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 44)
                .fontWeight(.thin)
            
            Text(chore.name)
                .font(.system(size: 28, weight: .bold))
                .lineLimit(2)
            
            Spacer()
            
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.gray)
            }
        }
    }
    
    private var confirmButton: some View {
        Button {
            Task {
                isSaving = true
                didFail = false
                let success = await carouselViewModel.confirmPick(item, slots: slots)
                isSaving = false
                if success {
                    async let scoredSuccessfully = ScoreManager.shared.assignScoreForMyUser(score: ScoreValues.unassignedChorePicked.points)
                    dismiss()
                }
                else {
                    didFail = true
                }
            }
        } label: {
            Group {
                if isSaving {
                    ProgressView().tint(.white)
                } else {
                    Text("Confirmar")
                        .foregroundColor(.white)
                        .fontWeight(.bold)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(Color.blue)
            .clipShape(Capsule())
        }
        .disabled(!canConfirm || isSaving)
        .opacity(canConfirm ? 1 : 0.4)
    }
}
