//
//  ChoreCardTitle.swift
//  Cognitive-Work
//
//  Created by anshu Li on 25/08/26.
//

import SwiftUI

struct ChoreCardTitle: View {
    let choreName: String
    let roomName: String

    var body: some View {
        VStack {
            Text(roomName)
                .fontWeight(.regular)
                .font(.headline)
            Text(choreName)
                .bold()
                .font(.title)
        }
    }
}

#Preview {
    ChoreCardTitle(choreName: "Lavar banheiro", roomName: "Banheiro da suíte")
}
