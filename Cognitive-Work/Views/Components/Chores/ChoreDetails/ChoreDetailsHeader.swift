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
                CapsuleTag(
                    tagName: chore.priorityTag.rawValue,
                    tagColor: chore.priorityTag.color
                )
                
                CapsuleTag(
                    tagName: chore.priorityTag.rawValue,
                    tagColor: chore.priorityTag.color
                )
                
                CapsuleTag(
                    tagName: chore.frequency.rawValue,
                    tagColor: chore.frequency.color
                )
            }
        }
        .foregroundColor(.black)
    }
}
