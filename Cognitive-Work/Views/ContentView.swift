//
//  ContentView.swift
//  Cognitive-Work
//
//  Created by Jonas Fernando Nascimento Melo on 07/08/26.
//

import SwiftUI
import CloudKit

/// The app's root screen once onboarding is finished.
///
/// Hosts the main tab bar and handles share invitations that arrive while the
/// user already belongs to a house.
struct ContentView: View {
    
    // MARK: - Properties
    @State private var viewModel: ContentViewModel = ContentViewModel()
    
    /// Shared by every tab so pushed screens can hide the tab bar and animate it back.
    @State private var tabBarVisibility = TabBarVisibilityController()
    
    @Environment(\.scenePhase) private var scenePhase
    
    // MARK: - Body
    
    var body: some View {
        TabView {
            ChoresView()
                .tabItem {
                    Label("Tarefas", systemImage: "checklist")
                }
            
            ShopListView()
                .tabItem {
                    Label("Compras", systemImage: "basket")
                }
            
            DashboardView()
                .tabItem {
                    Label("Progresso", systemImage: "figure.2")
                }
            
            UserProfileView()
                .tabItem {
                    Label("Perfil", systemImage: "person.fill")
                }
        }
        .environment(tabBarVisibility)
        .onReceive(NotificationCenter.default.publisher(for: .notAcceptShare)) { cloudMetadata in
            viewModel.showInviteAcceptAlert = true
            viewModel.shareMetadata = cloudMetadata.object as? CKShare.Metadata
        }
        .alert("Não é possivel estar em duas casas ao mesmo tempo", isPresented: $viewModel.showInviteAcceptAlert) {
            Button("Trocar de casa",role: .destructive) {
                viewModel.isSwitchingHouse = true
                Task {
                    if let sm = viewModel.shareMetadata {
                        await viewModel.switchHouse(to: sm)
                    }
                    viewModel.isSwitchingHouse = false
                }
            }
        } message: {
            Text("Se você aceitar, você sairá da sua casa atual todos os seus dados serão perdidos")
        }
        .alert("Ops", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? L10n.tr("Deu algum erro."))
        }
        
        .alert("A casa que você pertencia foi deletada.", isPresented: $viewModel.userHasNoHouse) {
            Button("Ok", role: .confirm) {
                viewModel.accountWithoutHouseReturnToOnboarding()
            }
        } message: {
            Text("Você será redirecionado ao início do aplicativo.")
        }
        
        .blockingOperation(isPresented: $viewModel.isSwitchingHouse, message: "Trocando de casa...")
        .blockingWhileUnlinkingOrphanedHouse()
        
        .task {
            await viewModel.leaveOrphanedHouses()
            await viewModel.fetchHouse()
        }
        .onReceive(NotificationCenter.default.publisher(for: .cloudKitDidChange)) { _ in
            Task { await viewModel.fetchHouse() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await viewModel.fetchHouse() }
            }
        }
    }
}

#Preview {
    ContentView()
}
