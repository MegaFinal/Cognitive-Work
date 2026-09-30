//
//  CreateAndEditChoreView.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 28/08/26.
//

import SwiftUI
import CloudKit

/// A form view utilized to create a new chore or edit an existing one.
struct CreateAndEditChoreView: View {
    
    init(originalModel: ChoreModel,
         availableHouseUsers: [UserModel],
         carouselViewModel: CarouselViewModel,
         targetAssignments: [RecurrentAssignmentModel] = []) {
        self._viewModel = State(initialValue: CreateAndEditChoreViewModel(
            originalModel: originalModel,
            availableHouseUsers: availableHouseUsers,
            carouselViewModel: carouselViewModel,
            targetAssignments: targetAssignments
        ))
    }
    
    @State private var viewModel: CreateAndEditChoreViewModel
    
    @State private var showDeleteConfirmation = false
    
    @Environment(\.dismiss) private var dismiss
    
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
                        ChoreTagPicker(chore: $viewModel.draft, type: .priority)
                    }
                    
                    HStack {
                        Text("Duração")
                        Spacer()
                        ChoreTagPicker(chore: $viewModel.draft, type: .duration)
                    }
                    
                    HStack {
                        Text("Frequência")
                        Spacer()
                        ChoreTagPicker(chore: $viewModel.draft, type: .frequency)
                    }
                    
                    if viewModel.showsDateSection {
                        dateSection
                    }
                    
                }
                .font(.system(size: 15))
                .fontWeight(.semibold)
                
                // MARK: - Description
                VStack(alignment: .leading, spacing: 10) {
                    Text("Descrição")
                        .font(.system(size: 15))
                        .fontWeight(.semibold)
                    
                    TextField("Descrição da Tarefa", text: $viewModel.draft.description, axis: .vertical)
                        .font(.system(size: 17))
                        .foregroundColor(.gray)
                        .characterLimit(250, text: $viewModel.draft.description)
                }
                
                // MARK: - Checklist
                checklistSection
                
                // MARK: - Responsible Users
                VStack(alignment: .leading, spacing: 10) {
                    Text("Responsáveis")
                        .font(.system(size: 15))
                        .fontWeight(.semibold)
                    
                    ResponsibleUserPicker(
                        availableUsers: viewModel.selectableResponsibleUsers,
                        selectedUsers: $viewModel.draft.responsibleUsers
                    )
                }
                
                // MARK: - Visibility Toggle
                publicToggleSection
                
                Spacer()
                
                // MARK: - Confirmation Button
                confirmButton
                
                // MARK: - Delete Button
                if viewModel.showsDeleteButton {
                    deleteButton
                }
            }
            .padding(.vertical)
            .frame(width: width * 0.9)
        }
        .task {
            await viewModel.load()
        }
        .onChange(of: viewModel.draft.isPublic) { _, isPublic in
            viewModel.visibilityDidChange(isPublic: isPublic)
        }
        .onChange(of: viewModel.draft.frequency) { _, _ in
            viewModel.frequencyDidChange()
        }
        .hidesTabBar()
        .dismissKeyboardOnTap()
        .alert("Excluir Tarefa?", isPresented: $showDeleteConfirmation) {
            Button("Cancelar", role: .cancel) {}
            Button("Excluir", role: .destructive) {
                Task {
                    if await viewModel.delete() {
                        dismiss()
                    }
                }
            }
        } message: {
            Text("Se esta tarefa for recorrente, apenas esta ocorrência será excluída — as demais continuam como estão. Essa ação é permanente.")
        }
        .alert(
            viewModel.alert?.title ?? "",
            isPresented: Binding(
                get: { viewModel.alert != nil },
                set: { if !$0 { viewModel.alert = nil } }
            ),
            presenting: viewModel.alert
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { alert in
            Text(alert.message)
        }
        .blockingOperation(
            isPresented: Binding(get: { viewModel.isDeleting }, set: { _ in }),
            message: "Excluindo tarefa..."
        )
    }
    
    // MARK: - Subviews
    
    /// The uppermost structural section of the form: iconography, chore name field and room selection.
    private var header: some View {
        HStack {
            Image(systemName: viewModel.draft.room?.symbol ?? viewModel.draft.symbolName)
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
                        text: $viewModel.draft.name,
                        prompt: Text("Nome da Tarefa")
                            .foregroundStyle(.black)
                    )
                    .font(.system(size: 28))
                    .bold()
                    .characterLimit(18, text: $viewModel.draft.name)
                    
                    Capsule()
                        .frame(height: height * 0.0015)
                }
                
                HStack {
                    Text("Cômodo")
                        .bold()
                    
                    Spacer()
                    
                    Menu {
                        Picker("Cômodo", selection: $viewModel.draft.room) {
                            ForEach(viewModel.availableRooms, id: \.self) { room in
                                ColorIconTagLabel(title: room.name.capitalized, color: room.color.uiColor)
                                    .tag(RoomModel?(room))
                            }
                        }
                    }
                    label: {
                        HStack {
                            CapsuleTag(
                                tagName: viewModel.draft.room?.name.capitalized ?? "Sem Cômodo",
                                tagColor: viewModel.draft.room?.color.uiColor ?? .gray,
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
    
    /// Calendar shown below the pickers for every frequency except daily.
    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Data")
                .font(.system(size: 15))
                .fontWeight(.semibold)
            
            CustomCalendar(
                selectedDate: $viewModel.selectedDate,
                window: viewModel.dateWindow,
                opacityForDay: { viewModel.loadOpacity(on: $0) },
                earliestSelectable: viewModel.earliestSelectableDay
            )
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
                
                Toggle("", isOn: $viewModel.draft.hasChecklist)
                    .toggleStyle(.switch)
                    .onChange(of: viewModel.draft.hasChecklist) { _, isOn in
                        viewModel.checklistToggleDidChange(isOn: isOn)
                    }
                    .padding(.trailing, 3)
            }
            .frame(width: width * 0.9)
            
            if viewModel.draft.hasChecklist {
                CheckListCreateAndEdit(
                    hasChecklist: $viewModel.draft.hasChecklist,
                    localChecklist: $viewModel.draft.checklist
                )
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
                
                Toggle("", isOn: $viewModel.draft.isPublic)
                    .toggleStyle(.switch)
                    .padding(.trailing, 7)
                    .frame(width: width * 0.37)
            }
            .frame(width: width * 0.9)
            
            Text(viewModel.visibilityDescription)
                .font(.system(size: 15))
                .italic()
                .foregroundColor(.gray)
        }
    }
    
    /// Bottom-anchored confirmation button, featuring an embedded loading state.
    private var confirmButton: some View {
        VStack(spacing: 8) {
            if viewModel.showsMissingRoomWarning {
                Text("Escolha um cômodo para confirmar a tarefa.")
                    .font(.system(size: 13))
                    .foregroundColor(.red)
            } else if viewModel.showsMissingDateWarning {
                Text("Escolha uma data para confirmar a tarefa.")
                    .font(.system(size: 13))
                    .foregroundColor(.red)
            }
            
            HStack {
                Spacer()
                
                Button {
                    Task {
                        if await viewModel.confirm() {
                            dismiss()
                        }
                    }
                } label: {
                    Group {
                        if viewModel.isSaving {
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
                .disabled(!viewModel.canConfirm)
                .opacity(viewModel.canConfirm || viewModel.isSaving ? 1 : 0.5)
                
                Spacer()
            }
        }
    }
    
    /// Bottom-anchored destructive action that deletes the chore being edited
    private var deleteButton: some View {
        Button {
            showDeleteConfirmation = true
        } label: {
            Group {
                if viewModel.isDeleting {
                    ProgressView()
                        .tint(.red)
                } else {
                    Text("Excluir Tarefa")
                        .fontWeight(.semibold)
                }
            }
            .frame(height: height * 0.03)
        }
        .foregroundColor(.red)
        .disabled(viewModel.isSaving || viewModel.isDeleting)
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
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
