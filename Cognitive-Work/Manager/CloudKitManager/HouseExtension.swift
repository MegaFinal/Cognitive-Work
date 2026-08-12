//
//  HouseExtension.swift
//  Cognitive-Work
//
//  Created by Jonas Fernando Nascimento Melo on 11/08/26.
//

import CloudKit

// MARK: - House extension (CRUD)
extension CloudKitManager {
    
    /// Cria a "casa" e o CKShare associado a ela, num único save atômico.
    func createHouse(name: String, description: String) async -> (house: CKRecord, share: CKShare)? {
        let houseID = CKRecord.ID(recordName: UUID().uuidString, zoneID: houseZoneID)
        let house = CKRecord(recordType: "House", recordID: houseID)
        house["name"] = name
        house["description"] = description
        
        let share = CKShare(rootRecord: house)
        share[CKShare.SystemFieldKey.title] = name
        share.publicPermission = .readWrite //nivel de permissão que o link de convite da
        
        let operation = CKModifyRecordsOperation(recordsToSave: [house, share], recordIDsToDelete: nil)
        operation.savePolicy = .allKeys
        
        return await withCheckedContinuation { continuation in
            operation.modifyRecordsResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume(returning: (house, share))
                case .failure(let error):
                    self.errorMessage = "Falha ao criar casa: \(error.localizedDescription)"
                    continuation.resume(returning: nil)
                }
            }
            privateDB.add(operation)
        }
    }
    
    /// Busca todas as casas do usuário — próprias e compartilhadas.
    func fetchHouse() async throws -> CKRecord {
        let owned = await fetchOwnedHouse()
        let shared = await fetchSharedHouse()

        if let house = owned.first {
            return house
        }
        else if let house = shared.first {
            return house
        }
        else {
            throw HouseError.notFound
        }
    }
    
    /// Busca todas as casas que o usuário criou (é dono).
    private func fetchOwnedHouse() async -> [CKRecord] {
        let query = CKQuery(recordType: "House", predicate: NSPredicate(value: true))
        
        do {
            let (results, _) = try await privateDB.records(matching: query, inZoneWith: houseZoneID)
            return results.compactMap { try? $0.1.get() }
        } catch {
            errorMessage = "Falha ao buscar casas: \(error.localizedDescription)"
            return []
        }
    }
    
    /// Busca todas as casas que foram compartilhadas com o usuário (ele é convidado).
    private func fetchSharedHouse() async -> [CKRecord] {
        do {
            let zones = try await sharedDB.allRecordZones()
            
            var house: [CKRecord] = []
            
            for zone in zones {
                let query = CKQuery(recordType: "House",
                                    predicate: NSPredicate(value: true))
                
                let (results, _) = try await sharedDB.records(matching: query,inZoneWith: zone.zoneID)
                
                house.append(contentsOf: results.compactMap { try? $0.1.get() })
            }
            return house
        } catch {
            print(error)
            errorMessage = error.localizedDescription
            return []
        }
    }
    
    func updateHouseName(_ house: CKRecord, newName: String) async -> Bool {
        house["name"] = newName
        do {
            _ = try await privateDB.save(house)
            return true
        } catch {
            errorMessage = "Fail to update house name: \(error.localizedDescription)"
            return false
        }
    }
    
    func updateHouseDescription(_ house: CKRecord, newDescription: String) async -> Bool {
        house["description"] = newDescription
        do {
            _ = try await privateDB.save(house)
            return true
        } catch {
            errorMessage = "Fail to update house description: \(error.localizedDescription)"
            return false
        }
    }
    
    /// Apaga a casa inteira isso remove o share e revoga acesso de todos os moradores
    func deleteHouse(_ house: CKRecord) async -> Bool {
        do {
            try await privateDB.deleteRecord(withID: house.recordID)
            return true
        } catch {
            errorMessage = "Falha ao deletar casa: \(error.localizedDescription)"
            return false
        }
    }
    
}

enum HouseError: Error, LocalizedError {
    case notFound

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "Nenhuma casa encontrada (nem própria, nem compartilhada)."
        }
    }
}
