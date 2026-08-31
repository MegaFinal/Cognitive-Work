//
//  ChoresViewHeader.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 30/08/26.
//

import SwiftUI

/// Renders the page title alongside a layout toggle control switch.
struct ChoresViewHeader: View {
    
    /// The carousel view model injected from the parent to toggle between list and carousel contexts.
    @Binding var carouselVM: CarouselViewModel
    
    var body: some View {
        HStack {
            Text("Suas Tarefas")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.horizontal, 30)
                .padding(.top, 20)
            
            Spacer()
            
            LayoutToggleButton(viewModel: carouselVM)
                .padding(.top, 20)
                .padding(.trailing, 30)
        }
    }
}
