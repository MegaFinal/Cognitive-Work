//
//  Dashboard.swift
//  Cognitive-Work
//
//  Created by anshu Li on 24/08/26.
//

import SwiftUI
import CloudKit

struct FortnightlyChart: View {
    @State var viewModel = FortnightlyViewModel()
    @State private var selectedEntry: DailyUsageEntry?

    var body: some View {
        VStack(spacing: 16) {
            if viewModel.isLoading {
                ProgressView("Carregando gráfico...")
            } else if let errorMessage = viewModel.errorMessage {
                Text(errorMessage).foregroundColor(.red)
            } else {
                FortnightlyBarChart(
                    users: viewModel.users,
                    entries: viewModel.usageEntries,
                    startDate: viewModel.startDate,
                    onSelect: { entry in selectedEntry = entry }
                )
                FortnightlyLegend(users: viewModel.users)
                    .padding(.bottom)

                if let entry = selectedEntry,
                   let chore = viewModel.chores.first(where: { $0.recordID == entry.choreID }) {
                    ChoreCard(
                        chore: chore
                    )
                }
            }
        }
        .frame(maxWidth: 350, maxHeight: 200, alignment: .top)
        .task {
            viewModel.setup()
        }
    }
    

    private func userBinding(for user: UserModel) -> Binding<UserModel> {
        Binding(
            get: {
                viewModel.users.first(where: { $0.recordID == user.recordID }) ?? user
            },
            set: { newValue in
                if let index = viewModel.users.firstIndex(where: { $0.recordID == user.recordID }) {
                    viewModel.users[index] = newValue
                }
            }
        )
    }
}

#Preview {
    FortnightlyChart()
}
