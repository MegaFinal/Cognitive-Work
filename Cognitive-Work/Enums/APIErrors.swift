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
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:      return L10n.tr("Não foi possível encontrar o dispositivo externo. Confira o IP.")
        case .unableToEncode:  return L10n.tr("Erro ao preparar os dados.")
        case .invalidResponse: return L10n.tr("O dispositivo externo não respondeu como esperado.")
        case .invalidData:     return L10n.tr("Resposta do dispositivo externo em formato inesperado.")
        case .unknownError: return L10n.tr("Erro desconhecido.")
        }
    }
}
