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
            VStack(spacing: 15) {
                header
                
                HStack {
                    DoughnutChart(viewModel: $viewModel)
                    //Componente do porquinho
                }
                
                Spacer()
                
                BarPercentageComponent(viewModel: viewModel, isUnassignedChores: false)
                
                BarPercentageComponent(viewModel: viewModel, isUnassignedChores: true)
            }
        }
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
