//
//  CarouselViewModel.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 18/08/26.
//

import SwiftUI

struct ChoreFilters {
    var users: [UserModel] = []
    var tags: [PriorityTag] = []
    var frequencies: [Recurrence] = []
    var state: Bool? = nil
}

/// Controls the state and mathematical rendering of the carousel.
@Observable
class CarouselViewModel {
    var layoutMode: CardLayoutMode = .grid
    
    var snappedItem:  Double = 0
    var draggingItem: Double = 0
    var activeIndex:  Int    = 0
    
    /// The chores currently loaded into the carousel
    var cardModels: [ChoreModel] = []
    var isLoading: Bool = false
    var hasFocusedCard: Bool {
        focusedIndex != nil
    }
    
    /// Some filter is applied into the chores
    var userModels: [UserModel] = []
    var isFilterOn: Bool = false
    var isSelectingFilter = false
    var filteredChards: [ChoreModel] = []
    var filterChoices = ChoreFilters()
    
    private let flipDuration: Double = 0.6
    private var flippedIndices: Set<Int> = []
    private var backVisibleIndices: Set<Int> = []
    
    /// The card the user has tapped to bring into focus
    private var focusedIndex: Int? = nil
    private let focusSpringResponse: Double = 0.4
    private let focusSpringDamping: Double = 0.75
    
    func toggleLayout() {
        layoutMode = layoutMode == .grid ? .list : .grid
    }
    
    // MARK: - CloudKit Fetch
    
    func fetchChores() async {
        await MainActor.run { isLoading = true }
        
        cardModels = await CloudKitManager.shared.fetchAll(ChoreModel.self)
        
        await MainActor.run { self.isLoading = false }
    }
    
    func fetchUsers() async {
        await MainActor.run { isLoading = true }
        
        userModels = await CloudKitManager.shared.fetchAll(UserModel.self)
        
        await MainActor.run { self.isLoading = false }
    }
    
    // MARK: - Filters
    
    @MainActor
    func filterByUser() async {
        var chores: [ChoreModel] = []
        
        if filterChoices.users != [] {
            for user in filterChoices.users {
                for chore in self.cardModels {
                    if await chore.currentResponsible == user {
                        chores.append(chore)
                    }
                }
            }
        }
        
        if filterChoices.tags != [] {
            for tag in filterChoices.tags {
                chores = chores.filter {$0.priorityTag == tag}
            }
        }
        
        if filterChoices.frequencies != [] {
            for frequency in filterChoices.frequencies {
                chores = chores.filter {$0.frequency == frequency}
            }
        }
        
        if let state = filterChoices.state {
            chores = chores.filter {$0.isDone == state}
        }
        
        self.filteredChards = chores
        self.isFilterOn = true
    }
    
    func addOrRemoveFilter(user: UserModel? = nil, tag: PriorityTag? = nil, frequency: Recurrence? = nil, state: Bool? = nil) async {
        
        if let user = user {
            if !filterChoices.users.contains(user) {
                filterChoices.users.append(user)
            } else {
                filterChoices.users.removeAll {$0 == user}
            }
        }
        
        if let tag = tag {
            if !filterChoices.tags.contains(tag) {
                filterChoices.tags.append(tag)
            } else {
                filterChoices.tags.removeAll {$0 == tag}
            }
        }
        
        if let frequency = frequency {
            if !filterChoices.frequencies.contains(frequency) {
                filterChoices.frequencies.append(frequency)
            } else {
                filterChoices.frequencies.removeAll {$0 == frequency}
            }
        }
        
        if let state = state {
            if filterChoices.state != state {
                filterChoices.state = state
            } else {
                filterChoices.state = nil
            }
        }
        
        await filterByUser()
    }
    
    // MARK: - Focus
    
    /// The only card currently allowed to respond to a flip tap
    func isFocused(_ index: Int) -> Bool {
        focusedIndex == index
    }
    
    func focusImmediately(_ index: Int) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            focusedIndex = index
        }
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
    
    func focusAndFlip(_ index: Int) {
        if let old = focusedIndex, old != index {
            if flippedIndices.contains(old) {
                flip(old)
            }
        }
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            snappedItem = Double(index)
            draggingItem = Double(index)
            activeIndex = index
            focusedIndex = index
        }
        
        flip(index)
    }
    
    func clearFocus() {
        if let old = focusedIndex {
            if flippedIndices.contains(old) {
                flip(old)
            }
            withAnimation(.easeOut(duration: 0.2)) {
                focusedIndex = nil
            }
        }
    }
    
    // MARK: - List Mode Details
    
    /// The chore whose details card should currently be shown, driven by whichever card is
    /// focused — whether that focus came from the carousel or from a list-mode tap.
    var focusedChoreForDetails: ChoreModel? {
        guard let focusedIndex, cardModels.indices.contains(focusedIndex) else { return nil }
        return cardModels[focusedIndex]
    }
    
    /// Shows `index`'s details card right away, without the multi-stage flip animation the
    /// carousel uses. Used when a list-mode card is tapped: the details card should simply grow
    /// into view instead of flipping.
    func focusDetailsImmediately(_ index: Int) {
        flippedIndices.insert(index)
        backVisibleIndices.insert(index)
        
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            focusedIndex = index
        }
    }
    
    /// Closes a details card opened by `focusDetailsImmediately`, clearing the flip state
    /// directly instead of animating a flip back — the details card's own removal transition
    /// handles the "shrink away" instead.
    func clearFocusedDetails() {
        if let index = focusedIndex {
            flippedIndices.remove(index)
            backVisibleIndices.remove(index)
        }
        
        withAnimation(.easeOut(duration: 0.2)) {
            focusedIndex = nil
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
        guard !cardModels.isEmpty else { return 0 }
        return (draggingItem - Double(index)).remainder(dividingBy: Double(cardModels.count))
    }
    
    /// Calculates the horizontal displacement
    func xOffset(_ index: Int) -> Double {
        let fixedVisualCount: Double = 5.0
        let angle = (Double.pi * 2 / fixedVisualCount) * distance(index)
        
        let fixedRadius: Double = 130.0
        
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
        
        return base
    }
    
    /// 2D tilt
    func rotationEffect(_ index: Int) -> Double {
        let dist = distance(index)
        
        let dynamicSideTilt = dist * 22
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
            guard !cardModels.isEmpty else { return }
            
            let velocity = value.predictedEndTranslation.width - value.translation.width
            let nudge = min(max(velocity / 200, -1), 1)
            
            // Snap from where the finger actually left the carousel plus a small velocity nudge for quick flicks
            let count = cardModels.count
            draggingItem = (draggingItem + nudge)
                .rounded()
                .remainder(dividingBy: Double(count))
            snappedItem = draggingItem
            
            let rounded = Int(draggingItem)
            activeIndex = rounded >= 0 ? rounded : count + rounded
        }
    }
}
