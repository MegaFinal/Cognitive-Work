//
//  CloudKitManager.swift
//  Cognitive-Work
//
//  Created by Jonas Fernando Nascimento Melo on 11/08/26.
//

import CloudKit

@Observable
class CloudKitManager {
    
    static let shared = CloudKitManager()
    
    // MARK: - Propriedades
    let container: CKContainer
    let privateDB: CKDatabase
    let sharedDB: CKDatabase
    
    var errorMessage: String?
    
    private let zoneName = "HomeEnviroment"
    
    /// Atenção: essa zona é sempre SUA (ownerName = usuário atual).
    /// Só deve ser usada em operações inerentemente suas, como criar a zona
    /// ou buscar households que você é dono. Para qualquer operação em cima
    /// de uma household específica (sua ou de outra pessoa), use sempre
    /// `household.recordID.zoneID` em vez desta propriedade.
    @ObservationIgnored
    lazy var houseZoneID = CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)
    
    private init(){
        container = CKContainer.init(identifier: "iCloud.JonasMelo.Cognitive-Work")
        privateDB = container.privateCloudDatabase
        sharedDB = container.sharedCloudDatabase
    }
    
    // MARK: - Setup da zona customizada (necessário pra compartilhar)
    
    func createZoneIfNeeded() async -> Bool {
        let zone = CKRecordZone(zoneID: houseZoneID)
        do {
            _ = try await privateDB.save(zone)
            return true
        }
        catch {
            errorMessage = "Falha ao criar zona: \(error.localizedDescription)"
            return false
        }
    }
    
    // MARK: - Compartilhamento (convites)
    
    /// Garante que exista um CKShare salvo pra essa household e o retorna.
    /// Normalmente já existe (criado junto no createHousehold), mas serve de fallback.
    func resolveShare(for house: CKRecord) async -> CKShare? {
        if let existing = await fetchShare(for: house) {
            return existing
        }
        
        let share = CKShare(rootRecord: house)
        share[CKShare.SystemFieldKey.title] = house["name"] as? String
        share.publicPermission = .readWrite
        
        let operation = CKModifyRecordsOperation(recordsToSave: [house, share], recordIDsToDelete: nil)
        operation.savePolicy = .allKeys
        
        return await withCheckedContinuation { continuation in
            operation.modifyRecordsResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume(returning: share)
                case .failure(let error):
                    self.errorMessage = "Fail to creat shared zone: \(error.localizedDescription)"
                    continuation.resume(returning: nil)
                }
            }
            privateDB.add(operation)
        }
    }
    
    /// Busca o CKShare associado a um household (útil pra reabrir a UI de convite depois).
    /// Usa a database certa: privada se a household é sua, compartilhada se você é convidado.
    func fetchShare(for house: CKRecord) async -> CKShare? {
        guard let shareReference = house.share else {
            print("house.share == nil")
            return nil
        }
        
        let db = house.recordID.zoneID.ownerName == CKCurrentUserDefaultName ? privateDB : sharedDB
        
        do {
            let share = try await db.record(for: shareReference.recordID) as? CKShare
            return share
        } catch {
            errorMessage = "Fail to fetch Shared: \(error.localizedDescription)"
            return nil
        }
    }
    
    func acceptShare(metadata: CKShare.Metadata) async -> Bool {
        let operation = CKAcceptSharesOperation(shareMetadatas: [metadata])
        
        return await withCheckedContinuation { continuation in
            operation.acceptSharesResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume(returning: true)
                case .failure(let error):
                    self.errorMessage = "Failed to accept invite: \(error.localizedDescription)"
                    continuation.resume(returning: false)
                }
            }
            self.container.add(operation)
        }
    }
    
    /// Função para criar as subscriptions que são responsaveis por deixar a atualização em tempo real
    func createSharedSubscription() async throws {
        let subscription = CKDatabaseSubscription(subscriptionID: "shared-changes")
        let privateSubscription = CKDatabaseSubscription(subscriptionID: "shared-changes")
        
        let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = true // push silenciosa
        
        subscription.notificationInfo = info
        privateSubscription.notificationInfo = info
        try await privateDB.save(privateSubscription)
        let saved = try await sharedDB.save(subscription)
    }
}
