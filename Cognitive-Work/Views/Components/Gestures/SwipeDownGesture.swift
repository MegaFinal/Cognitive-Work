//
//  SwipeDownGesture.swift
//  Cognitive-Work
//
//  Created by Carolina Sun on 18/08/26.
//

/// A view modifier that detects intentional downward swipe gestures.
///
/// The gesture requires a minimum vertical displacement and verifies
/// that the movement is predominantly vertical. This prevents
/// horizontal gestures, such as scrolling through a horizontal
/// ``ScrollView``, from being interpreted as a downward swipe.
///
/// When a valid downward swipe is detected, the provided action is
/// executed with a spring animation.
///
import Foundation
import SwiftUI

struct SwipeDownGesture: ViewModifier {
    
    let action: () -> Void /// The action executed when a valid downward swipe is detected.
    
    /// Applies the downward swipe gesture to the modified view.
    /// - Parameter content: The view to which the gesture is applied.
    /// - Returns: A view that responds to intentional downward swipes.
    func body(content: Content) -> some View {
        
        content.simultaneousGesture(
                DragGesture(minimumDistance: 20)
                    .onEnded { value in
                        let vertical = value.translation.height
                        let horizontal = value.translation.width
                        
                        let isSwipeDown = vertical > 70 && vertical > abs(horizontal) * 1.5
                        
                        guard isSwipeDown else {
                            return
                        }
                        
                        withAnimation(.spring(response: 0.55,dampingFraction: 0.78)) {
                            action()
                        }
                    }
            )
    }
}

extension View {
    
    /// Adds a swipe-down gesture that triggers the provided action.
    /// - Parameter action: The closure executed when the downward
    ///   swipe is recognized.
    /// - Returns: A view with the downward swipe gesture applied.
    func onSwipeDown(action: @escaping () -> Void) -> some View {
        modifier(
            SwipeDownGesture(action: action)
        )
    }
}
