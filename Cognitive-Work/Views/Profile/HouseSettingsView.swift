//
//  HouseSettingsView.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 03/09/26.
//

import SwiftUI

/// The "Ajustes da Casa" screen: invite members, manage rooms, reset the chore division (admin)
/// and delete the house (admin) or leave it (other members).
struct HouseSettingsView: View {
    /// Loads the house and the admin status and runs delete/leave.
    @Bindable var viewModel: HouseEditViewModel
    /// Shows the "reset the division?" alert.
    @State var showChoreResetConfirmation = false
    /// Opens the screen that creates a new division (after confirming the reset).
    @State private var isResetting = false
    /// Shows the "delete the house?" alert.
    @State private var showDeleteConfirmation = false
    
    /// Shows the blocking overlay while the house is being deleted.
    @State private var isDeletingHouse = false
    /// Shows the "leave the house?" alert.
    @State private var showLeaveConfirmation = false
    /// Shows the blocking overlay while leaving the house.
    @State private var isLeavingHouse = false
    /// Error shown when leaving fails.
    @State private var leaveErrorMessage: String?
    /// Error shown when deleting fails.
    @State private var deleteErrorMessage: String?
    
    /// `true` while we still don't know if the user is the admin.
    private var isCheckingAdmin: Bool { !viewModel.isAdminResolved }
    
    /// Set to `false` after deleting or leaving, which sends the user back to onboarding.
    @AppStorage("didOnboard") private var didOnboard: Bool = true
    
    /// Kept in `@State` so the invite screen keeps one instance (and its polling/share state)
    /// instead of getting a brand-new view model on every redraw.
    @State private var inviteViewModel = OnboardingViewModel()
    
    var body: some View {
        VStack(spacing: 30) {
            // MARK: - Add roommates button
            NavigationLink {
                InviteAndWaitUsersFreeTimeOnboardingView(viewModel: $inviteViewModel, isFromSettings: true)
                    .padding(.bottom, 30)
                    .onAppear {
                        inviteViewModel.currentHouse = viewModel.house
                    }
            } label: {
                HStack {
                    Text("Adicionar moradores")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .accessibilityHidden(true)
                }
            }
            .voiceControlNames([L10n.tr("Adicionar moradores"), L10n.tr("Convidar"), L10n.tr("Moradores")])
            .buttonStyle(.plain)
            .padding(.horizontal)
            
            // MARK: - Rooms CRUD
            NavigationLink {
                RoomsManagementView(house: viewModel.house)
            } label: {
                HStack {
                    Text("Cômodos")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .accessibilityHidden(true)
                }
            }
            .voiceControlNames([L10n.tr("Cômodos")])
            .buttonStyle(.plain)
            .padding(.horizontal)
            
            // MARK: - Spinner while checking admin status
            if isCheckingAdmin {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .voiceOverLabel(L10n.tr("Verificando permissões"))
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
                            .accessibilityHidden(true)
                    }
                }
                .buttonStyle(.plain)
                .voiceControlNames([L10n.tr("Reiniciar divisão de tarefas"), L10n.tr("Reiniciar divisão"), L10n.tr("Reiniciar")])
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
                .voiceControlNames([L10n.tr("Excluir Casa"), L10n.tr("Excluir"), L10n.tr("Apagar")])
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
                .voiceControlNames([L10n.tr("Sair da Casa"), L10n.tr("Sair")])
                .foregroundColor(.red)
            }
        }
        .padding(.top)
        .padding(.bottom, 30)
        .navigationTitle("Ajustes da Casa")
        .navigationBarTitleDisplayMode(.inline)
        .hidesTabBar()
        // MARK: - Delete and leave alerts
        .alert("Excluir Casa?", isPresented: $showDeleteConfirmation) {
            Button("Cancelar", role: .cancel) {}
            Button("Excluir", role: .destructive) {
                guard viewModel.isAdminResolved, viewModel.isUserAdmin else { return }
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
        // MARK: - Blocking overlays and admin check
        .blockingOperation(isPresented: $isLeavingHouse, message: "Saindo da casa...")
        .blockingOperation(isPresented: $isDeletingHouse, message: "Excluindo sua casa...")
        .task {
            await viewModel.checkAdminStatus()
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
        // MARK: - Reset division alert and new division screen
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
    
}

#Preview {
    let house = HouseModel(name: "Casa", description: "Casa para o preview")
    let viewModel = HouseEditViewModel(house: house)
    viewModel.isUserAdmin = true
    
    return NavigationStack {
        HouseSettingsView(viewModel: viewModel)
    }
}
