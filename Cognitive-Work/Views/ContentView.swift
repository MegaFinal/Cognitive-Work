//
//  ContentView.swift
//  Cognitive-Work
//
//  Created by Jonas Fernando Nascimento Melo on 07/08/26.
//

import SwiftUI
import SwiftData
import CloudKit

struct ContentView: View {
    @State var url: URL? = nil
    @State var house: HouseModel? = nil
    var body: some View {
        VStack {
            Text("House name: \(house?.name ?? "no house")")
            Button {
                Task {
                    let house = HouseModel(name: "JonesHouseTest", description: "jfkdsfjdfiprajfiodfjadks")
                    guard let houseSaved = await CloudKitManager.shared.create(house)
                    else { return }
                    guard let share = await CloudKitManager.shared.resolveShare(for: houseSaved.toRecord())
                    else { return }
                    url = try? await CloudKitManager.shared.generateShareLink(share: share)
                }
            } label: {
                Image(systemName: "house")
            }
            .disabled(house != nil)
            .buttonStyle(.borderedProminent)
            
            CopyButtonView(textToCopy: url?.absoluteString ?? "no url")
        }
        .onAppear{
            Task {
                let predicate = NSPredicate(format: "name == %@", "JonesHouseTest")
                house = await CloudKitManager.shared.fetchAll(HouseModel.self, predicate: predicate).first
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .didAcceptShare)) { _ in
            Task {
                let predicate = NSPredicate(format: "name == %@", "JonesHouseTest")
                house = await CloudKitManager.shared.fetchAll(HouseModel.self, predicate: predicate).first
            }
        }
    }
}

#Preview {
    ContentView()
}

struct CopyButtonView: View {
    @State var textToCopy: String
    @State private var isCopied = false
    
    var body: some View {
        Button(action: {
            // Copy to system clipboard
            UIPasteboard.general.string = textToCopy
            
            // Trigger visual feedback
            withAnimation {
                isCopied = true
            }
            
            // Reset button text after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation {
                    isCopied = false
                }
            }
        }) {
            HStack {
                Image(systemName: isCopied ? "checkmark.circle.fill" : "doc.on.doc")
                Text(isCopied ? "Copied!" : "Copy Text")
            }
            .padding()
            .foregroundColor(.white)
            .background(isCopied ? Color.green : Color.blue)
            .cornerRadius(8)
        }
    }
}
