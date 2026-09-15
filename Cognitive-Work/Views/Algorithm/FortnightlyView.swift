//
//  FortnightlyView.swift
//  Cognitive-Work
//
//  Created by anshu Li on 26/08/26.
//

import SwiftUI
import CloudKit

struct FortnightlyView: View {
    let users: [UserModel]
    let chores: [ChoreModel]
    
    @State private var viewModel = FortnightlyViewModel()
    @State private var selectedEntry: DailyUsageEntry?
    
    var width = UIScreen.main.bounds.width
    var height = UIScreen.main.bounds.height
    
    let description: String = """
        Dividimos as tarefas escolhidas pelos moradores pensando nas cargas horárias que cada um tem disponível.
        """
    
    var body: some View {
        VStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("Escala quinzenal")
                    .bold()
                    .font(.system(size: 28))
                    .foregroundColor(.black)
                
                VStack(alignment: .leading, spacing: 10) {
                    Text(description)
                    
                    Text("Clique nas tarefas para saber mais.")
                }
            }
            .padding(.bottom, 30)
            .foregroundColor(.secondary)
            .frame(width: width * 0.8)
            
            ScrollView(showsIndicators: false) {
                chart
            }
            
            Spacer()
        }
        .navigationBarBackButtonHidden()
        .frame(width: width * 0.85)
        .padding(.top, 30)
    }
    
    private var chart: some View {
        VStack(spacing: 16) {
            if viewModel.isLoading {
                ProgressView("Carregando gráfico...")
            } else if let errorMessage = viewModel.errorMessage {
                Text(errorMessage).foregroundColor(.red)
            } else {
                FortnightlyBarChart(
                    users: users,
                    entries: viewModel.usageEntries,
                    startDate: viewModel.startDate,
                    onSelect: { entry in selectedEntry = entry }
                )
                
                legend
                    .padding(.bottom)
                
                if let entry = selectedEntry,
                   let chore = viewModel.chores.first(where: { $0.recordID == entry.choreID }) {
                    ChoreCard(chore: chore)
                }
            }
        }
        .task {
            await viewModel.setup(users: users, chores: chores)
        }
    }
    
    private var legend: some View {
        HStack {
            ForEach(Array(viewModel.users.enumerated()), id: \.offset) { index, user in
                HStack {
                    Circle()
                        .frame(width: 14)
                        .foregroundStyle(UserColorPalette.color(for: index))
                    
                    Text(user.name)
                        .font(.system(size: 15))
                        .fontWeight(.light)
                }
            }
        }
    }
}

#Preview {
    return FortnightlyView(users: [], chores: [])
}
