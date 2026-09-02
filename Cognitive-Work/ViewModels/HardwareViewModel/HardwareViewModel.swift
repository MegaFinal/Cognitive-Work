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
//TODO: Save Wi-Fi, password, and IP so the user doesn't need to log in every time.


/// A view model that manages hardware connectivity and data transmission for an ESP32 device.
@Observable
class HardwareViewModel {
    
    // MARK: - Device Connection & Pairing (IP & Wi-Fi)
    
    /// The IP address of the target hardware device.
    var deviceIP = ""
    
    /// The name (SSID) of the user's local Wi-Fi network.
    var userWifiName = ""
    
    /// The password for the user's local Wi-Fi network.
    var userWifiPassord = ""
    
    /// A boolean value indicating whether the Wi-Fi password is visible in the UI.
    var isPasswordVisible = false
    
    /// A flag indicating whether to navigate to the pairing view.
    var navigateToParingView: Bool = false
    
    /// An optional error message capturing the latest failure state.
    var errorMessage: String?
    
    private var deviceConnectionService = DeviceConnectionService()
    
    /// Sends Wi-Fi credentials to the connected hardware device.
    func sendWifiCredentials() async throws {
        deviceConnectionService.ip = deviceIP
        try await deviceConnectionService.sendWifiCredentials(ssid: self.userWifiName, password: self.userWifiPassord)
    }
    
    /// Requests a pairing code from the device using the current IP.
    func askForParingCode() async throws {
        deviceConnectionService.ip = deviceIP
        try await deviceConnectionService.askForParingCode(ipcode: deviceIP)
    }
    
    // MARK: - Image & Chart Transmission (ESP32 Display)
    
    /// A list of users associated with the charts.
    var users: [UserModel] = []
    
    /// A list of chores tracked in the system.
    var chores: [ChoreModel] = []
    
    /// Prepares and sends a static image ("fish") to the ESP32.
    func prepareImageForESP32() async throws {
        guard let image = UIImage(named: "fish"), let imageData = image.levelBitmap() else {
            return
        }
        
        try await deviceConnectionService.sendImageToDevice(imageData: imageData)
    }
    
    /// Renders a fortnightly chore chart and streams it as an e-paper compatible image to the ESP32.
    /// - Parameters:
    ///   - users: The list of users to display.
    ///   - chores: The list of chores tracked.
    ///   - usageEntries: Daily usage metrics.
    ///   - startDate: The starting date for the chart window.
    /// - Throws: An error if rendering fails or if the network transmission is interrupted.
    @MainActor
    func sendChartToESP32(users: [UserModel], chores: [ChoreModel], usageEntries: [DailyUsageEntry], startDate: Date) async throws {
        let chartView = FortnightlyChartRenderView(
            users: users,
            chores: chores,
            usageEntries: usageEntries,
            startDate: startDate
        )
        
        let renderer = ImageRenderer(content: chartView)
        renderer.scale = 1.0
        
        guard let image = renderer.uiImage else {
            throw NSError(domain: "HardwareViewModel", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Failed to render the chart view."])
        }
        guard let imageData = image.ditheringBitmap() else {
            throw NSError(domain: "HardwareViewModel", code: 1002, userInfo: [NSLocalizedDescriptionKey: "Failed to convert the chart image into e-paper format."])
        }
        
        try await deviceConnectionService.sendImageToDevice(imageData: imageData)
    }
}
