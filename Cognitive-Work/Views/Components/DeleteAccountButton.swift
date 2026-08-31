//
//  DeleteAccountButton.swift
//  Cognitive-Work
//
//  Created by Carolina Sun on 31/08/26.
//

import SwiftUI

struct DeleteAccountButton: View {
    let user: UserModel

    /// Called after a successful deletion, so the parent view can handle sign-out/navigation.
    var onDeleted: () -> Void

    @State private var showConfirmation = false
    @State private var isDeleting = false
    @State private var errorMessage: String?

    var body: some View {
        
        Button(role: .destructive) {
            showConfirmation = true
            
        } label: {
            if isDeleting {
                ProgressView()
            } else {
//                Text("Apagar conta")
                Image(systemName: "trash")
                    .font(.subheadline)
                    .padding(16)

                   
            }
        }
//        .glassEffect(
//            .regular.interactive(),
//            in: .circle
//        )
        .disabled(isDeleting)
        .confirmationDialog( "Tem certeza que deseja apagar sua conta?\nAo deletar a conta você será removido das casas a que pertence", isPresented: $showConfirmation, titleVisibility: .visible
        ) {
            Button("Apagar conta", role: .destructive) {
                Task { await deleteAccount() }
            }
            
            Button("Cancelar", role: .cancel) {}
            
        } message: {
            Text("Essa ação é permanente e não pode ser desfeita.")
        }
        .alert("Não foi possível apagar a conta",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func deleteAccount() async {
        isDeleting = true
        defer { isDeleting = false }

        let success = await CloudKitManager.shared.delete(user)

        if success {
            onDeleted()
        } else {
            errorMessage = CloudKitManager.shared.errorMessage ?? "Erro desconhecido."
        }
    }
}

#Preview {
    DeleteAccountButton(user: UserModel(name: "Usuário Teste",tier: .tier1),
        onDeleted: {
            print("Conta deletada com sucesso no Preview!")
        }
    )
}
