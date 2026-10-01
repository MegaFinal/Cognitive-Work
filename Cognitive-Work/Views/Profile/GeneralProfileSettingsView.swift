//
//  GeneralProfileSettingsView.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 03/09/26.
//

import SwiftUI

struct GeneralProfileSettingsView: View {
    @Bindable var viewModel: UserProfileViewModel
    
    @State private var isNotificationsEnabled = false
    
    /// Persisted and read by ``HapticsManager`` on every vibration, so the switch applies in
    /// real time. (It used to be a local `@State` that nothing read, reset on every visit.)
    @AppStorage(HapticsManager.storageKey) private var areHapticsEnabled = true
    
    @State private var showDeleteConfirmation = false

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
                Text("Permitir Notificações")
                
                Spacer()
                
                Toggle("", isOn: $isNotificationsEnabled)
                    .toggleStyle(.switch)
                    .padding(.trailing, 7)
                    .frame(width: width * 0.37)
            }
            
            HStack {
                Text("Idioma")
                
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
            }
            
            VStack(alignment: .leading) {
                HStack {
                    Text("Haptics")
                    
                    Spacer()
                    
                    Toggle("", isOn: $areHapticsEnabled)
                        .toggleStyle(.switch)
                        .padding(.trailing, 7)
                        .frame(width: width * 0.37)
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
                     
                    Spacer()
                     
                    if viewModel.isSyncingCalendar {
                        ProgressView()
                            .controlSize(.small)
                    }
                    
                    Toggle("", isOn: $viewModel.isCalendarSyncEnabled)
                        .toggleStyle(.switch)
                        .padding(.trailing, 7)
                        .frame(width: width * 0.37)
                        .disabled(viewModel.isSyncingCalendar)
                }
                 
                Text("Adicionar automaticamente as suas tarefas ao calendário da Apple (Pipa).")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // MARK: - Delete account button
            Button {
                showDeleteConfirmation = true
            } label: {
                Text("Excluir Perfil")
                    .fontWeight(.semibold)
            }
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
                    if viewModel.errorMessage == nil {
                        didOnboard = false
                    } else {
                        isDeletingAccount = false
                    }
                }
            }
        } message: {
            Text("Esta ação é permanente. Todos os seus dados serão apagados do iCloud.")
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

    return NavigationStack {
        GeneralProfileSettingsView(viewModel: mockViewModel)
    }
}
