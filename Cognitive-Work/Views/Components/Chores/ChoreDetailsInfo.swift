//
//  ChoreDetailsInfo.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 26/08/26.
//

import SwiftUI

struct ChoreDetailsInfo: View {
    @Bindable var viewModel: ChoreViewModel
    var width: CGFloat
    var height: CGFloat
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text(viewModel.chore.description)
                .font(.caption2)
                .frame(width: width * 0.75, alignment: .leading)
            
            HStack {
                Text("Cômodo")
                    .font(.footnote)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text(viewModel.roomName)
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(viewModel.roomColor)
                    .clipShape(Capsule())
            }
            
            Text("Checklist")
                .font(.footnote)
                .fontWeight(.medium)
            
            VStack(alignment: .leading) {
                ForEach($viewModel.checklistItems, id: \.id) { $item in
                    ChecklistItemButton(item: $item)
                }
            }
            
            HStack {
                Text("Responsáveis")
                    .font(.footnote)
                    .fontWeight(.medium)
                
                Spacer()
                
                ForEach($viewModel.responsibleUsers, id: \.id) { $user in
                    UserProfilePictureTag(user: $user)
                }
            }
        }
        .frame(width: width * 0.75)
    }
}
