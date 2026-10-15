//
//  TermsGate.swift
//  Cognitive-Work
//

import SwiftUI

extension View {

    /// Blocks the app until the Terms of Use are accepted: shows them on first launch (and when
    /// they change) and replaces the app with a farewell screen when they are declined.
    func requiresTermsAcceptance() -> some View {
        modifier(TermsGate())
    }
}

private struct TermsGate: ViewModifier {

    @State private var viewModel = TermsViewModel()

    func body(content: Content) -> some View {
        Group {
            if viewModel.decision == .declined {
                TermsDeclinedView(
                    title: viewModel.farewellTitle,
                    message: viewModel.farewellMessage,
                    onReviewTerms: { viewModel.reviewTerms() }
                )
                .transition(.opacity)
            } else {
                content
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.decision)
        .sheet(isPresented: Binding(
            get: { viewModel.isShowingTerms },
            set: { _ in }
        )) {
            TermsOfUseView(viewModel: viewModel)
        }
    }
}
