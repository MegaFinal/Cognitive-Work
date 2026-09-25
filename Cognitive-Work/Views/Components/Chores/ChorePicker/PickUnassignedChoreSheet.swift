//
//  PickUnassignedChoreSheet.swift
//  Cognitive-Work
//
//  Created by anshu Li on 25/09/26.
//

import SwiftUI

/// 领取一个还没排好日期的项目、或 weekly 空位（可能带出另一周）时的确认页。
struct PickUnassignedChoreSheet: View {
    let item: CarouselViewModel.UnassignedItem
    @Bindable var carouselViewModel: CarouselViewModel

    @Environment(\.dismiss) private var dismiss

    @State private var slots: [CarouselViewModel.WeeklyPickSlot] = []
    /// 日历当前在编辑第几格（只对 weekly 有意义，其它频率永远是 0）。
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

    private var frequencyLabel: String {
        switch chore.frequency {
        case .daily: "Diária"
        case .weekly: "Semanal"
        case .fortnightly: "Quinzenal"
        case .monthly: "Mensal"
        default: "Sem repetição"
        }
    }

    private var ruleText: String {
        switch chore.frequency {
        case .daily:
            "Você ficará responsável por todos os dias do período."
        case .weekly:
            "Escolha um dia para esta semana. A próxima semana é sugerida automaticamente — você pode mudar a data ou desmarcar."
        case .fortnightly:
            "Escolha um dia dentro do período."
        case .monthly:
            "Escolha um dia. Como você pegou esta tarefa neste ciclo, ela não será atribuída no próximo."
        default:
            "Escolha o dia da tarefa."
        }
    }

    /// 已勾选、已经有日期的格子——这些才会被保存，也是日历上会高亮的日子。
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
                    CapsuleTag(tagName: frequencyLabel, tagColor: roomColor,
                               horizontalPadding: 10, verticalPadding: 1.5)
                }

                if !chore.description.isEmpty {
                    Text(chore.description).font(.system(size: 15)).foregroundStyle(.gray)
                }

                Text(ruleText).font(.system(size: 15)).italic().foregroundStyle(.gray)

                if isWeekly {
                    weeklySlotRows
                }

                CustomCalendar(
                    selectedDate: activeDateBinding,
                    window: window,
                    opacityForDay: { carouselViewModel.loadOpacity(on: $0, in: window) },
                    highlightedDays: includedDates,
                    showsSelectionLabel: !isDaily
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
        .onChange(of: slots.first?.date) { _, newValue in
            // 只有"全新的 weekly 任务"才需要自动补出下周建议；
            // 点已有空位来的那种，下周格在 initialPickSlots 里已经算好了。
            guard isWeekly, item.isOneOffFresh, let newValue else { return }
            suggestNextWeekSlot(from: newValue)
        }
    }

    // MARK: - Weekly rows

    private var weeklySlotRows: some View {
        VStack(spacing: 8) {
            ForEach(slots.indices, id: \.self) { index in
                weeklyRow(index)
            }
        }
    }

    private func weeklyRow(_ index: Int) -> some View {
        guard slots.indices.contains(index) else { return AnyView(EmptyView()) }
        let slot = slots[index]
        let label = index == 0 ? "Esta semana" : "Próxima semana"

        return AnyView(
            HStack {
                Button {
                    guard slot.isDateEditable else { return }
                    activeSlot = index
                } label: {
                    HStack {
                        Text(label).font(.system(size: 15, weight: .semibold))
                        Spacer()
                        Text(slot.date.map {
                            $0.formatted(.dateTime.day().month(.abbreviated).locale(Locale(identifier: "pt_BR")))
                        } ?? "Escolher")
                        .foregroundStyle(.gray)
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(activeSlot == index ? roomColor.opacity(0.25) : Color.gray.opacity(0.08))
                    )
                }
                .buttonStyle(.plain)
                .disabled(!slot.isDateEditable)
            }
        )
    }

    // MARK: - Calendar binding

    /// 日历实际编辑的是 `slots[activeSlot]`。
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

    private func suggestNextWeekSlot(from date: Date) {
        let calendar = Calendar.current
        guard let suggested = calendar.date(byAdding: .day, value: 7, to: date),
              window.contains(suggested) else {
            if slots.count > 1 {
                slots.removeLast()
                if activeSlot >= slots.count { activeSlot = 0 }
            }
            return
        }
        if slots.count > 1 {
            slots[1].date = suggested
        } else {
            slots.append(.init(date: suggested, existingAssignment: nil, isDateEditable: true))
        }
    }

    // MARK: - Header & confirm

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: chore.symbolName)
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
                if success { dismiss() } else { didFail = true }
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
//#Preview {
//    PickUnassignedChoreSheet()
//}
