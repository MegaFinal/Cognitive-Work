//
//  TagPicker.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 28/08/26.
//

import SwiftUI
import CloudKit

struct TagPicker: View {
    @Bindable var chore: ChoreDTO
    var type: TagPickerType
    
    var availableRooms: [RoomModel] = []
    
    @State private var currentRoom: RoomModel? = nil
    
    var body: some View {
        Menu {
            switch type {
            case .priority:
                Picker("Prioridade", selection: $chore.priorityTag) {
                    ForEach(PriorityTag.allCases, id: \.self) { tag in
                        ColorIconTagLabel(title: tag.rawValue.capitalized, color: tag.color)
                            .tag(tag)
                    }
                }
                
            case .frequency:
                Picker("Frequência", selection: $chore.frequency) {
                    ForEach(Recurrence.allCases, id: \.self) { freq in
                        ColorIconTagLabel(title: freq.rawValue.capitalized, color: freq.color)
                            .tag(freq)
                    }
                }
                
            case .duration:
                Picker("Duração", selection: durationTierBinding) {
                    ForEach(ChoreDurationTier.allCases, id: \.self) { tier in
                        ColorIconTagLabel(title: tier.displayText.capitalized, color: tier.color)
                            .tag(tier)
                    }
                }
                
            case .room:
                Picker("Cômodo", selection: $currentRoom) {
                    Text("Sem Cômodo").tag(RoomModel?(nil))
                    
                    ForEach(availableRooms, id: \.self) { room in
                        ColorIconTagLabel(title: room.name.capitalized, color: room.color.uiColor)
                            .tag(RoomModel?(room))
                    }
                }
            }
        } label: {
            HStack {
                CapsuleTag(
                    tagName: type.labelName(for: chore, currentRoom: currentRoom),
                    tagColor: type.labelColor(for: chore, currentRoom: currentRoom)
                )
                
                Image(systemName: "chevron.up.chevron.down")
                    .foregroundColor(.black)
                    .imageScale(.small)
            }
        }
        .task {
            if type == .room, let roomReference = chore.roomReference {
                currentRoom = await CloudKitManager.shared
                    .fetchRecordsByRecordReference(for: RoomModel.self, recordReferences: [roomReference])?
                    .first
            }
        }
        .onChange(of: currentRoom) { _, newRoom in
            if let recordID = newRoom?.recordID {
                chore.roomReference = CKRecord.Reference(recordID: recordID, action: .none)
            } else {
                chore.roomReference = nil
            }
        }
    }
    
    private var durationTierBinding: Binding<ChoreDurationTier> {
        Binding(
            get: {
                let minutes = chore.duration / 60
                return ChoreDurationTier.from(minutes: minutes)
            },
            set: { newTier in
                switch newTier {
                case .muitoRapido: chore.duration = 5 * 60
                case .rapido: chore.duration = 15 * 60
                case .moderado: chore.duration = 30 * 60
                case .demorado: chore.duration = 60 * 60
                case .muitoDemorado: chore.duration = 120 * 60
                }
            }
        )
    }
}

extension UIImage {
    static func coloredCircle(color: Color) -> UIImage {
        let uiColor = UIColor(color)
        let size = CGSize(width: 24, height: 24)
        
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        uiColor.setFill()
        let rect = CGRect(x: 5, y: 5, width: 14, height: 14)
        UIBezierPath(ovalIn: rect).fill()
        
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image ?? UIImage()
    }
}
