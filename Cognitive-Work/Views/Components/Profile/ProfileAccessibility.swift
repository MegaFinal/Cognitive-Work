//
//  ProfileAccessibility.swift
//  Cognitive-Work
//
//  VoiceOver names for the profile/room pickers and the member avatar lists.
//

import Foundation

extension RoomColor {
    /// Spoken name of this color for VoiceOver (the pickers only show a swatch).
    var voiceOverName: String {
        switch self {
        case .purple: L10n.tr("Roxo")
        case .orange: L10n.tr("Laranja")
        case .yellow: L10n.tr("Amarelo")
        case .green: L10n.tr("Verde")
        case .blue: L10n.tr("Azul")
        }
    }
}

/// Accessibility text shared by the profile area's components.
enum ProfileAccessibility {

    /// Spoken name of a room icon (SF Symbol) offered by the room form's icon picker.
    static func symbolName(_ symbol: String) -> String {
        if let room = DefaultRoomsOnboarding.allCases.first(where: { $0.symbol == symbol }) {
            return room.rawValue.localizedDefault
        }
        switch symbol {
        case "lamp.table": return L10n.tr("Abajur")
        case "tv": return L10n.tr("Televisão")
        case "books.vertical": return L10n.tr("Livros")
        case "gamecontroller": return L10n.tr("Videogame")
        case "dumbbell": return L10n.tr("Halteres")
        case "pawprint": return L10n.tr("Animal de estimação")
        case "car": return L10n.tr("Carro")
        case "tree": return L10n.tr("Árvore")
        case "shippingbox": return L10n.tr("Caixa")
        case "stairs": return L10n.tr("Escada")
        case "bathtub": return L10n.tr("Banheira")
        case "music.note": return L10n.tr("Música")
        default: return L10n.tr("Ícone")
        }
    }

    /// Members read as "Fulano, Ciclano e mais 2".
    static func memberList(_ names: [String]) -> String {
        switch names.count {
        case 0: return ""
        case 1: return names[0]
        case 2: return L10n.tr("%@ e %@", names[0], names[1])
        default: return L10n.tr("%@, %@ e mais %lld", names[0], names[1], names.count - 2)
        }
    }
}
