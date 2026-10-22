//
//  CreateAndEditChoreView.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 28/08/26.
//

import SwiftUI
import CloudKit

/// The form to create a new chore or edit an existing one: name and room, priority, duration,
/// frequency, date, description, checklist, who is responsible and whether it's for the house.
/// When editing it can also delete the chore (only this occurrence for recurring chores).
struct CreateAndEditChoreView: View {
    
    /// Creates the form.
    /// - Parameters:
    ///   - originalModel: The chore to edit, or a new empty chore to create.
    ///   - availableHouseUsers: The members that can be made responsible.
    ///   - carouselViewModel: The chores screen's view model, updated after saving.
    ///   - targetAssignments: The occurrence(s) being edited, for recurring chores.
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
    
    /// Holds the draft and saves, deletes and validates it.
    @State private var viewModel: CreateAndEditChoreViewModel
    
    /// Shows the "delete chore?" alert.
    @State private var showDeleteConfirmation = false
    
    /// `true` from the moment the confirm button is tapped until the screen is dismissed
    /// (or the save fails). Unlike `viewModel.isSaving`, it doesn't drop back to `false`
    /// right before `dismiss()`, so the form stays locked during the closing animation too.
    @State private var isSubmitting = false
    
    /// Whether the form must ignore edits: still loading, saving or deleting.
    private var isFormLocked: Bool {
        !viewModel.isLoaded || isSubmitting || viewModel.isSaving || viewModel.isDeleting
    }
    
    /// Closes the form.
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Form
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 25) {
                header
                
                // MARK: - Validation warnings
                validationWarning
                
                // MARK: - Pickers
                VStack(spacing: 10) {
                    HStack {
                        Text("Prioridade")
                            .accessibilityHidden(true) // the picker says "Prioridade"
                        Spacer()
                        ChoreTagPicker(chore: $viewModel.draft, type: .priority)
                    }
                    
                    HStack {
                        Text("Duração")
                            .accessibilityHidden(true) // the picker says "Duração"
                        Spacer()
                        ChoreTagPicker(chore: $viewModel.draft, type: .duration)
                    }
                    
                    HStack {
                        Text("Frequência")
                            .accessibilityHidden(true) // the picker says "Frequência"
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
                        .accessibilityAddTraits(.isHeader)
                    
                    TextField("Descrição da Tarefa", text: $viewModel.draft.description, axis: .vertical)
                        .voiceControlNames([L10n.tr("Descrição da Tarefa"), L10n.tr("Descrição")])
                        .font(.system(size: 17))
                        .foregroundColor(.gray)
                        .characterLimit(TextLimits.choreDescription, text: $viewModel.draft.description)
                }
                
                // MARK: - Checklist
                checklistSection
                
                // MARK: - Responsible Users
                VStack(alignment: .leading, spacing: 10) {
                    Text("Responsáveis")
                        .font(.system(size: 15))
                        .fontWeight(.semibold)
                        .accessibilityAddTraits(.isHeader)
                    
                    ResponsibleUserPicker(
                        availableUsers: viewModel.selectableResponsibleUsers,
                        selectedUsers: $viewModel.draft.responsibleUsers
                    )
                }
                
                // MARK: - Visibility Toggle
                publicToggleSection
                
                Spacer()
                
                // MARK: - Delete Button
                if viewModel.showsDeleteButton {
                    deleteButton
                }
            }
            .padding(.vertical)
            .frame(width: width * 0.9)
            // MARK: - Locks the form while loading, saving or deleting
            // `load()` rebuilds the draft, so anything typed before it finishes would be lost.
            // While saving or deleting, edits would be ignored (the draft was already sent).
            .disabled(isFormLocked)
            .opacity(isFormLocked ? 0.5 : 1)
        }
        .hidesTabBar()
        // MARK: - Loading spinner
        .overlay {
            if !viewModel.isLoaded {
                ProgressView()
                    .controlSize(.large)
                    .voiceOverLabel(L10n.tr("Carregando"))
            }
        }
        .navigationBarBackButtonHidden(isSubmitting || viewModel.isSaving || viewModel.isDeleting)
        .toolbar {
            // MARK: - Confirmation Button
            ToolbarItem(placement: .confirmationAction) {
                if isSubmitting || viewModel.isSaving {
                    ProgressView()
                        .voiceOverLabel(L10n.tr("Salvando"))
                } else {
                    Button {
                        // Lock the form right away, before the first `await`.
                        isSubmitting = true
                        Task {
                            if await viewModel.confirm() {
                                HapticsManager.notify(.success)
                                dismiss()
                            } else {
                                // Save failed or was refused: let the user fix the form.
                                isSubmitting = false
                            }
                        }
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12))
                            .bold()
                            .foregroundColor(.white)
                    }
                    .tint(.blue)
                    .buttonStyle(.glassProminent)
                    .disabled(!viewModel.canConfirm)
                    .voiceOverLabel(L10n.tr("Confirmar"))
                    .voiceControlNames([L10n.tr("Confirmar"), L10n.tr("Salvar"), L10n.tr("OK")])
                }
            }
        }
        // MARK: - Loading and reacting to visibility and frequency changes
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
        // MARK: - Delete alert, error alert and deleting overlay
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
                .accessibilityDecorative()
            
            Spacer()
            
            VStack(spacing: 25) {
                VStack(spacing: 2) {
                    TextField(
                        "",
                        text: $viewModel.draft.name,
                        prompt: Text("Nome da Tarefa")
                            .foregroundStyle(.black)
                    )
                    .font(.custom("Alan Sans", size: 28))
                    .fontWeight(.semibold)
                    .characterLimit(TextLimits.choreName, text: $viewModel.draft.name)
                    .submitLabel(.done)
                    .voiceOverLabel(L10n.tr("Nome da Tarefa"))
                    .voiceControlNames([L10n.tr("Nome da Tarefa"), L10n.tr("Nome")])
                    
                    Capsule()
                        .frame(height: height * 0.0015)
                        .accessibilityDecorative()
                }
                
                HStack {
                    Text("Cômodo")
                        .bold()
                        .accessibilityHidden(true) // the menu says "Cômodo"
                    
                    Spacer()
                    
                    Menu {
                        Picker("Cômodo", selection: $viewModel.draft.room) {
                            ForEach(viewModel.availableRooms, id: \.self) { room in
                                ColorIconTagLabel(title: room.name.localizedDefault.capitalized(with: L10n.locale), color: room.color.uiColor)
                                    .tag(RoomModel?(room))
                            }
                        }
                    }
                    label: {
                        HStack {
                            CapsuleTag(
                                tagName: viewModel.draft.room?.name.localizedDefault.capitalized(with: L10n.locale) ?? L10n.tr("Sem Cômodo"),
                                tagColor: viewModel.draft.room?.color.uiColor ?? .gray,
                                horizontalPadding: 10.0,
                                verticalPadding: 1.5
                            )
                            
                            Image(systemName: "chevron.up.chevron.down")
                                .foregroundColor(.black)
                                .imageScale(.small)
                        }
                        .fixedSize()
                    }
                    .voiceOverLabel(L10n.tr("Cômodo"))
                    .voiceOverValue(viewModel.draft.room?.name.localizedDefault ?? L10n.tr("Sem Cômodo"))
                    .voiceControlNames([
                        L10n.tr("Cômodo"),
                        viewModel.draft.room?.name.localizedDefault.capitalized(with: L10n.locale) ?? L10n.tr("Sem Cômodo")
                    ])
                    .id(viewModel.draft.room?.recordID)
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
                .accessibilityAddTraits(.isHeader)
            
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
                    .accessibilityHidden(true) // the switch says "Checklist"
                
                Spacer()
                
                Toggle("", isOn: $viewModel.draft.hasChecklist)
                    .toggleStyle(.switch)
                    .voiceOverLabel(L10n.tr("Checklist"))
                    .voiceControlNames([L10n.tr("Checklist"), L10n.tr("Lista de itens")])
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
                    .accessibilityHidden(true) // the switch says it
                
                Spacer()
                
                Toggle("", isOn: $viewModel.draft.isPublic)
                    .toggleStyle(.switch)
                    .voiceOverLabel(L10n.tr("Essa tarefa é para a casa?"))
                    .voiceControlNames([L10n.tr("Essa tarefa é para a casa?"), L10n.tr("Para a casa"), L10n.tr("Tarefa da casa")])
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
    
    /// Explains why the (top-right) confirm button is disabled. Shown near the top so it is
    /// visible without scrolling.
    @ViewBuilder
    private var validationWarning: some View {
        if viewModel.showsMissingRoomWarning {
            Text("Escolha um cômodo para confirmar a tarefa.")
                .font(.system(size: 13))
                .foregroundColor(.red)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .onAppear { VoiceOver.announce(L10n.tr("Escolha um cômodo para confirmar a tarefa.")) }
        } else if viewModel.showsMissingDateWarning {
            Text("Escolha uma data para confirmar a tarefa.")
                .font(.system(size: 13))
                .foregroundColor(.red)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .onAppear { VoiceOver.announce(L10n.tr("Escolha uma data para confirmar a tarefa.")) }
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
                        .voiceOverLabel(L10n.tr("Excluindo tarefa..."))
                } else {
                    Text("Excluir Tarefa")
                        .fontWeight(.semibold)
                }
            }
            .frame(height: height * 0.03)
        }
        .foregroundColor(.red)
        .voiceControlNames([L10n.tr("Excluir Tarefa"), L10n.tr("Excluir")])
        .disabled(isSubmitting || viewModel.isSaving || viewModel.isDeleting)
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }
    
    /// A room option in the room menu: a colored circle and the room's name.
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

#Preview("Edição") {
    let house = CKRecord.Reference(recordID: CKRecord.ID(recordName: "preview-house"), action: .none)
    let user = UserModel(
        name: "Ana",
        tier: .tier1,
        house: house,
        recordID: CKRecord.ID(recordName: "preview-user-Ana"),
        ownerRecordName: "preview-owner-Ana"
    )
    let chore = ChoreModel(
        name: "Lavar a louça",
        description: "Pratos, copos e panelas.",
        dueDate: Calendar.current.date(byAdding: .day, value: 2, to: Date()),
        frequency: .weekly,
        duration: 30,
        isPublic: true,
        priorityTag: .high
    )
    chore.recordID = CKRecord.ID(recordName: "preview-chore")
    
    return NavigationStack {
        CreateAndEditChoreView(
            originalModel: chore,
            availableHouseUsers: [user],
            carouselViewModel: CarouselViewModel()
        )
    }
}
