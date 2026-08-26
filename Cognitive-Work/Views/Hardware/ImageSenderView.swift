//
//  ImageSenderView.swift
//  Cognitive-Work
//
//  Created by Isabela Hissa Pinto on 26/08/26.
//

import SwiftUI

struct ImageSenderView: View {
    let image1 = UIImage(named: "fish")
    let image2 = UIImage(named: "emoji")
    var imageSenderViewModel = ImageSenderViewModel()
    
    var body: some View {
        Button {
            imageSenderViewModel.prepareImageForESP32()
        } label: {
            Image(uiImage: image1!)
        }
    }
}

#Preview {
    ImageSenderView()
}
