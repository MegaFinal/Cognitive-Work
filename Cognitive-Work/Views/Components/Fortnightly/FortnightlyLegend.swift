//
//  DashboarLegend.swift
//  Cognitive-Work
//
//  Created by anshu Li on 24/08/26.
//

import SwiftUI
import CloudKit

struct FortnightlyLegend: View {
    let users: [UserModel]

    var body: some View {
        HStack {
            ForEach(Array(users.enumerated()), id: \.offset) { index, user in
                FortnightlyLegendEntry(
                    userColor: UserColorPalette.color(for: index),
                    userName: user.name
                )
            }
        }
    }
}

#Preview {
    FortnightlyLegend(users: [
        UserModel(name: "Você", tier: .tier1),
        UserModel(name: "Alice", tier: .tier1),
        UserModel(name: "Bob", tier: .tier1),
        UserModel(name: "Carol", tier: .tier1)
    ])
}
