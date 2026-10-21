//
//  RetroPercentageOfDoneView.swift
//  Cognitive-Work
//
//  Created by Jonas Fernando Nascimento Melo on 29/09/26.
//

import SwiftUI

/// Reads only `viewModel.percentageContent`; all numbers and messages come from the view model.
struct RetroPercentageOfDoneView: View {
    let viewModel: RetroViewModel
    /// Animated value (0...100) that drives the pie and the counter.
    @State private var percentage: Double = 0.0

    private var content: RetroPercentageContent { viewModel.percentageContent }

    private var isActive: Bool { viewModel.isPageActive(.percentage) }

    private struct AnimationKey: Equatable {
        let isActive: Bool
        let target: Double
    }

    var body: some View {
        ZStack {
            Color(.chorePurple)
                .overlay{
                    PieSlice(progress: percentage / 100)
                        .padding(.bottom, height * 0.127)
                        .frame(width: height * 2, height: height * 2)
                        .ignoresSafeArea()
                        .foregroundStyle(.white)
                }
                .ignoresSafeArea()

            VStack{
                Keyhole()
                    .aspectRatio(width * 0.8 / height * 1.5, contentMode: .fit)
                    .padding(.top, height * 0.24)
                    .foregroundStyle(.white)
                
            }
                

            VStack {
                Spacer ()
                
                AnimatedPercentageText(value: percentage)
                    .bold()
                    .font(.system(size: 64))
                    .padding(.bottom, height * 0.03)
                
                Text(content.summary)
                    .font(.title)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, height * 0.008)
                
                Text(content.subtitle)
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.subTitleGray) //Arrumar depois a cor
                
                Spacer()
                
                Text(content.closing)
                    .bold()
                    .font(.system(size: 40))
                    .padding(.bottom, height * 0.018)
                
                Button {
                    withAnimation {
                        viewModel.skipRetrospective()
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
                        viewModel.advance()
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        // Not onAppear: changing the state there can be applied before the first frame is drawn,
        // so the view would appear already filled. Drawing 0 first, then animating, always plays.
        // Keyed on the page being the visible one: the paged TabView builds this page while the
        // previous one is still on screen, and the animation would play where nobody sees it.
        // Re-runs every time the page becomes visible and if the data changes.
        .task(id: AnimationKey(isActive: isActive, target: content.percentage)) {
            percentage = 0
            guard isActive else { return }
            try? await Task.sleep(for: .seconds(0.3))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 2)) {
                percentage = content.percentage
            }
        }
    }
}

#if DEBUG
#Preview("0%") {
    RetroPreviewHost(completed: 0, total: 20, page: .percentage) { RetroPercentageOfDoneView(viewModel: $0) }
}

#Preview("25%") {
    RetroPreviewHost(completed: 25, total: 100, page: .percentage) { RetroPercentageOfDoneView(viewModel: $0) }
}

#Preview("50%") {
    RetroPreviewHost(completed: 50, total: 100, page: .percentage) { RetroPercentageOfDoneView(viewModel: $0) }
}

#Preview("75%") {
    RetroPreviewHost(completed: 75, total: 100, page: .percentage) { RetroPercentageOfDoneView(viewModel: $0) }
}

#Preview("100%") {
    RetroPreviewHost(completed: 100, total: 100, page: .percentage) { RetroPercentageOfDoneView(viewModel: $0) }
}
#endif
