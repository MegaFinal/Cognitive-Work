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
                        
                        HStack {
                            DoughnutChart(viewModel: $viewModel)
                            
                            // TODO: - Componente do porquinho
                        }
                        
                        // MARK: - House cognitive division
                        BarPercentageComponent(viewModel: viewModel, isUnassignedChores: false)
                        
                        // TODO: - Current Division
                        
                        
                        // MARK: - Unassigned chore
                        // This will be replaced when the pending chores section is finalized.
                        BarPercentageComponent(viewModel: viewModel, isUnassignedChores: true)
                    }
                }
            }
        }
        //        .navigationTitle("Seu progresso" )
        .task {
            await viewModel.load()
            viewModel.loadCompletionRing()
        }
    }
    
    private var header: some View {
        VStack(alignment: .leading) {
            Text("Seu progresso")
                .font(.system(size: 34))
                .fontWeight(.bold)
                .padding(.top, 20)
            
            DateDivisionComponent(viewModel: $viewModel)
        }
        .padding(.horizontal, 30)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    DashboardView()
}
