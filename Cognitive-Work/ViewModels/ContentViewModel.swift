//
//  ContentViewModel.swift
//  Cognitive-Work
//
//  Created by Jonas Fernando Nascimento Melo on 17/08/26.
//

import Foundation
import CloudKit

@Observable
class ContentViewModel {
    var errorMessage: String? = nil
    
    func switchHouse(to metadata: CKShare.Metadata) async {
        await CloudKitManager.shared.switchHouse(to: metadata)
        self.errorMessage = CloudKitManager.shared.errorMessage
    }
}
