//
//  Cognitive_WorkApp.swift
//  Cognitive-Work
//
//  Created by Jonas Fernando Nascimento Melo on 07/08/26.
//

import SwiftUI
import SwiftData

@main
struct Cognitive_WorkApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage("didOnboard") private var didOnboard: Bool = false
    
    @Environment(\.scenePhase) private var scenePhase
    @State private var hardwareViewModel = HardwareViewModel()
    
    /// Language picked in "Configurações Gerais" (or the device language by default).
    @State private var languageManager = LanguageManager.shared
    
    var body: some Scene {
        WindowGroup {
            Group {
                if didOnboard {
                    ContentView()
                } else {
                    Onboarding(didOnboard: $didOnboard)
                }
            }
            .requiresTermsAcceptance()
            .dynamicTypeSize(.large)
            .environment(\.locale, languageManager.locale)
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                Task { await HardwareViewModel.deliverNow() }
            case .background:
                HardwareBackgroundSync.scheduleAppRefresh()
            default:
                break
            }
        }
        .backgroundTask(.appRefresh(HardwareBackgroundSync.refreshTaskID)) {
            await HardwareBackgroundSync.scheduleAppRefresh()   // schedule the next one
            await HardwareViewModel.deliverNow()
        }
    }
}
