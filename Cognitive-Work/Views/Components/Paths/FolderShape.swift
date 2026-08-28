//
//  FolderShape.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 26/08/26.
//

import SwiftUI

struct FolderShape: Shape {
    var cornerRadius: CGFloat = 28
    
    // Largura da parte mais alta (onde fica o ícone)
    var tabWidth: CGFloat = 110
    
    // O quanto a parte da direita "afunda" em relação ao topo
    var topCutoutHeight: CGFloat = 48

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let w = rect.width
        let h = rect.height
        let r = cornerRadius
        let tabW = tabWidth
        let cutH = topCutoutHeight

        // Desenhamos os pontos das quinas "secas" do nosso polígono
        let topLeft = CGPoint(x: 0, y: 0)
        let topTabRight = CGPoint(x: tabW, y: 0)
        let innerCorner = CGPoint(x: tabW, y: cutH) // A quina invertida
        let topRight = CGPoint(x: w, y: cutH)
        let bottomRight = CGPoint(x: w, y: h)
        let bottomLeft = CGPoint(x: 0, y: h)

        // Começamos o traço um pouco abaixo da primeira quina
        path.move(to: CGPoint(x: 0, y: r))

        // O addArc cria a linha até a quina e arredonda com o radius perfeitamente
        path.addArc(tangent1End: topLeft, tangent2End: topTabRight, radius: r)
        path.addArc(tangent1End: topTabRight, tangent2End: innerCorner, radius: r)
        
        // Essa é a mágica: ele entende que a curva é pra "dentro" automaticamente!
        path.addArc(tangent1End: innerCorner, tangent2End: topRight, radius: r - 8) // Raio um pouco menor na curva interna fica mais elegante
        
        path.addArc(tangent1End: topRight, tangent2End: bottomRight, radius: r)
        path.addArc(tangent1End: bottomRight, tangent2End: bottomLeft, radius: r)
        path.addArc(tangent1End: bottomLeft, tangent2End: topLeft, radius: r)

        path.closeSubpath()

        return path
    }
}
