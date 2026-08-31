//
//  CreateAndEditChoreHeader.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 28/08/26.
//

import SwiftUI

struct CreateAndEditChoreHeader: View {
    @Bindable var chore: ChoreDTO
    
    var width = UIScreen.main.bounds.width
    var height = UIScreen.main.bounds.height
    
    var body: some View {
        HStack {
            Image(systemName: chore.symbolName)
                .resizable()
                .scaledToFit()
                .frame(width: width * 0.15)
                .fontWeight(.thin)
                .padding(.leading, 8)
            
            Spacer()
            
            VStack(spacing: 25) {
                VStack(spacing: 2) {
                    TextField(
                        "",
                        text: $chore.name,
                        prompt: Text("Nome da Tarefa")
                            .foregroundStyle(.black)
                    )
                    .font(.title)
                    .bold()
                    
                    Capsule()
                        .frame(height: height * 0.0015)
                }
                
                HStack {
                    Text("Cômodo")
                        .bold()
                    
                    Spacer()
                    
                    ChoreTagPicker(chore: chore, type: .room)
                }
            }
            .frame(width: width * 0.65)
        }
    }
}
