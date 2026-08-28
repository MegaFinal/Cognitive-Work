//
//  CreateAndEditChoreView.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 28/08/26.
//

import SwiftUI

struct CreateAndEditChoreView: View {
    @State var room: RoomModel? = nil
    @State var allResponsibleUsers: [UserModel] = []
    @Bindable var chore: ChoreModel
    
    @State private var choreName: String = ""
    @State private var choreDescription: String = ""
    
    @State private var hasChecklist = false
    @State private var localChecklist: [CheckItemDTO] = []
    
    var width = UIScreen.main.bounds.width
    var height = UIScreen.main.bounds.height
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 40) {
                CreateAndEditChoreHeader(chore: chore)
                
                VStack(spacing: 15) {
                    HStack {
                        Text("Prioridade").bold()
                        Spacer()
                        TagPicker(chore: chore, type: .priority)
                    }
                    
                    HStack {
                        Text("Duração").bold()
                        Spacer()
                        TagPicker(chore: chore, type: .duration)
                    }
                    
                    HStack {
                        Text("Frequência").bold()
                        Spacer()
                        TagPicker(chore: chore, type: .frequency)
                    }
                }
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("Descrição").bold()
                    
                    TextField("Descrição da Tarefa", text: $choreDescription, axis: .vertical)
                }
                
                HStack {
                    Text("Checklist")
                        .bold()
                    
                    Spacer()
                    
                    Toggle("", isOn: $hasChecklist)
                        .toggleStyle(.switch)
                        .onChange(of: hasChecklist) { _, isOn in
                            if isOn && localChecklist.isEmpty {
                                localChecklist.append(CheckItemDTO(name: "", isDone: false))
                            }
                        }
                        .padding(.trailing, 3)
                }
                .frame(width: width * 0.9)
                
                if hasChecklist {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach($localChecklist) { $item in
                            HStack {
                                Button {
                                    item.isDone.toggle()
                                } label: {
                                    Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(item.isDone ? .green : .gray)
                                        .font(.headline)
                                }
                                
                                TextField("Novo item", text: $item.name)
                                    .strikethrough(item.isDone, color: .gray)
                                    .foregroundColor(item.isDone ? .gray : .black)
                                    .font(.footnote)
                                
                                Spacer()
                                
                                Button {
                                    localChecklist.removeAll { $0.id == item.id }
                                    if localChecklist.isEmpty {
                                        hasChecklist = false
                                    }
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                        
                        Button {
                            localChecklist.append(CheckItemDTO(name: "", isDone: false))
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Adicionar item")
                                    .font(.footnote)
                            }
                            .foregroundColor(.blue)
                            .padding(.top, 5)
                        }
                    }
                }
                
                Spacer(minLength: 40)
                
                HStack {
                    Spacer()
                    Button {
                        // TODO: Salvar
                    } label: {
                        Text("Confirmar")
                            .foregroundColor(.white)
                            .fontWeight(.bold)
                            .frame(width: width * 0.8, height: height * 0.06)
                            .background(Color.blue)
                            .clipShape(Capsule())
                    }
                    Spacer()
                }
            }
            .padding(.vertical)
            .frame(width: width * 0.9)
        }
        .task {
            let savedItems = await chore.checkList
            if !savedItems.isEmpty {
                self.localChecklist = savedItems.map { CheckItemDTO(name: $0.name, isDone: $0.isDone) }
                self.hasChecklist = true
            }
        }
    }
}

fileprivate class MockChoreModel: ChoreModel { }

#Preview {
    let mockChore = MockChoreModel(
        name: "Lavar Banheiro",
        description: "Deixar tudo brilhando",
        isDone: false, frequency: .weekly, duration: 1800, isPublic: true, priorityTag: .urgent
    )
    return CreateAndEditChoreView(chore: mockChore)
}
