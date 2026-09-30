//
//  NewRoomSheet.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 24/08/26.
//

import SwiftUI

/// A sheet that lets the user define a custom room with a name and accent color
///
/// Presented from ``FourthOnboardingView`` when the user taps "+" card
///
/// The user enters a name, picks a color via ``CustomColorPicker``, and confirms
/// with the checkmark toolbar button
///
/// The confirm button is disabled while the name field is empty
struct NewRoomSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(OnboardingViewModel.self) var viewModel
    
    @State private var text = ""
    @State private var selectedColor: RoomColor = .yellow
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                ZStack {
                    Image(systemName: "lamp.table")
                        .resizable()
                        .scaledToFit()
                        .frame(width: width * 0.2, height: height * 0.1)
                        .foregroundColor(.black)
                }
                .frame(width: width * 0.42, height: height * 0.2)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .foregroundColor(selectedColor.uiColor)
                )
                
                VStack {
                    TextField("Nome do Cômodo", text: $text)
                        .characterLimit(TextLimits.roomName, text: $text)
                        .submitLabel(.done)
                        .frame(width: width * 0.75)
                        .font(.system(size: 34))
                        .bold()
                        .multilineTextAlignment(.center)
                    
                    Rectangle()
                        .frame(width: width * 0.75, height: height * 0.001)
                }
                
                HStack(spacing: 25) {
                    ForEach(RoomColor.allCases) { color in
                        CustomColorPicker(
                            item: color,
                            isSelected: selectedColor == color
                        ) {
                            withAnimation(.spring) {
                                selectedColor = color
                            }
                        }
                    }
                }
                
                Spacer()
            }
            .navigationTitle("Outro Cômodo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    ConfirmToolbarButton(isDisabled: text.trimmingCharacters(in: .whitespaces).isEmpty) {
                        viewModel.addCustomRoom(name: text.trimmingCharacters(in: .whitespaces), color: selectedColor)
                        dismiss()
                    }
                }
            }
            .dismissKeyboardOnTap()
        }
    }
}

// MARK: - Private subviews

/// A single color swatch used to pick a room's accent color.
///
/// Renders as a filled circle in ``item``'s color, with a blue selection ring.
private struct CustomColorPicker: View {
    let item: RoomColor
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Circle()
            .fill(item.uiColor)
            .frame(width: 34, height: 34)
            .overlay {
                if isSelected {
                    Circle()
                        .stroke(.blue, lineWidth: 2.5)
                        .padding(-3)
                }
            }
            .onTapGesture(perform: action)
    }
}

#Preview {
    NewRoomSheet()
        .environment(OnboardingViewModel())
}
