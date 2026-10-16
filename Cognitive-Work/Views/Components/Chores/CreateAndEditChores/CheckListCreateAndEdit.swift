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
                    .voiceOverLabel(accessibilityName(of: item))
                    .voiceOverValue(item.isDone ? L10n.tr("Concluído") : L10n.tr("Pendente"))
                    .voiceOverHint(L10n.tr("Toque duas vezes para alternar."))
                    .voiceControlNames([L10n.tr("Marcar %@", accessibilityName(of: item)), L10n.tr("Concluir %@", accessibilityName(of: item))])
                    
                    TextField("Novo item", text: $item.name)
                        .strikethrough(item.isDone, color: .gray)
                        .foregroundColor(item.isDone ? .gray : .black)
                        .font(.system(size: 15))
                        .characterLimit(TextLimits.checklistItem, text: $item.name)
                        .voiceControlNames([accessibilityName(of: item), L10n.tr("Item")])
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
                    .voiceOverLabel(L10n.tr("Remover %@", accessibilityName(of: item)))
                    .voiceControlNames([L10n.tr("Remover"), L10n.tr("Remover %@", accessibilityName(of: item)), L10n.tr("Menos")])
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
            .voiceOverLabel(L10n.tr("Adicionar item"))
            .voiceControlNames([L10n.tr("Adicionar item"), L10n.tr("Adicionar"), L10n.tr("Mais")])
        }
    }
    
    /// The item's text, or "Novo item" while it's still blank.
    private func accessibilityName(of item: CheckItemDTO) -> String {
        let name = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? L10n.tr("Novo item") : name
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
        if let item = localChecklist.first(where: { $0.id == id }) {
            VoiceOver.announce(L10n.tr("%@ removido", accessibilityName(of: item)))
        }
        localChecklist.removeAll { $0.id == id }
        if localChecklist.isEmpty {
            hasChecklist = false
        }
    }
}
