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
    }
}

#Preview {
    ContentView()
}

