//
//  RetroAlert.swift
//  Cognitive-Work
//
//  Created by Jonas Fernando Nascimento Melo on 29/09/26.
//

import SwiftUI

struct RetroView: View {
    @State var isExpanded: Bool = false
    @State var isRetroDone: Bool = false
    @State var page = 0
    /// Closes the presenting fullScreenCover; used by VoiceOver's escape gesture.
    @Environment(\.dismiss) private var dismissRetro
    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { }
                .accessibilityDecorative()
            
            RoundedRectangle(cornerRadius: 32)
                .frame(width: isExpanded ? .infinity : width * 0.87, height: isExpanded ? .infinity : height * 0.59)
                .foregroundStyle(.white)
                .ignoresSafeArea()
                .overlay {
                    if !isExpanded && !isRetroDone{
                        RetroAlert(isExpanded: $isExpanded, isRetroDone: $isRetroDone)
                    }
                    else if isExpanded && !isRetroDone {
                        VStack(spacing: 12){
                            TabView(selection: $page) {
                                RetroPercentageOfDoneView(page: $page, isRetroDone: $isRetroDone)
                                    .tag(0)
                                RetroStreakView(page: $page, isRetroDone: $isRetroDone)
                                    .tag(1)
                                RetroPointsView(page: $page, isRetroDone: $isRetroDone)
                                    .tag(2)
                                RetroRoomsView(isExpanded: $isExpanded, isRetroDone: $isRetroDone)
                                    .tag(3)
                            }
                            .tabViewStyle(.page(indexDisplayMode: .never))
                            
                            PageIndicator(count: 4, current: $page)
                        }
                    }
                    else if !isExpanded && isRetroDone{
                        RetroNewChoresDivision()
                    }
                }
        }
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape) { dismissRetro() }
        // Each step swaps the whole content: let VoiceOver re-read it from the top.
        .onChange(of: isExpanded) { VoiceOver.screenChanged() }
        .onChange(of: isRetroDone) { VoiceOver.screenChanged() }
        .onChange(of: page) { VoiceOver.screenChanged() }
    }
}

struct PageIndicator: View {
    let count: Int
    @Binding var current: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i == current ? Color.primary : Color.secondary.opacity(0.3))
                    .frame(width: 8, height: 8)
                    .onTapGesture { current = i }
            }
        }
        .animation(.spring(duration: 0.3), value: current)
        // One adjustable element: swipe up/down to change page.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.tr("Página"))
        .accessibilityValue(L10n.tr("%lld de %lld", current + 1, count))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                if current < count - 1 { current += 1 }
            case .decrement:
                if current > 0 { current -= 1 }
            @unknown default:
                break
            }
        }
    }
}

private struct RetroAlert: View {
    @Binding var isExpanded: Bool
    @Binding var isRetroDone: Bool
    
    var body: some View {
        VStack {
            Image(systemName: "chart.bar.xaxis")
                .resizable()
                .frame(width: width * 0.27, height: height * 0.089)
                .foregroundStyle(.choreYellow)
                .padding(.bottom, height * 0.05)
                .accessibilityDecorative()
            
            Text("Sua retrospectiva chegou!")
                .bold()
                .font(.largeTitle)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
                .padding(.bottom, height * 0.018)
            
            Text("Veja como você se saiu durante os últimos 15 dias")
                .font(.title2)
                .multilineTextAlignment(.center)
                .fontWeight(.regular)
                .padding(.bottom, height * 0.037)
            
                Button {
                    withAnimation {
                        isExpanded.toggle()
                    }
                } label: {
                    Text("Ver minha retrospectiva")
                        .frame(width: width * 0.69, height: height * 0.037)
                        .fontWeight(.medium)
                        .font(.system(size: 17))
                }
                .buttonStyle(.glassProminent)
                .glassEffectTransition(.identity)

                Button {
                    // Skips the retrospective pages and goes straight to the new division screen.
                    withAnimation {
                        isRetroDone = true
                    }
                } label: {
                    Text("Pular para a nova divisão")
                        .frame(width: width * 0.69, height: height * 0.037)
                        .fontWeight(.medium)
                        .font(.system(size: 17))
                }
                .buttonStyle(.glass)
        
        }
    }
}



private struct RetroPercentageOfDoneView: View {
    @Binding var page: Int
    @Binding var isRetroDone: Bool
    @State var percentage: Double = 0.0

    var body: some View {
        ZStack {
            VStack {
                Spacer ()
                
                Text("\(String(format: "%.0f", percentage))%")
                    .bold()
                    .font(.system(size: 64))
                    .padding(.bottom, height * 0.03)
                    .accessibilityLabel(L10n.tr("%@ das tarefas concluídas", ChartA11y.percent(percentage / 100)))
                    .accessibilityAddTraits(.isHeader)
                
                Text("Você realizou 0 de 20 \n tarefas da sua escala")
                    .font(.title)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, height * 0.008)
                
                Text("Vamos tentar de novo na próxima")
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.subTitleGray) //Arrumar depois a cor
                
                Spacer()
                
                Text("você consegue!")
                    .bold()
                    .font(.system(size: 40))
                    .padding(.bottom, height * 0.018)
                
                Button {
                    withAnimation {
                        isRetroDone = true
                    }
                } label: {
                    Text("ver depois")
                        .fontWeight(.semibold)
                        .font(.subheadline)
                        .foregroundStyle(.subTitleGray) //Arrumar depois a cor
                }
                .padding(.bottom, height * 0.014)
                
                Button {
                    withAnimation {
                        page += 1
                    }
                } label: {
                    Text("Continuar")
                        .frame(width: width * 0.69, height: height * 0.037)
                        .fontWeight(.medium)
                        .font(.system(size: 17))
                }
                .buttonStyle(.glassProminent)
                .glassEffectTransition(.identity)
            }
        }
    }
}

private struct RetroStreakView: View {
    @Binding var page: Int
    @Binding var isRetroDone: Bool
    
    var body: some View {
        VStack {
            
            Spacer()
            
            Image(systemName: "flame.fill")
                .resizable()
                .frame(width: width * 0.54, height: height * 0.3)
                .foregroundStyle(.gray)
                .padding(.bottom, height * 0.037)
                .accessibilityDecorative()
            
            Text("0 dias")
                .bold()
                .font(.system(size: 64))
                .padding(.bottom, height * 0.014)
                .accessibilityAddTraits(.isHeader)
            
            Text("seguidos sem atrasar nenhuma tarefa")
                .fontWeight(.regular)
                .font(.title)
                .multilineTextAlignment(.center)
                .padding(.bottom, height * 0.014)
            
            Text("Dá para começar ainda hoje!")
                .font(.callout)
                .foregroundStyle(.gray) //arrumar o cinza depois
                .padding(.bottom, height * 0.093)

            
            Button {
                withAnimation {
                    isRetroDone = true
                }
            } label: {
                Text("ver depois")
                    .fontWeight(.semibold)
                    .font(.subheadline)
                    .foregroundStyle(.gray) //arrumar o cinza depois
            }
            
            
            Button {
                withAnimation {
                    page += 1
                }
            } label: {
                Text("Continuar")
                    .frame(width: width * 0.69, height: height * 0.037)
                    .fontWeight(.medium)
                    .font(.system(size: 17))
            }
            .buttonStyle(.glassProminent)
            .glassEffectTransition(.identity)
        }
    }
}

private struct RetroPointsView: View {
    @Binding var page: Int
    @Binding var isRetroDone: Bool
    
    var body: some View {
        VStack {
            
            Spacer()
            
            Image("RetroPig")
                .resizable()
                .frame(width: width * 0.6, height: width * 0.6)
                .foregroundStyle(.gray)
                .padding(.bottom, height * 0.037)
                .accessibilityDecorative()
            
            Text("4 pontos")
                .bold()
                .font(.system(size: 64))
                .padding(.bottom, height * 0.014)
                .accessibilityAddTraits(.isHeader)
            
            Text("adquiridos por ter notado algo na casa")
                .fontWeight(.regular)
                .font(.title)
                .multilineTextAlignment(.center)
                .padding(.bottom, height * 0.014)
            
            Text("Cada coisa que você reparou conta!")
                .font(.callout)
                .foregroundStyle(.gray) //arrumar o cinza depois
                .padding(.bottom, height * 0.093)

            
            Button {
                withAnimation {
                    isRetroDone = true
                }
            } label: {
                Text("ver depois")
                    .fontWeight(.semibold)
                    .font(.subheadline)
                    .foregroundStyle(.gray) //arrumar o cinza depois
            }
            
            
            Button {
                withAnimation {
                    page += 1
                }
            } label: {
                Text("Continuar")
                    .frame(width: width * 0.69, height: height * 0.037)
                    .fontWeight(.medium)
                    .font(.system(size: 17))
            }
            .buttonStyle(.glassProminent)
            .glassEffectTransition(.identity)
        }
    }
}

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
    
    @State var chartItens: [RetroChartItemDTO] = [
        RetroChartItemDTO(roomName: "Cozinha", numOfChores: 8, roomColor: .choreBlue),
        RetroChartItemDTO(roomName: "Sala", numOfChores: 5, roomColor: .choreGreen),
        RetroChartItemDTO(roomName: "Banheiro", numOfChores: 6, roomColor: .choreOrange),
        RetroChartItemDTO(roomName: "Quarto", numOfChores: 4, roomColor: .chorePurple),
        RetroChartItemDTO(roomName: "Lavanderia", numOfChores: 3, roomColor: .choreYellow),
        RetroChartItemDTO(roomName: "Área externa", numOfChores: 2, roomColor: .choreBlue)
    ]
    
    var maxNumOfChores: Int {
        chartItens.map(\.numOfChores).max() ?? 0
    }
    
    var body: some View {
        VStack {
            Text("6 cômodos")
                .bold()
                .font(.system(size: 64))
                .padding(.top, height * 0.071)
                .accessibilityAddTraits(.isHeader)
            
            Text("A cozinha foi onde você mais trabalhou.")
                .font(.title)
                .multilineTextAlignment(.center)
                .padding(.bottom, height * 0.02)
            
            HStack {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(chartItens) { item in
                        Text("\(item.roomName)")
                            .font(.body)
                            .fontWeight(.semibold)
                            .padding(.bottom, 0.01)
                            // Read by the bar below, together with its value.
                            .accessibilityHidden(true)
                        
                        Capsule()
                            .frame(width: (width * 0.877) * CGFloat(item.numOfChores) / CGFloat(maxNumOfChores), height: height * 0.041)
                            .foregroundStyle(item.roomColor)
                            .overlay(alignment: .leading) {
                                Text("\(item.numOfChores) tarefas")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal)
                            }
                            .padding(.bottom, 0.02)
                            // One element per room: "Cozinha, 8 tarefas".
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(item.roomName.localizedDefault)
                            .accessibilityValue(L10n.tr("%lld tarefas", item.numOfChores))
                    }
                }
                Spacer()
            }
            .padding(.horizontal, width * 0.061)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(L10n.tr("Tarefas por cômodo"))
            .accessibilityChartDescriptor(roomsChartDescriptor)
            
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
    }
    
    /// Audio graph for VoiceOver's chart rotor: chores done per room.
    private var roomsChartDescriptor: CategoryChartDescriptor {
        CategoryChartDescriptor(
            title: L10n.tr("Tarefas por cômodo"),
            summary: nil,
            categoryAxisTitle: L10n.tr("Cômodo"),
            valueAxisTitle: L10n.tr("Tarefas"),
            points: chartItens.map { (label: $0.roomName.localizedDefault, value: Double($0.numOfChores)) }
        )
    }
}

struct RetroNewChoresDivision: View {
    /// Closes the screen that presented the retrospective (e.g. the fullScreenCover in NotificationsView).
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack {
            Image(systemName: "calendar.circle")
                .resizable()
                .frame(width: width * 0.24, height: width * 0.24)
                .padding(.bottom, height * 0.04)
                .foregroundStyle(.choreGreen)
                .padding(.top, height * 0.088)
                .accessibilityDecorative()
            
            Text("Comece a nova divisão de tarefas da casa!")
                .font(.title)
                .bold()
                .multilineTextAlignment(.leading)
                .accessibilityAddTraits(.isHeader)
            
            Text("Clique no botão abaixo para dividir as tarefas entre todos os moradores da casa automaticamente")
                .font(.title3)
                .fontWeight(.regular)
                .multilineTextAlignment(.leading)

            Spacer()
            
            Button {
                
            } label: {
                Text("Divisão automática de tarefas")
                    .frame(width: width * 0.69, height: height * 0.037)
                    .fontWeight(.medium)
                    .font(.system(size: 18))
            }
            .buttonStyle(.glassProminent)
            .glassEffectTransition(.identity)
            
            Button {
                dismiss()
            } label: {
                Text("Dividir mais tarde")
                    .fontWeight(.semibold)
                    .font(.subheadline)
                    .foregroundStyle(.gray) //arrumar o cinza depois
            }
        }
        .padding(16)
    }
}

#Preview {
    RetroView()
}
