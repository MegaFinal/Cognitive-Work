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
    case livingRoom = "Sala de estar"
    case laundryRoom = "Área de serviço"
    case kitchen = "Cozinha"
    case bathroom = "Banheiro"
    case homeOffice = "Escritório"

    // MARK: - Identity

    /// Stable identity used by `ForEach` and `Picker`.
    var id: String { rawValue }

    // MARK: - Default Chores

    /// Chores suggested for this room during onboarding.
    ///
    /// > Important: ``ChoreDTO`` is a reference type, so every access builds a
    /// > brand new batch of instances. Store the result once (in the view model
    /// > or in `@State`) instead of calling this inside `body`, otherwise the
    /// > toggles reset on each redraw.
    var defaultChores: [ChoreDTO] {
        switch self {
        case .bedroom: DefaultRoomsOnboarding.bedroomChores
        case .livingRoom: DefaultRoomsOnboarding.livingRoomChores
        case .laundryRoom: DefaultRoomsOnboarding.laundryRoomChores
        case .kitchen: DefaultRoomsOnboarding.kitchenChores
        case .bathroom: DefaultRoomsOnboarding.bathroomChores
        case .homeOffice: DefaultRoomsOnboarding.homeOfficeChores
        }
    }
}

// MARK: - Chore Catalog

private extension DefaultRoomsOnboarding {

    static var bedroomChores: [ChoreDTO] {
        [
            ChoreDTO(
                name: "Arrumar a cama",
                description: "Esticar o lençol, ajeitar o edredom e os travesseiros.",
                frequency: .daily,
                duration: 5,
                priorityTag: .low
            ),
            ChoreDTO(
                name: "Trocar a roupa de cama",
                description: "Trocar lençol, fronhas e capa do edredom e levar o usado para lavar.",
                frequency: .weekly,
                duration: 15,
                priorityTag: .medium
            ),
            ChoreDTO(
                name: "Tirar o pó dos móveis",
                description: "Passar pano nas superfícies do criado-mudo, cômoda e prateleiras.",
                frequency: .weekly,
                duration: 10,
                priorityTag: .low
            ),
            ChoreDTO(
                name: "Aspirar e limpar o chão",
                description: "Aspirar embaixo da cama, varrer e passar pano no quarto todo.",
                frequency: .weekly,
                duration: 20,
                priorityTag: .medium
            ),
            ChoreDTO(
                name: "Organizar o guarda-roupa",
                description: "Dobrar e guardar as roupas, separar o que não usa mais.",
                frequency: .monthly,
                duration: 40,
                priorityTag: .low
            )
        ]
    }

    static var livingRoomChores: [ChoreDTO] {
        [
            ChoreDTO(
                name: "Organizar a sala",
                description: "Guardar objetos fora do lugar, ajeitar almofadas e mantas.",
                frequency: .daily,
                duration: 10,
                priorityTag: .low
            ),
            ChoreDTO(
                name: "Tirar o pó",
                description: "Limpar mesa de centro, estantes, quadros e rodapés.",
                frequency: .weekly,
                duration: 15,
                priorityTag: .low
            ),
            ChoreDTO(
                name: "Aspirar sofá e tapetes",
                description: "Aspirar entre as almofadas do sofá e os tapetes da sala.",
                frequency: .weekly,
                duration: 20,
                priorityTag: .medium
            ),
            ChoreDTO(
                name: "Varrer e passar pano no chão",
                description: "Limpar o piso da sala inteira, incluindo cantos e embaixo dos móveis.",
                frequency: .weekly,
                duration: 20,
                priorityTag: .medium
            ),
            ChoreDTO(
                name: "Limpar TV e eletrônicos",
                description: "Passar pano de microfibra na tela, no rack e nos controles.",
                frequency: .monthly,
                duration: 10,
                priorityTag: .low
            ),
            ChoreDTO(
                name: "Limpar janelas e vidros",
                description: "Lavar os vidros e limpar os trilhos das janelas.",
                frequency: .monthly,
                duration: 30,
                priorityTag: .low
            )
        ]
    }

    static var laundryRoomChores: [ChoreDTO] {
        [
            ChoreDTO(
                name: "Lavar a roupa",
                description: "Separar por cor e tecido e colocar na máquina.",
                frequency: .weekly,
                duration: 30,
                priorityTag: .high
            ),
            ChoreDTO(
                name: "Estender e recolher a roupa",
                description: "Pendurar no varal e recolher assim que secar.",
                frequency: .weekly,
                duration: 15,
                priorityTag: .medium
            ),
            ChoreDTO(
                name: "Dobrar e guardar a roupa",
                description: "Dobrar as peças limpas e distribuir nos armários.",
                frequency: .weekly,
                duration: 40,
                priorityTag: .medium
            ),
            ChoreDTO(
                name: "Separar o lixo reciclável",
                description: "Organizar plástico, papel e vidro e levar para a coleta.",
                frequency: .weekly,
                duration: 10,
                priorityTag: .medium
            ),
            ChoreDTO(
                name: "Limpar o tanque e a máquina",
                description: "Esfregar o tanque, limpar o filtro e a borracha da máquina.",
                frequency: .monthly,
                duration: 20,
                priorityTag: .low
            ),
            ChoreDTO(
                name: "Organizar produtos de limpeza",
                description: "Conferir o estoque, repor o que acabou e arrumar as prateleiras.",
                frequency: .monthly,
                duration: 15,
                priorityTag: .low
            )
        ]
    }

    static var kitchenChores: [ChoreDTO] {
        [
            ChoreDTO(
                name: "Lavar a louça",
                description: "Lavar, secar e guardar pratos, panelas e talheres.",
                frequency: .daily,
                duration: 20,
                priorityTag: .high
            ),
            ChoreDTO(
                name: "Limpar a bancada e o fogão",
                description: "Passar pano na pia, na bancada e tirar a gordura do fogão.",
                frequency: .daily,
                duration: 10,
                priorityTag: .high
            ),
            ChoreDTO(
                name: "Tirar o lixo",
                description: "Trocar o saco e levar o lixo para fora.",
                frequency: .daily,
                duration: 5,
                priorityTag: .high
            ),
            ChoreDTO(
                name: "Varrer e passar pano no chão",
                description: "Limpar o piso da cozinha, incluindo embaixo da mesa e dos armários.",
                frequency: .weekly,
                duration: 20,
                priorityTag: .medium
            ),
            ChoreDTO(
                name: "Limpar a geladeira",
                description: "Descartar alimentos vencidos e higienizar as prateleiras e gavetas.",
                frequency: .monthly,
                duration: 30,
                priorityTag: .medium
            ),
            ChoreDTO(
                name: "Organizar a despensa",
                description: "Conferir validades, repor o que acabou e reorganizar as prateleiras.",
                frequency: .monthly,
                duration: 25,
                priorityTag: .low
            )
        ]
    }

    static var bathroomChores: [ChoreDTO] {
        [
            ChoreDTO(
                name: "Limpar o vaso sanitário",
                description: "Escovar por dentro, desinfetar o assento e a parte externa.",
                frequency: .weekly,
                duration: 10,
                priorityTag: .high
            ),
            ChoreDTO(
                name: "Limpar a pia e o espelho",
                description: "Esfregar a cuba, a torneira e deixar o espelho sem manchas.",
                frequency: .weekly,
                duration: 10,
                priorityTag: .medium
            ),
            ChoreDTO(
                name: "Limpar o box e o chuveiro",
                description: "Tirar o limo dos azulejos e o acúmulo de sabão do vidro do box.",
                frequency: .weekly,
                duration: 20,
                priorityTag: .medium
            ),
            ChoreDTO(
                name: "Trocar as toalhas",
                description: "Recolher as toalhas usadas e pendurar as limpas.",
                frequency: .weekly,
                duration: 5,
                priorityTag: .medium
            ),
            ChoreDTO(
                name: "Repor papel e produtos de higiene",
                description: "Conferir papel higiênico, sabonete e shampoo e repor o que faltar.",
                frequency: .weekly,
                duration: 5,
                priorityTag: .low
            ),
            ChoreDTO(
                name: "Lavar o chão e limpar o ralo",
                description: "Esfregar o piso com desinfetante e desentupir o ralo.",
                frequency: .monthly,
                duration: 20,
                priorityTag: .low
            )
        ]
    }

    static var homeOfficeChores: [ChoreDTO] {
        [
            ChoreDTO(
                name: "Organizar a mesa",
                description: "Guardar canecas, papéis soltos e deixar a superfície livre.",
                frequency: .daily,
                duration: 5,
                priorityTag: .low
            ),
            ChoreDTO(
                name: "Limpar teclado e monitor",
                description: "Passar pano de microfibra na tela e tirar a poeira entre as teclas.",
                frequency: .weekly,
                duration: 10,
                priorityTag: .low
            ),
            ChoreDTO(
                name: "Tirar o pó dos móveis",
                description: "Limpar a mesa, as prateleiras e os equipamentos.",
                frequency: .weekly,
                duration: 10,
                priorityTag: .low
            ),
            ChoreDTO(
                name: "Varrer e aspirar o chão",
                description: "Limpar o piso, incluindo embaixo da mesa e da cadeira.",
                frequency: .weekly,
                duration: 15,
                priorityTag: .low
            ),
            ChoreDTO(
                name: "Organizar cabos e fios",
                description: "Prender os cabos soltos e conferir as tomadas e o filtro de linha.",
                frequency: .monthly,
                duration: 20,
                priorityTag: .low
            ),
            ChoreDTO(
                name: "Organizar documentos",
                description: "Arquivar o que é importante e descartar os papéis desnecessários.",
                frequency: .monthly,
                duration: 30,
                priorityTag: .low
            )
        ]
    }
}
