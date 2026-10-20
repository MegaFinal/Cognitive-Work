//
//  RetroAlert.swift
//  Cognitive-Work
//
//  Created by Jonas Fernando Nascimento Melo on 29/09/26.
//

import SwiftUI

struct RetroView: View {
    /// Coins to redeem; loaded by the presenting screen before the retrospective opens.
    let coinsViewModel: RetroCoinsViewModel
    @State var isExpanded: Bool = false
    @State var isRetroDone: Bool = false
    @State var page = 0
    @State private var viewModel = RetroViewModel()
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
                        if viewModel.isLoading {
                            ProgressView()
                        } else {
                            VStack(spacing: 12){
                                TabView(selection: $page) {
                                    RetroPercentageOfDoneView(page: $page, viewModel: viewModel)
                                        .tag(0)
                                    RetroStreakView(page: $page, streakDays: viewModel.streakDays)
                                        .tag(1)
                                    RetroPointsView(page: $page, points: viewModel.points, coinsViewModel: coinsViewModel)
                                        .tag(2)
                                    RetroRoomsView(isExpanded: $isExpanded, isRetroDone: $isRetroDone, chartItens: viewModel.rooms)
                                        .tag(3)
                                }
                                .tabViewStyle(.page(indexDisplayMode: .never))
                                
                                PageIndicator(count: 4, current: $page)
                            }
                        }
                    }
                    else if !isExpanded && isRetroDone{
                        RetroNewChoresDivision()
                    }
                }
        }
        // Voice Control has no escape gesture: an invisible, touch-transparent "Fechar"
        // element in the top corner lets the user say "Toque em Fechar".
        .overlay(alignment: .topTrailing) {
            DashboardVoiceControlButton(
                labels: [L10n.tr("Fechar"), L10n.tr("Sair")],
                action: { dismissRetro() }
            )
        }
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape) { dismissRetro() }
        .task { await viewModel.load() }
        // Each step swaps the whole content: let VoiceOver re-read it from the top.
        .onChange(of: isExpanded) { VoiceOver.screenChanged() }
        .onChange(of: isRetroDone) { VoiceOver.screenChanged() }
        .onChange(of: page) { VoiceOver.screenChanged() }
    }
}

struct PageIndicator: View {
    let count: Int
    @Binding var current: Int
    /// VoiceOver pages with the adjustable action; everyone else (Voice Control) gets
    /// the invisible "Anterior" / "Próxima" elements next to the dots.
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled

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
        .voiceOverLabel(L10n.tr("Página"))
        .voiceOverValue(L10n.tr("%lld de %lld", current + 1, count))
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
        .voiceControlNames([L10n.tr("Página")])
        .accessibilityActions {
            Button(L10n.tr("Próxima")) { if current < count - 1 { current += 1 } }
            Button(L10n.tr("Anterior")) { if current > 0 { current -= 1 } }
        }
        // Voice Control can't use adjustable actions: "Toque em Próxima" / "Toque em Anterior".
        .overlay(alignment: .leading) {
            if !voiceOverEnabled && current > 0 {
                DashboardVoiceControlButton(
                    labels: [L10n.tr("Anterior"), L10n.tr("Voltar")],
                    action: { current -= 1 }
                )
                .offset(x: -32)
            }
        }
        .overlay(alignment: .trailing) {
            if !voiceOverEnabled && current < count - 1 {
                DashboardVoiceControlButton(
                    labels: [L10n.tr("Próxima"), L10n.tr("Avançar")],
                    action: { current += 1 }
                )
                .offset(x: 32)
            }
        }
    }
}

/// An invisible element that only exists for Voice Control (and VoiceOver) to activate by
/// name. It draws nothing and lets touches through, so the visual design is unchanged.
struct DashboardVoiceControlButton: View {
    /// Spoken names; the first is also the accessibility label.
    let labels: [String]
    let action: () -> Void

    var body: some View {
        Color.clear
            .frame(width: 28, height: 28)
            .allowsHitTesting(false)
            .accessibilityElement()
            .voiceOverLabel(labels.first ?? "")
            .voiceControlNames(labels)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { action() }
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
    let viewModel: RetroViewModel
    @Environment(\.dismiss) private var dismissRetro
    
    private var percentage: Double { viewModel.percentage }
    
    private var subtitle: LocalizedStringKey {
        switch percentage {
        case 80...: "Você mandou muito bem!"
        case 50..<80: "Faltou pouco para completar tudo"
        default: "Vamos tentar de novo na próxima"
        }
    }
    
    private var cheer: LocalizedStringKey {
        switch percentage {
        case 80...: "continue assim!"
        case 50..<80: "quase lá!"
        default: "você consegue!"
        }
    }

    var body: some View {
        ZStack {
            VStack {
                Spacer ()
                
                Text("\(String(format: "%.0f", percentage))%")
                    .bold()
                    .font(.system(size: 64))
                    .padding(.bottom, height * 0.03)
                    .voiceOverLabel(L10n.tr("%@ das tarefas concluídas", ChartA11y.percent(percentage / 100)))
                    .accessibilityAddTraits(.isHeader)
                
                Text("Você realizou \(viewModel.completedCount) de \(viewModel.totalCount) \n tarefas da sua escala")
                    .font(.title)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, height * 0.008)
                
                Text(subtitle)
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.subTitleGray) //Arrumar depois a cor
                
                Spacer()
                
                Text(cheer)
                    .bold()
                    .font(.system(size: 40))
                    .padding(.bottom, height * 0.018)
                
                Button {
                    dismissRetro()
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
                .voiceControlNames([L10n.tr("Continuar"), L10n.tr("Próxima")])
                .buttonStyle(.glassProminent)
                .glassEffectTransition(.identity)
            }
        }
    }
}

private struct RetroStreakView: View {
    @Binding var page: Int
    let streakDays: Int
    @Environment(\.dismiss) private var dismissRetro
    
    var body: some View {
        VStack {
            
            Spacer()
            
            Image(systemName: "flame.fill")
                .resizable()
                .frame(width: width * 0.54, height: height * 0.3)
                .foregroundStyle(streakDays > 0 ? Color.choreOrange : Color.gray)
                .padding(.bottom, height * 0.037)
                .accessibilityDecorative()
            
            Text("\(streakDays) dias")
                .bold()
                .font(.system(size: 64))
                .padding(.bottom, height * 0.014)
                .accessibilityAddTraits(.isHeader)
            
            Text("seguidos sem atrasar nenhuma tarefa")
                .fontWeight(.regular)
                .font(.title)
                .multilineTextAlignment(.center)
                .padding(.bottom, height * 0.014)
            
            Text(streakDays > 0 ? "Continue assim!" : "Dá para começar ainda hoje!")
                .font(.callout)
                .foregroundStyle(.gray) //arrumar o cinza depois
                .padding(.bottom, height * 0.093)

            
            Button {
                dismissRetro()
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
            .voiceControlNames([L10n.tr("Continuar"), L10n.tr("Próxima")])
            .buttonStyle(.glassProminent)
            .glassEffectTransition(.identity)
        }
    }
}

private struct RetroPointsView: View {
    @Binding var page: Int
    let points: Int
    let coinsViewModel: RetroCoinsViewModel
    @Environment(\.dismiss) private var dismissRetro
    
    var body: some View {
        VStack {
            
            Spacer()
            
            Image("RetroPig")
                .resizable()
                .frame(width: width * 0.6, height: width * 0.6)
                .foregroundStyle(.gray)
                .padding(.bottom, height * 0.037)
                .accessibilityDecorative()
            
            Text("\(points) pontos")
                .bold()
                .font(.system(size: 64))
                .padding(.bottom, height * 0.014)
                .accessibilityAddTraits(.isHeader)
            
            Text("ganhos com as tarefas que você concluiu")
                .fontWeight(.regular)
                .font(.title)
                .multilineTextAlignment(.center)
                .padding(.bottom, height * 0.014)
            
            Text("Cada tarefa feita conta!")
                .font(.callout)
                .foregroundStyle(.gray) //arrumar o cinza depois
                .padding(.bottom, height * 0.093)

            // Coins earned by rank in the cycle that ended.
            RetroCoinsRedeemButton(viewModel: coinsViewModel)
                .padding(.bottom, height * 0.014)

            
            Button {
                dismissRetro()
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
            .voiceControlNames([L10n.tr("Continuar"), L10n.tr("Próxima")])
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
    
    /// Completed chores per room, most first (see ``RetroViewModel/rooms``).
    let chartItens: [RetroChartItemDTO]
    
    var maxNumOfChores: Int {
        chartItens.map(\.numOfChores).max() ?? 0
    }
    
    var body: some View {
        VStack {
            if let topRoom = chartItens.first {
                Text("\(chartItens.count) cômodos")
                    .bold()
                    .font(.system(size: 64))
                    .padding(.top, height * 0.071)
                    .accessibilityAddTraits(.isHeader)
                
                Text("\(topRoom.roomName.localizedDefault) foi onde você mais trabalhou.")
                    .font(.title)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, height * 0.02)
            } else {
                Text("Nenhuma tarefa concluída nesses 15 dias")
                    .bold()
                    .font(.title)
                    .multilineTextAlignment(.center)
                    .padding(.top, height * 0.071)
                    .accessibilityAddTraits(.isHeader)
            }
            
            if !chartItens.isEmpty {
                HStack {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(chartItens) { item in
                            Text(item.roomName.localizedDefault)
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
                                .voiceOverLabel(item.roomName.localizedDefault)
                                .voiceOverValue(L10n.tr("%lld tarefas", item.numOfChores))
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, width * 0.061)
                .accessibilityElement(children: .contain)
                .voiceOverLabel(L10n.tr("Tarefas por cômodo"))
                .accessibilityChartDescriptor(roomsChartDescriptor)
            }
            
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
    RetroView(coinsViewModel: RetroCoinsViewModel())
}
