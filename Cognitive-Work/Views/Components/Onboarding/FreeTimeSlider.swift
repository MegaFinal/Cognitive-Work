//
//  FreeTimeSlider.swift
//  Cognitive-Work
//
//  Created by Jonas Fernando Nascimento Melo on 25/08/26.
//

import SwiftUI

struct FreeTimeSlider: View {
    @Binding var rating: Int
    var maxRating: Int = 6
    var squareSize: CGFloat = 38
    var activeColor: Color = .delimiteTimeSelectedSquareComponent
    var inactiveColor: Color = .delimiteTimeSquareComponent
    var spacing: CGFloat = 12
    
    var body: some View {
        GeometryReader { geometry in
            
            ZStack(alignment: .leading) {
                RectangleView(color: inactiveColor)
                
                RectangleView(color: activeColor)
                    .mask(
                        Rectangle()
                            .size(
                                width: rating < 6 ?
                                geometry.size.width * CGFloat(Double(rating) / Double(maxRating)) :
                                    geometry.size.width + 4.0,
                                height: geometry.size.height
                            )
                    )
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        updateRating(with: value.location.x, in: geometry.size.width)
                    }
            )
        }
        .frame(maxWidth: CGFloat(maxRating) * squareSize + spacing * CGFloat(maxRating - 1),maxHeight: squareSize)
    }
    
    private func RectangleView(color: Color) -> some View {
        HStack(spacing: spacing) {
            ForEach(0..<maxRating, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 4)
                    .frame(width: squareSize, height: squareSize)
                    .foregroundColor(color)
            }
        }
    }
    
    private func updateRating(with xPosition: CGFloat, in totalWidth: CGFloat) {
        let percentage = xPosition / totalWidth
        let rawRating = percentage * Double(maxRating)
        
        let calculatedRating = Int(ceil(rawRating))
        
        rating = max(0, min(maxRating, calculatedRating))
        print(rating)
    }
}
