//
//  SwipeToCompleteButton.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 15/09/26.
//

import SwiftUI

/// Triggers an action when the user pulls a vertical `ScrollView` down past its top edge
/// and releases it (pull-to-refresh style).
///
/// Unlike ``SwipeDownGesture``, this never fires while the user is simply scrolling the
/// content back up: it only reacts to the rubber-band overscroll that happens when the list
/// is already at the top.
struct PullDownAtTopGesture: ViewModifier {
    
    /// How far (in points) the content must be pulled beyond the top before releasing.
    let threshold: CGFloat
    
    /// The action executed when a valid pull-down is released.
    let action: () -> Void
    
    /// Current distance pulled beyond the top edge (negative while overscrolling).
    @State private var topOverscroll: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            // Track the offset relative to the top edge: 0 at rest, negative when pulled down.
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top
            } action: { _, newValue in
                topOverscroll = newValue
            }
            // Decide only when the finger is lifted, so the gesture never competes with scrolling.
            .onScrollPhaseChange { oldPhase, newPhase in
                guard oldPhase == .interacting,
                      newPhase != .interacting,
                      topOverscroll < -threshold
                else { return }
                
                withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
                    action()
                }
            }
    }
}

extension View {
    
    /// Adds a pull-down-at-top trigger to a vertical `ScrollView`.
    /// - Parameters:
    ///   - threshold: Minimum overscroll, in points, required to trigger the action.
    ///   - action: The closure executed when the pull-down is released.
    func onPullDownAtTop(threshold: CGFloat = 70, action: @escaping () -> Void) -> some View {
        modifier(PullDownAtTopGesture(threshold: threshold, action: action))
    }
}
