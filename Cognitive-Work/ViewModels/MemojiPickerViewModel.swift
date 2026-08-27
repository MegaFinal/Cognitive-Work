////
////  MemojiViewModel.swift
////  Cognitive-Work
////
////  Created by Carolina Sun on 19/08/26.
////
//
//import SwiftUI
//import UIKit
//
///// The view model responsible for managing the state of the Memoji picker.
/////
///// ``MemojiPickerViewModel`` stores the selected profile image and
///// controls when the hidden text view should request keyboard focus.
//
//@Observable
//class MemojiPickerViewModel {
//
//    /// The image currently selected as the profile picture.
//    var profileImage: UIImage?
//
//    /// Indicates whether the hidden text view should request keyboard focus.
//    var shouldOpenKeyboard = false
//
//    /// Requests the keyboard to open.
//    func openKeyboard() {
//        shouldOpenKeyboard = true
//    }
//
//    /// Updates the profile image with the image received from the keyboard.
//    /// - Parameter image: The image selected by the user.
//    func updateProfileImage(_ image: UIImage) {
//        profileImage = image
//    }
//
//    /// Resets the keyboard focus request after it has been handled.
//    func resetKeyboardRequest() {
//        shouldOpenKeyboard = false
//    }
//}
