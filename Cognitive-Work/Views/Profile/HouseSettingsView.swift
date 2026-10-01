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
    @State private var showLeaveConfirmation = false
    @State private var isLeavingHouse = false
    @State private var leaveErrorMessage: String?
    @State private var deleteErrorMessage: String?
    
    /// Admin-only rows used to pop in after an unannounced CloudKit round trip.
    @State private var isCheckingAdmin = true
    
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
            
            if isCheckingAdmin {
                ProgressView()
                    .frame(maxWidth: .infinity)
            }
            
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
            } else if !isCheckingAdmin {
                // MARK: - Leave house button
                // Only the admin can delete the house; every other member can just leave it.
                Button {
                    showLeaveConfirmation = true
                } label: {
                    Text("Sair da Casa")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.red)
            }
        }
        .padding(.top)
        .padding(.bottom, 30)
        .navigationTitle("Ajustes da Casa")
        .navigationBarTitleDisplayMode(.inline)
        .hidesTabBar()
        .alert("Excluir Casa?", isPresented: $showDeleteConfirmation) {
            Button("Cancelar", role: .cancel) {}
            Button("Excluir", role: .destructive) {
                isDeletingHouse = true
                Task {
                    let success = await viewModel.deleteHouse()
                    if success {
                        didOnboard = false
                    } else {
                        deleteErrorMessage = L10n.tr("Não foi possível excluir a casa. Verifique sua conexão e tente novamente.")
                        isDeletingHouse = false
                    }
                }
            }
        } message: {
            Text("Esta ação é permanente. Todos os dados desta casa serão apagados do iCloud.")
        }
        .alert("Sair da Casa?", isPresented: $showLeaveConfirmation) {
            Button("Cancelar", role: .cancel) {}
            Button("Sair", role: .destructive) {
                isLeavingHouse = true
                Task {
                    if await viewModel.leaveHouse() {
                        didOnboard = false
                    } else {
                        leaveErrorMessage = L10n.tr("Não foi possível sair da casa. Verifique sua conexão e tente novamente.")
                        isLeavingHouse = false
                    }
                }
            }
        } message: {
            Text("Você deixará de ver as tarefas desta casa. Os outros moradores continuam nela e você poderá entrar de novo com um convite.")
        }
        .alert(
            "Não foi possível sair",
            isPresented: Binding(
                get: { leaveErrorMessage != nil },
                set: { if !$0 { leaveErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(leaveErrorMessage ?? "")
        }
        .blockingOperation(isPresented: $isLeavingHouse, message: "Saindo da casa...")
        .blockingOperation(isPresented: $isDeletingHouse, message: "Excluindo sua casa...")
        .task {
            await viewModel.checkAdminStatus()
            isCheckingAdmin = false
        }
        // `deleteErrorMessage` was set on failure but never presented.
        .alert(
            "Não foi possível excluir",
            isPresented: Binding(
                get: { deleteErrorMessage != nil },
                set: { if !$0 { deleteErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deleteErrorMessage ?? "")
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
