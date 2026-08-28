//
//  UIImageExtention.swift
//  Cognitive-Work
//
//  Created by Isabela Hissa Pinto on 28/08/26.
//

import UIKit

extension UIImage {
    
    // MARK: - E-Paper Image Preparation (Black and White)

    /// The prepareForEPaper function takes an image, scales it to fit the screen, creates a source buffer
    /// with that scaled image in RGBA (32 bits per pixel) and uses that buffer to create a
    /// second destination buffer with only BW (1 bit per pixel) by checking the lightness of each pixel of the
    /// source buffer.
    ///
    /// A bitmap (or bit map) is a matrix of dots that defines the color of each pixel in a digital image.
    ///
    /// - Parameters:
    ///   - image: The image to be converted to the panel's format.
    /// - Returns: Main function that returns the Data object of 4,736 bytes (3 Colors).
    func blackAndWhiteBitmap() -> Data? {

        // ------------------------------------- Setup variables -------------------------------------
        var image: UIImage = self
        
        let ePaperWidth = 296 //pixels
        let ePaperHeight = 128 //pixels

        // The panel uses 1 bit per pixel (only black or white, no intermediate tones).
        // 296 × 128 = 37,888 pixels ÷ 8 bits per byte = 4,736 bytes.
        let bytesPerLayer = (ePaperWidth * ePaperHeight) / 8

        // Color space of the bitmap, in this case, indicates that it has three (R G B)
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        // flags for the context =  1  |  16384  →  16385
        // premultipliedLast adds a fourth channel, the alpha (transparency) as the last byte of the 4 bytes.
        // Each byte represents a color in a pixel (R G B A).
        // It also describes that the R G B bytes have already been multiplied beforehand by the A, so it no longer exerts any influence.
        // byteOrder32Big prevents the inversion of the pixels' bytes (keeps R G B A)
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue

        // CGContext: Allocates the bitmap's bytes
        // data: you can pass your own pointer or let Core Graphics allocate and deallocate
        // bitsPerComponent: number of bits per channel (one color). 8 = 0 - 255
        // bytesPerRow: number of bytes per row, so it knows where to jump to reach the next one
        // space: colorSpace, bitmapInfo: bitmapInfo -> descriptions of the bitmap
        guard let context = CGContext(data: nil, width: ePaperWidth, height: ePaperHeight,
                                      bitsPerComponent: 8, bytesPerRow: ePaperWidth * 4,
                                      space: colorSpace, bitmapInfo: bitmapInfo) else {
            return nil
        }

        // CGBitmapContext has its origin at the bottom-left corner. Y grows upward.
        // UIKit has its origin at the top-left corner. Y grows downward.
        // Below: Converts to UIKit's coordinate system (origin at the top-left)
        context.translateBy(x: 0, y: CGFloat(ePaperHeight))
        context.scaleBy(x: 1, y: -1)

        // Updates (pushes) UIKit's context to the newly created one -> any new drawing uses this context
        UIGraphicsPushContext(context)

        // ------------------------------------- Fills the source buffer -------------------------------------
        // Each pixel has 32 bits (4 bytes)

        // Chooses the color to be filled in the context
        UIColor.white.setFill()
        // Fills a rectangle with the color (so the background isn't left transparent)
        UIRectFill(CGRect(x: 0, y: 0, width: ePaperWidth, height: ePaperHeight))

        // Chooses the smallest ratio from the proportions between the frame and the image
        let aspectWidth = CGFloat(ePaperWidth) / image.size.width
        let aspectHeight = CGFloat(ePaperHeight) / image.size.height
        let ratio = min(aspectWidth, aspectHeight)

        // New height and width based on the ratio
        let newWidth = image.size.width * ratio
        let newHeight = image.size.height * ratio

        // Centers the image
        let xOffset = (CGFloat(ePaperWidth) - newWidth) / 2.0
        let yOffset = (CGFloat(ePaperHeight) - newHeight) / 2.0

        // Draws the image with the new dimensions at the x and y determined to center it
        image.draw(in: CGRect(x: xOffset, y: yOffset, width: newWidth, height: newHeight))

        // Pops UIKit's context
        UIGraphicsPopContext()

        // Pointer to the buffer allocated by Core Graphics, comes as type UnsafeMutableRawPointer (void*)
        guard let pixelBuffer = context.data else { return nil }
        // cast of the pointer to UInt8 (Unsigned Integer of 8 bits)
        // 1 byte (8 bits) 0 - 255 | [R][G][B][A]  ← each one is a UInt8
        let data = pixelBuffer.bindMemory(to: UInt8.self, capacity: ePaperWidth * ePaperHeight * 4)

        // ------------------------------------- Creates the destination buffer -------------------------------------
        // Each pixel has one bit

        // Creates a new buffer that will receive the BW image. Array of 4,736 zeroed bytes
        var blackBuffer = [UInt8](repeating: 0, count: bytesPerLayer)

        // Walks through the source byte matrix, going over every pixel
        for y in 0..<ePaperHeight {
            for x in 0..<ePaperWidth {

                // Finds the pixel's index by multiplying by the row and by 4 since each pixel has 4 bytes + col * 4
                let pixelIndex = (y * ePaperWidth * 4) + (x * 4)

                // Receives the value of each color and ignores the alpha
                let r = Int(data[pixelIndex])
                let g = Int(data[pixelIndex + 1])
                let b = Int(data[pixelIndex + 2])

                // Calculates whether it is light or dark
                // ITU-R BT.601 luma. The weights are unequal because the eye is much more sensitive to green than to blue.
                // 299+587+114 sums to 1000, so dividing by 1000 gives back the 0–255 scale.
                let brightness = (r * 299 + g * 587 + b * 114) / 1000

                // Bool for whether it is light or not
                let isWhite = brightness > 160
                // Inserts 0 into the buffer if it is light or 1 if it is dark
                let bitColor: UInt8 = isWhite ? 0 : 1

                // Calculation of the destination buffer's index: divides by 8 since each pixel is now a bit,
                // but the notation is in bytes -> truncated return
                let byteIndex = (y * (ePaperWidth / 8)) + (x / 8)

                // Finds the bit's position inside the byteIndex
                // In this case it finds the "complement", since bytes are read from right to left
                let bitPosition = 7 - (x % 8)

                // Writing the bit into the byte
                // in the array at the byte in question, pushes (<<) the color that is in bitColor (0 or 1)
                // to the bitPosition position. The |= does an overlay (OR)
                blackBuffer[byteIndex] |= (bitColor << bitPosition)
            }
        }

        return Data(blackBuffer) // Returns exactly 4,736 bytes
    }
}
