//
//  HouseSettingsView.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 03/09/26.
//

import SwiftUI

struct HouseSettingsView: View {
    @Bindable var viewModel: HouseEditViewModel
    @State var showChoreResetConfirmation = false
    @State private var isResetting = false
    @State private var showDeleteConfirmation = false
    
    @State private var isDeletingHouse = false
    @State private var deleteErrorMessage: String?
    
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
            
            // MARK: - Reset chores assignments
            if viewModel.isUserAdmin {
                Button {
                    showChoreResetConfirmation = true
                }
                label: {
                    HStack {
                        Text("Reiniciar divisão de tarefas")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
            }
            
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
                isDeletingHouse = true
                Task {
                    let success = await viewModel.deleteHouse()
                    if success {
                        didOnboard = false
                    } else {
                        deleteErrorMessage = "Não foi possível excluir a casa. Verifique sua conexão e tente novamente."
                        isDeletingHouse = false
                    }
                }
            }
        } message: {
            Text("Esta ação é permanente. Todos os dados desta casa serão apagados do iCloud.")
        }
        .blockingOperation(isPresented: $isDeletingHouse, message: "Excluindo sua casa...")
        .task {
            await viewModel.checkAdminStatus()
        }
        .alert("Deseja reiniciar a divisão de tarefas?", isPresented: $showChoreResetConfirmation) {
            Button("Cancelar", role: .cancel) {}
            Button("Reiniciar", role: .destructive) {
                isResetting = true
            }
        } message: {
            Text("Ao clicar em \"Reiniciar\" a divisão de tarefas atual será excluída.")
        }
        .navigationDestination(isPresented: $isResetting) {
            FortnightlyScheduleView(shouldGenerate: true) {
                isResetting = false
            }
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
