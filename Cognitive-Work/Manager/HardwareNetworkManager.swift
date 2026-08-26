//
//  HardwareNetworkManager.swift
//  Cognitive-Work
//
//  Created by Isabela Hissa Pinto on 25/08/26.
//

import Foundation

struct ImageToSend: Codable {
    let hash: String
    let imageData: Data
}

@Observable
class DeviceConnectionService {
    var ip: String = ""
    
    private var session = URLSession.self
    private var decoder = JSONDecoder()
    private var base: String = "http://"
    private var hash: String = ""
    private(set) var isConnected: Bool = false
    
    func sendWifiCredentials(ssid: String, password: String) async throws {
        let route = "/save_wifi"
        let endpoint = base + ip + route
        print("endpoint: \(endpoint)")
        let wifi = WifiCredentials(ssid: ssid, password: password)
        print("wifi: \(ssid), password: \(password)")
        
        guard let url = URL(string: endpoint) else {
            print("erro: URL linha")
            throw APIErrors.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
           let jsonData = try JSONEncoder().encode(wifi)
           request.httpBody = jsonData
        } catch {
            print("erro: encode de data - Wifi credentials")
            throw APIErrors.unableToEncode
        }
        
        let (data, response) = try await session.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            print("erro no envio das credenciais do WiFi.")
            throw APIErrors.invalidResponse
        }
        
        do {
            let resposta = try decoder.decode(Esp32Answer.self, from: data)
            print(resposta.message)
        } catch {
            print("erro: decode data - \(data)")
            throw APIErrors.invalidData
        }
    }
    
    func askForParingCode(ipcode: String) async throws {
        self.ip = ipcode
        
        let route = "/ask_code"
        let endpoint = base + ip + route
        print("endpoint: \(endpoint)")
        
        guard let url = URL(string: endpoint) else {
            print("erro: URL linha")
            throw APIErrors.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = Data() //vazio
        
        let (data, response) = try await session.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            print("erro no recebimento do código.")
            throw APIErrors.invalidResponse
        }
        
        do {
            let resposta = try decoder.decode(Esp32Answer.self, from: data)
            self.hash = resposta.message
            print("hash: \(resposta.message)")
        } catch {
            print("erro: decode data - \(data)")
            throw APIErrors.invalidData
        }
        
        print(self.ip)
    }
    
    func printMessageOnDevice(messageOne: String, messageTwo: String) async throws {
        let route = "/send_text"
        let endpoint = self.base + self.ip + route
        
        let message = MessageToSend(hash: hash, messageOne: messageOne, messageTwo: messageTwo)
        
        guard let url = URL(string: endpoint) else {
            print("erro: URL linha")
            throw APIErrors.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
           let jsonData = try JSONEncoder().encode(message)
           request.httpBody = jsonData
        } catch {
            print("erro: encode de data - Mensagem")
            throw APIErrors.unableToEncode
        }
        
        let (data, response) = try await session.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            print("erro no envio da mensagem a ser impressa.")
            throw APIErrors.invalidResponse
        }
        
        do {
            let resposta = try decoder.decode(Esp32Answer.self, from: data)
            print(resposta.message)
        } catch {
            print("erro: decode data - \(data)")
            throw APIErrors.invalidData
        }
    }
    
    func sendImageToDevice(imageData: Data) async throws {
        let route = "/send_image"
        let endpoint = self.base + self.ip + route
        
        let imageToSend = ImageToSend(hash: self.hash, imageData: imageData)
        
        guard let url = URL(string: endpoint) else {
            print("erro: URL linha")
            throw APIErrors.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
           let jsonData = try JSONEncoder().encode(imageToSend)
           request.httpBody = jsonData
        } catch {
            print("erro: encode de data - Imagem")
            throw APIErrors.unableToEncode
        }
        
        let (data, response) = try await session.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            print("erro no envio da imagem a ser impressa.")
            throw APIErrors.invalidResponse
        }
        
        do {
            let resposta = try decoder.decode(Esp32Answer.self, from: data)
            print(resposta.message)
        } catch {
            print("erro: decode data - \(data)")
            throw APIErrors.invalidData
        }
    }
    
}
