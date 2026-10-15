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
            
            if viewModel.visibleChores.isEmpty {
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
                    // VoiceOver reads the carousel as one adjustable element (see below);
                    // only the opened card's details are exposed as separate elements.
                    .accessibilityHidden(!viewModel.isFocused(index))
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
        // MARK: - VoiceOver
        // Closed: one adjustable element (swipe up/down to change card, double tap to open).
        // Open (or empty): a container exposing the details card / empty state, which traps focus.
        .accessibilityElement(children: exposesChildren ? .contain : .ignore)
        .voiceOverLabel(exposesChildren ? "" : L10n.tr("Tarefas do dia"))
        .voiceOverValue(exposesChildren ? "" : viewModel.accessibilityCarouselValue)
        .voiceOverHint(exposesChildren ? "" : L10n.tr("Deslize para cima ou para baixo para trocar de tarefa. Toque duas vezes para ver os detalhes."))
        .voiceOverTraits(.isModal, when: viewModel.hasFocusedCard)
        // Voice Control: the closed carousel is tappable ("Toque em <tarefa>" opens the centred card).
        .voiceOverTraits(.isButton, when: !(exposesChildren))
        .voiceControlNames(exposesChildren ? [] : viewModel.voiceControlCarouselInputLabels)
        .accessibilityAction {
            guard !viewModel.visibleChores.isEmpty else { return }
            if viewModel.hasFocusedCard {
                viewModel.clearFocus()
            } else {
                viewModel.focusAndFlip(viewModel.activeIndex)
            }
        }
        .accessibilityAdjustableAction { direction in
            guard !viewModel.hasFocusedCard else { return }
            switch direction {
            case .increment: viewModel.accessibilityMoveCarousel(by: 1)
            case .decrement: viewModel.accessibilityMoveCarousel(by: -1)
            @unknown default: break
            }
        }
        // Voice Control has no adjustable gesture: offer the card change as named actions.
        .accessibilityAction(named: Text(L10n.tr("Próxima tarefa"))) {
            guard !viewModel.hasFocusedCard else { return }
            viewModel.accessibilityMoveCarousel(by: 1)
        }
        .accessibilityAction(named: Text(L10n.tr("Tarefa anterior"))) {
            guard !viewModel.hasFocusedCard else { return }
            viewModel.accessibilityMoveCarousel(by: -1)
        }
        .accessibilityAction(named: Text(L10n.tr("Ver como lista"))) {
            onSwipeDown()
        }
        .accessibilityAction(.escape) {
            viewModel.clearFocus()
        }
    }
    
    /// Whether VoiceOver should see the carousel's children (the opened card's details or the
    /// empty state) instead of the single adjustable "carousel" element.
    private var exposesChildren: Bool {
        viewModel.hasFocusedCard || viewModel.visibleChores.isEmpty
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
