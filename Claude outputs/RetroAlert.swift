//
//  RetroAlert.swift
//  Cognitive-Work
//
//  Created by Jonas Fernando Nascimento Melo on 29/09/26.
//

import SwiftUI

// MARK: - Dados da retrospectiva (15 dias da divisão atual)

struct RetroSummary {
    var doneChores: Int
    var totalChores: Int
    var streakDays: Int
    var points: Int

    var completion: Double {
        guard totalChores > 0 else { return 0 }
        return min(Double(doneChores) / Double(totalChores), 1)
    }
}

extension RetroSummary {
    static let mock = RetroSummary(doneChores: 15, totalChores: 20, streakDays: 7, points: 14)
}

// MARK: - Variações (de cima para baixo no Figma)

private enum CompletionTier {
    case none, started, half, almost, full

    init(_ completion: Double) {
        switch completion {
        case ..<0.01: self = .none
        case ..<0.5:  self = .started
        case ..<0.75: self = .half
        case ..<1.0:  self = .almost
        default:      self = .full
        }
    }

    var subtitle: String {
        switch self {
        case .none:    "Vamos tentar de novo na próxima"
        case .started: "A próxima escala é uma nova chance!"
        case .half:    "Metade da escala feita!"
        case .almost:  "Quase toda a escala feita!"
        case .full:    "Você não deixou nada para trás!"
        }
    }

    var closing: String {
        switch self {
        case .none:            "você consegue!"
        case .started, .half:  "quase lá!"
        case .almost, .full:   "parabéns!"
        }
    }
}

private enum StreakTier {
    case none, some, week, fortnight

    init(_ days: Int) {
        switch days {
        case ..<1:  self = .none
        case ..<7:  self = .some
        case ..<15: self = .week
        default:    self = .fortnight
        }
    }

    var title: String {
        self == .fortnight ? "seguidos sem atrasar nenhuma tarefa!" : "seguidos sem atrasar nenhuma tarefa"
    }

    var subtitle: String {
        switch self {
        case .none:      "Dá para começar ainda hoje!"
        case .some:      "Bom começo, continue assim!"
        case .week:      "Uma semana inteira sem atrasar, parabéns!"
        case .fortnight: "A quinzena inteira sem faltar uma única vez, parabéns!"
        }
    }
}

private enum PointsTier {
    case none, few, coin, rich

    // Limiares ajustáveis
    static let coinThreshold = 10
    static let richThreshold = 30

    init(_ points: Int) {
        switch points {
        case ..<1:                   self = .none
        case ..<Self.coinThreshold:  self = .few
        case ..<Self.richThreshold:  self = .coin
        default:                     self = .rich
        }
    }

    var hasCoin: Bool { self == .coin || self == .rich }

    var subtitle: String {
        switch self {
        case .none: "Repare em algo pela casa na próxima!"
        case .few:  "Cada coisa que você reparou conta!"
        case .coin: "Reparar no que precisa ser feito também é trabalho, parabéns!"
        case .rich: "Boa parte do que a casa fez surgiu com você percebendo, parabéns!"
        }
    }
}

// MARK: - RetroView

struct RetroView: View {
    var summary: RetroSummary = .mock
    @State var isExpanded: Bool = false
    @State var isRetroDone: Bool = false
    @State var page = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { }

            RoundedRectangle(cornerRadius: 32)
                .frame(width: isExpanded ? .infinity : width * 0.87, height: isExpanded ? .infinity : height * 0.59)
                .foregroundStyle(.white)
                .ignoresSafeArea()
                .overlay {
                    if !isExpanded && !isRetroDone {
                        RetroAlert(isExpanded: $isExpanded)
                    }
                    else if isExpanded && !isRetroDone {
                        TabView(selection: $page) {
                            RetroPercentageOfDoneView(summary: summary, isActive: page == 0, page: $page, isRetroDone: $isRetroDone)
                                .tag(0)
                            RetroStreakView(days: summary.streakDays, isActive: page == 1, page: $page, isRetroDone: $isRetroDone)
                                .retroPageInsets()
                                .tag(1)
                            RetroPointsView(points: summary.points, isActive: page == 2, page: $page, isRetroDone: $isRetroDone)
                                .retroPageInsets()
                                .tag(2)
                            RetroRoomsView(isExpanded: $isExpanded, isRetroDone: $isRetroDone)
                                .retroPageInsets(top: false)
                                .tag(3)
                        }
                        .tabViewStyle(.page(indexDisplayMode: .never))
                        .overlay(alignment: .bottom) {
                            PageIndicator(count: 4, current: $page)
                                .padding(.bottom, height * 0.045)
                        }
                        .ignoresSafeArea()
                    }
                    else if !isExpanded && isRetroDone {
                        RetroNewChoresDivision()
                    }
                }
        }
    }
}

// MARK: - Layout helpers

private enum RetroLayout {
    /// Espaço inferior reservado para o PageIndicator + home indicator.
    static func bottomInset(_ screenHeight: CGFloat) -> CGFloat { screenHeight * 0.085 }
    static func topInset(_ screenHeight: CGFloat) -> CGFloat { screenHeight * 0.06 }
}

private extension View {
    func retroPageInsets(top: Bool = true) -> some View {
        self
            .padding(.top, top ? RetroLayout.topInset(height) : 0)
            .padding(.bottom, RetroLayout.bottomInset(height))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Texto que "conta" de 0 até o valor final quando `value` é animado.
private struct CountingText: View, Animatable {
    var value: Double
    let format: (Int) -> String

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        Text(format(Int(value.rounded())))
            .monospacedDigit()
    }
}

private struct RetroFooter: View {
    let onLater: () -> Void
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onLater) {
                Text("ver depois")
                    .fontWeight(.semibold)
                    .font(.subheadline)
                    .foregroundStyle(.subTitleGray) // Arrumar depois a cor
            }
            .padding(.bottom, height * 0.014)

            Button(action: onContinue) {
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

private func withoutAnimation(_ body: () -> Void) {
    var transaction = Transaction()
    transaction.disablesAnimations = true
    withTransaction(transaction, body)
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
    }
}

// MARK: - Alerta inicial

private struct RetroAlert: View {
    @Binding var isExpanded: Bool

    var body: some View {
        VStack {
            Image(systemName: "chart.bar.xaxis")
                .resizable()
                .frame(width: width * 0.27, height: height * 0.089)
                .foregroundStyle(.choreYellow)
                .padding(.bottom, height * 0.05)

            Text("Sua retrospectiva chegou!")
                .bold()
                .font(.largeTitle)
                .multilineTextAlignment(.center)
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
                isExpanded = true
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

// MARK: - Tela 2: porcentagem (fundo roxo que "varre" ao redor da fechadura)

/// Formato de fechadura: círculo + trapézio que alarga até a base.
private struct KeyholeShape: Shape {
    static let centerYRatio: CGFloat = 0.38   // em relação à altura
    static let radiusRatio: CGFloat = 0.42    // em relação à largura

    static func center(in rect: CGRect) -> CGPoint {
        CGPoint(x: rect.midX, y: rect.minY + rect.height * centerYRatio)
    }

    func path(in rect: CGRect) -> Path {
        let c = Self.center(in: rect)
        let r = rect.width * Self.radiusRatio
        let circle = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))

        let topY = c.y + r * 0.6
        let topHalf = rect.width * 0.2
        let bottomHalf = rect.width * 0.34

        var trapezoid = Path()
        trapezoid.move(to: CGPoint(x: c.x - topHalf, y: topY))
        trapezoid.addLine(to: CGPoint(x: c.x + topHalf, y: topY))
        trapezoid.addLine(to: CGPoint(x: c.x + bottomHalf, y: rect.maxY))
        trapezoid.addLine(to: CGPoint(x: c.x - bottomHalf, y: rect.maxY))
        trapezoid.closeSubpath()

        return circle.union(trapezoid)
    }
}

/// Fatia que cresce no sentido horário a partir das 3h (25% = canto inferior direito, 50% = metade de baixo...).
private struct SweepShape: Shape {
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        guard progress > 0 else { return Path() }
        let c = KeyholeShape.center(in: rect)
        let radius = hypot(rect.width, rect.height) * 1.5
        var path = Path()
        path.move(to: c)
        path.addArc(center: c,
                    radius: radius,
                    startAngle: .degrees(0),
                    endAngle: .degrees(360 * min(progress, 1)),
                    clockwise: false)
        path.closeSubpath()
        return path
    }
}

private struct RetroPercentageOfDoneView: View {
    let summary: RetroSummary
    let isActive: Bool
    @Binding var page: Int
    @Binding var isRetroDone: Bool

    @State private var progress: Double = 0
    @State private var textsIn = false
    @State private var closingIn = false
    @State private var runID = 0

    private var tier: CompletionTier { CompletionTier(summary.completion) }

    var body: some View {
        GeometryReader { geo in
            let rect = CGRect(origin: .zero, size: geo.size)

            ZStack {
                Color.white
                SweepShape(progress: progress)
                    .fill(Color.chorePurple)
                KeyholeShape()
                    .fill(Color.white)

                // Bloco central dentro do círculo
                VStack(spacing: 0) {
                    CountingText(value: progress * 100) { "\($0)%" }
                        .bold()
                        .font(.system(size: 64))
                        .padding(.bottom, height * 0.02)

                    VStack(spacing: height * 0.008) {
                        Text("Você realizou \(summary.doneChores) de \(summary.totalChores)\ntarefas da sua escala")
                            .font(.title2)
                        Text(tier.subtitle)
                            .font(.callout)
                            .foregroundStyle(.subTitleGray) // Arrumar depois a cor
                    }
                    .multilineTextAlignment(.center)
                    .opacity(textsIn ? 1 : 0)
                    .offset(y: textsIn ? 0 : 12)
                }
                .frame(width: geo.size.width * 0.72)
                .position(KeyholeShape.center(in: rect))

                // Parte de baixo (dentro do trapézio)
                VStack(spacing: 0) {
                    Spacer()

                    Text(tier.closing)
                        .bold()
                        .font(.system(size: 40))
                        .scaleEffect(closingIn ? 1 : 0.4)
                        .opacity(closingIn ? 1 : 0)
                        .padding(.bottom, height * 0.018)

                    RetroFooter {
                        withAnimation { isRetroDone = true }
                    } onContinue: {
                        withAnimation { page += 1 }
                    }
                }
                .padding(.bottom, RetroLayout.bottomInset(height))
            }
        }
        .sensoryFeedback(.success, trigger: closingIn) { _, new in new && tier == .full }
        .onChange(of: isActive, initial: true) { _, active in
            active ? play() : reset()
        }
    }

    private func play() {
        reset()
        let run = runID

        withAnimation(.easeOut(duration: 0.4).delay(0.15)) {
            textsIn = true
        }
        withAnimation(.easeInOut(duration: 1.3).delay(0.3)) {
            progress = summary.completion
        } completion: {
            guard run == runID else { return }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.55).delay(0.1)) {
                closingIn = true
            }
        }
    }

    private func reset() {
        runID += 1
        withoutAnimation {
            progress = 0
            textsIn = false
            closingIn = false
        }
    }
}

// MARK: - Tela 3: dias seguidos (chama)

private struct RetroStreakView: View {
    let days: Int
    let isActive: Bool
    @Binding var page: Int
    @Binding var isRetroDone: Bool

    @State private var count: Double = 0
    @State private var flameIn = false
    @State private var sideFlamesIn = false
    @State private var textsIn = false

    private var tier: StreakTier { StreakTier(days) }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            flame
                .padding(.bottom, height * 0.037)

            CountingText(value: count) { "\($0) \($0 == 1 ? "dia" : "dias")" }
                .bold()
                .font(.system(size: 64))
                .padding(.bottom, height * 0.014)

            VStack(spacing: height * 0.014) {
                Text(tier.title)
                    .fontWeight(.regular)
                    .font(.title)
                Text(tier.subtitle)
                    .font(.callout)
                    .foregroundStyle(.subTitleGray) // arrumar o cinza depois
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
            .opacity(textsIn ? 1 : 0)
            .offset(y: textsIn ? 0 : 12)
            .padding(.bottom, height * 0.07)

            RetroFooter {
                withAnimation { isRetroDone = true }
            } onContinue: {
                withAnimation { page += 1 }
            }
        }
        .sensoryFeedback(.success, trigger: sideFlamesIn) { _, new in new }
        .onChange(of: isActive, initial: true) { _, active in
            active ? play() : reset()
        }
    }

    private var flame: some View {
        ZStack {
            Image(systemName: "flame.fill")
                .resizable()
                .scaledToFit()
                .frame(width: width * 0.54, height: height * 0.27)
                .foregroundStyle(tier == .none ? Color.gray : Color.choreOrange)
                .symbolEffect(.breathe, options: .repeating, isActive: flameIn && tier != .none)
                .scaleEffect(flameIn ? 1 : 0.2, anchor: .bottom)
                .opacity(flameIn ? 1 : 0)

            if tier == .fortnight {
                sideFlame(size: 0.15, x: -0.30, y: 0.03, rotation: -14, delay: 0.0)
                sideFlame(size: 0.17, x: 0.30, y: -0.05, rotation: 12, delay: 0.12)
                sideFlame(size: 0.08, x: 0.10, y: -0.15, rotation: 6, delay: 0.24)
            }
        }
    }

    /// size/x em fração da largura da tela, y em fração da altura.
    private func sideFlame(size: CGFloat, x: CGFloat, y: CGFloat, rotation: Double, delay: Double) -> some View {
        Image(systemName: "flame.fill")
            .resizable()
            .scaledToFit()
            .frame(width: width * size)
            .foregroundStyle(Color.choreOrange)
            .symbolEffect(.breathe, options: .repeating.speed(1.4), isActive: sideFlamesIn)
            .scaleEffect(sideFlamesIn ? 1 : 0, anchor: .bottom)
            .rotationEffect(.degrees(sideFlamesIn ? rotation : 0), anchor: .bottom)
            .offset(x: width * x, y: height * y)
            .animation(.spring(response: 0.45, dampingFraction: 0.5).delay(delay), value: sideFlamesIn)
    }

    private func play() {
        reset()
        withAnimation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.15)) {
            flameIn = true
        }
        withAnimation(.easeOut(duration: 0.9).delay(0.25)) {
            count = Double(days)
        }
        withAnimation(.easeOut(duration: 0.4).delay(0.5)) {
            textsIn = true
        }
        if tier == .fortnight {
            withAnimation(.default.delay(0.8)) {
                sideFlamesIn = true
            }
        }
    }

    private func reset() {
        withoutAnimation {
            count = 0
            flameIn = false
            sideFlamesIn = false
            textsIn = false
        }
    }
}

// MARK: - Tela 4: pontos (porquinho)

private struct RetroPointsView: View {
    let points: Int
    let isActive: Bool
    @Binding var page: Int
    @Binding var isRetroDone: Bool

    @State private var count: Double = 0
    @State private var pigIn = false
    @State private var coinDropped = false
    @State private var coinLanded = false
    @State private var extraCoinsIn = false
    @State private var textsIn = false
    @State private var runID = 0

    private var tier: PointsTier { PointsTier(points) }
    private var pigSize: CGFloat { width * 0.6 }

    // Posição/tamanho da moeda dentro do "RetroPigCoin" (fração do tamanho do porquinho)
    private let slotOffset = CGSize(width: -0.049, height: -0.264)
    private let slotCoinSize: CGFloat = 0.33

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            illustration
                .frame(width: pigSize, height: pigSize)
                .padding(.bottom, height * 0.037)

            CountingText(value: count) { "\($0) \($0 == 1 ? "ponto" : "pontos")" }
                .bold()
                .font(.system(size: 64))
                .padding(.bottom, height * 0.014)

            VStack(spacing: height * 0.014) {
                Text("adquiridos por ter notado algo na casa")
                    .fontWeight(.regular)
                    .font(.title)
                Text(tier.subtitle)
                    .font(.callout)
                    .foregroundStyle(.subTitleGray) // arrumar o cinza depois
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
            .opacity(textsIn ? 1 : 0)
            .offset(y: textsIn ? 0 : 12)
            .padding(.bottom, height * 0.07)

            RetroFooter {
                withAnimation { isRetroDone = true }
            } onContinue: {
                withAnimation { page += 1 }
            }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: coinLanded) { _, new in new }
        .onChange(of: isActive, initial: true) { _, active in
            active ? play() : reset()
        }
    }

    private var illustration: some View {
        ZStack {
            // Moedas extras (30+ pontos)
            if tier == .rich {
                floatingCoin(size: 0.25, x: -0.55, y: -0.40, delay: 0.0)
                floatingCoin(size: 0.47, x: 0.48, y: -0.55, delay: 0.15)
            }

            // Porquinho: troca para a versão com moeda quando ela "encaixa"
            Image(coinLanded ? "RetroPigCoin" : "RetroPig")
                .resizable()
                .scaledToFit()
                .frame(width: pigSize, height: pigSize)
                .keyframeAnimator(initialValue: 1.0, trigger: coinLanded) { content, squash in
                    content.scaleEffect(x: 2 - squash, y: squash, anchor: .bottom)
                } keyframes: { _ in
                    KeyframeTrack {
                        SpringKeyframe(0.88, duration: 0.12)
                        SpringKeyframe(1.05, duration: 0.18)
                        SpringKeyframe(1.0, duration: 0.25)
                    }
                }
                .scaleEffect(pigIn ? 1 : 0.3, anchor: .bottom)
                .opacity(pigIn ? 1 : 0)

            // Moeda caindo no cofrinho
            if tier.hasCoin && !coinLanded {
                Image("RetroCoin")
                    .resizable()
                    .scaledToFit()
                    .frame(width: pigSize * slotCoinSize, height: pigSize * slotCoinSize)
                    .offset(x: pigSize * slotOffset.width,
                            y: pigSize * (coinDropped ? slotOffset.height : -1.0))
                    .opacity(coinDropped ? 1 : 0)
            }
        }
    }

    private func floatingCoin(size: CGFloat, x: CGFloat, y: CGFloat, delay: Double) -> some View {
        Image("RetroCoin")
            .resizable()
            .scaledToFit()
            .frame(width: pigSize * size, height: pigSize * size)
            .phaseAnimator([0.0, 1.0]) { content, phase in
                content.offset(y: -6 * phase)
            } animation: { _ in
                .easeInOut(duration: 1.4)
            }
            .rotation3DEffect(.degrees(extraCoinsIn ? 360 : 0), axis: (x: 0, y: 1, z: 0))
            .scaleEffect(extraCoinsIn ? 1 : 0)
            .offset(x: pigSize * x, y: pigSize * y)
            .animation(.spring(response: 0.6, dampingFraction: 0.6).delay(delay), value: extraCoinsIn)
    }

    private func play() {
        reset()
        let run = runID

        withAnimation(.spring(response: 0.55, dampingFraction: 0.65).delay(0.15)) {
            pigIn = true
        }
        withAnimation(.easeOut(duration: 1.0).delay(0.25)) {
            count = Double(points)
        }
        withAnimation(.easeOut(duration: 0.4).delay(0.5)) {
            textsIn = true
        }

        guard tier.hasCoin else { return }

        withAnimation(.easeIn(duration: 0.4).delay(0.75)) {
            coinDropped = true
        } completion: {
            guard run == runID else { return }
            withoutAnimation { coinLanded = true }
            if tier == .rich {
                withAnimation(.default.delay(0.15)) {
                    extraCoinsIn = true
                }
            }
        }
    }

    private func reset() {
        runID += 1
        withoutAnimation {
            count = 0
            pigIn = false
            coinDropped = false
            coinLanded = false
            extraCoinsIn = false
            textsIn = false
        }
    }
}

// MARK: - Tela 5: cômodos

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
                    }
                }
                Spacer()
            }
            .padding(.horizontal, width * 0.061)

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
}

// MARK: - Nova divisão

struct RetroNewChoresDivision: View {

    var body: some View {
        VStack {
            Image(systemName: "calendar.circle")
                .resizable()
                .frame(width: width * 0.24, height: width * 0.24)
                .padding(.bottom, height * 0.04)
                .foregroundStyle(.choreGreen)
                .padding(.top, height * 0.088)

            Text("Comece a nova divisão de tarefas da casa!")
                .font(.title)
                .bold()
                .multilineTextAlignment(.leading)

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

// MARK: - Previews (uma por variação)

#Preview("Padrão") {
    RetroView()
}

#Preview("0% · 0 dias · 4 pts") {
    RetroView(summary: .init(doneChores: 0, totalChores: 20, streakDays: 0, points: 4), isExpanded: true)
}

#Preview("25% · 3 dias · 4 pts") {
    RetroView(summary: .init(doneChores: 5, totalChores: 20, streakDays: 3, points: 4), isExpanded: true)
}

#Preview("50% · 7 dias · 14 pts") {
    RetroView(summary: .init(doneChores: 10, totalChores: 20, streakDays: 7, points: 14), isExpanded: true)
}

#Preview("75% · 7 dias · 14 pts") {
    RetroView(summary: .init(doneChores: 15, totalChores: 20, streakDays: 7, points: 14), isExpanded: true)
}

#Preview("100% · 15 dias · 34 pts") {
    RetroView(summary: .init(doneChores: 20, totalChores: 20, streakDays: 15, points: 34), isExpanded: true)
}
