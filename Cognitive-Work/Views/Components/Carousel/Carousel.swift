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
            else if viewModel.cardModels.isEmpty {
                Text("Nenhuma tarefa no momento")
                    .font(.headline)
                    .foregroundStyle(.black)
            }
            else {
                // Card loop
                ForEach(Array(viewModel.cardModels.enumerated()), id: \.element.id) { index, chore in
                    CarouselCardFrame(
                        chore: chore,
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
    
    Carousel(viewModel: mockVM, isBackgroundClear: true, onSwipeDown: {}, namespace: namespace)
}
