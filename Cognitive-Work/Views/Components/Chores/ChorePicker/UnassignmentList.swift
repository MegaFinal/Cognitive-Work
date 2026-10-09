//
//  UnassignmentList.swift
//  Cognitive-Work
//
//  Created by anshu Li on 16/09/26.
//

import SwiftUI

struct UnassignmentList: View {
    let items: [CarouselViewModel.UnassignedItem]
    let onPick: (CarouselViewModel.UnassignedItem) -> Void
    
    @Bindable var carouselViewModel: CarouselViewModel
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Tarefas para pegar")
                    .font(.system(size: 22))
                    .bold()
                    .foregroundStyle(.black)
                    .accessibilityAddTraits(.isHeader)
                
                Spacer()
                
                Image(systemName: "chevron.down")
                    // Visually just a hint; for VoiceOver it closes the popup.
                    .voiceOverLabel(L10n.tr("Fechar"))
                    .accessibilityAddTraits(.isButton)
                    .voiceControlNames([L10n.tr("Fechar"), L10n.tr("Cancelar")])
                    .accessibilityAction {
                        carouselViewModel.dismissUnassignedList()
                    }
            }
            
            if items.isEmpty {
                Text("Nenhuma tarefa disponível no momento.")
                    .font(.system(size: 14))
                    .foregroundStyle(.gray)
                    .padding(.top, 8)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(items) { item in
                            choreRow(for: item)
                        }
                    }
                }
                .frame(maxHeight: 190)
            }
        }
        .padding(15)
        .frame(width: width * 0.7)
        .glassEffect(.regular.tint(.white.opacity(0.35)), in: .rect(cornerRadius: 28))
        .shadow(radius: 28, y: 4)
        // Popup: keeps VoiceOver inside it; the escape gesture closes it.
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape) {
            carouselViewModel.dismissUnassignedList()
        }
    }
    
    private func choreRow(for item: CarouselViewModel.UnassignedItem) -> some View {
        
        let roomColor = carouselViewModel.getRoom(for: item.chore)?.color.uiColor ?? .gray
        
        return Button {
            onPick(item)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.chore.localizedName)
                        .font(.system(size: 15))
                        .foregroundStyle(.black)
                        .fontWeight(.semibold)
                    
                    HStack(spacing: 6) {
                        CapsuleTag(
                            tagName: item.chore.frequency.displayName,
                            tagColor: item.chore.frequency.color,
                            textColor: item.chore.frequency.textColor,
                            horizontalPadding: 6,
                            verticalPadding: 1.5
                        )
                        
                        CapsuleTag(
                            tagName: item.chore.priorityTag.displayName,
                            tagColor: item.chore.priorityTag.color,
                            horizontalPadding: 6,
                            verticalPadding: 1.5
                        )
                    }
                }
                .padding(5)
                
                Spacer()
                
                Image(systemName: "hand.rays")
                    .accessibilityDecorative()
                    .font(.system(size: 15))
                    .padding(7)
                    .foregroundColor(.black)
                    .background(
                        Circle()
                            .foregroundStyle(.white)
                    )
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(ScaleButtonStyle())
        .voiceOverLabel(rowAccessibilityLabel(for: item))
        .voiceControlNames([item.chore.localizedName, L10n.tr("Pegar %@", item.chore.localizedName)])
        .voiceOverHint(L10n.tr("Toque duas vezes para pegar esta tarefa."))
        .glassEffect(
            .regular.tint(roomColor.opacity(0.2)),
            in: .rect(cornerRadius: 16)
        )
    }
    
    /// "Lavar a louça, Cozinha, Prioridade média, …, sexta-feira, 25 de setembro".
    private func rowAccessibilityLabel(for item: CarouselViewModel.UnassignedItem) -> String {
        var parts = [
            item.chore.localizedName,
            carouselViewModel.accessibilityRoomName(for: item.chore),
            carouselViewModel.accessibilityTagsText(for: item.chore)
        ]
        if let date = item.displayDate {
            parts.append(CarouselViewModel.accessibilityDateText(date))
        }
        return parts.joined(separator: ", ")
    }
    
    private struct ScaleButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .scaleEffect(configuration.isPressed ? 0.7 : 1.0)
                .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
        }
    }
}

#Preview {
    UnassignmentList(items: [], onPick: { _ in }, carouselViewModel: CarouselViewModel())
}
