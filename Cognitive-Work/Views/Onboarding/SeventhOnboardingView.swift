//
//  seventh.swift
//  Cognitive-Work
//
//  Created by Jonas Fernando Nascimento Melo on 25/08/26.
//

import SwiftUI

@Observable
class ChoreDTO {
    let name: String
    let description: String
    let frequency: Recurrence
    let duration: Double
    let priorityTag: PriorityTag
    var isSelected: Bool = false
    
    init(name: String, description: String, frequency: Recurrence, duration: Double, priorityTag: PriorityTag){
        self.name = name
        self.description = description
        self.frequency = frequency
        self.duration = duration
        self.priorityTag = priorityTag
    }
}

struct SeventhOnboardingView: View {
    @State var showChores = false
    @State var rooms: [RoomDTO] = [
        RoomDTO(name: "Sala", symbol: ""),
        RoomDTO(name: "Banheiro", symbol: ""),
        RoomDTO(name: "Cozinha", symbol: ""),
        RoomDTO(name: "Área de serviço", symbol: "")
    ]
    @State var mockedChores: [ChoreDTO] = [
        ChoreDTO(name: "tarefa1", description: "descrição 1", frequency: .daily, duration: 10, priorityTag: .high),
        ChoreDTO(name: "tarefa2", description: "descrição 2", frequency: .daily, duration: 10, priorityTag: .high),
        ChoreDTO(name: "tarefa3", description: "descrição 3", frequency: .daily, duration: 10, priorityTag: .high),
    ]
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            
            VStack(alignment: .leading) {
                Text("Selecione as tarefas")
                    .bold()
                    .font(.system(size: 32))
                    .foregroundStyle(.titleGray)
                    .padding(.top, height * 0.034)
                    .padding(.bottom, 10)
                
                Text("Escolha **apenas** as tarefas que serão divididas de maneira igual entre todos os moradores")
                    .font(.system(size: 16))
                    .foregroundStyle(.subTitleGray)
                    .padding(.bottom, height * 0.025)
                
                ForEach($rooms) { $room in
                    HStack {
                        Text(room.name)
                            .font(.system(size: 24))
                            .bold()
                            .padding(.bottom, height * 0.018)
                        
                        Spacer()
                        
                        Button {
                            room.isExpanded.toggle()
                        } label: {
                            room.isExpanded == false ? Image(systemName: "chevron.down") : Image(systemName: "chevron.up")
                        }
                        .fontWeight(.semibold)
                        .foregroundStyle(.black)
                        
                    }
                    Divider()
                        .frame(height: height * 0.001)
                        .overlay(Color.black)
                    if room.isExpanded {
                        ForEach($mockedChores, id: \.name) { $chore in
                            Toggle(chore.name, isOn: $chore.isSelected)
                        }
                    }
                }
                Spacer()
                
                HStack {
                    Spacer()
                    Button {
                        // TODO ação: avançar e salvar
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 56, height: 56)
                            .background(Color.accentColor, in: Circle())
                            .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                    }
                    
                }
                .padding(.bottom, height * 0.07)
            }
            .padding(.horizontal, width * 0.086)
        }
    }
}

#Preview {
    SeventhOnboardingView()
}
