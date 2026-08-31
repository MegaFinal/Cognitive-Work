//
//  PublicToggleSection.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 30/08/26.
//

import SwiftUI

struct PublicToggleSection: View {
    @Bindable var choreDTO: ChoreDTO
    let width: CGFloat
    
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
