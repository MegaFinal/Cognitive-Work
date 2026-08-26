//
//  Dashboard.swift
//  Cognitive-Work
//
//  Created by anshu Li on 24/08/26.
//

import SwiftUI
import CloudKit

struct FortnightlyChart: View {
    @State private var viewModel: FortnightlyViewModel
    @State private var selectedEntry: DailyUsageEntry?
    let house: HouseModel?

    init(house: HouseModel?, viewModel: FortnightlyViewModel = FortnightlyViewModel()) {
        self.house = house
        _viewModel = State(initialValue: viewModel)
    }

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

                if let entry = selectedEntry,
                   let chore = viewModel.chores.first(where: { $0.recordID == entry.choreID }),
                   let matchedUser = viewModel.users.first(where: { $0.recordID == entry.userID }) {
                    ChoreCard(
                        chore: chore,
                        roomName: viewModel.roomName(for: chore),
                        user: userBinding(for: matchedUser)
                    )
                }
            }
        }
        .frame(width: 350)
        .task {
            if let houseID = house?.recordID, viewModel.users.isEmpty {
                let houseRef = CKRecord.Reference(recordID: houseID, action: .none)
                await viewModel.loadFortnightlyData(houseReference: houseRef)
            }
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
    let previewVM = FortnightlyViewModel()
    previewVM.loadMockData()
    
    return FortnightlyChart(house: nil, viewModel: previewVM)
        .padding()
}
