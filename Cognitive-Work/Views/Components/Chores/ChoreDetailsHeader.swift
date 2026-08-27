//
//  ChoreDetailsHeader.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 26/08/26.
//

import SwiftUI

struct ChoreDetailsHeader: View {
    var viewModel: ChoreViewModel
    var width: CGFloat
    var height: CGFloat
    
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: viewModel.cardSymbol)
                .resizable()
                .scaledToFit()
                .frame(width: width * 0.19, height: height * 0.09)
                .fontWeight(.thin)
            
            Text(viewModel.chore.name)
                .font(.title)
                .fontWeight(.semibold)
            
            HStack(spacing: 12) {
                PriorityDurationTag(
                    text: viewModel.chore.priorityTag.rawValue,
                    color: viewModel.chore.priorityTag.color
                )
                
                PriorityDurationTag(
                    text: viewModel.chore.priorityTag.rawValue,
                    color: viewModel.chore.priorityTag.color
                )
                
                PriorityDurationTag(
                    text: viewModel.chore.frequency.rawValue,
                    color: viewModel.chore.priorityTag.color
                )
            }
        }
        .foregroundColor(.black)
    }
}
