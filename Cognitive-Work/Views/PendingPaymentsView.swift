//
//  PendingPaymentsView.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 08/10/26.
//

import SwiftUI

/// "Pendências": who owes whom for the house's shopping. Rendering only; the numbers, texts and
/// settling live in ``PendingPaymentsViewModel``.
struct PendingPaymentsView: View {

    @State private var viewModel: PendingPaymentsViewModel

    init(viewModel: PendingPaymentsViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }

    /// Used by ``ShopListView`` to open the screen on the list it already has loaded.
    init(shopList: ShopListViewModel) {
        self._viewModel = State(initialValue: PendingPaymentsViewModel(shopList: shopList))
    }

    var body: some View {
        let groups = viewModel.groups

        VStack(alignment: .leading, spacing: 22) {
            VStack(spacing: 12) {
                DebtBalanceCard(
                    title: viewModel.balanceTitle,
                    caption: viewModel.balanceCaption,
                    amountText: viewModel.balanceText,
                    color: viewModel.balanceColor
                )
                summaryCards
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            if groups.isEmpty {
                // Centered in the space under the cards.
                emptyState
                    .frame(maxHeight: .infinity)
                    .padding(.bottom, 60)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        ForEach(groups) { group in
                            section(for: group)
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 60)
                }
            }
        }
        .background(Color.white.ignoresSafeArea())
        .navigationTitle("Pendências")
        .navigationBarTitleDisplayMode(.inline)
        .animation(.snappy, value: viewModel.selectedDirection)
        .animation(.snappy, value: viewModel.groups.map(\.id))
        .confirmationDialog(
            viewModel.confirmationTitle,
            isPresented: Binding(
                get: { viewModel.settlementRequest != nil },
                set: { if !$0 { viewModel.cancelSettlement() } }
            ),
            titleVisibility: .visible
        ) {
            Button("Pagar") {
                Task { await viewModel.confirmSettlement() }
            }
            Button("Cancelar", role: .cancel) {
                viewModel.cancelSettlement()
            }
        } message: {
            Text(viewModel.confirmationMessage)
        }
        .alert(
            "Não foi possível concluir",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.clearError() } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    // MARK: - Pieces

    private var summaryCards: some View {
        HStack(spacing: 12) {
            ForEach(DebtDirection.allCases) { direction in
                DebtSummaryCard(
                    title: viewModel.title(for: direction),
                    amount: viewModel.amountParts(viewModel.total(for: direction)),
                    isSelected: viewModel.selectedDirection == direction,
                    banner: viewModel.banner,
                    onTap: {
                        HapticsManager.selection()
                        viewModel.selectedDirection = direction
                    }
                )
            }
        }
    }

    private func section(for group: DebtGroup) -> some View {
        DebtGroupSection(
            user: group.counterparty,
            title: viewModel.title(for: group),
            totalText: viewModel.currencyText(group.total),
            rows: group.entries.map {
                .init(id: $0.id, name: $0.name, amountText: viewModel.currencyText($0.amount))
            },
            settleTitle: viewModel.settleButtonTitle(for: group),
            isPaid: viewModel.isPaid(group),
            isSettling: viewModel.isSettling,
            onSettle: { viewModel.requestSettlement(of: group) }
        )
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 44))
                .foregroundStyle(.choreYellow)

            Text(viewModel.emptyTitle)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.titleGray)

            Text(viewModel.emptyMessage)
                .font(.system(size: 16))
                .foregroundStyle(.subTitleGray)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity)
    }
}

#Preview("Você deve") {
    NavigationStack {
        PendingPaymentsView(viewModel: ShopListPreviewData.debtsViewModel)
    }
}

#Preview("Te devem") {
    let viewModel = ShopListPreviewData.debtsViewModel
    viewModel.selectedDirection = .owedToYou

    return NavigationStack {
        PendingPaymentsView(viewModel: viewModel)
    }
}

#Preview("Sem pendências") {
    NavigationStack {
        PendingPaymentsView(viewModel: ShopListPreviewData.noDebtsViewModel)
    }
}
