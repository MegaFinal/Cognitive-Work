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
    
    var body: some Scene {
        WindowGroup {
            Group {
                if didOnboard {
                    ContentView()
                } else {
                    Onboarding(didOnboard: $didOnboard)
                }
            }
            // Dynamic Type is not supported: every explicit font uses a fixed size, and this
            // pins everything else (texts with no `.font`, buttons, navigation titles, sheets)
            // to the default "Large" content size so it ignores the system text size setting.
            .dynamicTypeSize(.large)
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                Task { await hardwareViewModel.refreshDeviceIfNeeded() }
            case .background:
                HardwareBackgroundSync.scheduleAppRefresh()
            default:
                break
            }
        }
        .backgroundTask(.appRefresh(HardwareBackgroundSync.refreshTaskID)) {
            await HardwareBackgroundSync.scheduleAppRefresh()   // schedule the next one
            await HardwareViewModel().refreshDeviceIfNeeded()
        }
    }
}
