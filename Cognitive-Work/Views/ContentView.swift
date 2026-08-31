//
//  ContentView.swift
//  Cognitive-Work
//
//  Created by Jonas Fernando Nascimento Melo on 07/08/26.
//

import SwiftUI
import SwiftData
import CloudKit

struct ContentView: View {
    var body: some View {
//        FirstOnboardingView()
        TabView {
            UserChoresView()
                .tabItem {
                    Label("Tarefas", systemImage: "checklist")
                }
             
            UserChoresView()
                .tabItem {
                    Label("Compras", systemImage: "basket")
                }

            UserChoresView()
                .tabItem {
                    Label("Progresso", systemImage: "figure.2")
                }
            
            UserChoresView()
                .tabItem {
                    Label("Perfil", systemImage: "person.fill")
                }
        }
    }
}

#Preview {
    ContentView()
}

