////
////  ProfileEditToolbar.swift
////  Cognitive-Work
////
////  Created by Carolina Sun on 01/09/26.
////
//
//import SwiftUI
//
//struct ProfileEditToolbar: ToolbarContent {
//    @Bindable var viewModel: UserProfileViewModel
//
//    var body: some ToolbarContent {
//        if viewModel.isEditing {
//            
//            ToolbarItem(placement: .confirmationAction) {
//                Button{
//                    Task { await viewModel.saveChanges() }
//                } label:{
//                    Text("Salvar")
//                        .foregroundStyle(.blue)
//                }
//                .disabled(viewModel.isSaving || viewModel.editedName.trimmingCharacters(in: .whitespaces).isEmpty)
//            }
//            
//            ToolbarItem(placement: .cancellationAction) {
//                Button("Cancelar") {
//                    viewModel.cancelEditing()
//                }
//                .disabled(viewModel.isSaving)
//            }
//        }
//        
//        else{
//            ToolbarItem(placement: .confirmationAction){
//                Button("Editar") {
//                    viewModel.startEditing()
//                }
//            }
//            
//            ToolbarItem (placement: .cancellationAction) {
//                DeleteAccountButton(viewModel: viewModel)
//                    .foregroundStyle(.red)
//            }
//        }
//    }
//}
//
////#Preview {
////    ProfileEditToolbar()
////}
