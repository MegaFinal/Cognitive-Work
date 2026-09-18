//
//  HouseEditView.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 31/08/26.
//

import SwiftUI
import CloudKit

/// Button view that allows admin to delete the house
struct HouseEditView: View {
    @State var viewModel: HouseEditViewModel
    
    var body: some View {
        VStack {
            if viewModel.isLoading {
                ProgressView()
            } else if viewModel.house != nil {
                if viewModel.isUserAdmin {
                    Button {
                        Task {
                            await viewModel.deleteHouse()
                        }
                    } label: {
                        if viewModel.isDeleting {
                            ProgressView()
                        } else {
                            Text("Deletar Casa")
                                .foregroundColor(.red)
                        }
                    }
                    .disabled(viewModel.isDeleting)
                }
            } else {
                Text("Nenhuma casa encontrada.")
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .task {
            await viewModel.checkAdminStatus()
        }
    }
}

#Preview {
    let house = HouseModel(name: "Casa", description: "Casa para o preview")
    // The default zone's ownerName is already CKCurrentUserDefaultName, so isAdmin()
    // resolves to true and the preview renders the delete button.
    house.recordID = CKRecord.ID(recordName: "preview")
    
    let viewModel = HouseEditViewModel(house: house)
    
    return HouseEditView(viewModel: viewModel)
}
