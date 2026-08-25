//
//  ContentView.swift
//  Cognitive-Work
//
//  Created by Jonas Fernando Nascimento Melo on 07/08/26.
//

import SwiftUI
import SwiftData
import CloudKit

///// Test harness for the CloudKit sharing flow: creates one house, shares it, shows the invite link.
/////
///// >Warning: Temporary test implementation **must be replaced** before release.
///// >the house name, supports a single record, and reports no errors to the user.
/////
///// TODO: Replace with the real house-management screen. 
//struct ContentView: View {
//
//    // MARK: - Dependencies
//
//    private let viewModel = ContentViewModel()
//
//    // MARK: - Constants
//
//    /// Fixed name used so two devices can find the same test record.
//    private let houseName = "JonesHouseTest"
//
//    // MARK: - State
//
//    /// House loaded from the store, or `nil` when none exists yet.
//    @State private var house: HouseModel?
//
//    /// CloudKit invitation link for the current share.
//    @State private var shareURL: URL?
//
//    /// `true` while the create operation is running.
//    @State private var isWorking = false
//
//    /// Message describing the last failure, or `nil` when there is none.
//    @State private var errorMessage: String?
//
//    // MARK: - Body
//
//    /// Reloads ``house`` on appear, on pull-to-refresh, and when a share invite is accepted.
//    var body: some View {
//        ScrollView {
//            VStack(spacing: 16) {
//                Text(house?.name ?? "Nenhuma casa ainda")
//                    .font(.headline)
//
//                Button {
//                    Task {
//                        (self.house, self.shareURL) = await viewModel.createHouseAndShare(
//                            houseName: houseName,
//                            description: "description"
//                        )
//                    }
//                } label: {
//                    if isWorking {
//                        ProgressView()
//                            .frame(maxWidth: .infinity)
//                    } else {
//                        Label("Criar casa", systemImage: "house")
//                            .frame(maxWidth: .infinity)
//                    }
//                }
//                .buttonStyle(.borderedProminent)
//                .disabled(house != nil || isWorking)
//
//                CopyButtonView(textToCopy: shareURL?.absoluteString)
//
//                if let shareURL {
//                    ShareLink(item: shareURL) {
//                        Label("Compartilhar convite", systemImage: "square.and.arrow.up")
//                    }
//                }
//
//                if let errorMessage {
//                    Text(errorMessage)
//                        .font(.footnote)
//                        .foregroundStyle(.red)
//                        .multilineTextAlignment(.center)
//                }
//            }
//            .padding()
//            .frame(maxWidth: .infinity)
//        }
//        .task { house = await viewModel.loadHouse() }
//        .refreshable { house = await viewModel.loadHouse() }
//        .onReceive(NotificationCenter.default.publisher(for: .didAcceptShare)) { _ in
//            Task { house = await viewModel.loadHouse() }
//        }
//    }
//}
//
//// MARK: - Preview

struct ContentView: View {
    var body: some View {
        FirstOnboardingView()
//        SecondOnboardingView()
//        ThirdOnboardingView()
    }
}

#Preview {
    ContentView()
}

