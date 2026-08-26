//
//  CheckItemButton.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 25/08/26.
//

import SwiftUI

struct ChecklistItemButton: View {
    @Binding var item: CheckItemModel
    var width = UIScreen.main.bounds.width
        
    var body: some View {
        Button {
            item.isDone.toggle()
            
        } label: {
            HStack {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(item.isDone ? .green : .gray)
                    .font(.headline)
                
                Text(item.name)
                    .strikethrough(item.isDone, color: .gray)
                    .foregroundColor(item.isDone ? .gray : .black)
                    .font(.caption)
                    .multilineTextAlignment(.leading)
            }
        }
        .buttonStyle(.plain)
    }
}
