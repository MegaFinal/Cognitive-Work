//
//  Carousel.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 18/08/26.
//

import SwiftUI

/// Carousel Component with custom swipe, focus and flip gestures and animations
/// `Apply this component on a ZStack bellow the rest of the view's content`
struct Carousel: View {
    @Bindable var viewModel: CarouselViewModel
    var isBackgroundClear: Bool
    let onSwipeDown: () -> Void
    let namespace: Namespace.ID
    
    var body: some View {
        ZStack {
            // Clearing the focus state by tapping the empty space
            if !isBackgroundClear {
                Color.white
                    .onTapGesture {
                        viewModel.clearFocus()
                    }
            }
            
            if viewModel.isLoading {
                ProgressView("Carregando tarefas")
                    .foregroundStyle(.white)
            }
            else if viewModel.cardViewModels.isEmpty {
                Text("Nenhuma tarefa no momento")
                    .font(.headline)
                    .foregroundStyle(.black)
            }
            else {
                // Card loop
                ForEach(Array(viewModel.cardViewModels.enumerated()), id: \.element.id) { index, cardVM in
                    CarouselCardFrame(
                        viewModel: cardVM,
                        carouselViewModel: viewModel,
                        namespace: namespace,
                        isFocused: viewModel.isFocused(index),
                        rotation: viewModel.flipRotation(index),
                        isShowingBack: viewModel.isShowingBack(index)
                    )
                    .scaleEffect(viewModel.scaleEffect(index))
                    .zIndex(viewModel.zIndex(index))
                    .rotationEffect(.degrees(viewModel.rotationEffect(index)))
                    .offset(
                        x: viewModel.xOffset(index),
                        y: viewModel.yOffset(index)
                    )
                    .opacity(viewModel.opacity(index))
                    .onTapGesture {
                        if viewModel.isFocused(index) {
                            viewModel.clearFocus()
                        } else {
                            viewModel.focusAndFlip(index)
                        }
                    }
                }
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            viewModel.onDragChanged(value: value)
                        }
                        .onEnded { value in
                            viewModel.onDragEnded(value: value)
                        }
                )
            }
        }
        .frame(maxWidth: .infinity)
        .onSwipeDown(action: onSwipeDown)
        .matchedGeometryEffect(id: "Spawnpoint", in: namespace)
    }
}

#Preview {
    @Previewable @Namespace var namespace
    let mockVM = CarouselViewModel()
    
    let chore1 = ChoreModel(name: "Lavar Banheiro", description: "Limpar espelhos e chão", frequency: .weekly, duration: 1800, isPublic: true, priorityTag: .urgent)
    
    let chore2 = ChoreModel(name: "Varrer Sala", description: "Limpar espelhos e chão", frequency: .weekly, duration: 1800, isPublic: true, priorityTag: .urgent)
    
    let chore3 = ChoreModel(name: "Lavar a Louça", description: "Secar e guardar também", frequency: .daily, duration: 900, isPublic: true, priorityTag: .low)
    
    let card1 = ChoreViewModel.mock(chore: chore1, roomName: "Banheiro da Suíte", color: .blue)
    card1.cardSymbol = "toilet"
    
    let card2 = ChoreViewModel.mock(chore: chore2, roomName: "Sala", color: .yellow)
    card2.cardSymbol = "sofa"
    
    let card3 = ChoreViewModel.mock(chore: chore3, roomName: "Cozinha", color: .red)
    card3.cardSymbol = "fork.knife"
    
    mockVM.cardViewModels = [card1, card2, card3]
    
    return Carousel(viewModel: mockVM, isBackgroundClear: true, onSwipeDown: {}, namespace: namespace)
}
