//
//  RetroPointsView.swift
//  Cognitive-Work
//
//  Created by Jonas Fernando Nascimento Melo on 29/09/26.
//

import SwiftUI

/// Reads only `viewModel.pointsContent`. Thresholds, coin counts and messages live in the view model.
struct RetroPointsView: View {
    let viewModel: RetroViewModel
    /// Coins earned by rank in the cycle that ended. `nil` hides the redeem button (previews).
    var coinsViewModel: RetroCoinsViewModel? = nil

    @State private var showCoinPig = false
    @State private var showFloatingCoins = false

    private var content: RetroPointsContent { viewModel.pointsContent }

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
                    RetroCoinsScatter(count: content.floatingCoinsCount)
                }
            }
            .padding(.bottom, height * 0.037)
            // Restarts if the content changes while the page is on screen.
            .task(id: content) {
                showCoinPig = false
                showFloatingCoins = false
                guard content.hasCoinPig else { return }
                try? await Task.sleep(for: .seconds(0.6))
                withAnimation(.spring(response: 0.5, dampingFraction: 0.5)) {
                    showCoinPig = true
                }
                guard content.hasFloatingCoins else { return }
                try? await Task.sleep(for: .seconds(0.5))
                showFloatingCoins = true
            }
            
            Text(content.pointsLabel)
                .bold()
                .font(.system(size: 64))
                .padding(.bottom, height * 0.014)
            
            Text("adquiridos por ter notado algo na casa")
                .fontWeight(.regular)
                .font(.title)
                .multilineTextAlignment(.center)
                .padding(.bottom, height * 0.014)
            
            Text(content.message)
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(.gray) //arrumar o cinza depois
                .padding(.horizontal, 24)
                .padding(.bottom, height * 0.093)

            if let coinsViewModel {
                RetroCoinsRedeemButton(viewModel: coinsViewModel)
                    .padding(.bottom, height * 0.014)
            }
            
            Button {
                withAnimation {
                    viewModel.skipRetrospective()
                }
            } label: {
                Text("ver depois")
                    .fontWeight(.semibold)
                    .font(.subheadline)
                    .foregroundStyle(.gray) //arrumar o cinza depois
            }
            
            
            Button {
                withAnimation {
                    viewModel.continueToNextPage()
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

#if DEBUG
#Preview("4 pontos") {
    RetroPreviewHost(points: 4) { RetroPointsView(viewModel: $0) }
}

#Preview("50 pontos") {
    RetroPreviewHost(points: 50) { RetroPointsView(viewModel: $0) }
}

#Preview("100 pontos") {
    RetroPreviewHost(points: 100) { RetroPointsView(viewModel: $0) }
}
#endif
