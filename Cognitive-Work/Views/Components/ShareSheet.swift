//
//  ShareSheet.swift
//  Cognitive-Work
//
//  Created by Carolina Sun on 25/08/26.
//

import SwiftUI
import UIKit

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    init(url: URL) {
        self.items = [url]
    }
    
    /// Shares plain text, e.g. a Pix "copia e cola" code.
    init(text: String) {
        self.items = [text]
    }
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
    }
}


#Preview {
    ShareSheet(url: URL(string: "https://www.icloud.com/share/exemplo")!)
}
