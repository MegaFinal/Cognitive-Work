//
//  CarouselCardFrame.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 18/08/26.
//

import SwiftUI
import CloudKit

/// `Frame` ensures all images fit the card's ratio
/// /// - `Parameters:`
///   - `frontFace:` View that represents the front face of the card
///   - `quantity:` View that represents the back of the card
struct CarouselCardFrame: View {
    let chore: ChoreModel
    /// The specific occurrence this card represents, when it comes from the list
    /// layout. `nil` in the grid, where cards stand for the chore as a whole.
    var recurrentAssignment: RecurrentAssignmentModel?
    
    let carouselViewModel: CarouselViewModel
    let namespace: Namespace.ID
    
    
    var isFocused: Bool = false
    var rotation: Double = 0
    var isShowingBack: Bool = false
    private let fadeDuration: Double = 0.03
    
    var body: some View {
        ZStack {
            ChoreCarouselCard(chore: chore, namespace: namespace, carouselViewModel: carouselViewModel)
                .opacity(isShowingBack ? 0 : 1)
                .scaleEffect(
                    x: isFocused ? (0.88 / 0.72) : 1.0,
                    y: isFocused ? (0.65 / 0.47) : 1.0
                )

            if isShowingBack || rotation != 0 {
                ChoreDetailsCard(
                    chore: chore,
                    recurrentAssignment: recurrentAssignment,
                    carouselViewModel: carouselViewModel,
                    isShowingBack: isShowingBack
                )
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                .opacity(isShowingBack ? 1 : 0)
                .frame(width: 0, height: 0)
                .scaleEffect(
                    x: isFocused ? 1.0 : (0.72 / 0.88),
                    y: isFocused ? 1.0 : (0.47 / 0.65)
                )
                .transition(.identity)
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.75), value: isFocused)
        .animation(.easeInOut(duration: fadeDuration), value: isShowingBack)
        .rotation3DEffect(.degrees(rotation), axis: (x: 0, y: 1, z: 0), perspective: 0.4)
    }
}
