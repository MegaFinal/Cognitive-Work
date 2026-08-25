//
//  CarouselViewModel.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 18/08/26.
//

import SwiftUI

/// Controls the state and mathematical rendering of the carousel.
@Observable
class CarouselViewModel {
    var snappedItem:  Double = 0
    var draggingItem: Double = 0
    var activeIndex:  Int    = 0
    
    /// The chores currently loaded into the carousel
    var cardViewModels: [ChoreViewModel] = []
    var isLoading: Bool = false
    
    private let flipDuration: Double = 0.6
    private var flippedIndices: Set<Int> = []
    private var backVisibleIndices: Set<Int> = []
    
    /// The card the user has tapped to bring into focus
    private var focusedIndex: Int? = nil
    private let focusSpringResponse: Double = 0.4
    private let focusSpringDamping: Double = 0.75
    
    // MARK: - CloudKit Fetch
    
    func fetchChores() async {
        await MainActor.run { isLoading = true }
        
        let fetchedChores = await CloudKitManager.shared.fetchAll(ChoreModel.self)
        
        await MainActor.run {
            self.cardViewModels = fetchedChores.map { ChoreViewModel(chore: $0) }
            self.isLoading = false
        }
    }
    
    // MARK: - Focus
    
    /// The only card currently allowed to respond to a flip tap
    func isFocused(_ index: Int) -> Bool {
        focusedIndex == index
    }
    
    func focus(_ index: Int) {
        guard focusedIndex != index else { return }
        
        if focusedIndex != nil {
            withAnimation(.easeOut(duration: 0.15)) {
                focusedIndex = nil
            }
        }
        
        withAnimation(.spring(response: focusSpringResponse, dampingFraction: focusSpringDamping)) {
            snappedItem = Double(index)
            draggingItem = Double(index)
            activeIndex = index
        }
        
        // Wait for the focus state before activating the flip
        DispatchQueue.main.asyncAfter(deadline: .now() + focusSpringResponse) { [weak self] in
            guard let self, self.activeIndex == index else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                self.focusedIndex = index
            }
        }
    }
    
    func clearFocus() {
        if focusedIndex != nil {
            withAnimation(.easeOut(duration: 0.15)) {
                focusedIndex = nil
            }
        }
    }
    
    // MARK: - Flip
    
    /// Horizontal flip rotation for the card at `index`: 0° at
    /// rest, 180° once flipped.
    func flipRotation(_ index: Int) -> Double {
        flippedIndices.contains(index) ? 180 : 0
    }
    
    /// Whether the card at `index` should currently render its
    /// back face rather than its front face.
    func isShowingBack(_ index: Int) -> Bool {
        backVisibleIndices.contains(index)
    }
    
    /// Flips the card at `index` a half-turn (180°), animated,
    /// toggling between its front and its back face each tap.
    func flip(_ index: Int) {
        let isFlipping = !flippedIndices.contains(index)
        
        withAnimation(.easeInOut(duration: flipDuration)) {
            if isFlipping {
                flippedIndices.insert(index)
            } else {
                flippedIndices.remove(index)
            }
        }
        
        // Swap the visible face at the midpoint of the rotation
        DispatchQueue.main.asyncAfter(deadline: .now() + flipDuration / 2) { [weak self] in
            guard let self else { return }
            if isFlipping {
                self.backVisibleIndices.insert(index)
            } else {
                self.backVisibleIndices.remove(index)
            }
        }
    }
    
    // MARK: - Carousel Geometry Math
    
    /// Whether the card at `index` is the one currently centered
    func isCentered(_ index: Int) -> Bool {
        abs(distance(index)) < 0.5
    }
    
    /// Determines how far away an item is from the current focal point of the carousel
    func distance(_ index: Int) -> Double {
        guard !cardViewModels.isEmpty else { return 0 }
        return (draggingItem - Double(index)).remainder(dividingBy: Double(cardViewModels.count))
    }
    
    /// Calculates the horizontal displacement
    func xOffset(_ index: Int) -> Double {
        let fixedVisualCount: Double = 5.0
        let angle = (Double.pi * 2 / fixedVisualCount) * distance(index)
        
        let fixedRadius: Double = 160.0
        
        return sin(angle) * fixedRadius
    }
    
    /// Creates a vertical dip at the edges
    func yOffset(_ index: Int) -> Double {
        let dist = abs(distance(index))
        let hideThreshold = hideThreshold()
        if dist > hideThreshold { return 1000 }
        
        return pow(dist * 17, 2) / 10
    }
    
    /// Scales cards down as they move away from center; scales the
    /// focused card up
    func scaleEffect(_ index: Int) -> Double {
        let dist = abs(distance(index))
        let base = max(1 - dist * 0.18, 0.7)
        return isFocused(index) ? base * 1.12 : base
    }
    
    /// 2D tilt
    func rotationEffect(_ index: Int) -> Double {
        let dist = distance(index)
        
        let dynamicSideTilt = dist * 15
        return dynamicSideTilt
    }
    
    /// Ensures the center card is always rendered on top.
    func zIndex(_ index: Int) -> Double {
        1.0 - abs(distance(index)) * 0.1
    }
    
    /// Hides cards that have rotated around to the "back".
    func opacity(_ index: Int) -> Double {
        let dist = abs(distance(index))
        return dist > hideThreshold() ? 0.0 : 1.0
    }
    
    private func hideThreshold() -> Double {
        return 1.5
    }
    
    // MARK: - Gesture
    
    private static var dragPointsPerGroup: Double { UIScreen.main.bounds.width * 0.25 }
    
    func onDragChanged(value: DragGesture.Value) {
        clearFocus()
        draggingItem = snappedItem + value.translation.width / Self.dragPointsPerGroup
    }
    
    func onDragEnded(value: DragGesture.Value) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            guard !cardViewModels.isEmpty else { return }
            
            let velocity = value.predictedEndTranslation.width - value.translation.width
            let nudge = min(max(velocity / 200, -1), 1)
            
            // Snap from where the finger actually left the carousel plus a small velocity nudge for quick flicks
            let count = cardViewModels.count
            draggingItem = (draggingItem + nudge)
                .rounded()
                .remainder(dividingBy: Double(count))
            snappedItem = draggingItem
            
            let rounded = Int(draggingItem)
            activeIndex = rounded >= 0 ? rounded : count + rounded
        }
    }
}
