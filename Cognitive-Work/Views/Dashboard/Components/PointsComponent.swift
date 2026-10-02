//
//  PointsComponent.swift
//  Cognitive-Work
//
//  Created by Isabela Hissa Pinto on 01/10/26.
//

import SwiftUI

struct PointsComponent: View {
    var points: Int
    var subtitle: String = "adquiridos por ter notado\nalgo na casa"
    var piglet: String = "RetroPig"
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .foregroundStyle(Color(.systemGray6).opacity(0.5))
                .frame(width: width * 0.437, height: height * 0.21)
            
            VStack(spacing: 8) {
                Image(piglet)
                    .resizable()
                    .scaledToFit()
                    .frame(width: width * 0.28, height: height * 0.08)
                
                Text("\(points) pontos")
                    .font(.system(size: 20))
                    .fontWeight(.semibold)
                
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(.subTitleGray)
                    .fontWeight(.light)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

#Preview {
    PointsComponent(points: 42)
}
