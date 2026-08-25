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
                Text(errorMessage)
                    .foregroundColor(.red)
            } else {
                FortnightlyBarChart(
                    users: viewModel.users,
                    entries: viewModel.usageEntries,
                    startDate: viewModel.startDate
                )
                FortnightlyLegend(users: viewModel.users)
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
}

#Preview {
    let previewVM = FortnightlyViewModel()
    previewVM.loadMockData()
    
    return FortnightlyChart(house: nil, viewModel: previewVM)
        .padding()
}
