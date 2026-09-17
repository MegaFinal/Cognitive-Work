//
//  WifiConnectionViewModel.swift
//  Cognitive-Work
//
//  Created by Isabela Hissa Pinto on 25/08/26.
//

import SwiftUI
import UIKit
import CloudKit

//TODO: ip size verification and masking it to the user by not needing to include the dots
//TODO: loading screen to wait sending wifi. If true goes to code and if false comes back to wificredentials
//TODO: Save Wi-Fi, password, and IP so the user doesn't need to log in every time.


/// A view model that manages hardware connectivity and data transmission for an ESP32 device.
@Observable
class HardwareViewModel {
    
    // MARK: - Device Connection & Pairing (IP & Wi-Fi)
    
    /// The IP address of the target hardware device.
    var deviceIP = ""
    
    var hardwareIp: HardwareIpModel?
    
    var house: HouseModel?
    
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
    
    private var hardwareNetworkManager = HardwareNetworkManager()
    
    /// Sends Wi-Fi credentials to the connected hardware device.
    func sendWifiCredentials() async throws {
        hardwareNetworkManager.ip = deviceIP
        try await hardwareNetworkManager.sendWifiCredentials(ssid: self.userWifiName, password: self.userWifiPassord)
    }
    
    /// Requests a pairing code from the device using the current IP.
    func askForParingCode() async throws -> Bool {
        hardwareNetworkManager.ip = deviceIP
        try await hardwareNetworkManager.askForParingCode(ipcode: deviceIP)
        return hardwareNetworkManager.isConnected
    }
    
    // MARK: - Image & Chart Transmission (ESP32 Display)
    
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
        guard let imageData = image.levelBitmap4Gray() else {
            throw NSError(domain: "HardwareViewModel", code: 1002, userInfo: [NSLocalizedDescriptionKey: "Failed to convert the chart image into e-paper format."])
        }
        
        try await hardwareNetworkManager.sendImageToDevice(imageData: imageData)
    }
    
    /// Prepares and sends a static image (rendered from a SwiftUI View) to the ESP32.
    func prepareImageForESP32<Content: View>(view: Content) async throws {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1.0
        
        guard let image = renderer.uiImage else {
            throw NSError(
                domain: "HardwareViewModel",
                code: 1003,
                userInfo: [NSLocalizedDescriptionKey: "Falha ao renderizar a view em imagem."]
            )
        }
        guard let imageData = image.levelBitmap4Gray() else {
            throw NSError(
                domain: "HardwareViewModel",
                code: 1004,
                userInfo: [NSLocalizedDescriptionKey: "Falha ao converter imagem para o formato do e-paper."]
            )
        }
        try await hardwareNetworkManager.sendImageToDevice(imageData: imageData)
    }
    //MARK: - Cloudkit
    
    /// Creates a new IP record only if one doesn't already exist for this IP, avoiding duplicate records.
    @MainActor
    func createIp() async -> Bool {
        errorMessage = nil
         
        house = try? await CloudKitManager.shared.fetchFirst(HouseModel.self)
         
        guard let houseRecordID = house?.recordID else { 
            errorMessage = "House not found."
            return false
        }
         
        let houseReference = CKRecord.Reference(recordID: houseRecordID, action: .none)
         
        if let existing = try? await CloudKitManager.shared.fetchFirst(HardwareIpModel.self),
           existing.ip == self.deviceIP {
            self.hardwareIp = existing
            return true
        }
         
        let ip = HardwareIpModel(ip: self.deviceIP)
         
        if let created = await CloudKitManager.shared.create(ip, zoneID: house?.recordID?.zoneID, parent: houseReference) {
            self.hardwareIp = created
            return true
        } else {
            errorMessage = "Erro ao criar IP."
            return false
        }
    }
    
    func fetchIp() async {
        errorMessage = nil
        
        do {
            hardwareIp = try await CloudKitManager.shared.fetchFirst(HardwareIpModel.self)
        } catch {
            errorMessage = error.localizedDescription
        }
        
        deviceIP = hardwareIp?.ip ?? ""
        
        print(deviceIP)
    }
    
    /// Deletes the current IP record and clears local state so the UI reflects the change immediately.
    func deleteIp() async {
        guard let hardwareIp else { return }

        await CloudKitManager.shared.delete(hardwareIp)
        
        self.hardwareIp = nil
        self.deviceIP = ""
    }
}
