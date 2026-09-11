//
//  SceneDelegate.swift
//  Cognitive-Work
//
//  Created by Jonas Fernando Nascimento Melo on 14/08/26.
//

import UIKit
import CloudKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    
    var window: UIWindow?
    
    func windowScene(_ windowScene: UIWindowScene, userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata) {
        Task {
            do {
                let _ = try await CloudKitManager.shared.fetchFirst(HouseModel.self)
                NotificationCenter.default.post(name: .notAcceptShare, object: cloudKitShareMetadata)
            }
            catch {
                let success = await CloudKitManager.shared.acceptShare(metadata: cloudKitShareMetadata)
                if success {
                    NotificationCenter.default.post(name: .didAcceptShare, object: nil)
                }
            }
        }
    }
}
