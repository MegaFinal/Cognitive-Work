//
//  MemojiTextView.swift
//  Cognitive-Work
//
//  Created by Carolina Sun on 19/08/26.
//

import Foundation
import UIKit

/// A custom text view capable of detecting images received from the pasteboard.
///
/// ``MemojiTextView`` overrides the standard paste behavior to inspect
/// pasteboard contents for images. When an image is found, it is passed
/// to ``onImageReceived``

final class MemojiUITextView: UITextView {

    /// A closure called when an image is detected in the pasteboard.
    var onImageReceived: ((UIImage) -> Void)?

    /// The method first attempts to find a `UIImage` directly in the pasteboard. If that fails, it attempts to convert `Data` into  a `UIImage`.
    /// If no image can be extracted, the default UIKit paste behavior is preserved.
    /// - Parameter sender: The object that initiated the paste action.

    override func paste(_ sender: Any?) {
        let pasteboard = UIPasteboard.general

        for item in pasteboard.items {
            for (_, value) in item {
                if let image = value as? UIImage {
                    onImageReceived?(image)
                    return
                }

                if let data = value as? Data,
                   let image = UIImage(data: data) {
                    onImageReceived?(image)
                    return
                }
            }
        }

        super.paste(sender)
    }
}
