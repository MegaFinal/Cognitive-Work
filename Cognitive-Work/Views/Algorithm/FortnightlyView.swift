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
    @State private var usageEntries: [DailyUsageEntry] = []

    let description: String = """
        Dividimos as tarefas escolhidas pelos moradores pensando nas cargas horárias que cada um tem disponível.
        Clique nas tarefas para saber mais.
        """

    var body: some View {
        VStack {
            OnboardingHeader(title: "Escala quinzenal", description: description)
                .padding(.bottom)

            chart

            Spacer()
        }
        .navigationBarBackButtonHidden()
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
                    entries: usageEntries,
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
        .frame(maxWidth: 350, maxHeight: 200, alignment: .top)
        .task {
            await viewModel.setup(users: users, chores: chores)
            usageEntries = await viewModel.usageEntries
        }
        .onAppear {
            print("cheguei na chart")
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
