//
//  PickUnassignedChoreSheet.swift
//  Cognitive-Work
//
//  Created by anshu Li on 25/09/26.
//

import SwiftUI

/// A card overlay for confirming/selecting dates when claiming an unassigned chore.
struct PickUnassignedChoreCard: View {
    let item: CarouselViewModel.UnassignedItem
    @Bindable var carouselViewModel: CarouselViewModel
    
    @State private var slots: [CarouselViewModel.WeeklyPickSlot] = []
    @State private var activeSlot = 0
    @State private var isSaving = false
    @State private var didFail = false
    
    private var chore: ChoreModel { item.chore }
    private var window: Range<Date> { carouselViewModel.pickerWindow }
    private var isDaily: Bool { chore.frequency == .daily }
    private var isWeekly: Bool { chore.frequency == .weekly }
    
    private var roomName: String {
        carouselViewModel.getRoom(for: chore)?.name.localizedDefault ?? L10n.tr("Sem cômodo")
    }
    
    private var roomColor: Color {
        carouselViewModel.getRoom(for: chore)?.color.uiColor ?? .gray
    }
    
    private var originalDay: Date? {
        if case .recurring(let assignment) = item.choreType { return assignment.day }
        return nil
    }
    
    private var effectiveWindow: Range<Date> {
        let calendar = Calendar.current
        
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
        
        if isDaily { return window }
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
        VStack(spacing: 8) {
            header
                .padding(.bottom)
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 8) {
                    choreDetail
                    
                    calendarText
                    
                    CustomCalendar(
                        selectedDate: activeDateBinding,
                        window: effectiveWindow,
                        opacityForDay: { carouselViewModel.loadOpacity(on: $0, in: window) },
                        highlightedDays: includedDates,
                        earliestSelectable: Calendar.current.startOfDay(for: Date())
                    )
                    .allowsHitTesting(!isDaily)
                    
                    if didFail {
                        Text("Não foi possível salvar. Tente novamente.")
                            .font(.system(size: 13))
                            .foregroundStyle(.red)
                    }
                }
            }
            
            Spacer()
        }
        .padding(16)
        .frame(width: width * 0.88, height: height * 0.62)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 31))
        .shadow(color: .black.opacity(0.2), radius: 25, x: 0, y: 8)
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
    
    // MARK: - Subviews
    
    private var header: some View {
        HStack {
            closeButton
            
            Spacer()
            
            Text("Selecionar dia")
                .font(.system(size: 16))
                .foregroundStyle(.black)
            
            Spacer()
            
            confirmButton
        }
    }
    
    private var choreDetail: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(roomName)
                .font(.system(size: 15))
                .foregroundStyle(.black)
            
            Text(chore.name.localizedDefault)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.black)
            
            HStack(spacing: 16) {
                CapsuleTag(
                    tagName: chore.frequency.displayName,
                    tagColor: chore.frequency.color,
                    textColor: chore.frequency.textColor,
                    horizontalPadding: 6,
                    verticalPadding: 1.5
                )
                
                CapsuleTag(
                    tagName: chore.priorityTag.displayName,
                    tagColor: chore.priorityTag.color,
                    horizontalPadding: 6,
                    verticalPadding: 1.5
                )
                
                let durationTier = ChoreDurationTier.from(minutes: chore.duration)
                CapsuleTag(
                    tagName: durationTier.displayText,
                    tagColor: durationTier.color,
                    horizontalPadding: 6,
                    verticalPadding: 1.5
                )
                
                Spacer()
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .foregroundStyle(Color.gray.opacity(0.08))
        )
    }
    
    private var calendarText: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quando você deseja realizar esta tarefa?")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.black)
            
            Text("Esta escolha será apenas para a divisão de tarefas atual")
                .font(.system(size: 15))
                .foregroundStyle(.gray)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var closeButton: some View {
        Button {
            carouselViewModel.dismissPickCard()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.black)
                .frame(width: 35, height: 35)
                .glassEffect(in: .circle)
        }
        .buttonStyle(.plain)
    }
    
    private var confirmButton: some View {
        Button {
            Task {
                isSaving = true
                didFail = false
                let success = await carouselViewModel.confirmPick(item, slots: slots)
                isSaving = false
                if success {
                    _ = await ScoreManager.shared.assignScoreForMyUser(score: ScoreValues.unassignedChorePicked.points)
                    carouselViewModel.dismissPickCard()
                } else {
                    didFail = true
                }
            }
        } label: {
            Group {
                if isSaving {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .frame(width: 35, height: 35)
            .background(Color.blue)
            .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!canConfirm || isSaving)
        .opacity(canConfirm ? 1.0 : 0.5)
    }
}
