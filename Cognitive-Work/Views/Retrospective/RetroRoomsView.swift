//
//  RetroRoomsView.swift
//  Cognitive-Work
//
//  Created by Jonas Fernando Nascimento Melo on 29/09/26.
//

import SwiftUI

@Observable
class RetroChartItemDTO: Identifiable {
    let identifier: UUID = UUID()
    var roomName: String = ""
    var numOfChores: Int = 0
    var roomColor: Color = .gray
    
    init(roomName: String, numOfChores: Int, roomColor: Color) {
        self.roomName = roomName
        self.numOfChores = numOfChores
        self.roomColor = roomColor
    }
}

struct RetroRoomsView: View {
    @Binding var isExpanded: Bool
    @Binding var isRetroDone: Bool
    /// True while this page is the one being shown. The bars grow every time it becomes true.
    var isActive: Bool = true
    
    @State private var isChartShown = false
    
    @State var chartItems: [RetroChartItemDTO] = [
        RetroChartItemDTO(roomName: "Cozinha", numOfChores: 8, roomColor: .choreBlue),
        RetroChartItemDTO(roomName: "Sala", numOfChores: 5, roomColor: .choreGreen),
        RetroChartItemDTO(roomName: "Banheiro", numOfChores: 6, roomColor: .choreOrange),
        RetroChartItemDTO(roomName: "Quarto", numOfChores: 4, roomColor: .chorePurple),
        RetroChartItemDTO(roomName: "Lavanderia", numOfChores: 3, roomColor: .choreYellow),

        RetroChartItemDTO(roomName: "Área externa", numOfChores: 2, roomColor: .choreBlue)
    ]
    
    var maxNumOfChores: Int {
        chartItems.map(\.numOfChores).max() ?? 0
    }
    
    /// Rooms with fewer chores than this get the same width as a room with this many,
    /// so the "X tarefas" text always fits inside the bar.
    private let minimumChoresForWidth = 2
    
    /// Final width of the bar: proportional to the number of chores of the room, never narrower than the minimum.
    private func barWidth(for item: RetroChartItemDTO) -> CGFloat {
        let chores = max(item.numOfChores, minimumChoresForWidth)
        let maxChores = max(maxNumOfChores, minimumChoresForWidth)
        return (width * 0.877) * CGFloat(chores) / CGFloat(maxChores)
    }
    
    var body: some View {
        VStack {
            Text("6 cômodos")
                .bold()
                .font(.system(size: 64))
                .padding(.top, height * 0.071)
            
            Text("A cozinha foi onde você mais trabalhou.")
                .font(.title)
                .multilineTextAlignment(.center)
                .padding(.bottom, height * 0.02)
            
            // Only the chart scrolls (when there are many rooms); title and button stay fixed.
            ScrollView(.vertical, showsIndicators: false) {
                HStack {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(chartItems.enumerated()), id: \.element.id) { index, item in
                            Text("\(item.roomName)")
                                .font(.body)
                                .fontWeight(.semibold)
                                .padding(.bottom, 0.01)
                        
                            Capsule()
                                .frame(width: isChartShown ? barWidth(for: item) : 0, height: height * 0.041)
                                .foregroundStyle(item.roomColor)
                                .overlay(alignment: .leading) {
                                    Text("\(item.numOfChores) tarefas")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.white)
                                        .padding(.horizontal)
                                        .fixedSize()
                                        .opacity(isChartShown ? 1 : 0)
                                        .animation(.easeIn(duration: 0.3).delay(0.5 + Double(index) * 0.12), value: isChartShown)
                                }
                                // Taller bars take longer, so every bar grows at the same speed.
                                .animation(
                                    .easeOut(duration: 0.5 + 0.7 * Double(item.numOfChores) / Double(max(maxNumOfChores, 1)))
                                        .delay(Double(index) * 0.12),
                                    value: isChartShown
                                )
                                .padding(.bottom, 0.02)
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, width * 0.061)
                .padding(.bottom, height * 0.02)
            }
            .scrollBounceBehavior(.basedOnSize)
            
            Spacer()

            Button {
                withAnimation {
                    isRetroDone = true
                    isExpanded = false
                }
            } label: {
                Text("Concluir")
                    .frame(width: width * 0.69, height: height * 0.037)
                    .fontWeight(.medium)
                    .font(.system(size: 17))
            }
            .buttonStyle(.glassProminent)
            .glassEffectTransition(.identity)
        }
        .task(id: isActive) {
            if isActive {
                try? await Task.sleep(for: .seconds(0.3))
                isChartShown = true
            } else {
                // Reset without animating, so the bars grow again next time the page appears.
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) { isChartShown = false }
            }
        }
    }
}


#Preview {
    @Previewable @State var isExpanded = true
    @Previewable @State var isRetroDone = false
    RetroRoomsView(isExpanded: $isExpanded, isRetroDone: $isRetroDone)
}
