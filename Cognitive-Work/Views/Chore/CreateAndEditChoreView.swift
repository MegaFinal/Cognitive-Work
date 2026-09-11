//
//  CreateAndEditChoreView.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 28/08/26.
//

import SwiftUI
import CloudKit

/// A form view utilized to create a new chore or edit an existing one.
///
/// This view isolates the user's edits in a `ChoreDTO`. The underlying `originalModel`
/// is only modified and persisted to CloudKit when the user explicitly confirms the changes.
struct CreateAndEditChoreView: View {
    
    init(originalModel: ChoreModel, availableHouseUsers: [UserModel]) {
        self.originalModel = originalModel
        self._availableHouseUsers = State(initialValue: availableHouseUsers)
    }
    
    /// The persisted chore being edited, or an unsaved chore instance when creating a new one.
    var originalModel: ChoreModel
    
    @State private var availableHouseUsers: [UserModel]
    @State private var availableRooms: [RoomModel] = []
    
    /// A local copy of the chore's editable fields to prevent wrong modifications.
    @State private var choreDTO = ChoreDTO()
    
    /// Indicates whether an asynchronous save operation is currently in progress.
    @State private var isSaving = false
    
    @Environment(\.dismiss) private var dismiss
    
    var width = UIScreen.main.bounds.width
    var height = UIScreen.main.bounds.height
    
    // MARK: - Main Body
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 25) {
                header
                
                // MARK: - Pickers
                VStack(spacing: 10) {
                    HStack {
                        Text("Prioridade")
                        Spacer()
                        ChoreTagPicker(chore: $choreDTO, type: .priority)
                    }
                    
                    HStack {
                        Text("Duração")
                        Spacer()
                        ChoreTagPicker(chore: $choreDTO, type: .duration)
                    }
                    
                    HStack {
                        Text("Frequência")
                        Spacer()
                        ChoreTagPicker(chore: $choreDTO, type: .frequency)
                    }
                }
                .font(.subheadline)
                .fontWeight(.semibold)
                
                // MARK: - Description
                VStack(alignment: .leading, spacing: 10) {
                    Text("Descrição")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    TextField("Descrição da Tarefa", text: $choreDTO.description, axis: .vertical)
                        .font(.body)
                        .foregroundColor(.gray)
                }
                
                // MARK: - Checklist
                checklistSection
                
                // MARK: - Responsible Users
                VStack(alignment: .leading, spacing: 10) {
                    Text("Responsáveis")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    ResponsibleUserPicker(availableUsers: availableHouseUsers, selectedUsers: $choreDTO.responsibleUsers)
                }
                
                // MARK: - Visibility Toggle
                publicToggleSection
                
                Spacer()
                
                // MARK: - Confirmation Button
                confirmButton
            }
            .padding(.vertical)
            .frame(width: width * 0.9)
        }
        .task {
            await loadDraftIfNeeded()
            availableRooms = await CloudKitManager.shared.fetchAll(RoomModel.self)
        }
    }
    
    // MARK: - Subviews
    
    /// The uppermost structural section of the form: iconography, chore name field and room selection.
    private var header: some View {
        HStack {
            Image(systemName: choreDTO.symbolName)
                .resizable()
                .scaledToFit()
                .frame(width: width * 0.15)
                .fontWeight(.thin)
                .padding(.leading, 8)
            
            Spacer()
            
            VStack(spacing: 25) {
                VStack(spacing: 2) {
                    TextField(
                        "",
                        text: $choreDTO.name,
                        prompt: Text("Nome da Tarefa")
                            .foregroundStyle(.black)
                    )
                    .font(.title)
                    .bold()
                    
                    Capsule()
                        .frame(height: height * 0.0015)
                }
                
                HStack {
                    Text("Cômodo")
                        .bold()
                    
                    Spacer()
                    
                    Menu {
                        Picker("Cômodo", selection: $choreDTO.room) {
                            ForEach(availableRooms, id: \.self) { room in
                                ColorIconTagLabel(title: room.name.capitalized, color: room.color.uiColor)
                                    .tag(RoomModel?(room))
                            }
                        }
                    }
                    label: {
                        HStack {
                            CapsuleTag(
                                tagName: choreDTO.room?.name.capitalized ?? "Sem Cômodo",
                                tagColor: choreDTO.room?.color.uiColor ?? .gray,
                                horizontalPadding: 10.0,
                                verticalPadding: 1.5
                            )
                            
                            Image(systemName: "chevron.up.chevron.down")
                                .foregroundColor(.black)
                                .imageScale(.small)
                        }
                    }
//                    ChoreTagPicker(chore: $choreDTO, type: .room, availableRooms: availableRooms)
                }
            }
            .frame(width: width * 0.65)
        }
        
    }
    
    /// Encapsulates the toggle and the inline editor for the chore's checklist.
    private var checklistSection: some View {
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
    
    /// Contains the switch for deciding whether the chore should be public to the household.
    private var publicToggleSection: some View {
        VStack {
            HStack {
                Text("Essa tarefa é para a casa?")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Toggle("", isOn: $choreDTO.isPublic)
                    .toggleStyle(.switch)
                    .padding(.trailing, 7)
                    .frame(width: width * 0.37)
            }
            .frame(width: width * 0.9)
            
            Text("Caso essa tarefa seja para a sua casa ela aparecerá publica para todos os moradores.")
                .font(.subheadline)
                .italic()
                .foregroundColor(.gray)
        }
    }
    
    /// Bottom-anchored confirmation button, featuring an embedded loading state.
    private var confirmButton: some View {
        HStack {
            Spacer()
            
            Button {
                Task { await confirmAndSave() }
            } label: {
                Group {
                    if isSaving {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Confirmar")
                            .foregroundColor(.white)
                            .fontWeight(.bold)
                    }
                }
                .frame(width: width * 0.8, height: height * 0.06)
                .background(Color.blue)
                .clipShape(Capsule())
            }
            .disabled(choreDTO.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
            
            Spacer()
        }
    }
    
    // MARK: - Methods
    
    /// Persists the modifications from the local copy onto `originalModel` and dismisses the view.
    @MainActor
    private func confirmAndSave() async {
        isSaving = true
        await originalModel.save(from: choreDTO)
        isSaving = false
        dismiss()
    }
    
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
    
    /// Pre-populates the local copy if editing an existing chore.
    /// A new chore maintains the empty default copy provided by `ChoreDTO()`.
    private func loadDraftIfNeeded() async {
        guard originalModel.recordID != nil else { return }
        
        async let checklistModels = originalModel.checkList
        async let responsibleUsers = originalModel.allResponsibleUsers
        async let room = originalModel.room
        
        choreDTO.duration = originalModel.duration
        choreDTO.frequency = originalModel.frequency
        choreDTO.priorityTag = originalModel.priorityTag
        choreDTO.name = originalModel.name
        choreDTO.symbolName = originalModel.symbolName
        choreDTO.originalRecordID = originalModel.recordID
        choreDTO.room = await room
        choreDTO.checklist = await checklistModels.map(CheckItemDTO.init(from:))
        choreDTO.responsibleUsers = await responsibleUsers
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
//TODO: FIX PREVIEW
//#Preview {
//    let user1 = UserModel(name: "Dayô", tier: .tier1, recordID: CKRecord.ID(recordName: "user1"))
//    let user2 = UserModel(name: "João", tier: .tier1, recordID: CKRecord.ID(recordName: "user2"))
//    let user3 = UserModel(name: "Maria", tier: .tier2, recordID: CKRecord.ID(recordName: "user3"))
//    let allUsers = [user1, user2, user3]
//    
//    let check1 = CheckItemModel(name: "Limpar o espelho", isDone: true)
//    check1.recordID = CKRecord.ID(recordName: "check1")
//    let check2 = CheckItemModel(name: "Lavar o chão", isDone: false)
//    check2.recordID = CKRecord.ID(recordName: "check2")
//    
//    let mockChore = MockChoreModel(
//        name: "Lavar Banheiro",
//        description: "Deixar tudo brilhando e cheiroso",
//        isDone: false,
//        frequency: .weekly,
//        duration: 1800,
//        isPublic: false,
//        priorityTag: .urgent
//    )
//    
//    mockChore.recordID = CKRecord.ID(recordName: "chore_existente")
//    mockChore.mockUsers = [user1, user2]
//    mockChore.mockChecklist = [check1, check2]
//    
//    NavigationStack {
//        CreateAndEditChoreView(
//            originalModel: mockChore,
//            availableHouseUsers: allUsers
//        )
//    }
//}
