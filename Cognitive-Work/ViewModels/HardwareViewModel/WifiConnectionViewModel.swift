//
//  WifiConnectionViewModel.swift
//  Cognitive-Work
//
//  Created by Isabela Hissa Pinto on 25/08/26.
//

import SwiftUI

//TODO: ip size verification and masking it to the user by not needing to include the dots
//TODO: loading screen to wait sending wifi. If true goes to code and if false comes back to wificredentials
//TODO: document and organize here and on arduino ide


@Observable
class WifiConnectionViewModel {
    var deviceIP = ""
    var userWifiName = ""
    var userWifiPassord = ""
    var isPasswordVisible = false
    
    private var deviceConnectionService = DeviceConnectionService()
    
    var navigateToParingView: Bool = false
    var errorMessage: String?
    
    func sendWifiCredentials() async throws {
        deviceConnectionService.ip = deviceIP
        try await deviceConnectionService.sendWifiCredentials(ssid: self.userWifiName, password: self.userWifiPassord)
    }
    
    func askForParingCode() async throws {
        deviceConnectionService.ip = deviceIP
        try await deviceConnectionService.askForParingCode(ipcode: deviceIP)
    }
    
    func prepareImageForESP32() async throws {
        guard let image = UIImage(named: "fish") else {
            print("Imagem não encontrada!")
            return
        }

        if let jpegData = image.jpegData(compressionQuality: 0.8) {
            print(jpegData)
            try await deviceConnectionService.sendImageToDevice(imageData: jpegData)
        }
    }
}
