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
    
    /// Task-enacting closure triggered upon a successful gesture validation.
    var action: () -> Void
    var color: Color = .black
    
    @State private var dragOffset: CGFloat = 0
    @State private var isCompleted: Bool = false
    
    private let height: CGFloat = 54
    private let circlePadding: CGFloat = 5
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let circleWidth = height - (circlePadding * 2)
            let maxDrag = width - circleWidth - (circlePadding * 2)
            
            ZStack(alignment: .leading) {
                Capsule()
                    .foregroundColor(color.opacity(0.2))
                
                Text(isCompleted ? "Concluído" : "Deslize para concluir")
                    .foregroundColor(.black)
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .opacity(isCompleted ? 1.0 : Double(1.0 - (dragOffset / (maxDrag * 0.8))))
                
                Circle()
                    .fill(color)
                    .frame(width: circleWidth, height: circleWidth)
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    )
                    .offset(x: dragOffset)
                    .padding(circlePadding)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                guard !isCompleted else { return }
                                
                                let translation = value.translation.width
                                if translation > 0 {
                                    dragOffset = min(translation, maxDrag)
                                }
                            }
                            .onEnded { _ in
                                guard !isCompleted else { return }
                                
                                if dragOffset > maxDrag * 0.70 {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        dragOffset = maxDrag
                                        isCompleted = true
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
            .animation(.easeInOut, value: isCompleted)
        }
        .frame(height: height)
    }
}

#Preview {
    SwipeToCompleteButton {
        print("Tarefa concluída!")
    }
}
