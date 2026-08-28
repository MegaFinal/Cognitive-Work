//
//  ColorIconTagLabel.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 28/08/26.
//

import SwiftUI

struct ColorIconTagLabel: View {
    let title: String
    let color: Color
    
    var body: some View {
        Label {
            Text(title)
        } icon: {
            Image(uiImage: .coloredCircle(color: color))
                .renderingMode(.original)
        }
    }
}
