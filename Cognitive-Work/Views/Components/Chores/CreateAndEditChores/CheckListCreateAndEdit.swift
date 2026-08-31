//
//  CheckListCreateAndEdit.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 30/08/26.
//

import SwiftUI

struct CheckListCreateAndEdit: View {
    @Binding var hasChecklist: Bool
    @Binding var localChecklist: [CheckItemDTO]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach($localChecklist) { $item in
                HStack {
                    Button {
                        item.isDone.toggle()
                    } label: {
                        Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(item.isDone ? .black : .gray)
                            .font(.headline)
                    }
                    
                    TextField("Novo item", text: $item.name)
                        .strikethrough(item.isDone, color: .gray)
                        .foregroundColor(item.isDone ? .gray : .black)
                        .font(.subheadline)
                    
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
                        .font(.subheadline)
                }
                .foregroundColor(.blue)
                .padding(.top, 5)
            }
        }
    }
}
