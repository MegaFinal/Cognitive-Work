//
//  ChoreDetailsInfo.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 26/08/26.
//

import SwiftUI

struct ChoreDetailsInfo: View {
    @Bindable var chore: ChoreModel
    @State var room: RoomModel? = nil
    @State var checkList: [CheckItemModel] = []
    
    var width: CGFloat
    var height: CGFloat
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                Text(chore.description)
                    .font(.footnote)
                    .frame(width: width * 0.75, alignment: .leading)
                
                HStack {
                    Text("Cômodo")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text(room?.name ?? "Unnamed room")
                        .font(.footnote)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(room?.color.uiColor ?? .gray)
                        .clipShape(Capsule())
                        .foregroundColor(.white)
                }
                
                Text("Checklist")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                VStack(alignment: .leading, spacing: 5) {
                    ForEach($checkList, id: \.id) { $item in
                        ChecklistItemButton(item: $item)
                    }
                }
            }
        }
        .task {
            room = await chore.room
            checkList = await chore.checkList
        }
        .frame(width: width * 0.75, height: height * 0.24)
        .padding(.top)
    }
}
