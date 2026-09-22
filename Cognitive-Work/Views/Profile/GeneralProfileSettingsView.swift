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
    @State private var areHapticsEnabled = false
    @State private var areInteractionsEnabled = false
    @State private var selectedLanguage = "Português"
    
    @State private var showDeleteConfirmation = false
    /// True from the moment deletion starts until the redirect to onboarding happens (or the
    /// attempt fails). Drives ``disabled(_:)`` on the screen and the blocking loading cover
    /// below, so nothing on this screen — or the tab bar / back button around it — can be
    /// touched while the account is mid-deletion.
    @State private var isDeletingAccount = false
    @AppStorage("didOnboard") private var didOnboard: Bool = true
    
    // MARK: - Debug State
    
    let supportedLanguages = ["Português", "Inglês"]
    
    var width = UIScreen.main.bounds.width
    var height = UIScreen.main.bounds.height
    
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
                
                Text("\(selectedLanguage)")
                    .foregroundColor(.secondary)
                
                Menu {
                    Picker("Idioma", selection: $selectedLanguage) {
                        ForEach(supportedLanguages, id: \.self) { language in
                            Text(language)
                                .tag(language)
                        }
                    }
                } label: {
                    Image(systemName: "chevron.right")
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
                }
                
                Text("Vibrações ao concluir uma tarefa.")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading) {
                HStack {
                    Text("Microinterações")
                    
                    Spacer()
                    
                    Toggle("", isOn: $areInteractionsEnabled)
                        .toggleStyle(.switch)
                        .padding(.trailing, 7)
                        .frame(width: width * 0.37)
                }
                
                Text("Pequenos efeitos e animações que servem como um retorno visual.")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
            }
            
            // Calendar Toggle
            VStack(alignment: .leading) {
                HStack {
                    Text("Sincronizar com Calendário")
                     
                    Spacer()
                     
                    Toggle("", isOn: $viewModel.isCalendarSyncEnabled)
                        .toggleStyle(.switch)
                        .padding(.trailing, 7)
                        .frame(width: width * 0.37)
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
        .toolbar(.hidden, for: .tabBar)
        // Block every control on this screen while the deletion (and the redirect that
        // follows it) is in flight.
        .disabled(isDeletingAccount)
        .navigationBarBackButtonHidden(isDeletingAccount)
        
        // MARK: - Alerts
        .alert("Excluir Perfil?", isPresented: $showDeleteConfirmation) {
            Button("Cancelar", role: .cancel) {}
            Button("Excluir", role: .destructive) {
                isDeletingAccount = true
                Task {
                    await viewModel.deleteAccount()
                    if viewModel.errorMessage == nil {
                        // Stays true: the screen is about to be torn down as the app
                        // switches to onboarding, so there's nothing to reset here.
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
        //
        // A full-screen cover, not just an overlay: it also swallows swipes on the
        // navigation back gesture and taps on the tab bar underneath, so literally no
        // action is possible until the deletion finishes and onboarding takes over.
        .fullScreenCover(isPresented: $isDeletingAccount) {
            DeletingAccountLoadingView()
        }
    }
}

/// Full-screen blocking state shown while ``UserProfileViewModel/deleteAccount()`` is running
/// and, on success, until the app finishes redirecting to onboarding.
private struct DeletingAccountLoadingView: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .padding(.bottom, 8)
            Text("Excluindo seu perfil...")
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .interactiveDismissDisabled()
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
