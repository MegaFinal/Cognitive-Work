//
//  Keyhole.swift
//  Cognitive-Work
//
//  Created by Jonas Fernando Nascimento Melo on 29/09/26.
//

import SwiftUI

struct Keyhole: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height

        let center = CGPoint(x: rect.minX + w * 0.5013, y: rect.minY + h * 0.2562)
        let radius = w * 0.4734

        var path = Path()
        path.move(to: CGPoint(x: rect.minX + w * 0.2944, y: rect.minY + h * 0.4876)) // junção esquerda
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))                        // base esquerda
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))                        // base direita
        path.addLine(to: CGPoint(x: rect.minX + w * 0.7132, y: rect.minY + h * 0.4876)) // junção direita
        path.addArc(center: center,
                    radius: radius,
                    startAngle: .degrees(63.6),
                    endAngle: .degrees(115.8),
                    clockwise: true)
        path.closeSubpath()
        return path
    }
}


#Preview {
    Keyhole()
        .frame(width: 200, height: 300)
        .foregroundStyle(.purple)
}
