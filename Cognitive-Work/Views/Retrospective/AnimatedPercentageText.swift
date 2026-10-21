//
//  AnimatedPercentageText.swift
//  Cognitive-Work
//
//  Created by Jonas Fernando Nascimento Melo on 29/09/26.
//

import SwiftUI

/// Text that shows a percentage and interpolates its value frame by frame,
/// so it follows the exact same animation (duration and curve) as any other animated value.
struct AnimatedPercentageText: View, Animatable {
    var value: Double

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        Text("\(Int(value.rounded()))%")
            .monospacedDigit()
    }
}

#Preview {
    @Previewable @State var value = 0.0
    AnimatedPercentageText(value: value)
        .font(.system(size: 64).bold())
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6)) { value = 100 }
        }
}
