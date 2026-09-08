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
        print("convite identificado")
        Task {
            do {
                print("fetch casa")
                let _ = try await CloudKitManager.shared.fetchFirst(HouseModel.self)
                print("deu certo o fetch??? :(")
                NotificationCenter.default.post(name: .notAcceptShare, object: cloudKitShareMetadata)
            }
            catch {
                print("Ufa tamo aceitando o share")
                let success = await CloudKitManager.shared.acceptShare(metadata: cloudKitShareMetadata)
                if success {
                    NotificationCenter.default.post(name: .didAcceptShare, object: nil)
                    print("rolou")
                }
                print("não rolou")
            }
        }
    }
}
