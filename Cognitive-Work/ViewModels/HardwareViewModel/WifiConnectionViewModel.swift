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
        guard let image = UIImage(named: "fish"), let imageData = prepareForEPaper(image: image) else {
            print("Imagem não encontrada!")
            return
        }
        
        try await deviceConnectionService.sendImageToDevice(imageData: imageData)
    }
    
    // Função principal que devolve o objeto Data de 4.736 bytes (3 Cores)
    func prepareForEPaper(image: UIImage) -> Data? {
        let ePaperWidth = 296
        let ePaperHeight = 128
        let bytesPerLayer = (ePaperWidth * ePaperHeight) / 8 // 4.736 bytes
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        
        guard let context = CGContext(data: nil, width: ePaperWidth, height: ePaperHeight,
                                      bitsPerComponent: 8, bytesPerRow: ePaperWidth * 4,
                                      space: colorSpace, bitmapInfo: bitmapInfo) else {
            return nil
        }

        // Converte para o sistema de coordenadas do UIKit (origem no topo-esquerda)
        context.translateBy(x: 0, y: CGFloat(ePaperHeight))
        context.scaleBy(x: 1, y: -1)

        UIGraphicsPushContext(context)
        
        UIGraphicsPushContext(context)
        
        UIColor.white.setFill()
        UIRectFill(CGRect(x: 0, y: 0, width: ePaperWidth, height: ePaperHeight))
        
        let aspectWidth = CGFloat(ePaperWidth) / image.size.width
        let aspectHeight = CGFloat(ePaperHeight) / image.size.height
        let ratio = min(aspectWidth, aspectHeight)
        
        let newWidth = image.size.width * ratio
        let newHeight = image.size.height * ratio
        let xOffset = (CGFloat(ePaperWidth) - newWidth) / 2.0
        let yOffset = (CGFloat(ePaperHeight) - newHeight) / 2.0
        
        image.draw(in: CGRect(x: xOffset, y: yOffset, width: newWidth, height: newHeight))
        
        UIGraphicsPopContext()
        
        guard let pixelBuffer = context.data else { return nil }
        let data = pixelBuffer.bindMemory(to: UInt8.self, capacity: ePaperWidth * ePaperHeight * 4)
        
        var blackBuffer = [UInt8](repeating: 0, count: bytesPerLayer)
        
        for y in 0..<ePaperHeight {
            for x in 0..<ePaperWidth {
                let pixelIndex = (y * ePaperWidth * 4) + (x * 4)
                
                let r = Int(data[pixelIndex])
                let g = Int(data[pixelIndex + 1])
                let b = Int(data[pixelIndex + 2])
                
                // Calcula se é claro ou escuro
                let brightness = (r * 299 + g * 587 + b * 114) / 1000
                let isWhite = brightness > 160
                
                let blackBit: UInt8 = isWhite ? 0 : 1
                
                let byteIndex = (y * (ePaperWidth / 8)) + (x / 8)
                let bitPosition = 7 - (x % 8)
                
                blackBuffer[byteIndex] |= (blackBit << bitPosition)
            }
        }
        
        return Data(blackBuffer) // Retorna exatamente 4.736 bytes
    }
}
