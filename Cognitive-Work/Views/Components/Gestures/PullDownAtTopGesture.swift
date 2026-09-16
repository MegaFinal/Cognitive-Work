//
//  SwipeToCompleteButton.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 15/09/26.
//

import SwiftUI

/// Triggers an action when the user drags downward past a threshold and releases.
///
/// Reads the drag's own translation instead of `ScrollView` geometry, so it works on
/// any view — scrollable or not. Uses `.simultaneousGesture` and a vertical-dominance
/// check so it never steals or gets stolen by a sibling/child gesture (e.g. a card's
/// own horizontal `DragGesture`).
struct PullDownAtTopGesture: ViewModifier {
    
    /// How far (in points) the user must drag down before releasing triggers the action.
    let threshold: CGFloat
    
    /// The action executed when a valid pull-down is released.
    let action: () -> Void
    
    /// Current vertical translation of the in-progress drag (0 while idle or dragging up).
    @State private var translation: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            // Small rubber-band feedback while dragging; purely visual.
            .offset(y: translation * 0.4)
            // `.simultaneousGesture` (not `.gesture`) so this never wins gesture
            // priority away from a child's own `DragGesture` (e.g. card swiping).
            .simultaneousGesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { value in
                        // Only react to drags that are mostly vertical, so a
                        // horizontal card swipe never gets misread as a pull-down.
                        let isMostlyVertical = abs(value.translation.height) > abs(value.translation.width)
                        guard isMostlyVertical else { return }
                        translation = max(0, value.translation.height)
                    }
                    .onEnded { value in
                        let isMostlyVertical = abs(value.translation.height) > abs(value.translation.width)
                        let didPassThreshold = isMostlyVertical && value.translation.height > threshold
                        
                        withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
                            translation = 0
                        }
                        
                        if didPassThreshold {
                            action()
                        }
                    }
            )
    }
}

extension View {
    
    /// Adds a pull-down trigger to any view.
    /// - Parameters:
    ///   - threshold: Minimum downward drag distance, in points, required to trigger the action.
    ///   - action: The closure executed when the pull-down is released past the threshold.
    func onPullDownAtTop(threshold: CGFloat = 70, action: @escaping () -> Void) -> some View {
        modifier(PullDownAtTopGesture(threshold: threshold, action: action))
    }
}
