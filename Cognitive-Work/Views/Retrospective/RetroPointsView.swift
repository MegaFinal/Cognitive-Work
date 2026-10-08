//
//  RetroPointsView.swift
//  Cognitive-Work
//
//  Created by Jonas Fernando Nascimento Melo on 29/09/26.
//

import SwiftUI

struct RetroPointsView: View {
    @Binding var page: Int
    @Binding var isRetroDone: Bool
    var points: Int = 4

    /// From this many points on, the pig gets a coin (RetroPigCoin).
    private let coinPigThreshold = 50
    /// From this many points on, coins also float around the pig.
    private let floatingCoinsThreshold = 100
    /// Every extra `pointsPerExtraCoin` points after the threshold reveals one more floating coin.
    private let pointsPerExtraCoin = 50

    @State private var showCoinPig = false
    @State private var showFloatingCoins = false

    private var hasCoinPig: Bool { points >= coinPigThreshold }
    private var hasFloatingCoins: Bool { points >= floatingCoinsThreshold }

    private var floatingCoinsCount: Int {
        guard hasFloatingCoins else { return 0 }
        let extra = (points - floatingCoinsThreshold) / pointsPerExtraCoin
        return min(2 + extra, RetroCoinsScatter.maxCount)
    }

    private var message: String {
        if hasFloatingCoins {
            return "Boa parte do que a casa fez começou com você percebendo, parabéns!"
        } else if hasCoinPig {
            return "Reparar que algo precisa ser feito também é trabalho, parabéns!"
        } else {
            return "Cada coisa que você reparou conta!"
        }
    }

    var body: some View {
        VStack {
            
            Spacer()
            
            ZStack {
                Image("RetroPig")
                    .resizable()
                    .opacity(showCoinPig ? 0 : 1)
                
                Image("RetroPigCoin")
                    .resizable()
                    .opacity(showCoinPig ? 1 : 0)
                    .scaleEffect(showCoinPig ? 1 : 0.8)
            }
            .frame(width: showCoinPig ? width * 0.6 : width * 0.55, height: showCoinPig ? width * 0.6 : height * 0.159)
            .foregroundStyle(.gray)
            .overlay {
                if showFloatingCoins {
                    RetroCoinsScatter(count: floatingCoinsCount)
                }
            }
            .padding(.bottom, height * 0.037)
            .task {
                guard hasCoinPig else { return }
                try? await Task.sleep(for: .seconds(0.6))
                withAnimation(.spring(response: 0.5, dampingFraction: 0.5)) {
                    showCoinPig = true
                }
                guard hasFloatingCoins else { return }
                try? await Task.sleep(for: .seconds(0.5))
                showFloatingCoins = true
            }
            
            Text("\(points) \(points == 1 ? "ponto" : "pontos")")
                .bold()
                .font(.system(size: 64))
                .padding(.bottom, height * 0.014)
            
            Text("adquiridos por ter notado algo na casa")
                .fontWeight(.regular)
                .font(.title)
                .multilineTextAlignment(.center)
                .padding(.bottom, height * 0.014)
            
            Text(message)
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(.gray) //arrumar o cinza depois
                .padding(.horizontal, 24)
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


#Preview("4 pontos") {
    @Previewable @State var page = 2
    @Previewable @State var isRetroDone = false
    RetroPointsView(page: $page, isRetroDone: $isRetroDone, points: 4)
}

#Preview("50 pontos") {
    @Previewable @State var page = 2
    @Previewable @State var isRetroDone = false
    RetroPointsView(page: $page, isRetroDone: $isRetroDone, points: 50)
}

#Preview("100 pontos") {
    @Previewable @State var page = 2
    @Previewable @State var isRetroDone = false
    RetroPointsView(page: $page, isRetroDone: $isRetroDone, points: 100)
}
