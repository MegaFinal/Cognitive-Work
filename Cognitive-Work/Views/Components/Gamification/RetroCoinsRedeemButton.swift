//
//  RetroCoinsRedeemButton.swift
//  Cognitive-Work
//
//  Created by Claude on 16/10/26.
//

import SwiftUI
import CloudKit

/// The retrospective's "Resgatar moedas" button: confirms the user's pending cycle payouts and
/// credits them to their wallet (see ``CycleSettlementService``).
///
/// The data comes from ``RetroViewModel``, which the presenting screen loads before the
/// retrospective opens. Shows nothing when there is nothing to redeem.
struct RetroCoinsRedeemButton: View {

    let viewModel: RetroViewModel

    var body: some View {
        VStack(spacing: 6) {
            if viewModel.didRedeem {
                Label("Moedas resgatadas", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 17))
                    .fontWeight(.semibold)
                    .foregroundStyle(.choreGreen)
            } else if viewModel.pendingAmount > 0 {
                Button {
                    Task { await viewModel.redeem() }
                } label: {
                    Group {
                        if viewModel.isWorking {
                            ProgressView()
                        } else {
                            Text("Resgatar \(viewModel.pendingAmount) moedas")
                        }
                    }
                    .frame(width: width * 0.69, height: height * 0.037)
                    .fontWeight(.medium)
                    .font(.system(size: 17))
                }
                .buttonStyle(.glassProminent)
                .disabled(viewModel.isWorking)
            }

            if let errorText = viewModel.errorText {
                Text(errorText)
                    .font(.footnote)
                    .foregroundStyle(.subTitleGray)
                    .multilineTextAlignment(.center)
            }
        }
        // Normally already loaded by the presenting screen; otherwise this loads it.
        .task { await viewModel.load() }
    }
}
