//
//  RetroAlert.swift
//  Cognitive-Work
//
//  Created by Jonas Fernando Nascimento Melo on 29/09/26.
//

import SwiftUI

struct RetroAlert: View {
    let viewModel: RetroViewModel
    
    var body: some View {
        VStack {
            Image(systemName: "chart.bar.xaxis")
                .resizable()
                .font(.system(size: 64))
                .frame(width: width * 0.279, height: height * 0.089)
                .foregroundStyle(.choreYellow)
                .padding(.top, height * 0.085)
            
            Text("Sua retrospectiva chegou!")
                .font(.custom("Alan Sans", size: 34))
                .bold()
                .font(.largeTitle)
                .multilineTextAlignment(.center)
                .padding(.top, height * 0.052)
            
            Text("Veja como você se saiu durante os últimos 15 dias")
                .font(.title2)
                .multilineTextAlignment(.center)
                .fontWeight(.regular)
                .padding(.top, height * 0.0187)
            
            Spacer()
            
            Button {
                withAnimation {
                    viewModel.startRetrospective()
                }
            } label: {
                Text("Ver minha retrospectiva")
                    .frame(width: width * 0.69, height: height * 0.037)
                    .fontWeight(.medium)
                    .font(.system(size: 17))
            }
            .buttonStyle(.glassProminent)
            .glassEffectTransition(.identity)
            // The pages need the loaded data.
            .disabled(viewModel.loadState != .loaded)
            
            // Only the house admin, and only once the current division is over.
            if viewModel.canStartNewDivision {
                Button {
                    withAnimation {
                        viewModel.skipRetrospective()
                    }
                } label: {
                    Text("Pular para a nova divisão")
                        .frame(width: width * 0.69, height: height * 0.037)
                        .fontWeight(.medium)
                        .font(.system(size: 17))
                }
                .buttonStyle(.glass)
            }
            
            loadStatus
        }
        .padding(.horizontal)
        .padding(.bottom, height * 0.018)
    }
    
    /// Spinner while loading; message and retry if loading failed.
    @ViewBuilder
    private var loadStatus: some View {
        switch viewModel.loadState {
        case .idle, .loading:
            ProgressView()
                .padding(.top, height * 0.02)
        case .failed(let error):
            VStack(spacing: 4) {
                Text(error.localizedDescription)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.gray)
                Button("Tentar de novo") { viewModel.reload() }
                    .font(.footnote.weight(.semibold))
            }
            .padding(.top, height * 0.02)
        case .loaded:
            EmptyView()
        }
    }
}

#if DEBUG
#Preview {
    RetroPreviewHost(startOnPages: false) { RetroAlert(viewModel: $0) }
}
#endif
