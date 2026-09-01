//
//  DeleteAccountButton.swift
//  Cognitive-Work
//
//  Created by Carolina Sun on 31/08/26.
//

import SwiftUI

struct DeleteAccountButton: View {
    @Bindable var viewModel: UserProfileViewModel
    
    @State private var showConfirmation = false

    var body: some View {
        Button(role: .destructive) {
            showConfirmation = true
            
        } label: {
            if viewModel.isSaving {
                ProgressView()
            } else {
                Image(systemName: "trash")
                    .font(.subheadline)
                    .padding(16)

                   
            }
        }
        .disabled(viewModel.isSaving || viewModel.user == nil)
        .confirmationDialog(
            "Tem certeza que deseja apagar sua conta?\nAo deletar a conta você será removido das casas a que pertence",
            isPresented: $showConfirmation,
            titleVisibility: .visible
        ) {
            Button("Apagar conta", role: .destructive) {
                Task { await viewModel.deleteAccount() }
            }
            
            Button("Cancelar", role: .cancel) {}
        }
        
        message: {
            Text("Essa ação é permanente e não pode ser desfeita.")
        }
        
        // if error when deleting
        .alert("Não foi possível apagar a conta",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        }
        message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}

//#Preview {
//    DeleteAccountButton()
//}
