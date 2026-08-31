//
//  CreateAndEditChoreView.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 28/08/26.
//

import SwiftUI
import CloudKit

struct CreateAndEditChoreView: View {

    /// Persisted chore being edited, or an unsaved chore when creating a new one.
    var originalModel: ChoreModel

    /// Every user in the house
    @State var availableHouseUsers: [UserModel]

    /// Copy of the chore's editable fields
    @State private var choreDTO = ChoreDTO()
    
    /// Determines if the user is trying to save the changes.
    @State private var isSaving = false

    @Environment(\.dismiss) private var dismiss

    var width = UIScreen.main.bounds.width
    var height = UIScreen.main.bounds.height
    
    // MARK: - Main Body
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 25) {
                CreateAndEditChoreHeader(chore: choreDTO)

                VStack(spacing: 10) {
                    HStack {
                        Text("Prioridade")
                        Spacer()
                        ChoreTagPicker(chore: choreDTO, type: .priority)
                    }

                    HStack {
                        Text("Duração")
                        Spacer()
                        ChoreTagPicker(chore: choreDTO, type: .duration)
                    }

                    HStack {
                        Text("Frequência")
                        Spacer()
                        ChoreTagPicker(chore: choreDTO, type: .frequency)
                    }
                }
                .font(.subheadline)
                .fontWeight(.semibold)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Descrição")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    TextField("Descrição da Tarefa", text: $choreDTO.description, axis: .vertical)
                        .font(.body)
                        .foregroundColor(.gray)
                }

                ChecklistSection(choreDTO: choreDTO, width: width)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Responsáveis")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    ResponsibleUserPicker(availableUsers: availableHouseUsers, selectedUsers: $choreDTO.responsibleUsers)
                }

                PublicToggleSection(choreDTO: choreDTO, width: width)

                Spacer()

                ConfirmButtonSection(
                    isSaving: isSaving,
                    isDisabled: choreDTO.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving,
                    width: width,
                    height: height,
                    action: {
                        Task { await confirmAndSave() }
                    }
                )
            }
            .padding(.vertical)
            .frame(width: width * 0.9)
        }
        .task {
            await loadDraftIfNeeded()
        }
    }
    
    // MARK: - Methods

    /// Method that persists the draft onto `originalModel` and closes the screen
    /// once saving completes.
    private func confirmAndSave() async {
        isSaving = true
        await originalModel.save(from: choreDTO)
        isSaving = false
        dismiss()
    }

    /// A new chore keeps the empty draft created by `ChoreDTO()`.
    private func loadDraftIfNeeded() async {
        guard originalModel.recordID != nil else { return }

        async let checklistModels = originalModel.checkList
        async let responsibleUsers = originalModel.allResponsibleUsers
        async let room = originalModel.room

        let (savedChecklist, savedResponsibleUsers, savedRoom) = await (checklistModels, responsibleUsers, room)

        choreDTO = ChoreDTO(
            from: originalModel,
            users: savedResponsibleUsers,
            checklist: savedChecklist.map(CheckItemDTO.init(from:)),
            room: savedRoom
        )
    }
}

// MARK: - Mock for Preview
fileprivate class MockChoreModel: ChoreModel {
    var mockUsers: [UserModel] = []
    var mockChecklist: [CheckItemModel] = []
    var mockRoom: RoomModel? = nil
    
    override var allResponsibleUsers: [UserModel] { get async { mockUsers } }
    override var checkList: [CheckItemModel] { get async { mockChecklist } }
    override var room: RoomModel? { get async { mockRoom } }
}

#Preview {
    let user1 = UserModel(name: "Dayô", tier: .tier1, recordID: CKRecord.ID(recordName: "user1"))
    let user2 = UserModel(name: "João", tier: .tier1, recordID: CKRecord.ID(recordName: "user2"))
    let user3 = UserModel(name: "Maria", tier: .tier2, recordID: CKRecord.ID(recordName: "user3"))
    let allUsers = [user1, user2, user3]
    
    let check1 = CheckItemModel(name: "Limpar o espelho", isDone: true)
    check1.recordID = CKRecord.ID(recordName: "check1")
    let check2 = CheckItemModel(name: "Lavar o chão", isDone: false)
    check2.recordID = CKRecord.ID(recordName: "check2")
    
    let mockChore = MockChoreModel(
        name: "Lavar Banheiro",
        description: "Deixar tudo brilhando e cheiroso",
        isDone: false,
        frequency: .weekly,
        duration: 1800,
        isPublic: false,
        priorityTag: .urgent
    )
    
    mockChore.recordID = CKRecord.ID(recordName: "chore_existente")
    mockChore.mockUsers = [user1, user2]
    mockChore.mockChecklist = [check1, check2]
    
    return NavigationStack {
        CreateAndEditChoreView(
            originalModel: mockChore,
            availableHouseUsers: allUsers
        )
    }
}
