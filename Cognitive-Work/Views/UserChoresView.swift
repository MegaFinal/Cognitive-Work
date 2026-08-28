//
//  UserChoresView.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 25/08/26.
//

import SwiftUI

struct UserChoresView: View {
    @State var carouselVM = CarouselViewModel()
    var height = UIScreen.main.bounds.width
    @Namespace private var cardAnimation
    
    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 15) {
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
                    
                    HStack(spacing: 10) {
                        ProgressIndicatorCard(title: "Tempo médio", data: "1h 30min")
                        ProgressIndicatorCard(title: "Tempo médio", data: "1h 30min")
                        ProgressIndicatorCard(title: "Tempo médio", data: "1h 30min")
                    }
                    .padding(.horizontal, 30)
                    
                    Spacer()
                    .matchedGeometryEffect(id: "Spawnpoint", in: cardAnimation)
                    
                    if carouselVM.layoutMode != .grid {
                       ChoreListLayout(
                           viewModel: carouselVM,
                           onSwipeDown: carouselVM.toggleLayout, namespace: cardAnimation
                       )
                       .zIndex(1000)
                   }
                    RoundedRectangle(cornerRadius: 30)
                        .frame(width: 25, height: 25)
                }
                
                if carouselVM.layoutMode == .grid {
                    Spacer()
                    Carousel(
                        viewModel: carouselVM,
                        isBackgroundClear: true,
                        onSwipeDown: carouselVM.toggleLayout, namespace: cardAnimation
                    )
                    Spacer()
                    
                }
            }
            .background(
                Color(.white)
                    .ignoresSafeArea()
                    .onTapGesture {
                        carouselVM.clearFocus()
                    }
            )
//            .task {
//                if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" { return }
//                
//                await carouselVM.fetchChores()
//                await withTaskGroup(of: Void.self) { group in
//                    for cardVM in carouselVM.cardModels {
//                        group.addTask {
//                            await cardVM.loadDependencies()
//                        }
//                    }
//                }
//            }
        }
    }
}

#Preview {
    let viewModel = CarouselViewModel()
    return UserChoresView(carouselVM: viewModel)
}
