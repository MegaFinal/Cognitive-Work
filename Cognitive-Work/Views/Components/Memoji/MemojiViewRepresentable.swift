//
//  MemojiReciver.swift
//  Cognitive-Work
//
//  Created by Carolina Sun on 19/08/26.
//

import Foundation
import SwiftUI
import UIKit

/// A hidden UIKit text view used to receive images from the system keyboard.
///
/// ``MemojiReceiver`` embeds ``MemojiTextView`` inside SwiftUI
/// and manages keyboard focus and image delivery through `Binding`s.
///
/// The view remains visually hidden while still allowing the system
/// keyboard to interact with the underlying `UITextView`

struct MemojiViewRepresentable: UIViewRepresentable {
    @Binding var selectedImage: UIImage? /// The binding containing the image received from the keyboard.
    @Binding var triggerFocus: Bool /// A binding that requests keyboard focus when set to `true`.


    /// Creates and configures the underlying text view.
    /// - Parameter context: The representable context containing the coordinator.
    /// - Returns: A configured ``MemojiTextView`` instance.
    func makeUIView(context: Context) -> MemojiUITextView {
        let textView = MemojiUITextView()

        textView.backgroundColor = .clear
        textView.textColor = .clear
        textView.tintColor = .clear
        textView.allowsEditingTextAttributes = true
        textView.keyboardType = .default
        textView.returnKeyType = .done
        textView.alpha = 0.01
        textView.delegate = context.coordinator

        textView.onImageReceived = { image in
            DispatchQueue.main.async {
                context.coordinator.parent.selectedImage = image
                textView.resignFirstResponder()
            }
        }

        return textView
    }

    /// Updates the text view when SwiftUI state changes.
    /// When ``triggerFocus`` becomes `true`, the text view requests first responder status so that the keyboard is presented.
    /// - Parameters:
    ///   - uiView: The underlying ``MemojiTextView``.
    ///   - context: The representable context.
    func updateUIView(
        _ uiView: MemojiUITextView,
        context: Context
    ) {
        guard triggerFocus else {
            return
        }

        DispatchQueue.main.async {
            uiView.becomeFirstResponder()
            triggerFocus = false
        }
    }

    /// Creates the UIKit delegate coordinator.
    /// - Returns: A coordinator responsible for observing text view changes.
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    /// A coordinator that observes changes to the underlying text view.
    final class Coordinator: NSObject, UITextViewDelegate {

        var parent: MemojiViewRepresentable /// The parent representable associated with this coordinator

        init(_ parent: MemojiViewRepresentable) {
            self.parent = parent
        }

        /// Detects adaptive image glyphs inserted by the system keyboard
        /// When an ``NSAdaptiveImageGlyph`` is found, its image data is
        /// converted into a `UIImage` and delivered to the parent view
        /// - Parameter textView: The text view whose attributed content changed
        func textViewDidChange(_ textView: UITextView) {
            guard let attributedText = textView.attributedText
            else { return }

            let fullRange = NSRange( location: 0, length: attributedText.length)

            attributedText.enumerateAttributes(in: fullRange,options: []) { attributes, _, stop in
                guard let glyph = attributes.values
                    .compactMap({ $0 as? NSAdaptiveImageGlyph })
                    .first
                else { return }

                guard let image = UIImage(data: glyph.imageContent)
                else { return }

                self.applyImage(image,from: textView)

                stop.pointee = true
            }
        }

        /// Applies the extracted image to the parent and dismisses the keyboard.
        /// - Parameters:
        ///   - image: The extracted image.
        ///   - textView: The text view that received the image.
        private func applyImage(_ image: UIImage,from textView: UITextView) {
            DispatchQueue.main.async {
                self.parent.selectedImage = image
                textView.resignFirstResponder()
                textView.text = ""
            }
        }
    }
}
