//
//  GeneralProfileSettingsView.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 03/09/26.
//

import SwiftUI
import UserNotifications

struct GeneralProfileSettingsView: View {
    @Bindable var viewModel: UserProfileViewModel
    @Bindable var houseViewModel: HouseEditViewModel
        
    /// Persisted and read by ``HapticsManager`` on every vibration, so the switch applies in
    /// real time. (It used to be a local `@State` that nothing read, reset on every visit.)
    @AppStorage(HapticsManager.storageKey) private var areHapticsEnabled = true
    
    /// User's in-app choice. Only effective while the system permission is also granted.
    @AppStorage("notificationsEnabled") private var areNotificationsEnabled = false
    @State private var showNotificationsDeniedAlert = false
    @Environment(\.scenePhase) private var scenePhase
    
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
    
    private var notificationsBinding: Binding<Bool> {
        Binding(
            get: { areNotificationsEnabled },
            set: { isOn in
                if isOn {
                    enableNotifications()
                } else {
                    areNotificationsEnabled = false
                }
            }
        )
    }
    
    /// Asks for system permission; if the user already denied it, offers to open Settings.
    private func enableNotifications() {
        Task {
            let center = UNUserNotificationCenter.current()
            let status = await center.notificationSettings().authorizationStatus
            switch status {
            case .authorized, .provisional, .ephemeral:
                areNotificationsEnabled = true
            case .notDetermined:
                let granted = (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
                areNotificationsEnabled = granted
            default:
                areNotificationsEnabled = false
                showNotificationsDeniedAlert = true
            }
        }
    }
    
    /// Keeps the switch honest if the user revoked permission in iOS Settings.
    private func syncNotificationsWithSystem() async {
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        if status == .denied { areNotificationsEnabled = false }
    }
    
    var body: some View {
        VStack(spacing: 30) {
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
            
            // Notifications Toggle
            VStack(alignment: .leading) {
                HStack {
                    Text("Notificações")
                    
                    Spacer()
                    
                    Toggle("", isOn: notificationsBinding)
                        .toggleStyle(.switch)
                        .padding(.trailing, 7)
                        .frame(width: width * 0.37)
                }
                
                Text("Receber avisos sobre as tarefas da casa.")
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
            .foregroundColor(.red)
        }
        .padding(.top, 40)
        .padding(.bottom, 30)
        .frame(width: width * 0.9)
        .navigationTitle("Configurações Gerais")
        .navigationBarTitleDisplayMode(.inline)
        .hidesTabBar()
        
        .task { await syncNotificationsWithSystem() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await syncNotificationsWithSystem() } }
        }
        
        // MARK: - Alerts
        .alert("Notificações desativadas", isPresented: $showNotificationsDeniedAlert) {
            Button("Cancelar", role: .cancel) {}
            Button("Abrir Ajustes") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        } message: {
            Text("Para receber notificações, permita-as nos Ajustes do iPhone.")
        }
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
