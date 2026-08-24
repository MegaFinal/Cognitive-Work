//
//  DashboardLegendEntry.swift
//  Cognitive-Work
//
//  Created by anshu Li on 24/08/26.
//

import SwiftUI

struct FortnightlyLegendEntry: View {
    var userColor: Color
    var userName: String
    
    var body: some View {
        HStack{
            Circle()
                .frame(width: 14)
                .foregroundStyle(userColor)
            
            Text(userName)
                .font(.system(size: 15))
                .fontWeight(.light)
        }
    }
}

#Preview {
    FortnightlyLegendEntry(userColor: .gray, userName: "Você")
}
