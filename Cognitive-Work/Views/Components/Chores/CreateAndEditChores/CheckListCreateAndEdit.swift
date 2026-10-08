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
    
    /// The row whose text field currently has the keyboard.
    @FocusState private var focusedItemID: UUID?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach($localChecklist) { $item in
                HStack {
                    Button {
                        item.isDone.toggle()
                        HapticsManager.selection()
                    } label: {
                        Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(item.isDone ? .black : .gray)
                            .font(.system(size: 17, weight: .semibold))
                    }
                    
                    TextField("Novo item", text: $item.name)
                        .strikethrough(item.isDone, color: .gray)
                        .foregroundColor(item.isDone ? .gray : .black)
                        .font(.system(size: 15))
                        .characterLimit(TextLimits.checklistItem, text: $item.name)
                        .focused($focusedItemID, equals: item.id)
                        .submitLabel(.next)
                        .onSubmit {
                            insertItem(after: item.id)
                        }
                    
                    Spacer()
                    
                    Button {
                        remove(item.id)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(.red)
                    }
                }
            }
            Button {
                appendItem()
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
    
    // MARK: - Actions
    
    /// Creates an empty row right after `id` and focuses it (keyboard return).
    private func insertItem(after id: UUID) {
        guard let index = localChecklist.firstIndex(where: { $0.id == id }) else { return }
        
        // Return on a blank row ends the list instead of creating another blank row.
        guard !localChecklist[index].name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            focusedItemID = nil
            return
        }
        
        let newItem = CheckItemDTO(name: "", isDone: false)
        localChecklist.insert(newItem, at: index + 1)
        focusedItemID = newItem.id
    }
    
    /// "Adicionar item": reuses a trailing blank row if there is one, otherwise appends.
    private func appendItem() {
        if let last = localChecklist.last,
           last.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            focusedItemID = last.id
            return
        }
        let newItem = CheckItemDTO(name: "", isDone: false)
        localChecklist.append(newItem)
        focusedItemID = newItem.id
    }
    
    private func remove(_ id: UUID) {
        localChecklist.removeAll { $0.id == id }
        if localChecklist.isEmpty {
            hasChecklist = false
        }
    }
}
