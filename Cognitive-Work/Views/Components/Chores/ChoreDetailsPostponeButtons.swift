//
//  ChoreDetailsPostponeButtons.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 26/08/26.
//

import SwiftUI

struct ChoreDetailsPostponeButtons: View {
    var viewModel: ChoreViewModel
    var width: CGFloat
    
    var body: some View {
        HStack {
            Button {
                Task {
                    await viewModel.postpone(byDays: 7)
                }
            } label: {
                Text("Adiar 1 semana")
                    .font(.caption)
                    .foregroundColor(.black)
            }
            .padding(.horizontal, 35)
            .padding(.vertical, 10)
            .background(.gray.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 22))
            
            Spacer()
            
            Button {
                Task {
                    await viewModel.postpone(byDays: 1)
                }
            } label: {
                Text("Adiar 1 dia")
                    .font(.caption)
                    .foregroundColor(.black)
            }
            .padding(.horizontal, 35)
            .padding(.vertical, 10)
            .background(.gray.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 22))
        }
        .frame(width: width * 0.73)
    }
}
