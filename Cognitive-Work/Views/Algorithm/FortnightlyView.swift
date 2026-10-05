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
    
    /// Assignments and rooms already in memory. When both are given nothing is fetched.
    var assignments: [RecurrentAssignmentModel]? = nil
    var rooms: [RoomModel]? = nil
    
    @State private var viewModel = FortnightlyViewModel()
    @State private var selectedEntry: DailyUsageEntry?
    @State private var selectedUser: UserModel?
    
    let description: LocalizedStringKey = "Dividimos as tarefas escolhidas pelos moradores pensando nas cargas horárias que cada um tem disponível."
    
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
            .frame(width: width * 0.888)
            
            ScrollView(showsIndicators: false) {
                chart
            }
            
            Spacer()
        }
        .navigationBarBackButtonHidden()
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
                    selectedEntry: selectedEntry,
                    onSelect: { entry in
                        select(entry)
                    },
                    selectionInset: 12
                )
                
                legend
                    .padding(.bottom)
                
                if let entry = selectedEntry,
                   let chore = viewModel.chores.first(where: { $0.recordID == entry.choreID }) {
                    ChoreCard(
                        chore: chore,
                        user: selectedUser,
                        room: viewModel.getRoom(for: chore)
                    )
                }
            }
        }
        .task {
            if let assignments, let rooms {
                await viewModel.setup(users: users, chores: chores)
            } else {
                await viewModel.setup(users: users, chores: chores)
            }
            selectInitialEntry()
        }
    }
    
    // MARK: - Selection
    
    private func select(_ entry: DailyUsageEntry) {
        selectedEntry = entry
        selectedUser = viewModel.users.first { $0.recordID == entry.userID }
    }
    
    /// The screen always opens with the first chore of the first day (the leftmost column,
    /// its topmost bar) selected.
    private func selectInitialEntry() {
        guard selectedEntry == nil,
              let firstDay = viewModel.usageEntries.map(\.day).min(),
              let first = viewModel.usageEntries.first(where: { Calendar.current.isDate($0.day, inSameDayAs: firstDay) })
        else { return }
        
        select(first)
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
