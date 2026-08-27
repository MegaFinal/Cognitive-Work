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
    
    // MARK: - E-Paper Image Preparation

    /// A função prepareForEPaper recebe uma imagem, escalona para caber na tela, cria um buffer origem
    /// com essa imagem escalonada em RGBA (32 bits por pixel) e utiliza desse buffer para criar um
    /// segundo buffer origem com apenas BP (1 bit por pixel) verificando a claridade de cada pixel do
    /// buffer origem.
    ///
    /// Um bitmap (ou mapa de bits) é uma matriz de pontos que define a cor de cada pixel em uma imagem digital.
    ///
    /// - Parameters:
    ///   - image: A imagem a ser convertida para o formato do painel.
    /// - Returns: Função principal que devolve o objeto Data de 4.736 bytes (3 Cores).
    func prepareForEPaper(image: UIImage) -> Data? {

        // ----------------------------------------- Variáveis de preparaçao -----------------------------------------

        let ePaperWidth = 296 //pixels
        let ePaperHeight = 128 //pixels

        // O painel usa 1 bit por pixel (só preto ou branco, sem tons intermediários).
        // 296 × 128 = 37.888 pixels ÷ 8 bits por byte = 4.736 bytes.
        let bytesPerLayer = (ePaperWidth * ePaperHeight) / 8

        // Espaço de cor do bitmap, no caso, indica que tem três (R G B)
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        // flags para o context =  1  |  16384  →  16385
        // premultipliedLast Acrescenta um quarto canal, o alpha(transparência) como último byte dos 4 bytes.
        // Cada byte representa uma cor em um pixel (R G B A).
        // Também descreve que os bytes R G B já foram multiplicados previamente pelo A, então ele não excerce nenhuma influência mais.
        // byteOrder32Big impede a inversão dos bytes dos pixels (mantém R G B A)
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue

        // CGContext: Aloca os bytes do bitmap
        // data: pode passar um ponteiro próprio ou deixar o Core Graphics alocar e desalocar
        // bitsPerComponent: qtd de bits por canal (uma cor). 8 = 0 - 255
        // bytesPerRow: qtd de bytes por linha, para saber onde pular para a próxima
        // space: colorSpace, bitmapInfo: bitmapInfo -> descrições do bitmap
        guard let context = CGContext(data: nil, width: ePaperWidth, height: ePaperHeight,
                                      bitsPerComponent: 8, bytesPerRow: ePaperWidth * 4,
                                      space: colorSpace, bitmapInfo: bitmapInfo) else {
            return nil
        }

        // CGBitmapContext tem origem no canto inferior esquerdo. Y cresce para cima.
        // UIKit tem origem no canto superior esquerdo. Y cresce para baixo.
        // Abaixo: Converte para o sistema de coordenadas do UIKit (origem no topo-esquerda)
        context.translateBy(x: 0, y: CGFloat(ePaperHeight))
        context.scaleBy(x: 1, y: -1)

        // Atualiza (empurra) o context do UIKit para o novo criado -> novo desenho criado utiliza desse contexto
        UIGraphicsPushContext(context)

        // ----------------------------------------- Preenche buffer origem -----------------------------------------
        // Cada pixel tem 32 bits (4 bytes)

        // Escolhe cor a ser preenchida no contexto
        UIColor.white.setFill()
        // Preenche um retangulo com a cor (pra não deixar o fundo transparente)
        UIRectFill(CGRect(x: 0, y: 0, width: ePaperWidth, height: ePaperHeight))

        // Escolhe o menor ratio a partir das razões entre o frame e a imagem
        let aspectWidth = CGFloat(ePaperWidth) / image.size.width
        let aspectHeight = CGFloat(ePaperHeight) / image.size.height
        let ratio = min(aspectWidth, aspectHeight)

        // Nova altura e largura a partir do ratio
        let newWidth = image.size.width * ratio
        let newHeight = image.size.height * ratio

        // Centraliza a imagem
        let xOffset = (CGFloat(ePaperWidth) - newWidth) / 2.0
        let yOffset = (CGFloat(ePaperHeight) - newHeight) / 2.0

        // Desenha a imagem com as novas dimenções no x e y determinados para centralizar
        image.draw(in: CGRect(x: xOffset, y: yOffset, width: newWidth, height: newHeight))

        // Da pop no context do UIKit
        UIGraphicsPopContext()

        // Ponteiro para o buffer alocado pelo Core Graphics, vem no tipo UnsafeMutableRawPointer (void*)
        guard let pixelBuffer = context.data else { return nil }
        // cast do ponteiro para UInt8 (Unsigned Integer de 8 bits)
        // 1 byte(8 bits) 0 - 255 | [R][G][B][A]  ← cada um é um UInt8
        let data = pixelBuffer.bindMemory(to: UInt8.self, capacity: ePaperWidth * ePaperHeight * 4)

        // ----------------------------------------- Cria buffer destino -----------------------------------------
        // Cada pixel tem um bit

        // Cria novo buffer que vai receber a imagem PB. Array de 4.736 bytes zerados
        var blackBuffer = [UInt8](repeating: 0, count: bytesPerLayer)

        // Percorre a matriz de bytes origem, passsando por todos os pixels
        for y in 0..<ePaperHeight {
            for x in 0..<ePaperWidth {

                // Acha o index do pixel multiplicando pela linha e 4 pois cada pixel tem 4 bytes + col * 4
                let pixelIndex = (y * ePaperWidth * 4) + (x * 4)

                // Recebe o valor de cada cor e ignora o alpha
                let r = Int(data[pixelIndex])
                let g = Int(data[pixelIndex + 1])
                let b = Int(data[pixelIndex + 2])

                // Calcula se é claro ou escuro
                // Luma da ITU-R BT.601. Os pesos são desiguais porque o olho é muito mais sensível ao verde que ao azul.
                // Soma 299+587+114 = 1000, então dividir por 1000 devolve a escala 0–255.
                let brightness = (r * 299 + g * 587 + b * 114) / 1000

                // Bool se é claro ou não
                let isWhite = brightness > 160
                // Insere no buffer 0 se for claro ou 1 se for escuro
                let bitColor: UInt8 = isWhite ? 0 : 1

                // Calculo do index do buffer destino: divide por 8 pois cada pixel agora é um bit,
                // mas a notação esta em byte -> retorno truncado
                let byteIndex = (y * (ePaperWidth / 8)) + (x / 8)

                // Acha a posição do bit dentro do byteIndex
                // No caso acha o "complemento", pois bytes são lidos da direita pra esquerda
                let bitPosition = 7 - (x % 8)

                // Gravação do bit no byte
                // no array do byte em questão, empurra (<<) a cor que está no bitColor (0 ou 1)
                // para a posição bitPosition. O |= faz uma sobreposição (OR)
                blackBuffer[byteIndex] |= (bitColor << bitPosition)
            }
        }

        return Data(blackBuffer) // Retorna exatamente 4.736 bytes
    }
}
