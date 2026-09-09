//
//  CloudKitErrors.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 12/08/26.
//

import Foundation
import CloudKit

/// Errors that can occur while retrieving houses and interacting with CloudKit.
enum CloudKitErrors<T>: Error, LocalizedError {
    
    case notFound(T)
    case notAuthorized(T)
    case missingShareURL
    case networkUnavailable
    case quotaExceeded
    case recordChangedTwice
    case zoneNotFound
    case limitExceeded
    case underlying(Error)

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "No private or shared record was found for type: \(T.self)"
            
        case .notAuthorized:
            return "User not authorized to complete request for type: \(T.self)"
            
        case .missingShareURL:
            return "Missing share URL. Não foi possível gerar o link de compartilhamento."
            
        case .networkUnavailable:
            return "Sem conexão com a internet."
            
        case .quotaExceeded:
            return "O armazenamento do iCloud do usuário está cheio. Libere espaço para continuar."
            
        case .recordChangedTwice:
            return "Conflito: Este registro foi modificado recentemente em outro dispositivo. A operação foi cancelada para evitar perda de dados."
            
        case .zoneNotFound:
            return "A zona de registros não foi encontrada. Ela pode ter sido apagada ou não sincronizada."
            
        case .limitExceeded:
            return "O limite de requisições da Apple foi excedido. Tente novamente mais tarde."
            
        case .underlying(let error):
            if let ckError = error as? CKError {
                return "Erro do CloudKit (Código \(ckError.errorCode)): \(ckError.localizedDescription)"
            }
            return "Erro inesperado: \(error.localizedDescription)"
        }
    }
}
