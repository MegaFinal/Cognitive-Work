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
        .padding(12)
        .frame(width: 260)
        .glassEffect(.regular.tint(.white.opacity(0.35)), in: .rect(cornerRadius: 28))
        .shadow(radius: 28, y: 4)
    }
    
    private func choreRow(for item: CarouselViewModel.UnassignedItem) -> some View {
        
        let roomColor = carouselViewModel.getRoom(for: item.chore)?.color.uiColor ?? .gray
        
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.chore.name)
                    .font(.system(size: 16))
                
                if let date = item.displayDate {
                    Text(date.formatted(date: .numeric, time: .omitted))
                        .font(.system(size: 11))
                        .foregroundStyle(.gray)
                }
            }
            .padding(5)
            
            Spacer()
            
            Button {
                onPick(item)
            } label: {
                Image(systemName: "hand.rays")
                    .font(.system(size: 15))
                    .padding(7)
                    .foregroundColor(.black)
                    .contentShape(Circle())
                    .background(
                        Circle()
                            .foregroundStyle(.white)
                    )
                    .shadow(color: roomColor, radius: 8)
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .foregroundStyle(roomColor.opacity(0.5))
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
