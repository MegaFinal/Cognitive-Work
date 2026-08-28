//
//  ChoreDetailsHeader.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 26/08/26.
//

import SwiftUI

struct ChoreDetailsHeader: View {
    var chore: ChoreModel
    var width: CGFloat
    var height: CGFloat
    
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: chore.symbolName)
                .resizable()
                .scaledToFit()
                .frame(width: width * 0.19, height: height * 0.09)
                .fontWeight(.thin)
            
            Text(chore.name)
                .font(.title)
                .fontWeight(.semibold)
            
            HStack(spacing: 12) {
                PriorityDurationTag(
                    text: chore.priorityTag.rawValue,
                    color: chore.priorityTag.color
                )
                
                PriorityDurationTag(
                    text: chore.priorityTag.rawValue,
                    color: chore.priorityTag.color
                )
                
                PriorityDurationTag(
                    text: chore.frequency.rawValue,
                    color: chore.priorityTag.color
                )
            }
        }
        .foregroundColor(.black)
    }
}
