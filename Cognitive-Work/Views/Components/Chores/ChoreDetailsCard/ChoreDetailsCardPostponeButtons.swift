//
//  ChoreDetailsCardPostponeButtons.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 26/08/26.
//

import SwiftUI

struct ChoreDetailsCardPostponeButtons: View {
    var chore: ChoreModel
    var width: CGFloat
    
    var body: some View {
        HStack {
            Button {
                Task {
                    await chore.postpone(byDays: 7)
                }
            } label: {
                Text("Adiar 1 semana")
                    .font(.footnote)
                    .foregroundColor(.black)
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 10)
            .background(.gray.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 22))
            
            Spacer()
            
            Button {
                Task {
                    await chore.postpone(byDays: 1)
                }
            } label: {
                Text("Adiar 1 dia")
                    .font(.footnote)
                    .foregroundColor(.black)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 10)
            .background(.gray.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 22))
        }
        .padding(.top, 10)
        .frame(width: width * 0.72)
    }
}
