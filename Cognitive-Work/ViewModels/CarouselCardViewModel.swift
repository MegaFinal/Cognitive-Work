//
//  CarouselCardViewModel.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 18/08/26.
//

import SwiftUI
import CloudKit

/// The view model for a single flippable card in the chore carousel
///
/// Each `CarouselCardViewModel` wraps one ``ChoreModel`` and holds the presentation
/// state needed to render its card — whether it is showing its front or back face,
/// and the resolved display data (room name/color, responsible user's avatar) that is
/// lazily fetched from CloudKit via ``fetchRoomDependencies()`` and
/// ``fetchUserDependencies()``.
@Observable
class CarouselCardViewModel: Identifiable {
    let id = UUID()
    
    /// The chore this card represents
    var chore: ChoreModel
    
    /// Whether the card is currently flipped to show its back face
    var isShowingBack: Bool = false
    /// Whether a dependency fetch (room or user) is currently in progress
    var isLoadingDependencies: Bool = false
    
    /// The display name of the chore's room, resolved from CloudKit
    var roomName: String = "Nome do Cômodo"
    /// The accent color associated with the chore's room
    var roomColor: Color = .gray
    /// The profile image of the user currently responsible for the chore, if resolved
    var profileImage: Image? = nil
    
    var cardSymbol: String = "bus"
    
    /// Creates a card view model wrapping the given chore
    ///
    /// - Parameter chore: The chore to display on this card
    init(chore: ChoreModel) {
        self.chore = chore
    }
    
    /// Toggles the card between its front and back faces
    func flip() {
        isShowingBack.toggle()
    }
    
    /// Fetches the `RoomModel` referenced by ``chore``'s room, if any
    ///
    /// Does nothing and returns `nil` if a dependency fetch is already in progress
    /// If the chore has no associated room reference, ``roomName`` is set to a
    /// "room not found" placeholder instead of performing a fetch
    ///
    /// - Returns: The resolved ``RoomModel``, or `nil` if the chore has no room
    ///   reference, the fetch fails, or a fetch was already in progress
    func fetchRoomDependencies() async -> RoomModel? {
        guard !isLoadingDependencies else { return nil }
        
        await MainActor.run { isLoadingDependencies = true }
        
        if chore.room != nil {
            return await CloudKitManager.shared.fetchRecordsByRecordReference(for: RoomModel.self, recordReferences: [chore.room!])?.first
        } else {
            await MainActor.run { self.roomName = "Cômodo não encontrado" }
        }
        
        await MainActor.run { isLoadingDependencies = false }
        return nil
    }
    
    /// Fetches the `UserModel` currently responsible for ``chore``, if any
    ///
    /// Does nothing and returns `nil` if a dependency fetch is already in progress.
    /// If the chore has no current responsible user reference, ``roomName`` is set to
    /// a "user not found" placeholder instead of performing a fetch.
    ///
    /// - Returns: The resolved ``UserModel``, or `nil` if the chore has no
    ///   responsible-user reference, the fetch fails, or a fetch was already in progress.
    func fetchUserDependencies() async -> UserModel? {
        guard !isLoadingDependencies else { return nil }
        
        await MainActor.run { isLoadingDependencies = true }
        
        if chore.currentResponsible != nil {
            return await CloudKitManager.shared.fetchRecordsByRecordReference(for: UserModel.self, recordReferences: [chore.currentResponsible!])?.first
        } else {
            await MainActor.run { self.roomName = "User não encontrado" }
        }
        
        await MainActor.run { isLoadingDependencies = false }
        return nil
    }
    
    // MARK: - Mocks for preview
    
    /// Builds a populated view model for SwiftUI previews, bypassing CloudKit fetches
    ///
    /// - Parameters:
    ///   - chore: The chore to display on the mock card
    ///   - roomName: The room name to show directly, without fetching
    ///   - color: The room accent color to show directly
    ///   - imageName: An SF Symbol name used in place of a fetched profile image
    /// - Returns: A ``CarouselCardViewModel`` populated with the given preview data
    static func mock(
        chore: ChoreModel,
        roomName: String,
        color: Color,
        imageName: String
    ) -> CarouselCardViewModel {
        let vm = CarouselCardViewModel(chore: chore)
        vm.roomName = roomName
        vm.roomColor = color
        vm.profileImage = Image(systemName: imageName)
        return vm
    }
}
