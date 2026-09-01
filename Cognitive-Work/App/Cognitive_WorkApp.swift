//
//  Cognitive_WorkApp.swift
//  Cognitive-Work
//
//  Created by Jonas Fernando Nascimento Melo on 07/08/26.
//

import SwiftUI
import SwiftData

@main
struct Cognitive_WorkApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var didOnboard = false
    
    var body: some Scene {
        WindowGroup {
            if didOnboard {
                ContentView()
            } else {
                Onboarding(didOnboard: $didOnboard)
                    .onAppear {
                        Task {
                            try? await CloudKitCleaner.wipePrivateDatabase(defaultZoneRecordTypes: [
                                "UserModel",
                                "RoomModel",
                                "HouseModel",
                                "ChoreModel",
                                "AvailableTimeModel",
                                "DailyAssignmentModel"
                            ])
                            print("limpo")
                        }
                    }
            }
        }
    }
}

import CloudKit

enum CloudKitCleaner {

    /// Apaga tudo do banco privado.
    /// - Parameter recordTypes: tipos que existem na zona default. Zonas customizadas
    ///   são apagadas inteiras e não precisam ser listadas aqui.
    static func wipePrivateDatabase(defaultZoneRecordTypes: [String] = []) async throws {
        let db = CKContainer.default().privateCloudDatabase

        // 1. Apaga todas as zonas customizadas (leva junto registros, shares e subscriptions de zona)
        let zones = try await db.allRecordZones()
        let customZoneIDs = zones
            .map(\.zoneID)
            .filter { $0 != CKRecordZone.default().zoneID }

        if !customZoneIDs.isEmpty {
            _ = try await db.modifyRecordZones(saving: [], deleting: customZoneIDs)
        }

        // 2. Limpa a zona default, tipo por tipo
        for type in defaultZoneRecordTypes {
            try await deleteAll(ofType: type, in: db)
        }

        // 3. Opcional: remove subscriptions restantes
        let subs = try await db.allSubscriptions()
        if !subs.isEmpty {
            _ = try await db.modifySubscriptions(saving: [], deleting: subs.map(\.subscriptionID))
        }
    }

    private static func deleteAll(ofType type: String, in db: CKDatabase) async throws {
        let query = CKQuery(recordType: type, predicate: NSPredicate(value: true))
        var cursor: CKQueryOperation.Cursor?

        repeat {
            let page: (matchResults: [(CKRecord.ID, Result<CKRecord, Error>)],
                       queryCursor: CKQueryOperation.Cursor?)

            if let cursor {
                page = try await db.records(continuingMatchFrom: cursor,
                                            desiredKeys: [],
                                            resultsLimit: 400)
            } else {
                page = try await db.records(matching: query,
                                            inZoneWith: CKRecordZone.default().zoneID,
                                            desiredKeys: [],
                                            resultsLimit: 400)
            }

            let ids = page.matchResults.map(\.0)
            if !ids.isEmpty {
                _ = try await db.modifyRecords(saving: [], deleting: ids)
            }
            cursor = page.queryCursor
        } while cursor != nil
    }
}
