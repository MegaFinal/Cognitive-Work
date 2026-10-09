//
//  DashboardView.swift
//  Cognitive-Work
//
//  Created by Isabela Hissa Pinto on 01/10/26.
//

import SwiftUI

struct DashboardView: View {
    @State var viewModel = DashboardViewModel()
    
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
                }
            }
            .disabled(viewModel.isLoading)
            .opacity(viewModel.isLoading ? 0 : 1)
            // Invisible while loading, so VoiceOver must not reach it either.
            .accessibilityHidden(viewModel.isLoading)
        }
        .task(id: CloudKitManager.shared.dataRevision) {
            await viewModel.loadIfNeeded()
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
