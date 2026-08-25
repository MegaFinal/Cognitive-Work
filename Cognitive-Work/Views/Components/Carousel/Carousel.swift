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
    
    var body: some View {
        ZStack {
            // Clear background that occupies the whole screen to allow
            // clearing the focus state by tapping the empty space
            Color.white
                .onTapGesture {
                    viewModel.clearFocus()
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
                            viewModel.flip(index)
                        } else {
                            viewModel.focus(index)
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            await viewModel.fetchChores()
        }
    }
}

#Preview {
    let carouselVM = CarouselViewModel()
    
    let mock1 = ChoreModel(name: "Lavar Banheiro", description: "", frequency: .weekly, duration: 1800, isPublic: true, priorityTag: .urgent)
    let mock2 = ChoreModel(name: "Varrer Chão", description: "", frequency: .daily, duration: 900, isPublic: true, priorityTag: .low)
    let mock3 = ChoreModel(name: "Arrumar Cama", description: "", frequency: .monthly, duration: 300, isPublic: true, priorityTag: .low)
    let mock4 = ChoreModel(name: "Lavar Louça", description: "", frequency: .daily, duration: 400, isPublic: true, priorityTag: .urgent)
    
    carouselVM.cardViewModels = [
        CarouselCardViewModel.mock(chore: mock1, roomName: "Banheiro", color: .blue, imageName: "person.circle"),
        CarouselCardViewModel.mock(chore: mock2, roomName: "Sala", color: .red, imageName: "person.circle"),
        CarouselCardViewModel.mock(chore: mock3, roomName: "Quarto", color: .blue, imageName: "person.circle"),
        CarouselCardViewModel.mock(chore: mock4, roomName: "Cozinha", color: .red, imageName: "person.circle")
    ]
    
    return Carousel(viewModel: carouselVM)
}
