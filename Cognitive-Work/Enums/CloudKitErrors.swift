//
//  CloudKitErrors.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 12/08/26.
//

import Foundation

/// Errors that can occur while retrieving houses.
enum CloudKitErrors<T>: Error, LocalizedError {
    
    /// Indicates that no owned or shared house was found.
    case notFound(T)
    case missingShareURL

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "No private or shared record was found for type: \(T.self)"
        case .missingShareURL:
            return "Missing URL"
        }
    }
}
