//
//  GeneralProfileSettingsView.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 03/09/26.
//

import SwiftUI

struct GeneralProfileSettingsView: View {
    @Bindable var viewModel: UserProfileViewModel
    @Bindable var houseViewModel: HouseEditViewModel
        
    /// Persisted and read by ``HapticsManager`` on every vibration, so the switch applies in
    /// real time. (It used to be a local `@State` that nothing read, reset on every visit.)
    @AppStorage(HapticsManager.storageKey) private var areHapticsEnabled = true
    
    @State private var showDeleteConfirmation = false
    @State private var showAdminDeleteConfirmation = false

    @State private var isDeletingAccount = false
    @AppStorage("didOnboard") private var didOnboard: Bool = true
    
    private let languageManager = LanguageManager.shared
    
    private var languageSelection: Binding<AppLanguage> {
        Binding(
            get: { languageManager.current },
            set: { languageManager.setLanguage($0) }
        )
    }
    
    var body: some View {
        VStack(spacing: 30) {
            HStack {
                Text("Idioma")
                    .accessibilityHidden(true) // carried by the menu's label
                
                Spacer()
                
                Menu {
                    Picker("Idioma", selection: languageSelection) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(verbatim: language.nativeName)
                                .tag(language)
                        }
                    }
                } label: {
                    HStack {
                        Text(verbatim: languageManager.current.nativeName)
                            .foregroundColor(.secondary)
                        Image(systemName: "chevron.up.chevron.down")
                            .imageScale(.small)
                    }
                }
                .foregroundColor(.black)
                .voiceOverLabel(L10n.tr("Idioma"))
                .voiceOverValue(languageManager.current.nativeName)
                // Voice Control: the visible language name first, then the setting's name.
                .voiceControlNames([languageManager.current.nativeName, L10n.tr("Idioma"), L10n.tr("Língua")])
            }
            
            VStack(alignment: .leading) {
                HStack {
                    Text("Haptics")
                        .accessibilityHidden(true) // carried by the toggle's label
                    
                    Spacer()
                    
                    Toggle("", isOn: $areHapticsEnabled)
                        .toggleStyle(.switch)
                        .padding(.trailing, 7)
                        .frame(width: width * 0.37)
                        .voiceOverLabel(L10n.tr("Haptics"))
                        .voiceControlNames([L10n.tr("Haptics"), L10n.tr("Vibração")])
                        .onChange(of: areHapticsEnabled) { _, isOn in
                            // Immediate confirmation that vibrations are back on.
                            if isOn { HapticsManager.impact(.medium) }
                        }
                }
                
                Text("Vibrações ao concluir uma tarefa e em outras interações.")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
            }
            
            // Calendar Toggle
            VStack(alignment: .leading) {
                HStack {
                    Text("Sincronizar com Calendário")
                        .accessibilityHidden(true) // carried by the toggle's label
                     
                    Spacer()
                     
                    if viewModel.isSyncingCalendar {
                        ProgressView()
                            .controlSize(.small)
                            .voiceOverLabel(L10n.tr("Sincronizando"))
                    }
                    
                    Toggle("", isOn: $viewModel.isCalendarSyncEnabled)
                        .toggleStyle(.switch)
                        .padding(.trailing, 7)
                        .frame(width: width * 0.37)
                        .disabled(viewModel.isSyncingCalendar)
                        .voiceOverLabel(L10n.tr("Sincronizar com Calendário"))
                        .voiceControlNames([L10n.tr("Sincronizar com Calendário"), L10n.tr("Calendário")])
                }
                 
                Text("Adicionar automaticamente as suas tarefas ao calendário da Apple (Pipa).")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // MARK: - Delete account button
            Button {
                Task {
                    let isAdmin = await houseViewModel.checkAdminStatus()
                    if isAdmin {
                        showAdminDeleteConfirmation = true
                    } else {
                        showDeleteConfirmation = true
                    }
                }
            } label: {
                Text("Excluir Perfil")
                    .fontWeight(.semibold)
            }
            .voiceControlNames([L10n.tr("Excluir Perfil"), L10n.tr("Excluir"), L10n.tr("Apagar")])
            .foregroundColor(.red)
        }
        .padding(.top, 40)
        .padding(.bottom, 30)
        .frame(width: width * 0.9)
        .navigationTitle("Configurações Gerais")
        .navigationBarTitleDisplayMode(.inline)
        .hidesTabBar()
        
        // MARK: - Alerts
        .alert("Excluir Perfil?", isPresented: $showDeleteConfirmation) {
            Button("Cancelar", role: .cancel) {}
            Button("Excluir", role: .destructive) {
                isDeletingAccount = true
                Task {
                    await viewModel.deleteAccount()
                    await houseViewModel.getOutOfTheHouse()
                    if viewModel.errorMessage == nil {
                        didOnboard = false
                    } else {
                        isDeletingAccount = false
                    }
                }
            }
        } message: {
            Text("Ao apagar seu perfil, você também sairá da casa e perderá o acesso às tarefas e ao histórico. A casa continuará existindo para os outros moradores. Essa ação não pode ser desfeita.")
        }
        
        .alert("Excluir Perfil?", isPresented: $showAdminDeleteConfirmation) {
            Button("Cancelar", role: .cancel) {}
            Button("Excluir", role: .destructive) {
                isDeletingAccount = true
                Task {
                    await viewModel.deleteAccount()
                    await houseViewModel.deleteHouse()
                    if viewModel.errorMessage == nil {
                        didOnboard = false
                    } else {
                        isDeletingAccount = false
                    }
                }
            }
        } message: {
            Text("Você é o administrador desta casa. Ao apagar seu perfil, a casa também será apagada para todos os moradores, junto com as tarefas. Essa ação não pode ser desfeita.")
        }
        // MARK: - Blocking loading screen
        .blockingOperation(isPresented: $isDeletingAccount, message: "Excluindo seu perfil...")
    }
}

#Preview {
    let mockUser = UserModel(
        name: "Preview User",
        tier: .tier1,
        ownerRecordName: "preview-owner"
    )
    let mockViewModel = UserProfileViewModel(user: mockUser)
    let mockHouseViewModel = HouseEditViewModel()

    NavigationStack {
        GeneralProfileSettingsView(viewModel: mockViewModel, houseViewModel: mockHouseViewModel)
    }
}
