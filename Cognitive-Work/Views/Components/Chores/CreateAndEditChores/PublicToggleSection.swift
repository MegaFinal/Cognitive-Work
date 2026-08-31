//
//  PublicToggleSection.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 30/08/26.
//

import SwiftUI

/// Contains the switch for deciding whether a chore should be public to the household.
struct PublicToggleSection: View {
    
    /// The active data transfer object storing the public state constraint.
    @Bindable var choreDTO: ChoreDTO
    var width: CGFloat
    
    var body: some View {
        VStack {
            HStack {
                Text("Essa tarefa é para a casa?")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Toggle("", isOn: $choreDTO.isPublic)
                    .toggleStyle(.switch)
                    .padding(.trailing, 7)
                    .frame(width: width * 0.37)
            }
            .frame(width: width * 0.9)

            Text("Caso essa tarefa seja para a sua casa ela aparecerá publica para todos os moradores.")
                .font(.subheadline)
                .italic()
                .foregroundColor(.gray)
        }
    }
}
