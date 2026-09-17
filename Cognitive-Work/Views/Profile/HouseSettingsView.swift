//
//  HouseSettingsView.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 03/09/26.
//

import SwiftUI

struct HouseSettingsView: View {
    @Bindable var viewModel: HouseEditViewModel
    @State private var showDeleteConfirmation = false
    
    @AppStorage("didOnboard") private var didOnboard: Bool = true
    
    var body: some View {
        VStack(spacing: 30) {
            // MARK: - Add roomates button
            NavigationLink {
                InviteUsersOnboardingView(viewModel: .constant(makeInviteViewModel()), isFromSettings: true)
                    .padding(.bottom, 30)
            } label: {
                HStack {
                    Text("Adicionar moradores")
                    Spacer()
                    Image(systemName: "chevron.right")
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
            
//            Button {}
//            label: {
//                HStack {
//                    Text("Reiniciar divisão de tarefas")
//                    Spacer()
//                    Image(systemName: "chevron.right")
//                }
//            }
//            .buttonStyle(.plain)
//            .padding(.horizontal)
            
            Spacer()
            
            if viewModel.isUserAdmin {
                // MARK: - Delete house button
                Button {
                    showDeleteConfirmation = true
                } label: {
                    Text("Excluir Casa")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.red)
            }
        }
        .padding(.top)
        .padding(.bottom, 30)
        .navigationTitle("Ajustes da Casa")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        
        .alert("Excluir Casa?", isPresented: $showDeleteConfirmation) {
            Button("Cancelar", role: .cancel) {}
            Button("Excluir", role: .destructive) {
                Task {
                    await viewModel.deleteHouse()
                    didOnboard = false
                }
            }
        } message: {
            Text("Esta ação é permanente. Todos os dados desta casa serão apagados do iCloud.")
        }
        .task {
            await viewModel.checkAdminStatus()
        }
    }
    
    // MARK: - Helpers
    private func makeInviteViewModel() -> OnboardingViewModel {
        let inviteViewModel = OnboardingViewModel()
        inviteViewModel.currentHouse = viewModel.house
        return inviteViewModel
    }
}

#Preview {
    let house = HouseModel(name: "Casa", description: "Casa para o preview")
    let viewModel = HouseEditViewModel(house: house)
    viewModel.isUserAdmin = true
    
    return NavigationStack {
        HouseSettingsView(viewModel: viewModel)
    }
}
