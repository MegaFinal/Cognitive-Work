//
//  DashboardView.swift
//  Cognitive-Work
//
//  Created by Isabela Hissa Pinto on 01/10/26.
//

import SwiftUI

struct DashboardView: View {
    @State var viewModel = DashboardViewModel()
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some View {
        NavigationStack {
            
            VStack(spacing: 16) {
                
                header
                
                ScrollView {
                    VStack(spacing: 16) {
                        
                        HStack(spacing: 16) {
                            DoughnutChart(viewModel: $viewModel)
                            PointsComponent(
                                points: viewModel.myCognitiveLoad
                            )
                        }
                        
                        // MARK: - House cognitive division
                        BarPercentageComponent(
                            viewModel: viewModel,
                            isUnassignedChores: false
                        )
                        
                        // MARK: - Current Division
                        UserCurrentDivisionComponent(
                            periodStart: viewModel.periodStart,
                            sharedViewModel: viewModel.schedule
                        )
                            .padding(.horizontal, 16)
                        
                        // MARK: - Unassigned chore
                        // This will be replaced when the pending chores section is finalized.
                        BarPercentageComponent(
                            viewModel: viewModel,
                            isUnassignedChores: true
                        )
                    }
                    // New content version = new identity: the charts are recreated and draw the
                    // rebuilt data. Applied inside the ScrollView so the scroll position is kept.
                    .id(viewModel.contentVersion)
                }
                .refreshable {
                    await viewModel.reloadAfterRemoteChange()
                }
            }
            .disabled(viewModel.isLoading)
            .opacity(viewModel.isLoading ? 0 : 1)
            // Invisible while loading, so VoiceOver must not reach it either.
            .accessibilityHidden(viewModel.isLoading)
            // Only on a cold start without data in memory; otherwise the cards draw at once.
            .overlay {
                if viewModel.isLoading { ProgressView() }
            }
        }
        // Local changes: `markDataChanged()` bumps `dataRevision`.
        .task(id: CloudKitManager.shared.dataRevision) {
            await viewModel.loadIfNeeded()
        }
        // Changes made on another device (the CKDatabaseSubscription push posts this).
        .onReceive(NotificationCenter.default.publisher(for: .cloudKitDidChange)) { _ in
            Task { await viewModel.reloadAfterRemoteChange() }
        }
        // Pushes can be missed while the app is suspended, and "today" may have rolled over.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await viewModel.reloadAfterRemoteChange() }
            }
        }
    }
    
    private var header: some View {
        VStack(alignment: .leading) {
            Text("Seu progresso")
                .font(.system(size: 34))
                .fontWeight(.bold)
                .padding(.top, 20)
                .accessibilityAddTraits(.isHeader)
            
            DateDivisionComponent(viewModel: $viewModel)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    DashboardView()
}
