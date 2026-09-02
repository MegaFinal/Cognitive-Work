//
//  WifiConnectionViewModel.swift
//  Cognitive-Work
//
//  Created by Isabela Hissa Pinto on 25/08/26.
//

import SwiftUI
import UIKit

//TODO: ip size verification and masking it to the user by not needing to include the dots
//TODO: loading screen to wait sending wifi. If true goes to code and if false comes back to wificredentials

@Observable
class HardwareViewModel {
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
        guard let image = UIImage(named: "fish"), let imageData = image.levelBitmap() else {
            return
        }
        
        try await deviceConnectionService.sendImageToDevice(imageData: imageData)
    }
    
    @MainActor func sendChartToESP32(values: [CGFloat], labels: [String], title: String) async throws {
            let chartView = BarChartView(values: values, labels: labels, title: title)
            
            let renderer = ImageRenderer(content: chartView)
            renderer.scale = 1.0
            
            guard let image = renderer.uiImage else {
                print("Falha ao renderizar o gráfico")
                return
            }
        guard let imageData = image.ditheringBitmap() else {
                print("Falha ao converter gráfico para o formato do e-paper")
                return
            }
            
            try await deviceConnectionService.sendImageToDevice(imageData: imageData)
        }
}
