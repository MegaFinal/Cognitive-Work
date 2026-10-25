//
//  CreateAndEditChoreView.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 28/08/26.
//

import SwiftUI
import CloudKit

/// The sheet to create a new chore or edit an existing one, in two steps
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
    
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: CreateAndEditChoreViewModel
    @State private var showsScheduleStep = false
    @State private var showDeleteConfirmation = false
    @State private var isSubmitting = false
    @State private var showsCalendar = false
    
    /// Whether the form must ignore edits: still loading, saving or deleting.
    private var isFormLocked: Bool {
        !viewModel.isLoaded || isBusy
    }
    
    /// Saving or deleting.
    private var isBusy: Bool {
        isSubmitting || viewModel.isSaving || viewModel.isDeleting
    }
    
    private var roomColor: Color {
        (viewModel.draft.room?.color ?? .blue).uiColor
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            detailsStep
                .navigationDestination(isPresented: $showsScheduleStep) {
                    scheduleStep
                }
        }
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.groupedBackground)
        .interactiveDismissDisabled(isBusy)
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
    
    // MARK: - Step 1: details
    
    /// Photo, name, room, description and checklist.
    private var detailsStep: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                roomSymbol
                
                // MARK: Name
                VStack(alignment: .leading, spacing: 14) {
                    Text("Nome da tarefa")
                        .font(.title2.bold())
                        .accessibilityHidden(true)
                    
                    TextField("", text: $viewModel.draft.name, prompt: Text("Adicione o nome da tarefa"))
                        .characterLimit(TextLimits.choreName, text: $viewModel.draft.name)
                        .submitLabel(.done)
                        .voiceOverLabel(L10n.tr("Nome da tarefa"))
                        .voiceControlNames([L10n.tr("Nome da tarefa"), L10n.tr("Nome")])
                        .formField(in: Capsule())
                }
                
                // MARK: Room and the line in its color
                VStack(alignment: .leading, spacing: 6) {
                    roomRow
                        .formField(in: Capsule())
                    
                    if viewModel.showsMissingRoomWarning {
                        warning("Escolha um cômodo para confirmar a tarefa.")
                            .padding(.horizontal, 20)
                    }
                }
                
                Capsule()
                    .fill(roomColor)
                    .frame(height: 4)
                    .accessibilityHidden(true)
                
                // MARK: Description
                VStack(alignment: .leading, spacing: 10) {
                    sectionTitle("Detalhes")
                    
                    TextField("Descrição da tarefa", text: $viewModel.draft.description, axis: .vertical)
                        .characterLimit(TextLimits.choreDescription, text: $viewModel.draft.description)
                        .voiceControlNames([L10n.tr("Descrição da tarefa"), L10n.tr("Detalhes")])
                        .formField(in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                }
                
                // MARK: Checklist
                VStack(alignment: .leading, spacing: 10) {
                    sectionTitle("Checklist")
                    
                    CheckListCreateAndEdit(localChecklist: $viewModel.draft.checklist)
                        .padding(.horizontal, 20)
                        .padding(.top, 4)
                        .background(.white, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
            .disabled(isFormLocked)
            .opacity(isFormLocked ? 0.5 : 1)
        }
        .background(Color.groupedBackground)
        .dismissKeyboardOnTap()
        // MARK: - Loading spinner
        .overlay {
            if !viewModel.isLoaded {
                ProgressView()
                    .controlSize(.large)
                    .voiceOverLabel(L10n.tr("Carregando"))
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(role: .close) { dismiss() }
                    .disabled(isBusy)
            }
            
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    showsScheduleStep = true
                } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.glassProminent)
                .tint(.blue)
                .disabled(!viewModel.isLoaded || !viewModel.hasValidName || !viewModel.hasRoom)
                .voiceOverLabel(L10n.tr("Próximo"))
                .voiceControlNames([L10n.tr("Próximo"), L10n.tr("Continuar")])
            }
        }
    }
    
    /// "Cômodo" with a menu of the house's rooms.
    private var roomRow: some View {
        let roomName = viewModel.draft.room?.name.localizedDefault.capitalized(with: L10n.locale)
            ?? L10n.tr("Sem Cômodo")
        
        return ChoreAttributeMenuRow(title: "Cômodo", value: roomName, color: roomColor) {
            Picker("Cômodo", selection: $viewModel.draft.room) {
                ForEach(viewModel.availableRooms, id: \.self) { room in
                    ChoreMenuOption(
                        title: room.name.localizedDefault.capitalized(with: L10n.locale),
                        color: room.color.uiColor
                    )
                    .tag(RoomModel?(room))
                }
            }
        }
    }
    
    // MARK: - Step 2: schedule
    
    /// Priority, duration, frequency and date; who is responsible; sharing with the house.
    private var scheduleStep: some View {
        List {
            // MARK: Room symbol
            Section {
                roomSymbol
            }
            .listRowBackground(Color.clear)
            // No extra padding around the symbol.
            .listRowInsets(EdgeInsets())
            
            // MARK: Attributes and date
            Section {
                attributeRows
                
                if viewModel.showsDateSection {
                    dateRow
                }
            } footer: {
                if viewModel.showsMissingDateWarning {
                    warning("Escolha uma data para confirmar a tarefa.")
                }
            }
            
            // MARK: Responsible members
            Section {
                ResponsibleUserPicker(
                    availableUsers: viewModel.selectableResponsibleUsers,
                    selectedUsers: $viewModel.draft.responsibleUsers
                )
                .padding(.vertical, 6)
            } header: {
                sectionTitle("Responsáveis")
            }
            
            // MARK: Sharing with the house
            Section {
                Toggle(isOn: $viewModel.draft.isPublic) {
                    Text("Dividir com a casa?")
                        .fontWeight(.semibold)
                }
                .tint(.green)
                .voiceControlNames([L10n.tr("Dividir com a casa?"), L10n.tr("Dividir")])
            } footer: {
                Text("Ao dividir, qualquer morador pode receber essa tarefa. Sem dividir, ela fica apenas com quem você selecionou e não aparece para os outros moradores da casa.")
                    .italic()
            }
            
            // MARK: Delete (editing only)
            if viewModel.showsDeleteButton {
                Section {
                    deleteButton
                }
            }
        }
        .scrollContentBackground(.hidden)
        // The list's default top margin left a gap under the navigation bar.
        .contentMargins(.top, 0, for: .scrollContent)
        .background(Color.groupedBackground)
        .disabled(isFormLocked)
        .navigationTitle(viewModel.draft.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(isBusy)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                confirmButton
            }
        }
    }
    
    /// Priority, duration and frequency menus.
    @ViewBuilder
    private var attributeRows: some View {
        let draft = viewModel.draft
        
        ChoreAttributeMenuRow(
            title: "Prioridade",
            value: draft.priorityTag.displayName.firstLetterCapitalized,
            color: draft.priorityTag.color
        ) {
            Picker("Prioridade", selection: $viewModel.draft.priorityTag) {
                ForEach(PriorityTag.allCases.filter { $0 != .undefined }, id: \.self) { tag in
                    ChoreMenuOption(title: tag.displayName.firstLetterCapitalized, color: tag.color)
                        .tag(tag)
                }
            }
        }
        
        let tier = ChoreDurationTier.from(minutes: draft.duration)
        ChoreAttributeMenuRow(
            title: "Duração",
            value: tier.displayText.firstLetterCapitalized,
            color: tier.color
        ) {
            Picker("Duração", selection: durationTierBinding) {
                ForEach(ChoreDurationTier.allCases.filter { $0 != .undefined }, id: \.self) { tier in
                    ChoreMenuOption(title: tier.displayText.firstLetterCapitalized, color: tier.color)
                        .tag(tier)
                }
            }
        }
        
        ChoreAttributeMenuRow(
            title: "Frequência",
            value: draft.frequency.displayName.firstLetterCapitalized,
            color: draft.frequency.color
        ) {
            Picker("Frequência", selection: $viewModel.draft.frequency) {
                ForEach(Recurrence.allCases.filter { $0 != .undefined }, id: \.self) { frequency in
                    ChoreMenuOption(title: frequency.displayName.firstLetterCapitalized, color: frequency.color)
                        .tag(frequency)
                }
            }
        }
    }
    
    @ViewBuilder
    private var confirmButton: some View {
        if isSubmitting || viewModel.isSaving {
            ProgressView()
                .voiceOverLabel(L10n.tr("Salvando"))
        } else {
            Button {
                isSubmitting = true
                Task {
                    if await viewModel.confirm() {
                        HapticsManager.notify(.success)
                        dismiss()
                    } else {
                        isSubmitting = false
                    }
                }
            } label: {
                Image(systemName: "checkmark")
            }
            .buttonStyle(.glassProminent)
            .tint(.blue)
            .disabled(!viewModel.canConfirm)
            .voiceOverLabel(L10n.tr("Confirmar"))
            .voiceControlNames([L10n.tr("Confirmar"), L10n.tr("Salvar"), L10n.tr("OK")])
        }
    }
    
    private var deleteButton: some View {
        Button(role: .destructive) {
            showDeleteConfirmation = true
        } label: {
            Text("Excluir Tarefa")
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
        }
        .disabled(isBusy)
        .voiceControlNames([L10n.tr("Excluir Tarefa"), L10n.tr("Excluir")])
    }
    
    // MARK: - Room symbol
    
    private var roomSymbol: some View {
        SymbolImage(name: viewModel.draft.room?.symbol ?? "kite")
            .foregroundStyle(roomColor)
            .frame(width: width * 0.4, height: height * 0.14)
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)
    }
    
    // MARK: - Date
    
    /// "Calendário" with the picked date in a gray pill; tapping it opens the calendar.
    private var dateRow: some View {
        HStack {
            Text("Calendário")
                .fontWeight(.semibold)
            
            Spacer()
            
            Button {
                showsCalendar = true
            } label: {
                Text(selectedDateText)
                    .foregroundStyle(viewModel.selectedDate == nil ? Color.secondary : Color.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(.systemGray5), in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.tr("Calendário"))
            .accessibilityValue(selectedDateText)
            .popover(isPresented: $showsCalendar) {
                CustomCalendar(
                    selectedDate: $viewModel.selectedDate,
                    window: viewModel.dateWindow,
                    opacityForDay: { viewModel.loadOpacity(on: $0) },
                    earliestSelectable: viewModel.earliestSelectableDay
                )
                .padding()
                .frame(width: 340)
                .presentationCompactAdaptation(.popover)
            }
        }
        .onChange(of: viewModel.selectedDate) { _, date in
            if date != nil { showsCalendar = false }
        }
    }
    
    private var selectedDateText: String {
        guard let date = viewModel.selectedDate else { return L10n.tr("Escolher data") }
        return date.formatted(.dateTime.day().month(.abbreviated).year().locale(L10n.locale))
    }
    
    private var durationTierBinding: Binding<ChoreDurationTier> {
        Binding(
            get: { ChoreDurationTier.from(minutes: viewModel.draft.duration) },
            set: { viewModel.draft.duration = $0.minutes }
        )
    }
    
    // MARK: - Helpers
    
    private func sectionTitle(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(.primary)
            .textCase(nil)
            .accessibilityAddTraits(.isHeader)
    }
    
    private func warning(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.red)
    }
}

// MARK: - Form field style

private extension String {
    var firstLetterCapitalized: String {
        prefix(1).uppercased(with: L10n.locale) + dropFirst()
    }
}

private extension View {
    func formField<S: Shape>(in shape: S) -> some View {
        padding(.horizontal, 20)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white, in: shape)
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
    
    return CreateAndEditChoreView(
        originalModel: chore,
        availableHouseUsers: [user],
        carouselViewModel: CarouselViewModel()
    )
}
