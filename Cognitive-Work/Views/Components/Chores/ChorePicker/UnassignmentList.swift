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
                
                Spacer()
                
                Image(systemName: "chevron.down")
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
    }
    
    private func choreRow(for item: CarouselViewModel.UnassignedItem) -> some View {
        
        let roomColor = carouselViewModel.getRoom(for: item.chore)?.color.uiColor ?? .gray
        
        return Button {
            onPick(item)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.chore.name)
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
        .glassEffect(
            .regular.tint(roomColor.opacity(0.2)),
            in: .rect(cornerRadius: 16)
        )
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
