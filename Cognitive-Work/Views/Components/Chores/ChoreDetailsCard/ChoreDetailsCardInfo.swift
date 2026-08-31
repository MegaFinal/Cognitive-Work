//
//  ChoreDetailsCardInfo.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 26/08/26.
//

import SwiftUI

/// The central information scroll view of the `ChoreDetailsCard`.
///
/// Contains the textual description of the chore, the associated room tag, and the interactive checklist.
struct ChoreDetailsCardInfo: View {
    
    /// The core data model of the chore being displayed.
    @Bindable var chore: ChoreModel
    
    /// The room associated with the current chore.
    @State var room: RoomModel? = nil
    
    /// The sub-items defining the chore's checklist.
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
                    
                    CapsuleTag(
                        tagName: room?.name ?? "Unnamed room",
                        tagColor: room?.color.uiColor ?? .gray,
                        horizontalPadding: 10.0,
                        verticalPadding: 1.5
                    )
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
