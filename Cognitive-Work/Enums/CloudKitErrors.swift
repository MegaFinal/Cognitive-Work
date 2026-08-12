//
//  CloudKitErrors.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 12/08/26.
//

import Foundation

/// Errors that can occur while retrieving houses.
enum CloudKitErrors: Error, LocalizedError {

    /// Indicates that no owned or shared house was found.
    case houseNotFound
    case choreNotFound

    var errorDescription: String? {
        switch self {
        case .houseNotFound:
            return "No owned or shared house was found."
        case .choreNotFound:
            return "No private or shared chore was found"
        }
    }
}
