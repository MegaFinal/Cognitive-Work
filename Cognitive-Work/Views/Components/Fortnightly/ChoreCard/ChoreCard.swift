//
//  ChoreCard.swift
//  Cognitive-Work
//
//  Created by anshu Li on 25/08/26.
//

import SwiftUI

struct ChoreCard: View {
    var width = UIScreen.main.bounds.width
    var height = UIScreen.main.bounds.height
    
    var text: String
    var symbol: String
    
    var body: some View {
        VStack{
            ChoreCardTitle()
            
            HStack{
                Image(systemName: symbol)
                    .resizable()
                    .scaledToFit()
                    .frame(width: width * 0.25, height: height * 0.2)
            }
            
        }
    }
}

#Preview {
    ChoreCard(text: " ", symbol: "toilet")
}
