//
//  HardwareNetworkManager.swift
//  Cognitive-Work
//
//  Created by Isabela Hissa Pinto on 25/08/26.
//

import Foundation

/// Handles every HTTP call to the ESP32 device.
///
/// The device is reached over the local network, so every endpoint is built as
/// "http://" + the device's IP + the route. There are three phases:
///
/// 1. Provisioning — the ESP32 is its own access point and receives the home WiFi credentials
/// 2. Pairing — the app asks for the hash the device generated at boot and keeps it
/// 3. Use — text and images are sent, authenticated by that hash
@Observable
class HardwareNetworkManager {
    /// The device's IP. Typed by the user while the ESP32 is still an access point
    /// (usually 192.168.4.1), then replaced by the address it gets on the home network.
    var ip: String = ""

    private var session = URLSession.shared
    private var decoder = JSONDecoder()

    /// Scheme prefix. Plain HTTP because the ESP32 has no certificate.
    private var base: String = "http://"

    /// Pairing token received from /ask_code. Proves to the device that requests
    /// come from this app and not from another machine on the same network.
    private var hash: String = ""

    private(set) var isConnected: Bool = false
    
    // MARK: - Hash Persistence
    
    private var localPersistence = UserDefaults.standard
    
    private enum StorageKey {
        static let hash = "hardware.hash"
        static let ip = "hardware.ip"
    }
    
    init() {
        if let savedHash = localPersistence.string(forKey: StorageKey.hash),
           let savedIP = localPersistence.string(forKey: StorageKey.ip) {
            self.hash = savedHash
            self.ip = savedIP
            self.isConnected = true
        }
    }

    // MARK: - Provisioning

    /// Sends the user's home WiFi credentials so the device can leave access point mode.
    ///
    /// After this call the ESP32 drops its own network and joins the one given here,
    /// which means its IP changes and this service must be pointed at the new address.
    ///
    /// - Parameters:
    ///   - ssid: Name of the network the device should join.
    ///   - password: Password of that network.
    /// - Throws: ``APIErrors/invalidURL`` if the IP produces a malformed endpoint,
    ///   ``APIErrors/unableToEncode`` if the credentials can't be turned into JSON,
    ///   ``APIErrors/invalidResponse`` if the device answers with anything other than 200,
    ///   ``APIErrors/invalidData`` if the body doesn't match ``Esp32Answer``.
    func sendWifiCredentials(ssid: String, password: String) async throws {
        let route = "/save_wifi"
        let endpoint = base + ip + route
        let wifi = WifiCredentials(ssid: ssid, password: password)

        guard let url = URL(string: endpoint) else {
            throw APIErrors.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Encodes the credentials into the request body
        do {
           let jsonData = try JSONEncoder().encode(wifi)
           request.httpBody = jsonData
        } catch {
            throw APIErrors.unableToEncode
        }

        let (data, response) = try await session.data(for: request)

        // The ESP32 answers 200 before actually connecting, since connecting
        // tears down the access point and this response would never arrive
        try validate(data: data, response: response)
    }

    // MARK: - Pairing

    /// Asks the device for its pairing hash and stores it for the authenticated routes.
    ///
    /// The hash is a UUID the ESP32 generates once at boot. Every later request carries it,
    /// so a reboot on the device side invalidates the pairing and this call must be repeated.
    ///
    /// - Parameters:
    ///   - ipcode: The device's IP, which also becomes this service's stored address.
    /// - Throws: ``APIErrors/invalidURL``, ``APIErrors/invalidResponse``, ``APIErrors/invalidData``.
    func askForParingCode(ipcode: String) async throws {
        self.ip = ipcode

        let route = "/ask_code"
        let endpoint = base + ip + route

        guard let url = URL(string: endpoint) else {
            throw APIErrors.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = Data() // empty: the device reads nothing from this request

        let (data, response) = try await session.data(for: request)

        // The hash travels in the "message" field of the standard answer envelope
        let answer = try validate(data: data, response: response)
        self.hash = answer.message
        isConnected = true
        
        // Persistence
        localPersistence.set(self.hash, forKey: StorageKey.hash)
        localPersistence.set(self.ip, forKey: StorageKey.ip)
    }

    // MARK: - Sending content

    /// Prints two lines of text on the e-paper: the first in black, the second in red.
    ///
    /// Unlike ``sendImageToDevice(imageData:)``, the hash goes inside the JSON body here
    /// rather than in a header.
    ///
    /// - Parameters:
    ///   - messageOne: Text of the first line (black).
    ///   - messageTwo: Text of the second line (red).
    /// - Throws: ``APIErrors/invalidURL``, ``APIErrors/unableToEncode``,
    ///   ``APIErrors/invalidResponse``, ``APIErrors/invalidData``.
    func printMessageOnDevice(messageOne: String, messageTwo: String) async throws {
        let route = "/send_text"
        let endpoint = self.base + self.ip + route

        // The hash is part of the payload, alongside the two lines
        let message = MessageToSend(hash: hash, messageOne: messageOne, messageTwo: messageTwo)

        guard let url = URL(string: endpoint) else {
            throw APIErrors.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
           let jsonData = try JSONEncoder().encode(message)
           request.httpBody = jsonData
        } catch {
            throw APIErrors.unableToEncode
        }

        let (data, response) = try await session.data(for: request)
        try validate(data: data, response: response)
    }

    /// Sends a 1 bit per pixel bitmap to be drawn on the e-paper.
    ///
    /// The body is base64 rather than raw binary: the ESP32's WebServer stores the request body
    /// in a C string, which stops at the first 0x00 byte — and a bitmap is full of zeroed bytes
    /// wherever the image is white. Base64 only uses printable characters, so it survives that.
    /// The 33% size increase is irrelevant over a local network.
    ///
    /// Because the body is entirely image data, there is no room for a JSON envelope, so the
    /// hash travels in the X-Auth-Hash header instead.
    ///
    /// - Parameters:
    ///   - imageData: The 4,736 bytes produced by `prepareForEPaper` or `ditheringBitmap`.
    /// - Throws: ``APIErrors/invalidURL``, ``APIErrors/invalidResponse``, ``APIErrors/invalidData``.
    func sendImageToDevice(imageData: Data) async throws {
        guard imageData.count == 800 * 480 / 4 else { throw APIErrors.invalidData }

        let endpoint = self.base + self.ip + "/send_image"
        guard let url = URL(string: endpoint) else { throw APIErrors.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.setValue(self.hash, forHTTPHeaderField: "X-Auth-Hash")
        request.timeoutInterval = 60

        let (data, response) = try await session.upload(for: request, from: imageData)
        try validate(data: data, response: response)
    }
    
    // MARK: - Reset

    /// Asks the device to wipe its WiFi credentials and hash, then forgets the local pairing.
    ///
    /// The ESP32 answers before restarting and comes back in access point mode,
    /// so provisioning and pairing must be done again.
    func resetDevice() async throws {
        let endpoint = base + ip + "/reset"
        guard let url = URL(string: endpoint) else { throw APIErrors.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(hash, forHTTPHeaderField: "X-Auth-Hash")
        request.httpBody = Data()

        let (data, response) = try await session.data(for: request)
        try validate(data: data, response: response)

        forgetDevice()
    }

    /// Clears the pairing on this iPhone only. Also useful when the device was reset
    /// by its button and can no longer be reached.
    func forgetDevice() {
        hash = ""
        ip = ""
        isConnected = false
        localPersistence.removeObject(forKey: StorageKey.hash)
        localPersistence.removeObject(forKey: StorageKey.ip)
    }

    // MARK: - Response handling

    /// Validates the device's answer and decodes the standard envelope.
    ///
    /// A 401 means the hash no longer matches — usually because the ESP32 rebooted and
    /// generated a new one — so the pairing is dropped and the app must pair again.
    ///
    /// - Parameters:
    ///   - data: Raw body returned by the request.
    ///   - response: The URLResponse to validate.
    /// - Returns: The decoded ``Esp32Answer``.
    /// - Throws: ``APIErrors/invalidResponse`` for any status other than 200,
    ///   ``APIErrors/invalidData`` if the body doesn't match ``Esp32Answer``.
    @discardableResult
    private func validate(data: Data, response: URLResponse) throws -> Esp32Answer {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIErrors.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            isConnected = false
            hash = ""
            localPersistence.removeObject(forKey: StorageKey.hash)
            throw APIErrors.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw APIErrors.invalidResponse
        }

        do {
            return try decoder.decode(Esp32Answer.self, from: data)
        } catch {
            throw APIErrors.invalidData
        }
    }
}
