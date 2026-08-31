//
//  ChecklistSection.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 30/08/26.
//

import SwiftUI

struct ChecklistSection: View {
    @Bindable var choreDTO: ChoreDTO
    let width: CGFloat
    
    var body: some View {
        VStack {
            HStack {
                Text("Checklist")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Toggle("", isOn: $choreDTO.hasChecklist)
                    .toggleStyle(.switch)
                    .onChange(of: choreDTO.hasChecklist) { _, isOn in
                        if isOn && choreDTO.checklist.isEmpty {
                            choreDTO.checklist.append(CheckItemDTO(name: "", isDone: false))
                        }
                    }
                    .padding(.trailing, 3)
            }
            .frame(width: width * 0.9)

            if choreDTO.hasChecklist {
                CheckListCreateAndEdit(hasChecklist: $choreDTO.hasChecklist, localChecklist: $choreDTO.checklist)
            }
        }
    }
}
