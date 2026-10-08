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
                // Was `.foregroundStyle(.white)` over the white chores screen: the label was
                // invisible, so the carousel looked empty while loading.
                ProgressView("Carregando tarefas")
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            else if viewModel.visibleChores.isEmpty {
                ChoresEmptyState(kind: .today)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
            }
            else {
                ForEach(Array(viewModel.visibleChores.enumerated())
                    .filter { abs(viewModel.distance($0.offset)) < 2.5 }, id: \.element.id) { index, chore in
                    CarouselCardFrame(
                        chore: chore,
                        recurrentAssignment: viewModel.getAssignmentsForActiveContext(for: chore).first,
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
        .onPullDownAtTop(action: onSwipeDown)
        .matchedGeometryEffect(id: "Spawnpoint", in: namespace)
    }
}

#Preview("Carousel") {
    @Previewable @Namespace var namespace
    let mockVM = CarouselViewModel()
    
    let chore1 = ChoreModel(
        name: "Lavar o Banheiro",
        description: "Esfregar o chão do box e limpar os espelhos.",
        isDone: false,
        frequency: .weekly,
        duration: 1800,
        isPublic: true,
        priorityTag: .urgent
    )
    chore1.symbolName = "toilet"
    
    let chore2 = ChoreModel(
        name: "Varrer a Sala",
        description: "Afastar os móveis e passar pano úmido.",
        isDone: false,
        frequency: .weekly,
        duration: 1200,
        isPublic: true,
        priorityTag: .urgent
    )
    chore2.symbolName = "sofa"
    
    let chore3 = ChoreModel(
        name: "Lavar o Banheiro",
        description: "Esfregar o chão do box e limpar os espelhos.",
        isDone: false,
        frequency: .weekly,
        duration: 1800,
        isPublic: true,
        priorityTag: .urgent
    )
    chore3.symbolName = "toilet"
    
    mockVM.cardModels = [chore1, chore2, chore3]
    
    return Carousel(
        viewModel: mockVM,
        isBackgroundClear: true,
        onSwipeDown: {},
        namespace: namespace
    )
}
