//
//  AppDelegate.swift
//  Cognitive-Work
//
//  Created by Jonas Fernando Nascimento Melo on 14/08/26.
//

import UIKit
import CloudKit

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: "Default Configuration",
                                          sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }
    
    func application(
        _ application: UIApplication,
        userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
    ) {
        Task {
            let success = await CloudKitManager.shared.acceptShare(metadata: cloudKitShareMetadata)
            if success {
                NotificationCenter.default.post(name: .didAcceptShare, object: nil)
            }
        }
    }
    
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable : Any]
    ) async -> UIBackgroundFetchResult {
        let notification = CKNotification(fromRemoteNotificationDictionary: userInfo)
        
        if notification?.subscriptionID == "shared-changes" || notification?.subscriptionID == "private-changes" {
            NotificationCenter.default.post(name: .cloudKitDidChange, object: nil)
        }
        return .newData
    }
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {

        application.registerForRemoteNotifications()
        
        // Sync fix: subscriptions used to be created only at house creation / join time, and a
        // failure there was swallowed by `try?`. Re-ensuring them on every launch (the call is
        // idempotent) repairs a device that would otherwise never receive `.cloudKitDidChange`.
        Task {
            try? await CloudKitManager.shared.createSharedSubscription()
        }
        
        return true
    }
}
