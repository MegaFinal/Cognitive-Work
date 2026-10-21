//
//  GeneralProfileSettingsView.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 03/09/26.
//

import SwiftUI
import UserNotifications

/// The "Configurações Gerais" screen: app language, haptics, calendar sync and deleting the profile.
struct GeneralProfileSettingsView: View {
    /// The user's profile: calendar sync and deleting the account.
    @Bindable var viewModel: UserProfileViewModel
    /// The house: checks if the user is admin and deletes or leaves the house with the profile.
    @Bindable var houseViewModel: HouseEditViewModel
        
    /// Persisted and read by ``HapticsManager`` on every vibration, so the switch applies in
    /// real time. (It used to be a local `@State` that nothing read, reset on every visit.)
    @AppStorage(HapticsManager.storageKey) private var areHapticsEnabled = true
    
    /// User's in-app choice. Only effective while the system permission is also granted.
    @AppStorage("notificationsEnabled") private var areNotificationsEnabled = false
    /// Shows the "notifications are off, open Settings" alert.
    @State private var showNotificationsDeniedAlert = false
    /// Used to re-check the notification permission when the app comes back.
    @Environment(\.scenePhase) private var scenePhase
    
    /// Shows the "delete profile?" alert for a regular member.
    @State private var showDeleteConfirmation = false
    /// Shows the "delete profile?" alert for the admin (the house is deleted too).
    @State private var showAdminDeleteConfirmation = false

    /// Shows the blocking overlay while the profile is being deleted.
    @State private var isDeletingAccount = false
    /// Set to `false` after deleting, which sends the user back to onboarding.
    @AppStorage("didOnboard") private var didOnboard: Bool = true
    
    /// Reads and changes the app's language.
    private let languageManager = LanguageManager.shared
    
    /// Connects the language picker to ``LanguageManager``.
    private var languageSelection: Binding<AppLanguage> {
        Binding(
            get: { languageManager.current },
            set: { languageManager.setLanguage($0) }
        )
    }
    
    /// The notifications switch: turning it on asks for permission first.
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
            // MARK: - Language picker
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
            
            // MARK: - Haptics switch
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
            
            // MARK: - Notifications switch (hidden for now)
//            VStack(alignment: .leading) {
//                HStack {
//                    Text("Notificações")
//                    
//                    Spacer()
//                    
//                    Toggle("", isOn: notificationsBinding)
//                        .toggleStyle(.switch)
//                        .padding(.trailing, 7)
//                        .frame(width: width * 0.37)
//                }
//                
//                Text("Receber avisos sobre as tarefas da casa.")
//                    .font(.system(size: 15))
//                    .foregroundColor(.secondary)
//            }
            
            // MARK: - Calendar sync switch
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
        
        // MARK: - Keeps the notifications switch in sync with iOS Settings
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
