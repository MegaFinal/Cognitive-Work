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
    
    init(originalModel: ChoreModel,
         availableHouseUsers: [UserModel],
         carouselViewModel: CarouselViewModel,
         targetAssignments: [RecurrentAssignmentModel] = []) {
        self.originalModel = originalModel
        self.carouselViewModel = carouselViewModel
        self.targetAssignments = targetAssignments
        
        var bestByOwner: [String: UserModel] = [:]
        for user in availableHouseUsers {
            let key = user.ownerRecordName
            if let existing = bestByOwner[key] {
                if existing.houseReference == nil && user.houseReference != nil {
                    bestByOwner[key] = user
                }
            } else {
                bestByOwner[key] = user
            }
        }
        
        self._availableHouseUsers = State(initialValue: Array(bestByOwner.values))
        self._choreDTO = State(initialValue: ChoreDTO(from: originalModel, users: [], checklist: [], room: nil))
                 
        self._availableRooms = State(initialValue: [])
        self._isSaving = State(initialValue: false)
    }
    
    /// The persisted chore being edited, or an unsaved chore instance when creating a new one.
    var originalModel: ChoreModel
    
    var targetAssignments: [RecurrentAssignmentModel]
    
    @State private var availableHouseUsers: [UserModel]
    @State private var availableRooms: [RoomModel] = []
    
    /// A local copy of the chore's editable fields to prevent wrong modifications.
    @State private var choreDTO: ChoreDTO
    
    /// Indicates whether an asynchronous save operation is currently in progress.
    @State private var isSaving = false
    
    @Bindable var carouselViewModel: CarouselViewModel
    
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
                .font(.system(size: 15))
                .fontWeight(.semibold)
                
                // MARK: - Description
                VStack(alignment: .leading, spacing: 10) {
                    Text("Descrição")
                        .font(.system(size: 15))
                        .fontWeight(.semibold)
                    
                    TextField("Descrição da Tarefa", text: $choreDTO.description, axis: .vertical)
                        .font(.system(size: 17))
                        .foregroundColor(.gray)
                }
                
                // MARK: - Checklist
                checklistSection
                
                // MARK: - Responsible Users
                VStack(alignment: .leading, spacing: 10) {
                    Text("Responsáveis")
                        .font(.system(size: 15))
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
            availableRooms = await CloudKitManager.shared.fetchAll(RoomModel.self)
            choreDTO.room = await originalModel.room
             
            let checklistModels = await originalModel.checkList
            choreDTO.checklist = checklistModels.map(CheckItemDTO.init(from:))
            choreDTO.hasChecklist = !choreDTO.checklist.isEmpty
             
            if !targetAssignments.isEmpty {
                let userIDs = Set(targetAssignments.compactMap { $0.userReference?.recordID })
                choreDTO.responsibleUsers = availableHouseUsers.filter { user in
                    guard let id = user.recordID else { return false }
                    return userIDs.contains(id)
                }
            } else if let refs = originalModel.allResponsibleUsersReference {
                let userIDs = Set(refs.map { $0.recordID })
                choreDTO.responsibleUsers = availableHouseUsers.filter { userIDs.contains($0.recordID ?? CKRecord.ID(recordName: "")) }
            }
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
                    .font(.system(size: 28))
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
                    .font(.system(size: 15))
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
                    .font(.system(size: 15))
                    .fontWeight(.semibold)
                
                Spacer()
                
                Toggle("", isOn: $choreDTO.isPublic)
                    .toggleStyle(.switch)
                    .padding(.trailing, 7)
                    .frame(width: width * 0.37)
            }
            .frame(width: width * 0.9)
            
            Text("Caso essa tarefa seja para a sua casa ela aparecerá publica para todos os moradores.")
                .font(.system(size: 15))
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
        
        await originalModel.save(from: choreDTO, targetAssignments: targetAssignments)
        await carouselViewModel.refreshAfterChoreUpdate()
        
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
}
