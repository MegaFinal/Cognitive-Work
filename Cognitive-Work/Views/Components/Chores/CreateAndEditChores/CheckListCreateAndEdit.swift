//
//  CheckListCreateAndEdit.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 30/08/26.
//

import SwiftUI

/// An interactive list allowing users to add, edit, or remove sub-items within a chore's checklist.
struct CheckListCreateAndEdit: View {
    
    /// Binding dictating whether the checklist feature is currently active for this chore.
    @Binding var hasChecklist: Bool
    
    /// A draft array of `CheckItemDTO` items backing the visual list.
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
                            .font(.system(size: 17, weight: .semibold))
                    }
                    
                    TextField("Novo item", text: $item.name)
                        .strikethrough(item.isDone, color: .gray)
                        .foregroundColor(item.isDone ? .gray : .black)
                        .font(.system(size: 15))
                    
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
                        .font(.system(size: 15))
                }
                .foregroundColor(.blue)
                .padding(.top, 5)
            }
        }
    }
}
