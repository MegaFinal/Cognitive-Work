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
    @State var viewModel: ContentViewModel = ContentViewModel()
    /// Whether the "already in a house" warning is being presented.
    @State var showEnviteAcceptAlert: Bool = false

    /// Metadata of the invitation that triggered the warning.
    @State var shareMetadata: CKShare.Metadata? = nil
    @State private var isSwitchingHouse = false
    
    /// Shared by every tab so pushed screens can hide the tab bar and animate it back.
    @State private var tabBarVisibility = TabBarVisibilityController()
    
    @AppStorage("didOnboard") private var didOnboard: Bool = true

    // MARK: - Body

    var body: some View {
        TabView {
            ChoresView()
                .tabItem {
                    Label("Tarefas", systemImage: "checklist")
                }
             
//            ShopListView()
//                .tabItem {
//                    Label("Compras", systemImage: "basket")
//                }
            
            UserProfileView()
            .tabItem {
                Label("Perfil", systemImage: "person.fill")
            }
        }
        .environment(tabBarVisibility)
        .onReceive(NotificationCenter.default.publisher(for: .notAcceptShare)) { cloudMetadata in
            showEnviteAcceptAlert = true
            self.shareMetadata = cloudMetadata.object as? CKShare.Metadata
        }
        .alert("Não é possivel estar em duas casas ao mesmo tempo", isPresented: $showEnviteAcceptAlert) {
            Button("Trocar de casa",role: .destructive) {
                isSwitchingHouse = true
                Task {
                    if let shareMetadata {
                        await viewModel.switchHouse(to: shareMetadata)
                    }
                    isSwitchingHouse = false
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
        .blockingOperation(isPresented: $isSwitchingHouse, message: "Trocando de casa...")
        .blockingWhileUnlinkingOrphanedHouse()
        .task {
            await leaveOrphanedHouses()
        }
    }
    
    // MARK: - Orphaned houses
    
    /// Leaves any house this iCloud account is still attached to without a member record
    private func leaveOrphanedHouses() async {
        let removed = await CloudKitManager.shared.pruneOrphanedSharedMemberships()
        guard removed > 0 else { return }
        
        if await CloudKitManager.shared.currentHouse(forceRefresh: true) == nil {
            didOnboard = false
        } else {
            NotificationCenter.default.post(name: .cloudKitDidChange, object: nil)
        }
    }
}

#Preview {
    ContentView()
}
