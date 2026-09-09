//
//  ChoreDetailsCard.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 18/08/26.
//

import SwiftUI
import UIKit
import CloudKit

/// Represents the detailed back-face view of a chore card.
///
/// This view is revealed when the user flips or taps a card, providing full details, checklist progress,
/// postponement actions, and a completion swipe toggle.
struct ChoreDetailsCard: View {
    
    /// The room associated with the current chore.
    @State var room: RoomModel? = nil
    
    /// All users designated as responsible for this chore.
    @State var allResponsibleUsers: [UserModel] = []
    
    /// The sub-items defining the chore's checklist.
    @State private var checkList: [CheckItemModel] = []
    
    /// The core data model of the chore being displayed.
    @Bindable var chore: ChoreModel
    
    /// The view model governing the carousel's state.
    @Bindable var carouselViewModel: CarouselViewModel
    
    var width = UIScreen.main.bounds.width
    var height = UIScreen.main.bounds.height
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                header
                
                info
                
                VStack {
                    postponeButtons
                    
                    SwipeToCompleteButton(action:  {
                        Task {
                            await chore.toggle()
                        }
                    }, color: room?.color.uiColor ?? .gray)
                    .padding(.horizontal, 30)
                }
            }
            .padding(.top, 8)
            
            actionBar
        }
        .task {
            room = await chore.room
            allResponsibleUsers = await chore.allResponsibleUsers
            checkList = await chore.checkList
        }
        .frame(width: width * 0.88, height: height * 0.599)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 31))
        .shadow(color: .black.opacity(0.14), radius: 20.39595, x: 0, y: 5.80668)
    }
    
    // MARK: - Subviews
    
    /// The upper header section: the chore's primary icon, name, and status tags.
    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: chore.symbolName)
                .resizable()
                .scaledToFit()
                .frame(width: width * 0.19, height: height * 0.09)
                .fontWeight(.thin)
            
            Text(chore.name)
                .font(.title)
                .fontWeight(.semibold)
            
            HStack(spacing: 12) {
                CapsuleTag(
                    tagName: chore.priorityTag.rawValue,
                    tagColor: chore.priorityTag.color,
                    horizontalPadding: 10.0,
                    verticalPadding: 1.5
                )
                
                CapsuleTag(
                    tagName: ChoreDurationTier.from(minutes: chore.duration / 60).displayText,
                    tagColor: ChoreDurationTier.from(minutes: chore.duration / 60).color,
                    horizontalPadding: 10.0,
                    verticalPadding: 1.5
                )
                
                CapsuleTag(
                    tagName: chore.frequency.rawValue,
                    tagColor: chore.frequency.color,
                    horizontalPadding: 10.0,
                    verticalPadding: 1.5
                )
            }
        }
        .foregroundColor(.black)
    }
    
    /// The central information scroll view: description, room tag and the interactive checklist.
    private var info: some View {
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
        .frame(width: width * 0.75, height: height * 0.24)
        .padding(.top)
    }
    
    /// Quick actions to delay the chore's deadline directly from the details card.
    private var postponeButtons: some View {
        HStack {
            Button {
                Task {
                    await chore.postpone(byDays: 7)
                }
            } label: {
                Text("Adiar 1 semana")
                    .font(.footnote)
                    .foregroundColor(.black)
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 10)
            .background(.gray.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 22))
            
            Spacer()
            
            Button {
                Task {
                    await chore.postpone(byDays: 1)
                }
            } label: {
                Text("Adiar 1 dia")
                    .font(.footnote)
                    .foregroundColor(.black)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 10)
            .background(.gray.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 22))
        }
        .padding(.top, 10)
        .frame(width: width * 0.72)
    }
    
    /// Floating top bar with dismiss, responsible avatars and the edit shortcut.
    private var actionBar: some View {
        HStack {
            Button {
                carouselViewModel.clearFocus()
            } label: {
                Image(systemName: "xmark")
                    .foregroundColor(.black)
            }
            .padding(12)
            .clipShape(Circle())
            .glassEffect()
            
            Spacer()
            
            if allResponsibleUsers.count == 1 {
                UserProfilePictureTag(user: allResponsibleUsers.first, widthMultiplier: 0.1)
            } else {
                UserProfilePictureList(chore: chore, widthMultiplier: 0.1)
            }
            
            NavigationLink {
                CreateAndEditChoreView(
                    originalModel: chore,
                    availableHouseUsers: allResponsibleUsers
                )
            } label: {
                Image(systemName: "pencil")
                    .foregroundColor(.white)
            }
            .padding(12)
            .background(.blue)
            .clipShape(Circle())
            .glassEffect()
        }
        .padding(.horizontal)
        .padding(.top)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

// MARK: - Private subviews

/// A button representing a single, actionable checklist item.
///
/// Tap interactions directly instruct the `CheckItemModel` to asynchronously toggle its completion state.
private struct ChecklistItemButton: View {
    
    /// The checklist item model corresponding to this entry.
    @Binding var item: CheckItemModel
    
    var body: some View {
        Button {
            Task {
                await item.toggle()
            }
        } label: {
            HStack {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(item.isDone ? .black : .gray)
                    .font(.headline)
                
                Text(item.name)
                    .strikethrough(item.isDone, color: .gray)
                    .foregroundColor(item.isDone ? .gray : .black)
                    .font(.footnote)
                    .multilineTextAlignment(.leading)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Mock class for preview
fileprivate class MockChoreModel: ChoreModel {
    var mockUsers: [UserModel] = []
    var mockChecklist: [CheckItemModel] = []
    var mockRoom: RoomModel? = nil
    
    override var allResponsibleUsers: [UserModel] { get async { mockUsers } }
    override var checkList: [CheckItemModel] { get async { mockChecklist } }
    override var room: RoomModel? { get async { mockRoom } }
}

//#Preview("UserChoresView") {
//    let mockImageData = UIImage(named: "defaultUser")?.pngData()
//    //TODO: Make preview work again, profilePicture now is a CKAsset
//    let user1 = UserModel(name: "Dayô", profilePicture: nil, tier: .tier1)
//    let user2 = UserModel(name: "João", profilePicture: nil, tier: .tier2)
//    
//    let room1 = RoomModel(name: "Banheiro", color: .blue)
//    
//    let chore1 = MockChoreModel(
//        name: "Lavar o Banheiro",
//        description: "Esfregar o chão do box, limpar os espelhos com limpa-vidros, lavar a pia e o vaso sanitário. Não esquecer de repor o papel higiênico e esvaziar a lixeira no final.",
//        isDone: false, frequency: .weekly, duration: 1800, isPublic: true, priorityTag: .urgent
//    )
//    chore1.symbolName = "toilet"
//    chore1.mockUsers = [user1, user2]
//    chore1.mockChecklist = [
//        CheckItemModel(name: "Lavar o vaso sanitário", isDone: true),
//        CheckItemModel(name: "Limpar o espelho sem manchas", isDone: false),
//        CheckItemModel(name: "Esvaziar a lixeira", isDone: false)
//    ]
//    chore1.mockRoom = room1
//    let carousel = CarouselViewModel()
//    
//    ChoreDetailsCard(chore: chore1, carouselViewModel: carousel)
//}
