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
                    .font(.subheadline)
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
                    .font(.subheadline)
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
        
        // MARK: - Alerts
        .alert("Excluir Perfil?", isPresented: $showDeleteConfirmation) {
            Button("Cancelar", role: .cancel) {}
            Button("Excluir", role: .destructive) {
                Task {
                    await viewModel.deleteAccount()
                }
            }
        } message: {
            Text("Esta ação é permanente. Todos os seus dados serão apagados do iCloud.")
        }
    }
}

#Preview {
    let mockUser = UserModel(name: "Preview User", tier: .tier1)
    let mockViewModel = UserProfileViewModel(user: mockUser)
    
    return NavigationStack {
        GeneralProfileSettingsView(viewModel: mockViewModel)
    }
}
