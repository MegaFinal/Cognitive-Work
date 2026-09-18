//
//  SwipeToCompleteButton.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 26/08/26.
//

import SwiftUI

/// A custom interaction component requiring a continuous horizontal drag gesture to trigger.
///
/// Integrates progressive visual state changes alongside multiple tier haptic feedbacks verifying the intent.
struct SwipeToCompleteButton: View {
    
    var isDone: Bool
    
    /// Task-enacting closure triggered upon a successful gesture validation.
    var action: () -> Void
    var color: Color = .black
    
    @State private var dragOffset: CGFloat = 0
    
    /// Tracks which progress "steps" have already fired a haptic during this drag, so each one only fires once per gesture instead of repeatedly.
    @State private var reachedSteps: Set<Int> = []
    
    private let height: CGFloat = 54
    private let circlePadding: CGFloat = 5
    
    /// Progress fractions at which a light "tick" haptic fires during the drag.
    private let progressSteps: [CGFloat] = [0.15, 0.3, 0.45, 0.5, 0.75]
    private let completionThreshold: CGFloat = 0.70
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let circleWidth = height - (circlePadding * 2)
            let maxDrag = width - circleWidth - (circlePadding * 2)
            let circleOffset = isDone ? maxDrag : dragOffset
            
            ZStack(alignment: .leading) {
                Capsule()
                    .foregroundColor(color.opacity(0.2))
                
                Text(isDone ? "Concluído" : "Deslize para concluir")
                    .foregroundColor(.black)
                    .font(.system(size: 15))
                    .frame(maxWidth: .infinity)
                    .opacity(isDone ? 1.0 : Double(1.0 - (dragOffset / (maxDrag * 0.8))))
                
                Circle()
                    .fill(color)
                    .frame(width: circleWidth, height: circleWidth)
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.system(size: 20))
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    )
                    .offset(x: circleOffset)
                    .padding(circlePadding)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                guard !isDone else { return }
                                
                                let translation = value.translation.width
                                if translation > 0 {
                                    dragOffset = min(translation, maxDrag)
                                }
                                guard maxDrag > 0 else { return }
                                let progress = dragOffset / maxDrag
                                
                                // Haptics leves em marcos intermediários do arraste
                                for (index, step) in progressSteps.enumerated() {
                                    if progress >= step && !reachedSteps.contains(index) {
                                        reachedSteps.insert(index)
                                        let generator = UIImpactFeedbackGenerator(style: .light)
                                        generator.impactOccurred(intensity: 0.6)
                                    }
                                }
                                
                                // Haptic distinto ao cruzar o threshold de conclusão
                                if progress >= completionThreshold && !reachedSteps.contains(999) {
                                    reachedSteps.insert(999)
                                    let generator = UIImpactFeedbackGenerator(style: .heavy)
                                    generator.impactOccurred()
                                }
                            }
                            .onEnded { _ in
                                guard !isDone else { return }
                                
                                if dragOffset > maxDrag * 0.70 {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        dragOffset = maxDrag
                                    }
                                    
                                    let generator = UINotificationFeedbackGenerator()
                                    generator.notificationOccurred(.success)
                                    
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        action()
                                    }
                                } else {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                        dragOffset = 0
                                    }
                                    
                                    let generator = UIImpactFeedbackGenerator(style: .light)
                                    generator.impactOccurred()
                                }
                            }
                    )
            }
            .animation(.easeInOut, value: isDone)
            .onChange(of: isDone) { _, newValue in
                if !newValue {
                    // if it was selected from the outside button, returns the swipe to zero
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        dragOffset = 0
                    }
                }
            }
        }
        .frame(height: height)
    }
}

#Preview {
    SwipeToCompleteButton(isDone: false) {
        print("Tarefa concluída!")
    }
}
