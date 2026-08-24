//
//  Dashboard.swift
//  Cognitive-Work
//
//  Created by anshu Li on 24/08/26.
//

import SwiftUI
import CloudKit

struct FortnightlyChart: View {
    @State private var viewModel = FortnightlyViewModel()
    let house: HouseModel?
    
    var body: some View {
        VStack{
            FortnightlyBarChart()
            FortnightlyLegend(users: viewModel.users)
        }
        .frame(width: 332)
        .task {
            guard let houseID = house?.recordID else { return }
            let ref = CKRecord.Reference(recordID: houseID, action: .none)
            await viewModel.loadUsers(houseReference: ref)
        }
    }
}

#Preview {
    //    FortnightlyChart()
}
