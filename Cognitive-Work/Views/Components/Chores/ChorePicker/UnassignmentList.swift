//
//  UnassignmentList.swift
//  Cognitive-Work
//
//  Created by anshu Li on 16/09/26.
//

import SwiftUI

/// The pop-up list of chores nobody is responsible for, opened by the "hand" button on the chores
/// screen. Tapping a row picks the chore.
struct UnassignmentList: View {
    /// The chores (or occurrences) without anyone responsible.
    let items: [CarouselViewModel.UnassignedItem]
    /// Runs when the user picks a chore.
    let onPick: (CarouselViewModel.UnassignedItem) -> Void
    
    /// The chores screen's view model.
    @Bindable var carouselViewModel: CarouselViewModel
    
    var body: some View {
        VStack(alignment: .leading) {
            // MARK: - Header: title and close hint
            HStack {
                Text("Tarefas para pegar")
                    .font(.system(size: 18))
                    .bold()
                    .foregroundStyle(.black)
                    .accessibilityAddTraits(.isHeader)
                
                Spacer()
                
                Image(systemName: "chevron.down")
                    // Visually just a hint; for VoiceOver it closes the popup.
                    .voiceOverLabel(L10n.tr("Fechar"))
                    .accessibilityAddTraits(.isButton)
                    .voiceControlNames([L10n.tr("Fechar"), L10n.tr("Cancelar")])
                    .accessibilityAction {
                        carouselViewModel.dismissUnassignedList()
                    }
            }
            
            // MARK: - Empty message or the scrolling list of chores
            if items.isEmpty {
                Text("Nenhuma tarefa disponível no momento.")
                    .font(.system(size: 14))
                    .foregroundStyle(.gray)
                    .padding(.top, 8)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 8) {
                        ForEach(items) { item in
                            UnassignedChoreRow(item: item, carouselViewModel: carouselViewModel, onPick: onPick)
                        }
                    }
                }
                .frame(maxHeight: 190)
            }
        }
        .padding(20)
        .frame(width: width * 0.7)
        .glassEffect(.regular.tint(.white.opacity(0.35)), in: .rect(cornerRadius: 28))
        .shadow(radius: 28, y: 4)
        // Popup: keeps VoiceOver inside it; the escape gesture closes it.
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape) {
            carouselViewModel.dismissUnassignedList()
        }
    }
}

#Preview {
    UnassignmentList(items: [], onPick: { _ in }, carouselViewModel: CarouselViewModel())
}
