//
//  ContentView.swift
//  Cognitive-Work
//
//  Created by Jonas Fernando Nascimento Melo on 07/08/26.
//

import SwiftUI
import CloudKit

struct ContentView: View {
    @State var showEnviteAcceptAlert: Bool = false
    @State var shareMetadata: CKShare.Metadata? = nil
    
    var body: some View {
        TabView {
            ChoresView()
                .tabItem {
                    Label("Tarefas", systemImage: "checklist")
                }
             
            ChoresView()
                .tabItem {
                    Label("Compras", systemImage: "basket")
                }

            ChoresView()
                .tabItem {
                    Label("Progresso", systemImage: "figure.2")
                }
            
            ChoresView()
                .tabItem {
                    Label("Perfil", systemImage: "person.fill")
                }
        }
        .onReceive(NotificationCenter.default.publisher(for: .notAcceptShare)) { cloudMetadata in
            showEnviteAcceptAlert = true
            self.shareMetadata = cloudMetadata.object as? CKShare.Metadata
        }
        .alert("Não é possivel estar em duas casas ao mesmo tempo", isPresented: $showEnviteAcceptAlert) {
            Button("Trocar de casa",role: .destructive) {
                Task {
                    if let shareMetadata {
                        await CloudKitManager.shared.switchHouse(to: shareMetadata)
                    }
                }
            }
        } message: {
            Text("Se você aceitar, você sairá da sua casa atual todos os seus dados serão perdidos")
        }
    }
}

#Preview {
    ContentView()
}

