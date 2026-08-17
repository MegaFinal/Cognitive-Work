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

    private static let houseName = "JonesHouseTest"
    private static var housePredicate: NSPredicate {
        NSPredicate(format: "name == %@", houseName)
    }

    @State private var house: HouseModel?
    @State private var shareURL: URL?
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text(house?.name ?? "Nenhuma casa ainda")
                    .font(.headline)

                Button {
                    Task { await createHouseAndShare() }
                } label: {
                    if isWorking {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Label("Criar casa", systemImage: "house")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(house != nil || isWorking)

                CopyButtonView(textToCopy: shareURL?.absoluteString)

                if let shareURL {
                    ShareLink(item: shareURL) {
                        Label("Compartilhar convite", systemImage: "square.and.arrow.up")
                    }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
        }
        .task { await loadHouse() }
        .refreshable { await loadHouse() }
        .onReceive(NotificationCenter.default.publisher(for: .didAcceptShare)) { _ in
            Task { await loadHouse() }
        }
    }

    // MARK: - Ações

    @MainActor
    private func loadHouse() async {
        house = await CloudKitManager.shared
            .fetchAll(HouseModel.self, predicate: Self.housePredicate)
            .first
    }

    @MainActor
    private func createHouseAndShare() async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        
        await CloudKitManager.shared.createZoneIfNeeded()
        
        let newHouse = HouseModel(
            name: Self.houseName,
            description: "Casa de teste criada pelo app"
        )
        print("Instancia da casa")
        guard let saved = await CloudKitManager.shared.create(newHouse) else {
            print(CloudKitManager.shared.errorMessage)
            return
        }
        print("Salvo CloudKit")

        guard let record = await CloudKitManager.shared.fetchRecord(for: saved) else {
            errorMessage = "A casa foi criada, mas o registro ainda não está disponível. Puxe para atualizar."
            await loadHouse()
            return
        }

        guard let share = await CloudKitManager.shared.resolveShare(for: record) else {
            errorMessage = "Não foi possível preparar o compartilhamento desta casa."
            await loadHouse()
            return
        }

        do {
            shareURL = try await CloudKitManager.shared.generateShareLink(share: share)
        } catch {
            errorMessage = "Falha ao gerar o link: \(error.localizedDescription)"
        }

        await loadHouse()
    }
}

// MARK: - Botão de copiar

struct CopyButtonView: View {
    let textToCopy: String?

    @State private var isCopied = false

    var body: some View {
        Button {
            guard let textToCopy else { return }
            UIPasteboard.general.string = textToCopy

            withAnimation { isCopied = true }
            Task {
                try? await Task.sleep(for: .seconds(2))
                withAnimation { isCopied = false }
            }
        } label: {
            HStack {
                Image(systemName: isCopied ? "checkmark.circle.fill" : "doc.on.doc")
                Text(isCopied ? "Copiado" : (textToCopy ?? "Nenhum link ainda"))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .foregroundStyle(.white)
            .background(isCopied ? Color.green : Color.blue, in: .rect(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .disabled(textToCopy == nil)
        .opacity(textToCopy == nil ? 0.5 : 1)
    }
}

#Preview {
    ContentView()
}
