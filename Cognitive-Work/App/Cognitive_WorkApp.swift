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
    @State private var didOnboard = false
    
    var body: some Scene {
        WindowGroup {
//            if didOnboard {
//                ContentView()
//            } else {
//                Onboarding(didOnboard: $didOnboard)
//            }
            
            WifiCredentialsView()
        }
    }
}
