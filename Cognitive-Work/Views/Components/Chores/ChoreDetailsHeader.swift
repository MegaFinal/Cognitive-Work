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
        VStack(spacing: 13) {
            Text(viewModel.chore.name)
                .font(.title2)
            
            Image(systemName: viewModel.cardSymbol)
                .resizable()
                .scaledToFit()
                .frame(width: width * 0.2, height: height * 0.1)
                .fontWeight(.ultraLight)
            
            HStack {
                PriorityDurationTag(
                    text: viewModel.chore.priorityTag.rawValue,
                    color: viewModel.chore.priorityTag.color
                )
                
                PriorityDurationTag(
                    text: viewModel.chore.priorityTag.rawValue,
                    color: viewModel.chore.priorityTag.color
                )
            }
        }
    }
}
