//
//  ChoreTagPicker.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 28/08/26.
//

import SwiftUI
import CloudKit

/// A menu-based picker configured to select core attributes associated with a chore.
struct ChoreTagPicker: View {
    
    /// The mutable configuration state governing the selected options.
    @Binding var chore: ChoreDTO
    
    /// Defines the attribute mode this picker will govern.
    var type: TagPickerType
    
    /// Internal collection utilized exclusively when the type maps to `.room`.
    var availableRooms: [RoomModel] = []
    
    /// Selected contextual room model derived from the `chore.roomReference`.
    @State private var currentRoom: RoomModel? = nil
    
    var body: some View {
        Menu {
            switch type {
            case .priority:
                Picker("Prioridade", selection: $chore.priorityTag) {
                    ForEach(PriorityTag.allCases.filter { $0 != .undefined }, id: \.self) { tag in
                        ColorIconTagLabel(title: tag.displayName, color: tag.color)
                            .tag(tag)
                    }
                }
                
            case .frequency:
                Picker("Frequência", selection: $chore.frequency) {
                    ForEach(Recurrence.allCases.filter { $0 != .undefined }, id: \.self) { freq in
                        ColorIconTagLabel(title: freq.displayName, color: freq.color)
                            .tag(freq)
                    }
                }
                
            case .duration:
                Picker("Duração", selection: durationTierBinding) {
                    ForEach(ChoreDurationTier.allCases.filter { $0 != .undefined }, id: \.self) { tier in
                        ColorIconTagLabel(title: tier.displayText, color: tier.color)
                            .tag(tier)
                    }
                }
            }
        } label: {
            HStack {
                CapsuleTag(
                    tagName: type.labelName(for: chore, currentRoom: currentRoom),
                    tagColor: type.labelColor(for: chore, currentRoom: currentRoom),
                    textColor: type.labelTextColor(for: chore),
                    horizontalPadding: 10.0,
                    verticalPadding: 1.5
                )
                
                Image(systemName: "chevron.up.chevron.down")
                    .foregroundColor(.black)
                    .imageScale(.small)
            }
        }
        .onChange(of: currentRoom) { _, newRoom in
            if let recordID = newRoom?.recordID {
                chore.roomReference = CKRecord.Reference(recordID: recordID, action: .none)
            } else {
                chore.room = nil
            }
        }
    }
    
    /// Maps raw numerical duration intervals into standard UX tiers for editing purposes.
    private var durationTierBinding: Binding<ChoreDurationTier> {
        Binding(
            get: {
                let minutes = chore.duration / 60
                return ChoreDurationTier.from(minutes: minutes)
            },
            set: { newTier in
                switch newTier {
                case .quick: chore.duration = 15 * 60
                case .moderate: chore.duration = 30 * 60
                case .slow: chore.duration = 60 * 60
                case .verySlow: chore.duration = 120 * 60
                case .undefined: chore.duration = 0
                }
            }
        )
    }
}

/// A UI label paired with a custom-rendered colored circular icon.
///
/// Used inside the picker menus to represent tagged properties visually.
private struct ColorIconTagLabel: View {
    
    /// The string to be displayed next to the icon.
    let title: String
    
    /// The background color for the circular icon shape.
    let color: Color
    
    var body: some View {
        Label {
            Text(title)
        } icon: {
            Image(uiImage: .coloredCircle(color: color))
                .renderingMode(.original)
        }
    }
}

extension UIImage {
    /// Dynamically constructs an image rendering a colored circle for icon substitution.
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
