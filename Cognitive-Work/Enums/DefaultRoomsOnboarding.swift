//
//  Room.swift
//  Cognitive-Work
//
//  Created by Jonas Fernando Nascimento Melo on 28/08/26.
//

import Foundation

/// A room of the house used to suggest a starting set of chores during onboarding.
///
/// Each case exposes a ``displayName`` for the UI and a ``defaultChores`` list
/// with the chores most households run for that room. The suggestions are meant
/// as a starting point: the user still toggles ``ChoreDTO/isSelected`` on the
/// selection screen before anything is persisted.
///
/// Example:
/// ```swift
/// let chores = Room.kitchen.defaultChores
/// // -> [Lavar a louça, Limpar a bancada e o fogão, ...]
/// ```
enum DefaultRoomsOnboarding: String, CaseIterable, Identifiable {

    case bedroom = "Quarto"
    case livingRoom = "Sala de Estar"
    case laundryRoom = "Área de Serviço"
    case kitchen = "Cozinha"
    case bathroom = "Banheiro"
    case homeOffice = "Escritório"

    // MARK: - Identity

    /// Stable identity used by `ForEach` and `Picker`.
    var id: String { rawValue }
    
    // MARK: - Room
    /// Room representation used by onboarding chore previews.
    var roomDTO: RoomDTO {
        switch self {
        case .bedroom:
            RoomDTO(
                name: rawValue,
                symbol: "bed.double.fill",
                color: .purple )
            
        case .livingRoom:
            RoomDTO(
                name: rawValue,
                symbol: "sofa.fill",
                color: .orange )
            
        case .laundryRoom:
            RoomDTO(
                name: rawValue,
                symbol: "washer.fill",
                color: .blue )
            
        case .kitchen:
            RoomDTO(
                name: rawValue,
                symbol: "fork.knife",
                color: .green )
            
        case .bathroom:
            RoomDTO(
                name: rawValue,
                symbol: "shower.fill",
                color: .white )
            
        case .homeOffice:
            RoomDTO(
                name: rawValue,
                symbol: "desktopcomputer",
                color: .yellow )
        }
    }

    // MARK: - Default Chores

    /// Chores suggested for this room during onboarding.
    ///
    /// > Important: ``ChoreDTO`` is a reference type, so every access builds a
    /// > brand new batch of instances. Store the result once (in the view model
    /// > or in `@State`) instead of calling this inside `body`, otherwise the
    /// > toggles reset on each redraw.
    /// Chores suggested for this room during onboarding.
    var defaultChores: [ChoreDTO] {
        switch self {
        case .bedroom:
            DefaultRoomsOnboarding.bedroomChores
        case .livingRoom:
            DefaultRoomsOnboarding.livingRoomChores
        case .laundryRoom:
            DefaultRoomsOnboarding.laundryRoomChores
        case .kitchen:
            DefaultRoomsOnboarding.kitchenChores
        case .bathroom:
            DefaultRoomsOnboarding.bathroomChores
        case .homeOffice:
            DefaultRoomsOnboarding.homeOfficeChores
        }
    }

}

// MARK: - Chore Catalog

private extension DefaultRoomsOnboarding {

    static var bedroomChores: [ChoreDTO] {
        let room = DefaultRoomsOnboarding.bedroom.roomDTO
        return [
            ChoreDTO(
                name: "Arrumar cama",
                description: "Esticar o lençol, ajeitar o edredom e os travesseiros.",
                frequency: .daily,
                duration: 5,
                priorityTag: .low,
                room: room
            ),
            ChoreDTO(
                name: "Trocar lençois",
                description: "Trocar lençol, fronhas e capa do edredom e levar o usado para lavar.",
                frequency: .weekly,
                duration: 15,
                priorityTag: .medium,
                room: room
            ),
            ChoreDTO(
                name: "Tirar pó sala",
                description: "Passar pano nas superfícies do criado-mudo, cômoda e prateleiras.",
                frequency: .weekly,
                duration: 10,
                priorityTag: .low,
                room: room
            ),
            ChoreDTO(
                name: "Limpar chão",
                description: "Aspirar embaixo da cama, varrer e passar pano no quarto todo.",
                frequency: .weekly,
                duration: 20,
                priorityTag: .medium,
                room: room
            ),
            ChoreDTO(
                name: "Organizar roupas",
                description: "Dobrar e guardar as roupas, separar o que não usa mais.",
                frequency: .monthly,
                duration: 40,
                priorityTag: .low,
                room: room
            )
        ]
    }

    static var livingRoomChores: [ChoreDTO] {
        let room = DefaultRoomsOnboarding.livingRoom.roomDTO
        return [
            ChoreDTO(
                name: "Organizar sala",
                description: "Guardar objetos fora do lugar, ajeitar almofadas e mantas.",
                frequency: .daily,
                duration: 10,
                priorityTag: .low,
                room: room,
                
            ),
            ChoreDTO(
                name: "Tirar o pó",
                description: "Limpar mesa de centro, estantes, quadros e rodapés.",
                frequency: .weekly,
                duration: 15,
                priorityTag: .low,
                room: room
            ),
            ChoreDTO(
                name: "Aspirar móveis",
                description: "Aspirar entre as almofadas do sofá e os tapetes da sala.",
                frequency: .weekly,
                duration: 20,
                priorityTag: .medium,
                room: room
            ),
            ChoreDTO(
                name: "Varrer chão",
                description: "Limpar o piso da sala inteira, incluindo cantos e embaixo dos móveis.",
                frequency: .weekly,
                duration: 20,
                priorityTag: .medium,
                room: room
            ),
            ChoreDTO(
                name: "Limpar eletrônicos",
                description: "Passar pano de microfibra na tela, no rack e nos controles.",
                frequency: .monthly,
                duration: 10,
                priorityTag: .low,
                room: room
            ),
            ChoreDTO(
                name: "Limpar janelas",
                description: "Lavar os vidros e limpar os trilhos das janelas.",
                frequency: .monthly,
                duration: 30,
                priorityTag: .low,
                room: room
            )
        ]
    }

    static var laundryRoomChores: [ChoreDTO] {
        let room = DefaultRoomsOnboarding.laundryRoom.roomDTO
        return [
            ChoreDTO(
                name: "Lavar roupa",
                description: "Separar por cor e tecido e colocar na máquina.",
                frequency: .weekly,
                duration: 30,
                priorityTag: .high,
                room: room
            ),
            ChoreDTO(
                name: "Estender roupa",
                description: "Pendurar no varal e recolher assim que secar.",
                frequency: .weekly,
                duration: 15,
                priorityTag: .medium,
                room: room
            ),
            ChoreDTO(
                name: "Dobrar roupas",
                description: "Dobrar as peças limpas e distribuir nos armários.",
                frequency: .weekly,
                duration: 40,
                priorityTag: .medium,
                room: room
            ),
            ChoreDTO(
                name: "Separar lixo",
                description: "Organizar plástico, papel e vidro e levar para a coleta.",
                frequency: .weekly,
                duration: 10,
                priorityTag: .medium,
                room: room
            ),
            ChoreDTO(
                name: "Limpar tanque",
                description: "Esfregar o tanque, limpar o filtro e a borracha da máquina.",
                frequency: .monthly,
                duration: 20,
                priorityTag: .low,
                room: room
            ),
            ChoreDTO(
                name: "Repor produtos",
                description: "Conferir o estoque, repor o que acabou e arrumar as prateleiras.",
                frequency: .monthly,
                duration: 15,
                priorityTag: .low,
                room: room
            )
        ]
    }

    static var kitchenChores: [ChoreDTO] {
        let room = DefaultRoomsOnboarding.kitchen.roomDTO
        return [
            ChoreDTO(
                name: "Lavar louça",
                description: "Lavar, secar e guardar pratos, panelas e talheres.",
                frequency: .daily,
                duration: 20,
                priorityTag: .high,
                room: room
            ),
            ChoreDTO(
                name: "Limpar bancada",
                description: "Passar pano na pia, na bancada e tirar a gordura do fogão.",
                frequency: .daily,
                duration: 10,
                priorityTag: .high,
                room: room
            ),
            ChoreDTO(
                name: "Tirar lixo",
                description: "Trocar o saco e levar o lixo para fora.",
                frequency: .daily,
                duration: 5,
                priorityTag: .high,
                room: room
            ),
            ChoreDTO(
                name: "Varrer chão",
                description: "Limpar o piso da cozinha, incluindo embaixo da mesa e dos armários.",
                frequency: .weekly,
                duration: 20,
                priorityTag: .medium,
                room: room
            ),
            ChoreDTO(
                name: "Limpar geladeira",
                description: "Descartar alimentos vencidos e higienizar as prateleiras e gavetas.",
                frequency: .monthly,
                duration: 30,
                priorityTag: .medium,
                room: room
            ),
            ChoreDTO(
                name: "Repor despensa",
                description: "Conferir validades, repor o que acabou e reorganizar as prateleiras.",
                frequency: .monthly,
                duration: 25,
                priorityTag: .low,
                room: room
            )
        ]
    }

    static var bathroomChores: [ChoreDTO] {
        let room = DefaultRoomsOnboarding.bathroom.roomDTO
        return [
            ChoreDTO(
                name: "Limpar vaso",
                description: "Escovar por dentro, desinfetar o assento e a parte externa.",
                frequency: .weekly,
                duration: 10,
                priorityTag: .high,
                room: room
            ),
            ChoreDTO(
                name: "Limpar pia",
                description: "Esfregar a cuba, a torneira e deixar o espelho sem manchas.",
                frequency: .weekly,
                duration: 10,
                priorityTag: .medium,
                room: room
            ),
            ChoreDTO(
                name: "Limpar box",
                description: "Tirar o limo dos azulejos e o acúmulo de sabão do vidro do box.",
                frequency: .weekly,
                duration: 20,
                priorityTag: .medium,
                room: room
            ),
            ChoreDTO(
                name: "Trocar toalhas",
                description: "Recolher as toalhas usadas e pendurar as limpas.",
                frequency: .weekly,
                duration: 5,
                priorityTag: .medium,
                room: room
            ),
            ChoreDTO(
                name: "Repor produtos",
                description: "Conferir papel higiênico, sabonete e shampoo e repor o que faltar.",
                frequency: .weekly,
                duration: 5,
                priorityTag: .low,
                room: room
            ),
            ChoreDTO(
                name: "Lavar chão",
                description: "Esfregar o piso com desinfetante e desentupir o ralo.",
                frequency: .monthly,
                duration: 20,
                priorityTag: .low,
                room: room
            )
        ]
    }

    static var homeOfficeChores: [ChoreDTO] {
        let room = DefaultRoomsOnboarding.homeOffice.roomDTO
        return [
            ChoreDTO(
                name: "Organizar mesa",
                description: "Guardar canecas, papéis soltos e deixar a superfície livre.",
                frequency: .daily,
                duration: 5,
                priorityTag: .low,
                room: room
            ),
            ChoreDTO(
                name: "Limpar pc",
                description: "Passar pano de microfibra na tela e tirar a poeira entre as teclas.",
                frequency: .weekly,
                duration: 10,
                priorityTag: .low,
                room: room
            ),
            ChoreDTO(
                name: "Tirar pó",
                description: "Limpar a mesa, as prateleiras e os equipamentos.",
                frequency: .weekly,
                duration: 10,
                priorityTag: .low,
                room: room
            ),
            ChoreDTO(
                name: "Varrer chão",
                description: "Limpar o piso, incluindo embaixo da mesa e da cadeira.",
                frequency: .weekly,
                duration: 15,
                priorityTag: .low,
                room: room
            ),
            ChoreDTO(
                name: "Organizar cabos",
                description: "Prender os cabos soltos e conferir as tomadas e o filtro de linha.",
                frequency: .monthly,
                duration: 20,
                priorityTag: .low,
                room: room
            ),
            ChoreDTO(
                name: "Organizar papeis",
                description: "Arquivar o que é importante e descartar os papéis desnecessários.",
                frequency: .monthly,
                duration: 30,
                priorityTag: .low,
                room: room
            )
        ]
    }
}
