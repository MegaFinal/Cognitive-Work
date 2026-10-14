//
//  ChoresViewButtonsSection.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 31/08/26.
//

import SwiftUI

/// Defines the overlay layout region containing core chore action buttons
struct ChoresViewButtonsSection: View {
    
    @State private var showCreateView = false
    
    @Bindable var carouselViewModel: CarouselViewModel

    /// The house members offered in the new-chore form.
    private var houseUsers: [UserModel] {
        carouselViewModel.userModels
    }
    
    var body: some View {
        HStack {
            Spacer()
            
            Button {
                carouselViewModel.toggleUnassignedList()
            } label: {
                Image(systemName: "hand.tap")
                    .font(.system(size: 32))
                    .padding(17)
                    .foregroundColor(.black)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .voiceOverLabel(L10n.tr("Tarefas para pegar"))
            .voiceControlNames([L10n.tr("Tarefas para pegar"), L10n.tr("Pegar tarefa"), L10n.tr("Tarefas sem responsável")])
            .voiceOverHint(L10n.tr("Mostra as tarefas sem responsável."))
            .voiceOverValue(carouselViewModel.isShowingUnassignedList ? L10n.tr("expandido") : L10n.tr("recolhido"))
            .glassEffect(
                .regular.interactive(),
                in: .circle
            )
            
            
            Button {
                showCreateView = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 28))
                    .foregroundColor(.white)
                    .padding(20)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .voiceOverLabel(L10n.tr("Nova tarefa"))
            .voiceControlNames([L10n.tr("Adicionar"), L10n.tr("Mais"), L10n.tr("Nova tarefa"), L10n.tr("Adicionar tarefa")])
            .glassEffect(
                .regular.interactive().tint(.black),
                in: .circle
            )
        }
        .padding(.horizontal, 30)
        .padding(.bottom)
        .navigationDestination(isPresented: $showCreateView) {
            CreateAndEditChoreView(
                originalModel: ChoreModel(
                    name: "",
                    description: "",
                    isDone: false,
                    frequency: .undefined,
                    duration: 0,
                    isPublic: true,
                    priorityTag: .undefined
                ),
                availableHouseUsers: houseUsers, carouselViewModel: carouselViewModel
            )
        }
    }
}

#Preview {
    NavigationStack {
        ChoresViewButtonsSection(carouselViewModel: CarouselViewModel())
    }
}
