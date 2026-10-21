//
//  NotificationsView.swift
//  Cognitive-Work
//
//  Created by Isabela Hissa Pinto on 30/09/26.
//

import SwiftUI

struct NotificationsView: View {
    /// ChoresView decides what to do with these actions (it owns carouselVM).
    var onPickChores: () -> Void = {}
    var onOpenChore: (ChoreModel, RecurrentAssignmentModel?) -> Void = { _, _ in }
    var onNewMember: () -> Void = {}
    
    @State private var viewModel = NotificationsViewModel()
    /// Loaded together with the notifications, so the retrospective opens ready.
    @State private var retroCoinsViewModel = RetroCoinsViewModel()
    @State private var isShowingRetro = false
    @State private var isShowingDashboard = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        // No NavigationStack here: we are already inside ChoresView's stack.
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                
                #if DEBUG
                simulateRetroSection
                #endif
                
                if viewModel.isLoading {
                    ProgressView().frame(maxWidth: .infinity)
                        .voiceOverLabel(L10n.tr("Carregando notificações"))
                } else if viewModel.sections.isEmpty {
                    Text("Nada por aqui nos últimos 14 dias")
                        .foregroundStyle(.subTitleGray)
                } else {
                    ForEach(viewModel.sections) { section in
                        sectionView(section)
                    }
                }
            }
            .padding(.top, 20)
        }
        .scrollIndicators(.hidden)
        .task { await viewModel.load() }
        .task { await retroCoinsViewModel.load() }
        .refreshable {
            await viewModel.load(force: true)
            await retroCoinsViewModel.reload()
        }
        .onDisappear { viewModel.markAllAsSeen() }
        .navigationDestination(isPresented: $isShowingDashboard) {
            DashboardView()
        }
        .fullScreenCover(isPresented: $isShowingRetro) {
            RetroView(coinsViewModel: retroCoinsViewModel) {
                isShowingRetro = false
            }
                .presentationBackground(.clear)
        }
    }
    
    // MARK: - Subviews
    
    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Notificações")
                .font(.system(size: 34))
                .fontWeight(.bold)
                .accessibilityAddTraits(.isHeader)
            Text(viewModel.newCountText)
                .font(.system(size: 17))
                .foregroundStyle(.subTitleGray)
        }
    }
    
    private func sectionView(_ section: NotificationSection) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(viewModel.title(for: section))
                .font(.system(size: 17))
                .foregroundStyle(.subTitleGray)
                .accessibilityAddTraits(.isHeader)

            ForEach(section.items) { notification in
                Button {
                    handleTap(notification.destination)
                } label: {
                    NotificationComponent(
                        color: notification.kind.color,
                        symbol: notification.kind.symbol,
                        title: notification.title,
                        subtitle: notification.subtitle
                    )
                }
                .buttonStyle(.plain) // keeps the text black
                // Voice Control: say just the title, not title + subtitle.
                .voiceControlNames([notification.title])
            }
        }
    }
    
    #if DEBUG
    // TODO: PROVISÓRIO — remover. Abre a retrospectiva na hora, sem esperar o fim do ciclo.
    // Mesma aparência de uma notificação; não existe em builds de Release.
    private var simulateRetroSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(verbatim: "Testes")
                .font(.system(size: 17))
                .foregroundStyle(.subTitleGray)
                .accessibilityAddTraits(.isHeader)
            
            Button {
                isShowingRetro = true
            } label: {
                NotificationComponent(
                    color: Notifications.retrospective.color,
                    symbol: Notifications.retrospective.symbol,
                    title: "Simular retrospectiva",
                    subtitle: "Provisório: abre a retro agora, com os dados reais"
                )
            }
            .buttonStyle(.plain) // keeps the text black
            .voiceControlNames(["Simular retrospectiva"])
        }
    }
    #endif
    
    // MARK: - Actions
    
    private func handleTap(_ destination: NotificationDestination) {
        switch destination {
        case .pickChores:
            dismiss()
            onPickChores()
        case .retrospective:
            isShowingRetro = true
        case .dashboard:
            isShowingDashboard = true
        case .chore(let chore, let assignment):
            dismiss()
            onOpenChore(chore, assignment)
        case .newMember:
            dismiss()
            onNewMember()
        }
    }
}

#Preview {
    NavigationStack { NotificationsView() }
}
