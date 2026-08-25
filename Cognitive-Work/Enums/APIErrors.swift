//
//  APIErrors.swift
//  Cognitive-Work
//
//  Created by Isabela Hissa Pinto on 25/08/26.
//

enum APIErrors: String, Error {
    case unableToEncode
    case invalidURL
    case invalidResponse
    case invalidData
    case unknownError
}
